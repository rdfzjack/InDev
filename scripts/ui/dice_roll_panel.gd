class_name DiceRollPanel
extends Control
## 对话检定的骰子面板（BG3 式）：
##   技能名 / "魅力检定"
##   难度等级（DC 原样显示：可能是负数、45、{难度}）
##   d20（点一下会转，然后出数）
##   加值卡片：属性 +x、熟练 +y（专精 / 万事通）
##   总加值
## 出数之后显示成功 / 失败，再点一下继续。
##
## roll(check, sheet) 是协程：await 它拿到 {success, natural, total}。

signal finished(result: Dictionary)

static var instance: DiceRollPanel

const SPIN_SEC := 1.1

var _title: Label
var _sub: Label
var _dc: Label
var _die: D20Face
var _hint: Label
var _cards: HBoxContainer
var _total: Label
var _result: Label

var _check: Dictionary
var _sheet: CharacterSheet
var _state := "idle"   # idle / ready / spinning / done
var _res := {}


func _init() -> void:
	instance = self


## 对话之外也能用（开锁、搜查……）。await DiceRollPanel.check({...}, sheet)
static func check(chk: Dictionary, s: CharacterSheet) -> Dictionary:
	return await instance.roll(chk, s)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel(Color(0.1, 0.08, 0.16, 0.96), UITheme.BORDER_BRIGHT, 2, 18, 18))
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.08
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(340, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(v)
	_title = _label(v, 26, UITheme.TEXT)
	_sub = _label(v, 16, UITheme.TEXT_DIM)
	var dch := _label(v, 13, UITheme.TEXT_DIM)
	dch.text = TextDB.ui("dice_dc")
	_dc = _label(v, 34, Color(1, 1, 1))
	_die = D20Face.new()
	_die.custom_minimum_size = Vector2(150, 150)
	_die.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_die)
	_hint = _label(v, 15, UITheme.TEXT_GOLD)
	_result = _label(v, 24, Color(1, 1, 1))
	_cards = HBoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 8)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_cards)
	_total = _label(v, 16, UITheme.TEXT)
	visible = false


