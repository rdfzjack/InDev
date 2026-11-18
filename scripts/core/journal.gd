extends Node
## 任务日志（autoload: Journal）。照 BG3 的结构做：
##
##   分类（category）→ 任务（quest）→ 子任务（parent）→ 目标（objective）→ 步骤（step）
##
##   步骤 = 刚刚发生了什么（过去时，日志里的一条）。目标 = 接下来该做什么（现在时）。
##   目标不能直接解锁：任务当前的目标 = 已解锁步骤所指向的目标里优先级最高的那个。
##   完成目标（completion）优先级最高，本身不显示；只显示关闭任务的那一步。
##
## 步骤怎么解锁（对应 BG3 的 DB_QuestDef_State / DB_QuestDef_LevelLoaded / QRY_QuestDef_BlockQuestUpdate）：
##   when    条件全部满足就自动解锁（剧情标记变化、关卡加载、入队、物品变化时重新检查）
##   block   任何一条满足就不解锁（一次性的例外）
##   after   必须先解锁过这些步骤
##   不写 when 的步骤只能由脚本 / 对话（$ quest <任务> <步骤>）解锁
## 步骤的任务操作（BG3 的 Add/Close Quest）：
##   quest_op: "" 普通更新 / "add" 加入任务并记这一条 / "add_only" 只加入任务不记这一条 / "close" 关闭
##   result: 关闭时是 "completed" 还是 "failed"
## 网状叙事：同一个任务可以有多个互斥的分支步骤（用 block / after 区分），各自指向不同的目标，
##   也可以有多个不同的关闭步骤（不同结局）。关闭以后任务不再更新。
## 每个解锁的步骤自动设一个剧情标记 q_<任务>_<步骤>，对话里可以直接当条件用。
## 奖励：xp、gold、approval（好感度）。
## 地图标记：挂在目标上（level + node）。被追踪的任务的当前目标显示在小地图上；
##   目标在别的关卡时，标在通往那个关卡的出口上。
##
## 存档：每个任务的 state / 已访问步骤（按时间顺序，带天数）/ 当前目标 / 未读标记。
## 数据：data/rules/quests.json（结构）+ data/text/journal.tsv（文字，按语言分列）。

signal updated(quest: String, step: String, kind: StringName)   # kind: added / updated / completed / failed
signal tracked_changed(quest: String)
signal read_changed

var defs: Dictionary = {}
var categories: Dictionary = {}
## quest -> {"state": active/completed/failed, "steps": [[step, day], ...], "objective": id, "unread": bool, "order": int}
var quests: Dictionary = {}
var tracked := ""
var _order := 0
var _checking := false
var _dirty := false


func _ready() -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/rules/quests.json"))
	defs = d.get("quests", {})
	categories = d.get("categories", {})
	Game.flag_changed.connect(func(_f, _v): _request_check())
	Game.party_changed.connect(_request_check)
	Router.level_loaded.connect(func(_l): _request_check())
	Inv.changed.connect(_request_check)
	reset()


## 新游戏
func reset() -> void:
	quests = {}
	tracked = ""
	_order = 0
	# 一条你没做过的已完成任务
	for qid in defs:
		var pre: Array = defs[qid].get("start_completed", [])
		if pre.is_empty():
			continue
		_ensure(qid)
		for s in pre:
			quests[qid]["steps"].append([s, 0])
		quests[qid]["state"] = "completed"
		quests[qid]["unread"] = false
		quests[qid]["objective"] = _objective_of(qid)


# ------------------------------------------------------------------ 查询

func has_quest(qid: String) -> bool:
	return quests.has(qid)


func state(qid: String) -> String:
	return quests[qid]["state"] if quests.has(qid) else ""


func is_active(qid: String) -> bool:
	return state(qid) == "active"


func visited(qid: String, step: String) -> bool:
	if not quests.has(qid):
		return false
	for e in quests[qid]["steps"]:
		if e[0] == step:
			return true
	return false


func objective(qid: String) -> String:
	return quests[qid]["objective"] if quests.has(qid) else ""


func title(qid: String) -> String:
	return TextDB.line("journal", "quest_" + qid)


func step_text(qid: String, step: String) -> String:
	return TextDB.line("journal", "step_%s_%s" % [qid, step])


func objective_text(qid: String, obj: String) -> String:
	return TextDB.line("journal", "obj_%s_%s" % [qid, obj])


func subquests(qid: String) -> Array:
	var out: Array = []
	for k in defs:
		if defs[k].get("parent", "") == qid and quests.has(k):
			out.append(k)
	return out


## 日志条目，最新的在前
func entries(qid: String) -> Array:
	var out: Array = []
	if not quests.has(qid):
		return out
	for e in quests[qid]["steps"]:
		var sd: Dictionary = defs[qid]["steps"].get(e[0], {})
		if sd.get("quest_op", "") == "add_only":
			continue
		out.push_front({"step": e[0], "day": int(e[1]), "text": step_text(qid, e[0])})
	return out


func unread_count() -> int:
	var n := 0
	for q in quests.values():
		if q.get("unread", false):
			n += 1
	return n


func mark_read(qid: String) -> void:
	if quests.has(qid):
		quests[qid]["unread"] = false


# ------------------------------------------------------------------ 解锁

## 脚本 / 对话直接解锁一步（BG3 的 QuestUpdate）。返回 true = 真的解锁了
func update(qid: String, step: String) -> bool:
	if not defs.has(qid) or not defs[qid]["steps"].has(step):
		push_warning("Journal: unknown step %s.%s" % [qid, step])
		return false
	if not _can_unlock(qid, step, false):
		return false
	_unlock(qid, step)
	return true


func _request_check() -> void:
	if not _dirty:
		_dirty = true
		_check.call_deferred()


