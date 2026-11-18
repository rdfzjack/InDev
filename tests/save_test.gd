extends Node
## Save / load round trip
var fails := 0


func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/sandbox.tscn"
	add_child(main)
	await Router.level_loaded
	await _frames(20)
	Game.debug_xp_to_next_level()
	var h := Game.sheet(&"husband")
	LevelUp.apply(h, LevelUp.recommended(h, "wizard"))
	h.hp = 5
	h.spend_slot(1)
	Inv.gold = 77
	Inv.add("acid_vial", 2)
	Game.set_flag(&"test_flag", 3)
	Game.shop_state("general")["stock"][0]["qty"] = 1
	var lead: Node3D = Router.current_level.get_node("Party").leader
	lead.global_position = Vector3(5, 0.1, 3)
	await _frames(2)
	_ok(Saves.save("test"), "saved")
	var loads0 := Meta.get_count("loads")
	# 改乱
	h.hp = 1
	Inv.gold = 0
	Game.set_flag(&"test_flag", 0)
	Game.sheets = {}
	await Saves.load_slot("test")
	await _frames(10)
	var h2 := Game.sheet(&"husband")
	_ok(h2.level() == 2 and h2.class_levels.get("wizard", 0) == 1, "husband level/class restored")
	_ok(h2.hp == 5, "hp restored")
	_ok(h2.slots_free(1) == 1, "spent slot restored")
	_ok(h2.spells_known == ["magic_missile", "shield"], "spells restored")
	_ok(Inv.gold == 77 and Inv.count("acid_vial") == 2, "inventory restored")
	_ok(Game.flag(&"test_flag") == 3, "flags restored")
	_ok(Game.shop_state("general")["stock"][0]["qty"] == 1, "shop stock persists (never restocks)")
	_ok(Meta.get_count("loads") == loads0 + 1, "load counted in meta stats (not rolled back)")
	var l2: Node3D = Router.current_level.get_node("Party").leader
	_ok(l2.global_position.distance_to(Vector3(5, 0.1, 3)) < 1.0, "position restored")
	_ok(PauseMenu.fmt_playtime(-3725.0) == "-01:02:05", "playtime is shown negative")
	DirAccess.remove_absolute(Saves.path_of("test"))
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
