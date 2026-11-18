class_name Encounter
extends Area3D
## 遭遇战。队员进入触发范围就开打。
## 参战的敌人：本节点下的所有 Enemy，加上 radius 内 "enemy" 组里的。

@export var size := Vector3(14, 3, 14)
@export var radius := 16.0
@export var once := true

var _done := false


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


func _on_enter(b: Node) -> void:
	if _done or Combat.active or not (b is PartyMember):
		return
	start()


func start() -> void:
	var list: Array[Combatant] = []
	for m in get_tree().get_nodes_in_group("party"):
		var a := m as PartyMember
		if a == null or not Game.in_party(a.char_id):
			continue
		if a is Poet and a.outside_map:
			# 他在地图外面。他照样参战——名字还在。
			pass
		var c := Combatant.new(Game.sheet(a.char_id), a, &"party")
		a.combatant = c
		list.append(c)
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Enemy and e.sheet.hp > 0 and (is_ancestor_of(e) or e.global_position.distance_to(global_position) <= radius):
			enemies.append(e)
	if enemies.is_empty():
		return
	for e in enemies:
		var c := Combatant.new(e.sheet, e, &"enemy")
		e.combatant = c
		list.append(c)
	_done = once
	for m in list:
		m.node.stop()
	Combat.start(list)
