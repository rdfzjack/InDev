class_name LevelExit
extends Area3D
## 关卡出口。队长走进去就切关卡。头顶有个牌子（名牌系统）。
## 战斗中不能离开。

@export_file("*.tscn") var target := ""
@export var spawn_name := ""
@export var label_key := ""
@export var size := Vector3(3, 2, 3)
## 需要的剧情标记（没有就走不了，旁白说一句）
@export var requires_flag := ""
@export var locked_narrator_key := ""

var char_id: StringName = &""
var display_name: String:
	get:
		return TextDB.ui(label_key)


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	add_to_group("nameplated")
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position.y = size.y * 0.5
	add_child(cs)
	var m := Placeholders.box(Vector3(size.x, 0.05, size.z), Color(0.95, 0.85, 0.4, 1.0))
	m.position.y = 0.03
	add_child(m)
	body_entered.connect(_on_enter)


func nameplate_position() -> Vector3:
	return global_position + Vector3.UP * 2.2


func _on_enter(b: Node) -> void:
	if not (b is PartyMember) or b.char_id != Game.PROTAGONIST or Combat.active or Router.is_busy():
		return
	if requires_flag != "" and not Game.flag(StringName(requires_flag)):
		if locked_narrator_key != "":
			Narrator.say(locked_narrator_key)
		return
	Router.goto(target, spawn_name)
