extends LevelBase
## 村庄（白模）。枢纽，笑点密度最高。一条主街，酒馆 / 商店 / 村长家 / 神殿，一个广场。走一圈两分钟。
##
## 主街东西向（x 轴）。北边尽头是魔王门（地图上一直标着），西边是白模区小路和营地，东边是地窖。
## 村庄 BGM 是 boss 战音乐（音乐轨道索引错误）。
##
## 南路：被害村民。走进他的触发半径就播过场，跳过是坏的（转到一半停住），每次都播，任务交完也播。
##   绕开半径从草地走就不会触发。第一次播完接到墓园任务（Dungeon 2，南边出口）。
## 铁匠（东南）：碰撞体太大，走不到跟前，隔着喊（字变大）。钥匙只能扔过来，在地上滚，有时候滚进地缝。
## 神殿大祭司：字幕全是错别字。墓园任务的发布 / 交付。
## 酒馆壮汉：少女音。

const DUNGEON := "res://scenes/levels/dungeon_1.tscn"
const CAMP := "res://scenes/levels/camp.tscn"
const DUNGEON2 := "res://scenes/levels/dungeon_2.tscn"
const WHITEBOX := "res://scenes/levels/whitebox.tscn"
const BOSS_ROAD := "res://scenes/levels/boss_road.tscn"
const MURDER_SPOT := Vector3(0, 0, 19)
const MURDER_RADIUS := 6.0
const SMITH_AT := Vector3(27, 0, 13)
const CRACK_AT := Vector3(26, 0, 8.6)

var _murder_armed := true
var _victim: Npc
var _smith: Npc

const STONE := Color(0.62, 0.6, 0.55)
const WOOD := Color(0.62, 0.45, 0.3)
const PLASTER := Color(0.85, 0.8, 0.68)


func _init() -> void:
	music = "boss"
	level_id = "village"


