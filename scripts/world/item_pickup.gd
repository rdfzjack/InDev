class_name ItemPickup
extends RigidBody3D
## 地上的物品（扔过来的、掉出来的）。会滚。停下以后点一下捡起来。
## 滚进地缝（"crack" 组的 Area3D）就卡住：看得见，名牌还在，捡不起来。

signal picked(by: StringName)

@export var item := ""
@export var qty := 1

var stuck := false
var char_id: StringName = &""
var display_name: String:
	get:
		return Inventory.display_name(item)
var interact_range := 1.6


func _ready() -> void:
	collision_layer = 8          # 只用来点击
	collision_mask = 1
	mass = 0.6
	linear_damp = 1.0
	angular_damp = 1.5
	continuous_cd = true
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.14
	sh.height = 0.32
	cs.shape = sh
	cs.rotation_degrees.z = 90.0
	add_child(cs)
	var m := Placeholders.box(Vector3(0.32, 0.12, 0.12), Color(0.85, 0.75, 0.35))
	add_child(m)
	add_to_group("nameplated")
	contact_monitor = true
	max_contacts_reported = 4


func nameplate_position() -> Vector3:
	return global_position + Vector3.UP * 0.5


## 掉进地缝：冻住，往下沉一点
func fall_into_crack() -> void:
	if stuck:
		return
	stuck = true
	collision_mask = 0
	freeze = true
	global_position.y -= 0.18
	Meta.bump("item_lost_in_crack_" + item)
	Bus.report(&"item_in_crack", &"", global_position)


func interact() -> bool:
	if stuck:
		Narrator.say("item_stuck_in_crack")
		return false
	Inv.add(item, qty)
	Narrator.show_text(TextDB.ui("picked_up") % Inventory.display_name(item))
	picked.emit(Game.selected)
	queue_free()
	return true
