class_name PartyController
extends Node3D
## 点击移动 + 队形跟随 + 点击交互。关卡里放一个。
## 生成队伍：根据 Game.party 实例化队员，放在 spawn 点。

const SCENES := {
	&"protagonist": preload("res://scripts/actors/protagonist.gd"),
	&"husband": preload("res://scripts/actors/husband.gd"),
	&"poet": preload("res://scripts/actors/poet.gd"),
	&"sl": preload("res://scripts/actors/sl.gd"),
}
const COLORS := {
	&"protagonist": Color(0.9, 0.85, 0.7),
	&"husband": Color(0.35, 0.3, 0.45),
	&"poet": Color(0.4, 0.75, 0.45),
	&"sl": Color(0.8, 0.2, 0.2),
}
## 队形：相对队长的偏移（队长朝 -Z）
const FORMATION := [Vector3(0, 0, 0), Vector3(-1.2, 0, 1.2), Vector3(1.2, 0, 1.2), Vector3(0, 0, 2.4)]

## 交互距离
const INTERACT_RANGE := 2.2

var members: Dictionary = {}   # id -> PartyMember
var leader: PartyMember
var camera_rig: CameraRig
var _pending_interact: Node3D


var combat: CombatController


func _ready() -> void:
	combat = CombatController.new()
	combat.name = "CombatController"
	add_child(combat)
	Game.party_changed.connect(_sync_party)
	_sync_party.call_deferred()


func spawn_point() -> Vector3:
	var level := owner if owner else get_parent()
	var want: String = level.get_meta("spawn", "") if level else ""
	for m in get_tree().get_nodes_in_group("spawns"):
		if want == "" or m.name == want:
			return (m as Node3D).global_position
	return global_position


func _sync_party() -> void:
	var base := spawn_point() if members.is_empty() else (leader.global_position if leader and leader.is_inside_tree() else spawn_point())
	for i in Game.party.size():
		var id: StringName = Game.party[i]
		if members.has(id):
			continue
		var m: PartyMember = SCENES[id].new()
		m.name = String(id)
		m.placeholder_color = COLORS[id]
		m.position = base + FORMATION[mini(i, FORMATION.size() - 1)]
		# 招募：场景里站着的同名 NPC 换成队员，站在原地
		for n in get_tree().get_nodes_in_group("npc"):
			if n.get("char_id") == id:
				m.position = n.global_position
				n.queue_free()
		get_parent().add_child.call_deferred(m)
		members[id] = m
	for id in members.keys():
		if not Game.in_party(id):
			members[id].queue_free()
			members.erase(id)
	leader = members.get(Game.PROTAGONIST)


func _unhandled_input(e: InputEvent) -> void:
	if DialogueBox.is_open() or Router.is_busy() or Combat.active or CutscenePlayer.is_playing():
		return
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_click(e.position)


func _click(screen_pos: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or leader == null:
		return
	# SubViewportContainer 转发输入时已经换算成低分辨率视口坐标
	var p := screen_pos
	var from := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	q.collide_with_areas = true
	q.collision_mask = 1 | 2 | 8   # 地形 / 角色 / 可交互
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col: Object = hit["collider"]
	var target := _interactable_of(col)
	if target:
		_pending_interact = target
		leader.move_to(target.global_position)
		return
	_pending_interact = null
	leader.move_to(hit["position"])
	Meta.bump("move_clicks")


func _interactable_of(o: Object) -> Node3D:
	var n := o as Node
	while n:
		if n.has_method("interact") and n != leader:
			return n as Node3D
		n = n.get_parent()
	return null


func _physics_process(_dt: float) -> void:
	if leader == null or Combat.active or DialogueBox.is_open() or CutscenePlayer.is_playing():
		return
	if _pending_interact and is_instance_valid(_pending_interact):
		# 目标可以自己定交互距离（铁匠碰撞体太大，走不到跟前，只能隔着喊）
		var rng: float = _pending_interact.get("interact_range") if _pending_interact.get("interact_range") != null else INTERACT_RANGE
		if leader.global_position.distance_to(_pending_interact.global_position) < rng:
			leader.stop()
			var t := _pending_interact
			_pending_interact = null
			t.interact()
	# 跟随：其他人朝队形位置走
	var basis := leader.model.global_transform.basis if leader.model else Basis()
	var fwd := -basis.z
	fwd.y = 0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var i := 0
	for id in Game.party:
		var m: PartyMember = members.get(id)
		if m == null or m == leader or not m.is_inside_tree():
			i += 1
			continue
		var off: Vector3 = FORMATION[mini(i, FORMATION.size() - 1)]
		var slot := leader.global_position + right * off.x - fwd * off.z
		if m.global_position.distance_to(slot) > 0.9 or m is Poet:
			m.move_to(slot)
		i += 1