func _build() -> void:
	# 地面：主街 + 广场
	floor_box(Vector3(0, 0, 0), Vector2(80, 60), Color(0.5, 0.58, 0.4))
	# 路面只是画面层（不重叠碰撞、不做台阶），层间留几厘米，避免 z-fighting
	ground_decal(Vector3(0, 0, 0), Vector2(70, 8), STONE, 0.04)                    # 主街
	ground_decal(Vector3(0, 0, -2), Vector2(16, 16), STONE.lightened(0.1), 0.08)   # 广场
	ground_decal(Vector3(0, 0, -18), Vector2(6, 20), STONE, 0.04)                  # 去魔王门的路
	ground_decal(Vector3(0, 0, 17), Vector2(5, 22), STONE, 0.04)                   # 去墓园的路（南）
	block(Vector3(0, 0, -2), Vector3(2.5, 1.2, 2.5), STONE.darkened(0.2))   # 广场中间的井

	# 商店（西北）
	room(Vector2(-16, -12), Vector2(10, 8), [["s", 0.5, 2.0]], 3.5, PLASTER)
	# 酒馆（东北），门洞只有 1.4 米宽，四个人进门要打转
	room(Vector2(16, -12), Vector2(12, 9), [["s", 0.5, 1.4]], 3.5, WOOD)
	# 村长家（西南）
	room(Vector2(-16, 12), Vector2(10, 8), [["n", 0.5, 2.0]], 3.5, PLASTER)
	# 神殿（东南）
	room(Vector2(16, 12), Vector2(10, 10), [["n", 0.5, 3.0]], 5.0, Color(0.9, 0.88, 0.82))
	block(Vector3(16, 0, 14.5), Vector3(3, 1.0, 1.2), Color(0.95, 0.95, 0.9))   # 祭坛

	# 魔王门（北）：一直锁着，门后有音乐（店铺 BGM）
	wall(Vector2(-12, -28), Vector2(-2, -28), 6, Color(0.3, 0.28, 0.3))
	wall(Vector2(2, -28), Vector2(12, -28), 6, Color(0.3, 0.28, 0.3))
	var gate := Interactable.new()
	gate.name = "BossGate"
	gate.label_key = "obj_boss_gate"
	gate.size = Vector3(4, 5, 0.6)
	gate.color = Color(0.2, 0.15, 0.15)
	add_child(gate)
	gate.position = Vector3(0, 0, -28)
	gate.interacted.connect(func(_by):
		Game.set_flag(&"boss_gate_tried")
		Narrator.say("boss_gate"))
	# 第二次来门开了（墓园之后）。没有解释，没有钥匙。
	if Game.flag(&"d2_done"):
		Game.set_flag(&"boss_gate_open")
		gate.queue_free()
		var ex := exit_to(Vector3(0, 0, -28.5), BOSS_ROAD, "from_village", "exit_to_bossroad", Vector3(4, 3, 1.5))
		ex.add_to_group("map_marker")
		ex.set_meta("blink", true)
		ex.set_meta("color", Color(1, 0.3, 0.25))
	gate.add_to_group("map_marker")
	gate.set_meta("blink", true)
	gate.set_meta("color", Color(1, 0.3, 0.25))
	var behind := AudioStreamPlayer3D.new()
	behind.stream = load("res://assets/audio/music/shop.ogg")
	(behind.stream as AudioStreamOggVorbis).loop = true
	behind.unit_size = 4.0
	behind.max_distance = 22.0
	behind.autoplay = true
	add_child(behind)
	behind.position = Vector3(0, 1.5, -30)

	# 卡在墙里的鸡（商店东墙）
	var chicken := Interactable.new()
	chicken.name = "Chicken"
	chicken.label_key = "obj_chicken"
	chicken.size = Vector3(0.3, 0.35, 0.3)
	chicken.color = Color(0.95, 0.92, 0.85)
	add_child(chicken)
	chicken.position = Vector3(-10.9, 1.2, -10)
	chicken.interacted.connect(func(_by): Narrator.say("chicken"))

	# 出口
	exit_to(Vector3(36, 0, 0), DUNGEON, "from_village", "exit_to_dungeon1")
	exit_to(Vector3(-36, 0, 6), CAMP, "from_village", "exit_to_camp")
	exit_to(Vector3(-36, 0, -6), WHITEBOX, "from_village", "exit_to_whitebox")
	exit_to(Vector3(0, 0, 28), DUNGEON2, "from_village", "exit_to_dungeon2")

	# 出生点
	spawn("start", Vector3(0, 0.1, 8))
	spawn("from_dungeon", Vector3(32, 0.1, 0))
	spawn("from_camp", Vector3(-32, 0.1, 6))
	spawn("from_dungeon2", Vector3(3, 0.1, 25.5))
	spawn("from_whitebox", Vector3(-32, 0.1, -6))
	spawn("from_bossgate", Vector3(0, 0.1, -24))

	# NPC
	npc(&"shopkeeper", Vector3(-16, 0.1, -13), "res://data/dialogue/shopkeeper.dlg", "start", Color(0.75, 0.6, 0.35))
	npc(&"NPC_Villager_04", Vector3(17, 0.1, -13), "res://data/dialogue/villager04.dlg", "start", Color(0.55, 0.55, 0.6))
	npc(&"chief", Vector3(-16, 0.1, 13), "res://data/dialogue/chief.dlg", "start", Color(0.5, 0.45, 0.6))
	if not Game.in_party(Game.SL):
		npc(&"sl", Vector3(3, 0.1, -4), "res://data/dialogue/sl.dlg", "recruit", PartyController.COLORS[&"sl"])
	if not Game.in_party(Game.HUSBAND):
		npc(&"husband", Vector3(-30, 0.1, 0), "res://data/dialogue/husband.dlg", "recruit", PartyController.COLORS[&"husband"])

	npc(&"priestess", Vector3(16, 0.1, 12.6), "res://data/dialogue/priestess.dlg", "start", Color(0.95, 0.93, 0.85))
	npc(&"burly_man", Vector3(19, 0.1, -14), "res://data/dialogue/burly_man.dlg", "start", Color(0.55, 0.35, 0.25))
	_build_murder()
	_build_smith()

	# 酒馆门口打转
	var jam := DoorJam.new()
	jam.size = Vector3(5, 2, 4)
	add_child(jam)
	jam.position = Vector3(16, 0, -7.5)

	narrate_zone(Vector3(0, 0, 4), Vector3(16, 2, 4), "village_enter", "music_index_wrong")


