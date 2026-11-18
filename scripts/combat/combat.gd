extends Node
## 战斗管理器（autoload: Combat）。5e 规则，BG3 式回合：动作 / 附赠动作 / 移动 / 反应。
##
## 规则结算是同步的；表现层（UI、动画）订阅信号。
## 移动和 AI 回合是异步的（要等角色走到位）。
##
## 行动（action）是一个 Dictionary：
##   id        唯一 id，比如 "attack" "spell:fire_bolt" "second_wind"
##   kind      weapon / spell / feature / common / custom / monster
##   cost      action / bonus / reaction / none
##   range     米
##   target    enemy / ally / creature / self / point / downed_ally
##   area      {shape, size}（范围法术）
##   weapon / spell / attack_index  具体数据的 key

signal combat_started
signal combat_ended(party_won: bool)
signal round_started(round: int)
signal turn_started(c: Combatant)
signal turn_ended(c: Combatant)
## 文字日志（已本地化）
signal logged(text: String)
## 飘字：数字、"未命中"、"豁免成功"……
signal floated(c: Combatant, text: String, kind: StringName)
signal moved(c: Combatant, path: PackedVector3Array)
signal acted(c: Combatant, action: Dictionary, targets: Array)
## boss 进入新阶段（phase 从 2 开始）
signal boss_phase(c: Combatant, phase: int)
signal monster_killed(c: Combatant)

const REACH := 2.0          # 近战触及（中心距离，含胶囊体半径）
const TOUCH := 2.0
const DOWNED_AUTO_CRIT := 2.0

var active := false
## 测试用：AI 不等待
var instant := false
var combatants: Array[Combatant] = []
var order: Array[Combatant] = []
var turn_index := 0
var round_num := 0
## 战斗开始时的快照（SL 的【读取存档】）
var _start_snapshot := {}
var _ending := false


# ================================================================== 流程

func start(list: Array[Combatant]) -> void:
	if active:
		return
	active = true
	_ending = false
	combatants = list
	round_num = 1
	for c in combatants:
		var r := Dice.d20(c.sheet.initiative_bonus())
		c.initiative = r.total
		log_text("log_initiative", [c.display_name(), _d20_str(r), r.total])
	order = combatants.duplicate()
	order.sort_custom(func(a, b):
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		return a.sheet.mod("dex") > b.sheet.mod("dex"))
	_start_snapshot = {}
	for c in combatants:
		_start_snapshot[c] = c.snapshot()
	Meta.bump("combats")
	combat_started.emit()
	round_started.emit(round_num)
	turn_index = 0
	_begin_turn()


func current() -> Combatant:
	if not active or order.is_empty():
		return null
	return order[turn_index]


func _begin_turn() -> void:
	var c := current()
	if c == null:
		return
	c.start_turn()
	turn_started.emit(c)
	if not c.is_alive():
		end_turn.call_deferred()
		return
	if c.is_down() and not c.sheet.is_monster:
		_death_save(c)
		end_turn.call_deferred()
		return
	if c.team == &"enemy":
		_run_ai.call_deferred(c)


func end_turn() -> void:
	if not active:
		return
	var c := current()
	if c:
		c.end_turn()
		turn_ended.emit(c)
	if _check_end():
		return
	turn_index += 1
	if turn_index >= order.size():
		turn_index = 0
		round_num += 1
		round_started.emit(round_num)
	_begin_turn()


func _check_end() -> bool:
	var party_up := combatants.any(func(c): return c.team == &"party" and c.can_act())
	var enemy_up := combatants.any(func(c): return c.team == &"enemy" and c.is_alive())
	if party_up and enemy_up:
		return false
	_finish(party_up)
	return true


func _finish(party_won: bool) -> void:
	if _ending:
		return
	_ending = true
	active = false
	for c in combatants:
		c.statuses.clear()
		c.concentration.clear()
		# 战斗结束后倒地的队员恢复 1 点
		if c.team == &"party" and c.is_down() and not c.sheet.dead:
			c.sheet.heal(1)
	log_text("log_victory" if party_won else "log_defeat", [])
	if party_won:
		var xp := 0
		for c in combatants:
			if c.sheet.is_monster and not c.is_alive():
				xp += int(Rules.monsters.get(c.sheet.monster_kind, {}).get("xp", 0))
		var n := combatants.filter(func(c): return c.team == &"party").size()
		if xp > 0 and n > 0:
			log_text("log_xp", [xp / n])
			Game.award_xp(xp / n)
	combat_ended.emit(party_won)


func _run_ai(c: Combatant) -> void:
	await CombatAI.take_turn(c)
	if active and current() == c:
		end_turn()


# ================================================================== 行动列表

