class_name DialogueBox
extends Control
## 对话框 + 对话执行器。
## 用法：DialogueBox.open("res://data/dialogue/xxx.dlg", "start")
##
## 主角的三个选项（我不知道 / 我没意见 / 哈哈哈）在每一组选项里随机混进去，
## 不特殊标注，语气平。节点写了 @ no_idk 就不插。

signal finished(script_path: String)
signal line_shown(who: String, text: String)
signal command(args: Array)

static var instance: DialogueBox

const IDK_KEYS := ["idk_dont_know", "idk_no_opinion", "idk_haha"]

var _ds: DialogueScript
var _node := ""
var _pc := 0
var _waiting_click := false
var _cache: Dictionary = {}
var _pre_lines: Array = []    # 开场前插入的台词（比如"不是说了别点吗"）

var _panel: PanelContainer
var _speaker: Label
var _text: RichTextLabel
var _options: VBoxContainer


static func open(path: String, node := "start") -> void:
	if instance:
		instance.start(path, node)


static func is_open() -> bool:
	return instance != null and instance.visible


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.78
	_panel.anchor_top = 0.62
	_panel.anchor_bottom = 0.97
	_panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER, 1, 3, 16))
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	_speaker = Label.new()
	_speaker.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	_speaker.add_theme_font_size_override("font_size", 20)
	vb.add_child(_speaker)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.add_theme_font_size_override("normal_font_size", 18)
	vb.add_child(_text)
	_options = VBoxContainer.new()
	vb.add_child(_options)
	visible = false


func start(path: String, node := "start") -> void:
	if not _cache.has(path):
		_cache[path] = DialogueScript.load_file(path)
	_ds = _cache[path]
	if not _ds.has_node(node):
		push_error("DialogueBox: node %s not found in %s" % [node, path])
		return
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pre_lines.clear()
	var crash := Meta.consume_crash()
	if crash != &"":
		var who: String = TextDB.row("ui", "crash_" + String(crash)).get("speaker", "sl")
		var t := TextDB.ui("crash_" + String(crash))
		_pre_lines.append({"t": "line", "who": who, "text": t})
	_goto(node)


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
				_show_line(op)
				return
			"goto":
				_goto(op["to"])
				return
			"cmd":
				_pc += 1
				_run_cmd(op["args"])
			"opt":
				_show_options()
				return
	_end()


func _show_line(op: Dictionary) -> void:
	var who: String = op["who"]
	var body := TextDB.dialogue_line(op.get("id", ""), op["text"])
	if who == "narrator":
		_speaker.text = ""
		_text.text = "[i][color=#%s]%s[/color][/i]" % [UITheme.NARRATOR.to_html(false), body]
	else:
		_speaker.text = TextDB.char_name(StringName(who))
		_text.text = body
	line_shown.emit(who, body)
	_waiting_click = true


func _show_options() -> void:
	var ops := _ops()
	var opts: Array = []
	while _pc < ops.size() and ops[_pc]["t"] == "opt":
		var o: Dictionary = ops[_pc]
		_pc += 1
		if _cond_ok(o["cond"]):
			opts.append(o)
	var nd: Dictionary = _ds.nodes[_node]
	var first_to: String = opts[0]["to"] if opts.size() > 0 else ""
	if not nd["no_idk"] and Game.in_party(Game.PROTAGONIST):
		var idk_to: String = nd["idk_to"] if nd["idk_to"] != "" else first_to
		for k in IDK_KEYS:
			var pos := randi_range(0, opts.size())
			opts.insert(pos, {"text": TextDB.ui(k), "to": idk_to, "idk": k})
	_waiting_click = false
	var n := 1
	for o in opts:
		var b := Button.new()
		var label: String = o["text"] if o.has("idk") else TextDB.dialogue_line(o.get("id", ""), o["text"])
		b.text = "%d. %s" % [n, label]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_choose.bind(o))
		_options.add_child(b)
		n += 1
	if _options.get_child_count() > 0:
		(_options.get_child(0) as Button).grab_focus.call_deferred()


func _choose(o: Dictionary) -> void:
	if o.has("idk"):
		Meta.bump("said_" + String(o["idk"]))
	_clear_options()
	var to: String = o["to"]
	if to == "":
		_step()
	else:
		_goto(to)


func _clear_options() -> void:
	for c in _options.get_children():
		c.queue_free()


func _cond_ok(cond: String) -> bool:
	if cond == "":
		return true
	if cond.begins_with("!"):
		return not Game.flag(StringName(cond.substr(1)))
	return bool(Game.flag(StringName(cond)))


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
		_:
			command.emit(args)


func _end() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_waiting_click = false
	_clear_options()
	finished.emit(_ds.path if _ds else "")


func _gui_input(e: InputEvent) -> void:
	if _waiting_click and e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if _waiting_click and (e.is_action_pressed("ui_accept")):
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
