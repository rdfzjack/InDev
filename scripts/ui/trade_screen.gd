class_name TradeScreen
extends Control
## 交易界面（BG3 式）：左边你的物品（点击卖出），右边商人的货（点击买入），上面双方金币。
##
## 设计：
##   商品列表第三格永远是空的。点了会真的卡死（主线程死循环），只能 alt+F4。
##   卡死前写异常退出标记，下次启动后的第一段对话开头会有人说"不是说了别点吗"。
##   库存永远不刷新。

static var instance: TradeScreen
## 测试里关掉，不然测试会被卡死
static var freeze_enabled := true

const EMPTY_SLOT_INDEX := 2

var shop_id := ""
var _shop: Dictionary = {}
var _mine: ItemGrid
var _theirs: ItemGrid
var _gold_mine: Label
var _gold_theirs: Label
var _msg: Label


static func open(id: String) -> void:
	if instance:
		instance._open(id)


func _init() -> void:
	instance = self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 4, 14))
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.1
	panel.anchor_bottom = 0.86
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := Label.new()
	title.text = TextDB.line("items", "trade_title")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	root.add_child(title)
	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 24)
	root.add_child(cols)
	var left := _column(cols, TextDB.line("items", "trade_party"))
	_gold_mine = left[0]
	_mine = left[1]
	_mine.price_fn = func(id): return sell_price(id)
	_mine.slot_pressed.connect(_on_sell)
	var right := _column(cols, "")
	_gold_theirs = right[0]
	_theirs = right[1]
	_theirs.price_fn = func(id): return buy_price(id)
	_theirs.slot_pressed.connect(_on_buy)
	var foot := HBoxContainer.new()
	root.add_child(foot)
	_msg = Label.new()
	_msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_msg.add_theme_color_override("font_color", Color(1, 0.6, 0.4))
	foot.add_child(_msg)
	var close_b := Button.new()
	close_b.text = TextDB.line("rules", "lu_cancel")
	close_b.pressed.connect(close)
	foot.add_child(close_b)
	visible = false


func _column(parent: Control, head: String) -> Array:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(v)
	var h := Label.new()
	h.text = head
	h.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	v.add_child(h)
	var g := Label.new()
	g.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	v.add_child(g)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(scroll)
	var grid := ItemGrid.new()
	scroll.add_child(grid)
	return [g, grid]


func _open(id: String) -> void:
	shop_id = id
	_shop = Game.shop_state(id)
	visible = true
	_msg.text = ""
	Meta.bump("trade_opened")
	Music.push(&"shop", &"trade")
	# 事前有人提醒过（只提醒一次）
	if not Game.flag(&"warned_slot3"):
		Game.set_flag(&"warned_slot3")
		var r := TextDB.row("ui", "trade_warning")
		Banter.say(StringName(r.get("speaker", "poet")), TextDB.localized(r))
	_refresh()


func close() -> void:
	visible = false
	Music.pop(&"trade")


func _refresh() -> void:
	_gold_mine.text = TextDB.line("items", "inv_gold") % Inv.gold
	_gold_theirs.text = TextDB.char_name(StringName(_shop.get("keeper", ""))) + "  " + TextDB.line("items", "inv_gold") % int(_shop.get("gold", 0))
	_mine.set_entries(Inv.bag.duplicate(true))
	_theirs.set_entries(_display_stock())


## 商人的货：有货的按顺序排，第三格永远插一个空格
func _display_stock() -> Array:
	var list: Array = []
	for e in _shop.get("stock", []):
		if e != null and int(e["qty"]) > 0:
			list.append(e)
	list.insert(mini(EMPTY_SLOT_INDEX, list.size()), null)
	return list


func buy_price(id: String) -> int:
	return int(Inventory.def(id).get("price", 1))


func sell_price(id: String) -> int:
	return maxi(1, int(buy_price(id) * float(_shop.get("buy_ratio", 0.5))))


func _on_buy(index: int, e) -> void:
	if e == null:
		if index == EMPTY_SLOT_INDEX:
			_freeze()
		return
	var id: String = e["id"]
	var price := buy_price(id)
	if not Inv.buy(id, price):
		_msg.text = TextDB.line("items", "trade_not_enough")
		return
	_shop["gold"] = int(_shop["gold"]) + price
	e["qty"] = int(e["qty"]) - 1
	_msg.text = ""
	_refresh()


func _on_sell(_index: int, e) -> void:
	if e == null:
		return
	var id: String = e["id"]
	var price := sell_price(id)
	if int(_shop["gold"]) < price:
		_msg.text = TextDB.line("items", "trade_keeper_out")
		return
	if not Inv.sell(id, price):
		return
	_shop["gold"] = int(_shop["gold"]) - price
	var found := false
	for s in _shop["stock"]:
		if s != null and s["id"] == id:
			s["qty"] = int(s["qty"]) + 1
			found = true
	if not found:
		_shop["stock"].append({"id": id, "qty": 1})
	_refresh()


## 第三格。真的无响应。
func _freeze() -> void:
	Meta.bump("clicked_slot3")
	Meta.arm_crash(&"shop_slot3")
	if not freeze_enabled:
		_msg.text = "FROZEN (test)"
		return
	while true:
		OS.delay_msec(1000)


func _unhandled_input(e: InputEvent) -> void:
	if visible and e.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
