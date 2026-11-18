class_name InventoryScreen
extends Control
## 背包（I 键）。右侧面板：金币、共享物品格子；上面是当前选中角色的装备槽。
## 点物品：能装备的装备到当前角色；能用的（药水、秘药、"炸弹"）对当前角色使用。
## 点装备槽：卸下。战斗中背包只能看，用物品走技能栏。

static var instance: InventoryScreen

const SLOTS := ["main_hand", "off_hand", "ranged", "armor", "shield", "ring"]

var _who: Label
var _slots: GridContainer
var _grid: ItemGrid
var _gold: Label


func _init() -> void:
	instance = self


static func toggle() -> void:
	if instance:
		instance.visible = not instance.visible
		if instance.visible:
			instance._refresh()


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -380
	offset_right = -10
	offset_top = 190
	offset_bottom = -170
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 3, 10))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	_who = Label.new()
	_who.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	_who.add_theme_font_size_override("font_size", 18)
	v.add_child(_who)
	_slots = GridContainer.new()
	_slots.columns = 2
	v.add_child(_slots)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	v.add_child(_gold)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	_grid = ItemGrid.new()
	_grid.price_fn = func(id): return int(Inventory.def(id).get("price", 1))
	_grid.slot_pressed.connect(_on_item)
	scroll.add_child(_grid)
	Inv.changed.connect(func(): if visible: _refresh())
	Game.selected_changed.connect(func(_id): if visible: _refresh())
	visible = false


func _refresh() -> void:
	var s := Game.sheet(Game.selected)
	_who.text = "%s  ·  %s" % [TextDB.line("items", "inv_title"), TextDB.char_name(Game.selected)]
	for c in _slots.get_children():
		c.queue_free()
	for slot in SLOTS:
		var b := Button.new()
		var cur = s.equipment.get(slot, "")
		var name := "—"
		if slot == "shield":
			name = TextDB.line("items", "item_shield") if cur else "—"
		elif cur is String and cur != "":
			name = Inventory.display_name(cur)
		b.text = "%s：%s" % [TextDB.line("items", "slot_" + slot), name] if TextDB.locale == "zh_CN" else "%s: %s" % [TextDB.line("items", "slot_" + slot), name]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.x = 170
		b.clip_text = true
		b.pressed.connect(func():
			if not Combat.active:
				Inv.unequip(s, slot)
				_refresh())
		_slots.add_child(b)
	_gold.text = TextDB.line("items", "inv_gold") % Inv.gold
	_grid.set_entries(Inv.bag.duplicate(true), 24)


func _on_item(_i: int, e) -> void:
	if e == null or Combat.active:
		return
	var id: String = e["id"]
	var s := Game.sheet(Game.selected)
	if Inventory.is_equippable(id):
		Inv.equip(s, id)
	else:
		use_outside_combat(s, id)
	_refresh()


## 战斗外使用：治疗、秘药、"炸弹"
static func use_outside_combat(s: CharacterSheet, id: String) -> bool:
	var u: Dictionary = Inventory.def(id).get("use", {})
	if u.is_empty():
		return false
	if u.has("heal"):
		if not Inv.remove(id):
			return false
		var got := s.heal(Dice.roll(u["heal"]).total)
		Meta.bump("used_" + id)
		return true
	if u.has("status"):
		if not Inv.remove(id):
			return false
		s.long_effects[u["status"]["id"]] = true
		Meta.bump("used_" + id)
		return true
	return false
