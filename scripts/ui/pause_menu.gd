class_name PauseMenu
extends Control
## Esc 菜单：继续 / 存档 / 读档 / 设置 / 退出。F5 快速存档，F9 快速读档。
## 存档列表里的游玩时间是负的（每次看到都更负一点）。
## 设置里有一项是灰的，写着"暂未开放"——全游戏唯一一个用了正常措辞的地方。

static var instance: PauseMenu

var _main: VBoxContainer
var _sub: VBoxContainer
var _msg: Label


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 4, 18))
	panel.anchor_left = 0.3
	panel.anchor_right = 0.7
	panel.anchor_top = 0.18
	panel.anchor_bottom = 0.82
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	_main = VBoxContainer.new()
	v.add_child(_main)
	_sub = VBoxContainer.new()
	_sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_sub)
	_msg = Label.new()
	_msg.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(_msg)
	visible = false


func toggle() -> void:
	visible = not visible
	if visible:
		_show_main()


func _btn(parent: Control, text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _clear(c: Control) -> void:
	for x in c.get_children():
		x.queue_free()


func _show_main() -> void:
	_clear(_main)
	_clear(_sub)
	_msg.text = ""
	_btn(_main, TextDB.ui("menu_continue"), toggle)
	_btn(_main, TextDB.ui("menu_save"), _show_save, not Saves.can_save())
	_btn(_main, TextDB.ui("menu_load"), _show_load)
	_btn(_main, TextDB.ui("menu_settings"), _show_settings)
	_btn(_main, TextDB.ui("menu_quit"), func(): get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST))


static func fmt_playtime(sec: float) -> String:
	var s := int(absf(sec))
	return "-%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]


func _slot_label(slot: String) -> String:
	var d := Saves.info(slot)
	if d.is_empty():
		return TextDB.ui("menu_empty_slot") % slot
	# 越玩越负：显示的是存档时的时间，再减去从那以后又玩了多久
	var shown := -float(d.get("playtime", 0.0)) - (Meta.playtime_sec - float(d.get("playtime", 0.0)))
	return "%s    %s    %s" % [slot, d.get("time", ""), fmt_playtime(shown)]


func _show_save() -> void:
	_clear(_sub)
	for slot in ["quicksave", "slot1", "slot2", "slot3"]:
		_btn(_sub, _slot_label(slot), func():
			if Saves.save(slot):
				_msg.text = TextDB.ui("menu_saved")
				_show_save())


func _show_load() -> void:
	_clear(_sub)
	for slot in Saves.list():
		_btn(_sub, _slot_label(slot), func():
			visible = false
			Saves.load_slot(slot))
	if Saves.list().is_empty():
		var l := Label.new()
		l.text = TextDB.ui("menu_no_saves")
		_sub.add_child(l)


func _show_settings() -> void:
	_clear(_sub)
	var lang := HBoxContainer.new()
	_sub.add_child(lang)
	var l := Label.new()
	l.text = TextDB.ui("menu_language")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang.add_child(l)
	for loc in ["zh_CN", "en"]:
		var b := Button.new()
		b.text = TextDB.ui("lang_" + loc)
		b.toggle_mode = true
		b.button_pressed = TextDB.locale == loc
		b.pressed.connect(func():
			TextDB.locale = loc
			_show_settings())
		lang.add_child(b)
	# 唯一一个用了正常措辞的地方
	var grey := _btn(_sub, TextDB.ui("settings_locked"), func(): pass, true)
	grey.tooltip_text = TextDB.ui("settings_locked")


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_ESCAPE:
				if LevelUpScreen.instance and LevelUpScreen.instance.visible:
					return
				if TradeScreen.instance and TradeScreen.instance.visible:
					return
				if Combat.active and CombatController.instance and not CombatController.instance.pending.is_empty():
					return
				toggle()
				get_viewport().set_input_as_handled()
			KEY_F5:
				if Saves.save("quicksave"):
					Narrator.show_text(TextDB.ui("menu_saved"))
				get_viewport().set_input_as_handled()
			KEY_F9:
				Saves.load_slot("quicksave")
				get_viewport().set_input_as_handled()
