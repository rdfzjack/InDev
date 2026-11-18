class_name CombatAI
## 敌人回合。简单：找最近的能打的人，走过去打；有远程武器且不在近战里就射。

const PAUSE := 0.35


static func take_turn(c: Combatant) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await _wait(tree, PAUSE)
	if not Combat.active or not c.can_act():
		return
	var target := _pick_target(c)
	if target == null:
		return
	var acts := Combat.actions_for(c)
	# 充能技能（龙息）：锥形里能罩住至少两个敌人，或者只剩一个敌人
	for a in acts:
		if a["kind"] != "special" or Combat.why_not(c, a) != "":
			continue
		var best_pt := Vector3.ZERO
		var best_n := 0
		for o in Combat.combatants:
			if not o.hostile_to(c) or not o.is_alive() or c.dist_to(o) > float(a["range"]):
				continue
			var n := Combat.in_area(c, a["area"], o.pos()).filter(func(x): return x.hostile_to(c)).size()
			if n > best_n:
				best_n = n
				best_pt = o.pos()
		var foes := Combat.combatants.filter(func(o): return o.hostile_to(c) and o.can_act()).size()
		if best_n >= 2 or (best_n >= 1 and foes == 1):
			await _wait(tree, PAUSE)
			await Combat.perform(c, a, best_pt)
			return
	var melee := acts.filter(func(a): return a["kind"] == "multiattack")
	melee.append_array(acts.filter(func(a): return a["kind"] == "monster" and c.sheet.monster_attacks[a["attack_index"]]["kind"] == "melee"))
	var ranged := acts.filter(func(a): return a["kind"] == "monster" and c.sheet.monster_attacks[a["attack_index"]]["kind"] == "ranged")
	var in_melee := Combat.combatants.any(func(o): return o.hostile_to(c) and o.can_act() and o.dist_to(c) <= Combat.REACH)
	# 远程优先：有弓、不在近战里、目标不在走一步就能砍到的地方
	if not ranged.is_empty() and not in_melee and c.dist_to(target) > c.move_left * 0.5 + Combat.REACH:
		var a: Dictionary = ranged[0]
		var m: Dictionary = c.sheet.monster_attacks[a["attack_index"]]
		if c.dist_to(target) > float(m["range"]):
			await approach(c, target, float(m["range"]) - 1.0)
		if Combat.valid_target(c, a, target):
			await Combat.perform(c, a, target)
		return
	if melee.is_empty():
		return
	var reach := float(melee[0]["range"])
	if c.dist_to(target) > reach:
		await approach(c, target, reach - 0.4)
	if not Combat.active or not c.can_act():
		return
	if c.dist_to(target) > reach:
		# 够不着：冲刺
		var dash := Combat.find_action(c, "dash")
		if not dash.is_empty() and await Combat.perform(c, dash, c):
			await approach(c, target, reach - 0.4)
		return
	await _wait(tree, PAUSE)
	if Combat.active and target.is_alive():
		await Combat.perform(c, melee[0], target)


static func _pick_target(c: Combatant) -> Combatant:
	var best: Combatant = null
	var best_score := INF
	for o in Combat.combatants:
		if not o.hostile_to(c) or not o.is_alive():
			continue
		# 隐匿的人看不见（除非贴脸）
		if o.has_status(&"hidden") and c.dist_to(o) > Combat.REACH:
			continue
		var score := c.dist_to(o)
		if o.is_down():
			score += 30.0
		if best == null or score < best_score:
			best = o
			best_score = score
	return best


## 走到离目标 stop_dist 以内
static func approach(c: Combatant, target: Combatant, stop_dist: float) -> void:
	var path := path_to(c, target.pos())
	path = trim_path_end(path, stop_dist)
	if path.size() < 2:
		return
	var walked := await Combat.move_along(c, path)
	await animate(c, walked)


static func path_to(c: Combatant, to: Vector3) -> PackedVector3Array:
	var from := c.pos()
	if c.node and c.node.is_inside_tree():
		var map := c.node.get_world_3d().navigation_map
		var p := NavigationServer3D.map_get_path(map, from, to, true)
		if p.size() >= 2:
			p[0] = from
			return p
	return PackedVector3Array([from, to])


static func trim_path_end(p: PackedVector3Array, stop_dist: float) -> PackedVector3Array:
	if p.size() < 2:
		return p
	var goal := p[p.size() - 1]
	var out := PackedVector3Array([p[0]])
	for i in range(1, p.size()):
		var a := out[out.size() - 1]
		var b := p[i]
		var da := Vector2(a.x - goal.x, a.z - goal.z).length()
		var db := Vector2(b.x - goal.x, b.z - goal.z).length()
		if db >= stop_dist:
			out.append(b)
			continue
		# 段内找到离目标恰好 stop_dist 的点
		if da > stop_dist:
			var lo := 0.0
			var hi := 1.0
			for k in 20:
				var m := (lo + hi) * 0.5
				var q := a.lerp(b, m)
				if Vector2(q.x - goal.x, q.z - goal.z).length() > stop_dist:
					lo = m
				else:
					hi = m
			out.append(a.lerp(b, lo))
		break
	return out


## 让 3D 节点沿逻辑路径走（表现层）。没有节点就直接返回。
static func animate(c: Combatant, walked: PackedVector3Array) -> void:
	if walked.size() < 2 or c.node == null or not c.node.has_method("follow_path"):
		return
	if Combat.instant:
		c.node.global_position = walked[walked.size() - 1]
		return
	var end := walked[walked.size() - 1]
	# 逻辑位置已经到终点；先把节点放回起点再走过去
	c.node.global_position = walked[0]
	c.node.follow_path(walked)
	await c.node.path_done
	c.node.global_position = end


static func _wait(tree: SceneTree, sec: float) -> void:
	if Combat.instant:
		return
	await tree.create_timer(sec).timeout
