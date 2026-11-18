class_name DialogueCamera
extends Camera3D
## 电影式对话镜头（BG3 式）。
##
## 镜头类型：
##   ots(subject, over)  越肩：从 over 的肩膀后面拍 subject。正打 = ots(NPC, 主角)，反打 = ots(主角, NPC)
##   close(subject)      特写：正面略偏，脸占画面上部
##   wide(a, b)          两人全景：从侧面同时拍到两个人
##
## 构图不靠写死的偏移，而是"放好机位 → 看向目标 → 迭代修正"，直到被拍的人的头落在目标屏幕位置：
##   头在画面上部 1/3 左右（FACE_Y），下面 30% 留给字幕和选项，不会挡脸。
##   越肩镜头里被拍的人偏向越肩者的对侧，前景肩膀占另一边。
## 机位和被拍者之间有墙挡着，就沿视线往前推，直到看得见。

const FACE_Y := 0.34          # 头的目标纵向位置（0 = 顶，1 = 底）
const SUBTITLE_TOP := 0.68    # 字幕区上沿，头和上半身都不能低于这里
const HEAD_RATIO := 0.93      # 头的高度 = 身高 × 这个比例

var _drift := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	fov = 38.0
	near = 0.05
	far = 200.0


var _track: Node3D


## 跟拍：每帧重新对准（诗人掉下去时镜头忠实跟随）
func track(n: Node3D) -> void:
	_track = n
	_drift = Vector3.ZERO


func _process(dt: float) -> void:
	if _track and is_instance_valid(_track):
		var h := head_of(_track)
		if global_position.distance_to(h) > 0.5:
			look_at(h, Vector3.UP)
		return
	# 极慢的推镜，让画面不死
	_t += dt
	if _drift != Vector3.ZERO and _t < 6.0:
		global_position += _drift * dt


static func head_of(n: Node3D) -> Vector3:
	var h := 1.8
	if n.get("height") != null:
		h = float(n.get("height"))
	return n.global_position + Vector3.UP * h * HEAD_RATIO


static func _flat(v: Vector3) -> Vector3:
	v.y = 0
	return v.normalized() if v.length() > 0.001 else Vector3.FORWARD


func shot(kind: String, a: Node3D, b: Node3D = null) -> void:
	_track = null
	_t = 0.0
	_drift = Vector3.ZERO
	match kind:
		"ots":
			_ots(a, b)
		"close":
			_close(a, b)
		"wide":
			_wide(a, b)
		_:
			_close(a, b)


## 越肩：从 over 右肩后拍 subject。机位在 over 右边，所以 over 的肩膀在画面左边，
## subject 放在画面偏右（对侧），两人在屏幕上至少隔开 MIN_SEPARATION，前景肩膀不压到脸。
const OTS_FRAME_X := 0.6
const MIN_SEPARATION := 0.3


func _ots(subject: Node3D, over: Node3D) -> void:
	if over == null:
		_close(subject, null)
		return
	fov = 36.0
	var hs := head_of(subject)
	var ho := head_of(over)
	var d := _flat(hs - ho)
	var right := d.cross(Vector3.UP).normalized()
	var lateral := 0.75
	for i in 4:
		var pos := ho - d * 1.25 + right * lateral - Vector3.UP * 0.05
		_place(pos, hs, Vector2(OTS_FRAME_X, FACE_Y), subject)
		if is_position_behind(ho) or frac_of(hs).x - frac_of(ho).x >= MIN_SEPARATION:
			break
		lateral += 0.25
	_drift = d * 0.04


## 特写：在 subject 面前（朝向 toward 那一侧），略偏 25°
func _close(subject: Node3D, toward: Node3D) -> void:
	fov = 32.0
	var hs := head_of(subject)
	var face := _flat((toward.global_position if toward else hs + Vector3.FORWARD) - subject.global_position)
	var side := face.cross(Vector3.UP).normalized()
	var dir := (face * cos(deg_to_rad(25)) + side * sin(deg_to_rad(25))).normalized()
	var pos := hs + dir * 1.7 + Vector3.UP * 0.05
	_place(pos, hs, Vector2(0.5, FACE_Y + 0.02), subject)
	_drift = -dir * 0.03


## 两人全景：机位在两人连线的垂直方向
func _wide(a: Node3D, b: Node3D) -> void:
	if b == null:
		_close(a, null)
		return
	fov = 42.0
	var ha := head_of(a)
	var hb := head_of(b)
	var mid := (ha + hb) * 0.5
	var along := _flat(hb - ha)
	var perp := along.cross(Vector3.UP).normalized()
	# 选离当前镜头更近的那一侧，避免跳轴
	if (global_position - mid).dot(perp) < 0:
		perp = -perp
	var dist := ha.distance_to(hb) * 1.1 + 2.6
	var pos := mid + perp * dist + Vector3.UP * 0.35
	_place(pos, mid, Vector2(0.5, FACE_Y + 0.04), a)


## 放机位 → 去掉遮挡 → 看向目标 → 迭代修正，让 target 落在屏幕 screen_frac 处
func _place(pos: Vector3, target: Vector3, screen_frac: Vector2, subject: Node3D) -> void:
	pos = _unoccluded(pos, target, subject)
	global_position = pos
	look_at(target, Vector3.UP)
	var vp := get_viewport()
	if vp == null:
		return
	var size := Vector2(vp.get_visible_rect().size)
	var fov_v := deg_to_rad(fov)
	var fov_h := 2.0 * atan(tan(fov_v * 0.5) * size.x / size.y)
	for i in 6:
		if is_position_behind(target):
			break
		var p := unproject_position(target) / size
		var err := screen_frac - p
		if err.length() < 0.004:
			break
		# 目标在屏幕上偏右（err.x < 0）→ 镜头往右转（负 yaw）→ 目标往左移
		# 目标偏下（err.y < 0）→ 镜头往下看（负 pitch）→ 目标往上移
		rotate_object_local(Vector3.UP, err.x * fov_h)
		rotate_object_local(Vector3.RIGHT, err.y * fov_v)
	# 保证身体中段也在字幕区以上：如果脚边（胸口）掉进字幕区，就把镜头抬一点
	var chest := target - Vector3.UP * 0.45
	if not is_position_behind(chest):
		var cy := unproject_position(chest).y / size.y
		if cy > SUBTITLE_TOP:
			rotate_object_local(Vector3.RIGHT, -(cy - SUBTITLE_TOP) * fov_v)


## 机位到被拍者头之间有静态几何体（layer 1）挡着，就沿视线往前推
func _unoccluded(pos: Vector3, target: Vector3, subject: Node3D) -> Vector3:
	var w := get_world_3d()
	if w == null:
		return pos
	var space := w.direct_space_state
	for i in 4:
		var q := PhysicsRayQueryParameters3D.create(pos, target, 1)
		if subject is CollisionObject3D:
			q.exclude = [(subject as CollisionObject3D).get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return pos
		pos = hit["position"] + (target - pos).normalized() * 0.25
	return pos


## 测试 / 调试：某个点在屏幕上的相对位置
func frac_of(p: Vector3) -> Vector2:
	var size := Vector2(get_viewport().get_visible_rect().size)
	return unproject_position(p) / size
