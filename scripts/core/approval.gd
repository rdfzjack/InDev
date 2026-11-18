extends Node
## 好感度（autoload: Approval）。照 BG3 做：
##   每个队友对主角一个值，-100 到 100。对话选项、任务结果、玩家行为都会改。
##   改了就在左上角提示"某某 赞同 / 不赞同"；有些是静默的（不提示）。
##   距离规则：队友离主角太远（同一关卡里超过 DISTANCE 米）时，现场发生的事他不知道，不改。
##     （诗人掉在地图外面的时候，离得太远，他对什么都没有看法。）全局事件（任务结局、营地）不受距离限制。
##   掉到 -25、-40 各警告一次，-50 离队，不回来。
##   对话条件：[approval:poet>=20]；对话命令：$ approve poet 3 [silent]
##   事件表：data/approval.tsv（谁、对什么事、加减多少、条件、是否静默、是否只一次）
##
## 坏掉的部分（设计）：某一天长休醒来，好感度显示全乱了，不能改回去。数值乱了，但人没变：
##   乱的只是显示（display），对话条件和离队判断用的还是真实值。赞同 / 不赞同的提示照常是对的。
## 你老公：他那栏永远显示"你老公"。不受任何输入影响，不提示，不离队。

signal changed(who: StringName, delta: int, silent: bool)
signal left_party(who: StringName)

const COMPANIONS := [&"husband", &"poet", &"sl"]
const FIXED := &"husband"
const MIN := -100
const MAX := 100
const DISTANCE := 30.0
const WARN_1 := -25
const WARN_2 := -40
const LEAVE_AT := -50
## 显示用的档位（真实值落在哪一档）
const TIERS := [[81, "exceptional"], [61, "very_high"], [41, "high"], [21, "medium"], [-19, "neutral"], [-39, "low"], [-49, "very_low"], [-100, "leaving"]]

var values: Dictionary = {}
## 显示偏移（乱掉以后）
var display_offset: Dictionary = {}
var scrambled := false
var scramble_day := 4
var warned: Dictionary = {}
var _once: Dictionary = {}
var _rows: Array = []


func _ready() -> void:
	var f := FileAccess.open("res://data/approval.tsv", FileAccess.READ)
	var header: PackedStringArray = []
	while f and not f.eof_reached():
		var raw := f.get_line()
		if raw.strip_edges() == "" or raw.begins_with("#"):
			continue
		var cells := raw.split("\t")
		if header.is_empty():
			header = cells
			continue
		var r := {}
		for i in header.size():
			r[header[i].strip_edges()] = cells[i].strip_edges() if i < cells.size() else ""
		_rows.append(r)
	Bus.reported.connect(_on_bug)
	Game.rested.connect(_on_rest)
	reset()


func reset() -> void:
	values = {}
	display_offset = {}
	warned = {}
	_once = {}
	scrambled = false
	scramble_day = randi_range(3, 5)
	for id in COMPANIONS:
		values[id] = 0


func value(who: StringName) -> int:
	return int(values.get(who, 0))


## 显示给玩家看的值（乱掉以后不对）。你老公返回 null（显示"你老公"）
func display_value(who: StringName) -> Variant:
	if who == FIXED:
		return null
	return clampi(value(who) + int(display_offset.get(who, 0)), MIN, MAX)


static func tier_of(v: int) -> String:
	for t in TIERS:
		if v >= int(t[0]):
			return t[1]
	return "leaving"


func display_tier(who: StringName) -> String:
	var v = display_value(who)
	return "husband" if v == null else tier_of(int(v))


