class_name DialogueBox
extends Control
## 对话（BG3 式电影模式）+ 对话执行器。
##
## 用法：
##   DialogueBox.open("res://data/dialogue/xxx.dlg", "start", 对话对象节点)
##   有对话对象时进入电影模式：隐藏 HUD，切到对话镜头，双方面对面。
##
## 画面：屏幕下方居中是"说话人：台词"，下面是编号选项（悬停金色 + »）。
##   字幕区只占屏幕下 30%，镜头构图保证脸在上面（见 DialogueCamera）。
##
## 选项标签：[吟游诗人] [提夫林] [游说] 【洞悉】……检定选项会弹出骰子面板。
## 主角的三个选项（我不知道 / 我没意见 / 哈哈哈）随机混进每组选项，不标注。

signal finished(script_path: String)
signal line_shown(who: String, text: String)
signal command(args: Array)
## 电影模式开关（main 用它隐藏 HUD）
signal cinematic_changed(on: bool)

static var instance: DialogueBox

const IDK_KEYS := ["idk_dont_know", "idk_no_opinion", "idk_haha"]

var _ds: DialogueScript
var _node := ""
var _pc := 0
var _waiting_click := false
var _cache: Dictionary = {}
var _pre_lines: Array = []

# 电影模式
var partner: Node3D
var partner_id: StringName = &""
var player_id: StringName = &"protagonist"
var _cam: DialogueCamera
var _prev_cam: Camera3D
var _cam_override: Dictionary = {}   # 当前 @ cam 指令
var _cinematic := false

var _shade: TextureRect
var _speaker: Label     # 说话人名字（并进字幕显示，这里只存值）
var _text: RichTextLabel
var _options: VBoxContainer
var _dice: DiceRollPanel


static func open(path: String, node := "start", with: Node3D = null) -> void:
	if instance:
		instance.start(path, node, with)


static func is_open() -> bool:
	return instance != null and instance.visible


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 底部渐暗，保证字幕可读，不加框
	_shade = TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	_shade.texture = gt
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.anchor_top = 0.6
	_shade.anchor_right = 1.0
	_shade.anchor_bottom = 1.0
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_speaker = Label.new()
	_speaker.visible = false
	add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.anchor_left = 0.14
	_text.anchor_right = 0.86
	_text.anchor_top = 0.69
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", 19)
	_text.add_theme_font_size_override("italics_font_size", 19)
	_text.add_theme_constant_override("outline_size", 4)
	_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_child(_text)
	_options = VBoxContainer.new()
	_options.anchor_left = 0.2
	_options.anchor_right = 0.84
	_options.anchor_top = 0.78
	_options.anchor_bottom = 0.99
	_options.add_theme_constant_override("separation", 1)
	add_child(_options)
	visible = false
	_bind_dice.call_deferred()


func _bind_dice() -> void:
	_dice = DiceRollPanel.instance


# ================================================================== 开始 / 结束

func start(path: String, node := "start", with: Node3D = null) -> void:
	if not _cache.has(path):
		_cache[path] = DialogueScript.load_file(path)
	_ds = _cache[path]
	if not _ds.has_node(node):
		push_error("DialogueBox: node %s not found in %s" % [node, path])
		return
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	partner = with
	partner_id = StringName(with.get("char_id")) if with and with.get("char_id") != null else &""
	player_id = Game.selected if Game.in_party(Game.selected) else Game.PROTAGONIST
	_cam_override = {}
	_pre_lines.clear()
	var crash := Meta.consume_crash()
	if crash != &"":
		var who: String = TextDB.row("ui", "crash_" + String(crash)).get("speaker", "sl")
		_pre_lines.append({"t": "line", "who": who, "text": TextDB.ui("crash_" + String(crash)), "conds": []})
	_enter_cinematic()
	_goto(node)


func _end() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_click = false
	_clear_options()
	_exit_cinematic()
	finished.emit(_ds.path if _ds else "")


func _enter_cinematic() -> void:
	_cinematic = partner != null and is_instance_valid(partner) and partner.is_inside_tree() and not Combat.active
	cinematic_changed.emit(true)
	if not _cinematic:
		return
	# 所有人站住（不然还在往队形位置走，镜头构好以后人走出画面）
	for n in get_tree().get_nodes_in_group("party") + get_tree().get_nodes_in_group("npc"):
		if n.has_method("stop"):
			n.stop()
	var player := actor_of(player_id)
	_prev_cam = partner.get_viewport().get_camera_3d()
	_cam = DialogueCamera.new()
	_cam.name = "DialogueCamera"
	partner.get_parent().add_child(_cam)
	if _prev_cam:
		_cam.global_transform = _prev_cam.global_transform
	_cam.make_current()
	# 面对面
	if player and player != partner:
		_face(player, partner)
		_face(partner, player)
		if player.has_method("stop"):
			player.stop()


func _exit_cinematic() -> void:
	cinematic_changed.emit(false)
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	_cam = null
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_prev_cam = null
	_cinematic = false


