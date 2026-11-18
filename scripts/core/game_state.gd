extends Node
## 全局状态：队伍、剧情标记、角色运行时状态。

const PROTAGONIST := &"protagonist"
const HUSBAND := &"husband"
const POET := &"poet"
const SL := &"sl"

signal party_changed
signal flag_changed(flag: StringName, value: Variant)

## 入队顺序。主角永远在。
var party: Array[StringName] = [PROTAGONIST]
var flags: Dictionary = {}

## 诗人是否在地图外面。场景切换时由 Router 清掉。
var poet_outside_map := false


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
