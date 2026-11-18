class_name Inventory
extends Node
## 队伍共享背包（autoload: Inv）。金币 + 物品堆叠。装备穿在各自的角色卡上。
## 物品定义见 data/rules/items.json 的 items；基础武器护甲（longsword、leather……）也可以当物品。

signal changed

var gold := 120
## [{id, qty}]，保持获得顺序
var bag: Array = []


func _ready() -> void:
	reset()


func reset() -> void:
	gold = 120
	bag = []
	add("potion_of_healing", 2)
	add("camp_supplies", 4)


func count(id: String) -> int:
	for e in bag:
		if e["id"] == id:
			return e["qty"]
	return 0


func add(id: String, qty := 1) -> void:
	for e in bag:
		if e["id"] == id:
			e["qty"] += qty
			changed.emit()
			return
	bag.append({"id": id, "qty": qty})
	changed.emit()


func remove(id: String, qty := 1) -> bool:
	for e in bag:
		if e["id"] == id and e["qty"] >= qty:
			e["qty"] -= qty
			if e["qty"] <= 0:
				bag.erase(e)
			changed.emit()
			return true
	return false


## 物品定义；基础武器护甲自动生成定义
static func def(id: String) -> Dictionary:
	var d := Rules.item(id)
	if not d.is_empty():
		return d
	if id == "shield":
		return {"kind": "shield", "slot": "shield", "price": 10}
	if Rules.weapons.has(id) and id != "unarmed":
		var w: Dictionary = Rules.weapons[id]
		return {"kind": "weapon", "slot": "ranged" if w["kind"] == "ranged" else "main_hand", "weapon": id, "price": 10}
	if Rules.armor.has(id):
		return {"kind": "armor", "slot": "armor", "armor": id, "price": 10}
	return {}


static func display_name(id: String) -> String:
	var d := def(id)
	if d.get("no_name", false):
		return "Item_01"
	var n := TextDB.line("items", "item_" + id)
	if n == "" and Rules.weapons.has(id):
		n = TextDB.line("rules", "weapon_" + id)
	return n if n != "" else id


static func description(id: String) -> String:
	return TextDB.line("items", "item_" + id + "_desc")


static func is_equippable(id: String) -> bool:
	return def(id).get("slot", "") != ""


## 穿上；原来那件放回背包。返回 false = 不能穿
func equip(s: CharacterSheet, id: String, slot := "") -> bool:
	var d := def(id)
	if slot == "":
		slot = d.get("slot", "")
	if slot == "" or count(id) <= 0:
		return false
	if slot == "off_hand":
		var w := Rules.weapon(d.get("weapon", id))
		if not ("light" in w.get("props", [])):
			return false
		if s.equipment.get("shield", false):
			unequip(s, "shield")
	if slot == "shield" and s.equipment.get("off_hand", "") != "":
		unequip(s, "off_hand")
	unequip(s, slot)
	remove(id)
	match slot:
		"shield":
			s.equipment["shield"] = true
		"ring":
			s.equipment["ring"] = id
		"armor":
			s.equipment["armor"] = d.get("armor", id)
		_:
			s.equipment[slot] = d.get("weapon", id)
	Meta.bump("equips")
	s.hp_changed.emit()
	return true


func unequip(s: CharacterSheet, slot: String) -> void:
	var cur = s.equipment.get(slot, "")
	if slot == "shield":
		if cur:
			add("shield")
		s.equipment["shield"] = false
		return
	if cur is String and cur != "":
		add(cur)
	s.equipment[slot] = ""


func buy(id: String, price: int) -> bool:
	if gold < price:
		return false
	gold -= price
	add(id)
	Meta.bump("bought")
	return true


func sell(id: String, price: int) -> bool:
	if not remove(id):
		return false
	gold += price
	Meta.bump("sold")
	changed.emit()
	return true


func snapshot() -> Dictionary:
	return {"gold": gold, "bag": bag.duplicate(true)}


func restore(d: Dictionary) -> void:
	gold = int(d.get("gold", 0))
	bag = d.get("bag", []).duplicate(true)
	for e in bag:
		e["qty"] = int(e["qty"])
	changed.emit()
