class_name LevelBase
extends Node3D
## 关卡基类：白模搭建工具 + 标准配置（导航、出生点、队伍、镜头、环境、音乐、区域名）。
## 子类实现 _build()，在里面用 floor_box / wall / room / exit_to / npc / ... 搭场景。
## 美术到了以后，把白模换成 .glb 场景，交互节点（出口、NPC、陷阱、拉杆）保留即可。

@export var music := "field"
## 节点名 = 区域名的 key（area_<level_id>）
var level_id := ""
@export var sky := Color(0.62, 0.74, 0.88)

var nav: NavigationRegion3D
var party_ctrl: PartyController


func _ready() -> void:
	if level_id != "":
		name = level_id
	set_meta("music", music)
	add_child(Placeholders.environment(sky))
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add_child(nav)
	_build()
	nav.bake_navigation_mesh(false)
	party_ctrl = PartyController.new()
	party_ctrl.name = "Party"
	add_child(party_ctrl)
	var rig := CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.global_position = party_ctrl.spawn_point()
	await get_tree().process_frame
	await get_tree().process_frame
	rig.target = party_ctrl.leader
	_after_spawn()


## 子类：搭场景
func _build() -> void:
	pass


## 子类：队伍出生之后（开场对话、剧情检查）
func _after_spawn() -> void:
	pass


## 开门、拆掉障碍之后重新烘焙导航
func rebake() -> void:
	await get_tree().process_frame
	nav.bake_navigation_mesh(false)


func member(id: StringName) -> PartyMember:
	return party_ctrl.members.get(id) if party_ctrl else null


# ------------------------------------------------------------------ 白模工具

func floor_box(center: Vector3, size: Vector2, color := Color(0.55, 0.6, 0.45)) -> StaticBody3D:
	var b := Placeholders.static_box(Vector3(size.x, 1, size.y), color, 0.25)
	b.position = center - Vector3(0, 0.5, 0)
	nav.add_child(b)
	return b


func block(center: Vector3, size: Vector3, color := Color(0.7, 0.6, 0.48)) -> StaticBody3D:
	var b := Placeholders.static_box(size, color)
	b.position = center + Vector3(0, size.y * 0.5, 0)
	nav.add_child(b)
	return b


## 两点之间一堵墙
func wall(a: Vector2, b: Vector2, h := 3.0, color := Color(0.72, 0.62, 0.5), thick := 0.4) -> StaticBody3D:
	var mid := (a + b) * 0.5
	var l := a.distance_to(b)
	var w := block(Vector3(mid.x, 0, mid.y), Vector3(l + thick, h, thick), color)
	w.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	return w


## 矩形房间的四面墙；doors: 每项 [边(n/s/e/w), 沿边的位置(0-1), 宽度]
func room(center: Vector2, size: Vector2, doors: Array = [], h := 3.0, color := Color(0.72, 0.62, 0.5)) -> void:
	var hx := size.x * 0.5
	var hz := size.y * 0.5
	var edges := {
		"n": [Vector2(center.x - hx, center.y - hz), Vector2(center.x + hx, center.y - hz)],
		"s": [Vector2(center.x - hx, center.y + hz), Vector2(center.x + hx, center.y + hz)],
		"w": [Vector2(center.x - hx, center.y - hz), Vector2(center.x - hx, center.y + hz)],
		"e": [Vector2(center.x + hx, center.y - hz), Vector2(center.x + hx, center.y + hz)],
	}
	for side in edges:
		var a: Vector2 = edges[side][0]
		var b: Vector2 = edges[side][1]
		var cuts: Array = []
		for d in doors:
			if d[0] == side:
				cuts.append([float(d[1]) - float(d[2]) / a.distance_to(b) * 0.5, float(d[1]) + float(d[2]) / a.distance_to(b) * 0.5])
		cuts.sort_custom(func(x, y): return x[0] < y[0])
		var t := 0.0
		for c in cuts:
			if c[0] > t + 0.01:
				wall(a.lerp(b, t), a.lerp(b, c[0]), h, color)
			t = c[1]
		if t < 0.99:
			wall(a.lerp(b, t), b, h, color)


func spawn(name_: String, at: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.name = name_
	m.add_to_group("spawns")
	add_child(m)
	m.position = at
	return m


## 走进去就切关卡（传统关卡切换，加载画面是笑点，诗人也靠这个回来）
func exit_to(at: Vector3, level: String, spawn_name: String, label_key: String, size := Vector3(3, 2, 3)) -> LevelExit:
	var e := LevelExit.new()
	e.target = level
	e.spawn_name = spawn_name
	e.label_key = label_key
	e.size = size
	add_child(e)
	e.position = at
	return e


func npc(id: StringName, at: Vector3, dialogue: String, node := "start", color := Color(0.7, 0.6, 0.4)) -> Npc:
	var n := Npc.new()
	n.name = String(id)
	n.char_id = id
	n.placeholder_color = color
	n.dialogue = dialogue
	n.dialogue_node = node
	add_child(n)
	n.position = at
	return n


## 走进去旁白说一句（只说一次）
func narrate_zone(at: Vector3, size: Vector3, key: String, glitch := "") -> Area3D:
	var z := Area3D.new()
	z.collision_layer = 0
	z.collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position.y = size.y * 0.5
	z.add_child(cs)
	add_child(z)
	z.position = at
	z.body_entered.connect(func(b):
		if b is PartyMember and not z.has_meta("done"):
			z.set_meta("done", true)
			if glitch != "":
				Bus.report(StringName(glitch), b.char_id, at)
			else:
				Narrator.say(key))
	return z


func enemy(kind: String, at: Vector3, parent: Node = null) -> Enemy:
	var e := Enemy.new()
	e.monster_kind = kind
	(parent if parent else self).add_child(e)
	e.position = at
	return e


func encounter(at: Vector3, size: Vector3) -> Encounter:
	var enc := Encounter.new()
	enc.size = size
	add_child(enc)
	enc.position = at
	return enc


func label(at: Vector3, key: String) -> Label3D:
	var l := Label3D.new()
	l.text = TextDB.ui(key)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.outline_size = 12
	l.no_depth_test = true
	add_child(l)
	l.position = at
	return l
