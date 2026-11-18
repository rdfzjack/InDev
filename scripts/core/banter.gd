extends Node
## 队友吐槽系统。反应表在 data/text/banter.tsv。
##
## 每行：speaker / trigger / cond / priority / cooldown / once / zh_CN / en ...
##   trigger：故障 id，或 "type:<类型>"，或 "any"
##   cond：空 = 无条件；self = 故障出在说话人自己身上；player = 出在主角身上；
##         other = 出在别人身上；present = 说话人得在队里（默认就要求）
##   priority：高的先说；同优先级随机
##   cooldown：同一个说话人两次开口的最短间隔（秒），按行算
##   once：1 = 全游戏只说一次
##
## 每个故障最多一个人接话。之后有概率谁都不说（沉默权重）——"……"就是这么来的。

signal spoke(speaker: StringName, text: String)

## 默认沉默概率
var silence_weight := 0.3
## 任何人开口之后的全局冷却
var global_cooldown := 2.0

var _last_spoke_row: Dictionary = {}   # row index -> time
var _said_once: Dictionary = {}        # row index -> true
var _last_any := -999.0


func _ready() -> void:
	Narrator.event_done.connect(_on_event)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _on_event(ev: BugEvent) -> void:
	var t := _now()
	if t - _last_any < global_cooldown:
		return
	var sil := ev.silence if ev.silence >= 0.0 else silence_weight
	if randf() < sil:
		return
	var best: Array = []
	var best_pri := -INF
	var rows := TextDB.rows("banter")
	for i in rows.size():
		var r: Dictionary = rows[i]
		if not _matches(r, ev):
			continue
		if _said_once.has(i):
			continue
		if t - float(_last_spoke_row.get(i, -999.0)) < float(r.get("cooldown", "0")):
			continue
		var pri := float(r.get("priority", "0"))
		if pri > best_pri:
			best_pri = pri
			best = [i]
		elif pri == best_pri:
			best.append(i)
	if best.is_empty():
		return
	var idx: int = best.pick_random()
	var row: Dictionary = rows[idx]
	_last_spoke_row[idx] = t
	_last_any = t
	if row.get("once", "") == "1":
		_said_once[idx] = true
	say(StringName(row["speaker"]), TextDB.localized(row))


func _matches(r: Dictionary, ev: BugEvent) -> bool:
	var speaker := StringName(r.get("speaker", ""))
	if not Game.in_party(speaker):
		return false
	var trig: String = r.get("trigger", "")
	if trig != "any" and trig != String(ev.glitch_id) and trig != "type:" + String(ev.type):
		return false
	match r.get("cond", ""):
		"self":
			return ev.instigator == speaker
		"player":
			return ev.instigator == Game.PROTAGONIST
		"other":
			return ev.instigator != speaker
	return true


## 剧情脚本也可以直接让某人说话
func say(speaker: StringName, text: String) -> void:
	spoke.emit(speaker, text)
