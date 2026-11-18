extends Node
## 任务日志 + 好感度（无头）
var fails := 0


func _ready() -> void:
	await get_tree().process_frame
	_journal_basics()
	await _cellar_paid()
	await _cellar_unasked()
	await _murder_and_subquest()
	await _summons_numeric()
	await _save_roundtrip()
	await _approval()
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _fresh() -> void:
	Game.new_game()
	Approval.reset()
	Journal.reset()
	await _settle()


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


func _journal_basics() -> void:
	print("== journal: a quest you never did")
	Journal.reset()
	_ok(Journal.state("lost_goat") == "completed", "lost goat is already completed")
	_ok(Journal.entries("lost_goat").size() == 3, "with three entries you never did")
	_ok(Journal.entries("lost_goat")[0]["step"] == "returned", "newest first")


func _cellar_paid() -> void:
	print("== cellar: accepted, paid, picked, reported")
	await _fresh()
	Game.join(Game.SL)
	Game.join(Game.POET)
	Game.set_flag(&"chief_met")
	await _settle()
	_ok(Journal.is_active("cellar") and Journal.objective("cellar") == "investigate", "talking to the chief adds the quest")
	_ok(Journal.tracked == "cellar", "new quest auto-tracked")
	var sl0 := Approval.value(&"sl")
	Game.set_flag(&"quest_cellar")
	Game.set_flag(&"chief_pays_extra")
	await _settle()
	_ok(Journal.visited("cellar", "pay_negotiated") and Approval.value(&"sl") == sl0 + 2, "pay negotiated, SL approves (+2)")
	Game.set_flag(&"d1_door_how", "pick")
	Game.set_flag(&"d1_puzzle_solved")
	await _settle()
	_ok(Journal.visited("cellar", "door_picked") and not Journal.visited("cellar", "door_forced"), "door branch: picked, not forced")
	Game.set_flag(&"d1_fight_won")
	await _settle()
	_ok(Journal.objective("cellar") == "search_deeper", "objective moves on by priority")
	Game.set_flag(&"d1_done")
	await _settle()
	_ok(Journal.visited("cellar", "cleared") and not Journal.visited("cellar", "cleared_unasked"), "cleared (asked) branch")
	_ok(Journal.objective("cellar") == "report", "objective: report to the chief")
	Game.set_flag(&"quest_cellar_reported")
	await _settle()
	_ok(Journal.state("cellar") == "completed", "closed")
	_ok(Journal.visited("cellar", "reported_paid") and not Journal.visited("cellar", "reported"), "the paid ending, not the other one")
	_ok(Game.flag(&"q_cellar_reported_paid"), "each step sets a quest flag")
	var n := Journal.entries("cellar").size()
	Game.set_flag(&"chief_looked_north")
	await _settle()
	_ok(Journal.entries("cellar").size() == n, "a closed quest no longer updates")


func _cellar_unasked() -> void:
	print("== cellar: cleared without being asked")
	await _fresh()
	Game.set_flag(&"d1_done")
	await _settle()
	_ok(Journal.is_active("cellar") and Journal.visited("cellar", "cleared_unasked") and not Journal.visited("cellar", "cleared"), "different branch, quest added late")
	_ok(Journal.objective("cellar") == "report", "still told to report")


func _murder_and_subquest() -> void:
	print("== murder: witnessed vs told, crypt key subquest")
	await _fresh()
	Game.set_flag(&"murder_seen")
	Game.set_flag(&"quest_murder")
	await _settle()
	_ok(Journal.visited("murder", "witnessed") and not Journal.visited("murder", "told"), "witnessed, so 'told' is blocked")
	_ok(Journal.is_active("crypt_key"), "subquest added under it")
	_ok(Journal.subquests("murder") == ["crypt_key"], "subquest listed under its parent")
	Game.set_flag(&"key_thrown")
	await _settle()
	_ok(Journal.objective("crypt_key") == "pick_up", "subquest objective")
	Inv.add("crypt_key")
	await _settle()
	_ok(Journal.state("crypt_key") == "completed" and Journal.visited("crypt_key", "picked"), "picked up: subquest completed")
	Game.set_flag(&"key_in_crack")
	await _settle()
	_ok(not Journal.visited("crypt_key", "lost"), "the other ending can't happen any more")
	await _fresh()
	Game.set_flag(&"quest_murder")
	await _settle()
	_ok(Journal.visited("murder", "told"), "told by the priestess instead")
	Game.set_flag(&"key_thrown")
	Game.set_flag(&"key_in_crack")
	await _settle()
	_ok(Journal.state("crypt_key") == "failed", "key lost: subquest failed")
	Game.set_flag(&"d2_boss_dead")
	Game.set_flag(&"quest_murder_done")
	await _settle()
	_ok(Journal.state("murder") == "completed" and Journal.visited("murder", "killer_dead"), "murder completed")
	await _fresh()
	Game.set_flag(&"d2_boss_dead")
	await _settle()
	_ok(Journal.visited("murder", "stranger_dead") and Journal.objective("murder") == "tell_priestess", "killed him without knowing who he was")