## 所有带 when 的步骤：条件满足就解锁。解锁会设标记，可能连锁解锁别的步骤，所以循环到稳定为止
func check_now() -> void:
	_check()


func _check() -> void:
	_dirty = false
	if _checking:
		return
	_checking = true
	for _pass in 8:
		var changed := false
		for qid in defs:
			if defs[qid].has("start_completed"):
				continue
			for step in defs[qid]["steps"]:
				var sd: Dictionary = defs[qid]["steps"][step]
				if not sd.has("when"):
					continue
				if _can_unlock(qid, step, true):
					_unlock(qid, step)
					changed = true
		if not changed:
			break
	_checking = false


func _can_unlock(qid: String, step: String, need_when: bool) -> bool:
	var sd: Dictionary = defs[qid]["steps"][step]
	if visited(qid, step):
		return false
	var st := state(qid)
	if st == "completed" or st == "failed":
		return false
	# 任务还没加入：只有 add / add_only 的步骤能开始它（子任务的父任务也要在）
	if st == "" and not (sd.get("quest_op", "") in ["add", "add_only"]):
		return false
	var parent: String = defs[qid].get("parent", "")
	if parent != "" and not quests.has(parent):
		return false
	if need_when and not Cond.all(sd.get("when", [])):
		return false
	if Cond.any(sd.get("block", [])):
		return false
	for a in sd.get("after", []):
		if not visited(qid, a):
			return false
	return true


func _ensure(qid: String) -> void:
	if quests.has(qid):
		return
	_order += 1
	quests[qid] = {"state": "active", "steps": [], "objective": "", "unread": true, "order": _order}


func _unlock(qid: String, step: String) -> void:
	var sd: Dictionary = defs[qid]["steps"][step]
	var is_new := not quests.has(qid)
	_ensure(qid)
	var q: Dictionary = quests[qid]
	q["steps"].append([step, Game.day])
	q["unread"] = true
	var kind := &"added" if is_new else &"updated"
	if sd.get("quest_op", "") == "close":
		q["state"] = sd.get("result", "completed")
		kind = StringName(q["state"])
	q["objective"] = _objective_of(qid)
	Game.set_flag(StringName("q_%s_%s" % [qid, step]))
	Meta.bump("journal_updates")
	# 奖励
	if int(sd.get("xp", 0)) > 0:
		Game.award_xp(int(sd["xp"]))
	if int(sd.get("gold", 0)) > 0:
		Inv.gold += int(sd["gold"])
	for who in sd.get("approval", {}):
		Approval.change(StringName(who), int(sd["approval"][who]), "quest:%s.%s" % [qid, step], false, true)
	# 关闭的任务把子任务也关掉（子任务没结束的算失败）
	if q["state"] != "active":
		for sub in subquests(qid):
			if quests[sub]["state"] == "active":
				quests[sub]["state"] = "failed"
	# 新任务自动追踪（没在追踪别的的话）
	if q["state"] == "active" and (tracked == "" or state(tracked) != "active") and defs[qid].get("parent", "") == "":
		track(qid)
	if sd.get("quest_op", "") != "add_only" or is_new:
		updated.emit(qid, step, kind)


## 当前目标 = 已解锁步骤指向的目标里优先级最高的
func _objective_of(qid: String) -> String:
	var best := ""
	var best_p := -INF
	var objs: Dictionary = defs[qid].get("objectives", {})
	for e in quests[qid]["steps"]:
		var o: String = defs[qid]["steps"].get(e[0], {}).get("objective", "")
		if o == "" or not objs.has(o):
			continue
		var p := float(objs[o].get("priority", 0))
		if p >= best_p:
			best_p = p
			best = o
	return best


func is_completion(qid: String, obj: String) -> bool:
	return bool(defs[qid].get("objectives", {}).get(obj, {}).get("completion", false))


# ------------------------------------------------------------------ 追踪 / 地图标记

func track(qid: String) -> void:
	tracked = qid
	tracked_changed.emit(qid)


## 当前关卡里要标的点（被追踪任务的当前目标，以及它没完成的子任务的目标）
func marker_positions(level: Node) -> Array:
	var out: Array = []
	if level == null or tracked == "" or not is_active(tracked):
		return out
	var qs: Array = [tracked] + subquests(tracked).filter(func(s): return is_active(s))
	for qid in qs:
		var o := objective(qid)
		if o == "":
			continue
		for m in defs[qid].get("objectives", {}).get(o, {}).get("markers", []):
			var p = _resolve_marker(level, m)
			if p != null:
				out.append(p)
	return out


func _resolve_marker(level: Node, m: Dictionary) -> Variant:
	var lvl: String = m.get("level", "")
	if lvl == String(level.name):
		var n := level.find_child(String(m.get("node", "")), true, false) as Node3D
		if n:
			return n.global_position
		if m.has("pos"):
			var a: Array = m["pos"]
			return Vector3(a[0], a[1], a[2])
		return null
	# 目标在别的关卡：标通往那里的出口
	for e in level.find_children("*", "LevelExit", true, false):
		if String(e.target).get_file().get_basename() == lvl:
			return (e as Node3D).global_position
	return null


# ------------------------------------------------------------------ 存档

func snapshot() -> Dictionary:
	return {"quests": quests.duplicate(true), "tracked": tracked, "order": _order}


func restore(d: Dictionary) -> void:
	quests = d.get("quests", {}).duplicate(true)
	for q in quests.values():
		for e in q["steps"]:
			e[1] = int(e[1])
		q["order"] = int(q.get("order", 0))
	tracked = d.get("tracked", "")
	_order = int(d.get("order", 0))
	tracked_changed.emit(tracked)