func actions_for(c: Combatant) -> Array:
	var out: Array = []
	var s := c.sheet
	if s.is_monster:
		var md: Dictionary = Rules.monsters.get(s.monster_kind, {})
		if md.has("multiattack"):
			var reach := 0.0
			for i in md["multiattack"]:
				reach = maxf(reach, float(s.monster_attacks[int(i)]["range"]))
			out.append({"id": "multiattack", "kind": "multiattack", "cost": "action", "range": reach + REACH - 1.5, "target": "enemy"})
		for sp in md.get("specials", []):
			out.append({"id": "special:" + sp["id"], "kind": "special", "cost": "action", "special": sp,
				"range": float(sp["area"]["size"]), "target": "point", "area": sp["area"]})
		for i in s.monster_attacks.size():
			var a: Dictionary = s.monster_attacks[i]
			var rng := float(a.get("long", a["range"]))
			if a["kind"] == "melee":
				rng = float(a["range"]) + REACH - 1.5
			out.append({"id": "mattack:%d" % i, "kind": "monster", "cost": "action", "attack_index": i,
				"range": rng, "target": "enemy"})
		out.append({"id": "dash", "kind": "common", "cost": "action", "range": 0, "target": "self"})
		if "nimble_escape" in s.traits:
			out.append({"id": "disengage", "kind": "common", "cost": "bonus", "range": 0, "target": "self"})
		return out
	var eq := s.equipment
	out.append({"id": "attack", "kind": "weapon", "cost": "action", "weapon": eq.get("main_hand", "unarmed"), "range": REACH, "target": "enemy"})
	if s.has_feature("divine_smite"):
		out.append({"id": "smite", "kind": "weapon", "cost": "action", "weapon": eq.get("main_hand", "unarmed"), "range": REACH, "target": "enemy", "smite": true})
	if eq.get("ranged", "") != "":
		var w := Rules.weapon(eq["ranged"])
		out.append({"id": "attack_ranged", "kind": "weapon", "cost": "action", "weapon": eq["ranged"], "range": float(w.get("range", [9, 9])[1]), "target": "enemy", "ranged": true})
	if eq.get("off_hand", "") != "" and "light" in Rules.weapon(eq.get("main_hand", "")).get("props", []):
		out.append({"id": "offhand", "kind": "weapon", "cost": "bonus", "weapon": eq["off_hand"], "range": REACH, "target": "enemy", "offhand": true})
	for sp in s.all_spells():
		var d := Rules.spell(sp)
		out.append({"id": "spell:" + sp, "kind": "spell", "spell": sp, "cost": d.get("cost", "action"),
			"range": float(d.get("range", 0)), "target": d.get("target", "creature"), "area": d.get("area", {})})
	if s.resources_max.has("second_wind"):
		out.append({"id": "second_wind", "kind": "feature", "cost": "bonus", "range": 0, "target": "self"})
	if s.resources_max.has("action_surge"):
		out.append({"id": "action_surge", "kind": "feature", "cost": "none", "range": 0, "target": "self"})
	if s.resources_max.has("lay_on_hands"):
		out.append({"id": "lay_on_hands", "kind": "feature", "cost": "action", "range": TOUCH, "target": "ally"})
	if s.resources_max.has("bardic_inspiration"):
		out.append({"id": "bardic_inspiration", "kind": "feature", "cost": "bonus", "range": 18.0, "target": "ally", "not_self": true})
	if s.has_feature("cunning_action"):
		out.append({"id": "cunning_dash", "kind": "feature", "cost": "bonus", "range": 0, "target": "self"})
		out.append({"id": "cunning_disengage", "kind": "feature", "cost": "bonus", "range": 0, "target": "self"})
	for cid in ["dash", "disengage", "dodge"]:
		out.append({"id": cid, "kind": "common", "cost": "action", "range": 0, "target": "self"})
	out.append({"id": "help", "kind": "common", "cost": "action", "range": TOUCH, "target": "downed_ally"})
	# 设计里的自定义技能（data/abilities.tsv）
	for r in TextDB.rows("abilities"):
		if r.get("owner", "") == String(s.id) and r["id"] in ["lie_down", "load_save"]:
			out.append({"id": r["id"], "kind": "custom", "cost": "action" if r["id"] == "lie_down" else "none",
				"range": 0, "target": "self", "cooldown": int(r.get("cooldown", "0"))})
	return out


func find_action(c: Combatant, aid: String) -> Dictionary:
	for a in actions_for(c):
		if a["id"] == aid:
			return a
	return {}


## 能不能用（不看目标）。返回空字符串 = 可以；否则是原因的 ui key。
func why_not(c: Combatant, a: Dictionary) -> String:
	if not active or current() != c:
		return "why_not_your_turn"
	if not c.can_act():
		return "why_down"
	match a.get("cost", "action"):
		"action":
			if c.actions <= 0:
				return "why_no_action"
		"bonus":
			if c.bonus <= 0:
				return "why_no_bonus"
		"reaction":
			return "why_reaction_only"
	if c.cooldowns.has(a["id"]):
		return "why_cooldown"
	var s := c.sheet
	match a["id"]:
		"second_wind", "action_surge":
			if not s.has_resource(a["id"]):
				return "why_no_uses"
		"lay_on_hands":
			if not s.has_resource("lay_on_hands"):
				return "why_no_uses"
		"bardic_inspiration":
			if not s.has_resource("bardic_inspiration"):
				return "why_no_uses"
		"smite":
			if s.lowest_slot_for(1) == 0:
				return "why_no_slot"
	if a["kind"] == "special" and not c.recharge.get(a["special"]["id"], true):
		return "why_recharging"
	if a["kind"] == "spell":
		var lvl := int(Rules.spell(a["spell"]).get("level", 0))
		if lvl > 0 and not s.is_bug_spell(a["spell"]) and s.lowest_slot_for(lvl) == 0:
			return "why_no_slot"
	return ""


func _pay(c: Combatant, a: Dictionary) -> void:
	match a.get("cost", "action"):
		"action":
			c.actions -= 1
		"bonus":
			c.bonus -= 1
		"reaction":
			c.reaction -= 1
	if int(a.get("cooldown", 0)) > 0:
		c.cooldowns[a["id"]] = int(a["cooldown"]) + 1


