class_name LevelUpScreen
extends Control
## 升级界面（BG3 式）。
##   左：职业列表（当前各职业等级；不满足兼职门槛的锁住，悬停看原因）
##   中：这一级得到什么（生命值、新特性、兼职熟练）
##   右：要做的选择（战斗风格 / 戏法 / 法术 / 专精 / 子职业 / 祈唤），每组显示 已选 x / y
##   下：取消 / 确认（选择没做完时确认是灰的）
## 预选来自 data/rules/party.json 的推荐路线，玩家可以改。

static var instance: LevelUpScreen

var _sheet: CharacterSheet
var _class := ""
var _step: Dictionary = {}
var _plan: Dictionary = {}

var _title: Label
var _classes: VBoxContainer
var _gains: VBoxContainer
var _choices: VBoxContainer
var _confirm: Button
var _error: Label


static func open_for(id: StringName) -> void:
	if instance and Game.can_level(id):
		instance._open(Game.sheet(id))


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 4, 16))
	panel.anchor_left = 0.06
	panel.anchor_right = 0.94
	panel.anchor_top = 0.07
	panel.anchor_bottom = 0.93
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	root.add_child(_title)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	_classes = VBoxContainer.new()
	_classes.custom_minimum_size.x = 170
	body.add_child(_classes)
	body.add_child(VSeparator.new())
	var mid_scroll := ScrollContainer.new()
	mid_scroll.custom_minimum_size.x = 260
	mid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(mid_scroll)
	_gains = VBoxContainer.new()
	_gains.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_scroll.add_child(_gains)
	body.add_child(VSeparator.new())
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	_choices = VBoxContainer.new()
	_choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices.add_theme_constant_override("separation", 8)
	right_scroll.add_child(_choices)
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 12)
	root.add_child(foot)
	_error = Label.new()
	_error.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_error)
	var cancel := Button.new()
	cancel.text = TextDB.line("rules", "lu_cancel")
	cancel.pressed.connect(close)
	foot.add_child(cancel)
	_confirm = Button.new()
	_confirm.text = TextDB.line("rules", "lu_confirm")
	_confirm.add_theme_stylebox_override("normal", UITheme.panel(Color(0.3, 0.24, 0.12, 0.9), UITheme.BORDER_BRIGHT, 1, 3, 8))
	_confirm.pressed.connect(_on_confirm)
	foot.add_child(_confirm)
	visible = false


func _open(s: CharacterSheet) -> void:
	_sheet = s
	var path: Array = Rules.party.get(String(s.id), {}).get("levels", [])
	var c := s.primary_class()
	if s.level() < path.size():
		c = path[s.level()].get("class", c)
	visible = true
	_select_class(c)


func close() -> void:
	visible = false


func _select_class(c: String) -> void:
	_class = c
	_step = LevelUp.recommended(_sheet, c)
	_plan = LevelUp.plan(_sheet, c)
	_rebuild()


