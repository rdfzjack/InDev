class_name Actor
extends CharacterBody3D
## 场景里的角色（队员、NPC、敌人）。走路用 NavigationAgent3D（门口打转要用它的避让）。
## 没有美术模型时自动生成占位胶囊。美术到了之后把模型作为子节点放进 "Model" 节点即可。
##
## 战斗中：follow_path() 沿给定路径走（不用避让），走完发 path_done。

signal path_done

@export var char_id: StringName = &""
@export var placeholder_color := Color(0.8, 0.8, 0.8)
@export var move_speed := 4.0
@export var height := 1.8

var display_name: String:
	get:
		return get_display_name()


func get_display_name() -> String:
	return TextDB.char_name(char_id)

var agent: NavigationAgent3D
var model: Node3D
var combatant: Combatant
var _has_target := false
var _path: PackedVector3Array = []
var _path_i := 0


func _ready() -> void:
	add_to_group("nameplated")
	_join_groups()
	collision_layer = 2
	collision_mask = 1
	if get_node_or_null("Shape") == null:
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var cap := CapsuleShape3D.new()
		cap.radius = 0.35
		cap.height = height
		cs.shape = cap
		cs.position.y = height * 0.5
		add_child(cs)
	model = get_node_or_null("Model")
	if model == null:
		model = Node3D.new()
		model.name = "Model"
		add_child(model)
		_build_placeholder()
	agent = NavigationAgent3D.new()
	agent.name = "Agent"
	agent.radius = 0.4
	agent.height = height
	agent.max_speed = move_speed
	# 导航网格表面和地面之间有一点高度差，判定距离是三维的，不能太小，否则会在路径点前来回抖
	agent.path_desired_distance = 0.75
	agent.target_desired_distance = 0.75
	# 避让（RVO）默认关：开着的时候队友互相让来让去，经常走不过去。
	# 要的话地点自己打开（DoorJam）。
	agent.avoidance_enabled = false
	agent.neighbor_distance = 3.0
	agent.velocity_computed.connect(_on_velocity)
	add_child(agent)


## 子类覆盖：加入 party / enemy 组
func _join_groups() -> void:
	pass


## 子类覆盖：比如 SL 的两套 LOD
func _build_placeholder() -> void:
	model.add_child(Placeholders.capsule(placeholder_color, height))


func nameplate_position() -> Vector3:
	return global_position + Vector3.UP * (height + 0.35)


func move_to(p: Vector3) -> void:
	agent.target_position = p
	_has_target = true


func stop() -> void:
	_has_target = false
	velocity = Vector3.ZERO
	# 避让系统会一直用最后一次设置的速度回调，必须清零，不然人会继续滑
	if agent:
		agent.velocity = Vector3.ZERO
		agent.target_position = global_position


## 战斗移动：沿固定路径走，不用导航避让
func follow_path(p: PackedVector3Array) -> void:
	stop()
	_path = p
	_path_i = 1


func is_following_path() -> bool:
	return _path_i > 0 and _path_i < _path.size()


## 死亡表现（占位：倒下）
func on_died() -> void:
	stop()
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:x", -90.0, 0.4)


## 倒地/起身表现
func set_downed(v: bool) -> void:
	var tw := create_tween()
	tw.tween_property(model, "rotation_degrees:x", -90.0 if v else 0.0, 0.3)


func _physics_process(dt: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * dt
	if _path_i > 0:
		_follow(dt)
		_post_physics(dt)
		return
	if _has_target and not agent.is_navigation_finished():
		var next := agent.get_next_path_position()
		var dir := next - global_position
		dir.y = 0
		var want := dir.normalized() * move_speed
		if agent.avoidance_enabled:
			agent.velocity = want
		else:
			_on_velocity(want)
	else:
		if _has_target and agent.avoidance_enabled:
			agent.velocity = Vector3.ZERO
		_has_target = false
		_on_velocity(Vector3.ZERO)
	_post_physics(dt)


func _on_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z
	if Vector2(v.x, v.z).length() > 0.1:
		var look := global_position + Vector3(v.x, 0, v.z)
		model.look_at(look, Vector3.UP)
	move_and_slide()


func _follow(dt: float) -> void:
	if _path_i >= _path.size():
		_path_i = 0
		velocity = Vector3.ZERO
		path_done.emit()
		return
	var target := _path[_path_i]
	var to := target - global_position
	to.y = 0
	var step := move_speed * dt
	if to.length() <= step:
		global_position = Vector3(target.x, global_position.y, target.z)
		_path_i += 1
	else:
		var v := to.normalized() * step
		global_position += v
		model.look_at(global_position + v, Vector3.UP)


## 子类钩子
func _post_physics(_dt: float) -> void:
	pass
