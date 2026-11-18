extends Node
## 全局状态：队伍、剧情标记、角色运行时状态。

const PROTAGONIST := &"protagonist"
const HUSBAND := &"husband"
const POET := &"poet"
const SL := &"sl"

signal party_changed
## 头顶提示（被动察觉等），OverheadText 显示
signal notice(char_id: StringName, text: String)
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

## 商店状态（库存永远不刷新，所以第一次打开时从数据复制一份，之后一直用这份）
var shops: Dictionary = {}


func shop_state(id: String) -> Dictionary:
	if not shops.has(id):
		var d: Dictionary = Rules.shops.get(id, {})
		var stock: Array = []
		for e in d.get("stock", []):
			if e != null:
				stock.append({"id": e["item"], "qty": int(e["qty"])})
		shops[id] = {"keeper": d.get("keeper", ""), "gold": int(d.get("gold", 0)),
			"buy_ratio": float(d.get("buy_ratio", 0.5)), "stock": stock}
	return shops[id]


## 天数（每次长休 +1）。约谈按天推进。
var day := 1
signal day_passed(day: int)


## 长休：要 40 点营地补给（营地补给每个 10 点）
const LONG_REST_SUPPLIES := 4


func has_rest_supplies() -> bool:
	return Inv.count("camp_supplies") >= LONG_REST_SUPPLIES


func long_rest() -> bool:
	if not Inv.remove("camp_supplies", LONG_REST_SUPPLIES):
		Narrator.say("long_rest_no_supplies")
		return false
	for id in sheets:
		sheets[id].long_rest()
	day += 1
	Meta.bump("long_rests")
	day_passed.emit(day)
	return true


## 全队等级（大家一起从 1 升到 3）
var party_level := 1
## 每人经验（5e：遭遇战经验按人头平分）。达到门槛后可以升级（升级界面里确认）。
var xp := 0
const XP_THRESHOLDS := {2: 300, 3: 900}
const MAX_LEVEL := 3
signal xp_changed
## 角色卡，跨关卡保留
var sheets: Dictionary = {}
signal leveled_up(level: int)


func sheet(id: StringName) -> CharacterSheet:
	if not sheets.has(id):
		# 中途入队的人按推荐路线直接到当前等级
		var s := CharacterSheet.from_party(id, party_level)
		s.hp_changed.connect(func(): hp_changed.emit(id))
		sheets[id] = s
	return sheets[id]


func award_xp(amount: int) -> void:
	xp += amount
	Meta.bump("xp_total", amount)
	xp_changed.emit()


## 经验允许的最高等级
func level_allowed() -> int:
	var lv := 1
	for l in range(2, MAX_LEVEL + 1):
		if xp >= int(XP_THRESHOLDS.get(l, 1 << 30)):
			lv = l
	return lv


func can_level(id: StringName) -> bool:
	return in_party(id) and sheet(id).level() < level_allowed()


## 升级界面确认之后调用
func on_sheet_leveled(s: CharacterSheet) -> void:
	party_level = maxi(party_level, s.level())
	leveled_up.emit(s.level())


## 调试：经验直接加到下一级门槛
func debug_xp_to_next_level() -> void:
	var nxt := level_allowed() + 1
	if XP_THRESHOLDS.has(nxt):
		award_xp(int(XP_THRESHOLDS[nxt]) - xp)


## 全队升一级，按 data/rules/party.json 的推荐路线（调试 / 测试用；正式流程走升级界面）
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
	if f == &"enough_supplies":
		return has_rest_supplies()
	return flags.get(f, default)


## Router 在每次关卡加载完之后调用
func on_level_loaded() -> void:
	poet_outside_map = false