func _rebuild() -> void:
	_title.text = "%s    %s" % [TextDB.char_name(_sheet.id), TextDB.line("rules", "lu_level_line") % [_sheet.level(), _sheet.level() + 1]]
	for ch in _classes.get_children():
		ch.queue_free()
	for o in LevelUp.class_options(_sheet):
		var b := Button.new()
		b.text = TextDB.line("rules", "lu_class_level") % [TextDB.line("rules", "class_" + o["class"]), o["level"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = o["class"] == _class
		b.disabled = not o["ok"]
		if not o["ok"]:
			b.tooltip_text = TextDB.line("rules", o["reason"])
		b.pressed.connect(_select_class.bind(o["class"]))
		_classes.add_child(b)
	# 中间：得到什么
	for ch in _gains.get_children():
		ch.queue_free()
	_add_label(_gains, TextDB.line("rules", "lu_hp") % _plan["hp_gain"], UITheme.TEXT_GOLD, 17)
	if not _plan["features"].is_empty():
		_add_label(_gains, TextDB.line("rules", "lu_new_features"), UITheme.TEXT_DIM, 14)
		for f in _plan["features"]:
			_add_label(_gains, TextDB.line("rules", "feat_" + f), UITheme.TEXT, 16)
			var d := TextDB.line("rules", "feat_" + f + "_desc")
			if d != "":
				_add_label(_gains, d, UITheme.TEXT_DIM, 13)
	if _plan.has("proficiencies") and not _plan["proficiencies"].is_empty():
		_add_label(_gains, TextDB.line("rules", "lu_proficiencies"), UITheme.TEXT_DIM, 14)
		_add_label(_gains, ", ".join(_plan["proficiencies"]), UITheme.TEXT, 14)
	# 右边：选择
	for ch in _choices.get_children():
		ch.queue_free()
	for ch in _plan["choices"]:
		_build_choice(ch)
	var err := LevelUp.validate(_sheet, _step)
	_confirm.disabled = err != ""
	_error.text = TextDB.line("rules", err) if err != "" else ""


func _choice_key(ch: Dictionary) -> String:
	return ch["key"] if ch["type"] == "subclass" else ch["type"]


func _build_choice(ch: Dictionary) -> void:
	var key := _choice_key(ch)
	var n: int = ch.get("count", 1)
	var single: bool = ch["type"] in ["fighting_style", "subclass"]
	var cur = _step.get(key, "" if single else [])
	var picked: Array = ([cur] if cur != "" else []) if cur is String else cur
	var head := HBoxContainer.new()
	_choices.add_child(head)
	var t := Label.new()
	t.text = TextDB.line("rules", "choice_" + key)
	t.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var cnt := Label.new()
	cnt.text = TextDB.line("rules", "lu_choose") % [picked.size(), n]
	cnt.add_theme_color_override("font_color", UITheme.TEXT if picked.size() == n else Color(1, 0.6, 0.4))
	head.add_child(cnt)
	if ch["options"].is_empty():
		_add_label(_choices, TextDB.line("rules", "lu_no_options"), UITheme.TEXT_DIM, 14)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	_choices.add_child(grid)
	for o in ch["options"]:
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = o in picked
		b.text = _option_name(ch["type"], o)
		b.tooltip_text = _option_desc(ch["type"], o)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(150, 0)
		b.add_theme_stylebox_override("pressed", UITheme.panel(Color(0.78, 0.63, 0.36, 0.3), UITheme.BORDER_BRIGHT, 1, 2, 4))
		b.toggled.connect(_toggle.bind(ch, o))
		grid.add_child(b)


func _toggle(on: bool, ch: Dictionary, o: String) -> void:
	var key := _choice_key(ch)
	var n: int = ch.get("count", 1)
	if ch["type"] in ["fighting_style", "subclass"]:
		_step[key] = o if on else ""
	else:
		var arr: Array = _step.get(key, []).duplicate()
		if on and not (o in arr):
			if arr.size() >= n:
				arr.pop_front()
			arr.append(o)
		elif not on:
			arr.erase(o)
		_step[key] = arr
	_rebuild.call_deferred()


func _option_name(type: String, o: String) -> String:
	match type:
		"cantrips", "spells":
			return TextDB.line("rules", "spell_" + o)
		"fighting_style":
			return TextDB.line("rules", "style_" + o)
		"subclass":
			return TextDB.line("rules", "sub_" + o)
		"invocations":
			return TextDB.line("rules", "inv_" + o)
		"expertise", "skills":
			return TextDB.line("rules", "skill_" + o)
	return o


func _option_desc(type: String, o: String) -> String:
	match type:
		"cantrips", "spells":
			var lvl := int(Rules.spell(o).get("level", 0))
			var head := TextDB.ui("hud_cantrip") if lvl == 0 else TextDB.ui("hud_spell_level") % lvl
			return "%s\n%s" % [head, TextDB.line("rules", "spell_" + o + "_desc")]
		"fighting_style":
			return TextDB.line("rules", "style_" + o + "_desc")
		"subclass":
			return TextDB.line("rules", "sub_" + o + "_desc")
		"invocations":
			return TextDB.line("rules", "inv_" + o + "_desc")
	return ""


func _add_label(parent: Control, text: String, col: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	parent.add_child(l)


func _on_confirm() -> void:
	if LevelUp.apply(_sheet, _step):
		Meta.bump("level_ups")
		Game.on_sheet_leveled(_sheet)
		close()


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
