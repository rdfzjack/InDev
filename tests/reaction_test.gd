extends Node
## 反应弹窗：敌人的行动触发我方反应 → 弹窗 → 玩家选（需要显示）
var fails := 0
var log_lines: Array = []


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(30)
	Combat.logged.connect(func(t): log_lines.append(t))
	var prompt: ReactionPrompt = main.get_node("UI/HUD/ReactionPrompt")
	var pr := Combatant.new(CharacterSheet.from_party(&"protagonist", 3), null, &"party")
	var h := Combatant.new(CharacterSheet.from_party(&"husband", 3), null, &"party")
	var gob := Combatant.new(CharacterSheet.from_monster("goblin", &"goblin_0"), null, &"enemy")
	pr.set_pos(Vector3(0, 0, 0))
	h.set_pos(Vector3(30, 0, 0))
	gob.set_pos(Vector3(1.5, 0, 0))
	var all: Array[Combatant] = [pr, h, gob]
	Combat.combatants = all
	Combat.order = all.duplicate()
	Combat.turn_index = 2
	Combat.active = true
	for c in all:
		c.start_turn()

	print("== opportunity attack: decline")
	var path := PackedVector3Array([gob.pos(), gob.pos() + Vector3(6, 0, 0)])
	var done := [false]
	var run := func():
		await Combat.move_along(gob, path)
		done[0] = true
	run.call()
	await _frames(5)
	_ok(prompt.is_open() and not done[0], "movement paused on the prompt")
	_ok(prompt._title.text.contains(TextDB.ui("react_name_opportunity")), "title: %s" % prompt._title.text)
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/reaction_prompt.png")
	_key(KEY_2)
	await _frames(5)
	_ok(done[0] and not prompt.is_open(), "declined, movement finished")
	_ok(pr.reaction == 1, "reaction not spent")
	_ok(gob.pos().distance_to(Vector3(7.5, 0, 0)) < 0.1, "goblin got away")

	print("== opportunity attack: accept (click the button)")
	gob.set_pos(Vector3(1.5, 0, 0))
	gob.move_left = 9.0
	done[0] = false
	log_lines.clear()
	run.call()
	await _frames(5)
	_ok(prompt.is_open(), "asked again")
	prompt._use.pressed.emit()
	await _frames(5)
	_ok(done[0], "movement finished")
	_ok(pr.reaction == 0, "reaction spent")
	_ok(log_lines.any(func(l): return l.contains(pr.display_name()) and l.contains("AC")), "attack rolled")

	print("== shield")
	var done2 := [null]
	var run2 := func():
		done2[0] = await Combat._try_shield(gob, h, h.ac())
	run2.call()
	await _frames(5)
	_ok(prompt.is_open() and prompt._title.text.contains(TextDB.ui("react_name_shield")), "shield prompt: %s / %s" % [prompt._title.text, prompt._what.text])
	_key(KEY_1)
	await _frames(5)
	_ok(done2[0] == true and h.has_status(&"shield_spell") and h.reaction == 0, "shield cast")

	print("== monsters and instant mode never ask")
	Combat.instant = true
	pr.reaction = 1
	gob.set_pos(Vector3(1.5, 0, 0))
	gob.move_left = 9.0
	await Combat.move_along(gob, path)
	_ok(not prompt.is_open() and pr.reaction == 0, "auto in instant mode")
	Combat.instant = false
	Combat.active = false
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _key(k: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	Input.parse_input_event(e)


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
