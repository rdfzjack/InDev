extends Node
## Screenshot: xvfb-run godot --path . res://tests/screenshot.tscn -- out.png
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	for i in 120:
		await get_tree().process_frame
	var pc: PartyController = Router.current_level.get_node("Party")
	pc.members[Game.POET].fall_out_of_map()
	for i in 90:
		await get_tree().process_frame
	var np = main.get_node("UI/Nameplates")
	print("plates size ", np.size, " children ", np.get_child_count())
	for c in np.get_children(): print("  ", c.text, " ", c.position, " ", c.size, " vis ", c.is_visible_in_tree())
	print("ui visible ", main.get_node("UI").visible, " loading ", main.get_node("UI/LoadingScreen").visible)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://shot.png"
	get_viewport().get_texture().get_image().save_png(out)
	print("saved ", out)
	get_tree().quit()
