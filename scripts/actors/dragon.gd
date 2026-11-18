class_name Dragon
extends Enemy
## 白模区的龙。全游戏最好看的东西，站在最空的地方。
##   不打它它不会攻击你：可以走近，绕着它转，看很久（它的头会慢慢转过来看你）。
##   专属音乐从它身上放（离远了就听不见；没找到这里的人永远没听过）。
##   打完什么都不给（xp 0，结算不统计）。
##   死了以后开始平移：保持死亡姿势，沿导航网格走向生前的目标点（队长）。可以一路跟着你。

const SLIDE_SPEED := 1.6

var _head: Node3D
var _song: AudioStreamPlayer3D
var _sliding := false


func _ready() -> void:
	monster_kind = "young_red_dragon"
	height = 3.2
	super._ready()
	name = "Dragon"
	char_id = &"dragon"     # 对话里的说话人 id
	_song = AudioStreamPlayer3D.new()
	_song.stream = load("res://assets/audio/music/dragon.ogg")
	if _song.stream is AudioStreamOggVorbis:
		(_song.stream as AudioStreamOggVorbis).loop = true
	_song.unit_size = 10.0
	_song.max_distance = 45.0
	_song.volume_db = -4.0
	_song.autoplay = true
	add_child(_song)
	_song.position.y = 2.0
	Combat.combat_started.connect(func(): _song.stream_paused = true)
	Combat.combat_ended.connect(func(_w): _song.stream_paused = false)


## 占位：身体、脖子、头、两只翅膀、尾巴。美术到了换掉 Model 下面的东西。
func _build_placeholder() -> void:
	var red := Color(0.62, 0.12, 0.1)
	var body := Placeholders.box(Vector3(2.2, 1.6, 4.2), red)
	body.position = Vector3(0, 1.5, 0.4)
	model.add_child(body)
	var neck := Placeholders.box(Vector3(0.8, 0.8, 2.0), red.darkened(0.1))
	neck.position = Vector3(0, 2.5, -2.0)
	neck.rotation_degrees.x = 35.0
	model.add_child(neck)
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 3.3, -2.9)
	model.add_child(_head)
	var head := Placeholders.box(Vector3(0.9, 0.7, 1.4), red.lightened(0.08))
	head.position = Vector3(0, 0, -0.4)
	_head.add_child(head)
	for sx in [-1.0, 1.0]:
		var horn := Placeholders.box(Vector3(0.15, 0.6, 0.15), Color(0.9, 0.85, 0.7))
		horn.position = Vector3(0.3 * sx, 0.5, 0.1)
		horn.rotation_degrees.x = -30.0
		_head.add_child(horn)
		var wing := Placeholders.box(Vector3(3.2, 0.12, 2.4), red.darkened(0.3))
		wing.position = Vector3(2.4 * sx, 2.6, 0.6)
		wing.rotation_degrees.z = 22.0 * sx
		model.add_child(wing)
		for z in [-0.8, 1.6]:
			var leg := Placeholders.box(Vector3(0.5, 1.0, 0.5), red.darkened(0.2))
			leg.position = Vector3(0.9 * sx, 0.5, z)
			model.add_child(leg)
	var tail := Placeholders.box(Vector3(0.6, 0.5, 3.4), red.darkened(0.15))
	tail.position = Vector3(0, 1.0, 3.9)
	tail.rotation_degrees.x = -10.0
	model.add_child(tail)


var interact_range := 5.5
## 对话镜头：头在哪，离多远拍
var camera_scale := 3.0


func camera_head() -> Vector3:
	return _head.global_position if _head else global_position + Vector3.UP * 3.0


## 点它：对话（它不先动手）
func interact() -> bool:
	if Combat.active or sheet.hp <= 0 or _sliding:
		return false
	DialogueBox.open("res://data/dialogue/dragon.dlg", "start", self)
	return true


func _process(dt: float) -> void:
	if _sliding or Combat.active or _head == null:
		return
	# 头慢慢转过来看队长（不看就太像摆设了）
	var lead: Node3D = null
	for m in get_tree().get_nodes_in_group("party"):
		if m.get("char_id") == Game.selected:
			lead = m
	if lead == null or lead.global_position.distance_to(global_position) > 25.0:
		return
	var local: Vector3 = _head.get_parent().to_local(lead.global_position + Vector3.UP * 1.5)
	var want := atan2(-(local.x - _head.position.x), -(local.z - _head.position.z))
	_head.rotation.y = lerp_angle(_head.rotation.y, clampf(want, -1.1, 1.1), dt * 0.8)


func on_died() -> void:
	stop()
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:z", 78.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(model, "position:y", 0.9, 1.2)
	Meta.bump("dragon_killed")
	await get_tree().create_timer(2.5).timeout
	if not is_inside_tree():
		return
	# 原来的移动逻辑没关：保持死亡姿势，沿导航网格走向生前的目标点
	_sliding = true
	Bus.report(&"dragon_slides", &"", global_position)


func _physics_process(dt: float) -> void:
	if not _sliding:
		super._physics_process(dt)
		return
	var lead: Node3D = null
	for m in get_tree().get_nodes_in_group("party"):
		if m.get("char_id") == Game.selected:
			lead = m
	if lead == null:
		return
	if global_position.distance_to(lead.global_position) < 4.5:
		return
	agent.target_position = lead.global_position
	if agent.is_navigation_finished():
		return
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0
	if dir.length() > 0.01:
		global_position += dir.normalized() * SLIDE_SPEED * dt
