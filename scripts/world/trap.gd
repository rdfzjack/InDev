class_name Trap
extends Area3D
## 陷阱。检测 "trap_trigger" 组里的 Area（诗人的隐形触发体）和角色身体。
## 解除陷阱功能没做：交互时提示"该功能尚未实现"。

@export var trap_id := "trap"
@export var rearm_sec := 4.0
@export var size := Vector3(1.5, 0.3, 1.5)
## 被动察觉 DC。0 = 一直看得见
@export var hidden_dc := 12

var _armed := true
var _plate: Node3D
var detected := false


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2 | 4
	monitoring = true
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	cs.position.y = size.y * 0.5
	add_child(cs)
	_plate = Placeholders.box(Vector3(size.x, 0.04, size.z), Color(0.5, 0.42, 0.35))
	_plate.position.y = 0.02
	if hidden_dc > 0:
		var p := Perceivable.new()
		p.dc = hidden_dc
		p.name = "Perceivable"
		add_child(p)
		p.add_child(_plate)
		p.discovered.connect(func(by): _on_detected(by))
		collision_layer = 0   # 没发现之前点不到
	else:
		add_child(_plate)
		detected = true
	body_entered.connect(_on_enter)
	area_entered.connect(_on_enter)


func _on_detected(by: StringName) -> void:
	detected = true
	collision_layer = 8
	Bus.report(&"trap_detected", by, global_position)


func _on_enter(n: Node) -> void:
	if not _armed:
		return
	var who: StringName = &""
	if n is PartyMember:
		if n is Poet and n.outside_map:
			return
		who = n.char_id
	elif n.is_in_group("trap_trigger"):
		who = n.get_meta("char_id", &"")
	else:
		return
	_armed = false
	Meta.bump("traps_triggered")
	Bus.report(&"trap_sprung", who, global_position)
	await get_tree().create_timer(rearm_sec).timeout
	_armed = true


## 点击陷阱 = 尝试解除
func interact() -> bool:
	Bus.report(&"disarm_not_implemented", Game.SL, global_position)
	return true
