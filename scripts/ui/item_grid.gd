class_name ItemGrid
extends GridContainer
## 物品格子（背包和交易界面共用）。每格一个按钮：图标或名字缩写 + 数量。
## 图标：res://assets/icons/items/<icon 或 id>.png；item_01 永远是粉红方块。

signal slot_pressed(index: int, entry)   # entry = {id, qty} 或 null（空格）

const SLOT := 52

var entries: Array = []
var price_fn: Callable   # (id) -> int，显示在提示里


func _ready() -> void:
	columns = 6
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)


func set_entries(list: Array, min_slots := 18) -> void:
	entries = list
	for c in get_children():
		c.queue_free()
	var n := maxi(min_slots, list.size())
	n = ceili(n / float(columns)) * columns
	for i in n:
		var e = list[i] if i < list.size() else null
		var b := Button.new()
		b.custom_minimum_size = Vector2(SLOT, SLOT)
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER.darkened(0.3), 1, 2, 2))
		b.add_theme_font_size_override("font_size", 11)
		if e != null:
			_fill(b, e)
		b.pressed.connect(func(): slot_pressed.emit(i, e))
		add_child(b)


func _fill(b: Button, e: Dictionary) -> void:
	var id: String = e["id"]
	var d := Inventory.def(id)
	if d.get("missing_icon", false):
		b.icon = _pink()
		b.expand_icon = true
	else:
		var p := "res://assets/icons/items/%s.png" % d.get("icon", id)
		if ResourceLoader.exists(p):
			b.icon = load(p)
			b.expand_icon = true
		else:
			b.text = Inventory.display_name(id).substr(0, 2)
	if int(e.get("qty", 1)) > 1:
		b.text += "\n×%d" % e["qty"]
	var tip := Inventory.display_name(id)
	var desc := Inventory.description(id)
	if desc != "":
		tip += "\n\n" + desc
	if price_fn.is_valid():
		tip += "\n\n" + TextDB.line("items", "inv_price") % price_fn.call(id)
	b.tooltip_text = tip
	var rarity: String = d.get("rarity", "common")
	if rarity == "uncommon":
		b.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, Color(0.3, 0.7, 0.35), 1, 2, 2))
	elif rarity == "rare":
		b.add_theme_stylebox_override("normal", UITheme.panel(UITheme.BG_DEEP, Color(0.35, 0.5, 0.95), 1, 2, 2))


static var _pink_tex: Texture2D


## 缺失贴图：粉红方块
static func _pink() -> Texture2D:
	if _pink_tex == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGB8)
		img.fill(Color(1, 0, 1))
		_pink_tex = ImageTexture.create_from_image(img)
	return _pink_tex
