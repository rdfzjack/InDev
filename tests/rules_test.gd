extends Node
## Rules unit tests: godot --headless --path . res://tests/rules_test.tscn
var fails := 0


func _ready() -> void:
	Dice.rng.seed = 42
	_dice()
	_party_levels()
	_multiclass()
	_slots()
	_level_up_rules()
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _dice() -> void:
	print("== dice")
	_eq(Dice.parse("2d6+3"), [2, 6, 3], "parse 2d6+3")
	_eq(Dice.parse("1d4-1"), [1, 4, -1], "parse 1d4-1")
	_eq(Dice.parse("5"), [0, 0, 5], "parse 5")
	var r := Dice.roll("8d6")
	_ok(r.dice.size() == 8 and r.total >= 8 and r.total <= 48, "8d6 in range: %s" % r)
	_ok(Dice.roll("1d8", true).dice.size() == 2, "crit doubles dice")
	_eq(Dice.mod(15), 2, "mod 15")
	_eq(Dice.mod(8), -1, "mod 8")
	_ok(absf(Dice.hit_chance(5, 15) - 0.55) < 0.001, "hit chance +5 vs 15 = 55%")
	_ok(absf(Dice.hit_chance(5, 40) - 0.05) < 0.001, "nat20 always hits")
	_ok(absf(Dice.hit_chance(20, 5) - 0.95) < 0.001, "nat1 always misses")


func _party_levels() -> void:
	print("== party at level 1 / 3")
	var p1 := CharacterSheet.from_party(&"protagonist", 1)
	_eq(p1.level(), 1, "paladin L1")
	_eq(p1.max_hp, 12, "paladin L1 hp = 10+2")
	_eq(p1.ac(), 18, "chain mail + shield = 18")
	_eq(p1.weapon_attack_bonus("longsword"), 5, "longsword +5")
	_eq(p1.resources.get("lay_on_hands"), 5, "lay on hands 5")
	_eq(p1.slots_max, [], "paladin L1 no slots")
	var p3 := CharacterSheet.from_party(&"protagonist", 3)
	_eq(p3.max_hp, 12 + 8 + 8, "paladin L3 hp = 12+8+8")
	_eq(p3.slots_max, [3], "paladin L3 three 1st slots")
	_eq(p3.resources.get("lay_on_hands"), 15, "lay on hands 15")
	_eq(p3.weapon_damage_expr("longsword"), "1d8+5", "dueling +2 (shield is not a weapon)")
	_eq(p3.choices.get("sacred_oath"), "", "oath is empty")
	_ok(p3.has_feature("sacred_oath"), "has sacred_oath feature (blank)")

	var h1 := CharacterSheet.from_party(&"husband", 1)
	_eq(h1.class_levels, {"fighter": 1}, "husband L1 fighter")
	_eq(h1.ac(), 21, "plate + shield + defense = 21")
	_eq(h1.max_hp, 12, "fighter L1 hp 10+2")
	_ok(h1.is_bug_spell("fireball") and "fireball" in h1.all_spells(), "fireball known at L1 (bug)")
	_ok(h1.has_resource("second_wind"), "second wind")
	var h3 := CharacterSheet.from_party(&"husband", 3)
	_eq(h3.class_levels, {"fighter": 2, "wizard": 1}, "husband F2/W1")
	_eq(h3.max_hp, 12 + 6 + 8, "hp 12 + (3+1+2) + (5+1+2)")
	_eq(h3.slots_max, [2], "wizard 1 slots")
	_eq(h3.spells_known, ["magic_missile", "shield"], "wizard 1 prepared spells within quota")
	_eq(h3.save_profs, ["str", "con"], "saves from first class only")
	_ok(not ("int" in h3.save_profs), "no wizard saves")
	_ok(h3.has_resource("action_surge"), "action surge at fighter 2")
	_eq(h3.spell_dc("magic_missile"), 8 + 1 + 2, "wizard spell DC 11")

	var b3 := CharacterSheet.from_party(&"poet", 3)
	_eq(b3.slots_max, [4, 2], "bard 3 slots")
	_eq(b3.max_hp, 9 + 6 + 6, "bard hp 8+1 / 5+1 / 5+1")
	_eq(b3.resources.get("bardic_inspiration"), 3, "inspiration = cha mod")
	_eq(b3.initiative_bonus(), 2 + 1, "jack of all trades on initiative")
	_eq(b3.skill_bonus("performance"), 3 + 4, "expertise")

	var s3 := CharacterSheet.from_party(&"sl", 3)
	_eq(s3.class_levels, {"rogue": 2, "warlock": 1}, "SL R2/W1")
	_eq(s3.pact_count, 1, "pact slot 1")
	_eq(s3.pact_level, 1, "pact level 1")
	_eq(s3.slots_max, [], "no regular slots")
	_ok(s3.slots_free(1) == 1, "one 1st level slot available via pact")
	_ok("fire" in s3.resist, "tiefling fire resistance")
	_ok("light" in s3.armor_profs and not ("heavy" in s3.armor_profs), "armor profs")


