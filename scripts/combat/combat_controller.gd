class_name CombatController
extends Node3D
## 战斗输入（BG3 式）：
##   左键点地面        移动（路径超出移动力的部分标红，只走能走的）
##   左键点敌人        默认近战攻击（够不着会先走过去）
##   技能栏选一个行动  进入瞄准：悬停显示命中率，点目标/地面执行
##   右键              取消瞄准
##   空格              结束回合
## 同时负责地面提示和单位倒地/死亡的表现同步。

signal hover_changed

static var instance: CombatController

var pending: Dictionary = {}
var hover_c: Combatant
var hover_point := Vector3.ZERO
var hover_valid := false
var hover_path := PackedVector3Array()
var busy := false

var gizmos: CombatGizmos
var _down_state := {}


func _init() -> void:
	instance = self


func _ready() -> void:
	gizmos = CombatGizmos.new()
	add_child(gizmos)
	Combat.turn_started.connect(func(_c): pending = {}; _sync_bodies())
	Combat.acted.connect(func(_c, _a, _t): _sync_bodies())
	Combat.combat_ended.connect(func(_w): pending = {}; gizmos.clear(); _sync_bodies())
	Combat.moved.connect(func(_c, _p): _sync_bodies())


func my_turn() -> Combatant:
	var c := Combat.current()
	if c and c.team == &"party" and c.can_act() and not busy:
		return c
	return null


func select_action(a: Dictionary) -> void:
	var c := my_turn()
	if c == null:
		return
	if a.get("target", "") == "self":
		await Combat.perform(c, a, c)
		pending = {}
		return
	pending = a
	hover_changed.emit()


func cancel() -> void:
	pending = {}
	hover_changed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not Combat.active or (ReactionPrompt.instance and ReactionPrompt.instance.is_open()):
		return
	if e is InputEventMouseMotion:
		_hover(e.position)
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			get_viewport().set_input_as_handled()
		elif e.button_index == MOUSE_BUTTON_LEFT and my_turn():
			_hover(e.position)
			get_viewport().set_input_as_handled()
			_click()
	elif e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_SPACE and my_turn():
		get_viewport().set_input_as_handled()
		Combat.end_turn()


func _hover(screen: Vector2) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var from := cam.project_ray_origin(screen)
	var to := from + cam.project_ray_normal(screen) * 200.0
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 2 | 16)
	var hit := space.intersect_ray(q)
	hover_c = null
	if not hit.is_empty() and hit["collider"] is Actor:
		hover_c = (hit["collider"] as Actor).combatant
	var qg := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hg := space.intersect_ray(qg)
	hover_valid = not hg.is_empty()
	if hover_valid:
		hover_point = hg["position"]
	if hover_c:
		hover_point = hover_c.pos()
		hover_valid = true
	hover_path = PackedVector3Array()
	var c := my_turn()
	if c and hover_valid:
		var act := pending
		if act.is_empty() and hover_c and hover_c.hostile_to(c) and hover_c.is_alive():
			act = Combat.find_action(c, "attack")
		if act.is_empty() and hover_c == null:
			# 普通悬停地面：移动路径
			hover_path = CombatAI.path_to(c, hover_point)
		elif hover_c and not act.is_empty() and float(act.get("range", 0)) <= Combat.REACH + 0.1 \
				and c.dist_to(hover_c) > float(act["range"]):
			# 近战够不着：预览走过去的路线
			hover_path = CombatAI.trim_path_end(CombatAI.path_to(c, hover_c.pos()), float(act["range"]) - 0.4)
	hover_changed.emit()