# ================================================================== 目标与预览

func valid_target(c: Combatant, a: Dictionary, t: Combatant) -> bool:
	if t == null:
		return false
	match a.get("target", "creature"):
		"enemy":
			if not c.hostile_to(t) or not t.is_alive():
				return false
		"ally":
			if c.hostile_to(t) or not t.is_alive():
				return false
			if a.get("not_self", false) and t == c:
				return false
		"downed_ally":
			if c.hostile_to(t) or not t.is_down() or t.sheet.dead or t == c:
				return false
		"creature":
			if not t.is_alive():
				return false
		"self":
			return t == c
	return c.dist_to(t) <= float(a.get("range", 0)) + 0.01


## 命中率 / 豁免失败率预览（BG3 鼠标悬停显示的那个百分比）
func preview(c: Combatant, a: Dictionary, t: Combatant) -> Dictionary:
	var res := {"chance": -1.0, "kind": ""}
	if t == null:
		return res
	if a["kind"] in ["weapon", "monster"]:
		var info := _attack_info(c, a, t)
		res["chance"] = Dice.hit_chance(info["bonus"], t.ac(), info["mode"])
		res["kind"] = "hit"
		res["reasons"] = info["reasons"]
	elif a["kind"] == "spell":
		var d := Rules.spell(a["spell"])
		if d.has("attack"):
			var info := _spell_attack_info(c, a["spell"], t)
			res["chance"] = Dice.hit_chance(info["bonus"], t.ac(), info["mode"])
			res["kind"] = "hit"
			res["reasons"] = info["reasons"]
		elif d.has("save"):
			var ab: String = d["save"]["ability"]
			res["chance"] = 1.0 - Dice.save_chance(t.sheet.save_bonus(ab), c.sheet.spell_dc(a["spell"]), _save_mode(t, ab))
			res["kind"] = "save_fail"
		elif d.get("auto_hit", false):
			res["chance"] = 1.0
			res["kind"] = "hit"
	return res


## 范围内的单位（范围法术用）。origin = 施法者位置，point = 目标点
func in_area(c: Combatant, area: Dictionary, point: Vector3) -> Array[Combatant]:
	var out: Array[Combatant] = []
	var shape: String = area.get("shape", "sphere")
	var size := float(area.get("size", 0))
	var o := c.pos()
	var dir := Vector2(point.x - o.x, point.z - o.z).normalized()
	for t in combatants:
		if not t.is_alive():
			continue
		var tp := t.pos()
		var rel := Vector2(tp.x - o.x, tp.z - o.z)
		match shape:
			"sphere":
				if Vector2(tp.x - point.x, tp.z - point.z).length() <= size:
					out.append(t)
			"cone":
				if t == c:
					continue
				var along := rel.dot(dir)
				if along > 0 and along <= size and absf(rel.cross(dir)) <= along * 0.5 + 0.4:
					out.append(t)
			"cube":
				# 雷鸣波：以施法者为中心的立方体（BG3 做法），不含自己
				if t != c and absf(rel.x) <= size * 0.5 + 0.4 and absf(rel.y) <= size * 0.5 + 0.4:
					out.append(t)
	return out


# ================================================================== 执行

## target: Combatant 或 Vector3（点目标）。返回 true = 执行了。
func perform(c: Combatant, a: Dictionary, target = null) -> bool:
	var why := why_not(c, a)
	if why != "":
		return false
	var t: Combatant = target if target is Combatant else null
	var point: Vector3 = target if target is Vector3 else (t.pos() if t else c.pos())
	if a.get("target", "") == "self":
		t = c
	elif a.get("target", "") != "point" and not valid_target(c, a, t):
		return false
	if a.get("target", "") == "point" and c.pos().distance_to(point) > float(a.get("range", 0)) + 0.01 and float(a.get("range", 0)) > 0:
		return false
	_pay(c, a)
	if c.has_status(&"hidden") and a["kind"] in ["weapon", "spell", "monster"]:
		c.remove_status(&"hidden")
	var targets: Array = []
	match a["kind"]:
		"weapon":
			targets = [t]
			_weapon_attack(c, a, t)
		"monster":
			targets = [t]
			_monster_attack(c, a, t)
		"multiattack":
			targets = [t]
			_multiattack(c, t)
		"special":
			targets = _special(c, a["special"], point)
		"spell":
			targets = _cast(c, a["spell"], t, point)
		"feature":
			targets = [t]
			_feature(c, a, t)
		"common", "custom":
			targets = [t]
			_common(c, a, t)
	acted.emit(c, a, targets)
	_check_end()
	return true


# ------------------------------------------------------------------ 攻击

func _attack_info(c: Combatant, a: Dictionary, t: Combatant) -> Dictionary:
	var ranged := false
	var bonus := 0
	var normal_range := REACH
	if a["kind"] == "monster":
		var m: Dictionary = c.sheet.monster_attacks[a["attack_index"]]
		ranged = m["kind"] == "ranged"
		bonus = int(m["to_hit"])
		normal_range = float(m["range"]) if ranged else float(m["range"]) + REACH - 1.5
	else:
		var w := Rules.weapon(a["weapon"])
		ranged = a.get("ranged", false)
		bonus = c.sheet.weapon_attack_bonus(a["weapon"])
		if ranged:
			normal_range = float(w.get("range", [9, 9])[0])
	var m := _adv(c, t, ranged, normal_range)
	return {"bonus": bonus, "mode": m["mode"], "reasons": m["reasons"], "ranged": ranged}


