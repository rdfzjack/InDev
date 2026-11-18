class_name LevelUp
## 升级规则（5e，1-3 级）。升级界面和测试都走这里。
##
## plan(sheet, class) 告诉你这一级会得到什么、要做哪些选择；
## recommended() 给出预选（data/rules/party.json 的推荐路线，没有就按顺序填）；
## validate() 检查选择是否合法；apply() 真正升级。
##
## step 格式（和 party.json 的 levels[i] 一样）：
##   {"class": "wizard", "cantrips": [...], "spells": [...], "fighting_style": "...",
##    "expertise": [...], "skills": [...], "invocations": [...], <subclass key>: "..."}

const CLASSES := ["paladin", "fighter", "wizard", "bard", "rogue", "warlock"]
const FIGHTING_STYLES_DESC := ["archery", "defense", "dueling", "great_weapon_fighting", "two_weapon_fighting"]


## 每个职业能不能拿：[{class, ok, reason}]
static func class_options(s: CharacterSheet) -> Array:
	var out: Array = []
	for c in CLASSES:
		var ok := s.can_take_class(c)
		var reason := ""
		if not ok:
			reason = "lu_req_multiclass"
		out.append({"class": c, "ok": ok, "reason": reason, "level": s.class_level(c)})
	return out


static func plan(s: CharacterSheet, c: String) -> Dictionary:
	var cd: Dictionary = Rules.classes.get(c, {})
	var cl := s.class_level(c) + 1
	var first_overall := s.level() == 0
	var first_in_class := s.class_level(c) == 0
	var hd: int = cd.get("hit_die", 8)
	var hp := (hd if first_overall else hd / 2 + 1) + s.mod("con")
	var p := {
		"class": c, "class_level": cl, "char_level": s.level() + 1, "hp_gain": maxi(1, hp),
		"features": cd.get("features", {}).get(str(cl), []).duplicate(),
		"choices": [],
	}
	if first_in_class and not first_overall:
		p["proficiencies"] = cd.get("mc_armor", []) + cd.get("mc_weapons", [])
		if int(cd.get("mc_skills", 0)) > 0:
			var opts := CharacterSheet.SKILL_ABILITY.keys().filter(func(k): return not (k in s.skills))
			p["choices"].append({"type": "skills", "count": int(cd["mc_skills"]), "options": opts})
	for ch in cd.get("choices", {}).get(str(cl), []):
		var x: Dictionary = ch.duplicate(true)
		match x["type"]:
			"fighting_style":
				x["options"] = x["options"].filter(func(o): return not (o in s.fighting_styles))
				x["count"] = 1
			"expertise":
				var pool: Array = s.skills.duplicate()
				x["options"] = pool.filter(func(o): return not (o in s.expertise))
			"subclass":
				x["count"] = 1 if x["options"].size() > 0 else 0
			"invocations":
				x["options"] = x["options"].filter(func(o): return not (o in s.invocations()))
		p["choices"].append(x)
	# 法术
	var max_lvl := CharacterSheet.class_max_spell_level(c, cl)
	var list: Dictionary = cd.get("spell_list", {})
	var new_cantrips := s.cantrip_quota(c, cl) - s.known_from(c, true).size()
	if new_cantrips > 0:
		var opts: Array = list.get("0", []).filter(func(sp): return not (sp in s.cantrips))
		p["choices"].append({"type": "cantrips", "count": mini(new_cantrips, opts.size()), "options": opts})
	var new_spells := s.spell_quota(c, cl) - s.known_from(c, false).size()
	if new_spells > 0 and max_lvl > 0:
		var opts: Array = []
		for l in range(1, max_lvl + 1):
			for sp in list.get(str(l), []):
				if not (sp in s.spells_known) and not (sp in opts):
					opts.append(sp)
		p["choices"].append({"type": "spells", "count": mini(new_spells, opts.size()), "options": opts})
	return p


static func _choice_key(ch: Dictionary) -> String:
	return ch["key"] if ch["type"] == "subclass" else ch["type"]


## 预选：推荐路线里同职业同等级的那一步；没有就按顺序填
static func recommended(s: CharacterSheet, c: String) -> Dictionary:
	var p := plan(s, c)
	var path: Array = Rules.party.get(String(s.id), {}).get("levels", [])
	var rec: Dictionary = {}
	if s.level() < path.size() and path[s.level()].get("class", "") == c:
		rec = path[s.level()]
	var step := {"class": c}
	for ch in p["choices"]:
		var key := _choice_key(ch)
		var n: int = ch.get("count", 1)
		if ch["type"] == "subclass":
			step[key] = rec.get(key, ch["options"][0] if ch["options"].size() > 0 else "")
			continue
		var picked: Array = []
		var want = rec.get(key, [])
		if want is String:
			want = [want]
		for o in want:
			if o in ch["options"] and picked.size() < n:
				picked.append(o)
		for o in ch["options"]:
			if picked.size() >= n:
				break
			if not (o in picked):
				picked.append(o)
		if ch["type"] == "fighting_style":
			step[key] = picked[0] if picked.size() > 0 else ""
		else:
			step[key] = picked
	return step


## 返回空字符串 = 合法；否则是错误的 key
static func validate(s: CharacterSheet, step: Dictionary) -> String:
	var c: String = step.get("class", "")
	if not s.can_take_class(c):
		return "lu_req_multiclass"
	var p := plan(s, c)
	for ch in p["choices"]:
		var key := _choice_key(ch)
		var n: int = ch.get("count", 1)
		if ch["type"] == "subclass":
			if n > 0 and not (String(step.get(key, "")) in ch["options"]):
				return "lu_choose_more"
			continue
		var v = step.get(key, [] if ch["type"] != "fighting_style" else "")
		var arr: Array = [v] if v is String else v
		arr = arr.filter(func(x): return x != "")
		if arr.size() != n:
			return "lu_choose_more"
		for x in arr:
			if not (x in ch["options"]):
				return "lu_invalid"
	return ""


static func apply(s: CharacterSheet, step: Dictionary) -> bool:
	if validate(s, step) != "":
		return false
	return s.level_up(step)
