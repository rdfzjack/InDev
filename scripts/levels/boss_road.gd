extends LevelBase
## 通往魔王的路 + 魔王战。
##   斜坡：走到中段，镜头的上方向向量计算失败，画面倒过来（世界没有翻转）。
##   尸体一路悬空：死亡那一帧停了物理，停在离地一米的地方。
##   坡顶：魔王。登场过场（跳过是好的）→ 战斗 → 二阶段音乐换成店铺 BGM，队友被洗脑 → 上天 → 无法判定。
##
## 可以重打（重新进这一关 / 读档），每次出的问题不一样。尝试次数记在 Meta 里（不跟着读档回退）：
##   第 1 次：正常打，死了上天。不算数。
##   之后：卡在地里 / 血量不掉 / 直接不出现，顺序随机。某一次之后游戏就往下走了（结局）。
##   不解释为什么这次算数。血量不掉的那次永远打不完，只能读档或者走开。

const VILLAGE := "res://scenes/levels/village.tscn"
const TOP_Y := 6.0
const STONE := Color(0.5, 0.47, 0.5)
const VARIANTS := ["stuck", "frozen", "no_show"]

var _boss: DemonLord
var _variant := "normal"
var _attempt := 0
var _counts := false
var _phase2_round := -1
var _started := false
var _rig_flipped := false


func _init() -> void:
	music = "field"
	level_id = "boss_road"
	sky = Color(0.35, 0.22, 0.3)


func _build() -> void:
	_attempt = Meta.get_count("boss_attempts") + 1
	_variant = _pick_variant(_attempt)
	_counts = _decide_counts(_attempt, _variant)
	# 坡底
	floor_box(Vector3(0, 0, 0), Vector2(16, 22), Color(0.4, 0.38, 0.34))
	spawn("from_village", Vector3(0, 0.1, 7))
	exit_to(Vector3(0, 0, 10.5), VILLAGE, "from_bossgate", "exit_to_village")
	# 斜坡：z -11 → -51，抬高 6 米
	var run := 40.0
	var ang := atan2(TOP_Y, run)
	var ramp := Placeholders.static_box(Vector3(9, 1, sqrt(run * run + TOP_Y * TOP_Y)), STONE, 0.25, false)
	ramp.rotation.x = ang
	ramp.position = Vector3(0, TOP_Y * 0.5, -11 - run * 0.5) - Vector3(0, cos(ang), sin(ang)) * 0.5
	nav.add_child(ramp)
	# 坡上的翻转区
	var flip := Area3D.new()
	flip.name = "FlipZone"
	flip.collision_layer = 0
	flip.collision_mask = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 6, 14)
	cs.shape = box
	flip.add_child(cs)
	add_child(flip)
	flip.position = Vector3(0, TOP_Y * 0.5 + 1.5, -31)
	flip.body_entered.connect(func(b):
		if b == party_ctrl.leader:
			_flip(true))
	flip.body_exited.connect(func(b):
		if b == party_ctrl.leader:
			_flip(false))
	# 悬空的尸体（前人）
	var corpses := [Vector3(-2.5, 0, -16), Vector3(2.8, 0, -21), Vector3(-1.5, 0, -27), Vector3(3.0, 0, -36), Vector3(-3.0, 0, -44)]
	for i in corpses.size():
		var p: Vector3 = corpses[i]
		p.y = _ramp_y(p.z) + 1.0
		var c := Placeholders.capsule(Color(0.5, 0.45, 0.4).darkened(0.1 * i), 1.7)
		add_child(c)
		c.position = p
		c.rotation_degrees = Vector3(-70 + i * 17, i * 61, 25 - i * 12)
	narrate_zone(Vector3(0, _ramp_y(-15), -15), Vector3(9, 3, 3), "", "corpse_floating")
	# 坡顶：竞技场
	floor_box(Vector3(0, TOP_Y, -64), Vector2(30, 26), Color(0.3, 0.25, 0.3))
	block(Vector3(0, TOP_Y, -74), Vector3(4, 1.4, 2.5), Color(0.2, 0.12, 0.15))   # 王座
	for x in [-9.0, 9.0]:
		block(Vector3(x, TOP_Y, -60), Vector3(1.4, 5, 1.4), STONE.darkened(0.3))
		block(Vector3(x, TOP_Y, -70), Vector3(1.4, 5, 1.4), STONE.darkened(0.3))
	if _variant != "no_show":
		_boss = DemonLord.new()
		_boss.variant = _variant
		add_child(_boss)
		_boss.position = Vector3(0, TOP_Y + 0.1, -71.5)
		_boss.rotation_degrees.y = 180.0
	var arena := Area3D.new()
	arena.name = "ArenaTrigger"
	arena.collision_layer = 0
	arena.collision_mask = 2
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(28, 6, 4)
	acs.shape = abox
	arena.add_child(acs)
	add_child(arena)
	arena.position = Vector3(0, TOP_Y + 2, -54)
	arena.body_entered.connect(func(b):
		if b == party_ctrl.leader and not _started:
			_started = true
			_begin())
	Combat.boss_phase.connect(_on_phase)
	Combat.round_started.connect(_on_round)
	Combat.monster_killed.connect(_on_killed)