func _label(parent: Control, size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## 一次检定的数值拆解（UI 和结算共用）
static func breakdown(check: Dictionary, s: CharacterSheet) -> Dictionary:
	var sk: String = check["skill"]
	var ab: String = check.get("ability", "")
	if ab == "":
		ab = CharacterSheet.SKILL_ABILITY.get(sk, "cha")
	var cards: Array = [{"key": "ab_" + ab, "value": s.mod(ab)}]
	if sk in s.expertise:
		cards.append({"key": "dice_expertise", "value": s.proficiency() * 2})
	elif sk in s.skills:
		cards.append({"key": "dice_proficiency", "value": s.proficiency()})
	elif s.has_feature("jack_of_all_trades"):
		cards.append({"key": "feat_jack_of_all_trades", "value": s.proficiency() / 2})
	var total := 0
	for c in cards:
		total += int(c["value"])
	var dc_text: String = check.get("dc_text", "10")
	var dc := int(dc_text) if dc_text.is_valid_int() else 10
	return {"ability": ab, "cards": cards, "bonus": total, "dc": dc, "dc_text": dc_text}


func roll(check: Dictionary, s: CharacterSheet) -> Dictionary:
	_check = check
	_sheet = s
	var b := breakdown(check, s)
	_title.text = TextDB.line("rules", "skill_" + check["skill"])
	_sub.text = TextDB.ui("dice_ability_check") % TextDB.line("rules", "ab_" + b["ability"])
	_dc.text = b["dc_text"]
	_die.number = 20
	_die.rot = 0.0
	_die.tint = Color(0.25, 0.75, 0.95)
	_hint.text = TextDB.ui("dice_click")
	_result.text = ""
	for c in _cards.get_children():
		c.queue_free()
	for c in b["cards"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UITheme.panel(Color(0.2, 0.15, 0.3, 0.95), UITheme.BORDER, 1, 6, 8))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cv := VBoxContainer.new()
		cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(cv)
		_label(cv, 18, UITheme.TEXT).text = "%+d" % int(c["value"])
		_label(cv, 12, UITheme.TEXT_DIM).text = TextDB.line("rules", c["key"]) if TextDB.has("rules", c["key"]) else TextDB.ui(c["key"])
		_cards.add_child(card)
	_total.text = TextDB.ui("dice_total") % b["bonus"]
	# 奇怪的 DC：负数 / 45 / 没替换。旁白会说。
	if not String(b["dc_text"]).is_valid_int():
		Bus.report(&"check_dc_unresolved")
	elif b["dc"] < 0:
		Bus.report(&"check_negative_dc")
	elif b["dc"] >= 40:
		Bus.report(&"check_impossible_dc")
	visible = true
	_state = "ready"
	_res = {}
	await finished
	visible = false
	return _res


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(e: InputEvent) -> void:
	if visible and (e.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		_advance()


func _advance() -> void:
	match _state:
		"ready":
			_spin()
		"done":
			_state = "idle"
			finished.emit(_res)


func _spin() -> void:
	_state = "spinning"
	_hint.text = ""
	var b := breakdown(_check, _sheet)
	var r := Dice.d20(b["bonus"])
	var t := 0.0
	while t < SPIN_SEC:
		var dt := get_process_delta_time() if is_inside_tree() else 0.016
		t += maxf(dt, 0.016)
		_die.number = Dice.rng.randi_range(1, 20) if t < SPIN_SEC - 0.15 else r.natural
		_die.rot += 18.0 * dt * (1.0 - t / SPIN_SEC)
		_die.queue_redraw()
		await get_tree().process_frame
	_die.number = r.natural
	_die.rot = 0.0
	# BG3：对话检定掷出 20 必定成功，1 必定失败
	var ok: bool = r.natural == 20 or (r.natural != 1 and r.total >= b["dc"])
	_res = {"success": ok, "natural": r.natural, "total": r.total, "dc": b["dc"]}
	_die.tint = Color(0.35, 0.85, 0.4) if ok else Color(0.85, 0.3, 0.25)
	_die.queue_redraw()
	var head := TextDB.ui("dice_crit_success") if r.natural == 20 else (TextDB.ui("dice_crit_fail") if r.natural == 1 else TextDB.ui("dice_success" if ok else "dice_fail"))
	_result.text = "%s    %d + %d = %d" % [head, r.natural, b["bonus"], r.total]
	_result.add_theme_color_override("font_color", Color(0.5, 1, 0.55) if ok else Color(1, 0.45, 0.4))
	_hint.text = TextDB.ui("dice_continue")
	Meta.bump("dialogue_checks")
	Meta.bump("dialogue_checks_" + ("ok" if ok else "fail"))
	_state = "done"


## 画一个 d20 的正面（六边形外框 + 中间三角形 + 数字），占位，美术到了换贴图。
class D20Face extends Control:
	var number := 20
	var rot := 0.0
	var tint := Color(0.25, 0.75, 0.95)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.48
		var hexa := PackedVector2Array()
		for i in 6:
			var a := rot + TAU * i / 6.0 - PI / 2.0
			hexa.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(hexa, tint.darkened(0.25))
		var tri := PackedVector2Array()
		for i in 3:
			var a := rot + TAU * i / 3.0 - PI / 2.0
			tri.append(c + Vector2(cos(a), sin(a)) * r * 0.78)
		draw_colored_polygon(tri, tint)
		for i in 3:
			draw_line(tri[i], hexa[i * 2], tint.lightened(0.4), 1.5, true)
			draw_line(tri[i], tri[(i + 1) % 3], tint.lightened(0.5), 1.5, true)
		hexa.append(hexa[0])
		draw_polyline(hexa, tint.lightened(0.5), 2.0, true)
		var f := get_theme_default_font()
		var fs := int(r * 0.55)
		var s := str(number)
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, c + Vector2(-w.x * 0.5, fs * 0.38), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
