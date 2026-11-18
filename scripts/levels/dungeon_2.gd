extends LevelBase
## Dungeon 2（墓园地穴）。环境和系统开始坏。每个房间只负责一件事：
##   A 入口：铁门（铁匠的钥匙 / SL 开锁 DC 15 / 硬砸 DC 18）。守墓人的鬼魂：检定全是坏的
##      （DC 负数、DC 45、DC {难度}、说服用力量）。
##   B 走廊 + C 墓室：战斗触发范围比房间大——还在走廊就进战斗，僵尸在下一个房间，第一轮谁都够不着谁。
##      其中一只死了以后还会轮到他（全队等他，等一会儿，跳过）。
##   D 侧室：宝箱。第一次打开动画播了但没开，再开一次才开。里面是传说装备（全队共享同一个实例）。
##   E 尽头：神秘人（村里那个凶手）。死后尸体往北飞 13 米：在房间深处打死他，就飞进北墙里，
##      交互点在墙另一边，旁白准确告诉你上面有什么。读档重打还是往同一个方向飞。换个位置打有用。
## 布局：从南（z=+）往北（z=-）走。

const VILLAGE := "res://scenes/levels/village.tscn"
const W := Color(0.4, 0.4, 0.44)
const NORTH_WALL_Z := -42.0
const CORPSE_FLIGHT := Vector3(0, 0, -13.0)

var _gate: StaticBody3D
var _gate_inter: Interactable
var _boss: Enemy
var _boss_dead := false


func _init() -> void:
	music = "field"
	level_id = "dungeon_2"
	sky = Color(0.06, 0.06, 0.09)


func _build() -> void:
	floor_box(Vector3(0, 0, -20), Vector2(40, 76), Color(0.3, 0.31, 0.3))
	# A 入口 (z 11..1)
	room(Vector2(0, 6), Vector2(10, 10), [["s", 0.5, 3.0], ["n", 0.5, 2.2]], 4.0, W)
	spawn("from_village", Vector3(0, 0.1, 9.5))
	exit_to(Vector3(0, 0, 12.5), VILLAGE, "from_dungeon2", "exit_to_village")
	narrate_zone(Vector3(0, 0, 8), Vector3(8, 2, 3), "d2_enter")
	_gate = block(Vector3(0, 0, 1), Vector3(2.4, 3.2, 0.3), Color(0.22, 0.22, 0.25))
	_gate_inter = Interactable.new()
	_gate_inter.name = "CryptGate"
	_gate_inter.label_key = "obj_crypt_gate"
	_gate_inter.size = Vector3(2.4, 2.6, 0.7)
	_gate_inter.color = Color(0, 0, 0, 0)
	add_child(_gate_inter)
	_gate_inter.position = Vector3(0, 0, 1.4)
	_gate_inter.interacted.connect(_try_gate)
	var ghost := npc(&"gravekeeper", Vector3(-3, 0.1, 4.5), "res://data/dialogue/gravekeeper.dlg", "start", Color(0.7, 0.85, 0.9))
	ghost.name = "gravekeeper"

	# B 走廊 (z 1..-11)
	room(Vector2(0, -5), Vector2(4, 12), [["s", 0.5, 3.0], ["n", 0.5, 3.0]], 4.0, W)
	# C 墓室 (z -11..-25)
	room(Vector2(0, -18), Vector2(16, 14), [["s", 0.5, 3.0], ["n", 0.5, 2.4], ["e", 0.5, 2.0]], 4.0, W)
	for x in [-5.0, 5.0]:
		block(Vector3(x, 0, -16), Vector3(1.6, 0.9, 2.6), W.darkened(0.25))    # 石棺
	# 触发盒从走廊中段一直盖到墓室北墙：还在走廊就开打
	var enc := encounter(Vector3(0, 0, -13), Vector3(16, 3, 24))
	enc.name = "CryptEncounter"
	enc.body_entered.connect(func(b):
		if b is PartyMember and Combat.active and not enc.has_meta("reported"):
			enc.set_meta("reported", true)
			Bus.report(&"encounter_too_big", &"", enc.global_position))
	var zs := [Vector3(-4, 0.1, -22.5), Vector3(-1.3, 0.1, -23.2), Vector3(1.3, 0.1, -23.2), Vector3(4, 0.1, -22.5)]
	for i in zs.size():
		var z := enemy("zombie", zs[i], enc)
		if i == 2:
			z.set_meta("dead_turn", true)

	# D 侧室 (东)
	room(Vector2(12, -18), Vector2(8, 6), [["w", 0.5, 2.0]], 3.5, W)
	_build_chest(Vector3(14, 0, -18))

	# E 尽头 (z -26..-42)
	room(Vector2(0, -34), Vector2(16, 16), [["s", 0.5, 2.4]], 4.5, W)
	var enc2 := encounter(Vector3(0, 0, -34), Vector3(14, 3, 14))
	enc2.name = "BossEncounter"
	_boss = enemy("hooded_figure", Vector3(0, 0.1, -38.5), enc2)
	_boss.name = "HoodedFigure"
	_boss.placeholder_color = Color(0.12, 0.1, 0.12)
	enemy("skeleton", Vector3(-4, 0.1, -36), enc2)
	enemy("skeleton", Vector3(4, 0.1, -36), enc2)
	# 北墙后面的夹层：封死的，走不进去，从上面看得见
	room(Vector2(0, -47), Vector2(10, 8), [], 4.5, W.darkened(0.1))
	Combat.monster_killed.connect(_on_killed)
	Combat.combat_ended.connect(_on_combat_ended)


