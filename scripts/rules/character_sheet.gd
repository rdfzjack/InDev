class_name CharacterSheet
extends RefCounted
## 角色卡。5e 规则，1-3 级。队员和怪物共用（怪物走 from_monster，数据直接是 stat block）。
## 生命值存在这里，跨战斗保留；回合内资源（动作、附赠动作、移动、反应）在 Combatant 里。

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]
const SKILL_ABILITY := {
	"athletics": "str", "acrobatics": "dex", "sleight_of_hand": "dex", "stealth": "dex",
	"arcana": "int", "history": "int", "investigation": "int", "nature": "int", "religion": "int",
	"animal_handling": "wis", "insight": "wis", "medicine": "wis", "perception": "wis", "survival": "wis",
	"deception": "cha", "intimidation": "cha", "performance": "cha", "persuasion": "cha",
}
## 多职业施法者法术位表（施法者等级 → 各环位数）
const MULTICLASS_SLOTS := {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]}

signal hp_changed

var id: StringName
var is_monster := false
var monster_kind := ""
var race := "human"
var abilities := {}
## 按获得顺序的职业等级。[{"class": "fighter", ...choices}, ...]
var class_path: Array = []
var class_levels := {}          # class -> level
var max_hp := 1
var hp := 1
var temp_hp := 0
var death_successes := 0
var death_failures := 0
var dead := false

var armor_profs: Array = []
var weapon_profs: Array = []
var save_profs: Array = []
var skills: Array = []
var expertise: Array = []
var features: Array = []        # "class:feature"
var fighting_styles: Array = []
var choices := {}               # sacred_oath / bard_college / patron ...

var cantrips: Array = []
var spells_known: Array = []
var bug_spells: Array = []      # 永远可用、不耗法术位（你老公的火球）
var spell_source := {}          # spell -> class（决定施法属性）
var slots_max: Array = []       # index 0 = 1 环
var slots_used: Array = []
var pact_count := 0
var pact_level := 0
var pact_used := 0

var resources := {}             # 每日/短休资源：剩余次数
## 战斗外的持续效果（药剂等），长休清除。id -> true
var long_effects := {}
var resources_max := {}

var equipment := {}
var resist: Array = []
var vulnerable: Array = []
var immune: Array = []
var traits: Array = []
var speed := 9.0

# 怪物
var monster_ac := 10
var monster_attacks: Array = []
var monster_saves := {}


# ------------------------------------------------------------------ 构建

static func from_party(char_id: StringName, level := 1) -> CharacterSheet:
	var d: Dictionary = Rules.party.get(String(char_id), {})
	var s := CharacterSheet.new()
	s.id = char_id
	s.race = d.get("race", "human")
	s.abilities = d.get("abilities", {}).duplicate()
	s.equipment = d.get("equipment", {}).duplicate()
	s.skills = d.get("skills", []).duplicate()
	s.bug_spells = d.get("bug_spells", []).duplicate()
	var r: Dictionary = Rules.races.get(s.race, {})
	s.resist = r.get("resist", []).duplicate()
	s.traits = r.get("traits", []).duplicate()
	s.speed = float(r.get("speed", 9))
	for i in level:
		if not s.level_up_next():
			break
	s.hp = s.max_hp
	return s


static func from_monster(kind: String, instance_id: StringName) -> CharacterSheet:
	var d: Dictionary = Rules.monsters.get(kind, {})
	var s := CharacterSheet.new()
	s.id = instance_id
	s.is_monster = true
	s.monster_kind = kind
	s.abilities = d.get("abilities", {}).duplicate()
	s.monster_ac = int(d.get("ac", 10))
	s.max_hp = int(d.get("hp", 1))
	s.hp = s.max_hp
	s.speed = float(d.get("speed", 9))
	s.monster_attacks = d.get("attacks", []).duplicate(true)
	s.monster_saves = d.get("saves", {})
	s.resist = d.get("resist", []).duplicate()
	s.vulnerable = d.get("vulnerable", []).duplicate()
	s.immune = d.get("immune", []).duplicate()
	s.traits = d.get("traits", []).duplicate()
	return s


