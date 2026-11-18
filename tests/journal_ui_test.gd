extends Node
## 任务日志界面、日志更新横条、好感度提示、小地图目标标记（需要显示）
var fails := 0
var out := ""


func _ready() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await Router.level_loaded
	for id in [Game.HUSBAND, Game.POET, Game.SL]:
		Game.join(id)
	await _frames(40)
	var toasts: NoticeToasts = main.get_node("UI/HUD/NoticeToasts")
	Game.set_flag(&"chief_met")
	await _frames(5)
	_ok(toasts._banner.visible and (toasts._banner_title.text == Journal.title("cellar") or toasts._queue.any(func(q): return q[1] == Journal.title("cellar"))), "banner: new quest (queued)")
	Game.set_flag(&"quest_cellar")
	Game.set_flag(&"chief_pays_extra")
	Game.set_flag(&"murder_seen")
	Game.set_flag(&"quest_murder")
	Game.set_flag(&"key_thrown")
	Game.set_flag(&"warned_slot3")
	await _frames(5)
	_ok(toasts._approvals.get_child_count() > 0, "approval toast in the top-left")
	await _frames(20)
	_shot("journal_toasts")
	Journal.track("cellar")
	var marks := Journal.marker_positions(Router.current_level)
	_ok(marks.size() >= 1 and (marks[0] as Vector3).distance_to(Vector3(36, 0, 0)) < 0.5, "objective in the cellar: marks the exit to the cellar")
	Game.set_flag(&"d1_done")
	await _frames(5)
	marks = Journal.marker_positions(Router.current_level)
	var chief: Node3D = Router.current_level.get_node("chief")
	_ok(marks.size() == 1 and (marks[0] as Vector3).distance_to(chief.global_position) < 0.1, "objective: report → marks the chief")
	Journal.track("murder")
	marks = Journal.marker_positions(Router.current_level)
	_ok(marks.size() >= 1, "objective in another level: marks the exit (%d markers)" % marks.size())
	_ok(Journal.unread_count() >= 3, "unread count on the journal button (%d)" % Journal.unread_count())
	JournalScreen.toggle()
	await _frames(10)
	var js: JournalScreen = main.get_node("UI/HUD/JournalScreen")
	_ok(js.visible and js._detail.get_child_count() > 2, "journal opens")
	_shot("journal_murder")
	js._list.get_node("Q_cellar").pressed.emit()
	await _frames(5)
	_shot("journal_cellar")
	var found_lost := false
	for b in js._list.get_children():
		if b is Button and b.name == "Q_lost_goat":
			found_lost = true
	_ok(found_lost, "the lost goat is listed under finished")
	JournalScreen.toggle()
	InventoryScreen.toggle()
	Game.select(Game.POET)
	await _frames(5)
	var inv: InventoryScreen = main.get_node("UI/HUD/InventoryScreen")
	_ok(inv._approval.visible and inv._approval.text.contains("好感度"), "approval in the character panel: %s" % inv._approval.text)
	Game.select(Game.HUSBAND)
	await _frames(5)
	_ok(inv._approval.text.ends_with("你老公"), "his: %s" % inv._approval.text)
	_shot("approval_husband")
	print("\nRESULT: %s (%d failures)" % ["PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(1 if fails else 0)


func _shot(n: String) -> void:
	get_viewport().get_texture().get_image().save_png(out + "/" + n + ".png")


func _ok(c: bool, what: String) -> void:
	print("  ", "OK  " if c else "FAIL", " ", what)
	if not c:
		fails += 1


func _frames(n: int) -> void:
	for k in n:
		await get_tree().process_frame
