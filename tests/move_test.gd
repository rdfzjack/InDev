extends Node
## Out-of-combat click-to-move with real input events (needs a display)
var fails := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(60)
	var pc: PartyController = Router.current_level.get_node("Party")
	var lead := pc.leader
	var hud: CombatHUD = main.get_node("UI/HUD/CombatHUD")
	var p0 := lead.global_position
	var target := p0 + Vector3(3, 0, -3)
	var sp := hud.world_to_screen(target)
	print("leader ", p0, " click at ", sp, " dialogue_open=", DialogueBox.is_open(), " busy=", Router.is_busy(), " combat=", Combat.active)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = sp
		e.global_position = sp
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)
	await _frames(90)
	print("leader now ", lead.global_position, " target ", lead.agent.target_position, " finished=", lead.agent.is_navigation_finished())
	_ok(lead.global_position.distance_to(p0) > 1.5, "leader moved after clicking the ground")
	await _frames(120)
	var d := Vector2(lead.global_position.x - target.x, lead.global_position.z - target.z).length()
	_ok(d < 1.0, "leader arrived (%.2f m from target)" % d)
	# 再点一次远处（要跨过路缘），队友跟上
	Game.join(Game.SL)
	await _frames(10)
	var far := lead.global_position + Vector3(-6, 0, -2)
	var sp2 := hud.world_to_screen(far)
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = sp2
		e.global_position = sp2
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		Input.parse_input_event(e)
	await _frames(300)
	var d2 := Vector2(lead.global_position.x - far.x, lead.global_position.z - far.z).length()
	_ok(d2 < 1.5, "walked across the road layers (%.2f m from target)" % d2)
	var sl: PartyMember = pc.members[Game.SL]
	_ok(sl.global_position.distance_to(lead.global_position) < 4.0, "follower kept up (%.1f m)" % sl.global_position.distance_to(lead.global_position))
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/village_floor.png")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
