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
	_end_turn.pressed.connect(func():
		if CombatController.instance and CombatController.instance.my_turn():
			Combat.end_turn())
	add_child(_end_turn)
	Game.selected_changed.connect(func(_id): _rebuild())
	Game.party_changed.connect(_rebuild)
	Game.leveled_up.connect(func(_l): _rebuild())
	Combat.turn_started.connect(func(_c): _rebuild.call_deferred())
	Combat.acted.connect(func(_c, _a, _t): _rebuild.call_deferred())
	Combat.combat_started.connect(func(): _rebuild.call_deferred())
	Combat.combat_ended.connect(func(_w): _rebuild.call_deferred())
	_rebuild()


## 当前要显示谁的行动：战斗中是当前回合的队员，否则是选中的角色
func _who() -> Combatant:
	var c := Combat.current()
	if Combat.active and c and c.team == &"party":
		return c
	var s := Game.sheet(Game.selected)
	return Combatant.new(s, null, &"party")


const KIND_ORDER := {"weapon": 0, "monster": 0, "spell": 1, "feature": 2, "common": 3, "custom": 4}


func _rebuild() -> void:
	var who := _who()
	_portrait.setup(who.id())
	for c in _grid.get_children():
		c.queue_free()
	var acts := Combat.actions_for(who)
	acts.sort_custom(func(a, b):
		var ka: int = KIND_ORDER.get(a["kind"], 9)
		var kb: int = KIND_ORDER.get(b["kind"], 9)
		if ka != kb:
			return ka < kb
		if a["kind"] == "spell":
			return int(Rules.spell(a["spell"]).get("level", 0)) < int(Rules.spell(b["spell"]).get("level", 0))
		return false)
	var in_combat := Combat.active and Combat.current() == who
	for i in COLS * ROWS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER.darkened(0.25), 1, 2, 2))
		b.add_theme_stylebox_override("disabled", UITheme.panel(UITheme.BG_DEEP.darkened(0.3), UITheme.BORDER.darkened(0.5), 1, 2, 2))
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		if i < acts.size():
			var a: Dictionary = acts[i]
			var key := _name_key(a)
			var icon_path := "res://assets/icons/%s.png" % key
			if ResourceLoader.exists(icon_path):
				b.icon = load(icon_path)
				b.expand_icon = true
			else:
				b.text = TextDB.line("rules", key).substr(0, 2)
				b.add_theme_font_size_override("font_size", 12)
			var why := Combat.why_not(who, a) if in_combat else ""
			var usable: bool = why == "" and (in_combat or a["id"] in ["lie_down"])
			b.disabled = not usable
			b.tooltip_text = _tooltip(a, why)
			if a.get("spell", "") != "" and who.sheet.is_bug_spell(a["spell"]):
				b.add_theme_color_override("font_color", Color(1, 0.55, 0.3))
			b.pressed.connect(_use.bind(a))
		else:
			b.disabled = true
		_grid.add_child(b)
	_end_turn.disabled = not (CombatController.instance and CombatController.instance.my_turn() != null)


func _name_key(a: Dictionary) -> String:
	if a["kind"] == "spell":
		return "spell_" + a["spell"]
	return "act_" + a["id"]


func _tooltip(a: Dictionary, why: String) -> String:
	var key := _name_key(a)
	var t := TextDB.line("rules", key)
	if a["kind"] == "spell":
		var lvl := int(Rules.spell(a["spell"]).get("level", 0))
		t += "  " + (TextDB.ui("hud_cantrip") if lvl == 0 else TextDB.ui("hud_spell_level") % lvl)
	t += "\n" + TextDB.line("rules", "cost_" + a.get("cost", "action"))
	var desc := TextDB.line("rules", key + "_desc")
	if desc != "":
		t += "\n\n" + desc
	if a["kind"] == "weapon":
		t += "\n" + TextDB.line("rules", "weapon_" + a["weapon"])
	var cd := int(a.get("cooldown", 0))
	if cd > 0:
		t += "\n\n" + TextDB.ui("hud_cooldown") % cd
	if why != "":
		t += "\n\n" + TextDB.line("rules", why)
	return t


func _use(a: Dictionary) -> void:
	if Combat.active:
		if CombatController.instance:
			CombatController.instance.select_action(a)
		_rebuild.call_deferred()
		return
	# 战斗外：只有躺着有反应
	if a["id"] == "lie_down":
		Meta.bump("lay_down")
		Bus.report(&"player_lay_down", Game.selected)
