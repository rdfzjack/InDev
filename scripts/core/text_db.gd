extends Node
## 读取 data/ 下所有 .tsv 表。
## 约定：第一行是表头；空行和以 # 开头的行忽略；单元格里的 \n 转成换行。
## 同一个 key 出现多行 = 多个变体，line() 随机取一条。
##
## 本地化：玩家可见的文字按语言分列（zh_CN / en / ...）。
## 当前语言的列为空时回退到 SOURCE_LOCALE。代码里不写任何玩家可见的字符串。

const TABLES := {
	"characters": "res://data/text/characters.tsv",
	"narrator": "res://data/text/narrator.tsv",
	"banter": "res://data/text/banter.tsv",
	"ui": "res://data/text/ui.tsv",
	"glitches": "res://data/glitches.tsv",
	"rules": "res://data/text/rules.tsv",
	"items": "res://data/text/items.tsv",
	"abilities": "res://data/abilities.tsv",
	"dialogue": "res://data/text/dialogue.tsv",
	"cutscene": "res://data/text/cutscene.tsv",
	"ending": "res://data/text/ending.tsv",
}

## 原文语言
const SOURCE_LOCALE := "zh_CN"

signal locale_changed

## 当前语言。默认原文；设置菜单里切换。翻译齐了之后再考虑跟随系统。
var locale := SOURCE_LOCALE:
	set(v):
		locale = v
		locale_changed.emit()

var _rows: Dictionary = {}       # table -> Array[Dictionary]
var _by_key: Dictionary = {}     # table -> { key: Array[Dictionary] }


func _ready() -> void:
	for t in TABLES:
		_load(t, TABLES[t])


func _load(table: String, path: String) -> void:
	var rows: Array[Dictionary] = []
	var by_key := {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("TextDB: cannot open %s" % path)
		_rows[table] = rows
		_by_key[table] = by_key
		return
	var header: PackedStringArray = []
	while not f.eof_reached():
		var raw := f.get_line()
		if raw.strip_edges() == "" or raw.begins_with("#"):
			continue
		var cells := raw.split("\t")
		if header.is_empty():
			header = cells
			continue
		var row := {}
		for i in header.size():
			var v := cells[i] if i < cells.size() else ""
			row[header[i].strip_edges()] = v.replace("\\n", "\n")
		rows.append(row)
		var key: String = row.get(header[0].strip_edges(), "")
		if not by_key.has(key):
			by_key[key] = []
		by_key[key].append(row)
	_rows[table] = rows
	_by_key[table] = by_key


func rows(table: String) -> Array[Dictionary]:
	return _rows.get(table, [] as Array[Dictionary])


func row(table: String, key: String) -> Dictionary:
	var list: Array = _by_key.get(table, {}).get(key, [])
	return list[0] if list.size() > 0 else {}


func has(table: String, key: String) -> bool:
	return _by_key.get(table, {}).has(key)


## 从一行里取当前语言的文字，空则回退到原文。
func localized(r: Dictionary) -> String:
	var s: String = r.get(locale, "")
	if s == "":
		s = r.get(SOURCE_LOCALE, "")
	return s


## 取一条文本（多变体随机），当前语言。
func line(table: String, key: String) -> String:
	var list: Array = _by_key.get(table, {}).get(key, [])
	if list.is_empty():
		return ""
	return localized(list.pick_random())


func ui(key: String) -> String:
	var s := line("ui", key)
	return s if s != "" else key


func char_name(id: StringName) -> String:
	var r := row("characters", String(id))
	var s := localized(r)
	return s if s != "" else String(id)


## 对话台词：按台词 ID 查翻译表，查不到用 .dlg 里的原文。
func dialogue_line(id: String, fallback: String) -> String:
	if id == "" or locale == SOURCE_LOCALE:
		return fallback
	var s: String = row("dialogue", id).get(locale, "")
	return s if s != "" else fallback
