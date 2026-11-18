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

## 3 级团的占位数值。战斗系统接手后改成从角色卡读。
var hp := {PROTAGONIST: 28, HUSBAND: 64, POET: 19, SL: 22}
var max_hp := {PROTAGONIST: 28, HUSBAND: 64, POET: 19, SL: 22}


func select(id: StringName) -> void:
	if id == selected or not in_party(id):
		return
	selected = id
	selected_changed.emit(id)


func set_hp(id: StringName, v: int) -> void:
	hp[id] = clampi(v, 0, int(max_hp.get(id, v)))
	hp_changed.emit(id)


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
