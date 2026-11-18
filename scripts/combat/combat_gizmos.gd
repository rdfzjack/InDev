class_name CombatGizmos
extends MeshInstance3D
## 战斗中画在地面上的提示：移动范围圈、路径预览、法术射程圈、范围预览。
## 用 ImmediateMesh，每帧重画。不走 PS2 材质（UI 层的东西允许是现代的）。

const COL_MOVE := Color(0.95, 0.85, 0.5, 0.8)
const COL_PATH_OK := Color(0.4, 0.95, 0.5, 0.95)
const COL_PATH_BAD := Color(0.95, 0.3, 0.25, 0.95)
const COL_RANGE := Color(0.6, 0.75, 1.0, 0.6)
const COL_AREA := Color(1.0, 0.45, 0.2, 0.9)
const Y := 0.06

var im := ImmediateMesh.new()


func _ready() -> void:
	mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 10
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_transform = Transform3D.IDENTITY


func clear() -> void:
	im.clear_surfaces()


func begin() -> void:
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	# 空 surface 会报错，先放一段零长度线
	im.surface_set_color(Color(0, 0, 0, 0))
	im.surface_add_vertex(Vector3.ZERO)
	im.surface_add_vertex(Vector3.ZERO)


func finish() -> void:
	im.surface_end()


func circle(center: Vector3, r: float, col: Color, dashed := false) -> void:
	var n := maxi(24, int(r * 8))
	for i in n:
		if dashed and i % 2 == 1:
			continue
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		_line(center + Vector3(cos(a0) * r, 0, sin(a0) * r), center + Vector3(cos(a1) * r, 0, sin(a1) * r), col)


func cone(origin: Vector3, toward: Vector3, length: float, col: Color) -> void:
	var d := toward - origin
	d.y = 0
	if d.length() < 0.01:
		return
	d = d.normalized()
	var side := d.cross(Vector3.UP) * length * 0.5
	var tip := origin + d * length
	_line(origin, tip + side, col)
	_line(origin, tip - side, col)
	_line(tip + side, tip - side, col)


func square(center: Vector3, size: float, col: Color) -> void:
	var h := size * 0.5
	var c := [center + Vector3(-h, 0, -h), center + Vector3(h, 0, -h), center + Vector3(h, 0, h), center + Vector3(-h, 0, h)]
	for i in 4:
		_line(c[i], c[(i + 1) % 4], col)


## 路径：前 budget 米绿色，超出部分红色
func path(points: PackedVector3Array, budget: float) -> void:
	var left := budget
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var len := a.distance_to(b)
		if left >= len:
			_line(a, b, COL_PATH_OK)
		elif left > 0:
			var m := a.lerp(b, left / len)
			_line(a, m, COL_PATH_OK)
			_line(m, b, COL_PATH_BAD)
		else:
			_line(a, b, COL_PATH_BAD)
		left -= len


func _line(a: Vector3, b: Vector3, col: Color) -> void:
	im.surface_set_color(col)
	im.surface_add_vertex(Vector3(a.x, a.y + Y, a.z))
	im.surface_set_color(col)
	im.surface_add_vertex(Vector3(b.x, b.y + Y, b.z))
