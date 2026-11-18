class_name LoadingScreen
extends Control
## 加载画面。永远只有一条提示。到魔王战之前那一次，还是这一条。

var _tip: Label
var _spinner: Label
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_tip = Label.new()
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip.anchor_left = 0.1
	_tip.anchor_right = 0.9
	_tip.anchor_top = 0.82
	_tip.add_theme_font_size_override("font_size", 20)
	_tip.add_theme_color_override("font_color", Color(0.85, 0.8, 0.68))
	add_child(_tip)
	_spinner = Label.new()
	_spinner.anchor_left = 0.9
	_spinner.anchor_top = 0.92
	_spinner.add_theme_font_size_override("font_size", 18)
	add_child(_spinner)


func on_show() -> void:
	_tip.text = TextDB.ui("loading_tip")
	Meta.bump("saw_loading_tip")


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	_spinner.text = ["◐", "◓", "◑", "◒"][int(_t * 6.0) % 4]
