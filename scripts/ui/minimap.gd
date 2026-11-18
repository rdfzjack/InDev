class_name Minimap
extends Control
## 右上角圆形小地图：俯视正交相机实时渲染同一个 3D 世界，圆形遮罩。
## 地图标记：任何在 "map_marker" 组里的 Node3D。
##   meta "blink" = true 时闪烁（魔王的位置从游戏一开始就标着，像个未读提示）
##   meta "color" = Color
## 地图下方显示区域名（ui.tsv 的 area_<关卡名>）。

const SIZE := 150
const WORLD_SPAN := 40.0   # 小地图直径对应的世界米数

const MASK_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 d = UV - vec2(0.5);
	if (length(d) > 0.5) { discard; }
	COLOR = texture(TEXTURE, UV);
}
"""

var _vp: SubViewport
var _cam: Camera3D
var _rect: TextureRect
var _area: Label
var _t := 0.0


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -SIZE - 16
	offset_right = -16
	offset_top = 12
	offset_bottom = 12 + SIZE + 26
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = WORLD_SPAN
	_cam.far = 200.0
	_cam.rotation_degrees = Vector3(-90, 0, 0)
	_vp.add_child(_cam)
	_rect = TextureRect.new()
	_rect.texture = _vp.get_texture()
	_rect.size = Vector2(SIZE, SIZE)
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = MASK_SHADER
	mat.shader = sh
	_rect.material = mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	_area = Label.new()
	_area.position = Vector2(0, SIZE + 4)
	_area.size = Vector2(SIZE, 20)
	_area.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area.add_theme_font_size_override("font_size", 13)
	_area.add_theme_color_override("font_color", UITheme.TEXT_GOLD)
	add_child(_area)
	Router.level_loaded.connect(_on_level)


func _on_level(level: Node) -> void:
	_vp.world_3d = level.get_viewport().find_world_3d()
	_cam.make_current()
	_area.text = TextDB.ui("area_" + level.name.to_snake_case())


func _leader() -> Node3D:
	for m in get_tree().get_nodes_in_group("party"):
		if m.get("char_id") == Game.PROTAGONIST:
			return m
	return null


func _process(dt: float) -> void:
	_t += dt
	var l := _leader()
	if l:
		_cam.global_position = l.global_position + Vector3.UP * 60.0


## 边框和标记画在贴图之上（子节点后画，所以单独一个 Overlay 节点）
class Overlay extends Control:
	var map: Minimap

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(Minimap.SIZE, Minimap.SIZE) * 0.5
		var r := Minimap.SIZE * 0.5
		var l := map._leader()
		if l:
			var scale := Minimap.SIZE / Minimap.WORLD_SPAN
			for m in get_tree().get_nodes_in_group("map_marker"):
				var d: Vector3 = (m as Node3D).global_position - l.global_position
				var p := c + Vector2(d.x, d.z) * scale
				if p.distance_to(c) > r - 6:
					p = c + (p - c).normalized() * (r - 6)
				var col: Color = m.get_meta("color", UITheme.TEXT_GOLD)
				if m.get_meta("blink", false) and int(map._t * 2.0) % 2 == 0:
					col.a = 0.2
				draw_circle(p, 4, col)
			# 自己：中心的小三角
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(5, 5), c + Vector2(-5, 5)]), Color(1, 1, 1))
		draw_arc(c, r - 1, 0, TAU, 64, UITheme.BORDER_BRIGHT, 2.0, true)
		draw_arc(c, r - 4, 0, TAU, 64, UITheme.BORDER.darkened(0.4), 1.0, true)


func _enter_tree() -> void:
	if get_node_or_null("Overlay") == null:
		var o := Overlay.new()
		o.name = "Overlay"
		o.map = self
		o.size = Vector2(SIZE, SIZE)
		o.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child.call_deferred(o)