func _exit_tree() -> void:
	for pair in [[Combat.boss_phase, _on_phase], [Combat.round_started, _on_round], [Combat.monster_killed, _on_killed]]:
		if pair[0].is_connected(pair[1]):
			pair[0].disconnect(pair[1])


func _ramp_y(z: float) -> float:
	return clampf((-11.0 - z) / 40.0, 0.0, 1.0) * TOP_Y


func _flip(on: bool) -> void:
	var rig: CameraRig = get_node_or_null("CameraRig")
	if rig == null:
		return
	rig.roll_target = 180.0 if on else 0.0
	if on and not _rig_flipped:
		_rig_flipped = true
		Bus.report(&"camera_up_failed", &"", party_ctrl.leader.global_position)
	Meta.bump("camera_flips")


# ------------------------------------------------------------------ 尝试

## 第 1 次正常；之后按一个固定的随机顺序（种子记在 Meta 里）
static func _pick_variant(attempt: int) -> String:
	if attempt <= 1:
		return "normal"
	if Meta.get_count("boss_order_seed") == 0:
		Meta.bump("boss_order_seed", randi_range(1, 6))
	var order := VARIANTS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = Meta.get_count("boss_order_seed")
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	return order[(attempt - 2) % order.size()]


## 这一次算不算数。血量不掉的那次永远不算；第 4 次之后一定算（如果打得完）
static func _decide_counts(attempt: int, variant: String) -> bool:
	if attempt <= 1 or variant == "frozen":
		return false
	return attempt >= 4 or randf() < 0.5


func _begin() -> void:
	Meta.bump("boss_attempts")
	Meta.bump("boss_variant_" + _variant)
	var cs := Cutscene.new(&"boss_intro")
	var throne := Vector3(0, TOP_Y + 2.2, -72)
	cs.cam(Vector3(6, TOP_Y + 3.0, -58), throne)
	cs.cam_move(Vector3(2.5, TOP_Y + 2.6, -64), throne, 5.0)
	if _variant == "no_show":
		cs.line("boss_intro_empty")
		cs.wait(1.5)
	else:
		cs.line("boss_intro_01")
		cs.line("boss_intro_02")
		cs.line("boss_intro_03")
		if _variant == "stuck":
			cs.line("boss_intro_stuck")
		cs.line("boss_intro_04")
	await CutscenePlayer.play(cs)
	if _variant == "no_show":
		_no_show()
		return
	var enc := Encounter.new()
	enc.radius = 40.0
	enc.size = Vector3(0.1, 0.1, 0.1)
	add_child(enc)
	enc.global_position = _boss.global_position
	await get_tree().process_frame
	enc.start()


func _no_show() -> void:
	await get_tree().create_timer(12.0 if not CutscenePlayer.instance.fast else 0.1).timeout
	if not is_inside_tree():
		return
	Narrator.say("boss_no_show")
	await get_tree().create_timer(4.0 if not CutscenePlayer.instance.fast else 0.1).timeout
	_resolve()


# ------------------------------------------------------------------ 战斗中

func _on_phase(c: Combatant, phase: int) -> void:
	if phase == 2 and _boss and c.node == _boss:
		_phase2_round = Combat.round_num
		_bark("boss_phase2")


## 二阶段：店铺 BGM 循环。打到后面有人开始哼
func _on_round(r: int) -> void:
	if _phase2_round < 0:
		return
	match r - _phase2_round:
		1:
			_bark("boss_bark_brainwashed")
		2:
			_bark("boss_bark_which")
			await get_tree().create_timer(2.2).timeout
			_bark("boss_bark_eleventh")
		4:
			_bark("boss_bark_hum")


func _on_killed(c: Combatant) -> void:
	if _boss == null or c.node != _boss:
		return
	# 战斗音乐还在放：底音乐换成店铺 BGM，打完也不切回去
	Music.set_base(&"shop")
	set_meta("music", "shop")
	await get_tree().create_timer(2.5).timeout
	_bark("boss_bark_sky")
	await get_tree().create_timer(3.0).timeout
	Narrator.say("boss_verdict")
	await get_tree().create_timer(3.0).timeout
	_resolve()


func _resolve() -> void:
	if not is_inside_tree():
		return
	if _counts:
		Meta.bump("boss_counted_on_attempt_%d" % _attempt)
		Game.set_flag(&"game_finished")
		await get_tree().create_timer(2.0 if not CutscenePlayer.instance.fast else 0.1).timeout
		EndingScreen.instance.play()
	else:
		_bark("boss_bark_reload")


func _bark(key: String) -> void:
	var r := TextDB.row("cutscene", key)
	var who := StringName(r.get("speaker", "narrator"))
	var text := TextDB.line("cutscene", key)
	if who == &"narrator":
		Narrator.show_text(text)
	elif Game.in_party(who) or who == &"demon_lord":
		Banter.say(who, text)
