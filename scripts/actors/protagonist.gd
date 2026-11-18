class_name Protagonist
extends PartyMember
## 主角。默认圣骑士。
## 武器绑在不存在的骨骼上——BoneAttachment 找不到骨骼时留在骨架原点，也就是脚底。
## 他自己看一切正常。换武器不解决问题：任何武器都挂到同一个错的位置。

## 美术到位后：武器模型挂在这个节点下。骨骼名故意写一个不存在的。
const WEAPON_BONE := "hand_r_socket_FINAL"

var weapon_socket: Node3D


func _ready() -> void:
	char_id = Game.PROTAGONIST
	super._ready()
	weapon_socket = Node3D.new()
	weapon_socket.name = "WeaponSocket_" + WEAPON_BONE
	# 脚底原点，平躺，剑尖朝后，一半插进地里
	weapon_socket.position = Vector3(0, 0.02, 0)
	weapon_socket.rotation_degrees = Vector3(90, 0, 35)
	model.add_child(weapon_socket)
	equip_placeholder_weapon()


func equip_placeholder_weapon() -> void:
	for c in weapon_socket.get_children():
		c.queue_free()
	var blade := Placeholders.box(Vector3(0.08, 1.0, 0.03), Color(0.85, 0.85, 0.9))
	blade.position.y = 0.5
	weapon_socket.add_child(blade)