func _summons_numeric() -> void:
	print("== numeric conditions")
	await _fresh()
	Game.set_flag(&"summons_stage", 1)
	await _settle()
	_ok(Journal.visited("summons", "summons_1") and not Journal.visited("summons", "summons_2"), "stage 1")
	Game.set_flag(&"summons_stage", 3)
	await _settle()
	_ok(Journal.visited("summons", "summons_2") and Journal.visited("summons", "summons_3"), "stage 3 unlocks 2 and 3 in order")
	var e := Journal.entries("summons")
	_ok(e[0]["step"] == "summons_3" and e[1]["step"] == "summons_2", "chronological")


func _save_roundtrip() -> void:
	print("== save")
	await _fresh()
	Game.set_flag(&"chief_met")
	await _settle()
	var snap: Dictionary = JSON.parse_string(JSON.stringify(Journal.snapshot()))
	Journal.reset()
	_ok(not Journal.has_quest("cellar"), "reset")
	Journal.restore(snap)
	_ok(Journal.visited("cellar", "heard") and Journal.tracked == "cellar", "restored from JSON")


func _approval() -> void:
	print("== approval")
	await _fresh()
	Game.join(Game.HUSBAND)
	Game.join(Game.POET)
	Game.join(Game.SL)
	_ok(Approval.tier_of(0) == "neutral" and Approval.tier_of(25) == "medium" and Approval.tier_of(-45) == "very_low", "tiers")
	_ok(not Approval.change(&"husband", 50, "test"), "husband: not affected by anything")
	_ok(Approval.display_value(&"husband") == null and Approval.display_tier(&"husband") == "husband", "his row says 你老公")
	Approval.change(&"poet", 30, "test")
	_ok(Cond.ok("approval:poet>=30") and not Cond.ok("approval:poet>30"), "approval conditions use the real value")
	var dlg := DialogueScript.parse_cond("approval:poet>=20")
	_ok(dlg["type"] == "cond", "dialogue can check approval")
	Approval.event("player_load")
	_ok(Approval.value(&"sl") == 2, "loading a save: SL approves")
	Approval.event("player_load")
	_ok(Approval.value(&"sl") == 4, "every time (he really likes it)")
	Approval.event("friendly_fire", &"poet")
	_ok(Approval.value(&"poet") == 27, "fireball on the poet: -3")
	# 一觉醒来全乱了
	Game.day = Approval.scramble_day
	Game.rested.emit(&"long")
	_ok(Approval.scrambled, "scrambled after that long rest")
	_ok(Approval.value(&"poet") == 27 and Cond.ok("approval:poet>=27"), "but the person didn't change")
	_ok(Approval.display_offset.has(&"poet") and not Approval.display_offset.has(&"husband"), "only the display is off; his row is untouched")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(Approval.snapshot()))
	Approval.reset()
	Approval.restore(snap)
	_ok(Approval.scrambled and Approval.value(&"poet") == 27, "and it can't be changed back (saved)")
	# 警告和离队
	Approval.change(&"sl", -30, "test")
	_ok(Approval.warned.has("sl_1"), "first warning at -25")
	Approval.change(&"sl", -20, "test")
	_ok(Approval.warned.has("sl_2"), "second warning at -40")
	Approval.change(&"sl", -10, "test")
	_ok(not Game.in_party(&"sl") and Game.flag(&"left_sl"), "-50: SL leaves")
	_ok(not Approval.change(&"sl", 10, "test"), "and he doesn't come back")


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1