func _spell_attack_info(c: Combatant, sp: String, t: Combatant) -> Dictionary:
	var d := Rules.spell(sp)
	var ranged: bool = d["attack"] == "ranged_spell"
	var m := _adv(c, t, ranged, float(d.get("range", 18)))
	if d.get("special", "") == "adv_vs_metal_armor" and t.sheet.wears_metal_armor():
		m["reasons"].append("adv_metal")
		m["mode"] = _combine(m["reasons"])
	return {"bonus": c.sheet.spell_attack_bonus(sp), "mode": m["mode"], "reasons": m["reasons"]}


## 优势/劣势来源。reasons 里 adv_ 开头算优势，dis_ 开头算劣势；两边都有则抵消。
func _adv(c: Combatant, t: Combatant, ranged: bool, normal_range: float) -> Dictionary:
	var r: Array = []
	var d := c.dist_to(t)
	if t.has_status(&"prone") or t.is_down():
		r.append("dis_target_prone" if (ranged and d > REACH) else "adv_target_prone")
	if c.has_status(&"prone"):
		r.append("dis_prone")
	if t.has_status(&"dodging"):
		r.append("dis_dodging")
	if c.has_status(&"hidden"):
		r.append("adv_hidden")
	if c.has_status(&"mocked"):
		r.append("dis_mocked")
	if ranged:
		if d > normal_range:
			r.append("dis_long_range")
		for o in combatants:
			if o.hostile_to(c) and o.can_act() and c.dist_to(o) <= REACH:
				r.append("dis_ranged_in_melee")
				break
	if "pack_tactics" in c.sheet.traits:
		for o in combatants:
			if o != c and not o.hostile_to(c) and o.can_act() and o.dist_to(t) <= REACH:
				r.append("adv_pack_tactics")
				break
	return {"mode": _combine(r), "reasons": r}


func _combine(reasons: Array) -> int:
	var adv := reasons.any(func(x): return x.begins_with("adv_"))
	var dis := reasons.any(func(x): return x.begins_with("dis_"))
	return (1 if adv else 0) - (1 if dis else 0)


## 攻击骰：处理祝福、激励、语出惊人、护盾术。返回 {hit, crit, roll, total}
func _roll_attack(c: Combatant, t: Combatant, bonus: int, mode: int, label: String) -> Dictionary:
	var r := Dice.d20(bonus, mode)
	var extra := 0
	var extra_txt := ""
	if c.has_status(&"blessed"):
		var b := Dice.roll("1d4")
		extra += b.total
		extra_txt += "+%s" % b
	if c.has_status(&"inspired"):
		var b := Dice.roll("1d6")
		extra += b.total
		extra_txt += "+%s" % b
		c.remove_status(&"inspired")
	if c.has_status(&"mocked"):
		c.remove_status(&"mocked")
	var total := r.total + extra
	var crit := r.is_nat20()
	var hit := crit or (not r.is_nat1() and total >= t.ac())
	# 反应：护盾术（被打的一方）
	if hit and not crit:
		hit = not _try_shield(t, total)
	# 反应：语出惊人（诗人保护队友）
	if hit and not crit:
		var cw := _try_cutting_words(c, t, total)
		if cw > 0:
			total -= cw
			extra_txt += "-%d" % cw
			hit = total >= t.ac()
	if t.is_down() and c.dist_to(t) <= REACH and hit:
		crit = true
	var res_key := "log_crit" if crit else ("log_hit" if hit else "log_miss")
	log_text("log_attack_roll", [c.display_name(), label, t.display_name(), _d20_str(r) + extra_txt, total, t.ac(), TextDB.line("rules", res_key)])
	if not hit:
		floated.emit(t, TextDB.line("rules", "float_miss"), &"miss")
	return {"hit": hit, "crit": crit, "natural": r.natural, "total": total}


func _weapon_attack(c: Combatant, a: Dictionary, t: Combatant) -> void:
	var info := _attack_info(c, a, t)
	var wname := TextDB.line("rules", "weapon_" + a["weapon"])
	var res := _roll_attack(c, t, info["bonus"], info["mode"], wname)
	Meta.bump("attacks")
	if not res["hit"]:
		return
	var w := Rules.weapon(a["weapon"])
	var expr := c.sheet.weapon_damage_expr(a["weapon"])
	if a.get("offhand", false):
		# 双武器战斗：副手不加正的属性调整值
		expr = w.get("dice", "1")
	var parts: Array = [[expr, w.get("type", "bludgeoning")]]
	# 偷袭：每回合一次，灵巧或远程武器，有优势或目标身边有我方
	if c.sheet.has_feature("sneak_attack") and not c.sneak_used and ("finesse" in w.get("props", []) or info["ranged"]):
		var ally_near := combatants.any(func(o): return o != c and not o.hostile_to(c) and o.can_act() and o.dist_to(t) <= REACH)
		if info["mode"] == 1 or (ally_near and info["mode"] != -1):
			c.sneak_used = true
			parts.append(["%dd6" % ceili(c.sheet.class_level("rogue") / 2.0), w.get("type", "piercing"), "sneak_attack"])
	# 至圣斩
	if a.get("smite", false):
		var lvl := c.sheet.lowest_slot_for(1)
		if lvl > 0 and c.sheet.spend_slot(lvl):
			var n := 2 + (lvl - 1)
			if t.sheet.is_monster and Rules.monsters.get(t.sheet.monster_kind, {}).get("undead", false):
				n += 1
			parts.append(["%dd8" % mini(n, 5), "radiant", "divine_smite"])
	_add_hex(c, t, parts)
	_deal(c, t, parts, res["crit"])