func _after_spawn() -> void:
	if not Game.flag(&"intro_done"):
		Game.set_flag(&"intro_done")
	if Game.flag(&"murder_seen"):
		_sticky_skip_hint.call_deferred()
	DialogueBox.instance.command.connect(_on_dialogue_cmd)


func _exit_tree() -> void:
	if DialogueBox.instance and DialogueBox.instance.command.is_connected(_on_dialogue_cmd):
		DialogueBox.instance.command.disconnect(_on_dialogue_cmd)


func _on_dialogue_cmd(args: Array) -> void:
	if args.size() >= 2 and args[0] == "throw":
		_throw(String(args[1]))


# ------------------------------------------------------------------ 被害村民

func _build_murder() -> void:
	_victim = npc(&"murdered_villager", MURDER_SPOT + Vector3(0, 0.1, 0), "res://data/dialogue/murdered_villager.dlg", "start", Color(0.6, 0.55, 0.45))
	var z := Area3D.new()
	z.name = "MurderTrigger"
	z.collision_layer = 0
	z.collision_mask = 2
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = MURDER_RADIUS
	cyl.height = 3.0
	cs.shape = cyl
	cs.position.y = 1.5
	z.add_child(cs)
	add_child(z)
	z.position = MURDER_SPOT
	z.body_entered.connect(func(b):
		if b is PartyMember and b == party_ctrl.leader and _murder_armed and not Combat.active:
			_murder_armed = false
			_play_murder())
	# 离开半径之后重新上膛（任务交完也一样）
	z.body_exited.connect(func(b):
		if b is PartyMember and b == party_ctrl.leader:
			_murder_armed = true)


func _sticky_skip_hint() -> void:
	CutscenePlayer.instance.sticky_hint = true


func _play_murder() -> void:
	var first: bool = not Game.flag(&"murder_seen")
	var v := _victim
	var killer := Npc.new()
	killer.char_id = &"hooded_figure"
	killer.placeholder_color = Color(0.12, 0.1, 0.12)
	add_child(killer)
	killer.position = MURDER_SPOT + Vector3(9, 0.1, 1)
	var cs := Cutscene.new(&"murder")
	cs.skip_breaks_at = 0.5
	var c0 := MURDER_SPOT + Vector3(-5.5, 2.4, -4.5)
	var look := MURDER_SPOT + Vector3(1.5, 1.2, 0)
	cs.cam(c0, look)
	cs.cam_move(c0 + Vector3(1.5, -0.6, 1.2), look, 6.0)
	cs.run(func(): _face(v, Vector3(-1, 0, -1)))
	cs.line("murder_01")
	cs.run(func(): _slide(killer, MURDER_SPOT + Vector3(1.4, 0.1, 0), 1.4))
	cs.wait(1.5)
	cs.run(func(): _face(v, Vector3(1, 0, 0)))
	cs.line("murder_02")
	cs.line("murder_03")
	cs.run(func():
		_slide(killer, MURDER_SPOT + Vector3(0.7, 0.1, 0), 0.15)
		_fall(v))
	cs.wait(1.4)
	cs.cam(MURDER_SPOT + Vector3(3.5, 3.0, -3.0), MURDER_SPOT + Vector3(0, 0.3, 4))
	cs.run(func(): _slide(killer, Vector3(0, 0.1, 30), 2.4))
	cs.line("murder_04" if first else "murder_04_again")
	cs.finally(func():
		# 过场复位：他又站起来了
		killer.queue_free()
		if is_instance_valid(v) and v.model:
			v.model.rotation = Vector3.ZERO
			v.model.position = Vector3.ZERO)
	await CutscenePlayer.play(cs)
	Meta.bump("murder_plays")
	Game.set_flag(&"murder_plays", int(Game.flag(&"murder_plays", 0)) + 1)
	_sticky_skip_hint()
	if first:
		Game.set_flag(&"murder_seen")
		Game.set_flag(&"quest_murder")
		Narrator.say("quest_murder_start")


