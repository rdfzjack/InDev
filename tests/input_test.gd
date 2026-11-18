extends Node
## Real input events through the SubViewport into CombatController (+ screenshots)
var fails := 0
var out := ""


func _ready() -> void:
	Dice.rng.seed = 11
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(30)
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	var i := 0
	for id in pc.members:
		pc.members[id].global_position = Vector3(-2 + i * 1.5, 0.1, -8)
		i += 1
	await _frames(5)
	lvl.get_node("Encounter").start()
	await _frames(2)
	var me: Combatant = pc.members[Game.PROTAGONIST].combatant
	Combat.turn_index = Combat.order.find(me)
	me.start_turn()
	Combat.turn_started.emit(me)
	await _frames(60)   # 镜头移过去
	var hud: CombatHUD = main.get_node("UI/HUD/CombatHUD")
	var cc := CombatController.instance

	print("== hover ground")
	var ground := me.pos() + Vector3(0, 0, 4)
	var sp := hud.world_to_screen(ground)
	_move(sp)
	await _frames(3)
	_ok(cc.hover_path.size() >= 2, "path preview on ground hover")
	_ok(hud._tip.visible and hud._tip_label.text.contains(TextDB.ui("hud_move").substr(0, 2)), "tooltip shows move distance: %s" % hud._tip_label.text.replace("\n", " | "))
	await _shot("input_move")

	print("== click ground")
	var left0 := me.move_left
	_click(sp)
	await _frames(90)
	_ok(me.move_left < left0 - 2.0, "moved via click (left %.1f)" % me.move_left)

	print("== hover enemy")
	var foe: Combatant = null
	for c in Combat.combatants:
		if c.team == &"enemy" and c.is_alive() and (foe == null or me.dist_to(c) < me.dist_to(foe)):
			foe = c
	_move(hud.world_to_screen(foe.pos() + Vector3.UP * 0.9))
	await _frames(3)
	_ok(cc.hover_c == foe, "hover picks the enemy under the cursor")
	_ok(hud._tip_label.text.contains("%"), "hit chance shown: %s" % hud._tip_label.text.replace("\n", " | "))
	await _shot("input_enemy")

	print("== select spell via hotbar, area preview")
	Inv.add("alchemists_fire")
	var a := Combat.find_action(me, "item:alchemists_fire")
	cc.select_action(a)
	_move(hud.world_to_screen(foe.pos()))
	await _frames(3)
	_ok(not cc.pending.is_empty(), "targeting mode")
	await _shot("input_area")
	_right_click(hud.world_to_screen(foe.pos()))
	await _frames(2)
	_ok(cc.pending.is_empty(), "right click cancels")

	print("== space ends turn")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(3)
	_ok(Combat.current() != me, "space ended the turn")
	Combat.active = false
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p
	e.global_position = p
	Input.parse_input_event(e)


func _click(p: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = p
		e.global_position = p
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)


func _right_click(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.position = p
	e.global_position = p
	e.button_index = MOUSE_BUTTON_RIGHT
	e.pressed = true
	Input.parse_input_event(e)


func _shot(name: String) -> void:
	await _frames(4)
	if out != "":
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