func _monster_attack(c: Combatant, a: Dictionary, t: Combatant) -> void:
	var m: Dictionary = c.sheet.monster_attacks[a["attack_index"]]
	var info := _attack_info(c, a, t)
	var res := _roll_attack(c, t, info["bonus"], info["mode"], TextDB.line("rules", "weapon_" + m["id"]))
	if not res["hit"]:
		return
	var parts: Array = [[m["dice"], m["type"]]]
	if m.has("extra"):
		parts.append([m["extra"][0], m["extra"][1]])
	# 群体优势（大地精）：每回合一次，目标身边有它的同伴时 +2d6
	if "martial_advantage" in c.sheet.traits and not c.sneak_used:
		if combatants.any(func(o): return o != c and not o.hostile_to(c) and o.can_act() and o.dist_to(t) <= REACH):
			c.sneak_used = true
			parts.append(["2d6", m["type"], "martial_advantage"])
	_deal(c, t, parts, res["crit"])
	if m.has("on_hit_save") and t.is_alive() and not t.is_down():
		var sv: Dictionary = m["on_hit_save"]
		if not _save(t, sv["ability"], int(sv["dc"])):
			t.add_status(StringName(sv["status"]), 99)


## 多重攻击：按 stat block 的顺序打；目标死了就换身边另一个
func _multiattack(c: Combatant, t: Combatant) -> void:
	var md: Dictionary = Rules.monsters.get(c.sheet.monster_kind, {})
	for i in md.get("multiattack", []):
		var m: Dictionary = c.sheet.monster_attacks[int(i)]
		var reach := float(m["range"]) + REACH - 1.5
		if t == null or not t.is_alive() or t.is_down() or c.dist_to(t) > reach:
			t = null
			for o in combatants:
				if o.hostile_to(c) and o.can_act() and c.dist_to(o) <= reach:
					t = o
					break
		if t == null:
			continue
		_monster_attack(c, {"kind": "monster", "attack_index": int(i)}, t)
		if not active:
			return


## 充能技能（龙息）：锥形范围豁免
func _special(c: Combatant, sp: Dictionary, point: Vector3) -> Array:
	c.recharge[sp["id"]] = false
	log_text("log_special", [c.display_name(), TextDB.line("rules", "special_" + sp["id"])])
	var targets := in_area(c, sp["area"], point)
	for t in targets:
		var ok := _save(t, sp["save"]["ability"], int(sp["save"]["dc"]))
		var r := Dice.roll(sp["damage"]["dice"])
		var amount: int = r.total
		if ok:
			amount = amount / 2 if sp["save"].get("half", false) else 0
		if amount > 0:
			var dealt := _apply_typed(t, amount, sp["damage"]["type"])
			log_text("log_damage", [t.display_name(), dealt, "%s %s" % [r, TextDB.line("rules", "dmg_" + sp["damage"]["type"])]])
			floated.emit(t, str(dealt), &"damage")
			_after_damage(c, t, dealt, false, sp["damage"]["type"])
	return targets


func _check_phase(t: Combatant) -> void:
	var md: Dictionary = Rules.monsters.get(t.sheet.monster_kind, {})
	var phases: Array = md.get("phases", [])
	for i in phases.size():
		var ph := i + 2
		if t.phase < ph and t.sheet.hp > 0 and float(t.sheet.hp) / t.sheet.max_hp <= float(phases[i]):
			t.phase = ph
			log_text("log_phase", [t.display_name()])
			boss_phase.emit(t, ph)


func _add_hex(c: Combatant, t: Combatant, parts: Array) -> void:
	if t.has_status(&"hexed") and t.statuses[&"hexed"]["source"] == c:
		parts.append(["1d6", "necrotic", "hex"])


## parts: [[expr, type, (source)], ...]
func _deal(c: Combatant, t: Combatant, parts: Array, crit: bool) -> int:
	var total := 0
	var txt: Array = []
	var main_type := ""
	for p in parts:
		var r := Dice.roll(p[0], crit)
		total += _apply_typed(t, r.total, p[1])
		txt.append("%s %s" % [r, TextDB.line("rules", "dmg_" + p[1])])
		if main_type == "":
			main_type = p[1]
	log_text("log_damage", [t.display_name(), total, " + ".join(txt)])
	floated.emit(t, str(total), &"crit" if crit else &"damage")
	_after_damage(c, t, total, crit, main_type)
	return total


## 抗性/易伤/免疫在 sheet.apply_damage 里处理；这里返回扣掉的血
func _apply_typed(t: Combatant, amount: int, dtype: String) -> int:
	return t.sheet.apply_damage(amount, dtype)


func _after_damage(src: Combatant, t: Combatant, amount: int, crit: bool, dtype: String) -> void:
	if amount <= 0:
		return
	if t.sheet.is_monster:
		_check_phase(t)
	# 专注检定
	if not t.concentration.is_empty():
		if not _save(t, "con", maxi(10, amount / 2)):
			_break_concentration(t)
	# 倒地中受伤 = 死亡豁免失败
	if t.is_down() and not t.sheet.is_monster:
		if t.has_status(&"downed"):
			t.sheet.death_failures += 2 if crit else 1
			_check_death(t)
		else:
			_go_down(t)
	elif t.is_down() and t.sheet.is_monster:
		# 不死坚韧
		if "undead_fortitude" in t.sheet.traits and dtype != "radiant" and not crit:
			if _save(t, "con", 5 + amount):
				t.sheet.hp = 1
				log_text("log_undead_fortitude", [t.display_name()])
				return
		_monster_dies(src, t)
	_on_attacked_reactions(src, t, true)


