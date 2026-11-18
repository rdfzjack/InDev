class_name OverheadText
extends Control
## 队友随口说的话飘在说话人头顶（BG3 那样），几秒后淡出。
## 说话人不在场景里（或者在地图外面）就贴在他名牌的位置——诗人在地下说"哎哟"也照样显示。

const LIFETIME := 4.0
const MAX_WIDTH := 260.0

var nameplates: Nameplates
var _active: Dictionary = {}   # speaker -> Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Banter.spoke.connect(_on_spoke)
	Game.notice.connect(func(id, t): _on_spoke(id, t, Color(0.6, 0.85, 1.0)))


func _on_spoke(speaker: StringName, text: String, col := Color(1, 0.97, 0.88)) -> void:
	if _active.has(speaker) and is_instance_valid(_active[speaker]):
		_active[speaker].queue_free()
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(MAX_WIDTH, 16.0 * text.length() + 8.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("speaker", speaker)
	add_child(l)
	_active[speaker] = l
	var tw := l.create_tween()
	tw.tween_interval(LIFETIME)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		if _active.get(speaker) == l:
			_active.erase(speaker)
		l.queue_free())


func _process(_dt: float) -> void:
	for speaker in _active:
		var l: Label = _active[speaker]
		if not is_instance_valid(l):
			continue
		var p := nameplates.plate_screen_pos(speaker) if nameplates else Vector2(-1, -1)
		if p.x < 0:
			l.visible = false
			continue
		l.visible = true
		l.position = p - Vector2(l.size.x * 0.5, l.size.y + 22.0)
		l.position = l.position.clamp(Vector2(8, 8), size - l.size - Vector2(8, 8))
