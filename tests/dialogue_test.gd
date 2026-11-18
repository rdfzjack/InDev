extends Node
## Cinematic dialogue + checks (needs a display for screenshots)
var fails := 0
var out := ""


func _ready() -> void:
	Dice.rng.seed = 5
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(40)
	var pc: PartyController = Router.current_level.get_node("Party")
	var poet: PartyMember = pc.members[Game.POET]
	var pro: PartyMember = pc.members[Game.PROTAGONIST]
	poet.global_position = pro.global_position + Vector3(1.8, 0, -0.6)
	await _frames(5)
	var box := DialogueBox.instance
	var hud := main.get_node("UI/HUD")

	print("== click teammate -> cinematic")
	_ok(poet.interact(), "poet has a talk dialogue")
	await _frames(5)
	_ok(box.camera() != null and box.camera().current, "dialogue camera is current")
	_ok(not hud.get_node("Hotbar").visible and not hud.get_node("PartyPortraits").visible, "HUD hidden")
	var cam := box.camera()
	var f := cam.frac_of(DialogueCamera.head_of(poet))
	print("  poet head at ", f)
	_ok(f.y > 0.2 and f.y < 0.5, "speaker face in the upper part (y=%.2f)" % f.y)
	_ok(absf(f.x - DialogueCamera.OTS_FRAME_X) < 0.08, "speaker framed opposite the shoulder (x=%.2f)" % f.x)
	var fs := cam.frac_of(DialogueCamera.head_of(pro))
	_ok(cam.is_position_behind(DialogueCamera.head_of(pro)) or f.x - fs.x >= DialogueCamera.MIN_SEPARATION - 0.02, "foreground shoulder clear of the speaker's face")
	await _shot("dlg_poet")
	box._advance()
	await _frames(5)
	var labels: Array = box._options.get_children().map(func(b): return b.text)
	print("  options: ", labels)
	_ok(labels.any(func(t): return t.contains("[" + TextDB.line("rules", "skill_persuasion") + "]")), "check option tagged [游说]")
	_ok(labels.any(func(t): return t.contains("[" + TextDB.line("rules", "class_bard") + "]")) == false, "class option hidden (protagonist is not a bard)")
	await _shot("dlg_options")

	print("== reverse shot")
	for b in box._options.get_children():
		if b.text.contains("去哪"):
			b.pressed.emit()
	await _frames(3)
	box._advance()   # poet: 地图外面 -> protagonist line (reverse)
	await _frames(5)
	var fp := cam.frac_of(DialogueCamera.head_of(pro))
	print("  protagonist head at ", fp)
	_ok(fp.y > 0.2 and fp.y < 0.5 and fp.x > 0.2 and fp.x < 0.7, "reverse shot frames the protagonist")
	await _shot("dlg_reverse")
	box._advance()
	await _frames(5)
	_ok(not box.visible and hud.get_node("Hotbar").visible, "dialogue over, HUD back")

	print("== skill check with dice")
	poet.interact()
	await _frames(3)
	box._advance()
	await _frames(3)
	var check_btn: Button = null
	for b in box._options.get_children():
		if b.text.contains(TextDB.line("rules", "skill_persuasion")):
			check_btn = b
	check_btn.pressed.emit()
	await _frames(5)
	var dice: DiceRollPanel = box._dice
	_ok(dice.visible, "dice panel shown")
	_ok(dice._dc.text == "12", "DC 12 shown")
	await _shot("dlg_dice_before")
	dice._advance()   # spin
	await get_tree().create_timer(1.4).timeout
	await _shot("dlg_dice_after")
	_ok(dice._state == "done" and dice._result.text != "", "rolled: %s" % dice._result.text)
	var ok: bool = dice._res["success"]
	dice._advance()
	await _frames(5)
	var line := box._text.text
	print("  after check: ", line)
	_ok(line.contains("好吧") == ok, "branch follows result (success=%s)" % ok)
	while box.visible:
		box._advance()
		await _frames(2)

	print("== passive insight / glitched DC (SL)")
	var sl: PartyMember = pc.members[Game.SL]
	sl.global_position = pro.global_position + Vector3(-1.6, 0, -1.0)
	await _frames(3)
	sl.interact()
	await _frames(3)
	box._advance()
	await _frames(3)
	labels = box._options.get_children().map(func(b): return b.text)
	print("  options: ", labels)
	_ok(labels.any(func(t): return t.contains("[" + TextDB.line("rules", "skill_intimidation") + "]")), "DC 45 option present")
	for b in box._options.get_children():
		if b.text.contains(TextDB.line("rules", "skill_deception")):
			b.pressed.emit()
	await _frames(4)
	_ok(box._dice._dc.text == "{难度}", "unresolved DC shown raw")
	box._dice._advance()
	await get_tree().create_timer(1.4).timeout
	box._dice._advance()
	await _frames(3)
	while box.visible:
		box._advance()
		await _frames(2)
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


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
