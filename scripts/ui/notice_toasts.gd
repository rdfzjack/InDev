class_name NoticeToasts
extends Control
## 两种提示（BG3 式）：
##   日志：屏幕上方居中的横条，"新任务 / 日志已更新 / 任务完成 / 任务失败" + 任务名，一条一条排队，按 J 打开日志
##   好感度：左上角，"低低 赞同" / "小扬 不赞同"，几秒后淡出；静默的不显示
## 两种都同时写进消息日志。

const JOURNAL_SEC := 3.2
const APPROVAL_SEC := 3.5

var _banner: PanelContainer
var _banner_kind: Label
var _banner_title: Label
var _queue: Array = []
var _busy := false
var _approvals: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner = PanelContainer.new()
	_banner.name = "JournalBanner"
	_banner.add_theme_stylebox_override("panel", UITheme.panel(Color(0.08, 0.06, 0.04, 0.92), UITheme.BORDER_BRIGHT, 1, 4, 10))
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_top = 72
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.custom_minimum_size.x = 300
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	_banner.add_child(v)
	_banner_kind = Label.new()
	_banner_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_kind.add_theme_font_size_override("font_size", 13)
	_banner_kind.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(_banner_kind)
	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_title.add_theme_font_size_override("font_size", 18)
	_banner_title.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	v.add_child(_banner_title)
	_banner.visible = false
	_approvals = VBoxContainer.new()
	_approvals.name = "Approvals"
	_approvals.position = Vector2(84, 122)
	_approvals.add_theme_constant_override("separation", 2)
	_approvals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_approvals)
	Journal.updated.connect(_on_journal)
	Approval.changed.connect(_on_approval)


func _on_journal(qid: String, _step: String, kind: StringName) -> void:
	# 子任务的更新也提示父任务的名字（BG3 一样）
	var parent: String = Journal.defs.get(qid, {}).get("parent", "")
	var t := Journal.title(qid) if parent == "" else "%s · %s" % [Journal.title(parent), Journal.title(qid)]
	_queue.append([TextDB.line("journal", "toast_" + String(kind)), t])
	if not _busy:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_busy = false
		_banner.visible = false
		return
	_busy = true
	var it: Array = _queue.pop_front()
	_banner_kind.text = it[0]
	_banner_title.text = it[1]
	_banner.visible = true
	_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(JOURNAL_SEC)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_next)


func _on_approval(who: StringName, delta: int, silent: bool) -> void:
	if silent:
		return
	var key := "approves" if delta > 0 else "disapproves"
	var l := Label.new()
	l.text = TextDB.line("approval", key) % TextDB.char_name(who)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.55) if delta > 0 else Color(0.95, 0.5, 0.45))
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_approvals.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(APPROVAL_SEC)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
