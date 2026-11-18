extends Node
## 标题画面 → 角色创建（很认真）→ 确认 → 默认圣骑士进村，不宣布
var fails := 0
var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await _frames(20)
	var title: TitleScreen = main.title
	_ok(main.show_title and title.visible and Router.current_level == null, "starts on the title screen")
	_shot("title")
	title._menu.get_node("NewGame").pressed.emit()
	await _frames(5)
	var cg: CharacterCreation = title._chargen
	_ok(cg.visible, "new game → character creation")
	var sec0 := Meta.get_count("chargen_seconds")
	cg._show_tab("race")
	await _frames(3)
	for b in cg._content.get_children():
		if b is GridContainer:
			for o in b.get_children():
				if o.name == "Opt_tiefling":
					o.pressed.emit()
	await _frames(3)
	_ok(cg.choice["race"] == "tiefling", "picked tiefling")
	_shot("chargen_race")
	cg._show_tab("class")
	await _frames(3)
	for b in cg._content.get_children():
		if b is GridContainer:
			for o in b.get_children():
				if o.name == "Opt_wizard":
					o.pressed.emit()
	await _frames(3)
	_ok(cg.choice["class"] == "wizard" and cg.choice["plus2"] == "int", "picked wizard, recommended scores")
	_ok(cg.points_left() >= 0, "point buy within 27 (%d left)" % cg.points_left())
	cg._show_tab("abilities")
	await _frames(5)
	_shot("chargen_abilities")
	cg._show_tab("appearance")
	await _frames(5)
	_shot("chargen_appearance")
	cg.choice["name"] = "卡西乌斯"
	cg._show_tab("name")
	await get_tree().create_timer(2.2).timeout
	_ok(Meta.get_count("chargen_seconds") >= sec0 + 2, "time in character creation is counted")
	cg.get_node("Confirm").pressed.emit()
	await Router.level_loaded
	await _frames(30)
	_ok(not title.visible and Router.current_level != null, "into the game")
	var s := Game.sheet(Game.PROTAGONIST)
	_ok(s.class_level("paladin") == 1 and s.class_level("wizard") == 0, "and he's the default paladin")
	_ok(TextDB.char_name(Game.PROTAGONIST) == "圣骑士", "name didn't take")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