func _go_down(t: Combatant) -> void:
	t.add_status(&"downed", 999)
	t.add_status(&"prone", 999)
	_break_concentration(t)
	log_text("log_downed", [t.display_name()])
	Meta.bump("downed_" + String(t.id()))


func _monster_dies(src: Combatant, t: Combatant) -> void:
	log_text("log_killed", [t.display_name()])
	monster_killed.emit(t)
	floated.emit(t, TextDB.line("rules", "float_dead"), &"dead")
	# 邪魔之赐（邪术师·邪魔宗主）：击杀敌人获得临时生命
	if src and src.sheet.choices.get("patron", "") == "fiend" and src.sheet.class_level("warlock") > 0:
		src.sheet.temp_hp = maxi(src.sheet.temp_hp, src.sheet.mod("cha") + src.sheet.class_level("warlock"))
	for o in combatants:
		if o.has_status(&"hexed") and o == t:
			o.remove_status(&"hexed")
	if t.node and t.node.has_method("on_died"):
		t.node.on_died()


func _death_save(c: Combatant) -> void:
	var r := Dice.d20()
	if r.is_nat20():
		c.sheet.heal(1)
		c.remove_status(&"downed")
		log_text("log_death_save_nat20", [c.display_name()])
		return
	if r.natural >= 10:
		c.sheet.death_successes += 1
	else:
		c.sheet.death_failures += 2 if r.is_nat1() else 1
	log_text("log_death_save", [c.display_name(), r.natural, c.sheet.death_successes, c.sheet.death_failures])
	if c.sheet.death_successes >= 3:
		c.remove_status(&"downed")
		c.add_status(&"stable", 999)
		log_text("log_stable", [c.display_name()])
	_check_death(c)


func _check_death(c: Combatant) -> void:
	if c.sheet.death_failures >= 3 and not c.sheet.dead:
		c.sheet.dead = true
		log_text("log_died", [c.display_name()])
		Meta.bump("died_" + String(c.id()))


func _save(t: Combatant, ab: String, dc: int) -> bool:
	var bonus := t.sheet.save_bonus(ab)
	var r := Dice.d20(bonus, _save_mode(t, ab))
	var extra := 0
	if t.has_status(&"blessed"):
		extra += Dice.roll("1d4").total
	if t.has_status(&"inspired"):
		extra += Dice.roll("1d6").total
		t.remove_status(&"inspired")
	var ok := r.total + extra >= dc
	log_text("log_save", [t.display_name(), TextDB.line("rules", "ab_" + ab), _d20_str(r), r.total + extra, dc,
		TextDB.line("rules", "log_save_ok" if ok else "log_save_fail")])
	return ok


func _save_mode(t: Combatant, ab: String) -> int:
	if t.has_status(&"dodging") and ab == "dex":
		return 1
	return 0


# ------------------------------------------------------------------ 法术

func _cast(c: Combatant, sp: String, t: Combatant, point: Vector3) -> Array:
	var d := Rules.spell(sp)
	var base := int(d.get("level", 0))
	var slot := base
	var bug := c.sheet.is_bug_spell(sp)
	if base > 0 and not bug:
		slot = c.sheet.lowest_slot_for(base)
		c.sheet.spend_slot(slot)
	log_text("log_cast", [c.display_name(), TextDB.line("rules", "spell_" + sp), slot])
	Meta.bump("cast_" + sp)
	if bug:
		Bus.report(&"husband_fireball", c.id(), point)
		Meta.bump("bug_fireball_casts")
	var up := maxi(0, slot - base)
	if d.get("concentration", false):
		_break_concentration(c)
	var targets: Array[Combatant] = []
	if d.has("area"):
		targets = in_area(c, d["area"], point)
	elif t:
		targets = [t]
	# 祝福：最多 3 个目标——这里一次点一个，自动加上附近的队友
	if d.has("max_targets") and t:
		for o in combatants:
			if targets.size() >= int(d["max_targets"]):
				break
			if o != t and not o.hostile_to(c) and o.can_act() and c.dist_to(o) <= float(d["range"]):
				targets.append(o)
	for tg in targets:
		_spell_effect(c, sp, d, tg, up)
	if d.get("concentration", false):
		c.concentration = {"spell": sp, "targets": targets}
	return targets


