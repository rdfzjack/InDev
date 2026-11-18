class_name CombatHUD
extends Control
## 战斗 UI：
##   顶部先攻条（当前回合高亮，敌人红框，死了变灰）
##   技能栏上方的资源：动作 ● 附赠动作 ▲ 反应 ◆，剩余移动力条，法术位
##   鼠标悬停目标：命中率 / 豁免失败率 + 优劣势原因
##   飘字：伤害、治疗、未命中

var nameplates: Nameplates

var _order_box: HBoxContainer
var _res: Control
var _tip: PanelContainer
var _tip_label: Label
var _floats: Array = []   # [{label, c, t}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_order_box = HBoxContainer.new()
	_order_box.anchor_left = 0.5
	_order_box.anchor_right = 0.5
	_order_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_order_box.offset_top = 70
	_order_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_order_box.add_theme_constant_override("separation", 4)
	_order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_order_box)
	_res = ResourceBar.new()
	_res.anchor_left = 0.5
	_res.anchor_right = 0.5
	_res.anchor_top = 1.0
	_res.anchor_bottom = 1.0
	_res.offset_left = -170
	_res.offset_right = 230
	_res.offset_top = -132
	_res.offset_bottom = -104
	add_child(_res)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG_DEEP, UITheme.BORDER_BRIGHT, 1, 2, 6))
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = Label.new()
	_tip_label.add_theme_font_size_override("font_size", 14)
	_tip.add_child(_tip_label)
	add_child(_tip)
	_tip.visible = false
	Combat.combat_started.connect(_rebuild_order)
	Combat.turn_started.connect(func(_c): _rebuild_order())
	Combat.round_started.connect(func(_r): _rebuild_order())
	Combat.combat_ended.connect(func(_w): _rebuild_order())
	Combat.floated.connect(_on_float)
	visible = true


func _rebuild_order() -> void:
	for ch in _order_box.get_children():
		ch.queue_free()
	_res.visible = Combat.active
	if not Combat.active:
		return
	for i in Combat.order.size():
		var c: Combatant = Combat.order[i]
		var p := Portrait.new()
		p.custom_minimum_size = Vector2(40, 48) if i != Combat.turn_index else Vector2(50, 60)
		if c.sheet.is_monster:
			p.char_id = StringName(c.sheet.monster_kind)
			p.name_text = c.display_name()
			p.tooltip_text = c.display_name()
		else:
			p.setup(c.id())
		p.selected = i == Combat.turn_index
		p.modulate = Color(0.4, 0.4, 0.4) if not c.is_alive() else (Color(1, 0.75, 0.72) if c.team == &"enemy" else Color.WHITE)
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		_order_box.add_child(p)


func _on_float(c: Combatant, text: String, kind: StringName) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26 if kind == &"crit" else 20)
	var col := Color(1, 0.92, 0.85)
	match kind:
		&"crit":
			col = Color(1, 0.55, 0.2)
		&"heal":
			col = Color(0.5, 1, 0.55)
		&"miss":
			col = Color(0.75, 0.75, 0.8)
		&"dead":
			col = Color(0.85, 0.3, 0.3)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_floats.append({"label": l, "c": c, "t": 0.0, "dx": randf_range(-14, 14)})


func _process(dt: float) -> void:
	# 飘字
	for f in _floats.duplicate():
		f["t"] += dt
		var l: Label = f["label"]
		var p := world_to_screen(f["c"].pos() + Vector3.UP * 2.0)
		l.position = p + Vector2(f["dx"] - l.size.x * 0.5, -40.0 * f["t"])
		l.modulate.a = clampf(1.6 - f["t"], 0, 1)
		if f["t"] > 1.6:
			l.queue_free()
			_floats.erase(f)
	_update_tip()


func world_to_screen(p: Vector3) -> Vector2:
	if nameplates == null:
		return Vector2.ZERO
	var vp := nameplates.world_view.get_child(0) as SubViewport
	var cam := vp.get_camera_3d() if vp else null
	if cam == null:
		return Vector2.ZERO
	return nameplates._project(cam, p)


