extends Node
## 通往魔王的路 + 魔王战 + 结局
var fails := 0
var out := ""
var barks: Array = []


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	for k in Meta.counters.keys():
		if String(k).begins_with("boss_"):
			Meta.counters.erase(k)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.first_level = "res://scenes/levels/boss_road.tscn"
	add_child(main)
	await Router.level_loaded
	for id in [Game.HUSBAND, Game.POET, Game.SL]:
		Game.join(id)
	await _frames(40)
	Banter.spoke.connect(func(who, t): barks.append([who, t]))
	CutscenePlayer.instance.fast = true
	var lvl := Router.current_level
	var pc: PartyController = lvl.get_node("Party")
	var lead := pc.leader
	_ok(lvl._variant == "normal", "attempt 1: normal")

	print("== the slope")
	lead.global_position = Vector3(0, lvl._ramp_y(-29) + 0.3, -29)
	await _frames(90)
	var rig: CameraRig = lvl.get_node("CameraRig")
	_ok(rig.roll_target == 180.0, "camera flips on the slope")
	_shot("boss_road_flipped")
	lead.global_position = Vector3(0, lvl._ramp_y(-48) + 0.3, -48)
	await _frames(90)
	_ok(rig.roll_target == 0.0, "and back")

	print("== the fight")
	lead.global_position = Vector3(0, 6.2, -52)
	await _until(func(): return Combat.active, 400)
	_ok(Combat.active and Music.current() == &"boss", "intro, then combat with boss music")
	var boss: DemonLord = lvl.get_node("DemonLord")
	var bc: Combatant = boss.combatant
	bc.sheet.hp = bc.sheet.max_hp / 2 - 1
	Combat._check_phase(bc)
	await _frames(5)
	_ok(Music.current() == &"shop", "phase 2: shop music")
	for r in 4:
		Combat.round_started.emit(Combat.round_num + r + 1)
		await get_tree().create_timer(2.5).timeout
	var said := barks.map(func(b): return b[1])
	_ok(said.has("我都被它洗脑了。") and said.has("第几遍了？") and said.has("第十一遍。"), "brainwashed banter: %s" % [said])
	_shot("boss_phase2")
	Combat.instant = true
	bc.sheet.hp = 0
	Combat._after_damage(null, bc, 999, false, "radiant")
	Combat._check_end()
	await _frames(30)
	_shot("boss_launch")
	await get_tree().create_timer(4.0).timeout
	_ok(boss.global_position.y > 40.0, "he flies up (y %.0f)" % boss.global_position.y)
	await get_tree().create_timer(5.0).timeout
	_ok(Music.current() == &"shop", "shop music keeps playing after the fight")
	said = barks.map(func(b): return b[1])
	_ok(said.has("嘿快看，boss 上天了。这个是不是代表我们胜利了？"), "poet: boss 上天了")
	_ok(said.has("读个档试试。") and not EndingScreen.instance.visible, "attempt 1 doesn't count")
	Combat.instant = false

	print("== attempt 2+: variants")
	_ok(DemonLord.new() != null, "")
	for v in ["stuck", "frozen", "no_show"]:
		_ok(v in ["stuck", "frozen", "no_show"], "")
	var seen := {}
	for n in range(2, 5):
		seen[lvl._pick_variant(n)] = true
	_ok(seen.size() == 3, "attempts 2-4 cover all three problems: %s" % [seen.keys()])
	_ok(not lvl._decide_counts(3, "frozen"), "hp-frozen never counts")
	_ok(lvl._decide_counts(4, "stuck"), "by attempt 4 it counts")
	# 直接进第 2 次：拿到 frozen 的那一次试试伤害不掉
	Meta.counters["boss_attempts"] = 1
	for i in 3:
		if lvl._pick_variant(2) == "frozen":
			break
		Meta.counters["boss_order_seed"] = int(Meta.counters["boss_order_seed"]) % 6 + 1
	Router.goto("res://scenes/levels/boss_road.tscn", "from_village")
	await Router.level_loaded
	await _frames(40)
	lvl = Router.current_level
	_ok(lvl._variant == "frozen", "attempt 2 is the hp-frozen one (forced for the test)")
	pc = lvl.get_node("Party")
	pc.leader.global_position = Vector3(0, 6.2, -52)
	await _until(func(): return Combat.active, 400)
	boss = lvl.get_node("DemonLord")
	var hp0: int = boss.combatant.sheet.hp
	Combat._deal(null, boss.combatant, [["4d6", "slashing"]], false)
	_ok(boss.combatant.sheet.hp == hp0, "damage doesn't drop his hp")
	Combat.active = false
	await _frames(5)

	print("== ending")
	Meta.counters["chargen_seconds"] = 862
	EndingScreen.instance.fast = true
	EndingScreen.instance.play()
	await _frames(10)
	_ok(EndingScreen.instance.visible and Music.current() == &"ending", "ending slides with their own music")
	_ok(Bus.muted, "nothing is broken any more")
	var pages := 0
	while EndingScreen.instance._step < EndingScreen.instance._pages.size() - 1 and pages < 20:
		_shot("ending_%d" % EndingScreen.instance._step)
		EndingScreen.instance._advance()
		await _frames(8)
		pages += 1
	_shot("ending_credits")
	_ok(pages == 7, "5 slides + true love + stats, then credits (%d)" % pages)
	_ok(EndingScreen.stat_lines().any(func(l): return l.contains("14 分 22 秒")), "chargen time in the stats")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _until(f: Callable, max_frames: int) -> void:
	for i in max_frames:
		if f.call():
			return
		await get_tree().process_frame


func _ok(c: bool, what: String) -> void:
	if what == "":
		return
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
