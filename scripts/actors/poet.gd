class_name Poet
extends PartyMember
## 诗人。会掉出地图。
##
## 掉下去：关碰撞，重力往下拽，落速有上限，到 STOP_Y 停住（"他在下面"，不是无限下坠）。
## 不走 Kill Z。名牌不跟着掉：留在他掉下去的地方（原来站着的位置头顶），飘在空中。
## 跟随逻辑停掉——但 TrapProxy（隐形的触发体）继续跟着队伍走，所以陷阱还是会被他踩响。
## 每次关卡加载他都会回来（新关卡里就是一个新的他）。

const STOP_Y := -45.0
const MAX_FALL_SPEED := 18.0

var outside_map := false
## 掉下去的位置（名牌留在这里）
var fall_origin := Vector3.ZERO
## 名牌系统在他不可见时也显示
var plate_when_hidden := true
## 隐形触发体：陷阱检测它，而不是检测身体
var trap_proxy: Area3D
## 队伍里他该站的位置（PartyController 每帧写）
var formation_target := Vector3.ZERO


func _ready() -> void:
	char_id = Game.POET
	super._ready()
	trap_proxy = Area3D.new()
	trap_proxy.name = "TrapProxy"
	trap_proxy.top_level = true
	trap_proxy.collision_layer = 4   # layer 3 = 陷阱触发者
	trap_proxy.collision_mask = 0
	trap_proxy.add_to_group("trap_trigger")
	trap_proxy.set_meta("char_id", char_id)
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.35
	s.height = 1.6
	cs.shape = s
	cs.position.y = 0.8
	trap_proxy.add_child(cs)
	add_child(trap_proxy)


func fall_out_of_map() -> void:
	if outside_map:
		return
	outside_map = true
	fall_origin = global_position
	Game.poet_outside_map = true
	collision_layer = 0
	collision_mask = 0
	stop()
	agent.avoidance_enabled = false
	Meta.bump("poet_fell")
	Game.set_flag(&"poet_fell_seen")
	Bus.report(&"poet_fell", char_id, global_position)


func move_to(p: Vector3) -> void:
	if outside_map:
		formation_target = p
		return
	super.move_to(p)


func _physics_process(dt: float) -> void:
	if not outside_map:
		super._physics_process(dt)
		trap_proxy.global_position = global_position
		return
	velocity.x = 0
	velocity.z = 0
	if global_position.y > STOP_Y:
		velocity.y = maxf(velocity.y - 9.8 * dt, -MAX_FALL_SPEED)
		global_position += velocity * dt
	else:
		velocity.y = 0
		global_position.y = STOP_Y
	# 触发体沿地面朝他该在的位置走，和正常走路一样快
	var p := trap_proxy.global_position
	var to := formation_target - p
	to.y = 0
	var step := minf(to.length(), move_speed * dt)
	if step > 0.001:
		p += to.normalized() * step
	p.y = formation_target.y
	trap_proxy.global_position = p


## 他在下面时，名牌留在原位（掉下去那一点的头顶），不跟身体、也不跟触发体
func nameplate_position() -> Vector3:
	if outside_map:
		return fall_origin + Vector3.UP * (height + 0.35)
	return super.nameplate_position()
