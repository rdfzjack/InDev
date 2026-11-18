class_name ReactionPrompt
extends Control
## 反应弹窗（BG3 式）：敌人的行动触发我方反应时，战斗停下来问玩家用不用。
##   [头像色块] 名字 · 反应
##   发生了什么（"地精的攻击（15）将会命中。"）
##   反应的效果和消耗
##   [使用] [不用]       （快捷键：1 / Enter = 使用，2 / Esc = 不用）
##
## Combat._decide() 调 ask()，await 拿到 bool。

signal answered(yes: bool)

static var instance: ReactionPrompt

var _title: Label
var _what: Label
var _cost: Label
var _use: Button
var _skip: Button
var _open := false


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 2, 6, 14))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.55
	panel.anchor_bottom = 0.55
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(420, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_title = _label(v, 20, UITheme.TEXT_GOLD)
	_what = _label(v, 15, UITheme.TEXT)
	_cost = _label(v, 13, UITheme.TEXT_DIM)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	_use = _button(h, "react_use")
	_skip = _button(h, "react_skip")
	_use.pressed.connect(_answer.bind(true))
	_skip.pressed.connect(_answer.bind(false))
	visible = false


func _label(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _button(parent: Control, key: String) -> Button:
	var b := Button.new()
	b.text = TextDB.ui(key)
	b.custom_minimum_size = Vector2(120, 34)
	parent.add_child(b)
	return b


func is_open() -> bool:
	return _open


## reactor = 谁的反应；ctx = {"reaction", "attacker", "target", "total"}
func ask(reactor: Combatant, ctx: Dictionary) -> bool:
	var rid: String = ctx.get("reaction", "")
	var attacker: Combatant = ctx.get("attacker")
	var target: Combatant = ctx.get("target")
	_title.text = TextDB.ui("react_title") % [reactor.display_name(), TextDB.ui("react_name_" + rid)]
	match rid:
		"shield":
			_what.text = TextDB.ui("react_what_shield") % [attacker.display_name(), int(ctx.get("total", 0)), target.ac()]
		"cutting_words":
			_what.text = TextDB.ui("react_what_cutting_words") % [attacker.display_name(), target.display_name(), int(ctx.get("total", 0)), target.ac()]
		"hellish_rebuke":
			_what.text = TextDB.ui("react_what_hellish_rebuke") % attacker.display_name()
		"opportunity":
			_what.text = TextDB.ui("react_what_opportunity") % attacker.display_name()
		_:
			_what.text = ""
	_cost.text = TextDB.ui("react_cost_" + rid)
	_open = true
	visible = true
	_use.grab_focus()
	var yes: bool = await answered
	_open = false
	visible = false
	return yes


func _answer(yes: bool) -> void:
	if _open:
		answered.emit(yes)


func _unhandled_input(e: InputEvent) -> void:
	if not _open:
		return
	if e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.keycode == KEY_2):
		get_viewport().set_input_as_handled()
		_answer(false)
	elif e is InputEventKey and e.pressed and e.keycode == KEY_1:
		get_viewport().set_input_as_handled()
		_answer(true)
