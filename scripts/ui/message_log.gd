class_name MessageLog
extends PanelContainer
## 右下角消息日志：旁白、队友、对话全部记在这里。可以往回翻。

const MAX_LINES := 200

var _text: RichTextLabel
var _count := 0


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -205
	offset_right = -10
	offset_top = -150
	offset_bottom = -10
	add_theme_stylebox_override("panel", UITheme.panel(Color(0.04, 0.035, 0.03, 0.72), UITheme.BORDER.darkened(0.3), 1, 3, 8))
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_following = true
	_text.add_theme_font_size_override("normal_font_size", 13)
	_text.add_theme_font_size_override("italics_font_size", 13)
	add_child(_text)
	Narrator.line_shown.connect(_on_narrator)
	Banter.spoke.connect(_on_speak)
	if DialogueBox.instance:
		DialogueBox.instance.line_shown.connect(_on_dialogue)


func _on_narrator(text: String) -> void:
	_append("[i][color=#%s]%s[/color][/i]" % [UITheme.NARRATOR.to_html(false), text])


func _on_speak(speaker: StringName, text: String) -> void:
	_append("[color=#%s]%s[/color]%s%s" % [UITheme.TEXT_GOLD.to_html(false), TextDB.char_name(speaker), TextDB.ui("speaker_sep"), text])


func _on_dialogue(who: String, text: String) -> void:
	if who == "narrator":
		_on_narrator(text)
	else:
		_on_speak(StringName(who), text)


func _append(bb: String) -> void:
	if _count > 0:
		_text.append_text("\n")
	_text.append_text(bb)
	_count += 1
	if _count > MAX_LINES:
		_text.remove_paragraph(0)
		_count -= 1
