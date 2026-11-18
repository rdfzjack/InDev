extends Node
## 规则数据（autoload: Rules）。读 data/rules/*.json。

var classes: Dictionary
var spells: Dictionary
var weapons: Dictionary
var armor: Dictionary
var monsters: Dictionary
var party: Dictionary
var races: Dictionary
var items: Dictionary
var shops: Dictionary
var chargen: Dictionary


func _ready() -> void:
	classes = _load("res://data/rules/classes.json")
	spells = _load("res://data/rules/spells.json")
	var it := _load("res://data/rules/items.json")
	weapons = it.get("weapons", {})
	armor = it.get("armor", {})
	items = it.get("items", {})
	shops = _load("res://data/rules/shops.json")
	monsters = _load("res://data/rules/monsters.json")
	party = _load("res://data/rules/party.json")
	races = _load("res://data/rules/races.json")
	chargen = _load("res://data/rules/chargen.json")


func _load(path: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(txt)
	if not (data is Dictionary):
		push_error("Rules: failed to parse %s" % path)
		return {}
	data.erase("_doc")
	return data


func spell(id: StringName) -> Dictionary:
	return spells.get(String(id), {})


func item(id: String) -> Dictionary:
	return items.get(id, {})


func weapon(id: String) -> Dictionary:
	return weapons.get(id, weapons["unarmed"])


## 熟练加值（1-4 级都是 +2，留着公式以后扩展）
static func proficiency(level: int) -> int:
	return 2 + floori((maxi(level, 1) - 1) / 4.0)
