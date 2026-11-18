class_name Interactable
extends StaticBody3D
## 可以点的东西（拉杆、门、箱子、铺盖、鸡）。点击 → interacted 信号，子类或关卡脚本处理。
## 在 "nameplated" 组里显示名字。

signal interacted(by: StringName)

@export var label_key := ""
@export var size := Vector3(0.8, 1.0, 0.8)
@export var color := Color(0.6, 0.5, 0.3)

var char_id: StringName = &""
var display_name: String:
	get:
		return TextDB.ui(label_key)
var mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 8   # 只用来点击，不挡路
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position.y = size.y * 0.5
	add_child(cs)
	mesh = Placeholders.box(size, color)
	mesh.position.y = size.y * 0.5
	add_child(mesh)
	if label_key != "":
		add_to_group("nameplated")


func nameplate_position() -> Vector3:
	return global_position + Vector3.UP * (size.y + 0.4)


func interact() -> bool:
	interacted.emit(Game.selected)
	return true
