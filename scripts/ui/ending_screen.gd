class_name EndingScreen
extends Control
## 结局幻灯片 → 你找到了你的真爱 → 统计 → 关系 → 制作人员 → 返回标题。
## 从这里开始游戏就不再坏了：Bus 静音，没有任何故障，干净、完整。不解释为什么。
##
## 立绘：assets/portraits/ending_<id>.png（没有就用占位色块）。诗人那一段没有立绘，只有名字。
## 点击 / 空格 翻页。

signal finished

static var instance: EndingScreen

const SLIDES := ["protagonist", "husband", "poet", "sl", "party"]
const FADE := 0.8

var fast := false   # 测试用

var _bg: ColorRect
var _page: Control
var _hint: Label
var _waiting := false
var _step := 0
var _pages: Array[Callable] = []


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = Color(0.03, 0.03, 0.04)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_page = Control.new()
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)
	_hint = Label.new()
	_hint.text = TextDB.line("ending", "ending_continue")
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -160
	_hint.offset_top = -36
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	visible = false


func is_playing() -> bool:
	return visible


func play() -> void:
	Bus.muted = true
	Meta.bump("endings_seen")
	Meta.save()
	visible = true
	Music.play(&"ending")
	_pages.clear()
	for id in SLIDES:
		_pages.append(_slide.bind(id))
	_pages.append(_true_love)
	_pages.append(_stats)
	_pages.append(_credits)
	_step = 0
	_show()


func _show() -> void:
	for c in _page.get_children():
		c.queue_free()
	_page.modulate.a = 0.0
	(_pages[_step] as Callable).call()
	var tw := create_tween()
	tw.tween_property(_page, "modulate:a", 1.0, 0.01 if fast else FADE)
	_waiting = true
	_hint.visible = _step < _pages.size() - 1


func _advance() -> void:
	if not _waiting:
		return
	_waiting = false
	if _step >= _pages.size() - 1:
		return
	var tw := create_tween()
	tw.tween_property(_page, "modulate:a", 0.0, 0.01 if fast else FADE * 0.6)
	await tw.finished
	_step += 1
	_show()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()


# ------------------------------------------------------------------ 页面

func _label(text: String, size: int, col := Color(0.92, 0.88, 0.8), serif := true) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if serif and UITheme.serif_font():
		l.add_theme_font_override("font", UITheme.serif_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## 立绘：有图用图，没有就用角色色块 + 名字。portrait=false（诗人）：只有名字
func _portrait(id: String, big := false) -> Control:
	var path := "res://assets/portraits/ending_%s.png" % id
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		return t
	var p := PanelContainer.new()
	var col: Color = PartyController.COLORS.get(StringName(id), Color(0.3, 0.3, 0.35))
	p.add_theme_stylebox_override("panel", UITheme.panel(col.darkened(0.35), col.lightened(0.2), 2, 4, 0))
	var l := _label(TextDB.char_name(StringName(id)), 64 if big else 44, Color(1, 1, 1, 0.85))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _slide(id: String) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 70
	row.offset_right = -70
	row.offset_top = 90
	row.offset_bottom = -90
	row.add_theme_constant_override("separation", 48)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(row)
	if id == "poet":
		# 他那一段没有立绘，只有一个名字
		var name_only := _label(TextDB.char_name(&"poet"), 40)
		name_only.custom_minimum_size = Vector2(340, 0)
		name_only.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_only.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_only.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(name_only)
	elif id != "party":
		var pic := _portrait(id)
		pic.custom_minimum_size = Vector2(340, 0)
		pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(pic)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 18)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	if id != "party":
		v.add_child(_label(TextDB.char_name(StringName(id)), 30, UITheme.TEXT_GOLD))
	v.add_child(_label(TextDB.line("ending", "slide_" + id), 20))


func _true_love() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 140
	v.offset_right = -140
	v.offset_top = 40
	v.offset_bottom = -50
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(v)
	var t := _label(TextDB.line("ending", "true_love_title"), 32, UITheme.TEXT_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var pic := _portrait("husband", true)
	pic.custom_minimum_size = Vector2(0, 360)
	v.add_child(pic)
	var body := _label(TextDB.line("ending", "true_love"), 19)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)


## 统计：调试信息格式，不带情绪
static func stat_lines() -> Array:
	var out: Array = []
	var E := func(k: String) -> String: return TextDB.line("ending", k)
	out.append(E.call("stat_clicked_husband") % Meta.get_count("clicked_husband"))
	out.append(E.call("stat_clicked_husband_night") % Meta.get_count("clicked_husband_summons_night"))
	out.append(E.call("stat_lay_down") % Meta.get_count("lay_down"))
	out.append(E.call("stat_said_idk") % Meta.get_count("said_idk_dont_know"))
	out.append(E.call("stat_said_no_opinion") % Meta.get_count("said_idk_no_opinion"))
	out.append(E.call("stat_said_haha") % Meta.get_count("said_idk_haha"))
	out.append(E.call("stat_slot3") % Meta.get_count("clicked_slot3"))
	out.append(E.call("stat_loads") % Meta.get_count("loads"))
	out.append(E.call("stat_murder") % Meta.get_count("murder_plays"))
	out.append(E.call("stat_boss") % maxi(1, Meta.get_count("boss_attempts")))
	var sec := Meta.get_count("chargen_seconds")
	out.append(E.call("stat_chargen") % [sec / 60, sec % 60])
	return out


func _stats() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 120
	v.offset_right = -120
	v.offset_top = 60
	v.offset_bottom = -60
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(v)
	v.add_child(_label(TextDB.line("ending", "stats_title"), 22, UITheme.TEXT_GOLD, false))
	for s in stat_lines():
		v.add_child(_label(s, 16, Color(0.8, 0.82, 0.8), false))
	# SL 不信统计
	var loads := Meta.get_count("loads")
	var key := "stat_loads_zero" if loads == 0 else ("stat_loads_many" if loads >= 10 else "")
	if key != "":
		var sl := _label("%s%s%s" % [TextDB.char_name(&"sl"), TextDB.ui("speaker_sep"), TextDB.line("ending", key)], 16, UITheme.TEXT_GOLD)
		v.add_child(sl)
	v.add_child(_label(" ", 10))
	v.add_child(_label(TextDB.line("ending", "rel_title"), 22, UITheme.TEXT_GOLD, false))
	# 好感度是乱的；只有他那一栏不受任何输入影响
	for id in [&"poet", &"sl"]:
		var n := (hash(String(id)) + Meta.get_count("long_rests") * 37 + Meta.get_count("move_clicks")) % 101
		v.add_child(_label(TextDB.line("ending", "rel_value") % [TextDB.char_name(id), n], 16, Color(0.8, 0.82, 0.8), false))
	v.add_child(_label(TextDB.line("ending", "rel_husband"), 16, Color(0.8, 0.82, 0.8), false))


func _credits() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(v)
	var t := _label(TextDB.line("ending", "credits_title"), 34, UITheme.TEXT_GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var c := _label(TextDB.line("ending", "credits"), 17)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var back := Button.new()
	back.text = TextDB.line("ending", "ending_back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(160, 36)
	back.pressed.connect(_back_to_title)
	v.add_child(back)


func _back_to_title() -> void:
	Bus.muted = false
	visible = false
	finished.emit()
