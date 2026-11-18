class_name Hotbar
extends HBoxContainer
## 底部居中的技能栏：左边当前角色的圆形大头像，中间两排技能格，右边结束回合。
## 技能从 data/abilities.tsv 读，按当前选中的角色显示。
## 你老公的栏里没有【躺着】——不是灰的，是根本没有那一格。

const SLOT := 38
const COLS := 10
const ROWS := 2

var _portrait: Portrait
var _grid: GridContainer
var _end_turn: Button


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -8
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	_portrait = Portrait.new()
	_portrait.round = true
	_portrait.custom_minimum_size = Vector2(96, 96)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(_portrait)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG, UITheme.BORDER, 1, 3, 5))
	panel.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(panel)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 3)
	_grid.add_theme_constant_override("v_separation", 3)
	panel.add_child(_grid)
	_end_turn = Button.new()
	_end_turn.custom_minimum_size = Vector2(64, 64)
	_end_turn.size_flags_vertical = Control.SIZE_SHRINK_END
	_end_turn.text = TextDB.ui("hud_end_turn")
	_end_turn.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER, 1, 32, 4))
	_end_turn.disabled = true
	add_child(_end_turn)
	Game.selected_changed.connect(func(_id): _rebuild())
	Game.party_changed.connect(_rebuild)
	_rebuild()


func _abilities_for(id: StringName) -> Dictionary:
	var by_slot := {}
	for r in TextDB.rows("abilities"):
		var owner: String = r.get("owner", "")
		if owner == String(id) or owner == "all":
			by_slot[int(r.get("slot", "0"))] = r
	return by_slot


func _rebuild() -> void:
	_portrait.setup(Game.selected)
	for c in _grid.get_children():
		c.queue_free()
	var abil := _abilities_for(Game.selected)
	for i in COLS * ROWS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER.darkened(0.25), 1, 2, 2))
		b.focus_mode = Control.FOCUS_NONE
		if abil.has(i):
			var r: Dictionary = abil[i]
			var aid: String = r["id"]
			var icon_path := "res://assets/icons/%s.png" % r.get("icon", aid)
			if ResourceLoader.exists(icon_path):
				b.icon = load(icon_path)
				b.expand_icon = true
			else:
				b.text = TextDB.ui("ability_%s_name" % aid).substr(0, 2)
				b.add_theme_font_size_override("font_size", 13)
			b.tooltip_text = _tooltip(r)
			b.pressed.connect(_use.bind(r))
		else:
			b.disabled = true
		_grid.add_child(b)


func _tooltip(r: Dictionary) -> String:
	var aid: String = r["id"]
	var t := "%s\n\n%s" % [TextDB.ui("ability_%s_name" % aid), TextDB.ui("ability_%s_desc" % aid)]
	var cd := int(r.get("cooldown", "0"))
	if cd > 0:
		t += "\n\n" + TextDB.ui("hud_cooldown") % cd
	return t


func _use(r: Dictionary) -> void:
	var aid := StringName(r["id"])
	Meta.bump("ability_" + String(aid))
	var g: String = r.get("glitch", "")
	if g != "":
		Bus.report(StringName(g), Game.selected)
	Game.ability_used.emit(Game.selected, aid)
