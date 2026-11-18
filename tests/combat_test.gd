extends Node
## Combat rules tests (no 3D): godot --headless --path . res://tests/combat_test.tscn
var fails := 0
var log_lines: Array = []


func _ready() -> void:
	Combat.instant = true
	Combat.logged.connect(func(t): log_lines.append(t))
	Banter.silence_weight = 1.0
	Dice.rng.seed = 7
	await _fireball_bug()
	await _load_save()
	await _sneak_attack()
	await _opportunity_attack()
	await _lie_down()
	await _death_saves()
	await _full_fight(true)
	await _full_fight(false)
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _party(level: int) -> Dictionary:
	var out := {}
	var x := 0.0
	for id in [&"protagonist", &"husband", &"poet", &"sl"]:
		var c := Combatant.new(CharacterSheet.from_party(id, level), null, &"party")
		c.set_pos(Vector3(x, 0, 0))
		x += 1.5
		out[id] = c
	return out


func _mob(kind: String, n: int, at: Vector3) -> Array:
	var out: Array = []
	for i in n:
		var c := Combatant.new(CharacterSheet.from_monster(kind, StringName("%s_%d" % [kind, i])), null, &"enemy")
		c.set_pos(at + Vector3(i * 1.2, 0, 0))
		out.append(c)
	return out


func _start(list: Array) -> void:
	var typed: Array[Combatant] = []
	typed.assign(list)
	Combat.start(typed)
	await get_tree().process_frame


## 让指定单位成为当前回合
func _force_turn(c: Combatant) -> void:
	Combat.turn_index = Combat.order.find(c)
	c.start_turn()


func _stop() -> void:
	Combat.active = false
	await get_tree().process_frame


func _fireball_bug() -> void:
	print("== fireball bug (husband L1, no slot, friendly fire)")
	var p := _party(1)
	var gob := _mob("goblin", 2, Vector3(10, 0, 0))
	for g in gob:
		g.sheet.hp = 500
	await _start(p.values() + gob)
	var h: Combatant = p[&"husband"]
	_force_turn(h)
	var a := Combat.find_action(h, "spell:fireball")
	_ok(not a.is_empty(), "husband has fireball at level 1")
	_ok(Combat.why_not(h, a) == "", "fireball usable with no slots")
	var poet: Combatant = p[&"poet"]
	poet.set_pos(Vector3(10.5, 0, 1))
	var hp_before := poet.sheet.hp
	_ok(Combat.perform(h, a, Vector3(10.5, 0, 0)), "fireball cast")
	_ok(poet.sheet.hp < hp_before, "poet caught in fireball (%d -> %d)" % [hp_before, poet.sheet.hp])
	h.actions = 1
	_ok(Combat.perform(h, a, Vector3(10.5, 0, 0)), "cast again: unlimited")
	_ok(h.sheet.slots_used == [] or h.sheet.slots_used.all(func(x): return x == 0), "no slot spent")
	await _stop()


func _load_save() -> void:
	print("== SL load save")
	var p := _party(1)
	var gob := _mob("goblin", 1, Vector3(1, 0, 1))
	await _start(p.values() + gob)
	var sl: Combatant = p[&"sl"]
	var pr: Combatant = p[&"protagonist"]
	pr.sheet.apply_damage(5, "slashing")
	gob[0].sheet.apply_damage(3, "slashing")
	_force_turn(sl)
	var a := Combat.find_action(sl, "load_save")
	_ok(not a.is_empty(), "SL has load_save")
	_ok(Combat.perform(sl, a, sl), "load save performed")
	_ok(pr.sheet.hp == pr.sheet.max_hp, "protagonist hp restored")
	_ok(gob[0].sheet.hp == gob[0].sheet.max_hp, "goblin hp restored")
	_ok(Combat.why_not(sl, a) == "", "free & unlimited")
	await _stop()


func _sneak_attack() -> void:
	print("== sneak attack with ally adjacent")
	var p := _party(2)
	var z := _mob("zombie", 1, Vector3(0, 0, 1.2))
	await _start(p.values() + z)
	var sl: Combatant = p[&"sl"]
	sl.set_pos(Vector3(0, 0, 2.4))
	var found := false
	for i in 30:
		_force_turn(sl)
		z[0].sheet.hp = 22
		z[0].statuses.clear()
		log_lines.clear()
		Combat.perform(sl, Combat.find_action(sl, "attack"), z[0])
		if log_lines.any(func(l): return l.contains("d6(") and l.contains(" + ")):
			found = true
			break
	_ok(found, "sneak attack die added on a hit")
	await _stop()