# ------------------------------------------------------------------ 等级

func level() -> int:
	return class_path.size()


func class_level(c: String) -> int:
	return int(class_levels.get(c, 0))


func primary_class() -> String:
	return class_path[0]["class"] if class_path.size() > 0 else ""


## 下一级按 party.json 的推荐路线走（经过 LevelUp 校验，配额以规则为准）
func level_up_next() -> bool:
	var path: Array = Rules.party.get(String(id), {}).get("levels", [])
	if level() >= path.size():
		return false
	var c: String = path[level()].get("class", "")
	return LevelUp.apply(self, LevelUp.recommended(self, c))


func meets_multiclass_req(c: String) -> bool:
	var req: Dictionary = Rules.classes.get(c, {}).get("multiclass_req", {})
	for ab in req.get("all", {}):
		if int(abilities.get(ab, 0)) < int(req["all"][ab]):
			return false
	var any: Dictionary = req.get("any", {})
	if any.is_empty():
		return true
	for ab in any:
		if int(abilities.get(ab, 0)) >= int(any[ab]):
			return true
	return false


## 能否在下一级拿这个职业。兼职：当前所有职业和新职业都要满足属性门槛。
func can_take_class(c: String) -> bool:
	if not Rules.classes.has(c):
		return false
	if level() >= 20:
		return false
	if level() == 0 or class_levels.has(c):
		return true
	if not meets_multiclass_req(c):
		return false
	for existing in class_levels:
		if not meets_multiclass_req(existing):
			return false
	return true


## step: {"class": id, 其他选择...}
func level_up(step: Dictionary) -> bool:
	var c: String = step.get("class", "")
	if not can_take_class(c):
		push_warning("CharacterSheet %s: cannot take class %s" % [id, c])
		return false
	var cd: Dictionary = Rules.classes[c]
	var first_level_overall := level() == 0
	var first_in_class := not class_levels.has(c)
	class_path.append(step)
	class_levels[c] = class_level(c) + 1
	var cl := class_level(c)
	# 生命值：1 级取满，之后取平均（向上取整）
	var hd: int = cd["hit_die"]
	var con := mod("con")
	var gain := (hd if first_level_overall else hd / 2 + 1) + con
	max_hp += maxi(1, gain) - (1 if first_level_overall else 0)
	hp = max_hp
	# 熟练项
	if first_level_overall:
		save_profs = cd["saves"].duplicate()
		_add_unique(armor_profs, cd["armor"])
		_add_unique(weapon_profs, cd["weapons"])
	elif first_in_class:
		_add_unique(armor_profs, cd.get("mc_armor", []))
		_add_unique(weapon_profs, cd.get("mc_weapons", []))
	# 特性
	for f in cd["features"].get(str(cl), []):
		_gain_feature(c, f, step)
	# 选择
	for k in ["sacred_oath", "bard_college", "patron", "martial_archetype", "arcane_tradition", "roguish_archetype", "pact_boon"]:
		if step.has(k):
			choices[k] = step[k]
	if step.has("fighting_style"):
		_add_unique(fighting_styles, [step["fighting_style"]])
	if step.has("expertise"):
		_add_unique(expertise, step["expertise"])
	if step.has("skills"):
		_add_unique(skills, step["skills"])
	if step.has("invocations"):
		var inv: Array = choices.get("invocations", [])
		_add_unique(inv, step["invocations"])
		choices["invocations"] = inv
	for sp in step.get("cantrips", []):
		_learn(sp, c, true)
	for sp in step.get("spells", []):
		_learn(sp, c, false)
	_recompute_slots()
	return true


var _pending_max := {}