func _face(n: Node3D, dir: Vector3) -> void:
	var m: Node3D = n.get("model")
	if m:
		m.look_at(m.global_position + dir, Vector3.UP)


func _slide(n: Node3D, to: Vector3, sec: float) -> void:
	if not is_instance_valid(n):
		return
	var dir := to - n.global_position
	dir.y = 0
	if dir.length() > 0.05:
		_face(n, dir)
	var tw := create_tween()
	tw.tween_property(n, "global_position", to, sec)


func _fall(n: Node3D) -> void:
	var m: Node3D = n.get("model")
	if m == null:
		return
	var tw := create_tween()
	tw.tween_property(m, "rotation_degrees:x", -88.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(m, "position:y", 0.35, 0.5)


# ------------------------------------------------------------------ 铁匠

func _build_smith() -> void:
	block(SMITH_AT + Vector3(1.6, 0, 1.8), Vector3(1.2, 0.8, 0.7), Color(0.25, 0.25, 0.27))   # 铁砧
	block(SMITH_AT + Vector3(-2.4, 0, 2.6), Vector3(2.0, 1.4, 1.6), Color(0.45, 0.25, 0.2))  # 炉子
	_smith = npc(&"blacksmith", SMITH_AT + Vector3(0, 0.1, 0), "res://data/dialogue/blacksmith.dlg", "start", Color(0.4, 0.3, 0.25))
	_smith.shout = true
	_smith.interact_range = 6.2
	# 碰撞体太大：一个看不见的圆柱，半径 3.6 米，挡路也挡导航
	var big := StaticBody3D.new()
	big.name = "SmithCollider"
	big.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.6
	cyl.height = 2.5
	cs.shape = cyl
	cs.position.y = 1.25
	big.add_child(cs)
	nav.add_child(big)
	big.position = SMITH_AT
	# 地缝：在铁匠和来人之间
	ground_decal(CRACK_AT, Vector2(1.7, 0.35), Color(0.08, 0.07, 0.06), 0.06)
	var crack := Area3D.new()
	crack.name = "Crack"
	crack.collision_layer = 0
	crack.collision_mask = 8
	var ccs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.7, 0.6, 0.35)
	ccs.shape = box
	ccs.position.y = 0.3
	crack.add_child(ccs)
	add_child(crack)
	crack.position = CRACK_AT
	crack.body_entered.connect(func(b):
		if b is ItemPickup:
			b.fall_into_crack()
			Game.set_flag(&"key_in_crack"))


## 铁匠把东西扔给你：从他手里朝队长扔过去，带一点随机偏角，落地后滚
func _throw(item: String) -> void:
	await get_tree().process_frame
	var p := ItemPickup.new()
	p.item = item
	p.name = "Thrown_" + item
	add_child(p)
	# 从他头顶上方出手（人在自己那个太大的碰撞体里面，从里面扔会卡住）
	var to := party_ctrl.leader.global_position
	var dir := to - _smith.global_position
	dir.y = 0
	var dist := dir.length()
	dir = dir.normalized().rotated(Vector3.UP, deg_to_rad(randf_range(-24.0, 24.0)))
	p.global_position = _smith.global_position + Vector3(0, 2.9, 0)
	p.linear_velocity = dir * (dist * randf_range(0.75, 1.0)) + Vector3.UP * 1.5
	p.angular_velocity = Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	Meta.bump("smith_throws")
