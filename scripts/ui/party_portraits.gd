class_name PartyPortraits
extends VBoxContainer
## 左侧竖排队伍头像 + 血条。点击选中角色（技能栏随之切换）。
##
## 你老公的头像也会点不动——和他本人一样，约谈期间点击无响应。

const W := 58
const H := 72

var _items: Dictionary = {}   # id -> {portrait, bar}


func _ready() -> void:
	anchor_left = 0.0
	anchor_top = 0.0
	offset_left = 10
	offset_top = 120
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Game.party_changed.connect(_rebuild)
	Game.selected_changed.connect(func(_id): _refresh())
	Game.hp_changed.connect(func(_id): _refresh())
	Game.xp_changed.connect(_refresh)
	Game.leveled_up.connect(func(_l): _refresh())
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_items.clear()
	for id in Game.party:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(W, H)
		p.setup(id)
		p.gui_input.connect(_on_input.bind(id))
		box.add_child(p)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(W, 6)
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = UITheme.HP
		var bg := StyleBoxFlat.new()
		bg.bg_color = UITheme.BG_DEEP
		bar.add_theme_stylebox_override("fill", fill)
		bar.add_theme_stylebox_override("background", bg)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		var st := Label.new()
		st.add_theme_font_size_override("font_size", 11)
		st.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
		st.add_theme_color_override("font_outline_color", Color.BLACK)
		st.add_theme_constant_override("outline_size", 3)
		st.custom_minimum_size.x = W
		st.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(st)
		add_child(box)
		_items[id] = {"portrait": p, "bar": bar, "status": st}
	_refresh()


func _refresh() -> void:
	for id in _items:
		var it: Dictionary = _items[id]
		it["portrait"].selected = id == Game.selected
		it["portrait"].can_level = Game.can_level(id)
		it["portrait"].tooltip_text = TextDB.char_name(id) + ("\n" + TextDB.line("rules", "lu_ready") if Game.can_level(id) else "")
		var bar: ProgressBar = it["bar"]
		var sh := Game.sheet(id)
		bar.max_value = sh.max_hp
		bar.value = sh.hp
		bar.tooltip_text = TextDB.ui("hud_hp") % [sh.hp, sh.max_hp]


func _process(_dt: float) -> void:
	# 状态（战斗中才有）：每个状态取前两个字，悬停看全名
	for id in _items:
		var lab: Label = _items[id]["status"]
		var names: Array = []
		if Combat.active:
			for c in Combat.combatants:
				if c.id() == id:
					names = c.status_names()
		lab.text = " ".join(names.map(func(n): return n.substr(0, 2)))
		lab.tooltip_text = "\n".join(names)


func _on_input(e: InputEvent, id: StringName) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if id == Game.HUSBAND:
			Meta.bump("clicked_husband")
			if Game.flag(&"husband_summons_pending"):
				return
		Game.select(id)
		# 点角标（右上角）打开升级界面
		var p: Portrait = _items[id]["portrait"]
		if p.can_level and e.position.x > p.size.x - 20 and e.position.y < 20:
			LevelUpScreen.open_for(id)
