class_name DemonLord
extends Enemy
## 魔王。认真做：登场、台词、多阶段、庄严的音乐（二阶段被换成店铺 BGM）。
##
## 每次打出的问题不一样（variant，由关卡按尝试次数决定）：
##   normal  正常打。死了以后上天：ragdoll 继承动画末帧速度，有加速，带旋转，越飘越快，飘出画面
##   stuck   卡在地里：下半身在地面以下，动不了，够得着的还是会打
##   frozen  血量不掉：伤害照算，飘字照飘，生命值不写入
##   (no_show 直接不出现：关卡不生成他)

signal launched

var variant := "normal"
var _vel := 0.0
var _spin := Vector3.ZERO
var _launching := false


func _ready() -> void:
	monster_kind = "demon_lord"
	height = 2.8
	super._ready()
	name = "DemonLord"
	char_id = &"demon_lord"
	if variant == "stuck":
		sheet.speed = 0.0
		model.position.y = -1.3


func _build_placeholder() -> void:
	var dark := Color(0.3, 0.12, 0.2)
	var body := Placeholders.capsule(dark, height)
	model.add_child(body)
	for sx in [-1.0, 1.0]:
		var horn := Placeholders.box(Vector3(0.18, 0.7, 0.18), Color(0.85, 0.8, 0.65))
		horn.position = Vector3(0.28 * sx, height + 0.15, -0.05)
		horn.rotation_degrees.z = -25.0 * sx
		model.add_child(horn)
		var pauldron := Placeholders.box(Vector3(0.6, 0.35, 0.7), Color(0.15, 0.12, 0.14))
		pauldron.position = Vector3(0.55 * sx, height * 0.78, 0)
		model.add_child(pauldron)
	var cape := Placeholders.box(Vector3(1.1, height * 0.8, 0.08), Color(0.45, 0.05, 0.08))
	cape.position = Vector3(0, height * 0.45, 0.42)
	model.add_child(cape)


## 死亡：上天（不倒下）
func on_died() -> void:
	stop()
	collision_layer = 0
	collision_mask = 0
	if variant == "stuck":
		# 卡在地里的那一次，死了也从地里往上飞
		model.position.y = -1.3
	_launching = true
	_vel = 6.0
	_spin = Vector3(randf_range(-2, 2), randf_range(3, 6), randf_range(-2, 2))
	Meta.bump("boss_launched")
	Bus.report(&"ragdoll_launch", char_id, global_position)


func _physics_process(dt: float) -> void:
	if not _launching:
		super._physics_process(dt)
		return
	_vel += 22.0 * dt        # 越飘越快
	_spin *= 1.0 + 0.6 * dt
	global_position.y += _vel * dt
	model.rotation += _spin * dt
	if global_position.y > 160.0:
		_launching = false
		visible = false
		launched.emit()
