class_name BanterLog
extends VBoxContainer
## 队友随口说的话。左下角，几秒后淡出。CRPG 那种走路时的 banter。

const LIFETIME := 4.5
const MAX_LINES := 4


func _ready() -> void:
	anchor_left = 0.02
	anchor_right = 0.6
	anchor_top = 0.42
	anchor_bottom = 0.64
	alignment = BoxContainer.ALIGNMENT_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Banter.spoke.connect(_on_spoke)


func _on_spoke(speaker: StringName, text: String) -> void:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", 17)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.text = "[color=#f0c870]%s[/color]%s%s" % [TextDB.char_name(speaker), TextDB.ui("speaker_sep"), text]
	add_child(l)
	while get_child_count() > MAX_LINES:
		get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
