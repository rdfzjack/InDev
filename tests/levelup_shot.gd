extends Node
## Level-up screen screenshot
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(30)
	Game.debug_xp_to_next_level()
	await _frames(5)
	LevelUpScreen.open_for(&"husband")
	await _frames(20)
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	get_viewport().get_texture().get_image().save_png(out + "/levelup.png")
	print("saved levelup; can_level=", Game.can_level(&"husband"))
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