func _face(a: Node3D, b: Node3D) -> void:
	var m: Node3D = a.get("model") if a.get("model") else a
	var t := b.global_position
	t.y = m.global_position.y
	if m.global_position.distance_to(t) > 0.01:
		m.look_at(t, Vector3.UP)


## 对话对象被换掉了（NPC 入队变成队员节点），重新找
func _refresh_partner() -> void:
	if partner_id == &"":
		return
	if partner and is_instance_valid(partner) and not partner.is_queued_for_deletion():
		return
	partner = null
	for n in get_tree().get_nodes_in_group("party"):
		if n.get("char_id") == partner_id and not n.is_queued_for_deletion():
			partner = n


## 场景里某个角色 id 对应的节点
func actor_of(id) -> Node3D:
	var sid := StringName(String(id))
	_refresh_partner()
	if partner and is_instance_valid(partner) and partner.get("char_id") == sid:
		return partner
	for g in ["party", "npc"]:
		for n in get_tree().get_nodes_in_group(g):
			if n.get("char_id") == sid:
				return n
	return null


func camera() -> DialogueCamera:
	return _cam


# ================================================================== 执行

func _goto(node: String) -> void:
	if node == "END" or node == "":
		_end()
		return
	if not _ds.has_node(node):
		push_error("DialogueBox: jump to missing node %s" % node)
		_end()
		return
	_node = node
	_pc = 0
	_step()


func _ops() -> Array:
	return _ds.nodes[_node]["ops"]


func _step() -> void:
	_clear_options()
	if not _pre_lines.is_empty():
		_show_line(_pre_lines.pop_front())
		return
	var ops := _ops()
	while _pc < ops.size():
		var op: Dictionary = ops[_pc]
		match op["t"]:
			"line":
				_pc += 1
				if not _conds_ok(op.get("conds", [])):
					continue
				_show_line(op)
				return
			"goto":
				_goto(op["to"])
				return
			"cmd":
				_pc += 1
				_run_cmd(op["args"])
				if not visible:
					return
			"cam":
				_pc += 1
				_cam_override = op
			"opt":
				_show_options()
				return
	_end()


func _show_line(op: Dictionary) -> void:
	var who: String = op["who"]
	var body := TextDB.dialogue_line(op.get("id", ""), op["text"])
	var tag := _passive_tag(op.get("conds", []))
	if who == "narrator":
		_speaker.text = ""
		_text.text = "[center][i][color=#%s]%s%s[/color][/i][/center]" % [UITheme.NARRATOR.to_html(false), tag, body]
	else:
		_speaker.text = TextDB.char_name(StringName(who))
		var shown := tag + body
		# 喊话的 NPC（铁匠隔着一个太大的碰撞体说话）：字变大
		var sp := actor_of(who)
		if sp and sp.get("shout"):
			shown = "[font_size=34]%s[/font_size]" % shown
		_text.text = "[center][color=#%s]%s[/color]%s%s[/center]" % [UITheme.TEXT_GOLD.to_html(false), _speaker.text, TextDB.ui("speaker_sep"), shown]
	_frame_for(who)
	_waiting_click = true
	Voice.speak(StringName(who), body, op.get("id", ""))
	line_shown.emit(who, body)


func _show_options() -> void:
	var ops := _ops()
	var opts: Array = []
	while _pc < ops.size() and ops[_pc]["t"] == "opt":
		var o: Dictionary = ops[_pc]
		_pc += 1
		if _conds_ok(o.get("conds", [])):
			opts.append(o)
	var nd: Dictionary = _ds.nodes[_node]
	var first_to: String = opts[0]["to"] if opts.size() > 0 else ""
	if not nd["no_idk"] and Game.in_party(Game.PROTAGONIST):
		var idk_to: String = nd["idk_to"] if nd["idk_to"] != "" else first_to
		for k in IDK_KEYS:
			opts.insert(randi_range(0, opts.size()), {"text": TextDB.ui(k), "to": idk_to, "idk": k})
	_waiting_click = false
	_frame_for("__options__")
	var n := 1
	for o in opts:
		var b := Button.new()
		var label: String = o["text"] if o.has("idk") else TextDB.dialogue_line(o.get("id", ""), o["text"])
		var base_text := "%d.  %s%s" % [n, _option_tags(o.get("conds", [])), label]
		b.text = base_text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 17)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("outline_size", 3)
		b.mouse_entered.connect(func(): b.grab_focus())
		b.focus_entered.connect(func(): b.text = "» " + base_text)
		b.focus_exited.connect(func(): b.text = base_text)
		b.pressed.connect(_choose.bind(o))
		_options.add_child(b)
		n += 1
	if _options.get_child_count() > 0:
		(_options.get_child(0) as Button).grab_focus.call_deferred()


func _choose(o: Dictionary) -> void:
	if o.has("idk"):
		Meta.bump("said_" + String(o["idk"]))
		Bus.report(&"player_idk", Game.PROTAGONIST)
	_clear_options()
	var check := {}
	for c in o.get("conds", []):
		if c["type"] == "check":
			check = c
	var to: String = o["to"]
	if not check.is_empty():
		var res: Dictionary = await _dice.roll(check, Game.sheet(player_id))
		var ok: bool = res.get("success", false)
		if check.get("lie", false):
			# 旁白偶尔说反话：你没过，它夸你干得漂亮
			_pre_lines.append({"t": "line", "who": "narrator", "conds": [],
				"text": TextDB.line("narrator", "check_praise" if not ok else "check_fail_plain")})
		if not ok and o.get("to_fail", "") != "":
			to = o["to_fail"]
	if to == "":
		_step()
	else:
		_goto(to)


