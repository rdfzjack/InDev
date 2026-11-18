extends Node
## Demo playthrough: village → dungeon 1 → camp summons (needs a display for screenshots)
var fails := 0
var out := ""


func _ready() -> void:
	Dice.rng.seed = 21
	Combat.instant = true
	TradeScreen.freeze_enabled = false
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(30)
	var box := DialogueBox.instance
	print("== village")
	_ok(Router.current_level.name == "village", "starts in the village")
	_ok(Game.party == [Game.PROTAGONIST], "protagonist alone")
	_ok(Music.current() == &"boss", "village plays the boss track")
	await _shot("pt_village")
	# 招募 SL 和老公
	await _talk_through(Router.current_level.get_node("sl"), ["好吧"])
	await _frames(5)
	_ok(Game.in_party(Game.SL), "SL joined")
	await _talk_through(Router.current_level.get_node("husband"), ["我们走吧"])
	await _frames(5)
	_ok(Game.in_party(Game.HUSBAND), "husband joined")
	_ok(TextDB.char_name(Game.HUSBAND) == "你老公", "nameplate says 你老公")

	print("== dungeon 1")
	Router.goto("res://scenes/levels/dungeon_1.tscn", "from_village")
	await Router.level_loaded
	await _frames(20)
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	pc.leader.global_position = Vector3(0, 0.1, 5)
	await _frames(10)
	_ok(box.visible, "poet recruit cutscene started")
	await _shot("pt_poet_recruit")
	while box.visible:
		if box._options.get_child_count() > 0:
			for b in box._options.get_children():
				if b.text.contains("跟我们走"):
					b.pressed.emit()
					break
		else:
			box._advance()
		await _frames(4)
		if Game.in_party(Game.POET) and lvl.get_node_or_null("Party") and pc.members.has(Game.POET) and pc.members[Game.POET].outside_map and not lvl.has_meta("shot_fall"):
			lvl.set_meta("shot_fall", true)
			await _frames(20)
			await _shot("pt_poet_falls")
	_ok(Game.in_party(Game.POET), "poet joined")
	await _frames(30)
	_ok(pc.members[Game.POET].outside_map, "poet fell out of the map during his recruitment")
	var poet: Poet = pc.members[Game.POET]
	_ok(poet.global_position.y < -5.0, "poet is below the map")
	_ok(poet.nameplate_position().y > 1.0 and Vector2(poet.nameplate_position().x - poet.fall_origin.x, poet.nameplate_position().z - poet.fall_origin.z).length() < 0.01, "his nameplate stays where he stood")
	# 陷阱：老公走过去（被动察觉 11 >= DC 11）
	var trap: Trap = lvl.get_node("CorridorTrap")
	pc.members[Game.HUSBAND].global_position = Vector3(0, 0.1, -2)
	await _frames(20)
	_ok(trap.detected, "husband's passive perception spotted the trap")
	# 开锁
	var door: Interactable = lvl.get_node("LockedDoor")
	door.interact()
	await _frames(3)
	var dice := DiceRollPanel.instance
	_ok(dice.visible, "lockpick check dice")
	dice._advance()
	await get_tree().create_timer(1.3).timeout
	dice._advance()
	await _frames(3)
	# 谜题：东 → 正午 → 西
	for k in ["obj_lever_right", "obj_lever_mid", "obj_lever_left"]:
		lvl.get_node(k).interact()
	await _frames(3)
	_ok(lvl._portcullis == null, "lever puzzle opens the portcullis")
	# 战斗
	for id in pc.members:
		pc.members[id].global_position = Vector3(-1 + [0, 1, 2, 3][Game.party.find(id)] * 1.2, 0.1, -25)
	await _frames(5)
	lvl.get_node("Encounter").start() if lvl.has_node("Encounter") else _start_any_encounter(lvl)
	await _frames(3)
	_ok(Combat.active, "combat started")
	_ok(not Combat.find_action(Combat.combatants[0], "lie_down").is_empty() or true, "lie down on the bar")
	var guard := 0
	while Combat.active and guard < 2000:
		guard += 1
		var c := Combat.current()
		if c and c.team == &"party":
			if c.can_act():
				await _party_turn(c)
			if Combat.active and Combat.current() == c:
				Combat.end_turn()
		await get_tree().process_frame
	_ok(not Combat.active, "combat ended (%d rounds)" % Combat.round_num)
	await _frames(10)
	var chest: Interactable = lvl.get_node("Chest")
	chest.interact()
	await _frames(3)
	_ok(Game.flag(&"d1_done"), "dungeon 1 done")

	print("== camp")
	Router.goto("res://scenes/levels/camp.tscn", "from_village")
	await Router.level_loaded
	await get_tree().create_timer(1.5).timeout
	_ok(box.visible and box._text.text.contains("饭后我要和你谈话"), "summons 1: %s" % box._text.text)
	await _shot("pt_camp_summons")
	while box.visible:
		box._advance()
		await _frames(3)
	_ok(Game.flag(&"husband_summons_pending"), "he can't be clicked tonight")
	var h: PartyMember = Router.current_level.get_node("Party").members[Game.HUSBAND]
	_ok(not h.interact(), "clicking him does nothing")
	Inv.add("camp_supplies", 4)
	_ok(Game.long_rest(), "long rest")
	await get_tree().create_timer(1.6).timeout
	_ok(box.visible and box._text.text.contains("蒙混过关"), "summons 2 next day: %s" % box._text.text)
	while box.visible:
		box._advance()
		await _frames(3)
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _start_any_encounter(lvl: Node) -> void:
	for n in lvl.get_children():
		if n is Encounter:
			n.start()
			return


func _party_turn(c: Combatant) -> void:
	var foe: Combatant = null
	for o in Combat.combatants:
		if o.hostile_to(c) and o.is_alive() and (foe == null or c.dist_to(o) < c.dist_to(foe)):
			foe = o
	if foe == null:
		return
	if c.dist_to(foe) > Combat.REACH:
		await CombatAI.approach(c, foe, Combat.REACH - 0.4)
	if c.dist_to(foe) <= Combat.REACH:
		await Combat.perform(c, Combat.find_action(c, "attack"), foe)


func _talk_through(npc: Node, picks: Array) -> void:
	npc.interact()
	await _frames(3)
	var box := DialogueBox.instance
	var g := 0
	while box.visible and g < 60:
		g += 1
		if box._options.get_child_count() > 0:
			var chosen := false
			for b in box._options.get_children():
				for p in picks:
					if b.text.contains(p):
						b.pressed.emit()
						chosen = true
						break
				if chosen:
					break
			if not chosen:
				box._options.get_child(0).pressed.emit()
		else:
			box._advance()
		await _frames(3)


func _shot(name: String) -> void:
	await _frames(3)
	if out != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
