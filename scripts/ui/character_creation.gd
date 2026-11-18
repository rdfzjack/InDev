class_name CharacterCreation
extends Control
## 角色创建（BG3 式）。做得很认真：
##   左边分页（种族 / 职业 / 背景 / 属性 / 外貌 / 名字），中间内容，右边 3D 预览 + 小结，右下确认。
##   属性：27 点购点，8–15；种族加值 +2 / +1 自由分配（BG3）。
## 确认以后游戏以默认圣骑士开始。输入的名字、选的一切都不生效。中间没有任何暗示，进去之后也不宣布。
## 停留时间计入 Meta（chargen_seconds），结局统计会用。

signal confirmed

const ABILITIES := ["str", "dex", "con", "int", "wis", "cha"]
const TABS := ["race", "class", "background", "abilities", "appearance", "name"]

var choice := {
	"race": "human", "class": "fighter", "background": "soldier",
	"scores": [15, 13, 14, 8, 12, 8], "plus2": "str", "plus1": "con",
	"body": 1, "pronoun": "he", "skin": 1, "hair": 1, "hair_color": 1, "height": 0.5, "name": "",
}

var _tab := "race"
var _tabs: VBoxContainer
var _content: VBoxContainer
var _summary: Label
var _preview: PreviewModel
var _time_acc := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.045, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var title := _label(_t("cg_title"), 26, UITheme.TEXT_GOLD)
	title.position = Vector2(32, 18)
	add_child(title)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24
	row.offset_right = -24
	row.offset_top = 70
	row.offset_bottom = -70
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	_tabs = VBoxContainer.new()
	_tabs.custom_minimum_size.x = 130
	_tabs.add_theme_constant_override("separation", 6)
	row.add_child(_tabs)
	for t in TABS:
		var b := Button.new()
		b.name = "Tab_" + t
		b.text = _t("cg_tab_" + t)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(130, 40)
		b.pressed.connect(_show_tab.bind(t))
		_tabs.add_child(b)
	var mid := PanelContainer.new()
	mid.add_theme_stylebox_override("panel", UITheme.panel(UITheme.BG, UITheme.BORDER, 1, 4, 14))
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 260
	right.add_theme_constant_override("separation", 10)
	row.add_child(right)
	var pv := SubViewportContainer.new()
	pv.stretch = true
	pv.custom_minimum_size = Vector2(260, 360)
	right.add_child(pv)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	pv.add_child(vp)
	_preview = PreviewModel.new()
	vp.add_child(_preview)
	_summary = _label("", 15, UITheme.TEXT)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_summary)
	var confirm := Button.new()
	confirm.name = "Confirm"
	confirm.text = _t("cg_confirm")
	confirm.custom_minimum_size = Vector2(180, 44)
	confirm.anchor_left = 1.0
	confirm.anchor_right = 1.0
	confirm.anchor_top = 1.0
	confirm.anchor_bottom = 1.0
	confirm.offset_left = -204
	confirm.offset_right = -24
	confirm.offset_top = -58
	confirm.offset_bottom = -14
	confirm.add_theme_font_size_override("font_size", 20)
	confirm.add_theme_stylebox_override("normal", UITheme.panel(Color(0.25, 0.18, 0.08), UITheme.BORDER_BRIGHT, 2, 4, 6))
	confirm.pressed.connect(_confirm)
	add_child(confirm)
	_show_tab("race")


func _t(k: String) -> String:
	return TextDB.line("chargen", k)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _process(dt: float) -> void:
	if not is_visible_in_tree():
		return
	_time_acc += dt
	while _time_acc >= 1.0:
		_time_acc -= 1.0
		Meta.bump("chargen_seconds")


# ------------------------------------------------------------------ 分页

func _show_tab(t: String) -> void:
	_tab = t
	for b in _tabs.get_children():
		(b as Button).button_pressed = b.name == "Tab_" + t
	for c in _content.get_children():
		c.queue_free()
	match t:
		"race":
			_list(Rules.chargen.get("races", []), "race", "race_")
		"class":
			_list(Rules.chargen.get("classes", {}).keys(), "class", "class_")
		"background":
			_list(Rules.chargen.get("backgrounds", {}).keys(), "background", "bg_")
		"abilities":
			_abilities()
		"appearance":
			_appearance()
		"name":
			_name()
	_refresh()


