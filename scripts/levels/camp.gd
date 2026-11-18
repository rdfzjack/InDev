extends LevelBase
## 营地。很小。营地对话、老公约谈、长休。全程回来三四次。
##
## 约谈（地窖打完以后）：
##   第 1 天："饭后我要和你谈话。"    → 那一晚他点不动（husband_summons_pending）
##   长休 → 第 2 天："你妄图蒙混过关。" → 又点不动
##   长休 → 第 3 天："我已经通知过你两次了……"
##   长休 → 第 4 天："我对你很失望。" → 可以选"哈哈哈"。约谈结束。
## 约谈的真正内容写在 husband.dlg 的 summons_real 里，没有任何路径能到。

const VILLAGE := "res://scenes/levels/village.tscn"


func _init() -> void:
	music = "camp"
	level_id = "camp"
	sky = Color(0.2, 0.22, 0.35)


func _build() -> void:
	floor_box(Vector3.ZERO, Vector2(30, 30), Color(0.35, 0.42, 0.3))
	block(Vector3(0, 0, 0), Vector3(1.2, 0.4, 1.2), Color(0.9, 0.45, 0.15))      # 营火
	block(Vector3(-5, 0, -4), Vector3(3, 2, 3), Color(0.6, 0.55, 0.4))           # 帐篷
	block(Vector3(5, 0, -4), Vector3(3, 2, 3), Color(0.45, 0.4, 0.5))            # 帐篷
	var bed := Interactable.new()
	bed.name = "Bedroll"
	bed.label_key = "obj_bedroll"
	bed.size = Vector3(2, 0.3, 1)
	bed.color = Color(0.55, 0.3, 0.25)
	add_child(bed)
	bed.position = Vector3(-2, 0, 3)
	bed.interacted.connect(func(_by): DialogueBox.open("res://data/dialogue/camp.dlg", "bedroll", null))
	exit_to(Vector3(0, 0, 13), VILLAGE, "from_camp", "exit_to_village")
	spawn("from_village", Vector3(0, 0.1, 9))
	Game.day_passed.connect(_on_day)


func _after_spawn() -> void:
	Narrator.say("camp_enter")
	await get_tree().create_timer(0.8).timeout
	_maybe_summons()


func _on_day(_d: int) -> void:
	# 新的一天：前一晚的约谈过去了，他又点得动了
	Game.set_flag(&"husband_summons_pending", false)
	await get_tree().create_timer(1.0).timeout
	_maybe_summons()


func _maybe_summons() -> void:
	if not Game.flag(&"d1_done") or not Game.in_party(Game.HUSBAND):
		return
	var stage := int(Game.flag(&"summons_stage", 0))
	if stage >= 4 or int(Game.flag(&"summons_day", 0)) == Game.day:
		return
	Game.set_flag(&"summons_stage", stage + 1)
	Game.set_flag(&"summons_day", Game.day)
	var h := member(Game.HUSBAND)
	DialogueBox.open("res://data/dialogue/husband.dlg", "summons_%d" % (stage + 1), h)