func _spell_effect(c: Combatant, sp: String, d: Dictionary, t: Combatant, up: int) -> void:
	var dmg: Dictionary = d.get("damage", {})
	var dmg_expr: String = dmg.get("dice", "")
	if up > 0 and dmg.has("upcast"):
		dmg_expr = _add_dice(dmg_expr, dmg["upcast"], up)
	if d.get("auto_hit", false):
		var darts := int(d.get("darts", 1)) + up * int(d.get("upcast_darts", 0))
		var parts: Array = []
		for i in darts:
			parts.append([dmg_expr, dmg["type"]])
		_deal(c, t, parts, false)
		return
	if d.has("attack"):
		var info := _spell_attack_info(c, sp, t)
		var res := _roll_attack(c, t, info["bonus"], info["mode"], TextDB.line("rules", "spell_" + sp))
		if res["hit"]:
			var parts: Array = [[dmg_expr, dmg["type"]]]
			_add_hex(c, t, parts)
			_deal(c, t, parts, res["crit"])
			if d.has("on_hit_status") and t.is_alive():
				t.add_status(StringName(d["on_hit_status"]["id"]), int(d["on_hit_status"]["turns"]), c)
		return
	if d.has("save"):
		var ok := _save(t, d["save"]["ability"], c.sheet.spell_dc(sp))
		if dmg_expr != "":
			var r := Dice.roll(dmg_expr)
			var amount: int = r.total
			if ok:
				amount = amount / 2 if d["save"].get("half", false) else 0
			if amount > 0:
				var dealt := _apply_typed(t, amount, dmg["type"])
				log_text("log_damage", [t.display_name(), dealt, "%s %s" % [r, TextDB.line("rules", "dmg_" + dmg["type"])]])
				floated.emit(t, str(dealt), &"damage")
				_after_damage(c, t, dealt, false, dmg["type"])
			elif ok:
				floated.emit(t, TextDB.line("rules", "float_saved"), &"miss")
		if not ok:
			if d.has("on_fail_status") and t.is_alive():
				t.add_status(StringName(d["on_fail_status"]["id"]), int(d["on_fail_status"]["turns"]), c)
			if d.has("on_fail_push"):
				_push(c, t, float(d["on_fail_push"]))
		return
	if d.has("heal"):
		var h: Dictionary = d["heal"]
		var expr: String = h["dice"]
		if up > 0 and h.has("upcast"):
			expr = _add_dice(expr, h["upcast"], up)
		var r := Dice.roll(expr)
		var amount := r.total + (c.sheet.mod(c.sheet.spell_ability(sp)) if h.get("add_mod", false) else 0)
		_heal(c, t, amount, str(r))
		return
	if d.has("status"):
		t.add_status(StringName(d["status"]["id"]), int(d["status"]["turns"]), c)
		log_text("log_status", [t.display_name(), TextDB.line("rules", "status_" + d["status"]["id"])])


func _add_dice(expr: String, add: String, times: int) -> String:
	var p := Dice.parse(expr)
	var q := Dice.parse(add)
	if p[1] != q[1]:
		return expr
	var n: int = p[0] + q[0] * times
	return "%dd%d%s" % [n, p[1], ("+%d" % p[2]) if p[2] > 0 else ""]


func _heal(src: Combatant, t: Combatant, amount: int, detail: String) -> void:
	var was_down := t.is_down()
	var got := t.sheet.heal(amount)
	if was_down and not t.is_down():
		t.remove_status(&"downed")
		t.remove_status(&"stable")
	log_text("log_heal", [t.display_name(), got, detail])
	floated.emit(t, "+%d" % got, &"heal")


func _push(c: Combatant, t: Combatant, dist: float) -> void:
	var dir := t.pos() - c.pos()
	dir.y = 0
	if dir.length() < 0.01:
		return
	t.set_pos(t.pos() + dir.normalized() * dist)


func _break_concentration(c: Combatant) -> void:
	if c.concentration.is_empty():
		return
	var sp: String = c.concentration["spell"]
	var st: Dictionary = Rules.spell(sp).get("status", {})
	if st.has("id"):
		for t in c.concentration.get("targets", []):
			t.remove_status(StringName(st["id"]))
	c.concentration = {}
	log_text("log_concentration_lost", [c.display_name(), TextDB.line("rules", "spell_" + sp)])


# ------------------------------------------------------------------ 反应

func _try_shield(t: Combatant, total: int) -> bool:
	if t.reaction <= 0 or t.has_status(&"no_reactions") or not ("shield" in t.sheet.spells_known):
		return false
	if total >= t.ac() + 5 or t.sheet.lowest_slot_for(1) == 0:
		return false
	t.reaction -= 1
	t.sheet.spend_slot(t.sheet.lowest_slot_for(1))
	t.add_status(&"shield_spell", 1)
	log_text("log_reaction_shield", [t.display_name()])
	return true


func _try_cutting_words(attacker: Combatant, t: Combatant, total: int) -> int:
	for b in combatants:
		if b.team != t.team or not b.can_act() or b.reaction <= 0 or b.has_status(&"no_reactions"):
			continue
		if b.sheet.choices.get("bard_college", "") != "lore" or b.sheet.class_level("bard") < 3:
			continue
		if not b.sheet.has_resource("bardic_inspiration") or b.dist_to(attacker) > 18.0:
			continue
		if total - t.ac() > 3:
			continue
		b.reaction -= 1
		b.sheet.spend_resource("bardic_inspiration")
		var r := Dice.roll("1d6")
		log_text("log_reaction_cutting_words", [b.display_name(), attacker.display_name(), r.total])
		return r.total
	return 0


func _on_attacked_reactions(attacker: Combatant, t: Combatant, damaged: bool) -> void:
	# 炼狱叱喝：受到伤害后
	if damaged and attacker and attacker != t and t.can_act() and t.reaction > 0 and not t.has_status(&"no_reactions") \
			and "hellish_rebuke" in t.sheet.spells_known and t.sheet.lowest_slot_for(1) > 0 and attacker.is_alive() \
			and t.dist_to(attacker) <= 18.0:
		t.reaction -= 1
		var slot := t.sheet.lowest_slot_for(1)
		t.sheet.spend_slot(slot)
		log_text("log_reaction", [t.display_name(), TextDB.line("rules", "spell_hellish_rebuke")])
		_spell_effect(t, "hellish_rebuke", Rules.spell("hellish_rebuke"), attacker, slot - 1)


