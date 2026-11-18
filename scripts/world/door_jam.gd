class_name DoorJam
extends Area3D
## 门口打转（酒馆门）。地点属性，不是角色属性。
## 队员进入触发盒：避让考虑半径调大，过度避让 → 转圈七八秒。出去恢复。
## 诗人在地图外面时他不占位，进门就顺畅多了。

## 先关着（太烦，走不过去）。打开 = 进门开避让 + 调大半径。
@export var enabled := false
@export var size := Vector3(4, 2, 4)
@export var jam_neighbor_distance := 6.0
@export var jam_radius := 1.3

var _saved: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(b: Node) -> void:
	if not enabled or not (b is PartyMember):
		return
	var a: NavigationAgent3D = b.agent
	_saved[b] = [a.radius, a.neighbor_distance, a.avoidance_enabled]
	a.avoidance_enabled = true
	a.radius = jam_radius
	a.neighbor_distance = jam_neighbor_distance
	if _saved.size() >= 2:
		Bus.report(&"door_jam", &"", global_position)


func _on_exit(b: Node) -> void:
	if not _saved.has(b):
		return
	var a: NavigationAgent3D = b.agent
	a.radius = _saved[b][0]
	a.neighbor_distance = _saved[b][1]
	a.avoidance_enabled = _saved[b][2]
	_saved.erase(b)
