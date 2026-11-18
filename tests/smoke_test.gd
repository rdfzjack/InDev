extends Node
## 冒烟测试：godot --headless --path . res://tests/smoke_test.tscn
## 跑主场景，模拟一串事件，打印旁白和队友说的话，最后报告错误数。

var main: Node
var fails := 0


func _ready() -> void:
	Narrator.line_shown.connect(func(t): print("  [narrator] ", t))
	Banter.spoke.connect(func(s, t): print("  [", TextDB.char_name(s), "] ", t))
	Banter.silence_weight = 0.0
	Banter.global_cooldown = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(10)
	var pc: PartyController = Router.current_level.get_node("Party")
	_expect(pc.members.size() == 4, "party has 4 members")
	_expect(TextDB.ui("loading_tip") != "loading_tip", "loading tip exists")

	print("== poet falls")
	var poet: Poet = pc.members[Game.POET]
	var y0 := poet.global_position.y
	poet.fall_out_of_map()
	await _secs(3.0)
	_expect(poet.global_position.y < y0 - 10.0, "poet is below y=%.1f" % poet.global_position.y)
	_expect(poet.global_position.y >= Poet.STOP_Y - 0.01, "poet stops at STOP_Y")
	_expect(Game.poet_outside_map, "Game.poet_outside_map set")

	print("== trap: poet trigger proxy walks over")
	var trap: Trap = Router.current_level.get_node("Trap")
	pc.set_physics_process(false)
	poet.formation_target = trap.global_position
	await _secs(3.0)
	print('  proxy ', poet.trap_proxy.global_position, ' trap ', trap.global_position)
	pc.set_physics_process(true)
	_expect(Meta.get_count("traps_triggered") > 0, "trap sprung by poet proxy")

	print("== lay down")
	Bus.report(&"player_lay_down", Game.PROTAGONIST)
	await _secs(2.5)

	print("== dialogue: husband")
	DialogueBox.open("res://data/dialogue/husband.dlg", "talk")
	await _frames(2)
	var box := DialogueBox.instance
	_expect(box.visible, "dialogue box open")
	box._advance()
	await _frames(2)
	var labels: Array = box._options.get_children().map(func(b): return b.text)
	print("  options: ", labels)
	_expect(labels.size() == 3 + 3, "3 options + 3 idk options (asked_really unset)")
	var has_idk := labels.any(func(s): return TextDB.ui("idk_dont_know") in s)
	_expect(has_idk, "idk option injected")
	var really_text: String = TextDB.row("dialogue", "husband.talk.02").get("zh_CN", "")
	for b in box._options.get_children():
		if really_text in b.text:
			b.pressed.emit()
	await _frames(2)
	print("  line: ", box._text.text)
	_expect(box._text.text.contains(TextDB.row("dialogue", "husband.talk_really.01").get("zh_CN", "?")), "talk_really line shown")
	box._advance()
	await _frames(2)
	_expect(not box.visible, "dialogue closed")

	print("== parse all dialogue files")
	for f in DirAccess.get_files_at("res://data/dialogue"):
		var ds := DialogueScript.load_file("res://data/dialogue/" + f)
		_expect(ds.nodes.size() > 0, "%s: %d nodes" % [f, ds.nodes.size()])
		for n in ds.nodes:
			for op in ds.nodes[n]["ops"]:
				var to: String = op.get("to", "")
				if to != "" and to != "END" and not ds.has_node(to):
					_expect(false, "%s node %s jumps to missing %s" % [f, n, to])

	print("== all glitch narrator keys exist")
	for r in TextDB.rows("glitches"):
		if r["narrator"] != "":
			_expect(TextDB.has("narrator", r["narrator"]), "narrator key %s" % r["narrator"])

	print("== locale fallback")
	TextDB.locale = "en"
	_expect(TextDB.ui("loading_tip") == TextDB.row("ui", "loading_tip")["zh_CN"], "empty en falls back to zh_CN")
	_expect(TextDB.ui("speaker_sep") == ": ", "en separator")
	TextDB._by_key["dialogue"]["husband.talk.01"][0]["en"] = "What."
	_expect(TextDB.dialogue_line("husband.talk.01", "x") == "What.", "dialogue line translated by id")
	TextDB.locale = "zh_CN"

	print("== reload level, poet returns")
	Router.goto(Router.current_path)
	await Router.level_loaded
	await _frames(10)
	pc = Router.current_level.get_node("Party")
	poet = pc.members[Game.POET]
	_expect(not poet.outside_map and not Game.poet_outside_map, "poet is back")

	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _expect(ok: bool, what: String) -> void:
	print("  ", "OK  " if ok else "FAIL", " ", what)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