func _gain_feature(c: String, f: String, _step: Dictionary) -> void:
	features.append("%s:%s" % [c, f])
	match f:
		"lay_on_hands":
			pass  # 池子大小随圣武士等级，_recompute_slots 里一起算
		"second_wind", "action_surge", "arcane_recovery":
			_pending_max[f] = 1


func has_feature(f: String) -> bool:
	for x in features:
		if x.ends_with(":" + f):
			return true
	return false


func _learn(sp: String, c: String, cantrip: bool) -> void:
	if not Rules.spells.has(sp):
		push_warning("CharacterSheet: unknown spell %s" % sp)
		return
	_add_unique(cantrips if cantrip else spells_known, [sp])
	spell_source[sp] = c


func _recompute_slots() -> void:
	var old_max := resources_max.duplicate()
	# 普通施法者
	var casters: Array = []
	for c in class_levels:
		var t: String = Rules.classes[c].get("caster", "none")
		if t == "full" or t == "half":
			casters.append(c)
	var new_slots: Array = []
	if casters.size() == 1:
		var c: String = casters[0]
		new_slots = Rules.classes[c].get("slots", {}).get(str(class_level(c)), []).duplicate()
	elif casters.size() > 1:
		var cl := 0
		for c in casters:
			cl += class_level(c) if Rules.classes[c]["caster"] == "full" else class_level(c) / 2
		new_slots = MULTICLASS_SLOTS.get(cl, []).duplicate()
	slots_max = new_slots.map(func(x): return int(x))
	while slots_used.size() < slots_max.size():
		slots_used.append(0)
	# 契约魔法（邪术师）单独算
	var wl := class_level("warlock")
	if wl > 0:
		var ps: Array = Rules.classes["warlock"]["pact_slots"][str(wl)]
		pact_count = ps[0]
		pact_level = ps[1]
	# 资源
	for k in _pending_max:
		resources_max[k] = _pending_max[k]
	_pending_max.clear()
	var pal := class_level("paladin")
	if pal > 0:
		resources_max["lay_on_hands"] = pal * 5
	if class_level("bard") > 0:
		resources_max["bardic_inspiration"] = maxi(1, mod("cha"))
	# 上限提高了，当前值跟着加上差额
	for k in resources_max:
		resources[k] = int(resources.get(k, 0)) + int(resources_max[k]) - int(old_max.get(k, 0))


# ------------------------------------------------------------------ 法术配额

## 这个职业在某个职业等级能施放的最高环（按该职业自己的表）
static func class_max_spell_level(c: String, cl: int) -> int:
	var cd: Dictionary = Rules.classes.get(c, {})
	if cd.get("caster", "none") == "pact":
		return int(cd["pact_slots"].get(str(cl), [0, 0])[1])
	return cd.get("slots", {}).get(str(cl), []).size()


## 某职业在某职业等级的戏法数
func cantrip_quota(c: String, cl := -1) -> int:
	cl = class_level(c) if cl < 0 else cl
	return int(Rules.classes.get(c, {}).get("cantrips_known", {}).get(str(cl), 0))


## 某职业在某职业等级的法术数（已知或准备）
func spell_quota(c: String, cl := -1) -> int:
	cl = class_level(c) if cl < 0 else cl
	var cd: Dictionary = Rules.classes.get(c, {})
	if class_max_spell_level(c, cl) == 0:
		return 0
	if cd.has("spells_known"):
		return int(cd["spells_known"].get(str(cl), 0))
	if cd.has("prepared"):
		var lv := cl if cd.get("caster", "") == "full" else cl / 2
		return maxi(1, mod(cd["prepared"]) + lv)
	return 0


func known_from(c: String, cantrip: bool) -> Array:
	var out: Array = []
	for sp in (cantrips if cantrip else spells_known):
		if spell_source.get(sp, "") == c:
			out.append(sp)
	return out


func invocations() -> Array:
	return choices.get("invocations", [])


# ------------------------------------------------------------------ 数值

func mod(ab: String) -> int:
	return Dice.mod(int(abilities.get(ab, 10)))


