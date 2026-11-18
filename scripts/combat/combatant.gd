class_name Combatant
extends RefCounted
## 战斗中的一个单位：角色卡 + 回合资源 + 状态 + 位置。
## 有 3D 节点时位置跟节点走；没有（测试）时用 _pos。

signal status_changed

var sheet: CharacterSheet
var node: Node3D
var team: StringName = &"party"   # party / enemy
var initiative := 0

# 回合资源（BG3：动作 / 附赠动作 / 移动 / 反应）
var actions := 1
var bonus := 1
var reaction := 1
var move_left := 0.0
var sneak_used := false
var cooldowns := {}               # action id -> 剩余回合

## 状态：id -> {turns, source (Combatant), data}
var statuses := {}
## 专注：{spell, targets: Array[Combatant]}
var concentration := {}

var _pos := Vector3.ZERO


func _init(s: CharacterSheet, n: Node3D = null, t: StringName = &"party") -> void:
	sheet = s
	node = n
	team = t


func id() -> StringName:
	return sheet.id


func display_name() -> String:
	if sheet.is_monster:
		return TextDB.line("rules", "monster_" + sheet.monster_kind)
	return TextDB.char_name(sheet.id)


func pos() -> Vector3:
	if node and is_instance_valid(node):
		return node.global_position
	return _pos


func set_pos(p: Vector3) -> void:
	_pos = p
	if node and is_instance_valid(node):
		node.global_position = p


func dist_to(o: Combatant) -> float:
	var a := pos()
	var b := o.pos()
	return Vector2(a.x - b.x, a.z - b.z).length()


func is_alive() -> bool:
	return not sheet.dead and not (sheet.is_monster and sheet.hp <= 0)


func is_down() -> bool:
	return sheet.hp <= 0


## 能行动（活着且没倒地）
func can_act() -> bool:
	return is_alive() and not is_down()


func hostile_to(o: Combatant) -> bool:
	return team != o.team


func speed() -> float:
	var s := sheet.speed
	if has_status(&"slowed"):
		s -= 3.0
	if sheet.equipment.get("armor", "") != "":
		var req := int(Rules.armor.get(sheet.equipment["armor"], {}).get("str_req", 0))
		if req > 0 and int(sheet.abilities.get("str", 10)) < req:
			s -= 3.0
	return maxf(0.0, s)


func ac() -> int:
	var a := sheet.ac()
	if has_status(&"shield_of_faith"):
		a += 2
	if has_status(&"shield_spell"):
		a += 5
	if has_status(&"lying_down"):
		a += 2
	return a


# ------------------------------------------------------------------ 状态

func has_status(s: StringName) -> bool:
	return statuses.has(s)


func add_status(s: StringName, turns: int, source: Combatant = null, data := {}) -> void:
	statuses[s] = {"turns": turns, "source": source, "data": data}
	status_changed.emit()


func remove_status(s: StringName) -> void:
	if statuses.erase(s):
		status_changed.emit()


## 回合开始：重置资源，状态计时
func start_turn() -> void:
	actions = 1
	bonus = 1
	reaction = 1
	sneak_used = false
	move_left = speed()
	if has_status(&"prone") and can_act():
		# 站起来花一半移动力
		move_left = move_left / 2.0
		remove_status(&"prone")
	for k in cooldowns.keys():
		cooldowns[k] -= 1
		if cooldowns[k] <= 0:
			cooldowns.erase(k)
	# "直到你的下个回合开始"的状态
	for s in [&"dodging", &"disengaged", &"shield_spell", &"lying_down"]:
		remove_status(s)


func end_turn() -> void:
	for s in statuses.keys():
		var st: Dictionary = statuses[s]
		st["turns"] -= 1
		if st["turns"] <= 0 and s != &"prone" and s != &"hexed" and s != &"downed":
			statuses.erase(s)
	status_changed.emit()


## 存档快照（SL 的【读取存档】用）
func snapshot() -> Dictionary:
	return {
		"pos": pos(), "hp": sheet.hp, "temp": sheet.temp_hp, "dead": sheet.dead,
		"ds": sheet.death_successes, "df": sheet.death_failures,
		"slots": sheet.slots_used.duplicate(), "pact": sheet.pact_used,
		"res": sheet.resources.duplicate(), "statuses": statuses.duplicate(true),
		"conc": concentration.duplicate(), "cd": cooldowns.duplicate(),
	}


func restore(s: Dictionary) -> void:
	set_pos(s["pos"])
	sheet.hp = s["hp"]
	sheet.temp_hp = s["temp"]
	sheet.dead = s["dead"]
	sheet.death_successes = s["ds"]
	sheet.death_failures = s["df"]
	sheet.slots_used = s["slots"].duplicate()
	sheet.pact_used = s["pact"]
	sheet.resources = s["res"].duplicate()
	statuses = s["statuses"].duplicate(true)
	concentration = s["conc"].duplicate()
	cooldowns = s["cd"].duplicate()
	sheet.hp_changed.emit()
	status_changed.emit()
