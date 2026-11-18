class_name NarratorLog
extends Control
## 旁白。屏幕上方居中，斜体米黄色，像老式 CRPG 的叙述框。
## 一次只显示一句；新的来了就顶掉旧的。

const SEC_PER_CHAR := 0.09
const MIN_SEC := 3.0

var _label: RichTextLabel
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.12
	_label.anchor_right = 0.88
	_label.anchor_top = 0.04
	_label.add_theme_font_size_override("italics_font_size", 19)
	_label.add_theme_font_size_override("normal_font_size", 19)
	_label.add_theme_constant_override("outline_size", 5)
	_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02))
	add_child(_label)
	_label.modulate.a = 0.0
	Narrator.line_shown.connect(_on_line)


func _on_line(text: String) -> void:
	_label.text = "[center][i][color=#e6d6ac]%s[/color][/i][/center]" % text
	if _tween:
		_tween.kill()
	_label.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(maxf(MIN_SEC, text.length() * SEC_PER_CHAR))
	_tween.tween_property(_label, "modulate:a", 0.0, 1.0)
