extends Node
## 全局状态：队伍、剧情标记、角色运行时状态。

const PROTAGONIST := &"protagonist"
const HUSBAND := &"husband"
const POET := &"poet"
const SL := &"sl"

signal party_changed
signal flag_changed(flag: StringName, value: Variant)
signal selected_changed(id: StringName)
signal hp_changed(id: StringName)
## 技能栏按下。战斗系统订阅它。
signal ability_used(user: StringName, ability: StringName)

## 入队顺序。主角永远在。
var party: Array[StringName] = [PROTAGONIST]
var flags: Dictionary = {}

## 诗人是否在地图外面。场景切换时由 Router 清掉。
var poet_outside_map := false

## HUD 上当前选中的角色
var selected: StringName = PROTAGONIST

## 全队等级（大家一起从 1 升到 3）
var party_level := 1
## 角色卡，跨关卡保留
var sheets: Dictionary = {}
signal leveled_up(level: int)


func sheet(id: StringName) -> CharacterSheet:
	if not sheets.has(id):
		var s := CharacterSheet.from_party(id, party_level)
		s.hp_changed.connect(func(): hp_changed.emit(id))
		sheets[id] = s
	return sheets[id]


## 全队升一级，按 data/rules/party.json 的路线
func level_up_party() -> bool:
	if party_level >= 3:
		return false
	party_level += 1
	for id in sheets:
		sheets[id].level_up_next()
	leveled_up.emit(party_level)
	return true


func select(id: StringName) -> void:
	if id == selected or not in_party(id):
		return
	selected = id
	selected_changed.emit(id)




func in_party(id: StringName) -> bool:
	return id in party


func join(id: StringName) -> void:
	if id in party:
		return
	party.append(id)
	party_changed.emit()


func leave(id: StringName) -> void:
	party.erase(id)
	party_changed.emit()


func set_flag(f: StringName, v: Variant = true) -> void:
	flags[f] = v
	flag_changed.emit(f, v)


func flag(f: StringName, default: Variant = false) -> Variant:
	return flags.get(f, default)


## Router 在每次关卡加载完之后调用
func on_level_loaded() -> void:
	poet_outside_map = false
