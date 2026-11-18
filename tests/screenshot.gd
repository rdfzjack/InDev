extends Node
## Screenshot: xvfb-run godot --path . res://tests/screenshot.tscn -- out_dir
func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(120)
	var pc: PartyController = Router.current_level.get_node("Party")
	pc.members[Game.POET].fall_out_of_map()
	await _frames(150)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	_shot(out + "/explore.png")
	Bus.report(&"player_lay_down", Game.PROTAGONIST)
	DialogueBox.open("res://data/dialogue/husband.dlg", "talk")
	await _frames(5)
	DialogueBox.instance._advance()
	await _frames(30)
	_shot(out + "/dialogue.png")
	get_tree().quit()


func _shot(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("saved ", p)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