func _path_len(p: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(1, p.size()):
		l += Vector2(p[i].x - p[i - 1].x, p[i].z - p[i - 1].z).length()
	return l


func _update_tip() -> void:
	var cc := CombatController.instance
	_tip.visible = false
	if not Combat.active or cc == null:
		return
	var c := cc.my_turn()
	if c == null:
		return
	var lines: Array = []
	# 移动距离（悬停地面，或者近战够不着要先走过去）
	if cc.hover_path.size() >= 2:
		var need := _path_len(cc.hover_path)
		var key := "hud_move" if need <= c.move_left + 0.01 else "hud_move_too_far"
		lines.append(TextDB.ui(key) % [need, c.move_left])
	var t := cc.hover_c
	if t == null:
		# 范围法术悬停地面：列出会被波及的人数
		if not cc.pending.is_empty() and not cc.pending.get("area", {}).is_empty() and cc.hover_valid:
			var center := c.pos() if cc.pending.get("target", "") == "self" else cc.hover_point
			var hit := Combat.in_area(c, cc.pending["area"], center)
			var allies := hit.filter(func(x): return not x.hostile_to(c)).size()
			lines.append(TextDB.ui("hud_area_hits") % [hit.size() - allies, allies])
			if float(cc.pending.get("range", 0)) > 0 and cc.pending.get("target", "") == "point" \
					and c.pos().distance_to(cc.hover_point) > float(cc.pending["range"]):
				lines.append(TextDB.line("rules", "why_out_of_range"))
		_show_tip(lines)
		return
	var a: Dictionary = cc.pending
	if a.is_empty():
		if not t.hostile_to(c):
			_show_tip(lines)
			return
		a = Combat.find_action(c, "attack")
	lines.push_front(t.display_name() + "  " + TextDB.ui("hud_hp") % [t.sheet.hp, t.sheet.max_hp] + "  AC %d" % t.ac())
	var pv := Combat.preview(c, a, t)
	if pv["chance"] >= 0:
		var key := "hud_hit_chance" if pv["kind"] == "hit" else "hud_save_fail_chance"
		lines.append(TextDB.ui(key) % roundi(pv["chance"] * 100))
	var sts: Array = t.status_names()
	if not sts.is_empty():
		lines.append("、".join(sts))
	for r in pv.get("reasons", []):
		lines.append(("▲ " if r.begins_with("adv_") else "▼ ") + TextDB.line("rules", r))
	if c.dist_to(t) > float(a.get("range", 0)) + 0.01 and cc.hover_path.size() < 2:
		lines.append(TextDB.line("rules", "why_out_of_range"))
	_show_tip(lines)


func _show_tip(lines: Array) -> void:
	if lines.is_empty():
		return
	_tip_label.text = "\n".join(lines)
	_tip.visible = true
	_tip.reset_size()
	_tip.position = (get_viewport().get_mouse_position() + Vector2(18, 12)).clamp(Vector2.ZERO, size - _tip.size)


## 资源条：动作 / 附赠 / 反应 / 移动 / 法术位。用图形画，不用字形。
class ResourceBar extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var c := Combat.current()
		if c == null or c.team != &"party":
			return
		var x := 6.0
		var y := size.y * 0.5
		# 动作：绿色圆
		for i in maxi(1, c.actions):
			draw_circle(Vector2(x + 8, y), 8, Color(0.3, 0.85, 0.35) if i < c.actions else Color(0.25, 0.25, 0.25))
			x += 20
		# 附赠：橙色三角
		var col := Color(1, 0.6, 0.15) if c.bonus > 0 else Color(0.25, 0.25, 0.25)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 8, y - 9), Vector2(x + 17, y + 7), Vector2(x - 1, y + 7)]), col)
		x += 24
		# 反应：紫色菱形
		col = Color(0.7, 0.45, 1) if c.reaction > 0 else Color(0.25, 0.25, 0.25)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 8, y - 9), Vector2(x + 16, y), Vector2(x + 8, y + 9), Vector2(x, y)]), col)
		x += 26
		# 移动力条
		var w := 110.0
		draw_rect(Rect2(x, y - 4, w, 8), UITheme.BG_DEEP)
		var frac := clampf(c.move_left / maxf(0.01, c.speed()), 0, 1) if c.move_left <= c.speed() else 1.0
		draw_rect(Rect2(x, y - 4, w * frac, 8), Color(0.95, 0.85, 0.5))
		draw_rect(Rect2(x, y - 4, w, 8), UITheme.BORDER, false)
		var f := get_theme_default_font()
		draw_string(f, Vector2(x + w + 6, y + 5), "%.1fm" % c.move_left, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.TEXT)
		x += w + 52
		# 法术位：每环一组小方块
		var s := c.sheet
		for lvl in range(1, 4):
			var total := 0
			var free := s.slots_free(lvl)
			if lvl <= s.slots_max.size():
				total += s.slots_max[lvl - 1]
			if s.pact_level == lvl:
				total += s.pact_count
			if total == 0:
				continue
			draw_string(f, Vector2(x, y + 5), "%d" % lvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UITheme.TEXT_DIM)
			x += 10
			for i in total:
				draw_rect(Rect2(x, y - 5, 9, 10), Color(0.45, 0.6, 1) if i < free else Color(0.25, 0.25, 0.25))
				x += 12
			x += 6