func _multiclass() -> void:
	print("== multiclass rules")
	var p := CharacterSheet.from_party(&"protagonist", 1)
	_ok(not p.can_take_class("wizard"), "paladin INT 9 cannot take wizard")
	_ok(p.can_take_class("fighter"), "paladin can take fighter")
	var h := CharacterSheet.from_party(&"husband", 1)
	h.level_up({"class": "wizard"})
	_ok(not ("heavy" in Rules.classes["wizard"]["mc_armor"]), "wizard grants no armor on multiclass")
	_ok("heavy" in h.armor_profs, "heavy armor kept from fighter start")
	var weak := CharacterSheet.new()
	weak.abilities = {"str": 10, "dex": 10, "con": 10, "int": 10, "wis": 10, "cha": 10}
	weak.level_up({"class": "rogue"})
	_ok(not weak.can_take_class("rogue") == false, "can continue own class")
	_ok(not weak.can_take_class("bard"), "cannot multiclass with stats 10")


func _slots() -> void:
	print("== slots")
	var b := CharacterSheet.from_party(&"poet", 3)
	_eq(b.lowest_slot_for(1), 1, "lowest slot for L1 spell")
	for i in 4:
		b.spend_slot(1)
	_eq(b.lowest_slot_for(1), 2, "upcast to 2nd when 1st exhausted")
	b.long_rest()
	_eq(b.slots_free(1), 4, "long rest restores")
	var s := CharacterSheet.from_party(&"sl", 3)
	s.spend_slot(1)
	_eq(s.slots_free(1), 0, "pact slot spent")
	s.short_rest()
	_eq(s.slots_free(1), 1, "short rest restores pact slot")
	var t := CharacterSheet.from_party(&"sl", 3)
	_eq(t.apply_damage(10, "fire"), 5, "fire resisted")


func _eq(a, b, what: String) -> void:
	_ok(a == b, "%s (got %s, want %s)" % [what, a, b])


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _level_up_rules() -> void:
	print("== level-up rules")
	var h := CharacterSheet.from_party(&"husband", 1)
	var p := LevelUp.plan(h, "wizard")
	var kinds: Array = p["choices"].map(func(c): return c["type"])
	_ok("cantrips" in kinds and "spells" in kinds, "wizard multiclass asks for cantrips and spells")
	for ch in p["choices"]:
		if ch["type"] == "cantrips":
			_eq(ch["count"], 3, "3 cantrips")
		if ch["type"] == "spells":
			_eq(ch["count"], 2, "int 13 (+1) + wizard 1 = 2 prepared")
			_ok(not ("shatter" in ch["options"]), "no 2nd-level spells at wizard 1")
	var step := LevelUp.recommended(h, "wizard")
	_eq(LevelUp.validate(h, step), "", "recommended step is valid")
	var bad := step.duplicate(true)
	bad["spells"] = ["magic_missile", "shield", "burning_hands"]
	_eq(LevelUp.validate(h, bad), "lu_invalid" if false else "lu_choose_more", "too many spells rejected")
	_ok(LevelUp.apply(h, step), "apply")
	_eq(h.spells_known.size(), 2, "husband knows exactly 2 wizard spells")
	_ok("fireball" in h.all_spells(), "fireball still there (bug)")
	var p3 := CharacterSheet.from_party(&"poet", 3)
	_eq(p3.spells_known.size(), 6, "bard 3 knows 6 spells")
	_eq(p3.cantrips.size(), 2, "bard 3 knows 2 cantrips")
	var s3 := CharacterSheet.from_party(&"sl", 3)
	_eq(s3.spells_known.size(), 2, "warlock 1 knows 2 spells")
	var pal := CharacterSheet.from_party(&"protagonist", 2)
	_eq(pal.spells_known.size(), 3, "paladin 2: cha +2 + 1 = 3")
	var pp := LevelUp.plan(pal, "paladin")
	var oath: Array = pp["choices"].filter(func(c): return c["type"] == "subclass")
	_ok(oath.size() == 1 and oath[0]["options"].is_empty() and oath[0]["count"] == 0, "oath choice is empty")
	_eq(LevelUp.validate(pal, LevelUp.recommended(pal, "paladin")), "", "paladin 3 valid with no oath")
	# 多职业门槛
	var opts := LevelUp.class_options(CharacterSheet.from_party(&"protagonist", 1))
	var wiz: Array = opts.filter(func(o): return o["class"] == "wizard")
	_ok(not wiz[0]["ok"], "paladin cannot pick wizard (INT 9)")
	# 游荡者兼职给一个技能
	var b := CharacterSheet.from_party(&"poet", 1)
	var rp := LevelUp.plan(b, "rogue")
	_ok(rp["choices"].any(func(c): return c["type"] == "skills"), "multiclass into rogue grants a skill choice")
