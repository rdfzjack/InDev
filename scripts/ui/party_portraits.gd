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
		add_child(box)
		_items[id] = {"portrait": p, "bar": bar}
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
