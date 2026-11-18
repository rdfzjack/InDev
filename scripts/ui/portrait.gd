class_name Portrait
extends Control
## 一个角色头像。有美术用 res://assets/portraits/<id>_icon.png，没有就画占位（底色 + 名字首字）。
## round = true 时画成圆形（技能栏左边那个大头像）。

const ICON_PATH := "res://assets/portraits/%s_icon.png"

@export var char_id: StringName
@export var round := false
@export var selected := false:
	set(v):
		selected = v
		queue_redraw()

## 显示"可以升级"的角标
var can_level := false:
	set(v):
		can_level = v
		queue_redraw()
## 不为空时代替角色名（怪物用）
var name_text := ""
var _tex: Texture2D


func setup(id: StringName) -> void:
	char_id = id
	var p := ICON_PATH % String(id)
	_tex = load(p) if ResourceLoader.exists(p) else null
	tooltip_text = TextDB.char_name(id)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col: Color = PartyController.COLORS.get(char_id, Color(0.55, 0.2, 0.15))
	var border := UITheme.BORDER_BRIGHT if selected else UITheme.BORDER
	if round:
		var c := size * 0.5
		var rad := minf(size.x, size.y) * 0.5
		draw_circle(c, rad, UITheme.BG_DEEP)
		if _tex:
			# 圆形裁剪交给 shader 太重了，占位阶段直接画方贴图的内切部分
			var s := rad * 1.414
			draw_texture_rect(_tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		else:
			draw_circle(c, rad - 3, col.darkened(0.35))
			_draw_initial(c, rad)
		draw_arc(c, rad - 1, 0, TAU, 48, border, 2.0, true)
		draw_arc(c, rad - 5, 0, TAU, 48, UITheme.BORDER.darkened(0.3), 1.0, true)
		return
	draw_rect(r, UITheme.BG_DEEP)
	if _tex:
		draw_texture_rect(_tex, r.grow(-2), false)
	else:
		draw_rect(r.grow(-2), col.darkened(0.35))
		_draw_initial(size * 0.5, minf(size.x, size.y) * 0.5)
	draw_rect(r, border, false, 2.0 if selected else 1.0)
	if can_level:
		# 右上角金色加号
		var c := Vector2(size.x - 9, 9)
		draw_circle(c, 8, UITheme.TEXT_GOLD)
		draw_rect(Rect2(c - Vector2(5, 1.5), Vector2(10, 3)), UITheme.BG_DEEP)
		draw_rect(Rect2(c - Vector2(1.5, 5), Vector2(3, 10)), UITheme.BG_DEEP)


func _draw_initial(c: Vector2, rad: float) -> void:
	var name := name_text if name_text != "" else TextDB.char_name(char_id)
	if name == "":
		return
	var f := get_theme_default_font()
	var fs := int(rad * 0.8)
	var ch := name.substr(0, 1)
	var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, c + Vector2(-w.x * 0.5, fs * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.TEXT)
