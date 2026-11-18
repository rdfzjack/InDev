class_name CutscenePlayer
extends Control
## 播放 Cutscene：上下黑边、自动走的字幕、右下角"按住 空格 跳过"。
## 播放期间隐藏 HUD、队伍不能操作（playing_changed，main 接到和对话一样的开关上）。
##
## sticky_hint：过场结束后跳过提示也不消失（被害村民之后，村庄里那行字一直在角落）。

signal playing_changed(on: bool)

static var instance: CutscenePlayer

const BAR := 0.11            # 黑边高度（屏幕比例）
const SKIP_HOLD_SEC := 1.2

var fast := false            # 测试用：所有等待变成一帧
var sticky_hint := false:
	set(v):
		sticky_hint = v
		if is_inside_tree():
			_hint.visible = v or _playing
			_ring.visible = _hint.visible

var _top: ColorRect
var _bottom: ColorRect
var _sub: RichTextLabel
var _hint: Label
var _ring: SkipRing
var _cam: Camera3D
var _prev_cam: Camera3D
var _playing := false
var _skipped := false
var _skip_progress := 0.0
var _cs: Cutscene
var _tween: Tween


func _init() -> void:
	instance = self


static func is_playing() -> bool:
	return instance != null and instance._playing


static func play(cs: Cutscene) -> bool:
	return await instance.run(cs)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top = _bar(0.0, BAR)
	_bottom = _bar(1.0 - BAR, 1.0)
	_sub = RichTextLabel.new()
	_sub.bbcode_enabled = true
	_sub.fit_content = true
	_sub.scroll_active = false
	_sub.anchor_left = 0.12
	_sub.anchor_right = 0.88
	_sub.anchor_top = 1.0 - BAR - 0.07
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_font_size_override("normal_font_size", 19)
	_sub.add_theme_font_size_override("italics_font_size", 19)
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_child(_sub)
	_ring = SkipRing.new()
	_ring.custom_minimum_size = Vector2(26, 26)
	_ring.size = Vector2(26, 26)
	_ring.anchor_left = 1.0
	_ring.anchor_right = 1.0
	_ring.anchor_top = 1.0
	_ring.anchor_bottom = 1.0
	_ring.offset_left = -186
	_ring.offset_right = -160
	_ring.offset_top = -42
	_ring.offset_bottom = -16
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_hint = Label.new()
	_hint.text = TextDB.ui("cutscene_skip_hint")
	_hint.anchor_left = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -152
	_hint.offset_right = -12
	_hint.offset_top = -40
	_hint.offset_bottom = -16
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_set_visible(false)
	Router.level_loaded.connect(func(_l): sticky_hint = false)


func _bar(a: float, b: float) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.anchor_top = a
	r.anchor_bottom = b
	r.anchor_right = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## 过场里在右下角黑边上；过场外（村庄里一直挂着那行字）挪到左下角，不压右下角的日志
func _place_hint(in_cutscene: bool) -> void:
	var x0 := -186.0 if in_cutscene else 0.0
	var a := 1.0 if in_cutscene else 0.0
	for c in [_ring, _hint]:
		c.anchor_left = a
		c.anchor_right = a
	_ring.offset_left = x0 + (0.0 if in_cutscene else 14.0)
	_ring.offset_right = _ring.offset_left + 26.0
	_hint.offset_left = _ring.offset_right + 8.0
	_hint.offset_right = _hint.offset_left + 140.0


func _set_visible(on: bool) -> void:
	_top.visible = on
	_bottom.visible = on
	_sub.visible = on
	_sub.text = ""
	_hint.visible = on or sticky_hint
	_ring.visible = _hint.visible
	_place_hint(on)
	mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


## 返回 true = 被跳过了
func run(cs: Cutscene) -> bool:
	if _playing:
		return false
	_cs = cs
	_playing = true
	_skipped = false
	_skip_progress = 0.0
	Meta.bump("cutscene_" + String(cs.id))
	for n in get_tree().get_nodes_in_group("party") + get_tree().get_nodes_in_group("npc"):
		if n.has_method("stop"):
			n.stop()
	var world: Node = Router.current_level if Router.current_level else get_tree().current_scene
	_prev_cam = world.get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.1
	world.add_child(_cam)
	if _prev_cam:
		_cam.global_transform = _prev_cam.global_transform
	_cam.make_current()
	_set_visible(true)
	playing_changed.emit(true)
	for s in cs.steps:
		if not is_inside_tree():
			break
		match s["t"]:
			"cam":
				_kill_tween()
				_place(s["pos"], s["look"])
			"cam_move":
				_kill_tween()
				if _skipped or fast:
					_place(s["pos"], s["look"])
				else:
					var from := _cam.global_transform
					var to := _look_xform(s["pos"], s["look"])
					_tween = create_tween()
					_tween.tween_method(func(t: float): _cam.global_transform = from.interpolate_with(to, t), 0.0, 1.0, float(s["sec"])) \
						.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			"line":
				var r := TextDB.row("cutscene", s["key"])
				var who: String = r.get("speaker", "narrator")
				var body := TextDB.line("cutscene", s["key"])
				if who == "narrator" or who == "":
					_sub.text = "[center][i][color=#%s]%s[/color][/i][/center]" % [UITheme.NARRATOR.to_html(false), body]
				else:
					_sub.text = "[center][color=#%s]%s[/color]%s%s[/center]" % [UITheme.TEXT_GOLD.to_html(false), TextDB.char_name(StringName(who)), TextDB.ui("speaker_sep"), body]
					Voice.speak(StringName(who), body)
				await _wait(clampf(1.4 + body.length() * 0.11, 2.0, 6.0))
			"wait":
				await _wait(float(s["sec"]))
			"run":
				(s["f"] as Callable).call()
	_kill_tween()
	for f in cs.on_end:
		f.call()
	_set_visible(false)
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	_cam = null
	_playing = false
	playing_changed.emit(false)
	if _skipped:
		Meta.bump("cutscene_skipped_" + String(cs.id))
	return _skipped


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _look_xform(pos: Vector3, look: Vector3) -> Transform3D:
	var t := Transform3D(Basis(), pos)
	return t.looking_at(look, Vector3.UP)


func _place(pos: Vector3, look: Vector3) -> void:
	_cam.global_transform = _look_xform(pos, look)


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec and not _skipped and not fast and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
	if fast:
		await get_tree().process_frame


func _process(dt: float) -> void:
	if not _hint.visible:
		return
	var holding := _playing and Input.is_key_pressed(KEY_SPACE)
	var cap := _cs.skip_breaks_at if _cs else 1.0
	if holding and not _skipped:
		# 坏掉的跳过：转到一半停住，松开也不回去，过场照常播完
		_skip_progress = minf(_skip_progress + dt / SKIP_HOLD_SEC, cap)
		if cap < 1.0 and _skip_progress >= cap and not _cs.has_meta("skip_reported"):
			_cs.set_meta("skip_reported", true)
			Bus.report(&"skip_broken")
		if _skip_progress >= 1.0:
			_skipped = true
	elif cap >= 1.0:
		_skip_progress = maxf(0.0, _skip_progress - dt * 2.0)
	if not _playing and not sticky_hint:
		_skip_progress = 0.0
	_ring.progress = _skip_progress
	_ring.queue_redraw()


## 跳过进度圈
class SkipRing extends Control:
	var progress := 0.0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.25), 2.0, true)
		if progress > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * progress, 32, Color(1, 1, 1, 0.95), 3.0, true)