## 一列选项 + 选中项的说明
func _list(ids: Array, key: String, prefix: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for id in ids:
		var b := Button.new()
		b.name = "Opt_" + String(id)
		b.text = _t(prefix + String(id))
		b.toggle_mode = true
		b.button_pressed = choice[key] == id
		b.custom_minimum_size = Vector2(130, 36)
		b.pressed.connect(func():
			choice[key] = id
			if key == "class":
				_recommend()
			_show_tab(_tab))
		grid.add_child(b)
	var sel := String(choice[key])
	_content.add_child(_label(_t(prefix + sel), 22, UITheme.TEXT_GOLD))
	var desc := _label(_t(prefix + sel + "_desc"), 16, UITheme.TEXT)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(desc)
	if key == "class":
		var cd: Dictionary = Rules.chargen["classes"][sel]
		_content.add_child(_label(_t("cg_hit_die") % int(cd["hit_die"]), 15, UITheme.TEXT_DIM))
		_content.add_child(_label(_t("cg_primary") % TextDB.line("rules", "ab_" + cd["primary"]), 15, UITheme.TEXT_DIM))
	elif key == "background":
		var sk: Array = Rules.chargen["backgrounds"][sel]
		_content.add_child(_label(_t("cg_skills") % "、".join(sk.map(func(s): return TextDB.line("rules", "skill_" + s))), 15, UITheme.TEXT_DIM))


# ------------------------------------------------------------------ 属性（27 点购点）

static func cost_of(score: int) -> int:
	return int(Rules.chargen["point_buy"]["cost"].get(str(score), 99))


func points_left() -> int:
	var used := 0
	for s in choice["scores"]:
		used += cost_of(int(s))
	return int(Rules.chargen["point_buy"]["budget"]) - used


func final_score(i: int) -> int:
	var ab: String = ABILITIES[i]
	return int(choice["scores"][i]) + (2 if choice["plus2"] == ab else 0) + (1 if choice["plus1"] == ab else 0)


func _recommend() -> void:
	var rec: Array = Rules.chargen["recommended"].get(choice["class"], [])
	if rec.size() == 6:
		choice["scores"] = rec.map(func(x): return int(x))
	var prim: String = Rules.chargen["classes"][choice["class"]]["primary"]
	choice["plus2"] = prim
	choice["plus1"] = "con" if prim != "con" else "dex"


func _abilities() -> void:
	_content.add_child(_label(_t("cg_points_left") % points_left(), 18, UITheme.TEXT_GOLD))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	_content.add_child(grid)
	for i in ABILITIES.size():
		var ab: String = ABILITIES[i]
		grid.add_child(_label(TextDB.line("rules", "ab_" + ab), 16, UITheme.TEXT))
		var minus := Button.new()
		minus.text = "−"
		minus.disabled = int(choice["scores"][i]) <= 8
		minus.pressed.connect(func():
			choice["scores"][i] = int(choice["scores"][i]) - 1
			_show_tab("abilities"))
		grid.add_child(minus)
		grid.add_child(_label(str(choice["scores"][i]), 16, UITheme.TEXT))
		var plus := Button.new()
		plus.text = "+"
		var nxt := int(choice["scores"][i]) + 1
		plus.disabled = nxt > 15 or cost_of(nxt) - cost_of(nxt - 1) > points_left()
		plus.pressed.connect(func():
			choice["scores"][i] = int(choice["scores"][i]) + 1
			_show_tab("abilities"))
		grid.add_child(plus)
		for b in [["plus2", "cg_bonus_2"], ["plus1", "cg_bonus_1"]]:
			var bb := Button.new()
			bb.text = _t(b[1])
			bb.toggle_mode = true
			bb.button_pressed = choice[b[0]] == ab
			bb.pressed.connect(func():
				var other := "plus1" if b[0] == "plus2" else "plus2"
				if choice[other] == ab:
					choice[other] = choice[b[0]]
				choice[b[0]] = ab
				_show_tab("abilities"))
			grid.add_child(bb)
		var fs := final_score(i)
		grid.add_child(_label("%d（%+d）" % [fs, Dice.mod(fs)], 16, UITheme.TEXT_GOLD))
	var rec := Button.new()
	rec.text = _t("cg_recommended")
	rec.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rec.pressed.connect(func():
		_recommend()
		_show_tab("abilities"))
	_content.add_child(rec)


# ------------------------------------------------------------------ 外貌

func _appearance() -> void:
	_content.add_child(_label(_t("cg_body"), 16, UITheme.TEXT_GOLD))
	_options_row("body", [1, 2, 3, 4], func(v): return _t("cg_body_%d" % v))
	_content.add_child(_label(_t("cg_pronouns"), 16, UITheme.TEXT_GOLD))
	_options_row("pronoun", ["he", "she", "they"], func(v): return _t("cg_pronoun_" + v))
	_content.add_child(_label(_t("cg_skin"), 16, UITheme.TEXT_GOLD))
	_swatches("skin", Rules.chargen.get("skin", []))
	_content.add_child(_label(_t("cg_hair"), 16, UITheme.TEXT_GOLD))
	_options_row("hair", [1, 2, 3, 4, 5, 6], func(v): return _t("cg_hair_%d" % v))
	_content.add_child(_label(_t("cg_hair_color"), 16, UITheme.TEXT_GOLD))
	_swatches("hair_color", Rules.chargen.get("hair_color", []))
	_content.add_child(_label(_t("cg_height"), 16, UITheme.TEXT_GOLD))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.01
	sl.value = choice["height"]
	sl.custom_minimum_size.x = 300
	sl.value_changed.connect(func(v):
		choice["height"] = v
		_refresh())
	_content.add_child(sl)


func _options_row(key: String, values: Array, label: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_content.add_child(h)
	for v in values:
		var b := Button.new()
		b.text = label.call(v)
		b.toggle_mode = true
		b.button_pressed = choice[key] == v
		b.pressed.connect(func():
			choice[key] = v
			_show_tab(_tab))
		h.add_child(b)


func _swatches(key: String, colors: Array) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	_content.add_child(h)
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		var sb := UITheme.panel(Color(colors[i]), UITheme.BORDER_BRIGHT if choice[key] == i + 1 else UITheme.BORDER, 3 if choice[key] == i + 1 else 1, 4, 0)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			choice[key] = i + 1
			_show_tab(_tab))
		h.add_child(b)


# ------------------------------------------------------------------ 名字

func _name() -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	_content.add_child(h)
	var le := LineEdit.new()
	le.name = "NameEdit"
	le.placeholder_text = _t("cg_name_hint")
	le.text = choice["name"]
	le.custom_minimum_size.x = 280
	le.max_length = 24
	le.text_changed.connect(func(t):
		choice["name"] = t
		_refresh())
	h.add_child(le)
	var rnd := Button.new()
	rnd.text = _t("cg_random_name")
	rnd.pressed.connect(func():
		choice["name"] = Array(_t("cg_random_names").split("|")).pick_random()
		_show_tab("name"))
	h.add_child(rnd)


# ------------------------------------------------------------------ 小结 / 预览 / 确认

func _refresh() -> void:
	var nm: String = choice["name"] if choice["name"] != "" else "—"
	var lines: Array = [nm, _t("cg_summary") % [_t("race_" + choice["race"]), _t("class_" + choice["class"]), _t("bg_" + choice["background"])]]
	var ab := ""
	for i in ABILITIES.size():
		ab += "%s %d  " % [TextDB.line("rules", "ab_" + ABILITIES[i]), final_score(i)]
	lines.append(ab)
	_summary.text = "\n".join(lines)
	if _preview:
		_preview.apply(choice)


func _confirm() -> void:
	# 选的一切都不生效。不宣布。
	Meta.bump("chargen_confirmed")
	Meta.bump("chargen_class_" + String(choice["class"]))
	confirmed.emit()


## 右边的 3D 预览：占位身体 + 头 + 头发，跟着外貌选项变，慢慢转
class PreviewModel extends Node3D:
	var _body: MeshInstance3D
	var _head: MeshInstance3D
	var _hair: MeshInstance3D
	var _skin_mat: StandardMaterial3D
	var _hair_mat: StandardMaterial3D

	func _ready() -> void:
		var cam := Camera3D.new()
		cam.position = Vector3(0, 1.15, 3.6)
		cam.fov = 38.0
		add_child(cam)
		cam.look_at(Vector3(0, 1.0, 0))
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, 30, 0)
		add_child(light)
		_skin_mat = StandardMaterial3D.new()
		_hair_mat = StandardMaterial3D.new()
		_body = MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.3
		cm.height = 1.5
		_body.mesh = cm
		_body.material_override = _skin_mat
		add_child(_body)
		_head = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.17
		sm.height = 0.34
		_head.mesh = sm
		_head.material_override = _skin_mat
		add_child(_head)
		_hair = MeshInstance3D.new()
		_hair.material_override = _hair_mat
		add_child(_hair)

	func apply(c: Dictionary) -> void:
		if _body == null:
			return
		var skins: Array = Rules.chargen.get("skin", ["#cccccc"])
		var hairs: Array = Rules.chargen.get("hair_color", ["#333333"])
		_skin_mat.albedo_color = Color(skins[clampi(int(c["skin"]) - 1, 0, skins.size() - 1)])
		_hair_mat.albedo_color = Color(hairs[clampi(int(c["hair_color"]) - 1, 0, hairs.size() - 1)])
		var h := lerpf(0.88, 1.12, float(c["height"]))
		var w: float = [1.0, 0.85, 1.15, 0.95][clampi(int(c["body"]) - 1, 0, 3)]
		_body.scale = Vector3(w, h, w)
		_body.position.y = 0.75 * h
		_head.position.y = 1.5 * h + 0.1
		var bm := BoxMesh.new()
		match int(c["hair"]):
			1: bm.size = Vector3(0.36, 0.1, 0.36)
			2: bm.size = Vector3(0.38, 0.5, 0.3)
			3: bm.size = Vector3(0.34, 0.14, 0.42)
			4: bm.size = Vector3(0.01, 0.01, 0.01)
			5: bm.size = Vector3(0.3, 0.45, 0.25)
			_: bm.size = Vector3(0.44, 0.18, 0.44)
		_hair.mesh = bm
		_hair.position = Vector3(0, _head.position.y + 0.11 - (bm.size.y * 0.35 if int(c["hair"]) in [2, 5] else 0.0), 0.05 if int(c["hair"]) in [2, 5] else 0.0)

	func _process(dt: float) -> void:
		rotation.y += dt * 0.5