func _opportunity_attack() -> void:
	print("== opportunity attack")
	var p := _party(1)
	var w := _mob("wolf", 1, Vector3(0, 0, 1.2))
	await _start(p.values() + w)
	var pr: Combatant = p[&"protagonist"]
	_force_turn(pr)
	log_lines.clear()
	Combat.move_along(pr, PackedVector3Array([pr.pos(), pr.pos() + Vector3(0, 0, -5)]))
	_ok(log_lines.any(func(l): return l.contains(TextDB.line("rules", "log_opportunity").get_slice("%s", 1).strip_edges().substr(0, 2))), "OA logged")
	_ok(w[0].reaction == 0, "wolf used reaction")
	# 撤离后不触发
	_force_turn(pr)
	pr.set_pos(Vector3(0, 0, 0.2))
	w[0].reaction = 1
	Combat.perform(pr, Combat.find_action(pr, "disengage"), pr)
	Combat.move_along(pr, PackedVector3Array([pr.pos(), pr.pos() + Vector3(0, 0, -5)]))
	_ok(w[0].reaction == 1, "disengage prevents OA")
	_ok(pr.move_left < pr.speed(), "movement spent")
	await _stop()


func _lie_down() -> void:
	print("== lie down")
	var p := _party(1)
	var g := _mob("goblin", 1, Vector3(20, 0, 0))
	await _start(p.values() + g)
	var pr: Combatant = p[&"protagonist"]
	var h: Combatant = p[&"husband"]
	_force_turn(pr)
	var ac0 := pr.ac()
	var a := Combat.find_action(pr, "lie_down")
	_ok(not a.is_empty(), "protagonist can lie down")
	_ok(Combat.find_action(h, "lie_down").is_empty(), "husband has no lie down")
	_ok(Combat.perform(pr, a, pr), "lie down")
	_ok(pr.ac() == ac0 + 2, "AC +2")
	pr.end_turn()
	_force_turn(pr)
	_ok(pr.ac() == ac0, "AC back on next turn")
	_ok(Combat.why_not(pr, a) == "why_cooldown", "cooldown one round")
	await _stop()


func _death_saves() -> void:
	print("== downed & death saves")
	var p := _party(1)
	var g := _mob("goblin", 1, Vector3(1, 0, 0))
	await _start(p.values() + g)
	var poet: Combatant = p[&"poet"]
	Combat._deal(g[0], poet, [["50", "slashing"]], false)
	_ok(poet.is_down() and poet.has_status(&"downed"), "poet downed")
	_ok(poet.is_alive(), "not dead yet")
	Combat._deal(g[0], poet, [["1", "slashing"]], true)
	_ok(poet.sheet.death_failures == 2, "crit on downed = 2 failures")
	var pr: Combatant = p[&"protagonist"]
	pr.set_pos(poet.pos() + Vector3(1, 0, 0))
	_force_turn(pr)
	_ok(Combat.perform(pr, Combat.find_action(pr, "help"), poet), "help")
	_ok(poet.sheet.hp == 1 and not poet.has_status(&"downed"), "poet back at 1 hp")
	await _stop()


var use_fireball := true


func _full_fight(fireball: bool) -> void:
	use_fireball = fireball
	print("== full autoplay fight: L3 party vs 3 goblins + 2 wolves, fireball=%s" % fireball)
	log_lines.clear()
	var p := _party(3)
	var enemies := _mob("goblin", 3, Vector3(-3, 0, 9)) + _mob("wolf", 2, Vector3(2, 0, 7))
	var ended := [false, false]
	var cb := func(won): ended[0] = true; ended[1] = won
	Combat.combat_ended.connect(cb)
	# 队伍也交给 AI（测试用）
	for c in p.values():
		c.team = &"party"
	await _start(p.values() + enemies)
	var guard := 0
	while Combat.active and guard < 400:
		guard += 1
		var c := Combat.current()
		if c and c.team == &"party":
			if c.can_act():
				await _party_autoplay(c)
			if Combat.active and Combat.current() == c:
				Combat.end_turn()
		await get_tree().process_frame
	Combat.combat_ended.disconnect(cb)
	_ok(ended[0], "combat ended (rounds %d, loops %d)" % [Combat.round_num, guard])
	print("  party won: ", ended[1])
	for l in log_lines.slice(-12):
		print("    ", l)


func _party_autoplay(c: Combatant) -> void:
	var foe: Combatant = null
	for o in Combat.combatants:
		if o.hostile_to(c) and o.is_alive() and (foe == null or c.dist_to(o) < c.dist_to(foe)):
			foe = o
	if foe == null:
		return
	if use_fireball and c.id() == &"husband" and c.actions > 0:
		var fb := Combat.find_action(c, "spell:fireball")
		if Combat.perform(c, fb, foe.pos()):
			return
	if c.dist_to(foe) > Combat.REACH:
		await CombatAI.approach(c, foe, Combat.REACH - 0.4)
	if c.dist_to(foe) <= Combat.REACH:
		Combat.perform(c, Combat.find_action(c, "attack"), foe)
	elif not Combat.find_action(c, "attack_ranged").is_empty():
		Combat.perform(c, Combat.find_action(c, "attack_ranged"), foe)


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1
