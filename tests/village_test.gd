extends Node
## 村庄剩下的内容：被害村民（跳过是坏的）、铁匠（碰撞体太大，扔钥匙）、大祭司错别字、壮汉少女音
var fails := 0
var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	await _frames(30)
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	var lead := pc.leader
	var cut := CutscenePlayer.instance

	print("== murdered villager")
	lead.global_position = Vector3(0, 0.1, 10)
	await _frames(5)
	lead.move_to(Vector3(0, 0, 16))
	await _until(func(): return CutscenePlayer.is_playing(), 240)
	_ok(CutscenePlayer.is_playing(), "walking into his radius starts the cutscene")
	_ok(not lvl.get_node("UI") if lvl.has_node("UI") else true, "")
	_key(KEY_SPACE, true)
	await _frames(150)
	_ok(CutscenePlayer.is_playing(), "holding space does not skip")
	_ok(absf(cut._skip_progress - 0.5) < 0.01, "skip ring stuck at half (%.2f)" % cut._skip_progress)
	await _frames(40)
	_shot("village_murder")
	_key(KEY_SPACE, false)
	await _until(func(): return not CutscenePlayer.is_playing(), 1800)
	_ok(not CutscenePlayer.is_playing(), "cutscene plays to the end")
	_ok(Game.flag(&"quest_murder"), "quest started")
	_ok(cut.sticky_hint and cut._hint.visible, "skip hint stays in the corner")
	var v: Npc = lvl.get_node("murdered_villager")
	_ok(is_equal_approx(v.model.rotation.x, 0.0), "he stands up again")
	# 出去再进来：又播一遍
	lead.global_position = Vector3(0, 0.1, 9)
	await _frames(10)
	lead.move_to(Vector3(0, 0, 15))
	await _until(func(): return CutscenePlayer.is_playing(), 240)
	_ok(CutscenePlayer.is_playing(), "plays again on re-entry")
	cut.fast = true
	await _until(func(): return not CutscenePlayer.is_playing(), 600)
	cut.fast = false
	_ok(Meta.get_count("murder_plays") >= 2, "counted")

	print("== blacksmith")
	lead.global_position = Vector3(26, 0.1, 2)
	await _frames(10)
	var smith: Npc = lvl.get_node("blacksmith")
	pc._pending_interact = smith
	lead.move_to(smith.global_position)
	await _until(func(): return DialogueBox.is_open(), 400)
	_ok(DialogueBox.is_open(), "talked to him from %.1f m" % lead.global_position.distance_to(smith.global_position))
	_ok(lead.global_position.distance_to(smith.global_position) > 3.6, "couldn't get close")
	var box := DialogueBox.instance
	_ok(box._text.text.contains("font_size=34"), "he shouts (big text)")
	_shot("village_smith")
	await _pick(box, "钥匙")
	while box.visible:
		box._advance()
		await _frames(3)
	await _frames(240)
	var key: ItemPickup = lvl.get_node_or_null("Thrown_crypt_key")
	_ok(key != null, "key thrown and lying on the ground")
	if key:
		print("  key at ", key.global_position, " stuck=", key.stuck)
		_shot("village_key")
		if key.stuck:
			_ok(Game.flag(&"key_in_crack") and not key.interact(), "stuck in the crack: can't pick it up")
		else:
			_ok(key.interact() and Inv.count("crypt_key") == 1, "picked up the key")

	print("== priestess / burly man")
	DialogueBox.open("res://data/dialogue/priestess.dlg", "start", lvl.get_node("priestess"))
	await _frames(10)
	_ok(box._text.text.contains("痹佑"), "typo subtitles: %s" % box._text.text)
	_shot("village_priestess")
	while box.visible:
		if box._options.get_child_count() > 0:
			box._options.get_child(box._options.get_child_count() - 1).pressed.emit()
		else:
			box._advance()
		await _frames(3)
	_ok(Voice.voice_of(&"burly_man") == "girl", "burly man has a girl's voice")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _pick(box: DialogueBox, contains: String) -> void:
	for i in 60:
		if box._options.get_child_count() > 0:
			for b in box._options.get_children():
				if b.text.contains(contains):
					b.pressed.emit()
					return
			_ok(false, "option '%s' not found" % contains)
			return
		box._advance()
		await _frames(3)


func _key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _until(f: Callable, max_frames: int) -> void:
	for i in max_frames:
		if f.call():
			return
		await get_tree().process_frame


func _ok(c: bool, what: String) -> void:
	if what == "":
		return
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
