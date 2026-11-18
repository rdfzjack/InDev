class_name Nameplates
extends Control
## 头顶名牌。画在全分辨率 UI 层，位置从低分辨率 3D 视口换算过来。
## 任何节点只要在 "nameplated" 组里、并提供 display_name 和 nameplate_position()，就会有名牌。
##
## 名牌永远钳制在屏幕内：诗人在地下很远处时，他的名字贴在屏幕底边，跟着他的 X 走。

const MARGIN := 12.0
## 底部留给技能栏
const BOTTOM_MARGIN := 125.0
## 非队员的名牌：超过这个距离不显示；出屏不显示（只有队员会钳到屏幕边缘）
const NPC_RANGE := 22.0

var world_view: SubViewportContainer
var _labels: Dictionary = {}   # instance_id -> Label
var _by_char: Dictionary = {}  # char_id -> Label（给头顶对话用）


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_dt: float) -> void:
	var seen := {}
	_by_char.clear()
	var vp := world_view.get_child(0) as SubViewport if world_view and world_view.get_child_count() > 0 else null
	var cam := vp.get_camera_3d() if vp else null
	if cam:
		for n in get_tree().get_nodes_in_group("nameplated"):
			if not (n is Node3D) or not n.is_visible_in_tree() and not n.get("plate_when_hidden"):
				continue
			var id := n.get_instance_id()
			seen[id] = true
			var lab: Label = _labels.get(id)
			if lab == null:
				lab = _make_label()
				_labels[id] = lab
			lab.text = n.display_name
			var wp: Vector3 = n.nameplate_position()
			var raw := _project(cam, wp) - lab.size * Vector2(0.5, 1.0)
			# 掉出地图的诗人：名牌钉在原地，跟 NPC 一样出了屏幕就不显示（不钳制到屏幕边缘）
			var is_party: bool = n.is_in_group("party") and not n.get("outside_map")
			if not is_party:
				var far := cam.global_position.distance_to(wp) > NPC_RANGE + 12.0
				var off := cam.is_position_behind(wp) or raw.x < -lab.size.x or raw.x > size.x or raw.y < 0 or raw.y > size.y - BOTTOM_MARGIN
				lab.visible = not (far or off)
			else:
				lab.visible = true
			lab.position = raw.clamp(Vector2(MARGIN, MARGIN), size - lab.size - Vector2(MARGIN, BOTTOM_MARGIN))
			var cid = n.get("char_id")
			if cid != null:
				_by_char[cid] = lab
	for id in _labels.keys():
		if not seen.has(id):
			_labels[id].queue_free()
			_labels.erase(id)


## 某个角色名牌的屏幕位置（名牌上沿中点）。不在场返回 (-1, -1)。
func plate_screen_pos(char_id: StringName) -> Vector2:
	var lab: Label = _by_char.get(char_id)
	if lab == null or not is_instance_valid(lab):
		return Vector2(-1, -1)
	return lab.position + Vector2(lab.size.x * 0.5, 0)


func _project(cam: Camera3D, p: Vector3) -> Vector2:
	var scale := Vector2(world_view.size) / Vector2(cam.get_viewport().get_visible_rect().size)
	if cam.is_position_behind(p):
		# 在镜头后面：镜像到前方，然后压到屏幕下沿
		var local := cam.global_transform.affine_inverse() * p
		local.z = -absf(local.z)
		var front := cam.global_transform * local
		var s := cam.unproject_position(front) * scale
		return Vector2(world_view.size.x - s.x, size.y)
	return world_view.position + cam.unproject_position(p) * scale


func _make_label() -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l
