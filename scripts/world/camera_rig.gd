class_name CameraRig
extends Node3D
## CRPG 斜俯视镜头。跟随队长，Q/E 旋转，滚轮缩放。

@export var pitch_deg := -50.0
@export var distance := 12.0
@export var min_distance := 5.0
@export var max_distance := 22.0
@export var follow_speed := 6.0
@export var fov := 50.0

var target: Node3D
var cam: Camera3D
var _yaw := 45.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = fov
	cam.near = 0.3
	cam.far = 150.0
	add_child(cam)
	cam.make_current()
	_apply()


func _process(dt: float) -> void:
	var follow := target
	# 战斗中跟当前回合的单位
	if Combat.active:
		var c := Combat.current()
		if c and c.node and is_instance_valid(c.node):
			follow = c.node
	if follow and is_instance_valid(follow):
		global_position = global_position.lerp(follow.global_position, clampf(follow_speed * dt, 0, 1))
	if Input.is_key_pressed(KEY_Q):
		_yaw += 90.0 * dt
	if Input.is_key_pressed(KEY_E):
		_yaw -= 90.0 * dt
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(min_distance, distance - 1.0)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(max_distance, distance + 1.0)


func _apply() -> void:
	rotation_degrees = Vector3(0, _yaw, 0)
	var p := deg_to_rad(pitch_deg)
	cam.position = Vector3(0, -sin(p) * distance, cos(p) * distance)
	cam.rotation = Vector3(p, 0, 0)