func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()


# ================================================================== 条件

func _player_sheet() -> CharacterSheet:
	return Game.sheet(player_id)


func _conds_ok(conds: Array) -> bool:
	for c in conds:
		if not _cond_ok(c):
			return false
	return true


func _cond_ok(c: Dictionary) -> bool:
	match c["type"]:
		"flag":
			var v := bool(Game.flag(StringName(c["flag"])))
			return not v if c.get("neg", false) else v
		"class":
			return _player_sheet().class_level(c["value"]) > 0
		"race":
			return _player_sheet().race == c["value"]
		"party":
			return Game.in_party(StringName(c["value"]))
		"passive":
			# 被动：队里任何一个人过了就算
			for id in Game.party:
				if Game.sheet(id).passive(c["skill"]) >= int(c["dc"]):
					return true
			return false
	return true


func _option_tags(conds: Array) -> String:
	var out := ""
	for c in conds:
		match c["type"]:
			"class":
				out += "[%s] " % TextDB.line("rules", "class_" + c["value"])
			"race":
				out += "[%s] " % TextDB.line("rules", "race_" + c["value"])
			"check":
				out += "[%s] " % TextDB.line("rules", "skill_" + c["skill"])
			"passive":
				out += TextDB.line("rules", "notice_" + c["skill"]) + " "
	return out


func _passive_tag(conds: Array) -> String:
	for c in conds:
		if c["type"] == "passive":
			return TextDB.line("rules", "notice_" + c["skill"]) + " "
	return ""


# ================================================================== 镜头

func _frame_for(who: String) -> void:
	if not _cinematic or _cam == null:
		return
	_refresh_partner()
	if partner == null:
		return
	var player := actor_of(player_id)
	var shot: String = _cam_override.get("shot", "auto")
	var args: Array = _cam_override.get("args", [])
	match shot:
		"speaker":
			var s := actor_of(who)
			if s:
				_cam.shot("ots", s, player if s != player else partner)
			return
		"reverse":
			_cam.shot("ots", player, partner)
			return
		"close":
			var s2 := actor_of(args[0] if args.size() > 0 else who)
			if s2:
				_cam.shot("close", s2, partner if s2 != partner else player)
			return
		"wide":
			_cam.shot("wide", player, partner)
			return
		"track":
			var tr := actor_of(args[0] if args.size() > 0 else who)
			if tr:
				_cam.track(tr)
			return
		"ots":
			var a := actor_of(args[0]) if args.size() > 0 else partner
			var b := actor_of(args[1]) if args.size() > 1 else player
			if a and b:
				_cam.shot("ots", a, b)
			return
	# auto
	if who == "narrator":
		return
	if who == "__options__":
		_cam.shot("ots", partner, player)
		return
	var sp := actor_of(who)
	if sp == null:
		return
	if sp == partner:
		_cam.shot("ots", partner, player)
	elif sp == player:
		_cam.shot("ots", player, partner)     # 反打：越过对方肩膀拍主角
	else:
		_cam.shot("close", sp, partner)        # 旁边的队友插话：特写


# ================================================================== 命令

func _run_cmd(args: Array) -> void:
	if args.is_empty():
		return
	var a1 := String(args[1]) if args.size() > 1 else ""
	match args[0]:
		"set":
			Game.set_flag(StringName(a1), true)
		"clear":
			Game.set_flag(StringName(a1), false)
		"join":
			Game.join(StringName(a1))
		"leave":
			Game.leave(StringName(a1))
		"bump":
			Meta.bump(a1)
		"glitch":
			Bus.report(StringName(a1), StringName(args[2]) if args.size() > 2 else &"")
		"narrate":
			Narrator.say(a1)
		"trade":
			_end()
			TradeScreen.open(a1)
		"xp":
			Game.award_xp(int(a1))
		"music":
			Music.play(StringName(a1))
		"fall":
			_fall_later(a1)
		"long_rest":
			Game.long_rest()
		_:
			command.emit(args)


## 入队之后队员节点下一帧才出现，等一下再让他掉下去（台词照常继续）
func _fall_later(id: String) -> void:
	for i in 3:
		await get_tree().process_frame
	var p := actor_of(id)
	if p and p.has_method("fall_out_of_map"):
		p.fall_out_of_map()


# ================================================================== 输入

func _gui_input(e: InputEvent) -> void:
	if _waiting_click and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if not visible or _dice.visible:
		return
	if _waiting_click and e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
		return
	if not _waiting_click and e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode - KEY_1
		if k >= 0 and k < _options.get_child_count():
			get_viewport().set_input_as_handled()
			(_options.get_child(k) as Button).pressed.emit()


func _advance() -> void:
	_waiting_click = false
	_step()