func _exit_tree() -> void:
	if Combat.monster_killed.is_connected(_on_killed):
		Combat.monster_killed.disconnect(_on_killed)
	if Combat.combat_ended.is_connected(_on_combat_ended):
		Combat.combat_ended.disconnect(_on_combat_ended)


# ------------------------------------------------------------------ 铁门

func _try_gate(_by: StringName) -> void:
	if _gate == null:
		return
	if Inv.count("crypt_key") > 0:
		Narrator.say("d2_gate_key")
		_open_gate()
		return
	var who := Game.SL if Game.in_party(Game.SL) else Game.selected
	var chk := {"type": "check", "skill": "sleight_of_hand" if who == Game.SL else "athletics",
		"dc_text": "15" if who == Game.SL else "18", "ability": "", "lie": false}
	var res: Dictionary = await DiceRollPanel.check(chk, Game.sheet(who))
	if res.get("success", false):
		_open_gate()
	else:
		Narrator.say("d2_gate_locked")


func _open_gate() -> void:
	_gate.queue_free()
	_gate = null
	_gate_inter.queue_free()
	Game.set_flag(&"d2_gate_open")
	rebake()


# ------------------------------------------------------------------ 宝箱

func _build_chest(at: Vector3) -> void:
	var chest := Interactable.new()
	chest.name = "Chest"
	chest.label_key = "obj_chest"
	chest.size = Vector3(1.0, 0.6, 0.7)
	chest.color = Color(0.55, 0.4, 0.2)
	add_child(chest)
	chest.position = at
	var lid := Placeholders.box(Vector3(1.0, 0.12, 0.7), Color(0.6, 0.45, 0.22))
	lid.name = "Lid"
	var hinge := Node3D.new()
	hinge.name = "Hinge"
	chest.add_child(hinge)
	hinge.position = Vector3(0, 0.62, 0.35)
	hinge.add_child(lid)
	lid.position = Vector3(0, 0, -0.35)
	chest.interacted.connect(func(_by):
		var opened := int(chest.get_meta("opens", 0))
		chest.set_meta("opens", opened + 1)
		if opened == 0:
			# 第一次：动画播了，箱子没开（盖子又弹回去了）
			var tw := create_tween()
			tw.tween_property(hinge, "rotation_degrees:x", -105.0, 0.5)
			tw.tween_interval(0.35)
			tw.tween_property(hinge, "rotation_degrees:x", 0.0, 0.0)
			Bus.report(&"chest_fake_open", &"", chest.global_position)
		elif opened == 1:
			create_tween().tween_property(hinge, "rotation_degrees:x", -105.0, 0.5)
			Inv.add("oath_ring")
			Narrator.say("d2_chest_real"))


# ------------------------------------------------------------------ 尸体飞进墙里

func _on_killed(c: Combatant) -> void:
	if _boss == null or c.node != _boss or _boss_dead:
		return
	_boss_dead = true
	var from := _boss.global_position
	var land := from + CORPSE_FLIGHT
	var in_wall := land.z < NORTH_WALL_Z + 0.4
	if in_wall:
		# 卡进墙里：落在北墙后面的夹层（从上面看得见，走不进去）
		land.z = maxf(land.z, NORTH_WALL_Z - 1.6)
	Meta.bump("d2_corpse_" + ("wall" if in_wall else "ok"))
	_boss.collision_layer = 0
	_boss.collision_mask = 0
	var mid := (from + land) * 0.5 + Vector3.UP * 3.5
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(land, t)
		_boss.global_position = a.lerp(b, t), 0.0, 1.0, 0.9)
	tw.parallel().tween_property(_boss.model, "rotation_degrees", Vector3(-90, 540, 0), 0.9)
	await tw.finished
	var loot := Interactable.new()
	loot.name = "BossCorpse"
	loot.label_key = "obj_corpse"
	loot.size = Vector3(1.6, 0.5, 1.0)
	loot.color = Color(0, 0, 0, 0)
	add_child(loot)
	loot.global_position = Vector3(land.x, 0, land.z)
	if in_wall:
		Bus.report(&"corpse_in_wall", &"", land)
		Narrator.say("d2_corpse_loot")
		loot.interacted.connect(func(_by): Narrator.say("d2_corpse_loot"))
	else:
		loot.interacted.connect(func(_by):
			if loot.has_meta("looted"):
				return
			loot.set_meta("looted", true)
			Inv.gold += 150
			Inv.add("longsword_plus_1")
			Narrator.say("d2_corpse_loot_ok"))


func _on_combat_ended(party_won: bool) -> void:
	if party_won and _boss_dead and not Game.flag(&"d2_done"):
		Game.set_flag(&"d2_done")
		Narrator.say("d2_done")
