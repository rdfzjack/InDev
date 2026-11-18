extends Node
## Dungeon 2：铁门、坏检定、触发盒比房间大、死人的回合、假宝箱、共享传说装备、尸体飞进墙里
var fails := 0
var out := ""
var logs: Array = []


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/dungeon_2.tscn"
	add_child(main)
	await Router.level_loaded
	for id in [Game.HUSBAND, Game.POET, Game.SL]:
		Game.join(id)
	await _frames(40)
	Combat.logged.connect(func(t): logs.append(t))
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	var lead := pc.leader

	print("== gate")
	Inv.add("crypt_key")
	lvl.get_node("CryptGate").interact()
	await _frames(5)
	_ok(lvl._gate == null and Game.flag(&"d2_gate_open"), "key opens the gate")

	print("== gravekeeper: broken DCs")
	var box := DialogueBox.instance
	var dice := DiceRollPanel.instance
	DialogueBox.open("res://data/dialogue/gravekeeper.dlg", "start", lvl.get_node("gravekeeper"))
	await _frames(5)
	for i in 10:
		if box._options.get_child_count() > 0:
			break
		box._advance()
		await _frames(3)
	var texts: Array = box._options.get_children().map(func(b): return b.text)
	_ok(texts.size() >= 4, "options: %s" % [texts])
	for b in box._options.get_children():
		if b.text.contains("路过"):
			b.pressed.emit()
			break
	await _frames(5)
	_ok(dice.visible and dice._dc.text == "-3", "negative DC shown (%s), still have to roll" % dice._dc.text)
	_shot("d2_negative_dc")
	dice._advance()
	await _until(func(): return dice._state == "done", 200)
	_ok(dice._res.get("success", false) or dice._res.get("natural", 0) == 1, "negative DC: success unless nat 1")
	dice._advance()
	await _frames(5)
	while box.visible:
		if box._options.get_child_count() > 0:
			var done := false
			for b in box._options.get_children():
				if b.text.contains("没有了") or b.text.contains("再见"):
					b.pressed.emit()
					done = true
					break
			if not done:
				box._options.get_child(0).pressed.emit()
		else:
			box._advance()
		await _frames(3)
		if dice.visible:
			dice._advance()
			await _until(func(): return dice._state == "done", 200)
			dice._advance()
	var str_check := DiceRollPanel.breakdown({"skill": "persuasion", "ability": "str", "dc_text": "12"}, Game.sheet(Game.HUSBAND))
	_ok(str_check["ability"] == "str", "persuasion uses strength")
	_ok(DiceRollPanel.breakdown({"skill": "insight", "ability": "", "dc_text": "{难度}"}, Game.sheet(Game.PROTAGONIST))["dc_text"] == "{难度}", "DC {难度} shown raw")

	print("== encounter bigger than the room")
	lead.global_position = Vector3(0, 0.1, 3)
	await _frames(5)
	lead.move_to(Vector3(0, 0, -2))
	await _until(func(): return Combat.active, 300)
	_ok(Combat.active, "combat starts in the corridor")
	var nearest := 999.0
	for c in Combat.combatants:
		if c.team == &"enemy":
			for p in Combat.combatants:
				if p.team == &"party":
					nearest = minf(nearest, c.dist_to(p))
	_ok(nearest > 12.0, "nobody can reach anybody (%.1f m)" % nearest)
	await _frames(20)
	_shot("d2_corridor_combat")
	# 死人的回合：杀掉带 dead_turn 的那只，让回合轮到他
	var ghost_z: Combatant = null
	for c in Combat.combatants:
		if c.team == &"enemy" and c.node.get_meta("dead_turn", false):
			ghost_z = c
	_kill(ghost_z)
	Combat.turn_index = posmod(Combat.order.find(ghost_z) - 1, Combat.order.size())
	logs.clear()
	Combat.end_turn()
	await _frames(10)
	_ok(Combat.current() == ghost_z and logs.any(func(l): return l.contains("等待")), "everyone waits for the dead zombie")
	await get_tree().create_timer(4.0).timeout
	_ok(Combat.current() != ghost_z, "then his turn is skipped")
	Combat.instant = true
	for c in Combat.combatants.duplicate():
		if c.team == &"enemy" and c.is_alive():
			_kill(c)
	await _until(func(): return not Combat.active, 300)
	Combat.instant = false
	_ok(not Combat.active, "crypt cleared")

	print("== fake chest, shared legendary")
	var chest: Interactable = lvl.get_node("Chest")
	chest.interact()
	await _frames(70)
	_ok(Inv.count("oath_ring") == 0, "first open: animation played, nothing inside")
	chest.interact()
	await _frames(40)
	_ok(Inv.count("oath_ring") == 1, "second open: ring")
	var ac0 := Game.sheet(Game.HUSBAND).ac()
	Inv.equip(Game.sheet(Game.PROTAGONIST), "oath_ring")
	_ok(Inv.count("oath_ring") == 1, "still one in the bag after equipping")
	_ok(Inventory.shared_holders("oath_ring").size() == 4, "all four wear the same instance")
	_ok(Game.sheet(Game.HUSBAND).ac() == ac0 + 2, "husband's AC +2 too")
	Game.shop_state("general")
	_ok(Inv.sell("oath_ring", 1000), "sold")
	_ok(Inventory.shared_holders("oath_ring").is_empty() and Game.sheet(Game.HUSBAND).ac() == ac0, "everyone lost it at once")
	Game.shop_state("general")["stock"].append({"id": "oath_ring", "qty": 1})
	TradeScreen.freeze_enabled = false
	var ts: TradeScreen = main.get_node("UI/HUD/TradeScreen")
	ts.open("general")
	await _frames(5)
	var shown: Array = ts._display_stock()
	_ok(shown[2] != null and shown[2]["id"] == "oath_ring", "buying it back: it's in the third slot")
	ts._on_buy(2, shown[2])
	_ok(ts._msg.text.contains("FROZEN"), "clicking it freezes")
	ts.close()

	print("== boss corpse flies into the wall")
	lead.global_position = Vector3(0, 0.1, -30)
	await _until(func(): return Combat.active, 300)
	_ok(Combat.active, "boss fight")
	var boss: Enemy = lvl.find_child("HoodedFigure", true, false)
	boss.global_position = Vector3(0, 0.1, -38.5)
	Combat.instant = true
	_kill(boss.combatant)
	await get_tree().create_timer(1.5).timeout
	var corpse: Node3D = lvl.get_node_or_null("BossCorpse")
	_ok(corpse != null and corpse.global_position.z < -42.0, "corpse behind the north wall (z %.1f)" % (corpse.global_position.z if corpse else 0.0))
	_shot("d2_corpse_wall")
	for c in Combat.combatants.duplicate():
		if c.team == &"enemy" and c.is_alive():
			_kill(c)
	await _until(func(): return not Combat.active, 300)
	Combat.instant = false
	_ok(Game.flag(&"d2_done"), "dungeon 2 done")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _kill(c: Combatant) -> void:
	if c == null:
		return
	c.sheet.hp = 0
	Combat._after_damage(null, c, 999, false, "radiant")
	Combat._check_end()


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _until(f: Callable, max_frames: int) -> void:
	for i in max_frames:
		if f.call():
			return
		await get_tree().process_frame


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
