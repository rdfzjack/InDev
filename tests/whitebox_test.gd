extends Node
## 白模区和龙：不先动手、能对话、"这边还没做"然后开打、不给经验、死后平移跟着你
var fails := 0
var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/whitebox.tscn"
	add_child(main)
	await Router.level_loaded
	Game.join(Game.HUSBAND)
	await _frames(60)
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	var lead := pc.leader
	var dragon: Dragon = lvl.get_node("Dragon")
	_ok(Music.current() == &"none", "no level music in the whitebox")
	_ok(dragon != null, "a dragon")
	lead.global_position = Vector3(-22, 0.1, 2)
	await _frames(120)
	_ok(not Combat.active, "standing next to it: it doesn't attack")
	_shot("whitebox_dragon")

	print("== talk, then fight")
	var box := DialogueBox.instance
	_ok(dragon.interact() and box.visible, "click it: dialogue")
	await _frames(20)
	_shot("whitebox_dragon_talk")
	var said_not_done := false
	for i in 40:
		if not box.visible:
			break
		if box._options.get_child_count() > 0:
			for b in box._options.get_children():
				if b.text.contains("拔出武器"):
					b.pressed.emit()
					break
		else:
			if box._text.text.contains("这边还没做"):
				said_not_done = true
			box._advance()
		await _frames(4)
	_ok(said_not_done, "husband: 这边还没做。")
	await _until(func(): return Combat.active, 120)
	_ok(Combat.active and Music.current() == &"dragon", "then the fight starts, dragon music")
	var xp0 := Game.xp
	Combat.instant = true
	var dc: Combatant = dragon.combatant
	dc.sheet.hp = 0
	Combat._after_damage(null, dc, 999, false, "radiant")
	Combat._check_end()
	await _until(func(): return not Combat.active, 300)
	Combat.instant = false
	_ok(Game.xp == xp0, "no xp for the dragon")
	await get_tree().create_timer(3.0).timeout
	_ok(dragon._sliding, "corpse starts sliding")
	var p0 := dragon.global_position
	lead.global_position = Vector3(10, 0.1, 0)
	await get_tree().create_timer(3.0).timeout
	_ok(dragon.global_position.distance_to(p0) > 2.0, "it follows you (moved %.1f m)" % dragon.global_position.distance_to(p0))
	_shot("whitebox_dragon_slide")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


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