## 改好感度。source 只用于统计和调试。global = 不受距离限制
func change(who: StringName, delta: int, source := "", silent := false, global := false) -> bool:
	if delta == 0 or not (who in COMPANIONS):
		return false
	if not Game.in_party(who) or Game.flag(StringName("left_" + String(who))):
		return false
	if who == FIXED:
		Meta.bump("approval_husband_ignored")
		return false
	if not global and not _close_enough(who):
		Meta.bump("approval_out_of_range")
		return false
	var before := value(who)
	values[who] = clampi(before + delta, MIN, MAX)
	Meta.bump("approval_%s_%s" % [who, "up" if delta > 0 else "down"])
	changed.emit(who, delta, silent)
	if Bus.debug_print:
		print("[Approval] %s %+d -> %d (%s)" % [who, delta, values[who], source])
	_thresholds(who, before)
	return true


func _close_enough(who: StringName) -> bool:
	var me: Node3D = null
	var them: Node3D = null
	for n in get_tree().get_nodes_in_group("party"):
		if n.get("char_id") == Game.PROTAGONIST:
			me = n
		elif n.get("char_id") == who:
			them = n
	if me == null or them == null:
		return true   # 不在场景里（营地、过场、测试）就按在场算
	return me.global_position.distance_to(them.global_position) <= DISTANCE


func _thresholds(who: StringName, before: int) -> void:
	var v := value(who)
	if v <= LEAVE_AT and before > LEAVE_AT:
		_leave(who)
	elif v <= WARN_2 and before > WARN_2 and not warned.has(String(who) + "_2"):
		warned[String(who) + "_2"] = true
		_bark(who, "approval_warn_2_" + String(who))
	elif v <= WARN_1 and before > WARN_1 and not warned.has(String(who) + "_1"):
		warned[String(who) + "_1"] = true
		_bark(who, "approval_warn_1_" + String(who))


func _leave(who: StringName) -> void:
	_bark(who, "approval_leave_" + String(who))
	Game.set_flag(StringName("left_" + String(who)))
	Game.leave(who)
	Meta.bump("approval_left_" + String(who))
	Narrator.show_text(TextDB.line("approval", "approval_left") % TextDB.char_name(who))
	left_party.emit(who)


func _bark(who: StringName, key: String) -> void:
	var t := TextDB.line("approval", key)
	if t != "":
		Banter.say(who, t)


# ------------------------------------------------------------------ 事件表

## 剧情脚本里直接触发一个事件（表里 event 列）
func event(id: String, instigator: StringName = &"") -> void:
	for r in _rows:
		if r["event"] != id:
			continue
		if r.get("who", "") == "instigator" and instigator == &"":
			continue
		var who := instigator if r["who"] == "instigator" else StringName(r["who"])
		var key := "%s|%s|%s" % [id, who, r.get("cond", "")]
		if r.get("once", "") == "1" and _once.has(key):
			continue
		if not Cond.all(r.get("cond", "").split(",", false)):
			continue
		if change(who, int(r["delta"]), "event:" + id, r.get("silent", "") == "1", r.get("global", "") == "1"):
			_once[key] = true


func _on_bug(ev: BugEvent) -> void:
	event(String(ev.glitch_id), ev.instigator)


# ------------------------------------------------------------------ 一觉醒来全乱了

func _on_rest(kind: StringName) -> void:
	if kind != &"long" or scrambled or Game.day < scramble_day:
		return
	scrambled = true
	for id in COMPANIONS:
		if id != FIXED:
			display_offset[id] = randi_range(-90, 90)
	Meta.bump("approval_scrambled")
	Bus.report(&"approval_scrambled")


# ------------------------------------------------------------------ 存档

func snapshot() -> Dictionary:
	return {"values": values.duplicate(), "offset": display_offset.duplicate(), "scrambled": scrambled,
		"scramble_day": scramble_day, "warned": warned.duplicate(), "once": _once.duplicate()}


func restore(d: Dictionary) -> void:
	values = {}
	for k in d.get("values", {}):
		values[StringName(k)] = int(d["values"][k])
	display_offset = {}
	for k in d.get("offset", {}):
		display_offset[StringName(k)] = int(d["offset"][k])
	scrambled = bool(d.get("scrambled", false))
	scramble_day = int(d.get("scramble_day", 4))
	warned = d.get("warned", {}).duplicate()
	_once = d.get("once", {}).duplicate()