func proficiency() -> int:
	if is_monster:
		return 2
	return Rules.proficiency(level())


func ac() -> int:
	if is_monster:
		return monster_ac
	var a: String = equipment.get("armor", "")
	var base := 10 + mod("dex")
	if a != "" and Rules.armor.has(a):
		var ad: Dictionary = Rules.armor[a]
		base = int(ad["base"]) + mini(mod("dex"), int(ad.get("dex_max", 99)))
		if "defense" in fighting_styles:
			base += 1
	if equipment.get("shield", false):
		base += int(Rules.armor["shield"]["bonus"])
	base += int(Rules.item(equipment.get("ring", "")).get("ac", 0))
	return base


## 重击门槛：勇士 19
func crit_range() -> int:
	return 19 if choices.get("martial_archetype", "") == "champion" else 20


func wears_metal_armor() -> bool:
	var a: String = equipment.get("armor", "")
	return a != "" and Rules.armor.get(a, {}).get("metal", false)


func save_bonus(ab: String) -> int:
	if is_monster:
		return int(monster_saves.get(ab, mod(ab)))
	return mod(ab) + (proficiency() if ab in save_profs else 0) + int(Rules.item(equipment.get("ring", "")).get("saves", 0))


func skill_bonus(sk: String) -> int:
	var ab: String = SKILL_ABILITY.get(sk, "str")
	var b := mod(ab)
	if sk in expertise:
		b += proficiency() * 2
	elif sk in skills:
		b += proficiency()
	elif has_feature("jack_of_all_trades"):
		b += proficiency() / 2
	return b


## 被动技能：10 + 技能加值（察觉 / 洞悉 / 调查）
func passive(sk: String) -> int:
	if is_monster:
		var md: Dictionary = Rules.monsters.get(monster_kind, {})
		if sk == "perception":
			return int(md.get("passive_perception", 10 + mod("wis")))
		return 10 + mod(SKILL_ABILITY.get(sk, "wis"))
	return 10 + skill_bonus(sk)


## 主动技能检定加值（怪物用 stat block 里写的数）
func check_bonus(sk: String) -> int:
	if is_monster:
		var md: Dictionary = Rules.monsters.get(monster_kind, {})
		if md.has(sk):
			return int(md[sk])
		return mod(SKILL_ABILITY.get(sk, "str"))
	return skill_bonus(sk)


func initiative_bonus() -> int:
	var b := mod("dex")
	if long_effects.has("vigilant"):
		b += 5
	if has_feature("jack_of_all_trades"):
		b += proficiency() / 2
	return b


func proficient_with(weapon_id: String) -> bool:
	if is_monster:
		return true
	var w: Dictionary = Rules.weapon(weapon_id)
	if w.has("magic"):
		weapon_id = weapon_id.trim_suffix("_plus_1")
	return w.get("cat", "") in weapon_profs or weapon_id in weapon_profs or weapon_id == "unarmed"


## 武器攻击用哪个属性：灵巧武器取力敏较高者，远程武器用敏捷
func weapon_ability(weapon_id: String) -> String:
	var w: Dictionary = Rules.weapon(weapon_id)
	if w.get("kind", "melee") == "ranged":
		return "dex"
	if "finesse" in w.get("props", []):
		return "dex" if mod("dex") > mod("str") else "str"
	return "str"


func weapon_attack_bonus(weapon_id: String) -> int:
	var b := mod(weapon_ability(weapon_id)) + (proficiency() if proficient_with(weapon_id) else 0)
	b += int(Rules.weapon(weapon_id).get("magic", 0))
	if "archery" in fighting_styles and Rules.weapon(weapon_id).get("kind", "") == "ranged":
		b += 2
	return b


