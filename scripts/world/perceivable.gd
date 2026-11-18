class_name Perceivable
extends Node3D
## 被动察觉。藏起来的东西（陷阱、暗门、藏起来的箱子）。
## 队员走进 radius 内，被动察觉 >= dc 就发现：子节点显示出来，头顶提示【察觉】，发 discovered。
## 每个东西只对每个人判定一次（BG3 也是这样：走近时自动判定，没过就没过）。

signal discovered(by: StringName)

@export var dc := 12
@export var radius := 5.0
@export var skill := "perception"
var found := false
var _tried := {}
var _t := 0.0


func _ready() -> void:
	add_to_group("perceivable")
	_set_shown(false)
	child_entered_tree.connect(func(n):
		if not found and n is Node3D:
			n.visible = false)


func _set_shown(v: bool) -> void:
	for c in get_children():
		if c is Node3D:
			c.visible = v


func _physics_process(dt: float) -> void:
	if found:
		return
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	for m in get_tree().get_nodes_in_group("party"):
		var a := m as Actor
		if a == null or _tried.has(a.char_id) or a.global_position.distance_to(global_position) > radius:
			continue
		_tried[a.char_id] = true
		var p := Game.sheet(a.char_id).passive(skill)
		if p >= dc:
			reveal(a.char_id)
			return


func reveal(by: StringName = &"") -> void:
	if found:
		return
	found = true
	_set_shown(true)
	Meta.bump("perceived")
	if by != &"":
		Game.notice.emit(by, TextDB.line("rules", "notice_" + skill))
	discovered.emit(by)