# ------------------------------------------------------------------ 特性 / 通用行动

func _feature(c: Combatant, a: Dictionary, t: Combatant) -> void:
	var s := c.sheet
	match a["id"]:
		"second_wind":
			s.spend_resource("second_wind")
			var r := Dice.roll("1d10+%d" % s.class_level("fighter"))
			_heal(c, c, r.total, str(r))
		"action_surge":
			s.spend_resource("action_surge")
			c.actions += 1
			log_text("log_feature", [c.display_name(), TextDB.line("rules", "feat_action_surge")])
		"lay_on_hands":
			var need := t.sheet.max_hp - t.sheet.hp
			var amount := mini(need if need > 0 else 1, int(s.resources["lay_on_hands"]))
			s.spend_resource("lay_on_hands", amount)
			_heal(c, t, amount, str(amount))
		"bardic_inspiration":
			s.spend_resource("bardic_inspiration")
			t.add_status(&"inspired", 100, c)
			log_text("log_status", [t.display_name(), TextDB.line("rules", "status_inspired")])
		"cunning_dash":
			c.move_left += c.speed()
			log_text("log_feature", [c.display_name(), TextDB.line("rules", "act_dash")])
		"cunning_disengage":
			c.add_status(&"disengaged", 1)
			log_text("log_feature", [c.display_name(), TextDB.line("rules", "act_disengage")])


func _common(c: Combatant, a: Dictionary, t: Combatant) -> void:
	match a["id"]:
		"dash":
			c.move_left += c.speed()
		"disengage":
			c.add_status(&"disengaged", 1)
		"dodge":
			c.add_status(&"dodging", 1)
		"help":
			_heal(c, t, 1, "1")
		"lie_down":
			c.add_status(&"lying_down", 1)
			Meta.bump("lay_down")
			Bus.report(&"player_lay_down", c.id())
			return
		"load_save":
			_load_save(c)
			return
	log_text("log_feature", [c.display_name(), TextDB.line("rules", "act_" + a["id"])])


## SL 的【读取存档】：战斗回到开始时的状态。没有缺陷，没有代价。
func _load_save(c: Combatant) -> void:
	Meta.bump("sl_load_save")
	for x in combatants:
		if _start_snapshot.has(x):
			x.restore(_start_snapshot[x])
	round_num = 1
	turn_index = order.find(c)
	c.actions = 1
	c.bonus = 1
	c.reaction = 1
	c.move_left = c.speed()
	Bus.report(&"player_load", c.id())
	round_started.emit(round_num)


# ================================================================== 移动

## 沿路径移动。路径长度超出剩余移动力时截断。触发借机攻击。
## 返回实际走到的路径。
func move_along(c: Combatant, path: PackedVector3Array) -> PackedVector3Array:
	if not active or current() != c or path.size() < 2 or not c.can_act():
		return PackedVector3Array()
	var out := PackedVector3Array([path[0]])
	var left := c.move_left
	var threatened := {}
	for o in combatants:
		if o.hostile_to(c) and o.can_act() and o.dist_to(c) <= REACH:
			threatened[o] = true
	var cur := path[0]
	for i in range(1, path.size()):
		var seg := path[i] - cur
		var len := Vector2(seg.x, seg.z).length()
		if len <= 0.0001:
			continue
		var step := minf(len, left)
		var nxt := cur + seg * (step / len)
		# 每 0.25 米检查一次是否离开了谁的触及范围
		var n := maxi(1, ceili(step / 0.25))
		for k in n:
			var p := cur.lerp(nxt, float(k + 1) / n)
			c.set_pos(p)
			for o in threatened.keys():
				if threatened[o] and o.dist_to(c) > REACH:
					threatened[o] = false
					_opportunity_attack(o, c)
					if not c.can_act():
						out.append(p)
						c.move_left = maxf(0.0, left - step * float(k + 1) / n)
						moved.emit(c, out)
						return out
		left -= step
		cur = nxt
		out.append(cur)
		if left <= 0.0001:
			break
	c.move_left = left
	moved.emit(c, out)
	return out


func _opportunity_attack(o: Combatant, c: Combatant) -> void:
	if c.has_status(&"disengaged") or o.reaction <= 0 or o.has_status(&"no_reactions"):
		return
	o.reaction -= 1
	log_text("log_opportunity", [o.display_name(), c.display_name()])
	if o.sheet.is_monster:
		for i in o.sheet.monster_attacks.size():
			if o.sheet.monster_attacks[i]["kind"] == "melee":
				_monster_attack(o, {"kind": "monster", "attack_index": i}, c)
				return
	else:
		_weapon_attack(o, {"kind": "weapon", "weapon": o.sheet.equipment.get("main_hand", "unarmed")}, c)


# ================================================================== 日志

func log_text(key: String, args: Array) -> void:
	var fmt := TextDB.line("rules", key)
	if fmt == "":
		fmt = key
	var txt: String = fmt % args if args.size() > 0 and fmt.count("%") > 0 else fmt
	logged.emit(txt)


func _d20_str(r: Dice.D20) -> String:
	var s := "d20(%d" % r.natural
	if r.mode != 0:
		s += "/%d %s" % [r.other, TextDB.line("rules", "adv" if r.mode == 1 else "dis")]
	s += ")"
	if r.bonus > 0:
		s += "+%d" % r.bonus
	elif r.bonus < 0:
		s += "%d" % r.bonus
	return s
