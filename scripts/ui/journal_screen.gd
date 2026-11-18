class_name JournalScreen
extends Control
## 任务日志（J）。BG3 式：
##   左边：任务列表，按分类（主线 / 同伴 / 支线 / 其他）分组，结束了的放在最后"已结束"里。
##     当前关卡相关的任务标"此地"，有新内容的标金点。
##   右边：任务标题、结果（已完成 / 失败）、当前目标（可以追踪：小地图上标出来）、子任务和它们的目标、
##     日志条目（最新的在最上面，带天数）。
## 打开某个任务 = 已读。

static var instance: JournalScreen

var _list: VBoxContainer
var _detail: VBoxContainer
var _selected := ""


func _init() -> void:
	instance = self


static func toggle() -> void:
	if instance == null:
		return
	instance.visible = not instance.visible
	if instance.visible:
		if instance._selected == "" or not Journal.has_quest(instance._selected):
			instance._selected = Journal.tracked
		instance._refresh()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 4, 16))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = 40
	panel.offset_bottom = -40
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var head := Label.new()
	head.text = TextDB.line("journal", "journal_title")
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	v.add_child(head)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size.x = 280
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(ls)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	ls.add_child(_list)
	var sep := VSeparator.new()
	h.add_child(sep)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	h.add_child(ds)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 8)
	ds.add_child(_detail)
	Journal.updated.connect(func(_q, _s, _k): if visible: _refresh())
	visible = false


func _label(text: String, size: int, col: Color, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## 列表分组：[分类 key, [任务...]]
static func grouped() -> Array:
	var cats := Journal.categories.keys()
	cats.sort_custom(func(a, b): return int(Journal.categories[a].get("sort", 0)) < int(Journal.categories[b].get("sort", 0)))
	var out: Array = []
	var finished: Array = []
	for c in cats:
		var qs: Array = []
		for qid in Journal.quests:
			if Journal.defs[qid].get("parent", "") != "":
				continue
			if Journal.defs[qid].get("category", "other") != c:
				continue
			if Journal.is_active(qid):
				qs.append(qid)
			elif not finished.has(qid):
				finished.append(qid)
		qs.sort_custom(func(a, b): return int(Journal.quests[a]["order"]) > int(Journal.quests[b]["order"]))
		if qs.size() > 0:
			out.append(["cat_" + c, qs])
	finished.sort_custom(func(a, b): return int(Journal.quests[a]["order"]) > int(Journal.quests[b]["order"]))
	if finished.size() > 0:
		out.append(["cat_finished", finished])
	return out


static func is_here(qid: String) -> bool:
	return Router.current_level != null and String(Router.current_level.name) in Journal.defs[qid].get("areas", [])


func _refresh() -> void:
	for c in _list.get_children() + _detail.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	var groups := grouped()
	if groups.is_empty():
		_list.add_child(_label(TextDB.line("journal", "journal_empty"), 15, UITheme.TEXT_DIM))
		return
	if _selected == "" or not Journal.has_quest(_selected) or Journal.defs[_selected].get("parent", "") != "":
		_selected = groups[0][1][0]
	for g in groups:
		_list.add_child(_label(TextDB.line("journal", g[0]), 14, UITheme.TEXT_DIM, false))
		for qid in g[1]:
			var b := Button.new()
			b.name = "Q_" + qid
			var mark := "● " if Journal.quests[qid].get("unread", false) else ""
			var here := "   " + TextDB.line("journal", "journal_here") if is_here(qid) and Journal.is_active(qid) else ""
			b.text = "%s%s%s" % [mark, Journal.title(qid), here]
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.button_pressed = qid == _selected
			if not Journal.is_active(qid):
				b.add_theme_color_override("font_color", UITheme.TEXT_DIM)
			b.pressed.connect(func():
				_selected = qid
				_refresh())
			_list.add_child(b)
	_show(_selected)


func _show(qid: String) -> void:
	Journal.mark_read(qid)
	for sub in Journal.subquests(qid):
		Journal.mark_read(sub)
	Journal.read_changed.emit()
	var top := HBoxContainer.new()
	_detail.add_child(top)
	var t := _label(Journal.title(qid), 22, UITheme.TEXT_GOLD, false)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var st := Journal.state(qid)
	if st == "active":
		var tr := Button.new()
		tr.name = "Track"
		tr.toggle_mode = true
		tr.button_pressed = Journal.tracked == qid
		tr.text = TextDB.line("journal", "journal_tracking" if Journal.tracked == qid else "journal_track")
		tr.pressed.connect(func():
			Journal.track(qid if Journal.tracked != qid else "")
			_refresh())
		top.add_child(tr)
	else:
		top.add_child(_label(TextDB.line("journal", "journal_" + st), 16, Color(0.55, 0.85, 0.5) if st == "completed" else Color(0.9, 0.45, 0.4), false))
	_objective_box(qid)
	for sub in Journal.subquests(qid):
		var sv := VBoxContainer.new()
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 18)
		pad.add_child(sv)
		_detail.add_child(pad)
		var sst := Journal.state(sub)
		var tag := "" if sst == "active" else "（%s）" % TextDB.line("journal", "journal_" + sst)
		sv.add_child(_label("%s%s" % [Journal.title(sub), tag], 16, UITheme.TEXT_GOLD if sst == "active" else UITheme.TEXT_DIM))
		if sst == "active":
			var o := Journal.objective(sub)
			if o != "" and not Journal.is_completion(sub, o):
				sv.add_child(_label("◆ " + Journal.objective_text(sub, o), 15, UITheme.TEXT))
		for e in Journal.entries(sub):
			sv.add_child(_entry(e))
	_detail.add_child(HSeparator.new())
	for e in Journal.entries(qid):
		_detail.add_child(_entry(e))


func _objective_box(qid: String) -> void:
	if not Journal.is_active(qid):
		return
	var o := Journal.objective(qid)
	if o == "" or Journal.is_completion(qid, o):
		return
	var box := PanelContainer.new()
	box.name = "Objective"
	box.add_theme_stylebox_override("panel", UITheme.panel(Color(0.18, 0.14, 0.08, 0.9), UITheme.BORDER, 1, 4, 10))
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_child(_label(TextDB.line("journal", "journal_objective"), 13, UITheme.TEXT_DIM, false))
	v.add_child(_label(Journal.objective_text(qid, o), 17, UITheme.TEXT))
	_detail.add_child(box)


func _entry(e: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	if int(e["day"]) > 0:
		v.add_child(_label(TextDB.line("journal", "journal_day") % int(e["day"]), 12, UITheme.TEXT_DIM, false))
	v.add_child(_label(e["text"], 16, UITheme.TEXT))
	return v


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		visible = false
