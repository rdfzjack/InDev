class_name TitleScreen
extends Control
## 标题画面：继续 / 新游戏 / 读档 / 设置 / 退出。版本号永远停在 0.9x。
## 新游戏 → 角色创建 → 确认 → 默认圣骑士进村。

signal new_game_confirmed

static var instance: TitleScreen

const VERSION := "v0.97"

var _menu: VBoxContainer
var _sub: VBoxContainer
var _chargen: CharacterCreation


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.035, 0.05)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var title := Label.new()
	title.text = TextDB.ui("title_name")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	if UITheme.serif_font():
		title.add_theme_font_override("font", UITheme.serif_font())
	v.add_child(title)
	var gap := Control.new()
	gap.custom_minimum_size.y = 30
	v.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_menu.add_theme_constant_override("separation", 8)
	v.add_child(_menu)
	_sub = VBoxContainer.new()
	_sub.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sub.add_theme_constant_override("separation", 6)
	v.add_child(_sub)
	var ver := Label.new()
	ver.text = VERSION
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -80
	ver.offset_top = -30
	ver.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(ver)
	_chargen = CharacterCreation.new()
	_chargen.name = "CharacterCreation"
	_chargen.visible = false
	_chargen.confirmed.connect(_on_chargen_confirmed)
	add_child(_chargen)
	_build_menu()


func open() -> void:
	visible = true
	_chargen.visible = false
	_build_menu()


func _btn(parent: Control, text: String, cb: Callable, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 40)
	b.disabled = disabled
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _build_menu() -> void:
	for c in _menu.get_children() + _sub.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	var latest := latest_save()
	_btn(_menu, TextDB.ui("menu_continue"), func(): _load(latest), latest == "")
	_btn(_menu, TextDB.ui("title_new_game"), _new_game).name = "NewGame"
	_btn(_menu, TextDB.ui("menu_load"), _show_load, Saves.list().is_empty())
	_btn(_menu, TextDB.ui("menu_settings"), func():
		PauseMenu.instance.open_settings())
	_btn(_menu, TextDB.ui("menu_quit"), func(): get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST))


## 最近写的那个存档
static func latest_save() -> String:
	var best := ""
	var best_t := -1
	for s in Saves.list():
		var t := FileAccess.get_modified_time(Saves.path_of(s))
		if t > best_t:
			best_t = t
			best = s
	return best


func _show_load() -> void:
	for c in _sub.get_children():
		c.queue_free()
	for s in Saves.list():
		_btn(_sub, PauseMenu.instance.slot_label(s), _load.bind(s))


func _load(slot: String) -> void:
	if slot == "":
		return
	visible = false
	Saves.load_slot(slot)


func _new_game() -> void:
	Meta.bump("new_games")
	_chargen.visible = true


func _on_chargen_confirmed() -> void:
	_chargen.visible = false
	visible = false
	new_game_confirmed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _chargen.visible:
			_chargen.visible = false
