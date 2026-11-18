extends Node
## Combat screenshots: xvfb-run godot --path . res://tests/combat_shot.tscn -- out_dir
func _ready() -> void:
	Dice.rng.seed = 3
	Game.party_level = 3
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(60)
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	# 队伍挪到遭遇战旁边
	var i := 0
	for id in pc.members:
		pc.members[id].global_position = Vector3(-2 + i * 1.5, 0.1, -7)
		i += 1
	await _frames(10)
	lvl.get_node("Encounter").start()
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	# 等到你老公的回合（敌人回合交给 AI）
	var guard := 0
	while Combat.active and guard < 3000:
		guard += 1
		var c := Combat.current()
		if c and c.team == &"party":
			if c.id() == &"husband":
				break
			Combat.end_turn()
		await get_tree().process_frame
	await _frames(90)
	var cc := CombatController.instance
	var h := Combat.current()
	print("current: ", h.id() if h else "none", " round ", Combat.round_num)
	var target: Combatant = null
	for o in Combat.combatants:
		if o.team == &"enemy" and o.is_alive():
			target = o
			break
	# 1) 悬停敌人，显示命中率
	cc.hover_c = target
	cc.hover_point = target.pos()
	cc.hover_valid = true
	await _frames(10)
	_shot(out + "/combat_hover.png")
	var aim := h.pos() + (target.pos() - h.pos()).limit_length(16.0)
	# 2) 选火球，预览范围
	cc.select_action(Combat.find_action(h, "spell:fireball"))
	cc.hover_c = null
	cc.hover_point = aim
	await _frames(10)
	_shot(out + "/combat_fireball.png")
	# 3) 放火球
	print("fireball: ", await Combat.perform(h, cc.pending, aim))
	cc.pending = {}
	await _frames(25)
	_shot(out + "/combat_after.png")
	get_tree().quit()


func _shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
