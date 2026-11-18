class_name Placeholders
## 占位几何体，都用 PS2 材质，这样占位阶段就能看到最终的抖动和贴图手感。

const PS2 := preload("res://shaders/ps2.gdshader")
const CHECKER := preload("res://assets/textures/placeholder_checker.svg")


## snap = false：不做顶点抖动。地面和贴在地面上的层（路、陷阱板、出口）必须关：
## 两层各自抖到不同的屏幕格子，掠射角下深度差远大于几厘米，就会互相穿插闪烁。
static func material(color: Color, tex: Texture2D = null, uv_scale := Vector2.ONE, snap := true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS2
	m.set_shader_parameter("albedo_tex", tex if tex else CHECKER)
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("uv_scale", uv_scale)
	m.set_shader_parameter("use_vertex_color", false)
	if not snap:
		m.set_shader_parameter("snap_grid", 0.0)
	return m


static func capsule(color: Color, height := 1.8) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = height
	cm.radial_segments = 8
	cm.rings = 2
	mi.mesh = cm
	mi.position.y = height * 0.5
	mi.material_override = material(color)
	# 脸朝向（-Z）的小方块，看得出朝哪边
	var nose := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.15, 0.12, 0.2)
	nose.mesh = bm
	nose.position = Vector3(0, height * 0.3, -0.35)
	nose.material_override = material(color.darkened(0.5))
	mi.add_child(nose)
	return mi


## 很薄的方块（贴地层）自动关顶点抖动，见 material()
## 贴图按米投影：uv_per_meter = 每米几个棋盘周期（一个周期两格）
static func box(size: Vector3, color: Color, uv_per_meter := 0.5, snap := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	# PS2 时代的大面都要细分，不然 affine 贴图会拉扯到看不清
	bm.subdivide_width = int(size.x / 2.0)
	bm.subdivide_height = int(size.y / 2.0)
	bm.subdivide_depth = int(size.z / 2.0)
	mi.mesh = bm
	var m := material(color, null, Vector2.ONE * uv_per_meter, snap and size.y > 0.1)
	m.set_shader_parameter("box_uv", true)
	mi.material_override = m
	return mi


## 带碰撞的静态方块（地面、墙）
static func static_box(size: Vector3, color: Color, uv_per_meter := 0.5, snap := true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	sb.add_child(box(size, color, uv_per_meter, snap))
	return sb


## 简单环境：纯色天空（材质都是 unlit，不需要光）
static func environment(sky := Color(0.62, 0.74, 0.88)) -> WorldEnvironment:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = env
	return we