func _click() -> void:
	var c := my_turn()
	if c == null:
		return
	if not pending.is_empty():
		var a := pending
		match a.get("target", ""):
			"point":
				if c.pos().distance_to(hover_point) <= float(a["range"]) or float(a["range"]) == 0:
					pending = {}
					await Combat.perform(c, a, hover_point)
			_:
				if hover_c == null:
					return
				if not Combat.valid_target(c, a, hover_c) and float(a["range"]) <= Combat.REACH + 0.1:
					await _approach_then(c, a, hover_c)
				elif await Combat.perform(c, a, hover_c):
					pending = {}
		hover_changed.emit()
		return
	if hover_c and hover_c.hostile_to(c) and hover_c.is_alive():
		var atk := Combat.find_action(c, "attack")
		if Combat.why_not(c, atk) == "":
			await _approach_then(c, atk, hover_c)
		return
	if hover_valid and hover_c == null:
		busy = true
		var walked := await Combat.move_along(c, CombatAI.path_to(c, hover_point))
		await CombatAI.animate(c, walked)
		busy = false


func _approach_then(c: Combatant, a: Dictionary, t: Combatant) -> void:
	busy = true
	if c.dist_to(t) > float(a["range"]):
		await CombatAI.approach(c, t, float(a["range"]) - 0.4)
	busy = false
	if Combat.valid_target(c, a, t):
		await Combat.perform(c, a, t)
		pending = {}


func _process(_dt: float) -> void:
	if not Combat.active:
		return
	var c := Combat.current()
	gizmos.begin()
	if c and c.team == &"party" and c.can_act():
		gizmos.circle(c.pos(), c.move_left, CombatGizmos.COL_MOVE, true)
		if hover_path.size() >= 2:
			gizmos.path(hover_path, c.move_left)
		if not pending.is_empty():
			var r := float(pending.get("range", 0))
			if r > 0 and r <= Combat.REACH + 0.1:
				# 近战接触：实线小圈
				gizmos.circle(c.pos(), r, CombatGizmos.COL_AREA)
			elif r > 0 and pending.get("area", {}).get("shape", "") != "cone":
				gizmos.circle(c.pos(), r, CombatGizmos.COL_RANGE, true)
			if hover_c and pending.get("area", {}).is_empty() and pending.get("target", "") != "self":
				# 单体目标：目标脚下画圈，够得着金色，够不着红色
				var ok := Combat.valid_target(c, pending, hover_c)
				gizmos.circle(hover_c.pos(), 0.7, Color(1, 0.85, 0.4) if ok else CombatGizmos.COL_PATH_BAD)
			var area: Dictionary = pending.get("area", {})
			if not area.is_empty() and hover_valid:
				match area.get("shape", ""):
					"sphere":
						gizmos.circle(hover_point, float(area["size"]), CombatGizmos.COL_AREA)
					"cone":
						gizmos.cone(c.pos(), hover_point, float(area["size"]), CombatGizmos.COL_AREA)
					"cube":
						gizmos.square(c.pos(), float(area["size"]), CombatGizmos.COL_AREA)
	# 范围法术：范围内的单位脚下标红
	if c and not pending.is_empty() and not pending.get("area", {}).is_empty() and hover_valid:
		var center := c.pos() if pending.get("target", "") == "self" else hover_point
		for t in Combat.in_area(c, pending["area"], center):
			gizmos.circle(t.pos(), 0.55, CombatGizmos.COL_PATH_BAD)
	# 当前回合的单位脚下画个圈
	if c:
		gizmos.circle(c.pos(), 0.6, Color(1, 0.9, 0.5) if c.team == &"party" else Color(1, 0.35, 0.3))
	gizmos.finish()


## 倒地/死亡/起身的表现同步
func _sync_bodies() -> void:
	for c in Combat.combatants:
		if c.node == null or not is_instance_valid(c.node):
			continue
		var state := "dead" if not c.is_alive() else ("down" if c.is_down() else "up")
		if _down_state.get(c, "up") == state:
			continue
		_down_state[c] = state
		match state:
			"dead":
				c.node.on_died()
			"down":
				c.node.set_downed(true)
			"up":
				c.node.set_downed(false)