## 武器伤害表达式（含属性加值、对决风格）
func weapon_damage_expr(weapon_id: String) -> String:
	var w: Dictionary = Rules.weapon(weapon_id)
	var dice: String = w.get("dice", "1")
	var b := mod(weapon_ability(weapon_id)) + int(w.get("magic", 0))
	var one_handed_melee: bool = w.get("kind", "melee") == "melee" and not ("two_handed" in w.get("props", []))
	if "dueling" in fighting_styles and one_handed_melee and equipment.get("off_hand", "") == "":
		b += 2
	if not dice.contains("d"):
		return str(int(dice) + b)
	return "%s%s%d" % [dice, "+" if b >= 0 else "", b] if b != 0 else dice


func spell_ability(sp: String) -> String:
	var c: String = spell_source.get(sp, primary_class())
	if sp in bug_spells and not spell_source.has(sp):
		c = "wizard" if class_levels.has("wizard") else primary_class()
	return Rules.classes.get(c, {}).get("spell_ability", "cha")


func spell_attack_bonus(sp: String) -> int:
	return mod(spell_ability(sp)) + proficiency()


func spell_dc(sp: String) -> int:
	return 8 + mod(spell_ability(sp)) + proficiency()


# ------------------------------------------------------------------ 法术位

func all_spells() -> Array:
	var out := cantrips.duplicate()
	_add_unique(out, spells_known)
	_add_unique(out, bug_spells)
	return out


func is_bug_spell(sp: String) -> bool:
	return sp in bug_spells


## 某环可用的位（普通 + 契约）
func slots_free(lvl: int) -> int:
	var n := 0
	if lvl >= 1 and lvl <= slots_max.size():
		n += slots_max[lvl - 1] - slots_used[lvl - 1]
	if pact_level == lvl:
		n += pact_count - pact_used
	return n


## 施放 base_level 环法术能用的最低环位（0 = 没有）
func lowest_slot_for(base_level: int) -> int:
	for l in range(base_level, 10):
		if slots_free(l) > 0:
			return l
	return 0


func spend_slot(lvl: int) -> bool:
	if lvl >= 1 and lvl <= slots_max.size() and slots_used[lvl - 1] < slots_max[lvl - 1]:
		slots_used[lvl - 1] += 1
		return true
	if pact_level == lvl and pact_used < pact_count:
		pact_used += 1
		return true
	return false


func has_resource(r: String, amount := 1) -> bool:
	return int(resources.get(r, 0)) >= amount


func spend_resource(r: String, amount := 1) -> bool:
	if not has_resource(r, amount):
		return false
	resources[r] -= amount
	return true


func short_rest() -> void:
	pact_used = 0
	for r in ["second_wind", "action_surge"]:
		if resources_max.has(r):
			resources[r] = resources_max[r]


func long_rest() -> void:
	short_rest()
	long_effects.clear()
	hp = max_hp
	temp_hp = 0
	death_successes = 0
	death_failures = 0
	for i in slots_used.size():
		slots_used[i] = 0
	for r in resources_max:
		resources[r] = resources_max[r]
	hp_changed.emit()


# ------------------------------------------------------------------ 伤害

## 返回结算抗性/易伤/免疫之后的伤害量（日志显示这个数；0 血以下的部分也算）
func apply_damage(amount: int, dtype: String) -> int:
	if dtype in immune:
		return 0
	if dtype in resist:
		amount = amount / 2
	if dtype in vulnerable:
		amount *= 2
	var effective := amount
	var absorbed := mini(temp_hp, amount)
	temp_hp -= absorbed
	amount -= absorbed
	hp = maxi(0, hp - amount)
	hp_changed.emit()
	return effective


func heal(amount: int) -> int:
	if dead:
		return 0
	var before := hp
	hp = mini(max_hp, hp + amount)
	if hp > 0:
		death_successes = 0
		death_failures = 0
	hp_changed.emit()
	return hp - before


func is_down() -> bool:
	return hp <= 0


static func _add_unique(arr: Array, items: Array) -> void:
	for x in items:
		if not (x in arr):
			arr.append(x)
