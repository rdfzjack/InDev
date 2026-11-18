extends LevelBase
## Dungeon 1（地窖）。三五个房间。几乎全是好的，笑点都在队友身上。
## 每个房间只负责一件事：
##   A 入口：石阶（光照尚未烘焙）。诗人入队过场中掉下去。
##   B 走廊：隐藏陷阱（被动察觉正常工作）。解除陷阱功能没做，只能绕。诗人的名字还是会踩。
##   C 机关房：上锁的门（开锁检定正常）、三根拉杆 + 石碑谜题（正常运行，建立基准）。
##   D 战斗：地精和狼。第一次战斗，玩家在这里发现技能栏有【躺着】。
##   E 宝箱：金币、药水、卷轴。回村庄。
## 布局：从南（z=+）往北（z=-）走。

const VILLAGE := "res://scenes/levels/village.tscn"
const W := Color(0.42, 0.4, 0.38)
const LEVER_ORDER := ["obj_lever_right", "obj_lever_mid", "obj_lever_left"]   # 东 → 正午 → 西

var _lever_seq: Array = []
var _portcullis: StaticBody3D
var _door: StaticBody3D
var _door_inter: Interactable


func _init() -> void:
	music = "field"
	level_id = "dungeon_1"
	sky = Color(0.05, 0.05, 0.07)


func _build() -> void:
	floor_box(Vector3(0, 0, -20), Vector2(40, 70), Color(0.32, 0.3, 0.28))
	# A 入口 (z 10..0)
	room(Vector2(0, 6), Vector2(10, 10), [["s", 0.5, 3.0], ["n", 0.5, 3.0]], 4.0, W)
	spawn("from_village", Vector3(0, 0.1, 9.5))
	exit_to(Vector3(0, 0, 12.5), VILLAGE, "from_dungeon", "exit_to_village")
	narrate_zone(Vector3(0, 0, 8), Vector3(8, 2, 3), "d1_stairs")
	if not Game.in_party(Game.POET):
		var p := npc(&"poet", Vector3(2.5, 0.1, 3), "res://data/dialogue/poet.dlg", "recruit", PartyController.COLORS[&"poet"])
		var z := Area3D.new()
		z.collision_layer = 0
		z.collision_mask = 2
		var cs := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(8, 2, 3)
		cs.shape = s
		z.add_child(cs)
		add_child(z)
		z.position = Vector3(0, 1, 4.5)
		z.body_entered.connect(_on_poet_zone.bind(z))
	# B 走廊 (z 1..-11)，3 米宽，中间一块隐藏压力板
	room(Vector2(0, -5), Vector2(4, 12), [["s", 0.5, 3.0], ["n", 0.5, 3.0]], 4.0, W)
	var trap := Trap.new()
	trap.name = "CorridorTrap"
	trap.hidden_dc = 11
	trap.size = Vector3(2.2, 0.3, 1.5)
	add_child(trap)
	trap.position = Vector3(0.6, 0, -5)
	# C 机关房 (z -11..-23)
	room(Vector2(0, -17), Vector2(14, 12), [["s", 0.5, 3.0], ["n", 0.5, 2.0], ["e", 0.5, 2.0]], 4.0, W)
	var stele := Interactable.new()
	stele.name = "Stele"
	stele.label_key = "obj_stele"
	stele.size = Vector3(1.2, 2.0, 0.4)
	stele.color = Color(0.55, 0.55, 0.6)
	add_child(stele)
	stele.position = Vector3(0, 0, -21)
	stele.interacted.connect(func(_by): Narrator.say("d1_puzzle"))
	var xs := {"obj_lever_left": -4.0, "obj_lever_mid": 0.0, "obj_lever_right": 4.0}
	for k in xs:
		var lv := Interactable.new()
		lv.name = k
		lv.label_key = k
		lv.size = Vector3(0.3, 1.2, 0.3)
		lv.color = Color(0.5, 0.4, 0.25)
		add_child(lv)
		lv.position = Vector3(xs[k], 0, -14)
		lv.interacted.connect(_pull.bind(k, lv))
	# 北边铁栅（谜题开）
	_portcullis = block(Vector3(0, 0, -23), Vector3(2.2, 3.5, 0.3), Color(0.25, 0.25, 0.28))
	# 东边上锁的门（开锁检定）→ 储藏间
	_door = block(Vector3(7, 0, -17), Vector3(0.3, 3, 2.2), Color(0.45, 0.32, 0.2))
	_door_inter = Interactable.new()
	_door_inter.name = "LockedDoor"
	_door_inter.label_key = "obj_door"
	_door_inter.size = Vector3(0.6, 2.4, 2.0)
	_door_inter.color = Color(0.45, 0.32, 0.2, 0.0)
	add_child(_door_inter)
	_door_inter.position = Vector3(6.6, 0, -17)
	_door_inter.interacted.connect(_try_door)
	room(Vector2(11, -17), Vector2(8, 6), [["w", 0.5, 2.0]], 3.0, W)
	var stash := Interactable.new()
	stash.label_key = "obj_chest"
	stash.color = Color(0.5, 0.35, 0.2)
	add_child(stash)
	stash.position = Vector3(13, 0, -17)
	stash.interacted.connect(func(_by):
		if not stash.has_meta("looted"):
			stash.set_meta("looted", true)
			Inv.add("alchemists_fire", 2)
			Inv.gold += 25
			Narrator.show_text(TextDB.ui("loot_stash")))
	# D 战斗 (z -23..-37)
	room(Vector2(0, -30), Vector2(16, 14), [["s", 0.5, 2.0], ["n", 0.5, 2.0]], 4.0, W)
	var enc := encounter(Vector3(0, 0, -30), Vector3(14, 3, 12))
	enemy("goblin", Vector3(-3, 0.1, -33), enc)
	enemy("goblin", Vector3(3, 0.1, -34), enc)
	enemy("goblin", Vector3(0, 0.1, -35), enc)
	enemy("wolf", Vector3(-1, 0.1, -32), enc)
	block(Vector3(-5, 0, -29), Vector3(1.5, 1.2, 1.5), W.darkened(0.2))   # 掩体
	block(Vector3(5, 0, -31), Vector3(1.5, 1.2, 1.5), W.darkened(0.2))
	# E 宝箱 (z -37..-45)
	room(Vector2(0, -41), Vector2(8, 8), [["s", 0.5, 2.0]], 3.5, W)
	var chest := Interactable.new()
	chest.name = "Chest"
	chest.label_key = "obj_chest"
	chest.color = Color(0.6, 0.45, 0.2)
	add_child(chest)
	chest.position = Vector3(0, 0, -43)
	chest.interacted.connect(func(_by):
		if chest.has_meta("looted"):
			return
		chest.set_meta("looted", true)
		Inv.gold += 50
		Inv.add("potion_of_healing")
		Inv.add("scroll_of_bless")
		Narrator.say("d1_chest")
		if not Game.flag(&"d1_done"):
			Game.set_flag(&"d1_done")
			Game.award_xp(100)
			Narrator.say("d1_done"))
	exit_to(Vector3(0, 0, -39), VILLAGE, "from_dungeon", "exit_to_village", Vector3(2, 2, 1.5)).requires_flag = "d1_done"


func _on_poet_zone(b: Node, z: Area3D) -> void:
	var p := get_node_or_null("poet")
	if b is PartyMember and b.char_id == Game.PROTAGONIST and not z.has_meta("done") and p and p is Npc:
		z.set_meta("done", true)
		DialogueBox.open("res://data/dialogue/poet.dlg", "recruit", p)


func _pull(_by: StringName, k: String, lv: Interactable) -> void:
	if _portcullis == null:
		return
	lv.mesh.rotation_degrees.x = -35.0 if lv.mesh.rotation_degrees.x == 0.0 else 0.0
	_lever_seq.append(k)
	if _lever_seq.size() > LEVER_ORDER.size():
		_lever_seq.pop_front()
	if _lever_seq == LEVER_ORDER:
		Narrator.say("d1_puzzle_solved")
		_portcullis.queue_free()
		_portcullis = null
		rebake()
		Meta.bump("d1_puzzle_solved")
		Game.award_xp(25)


## 开锁：有 SL 的话他来（巧手，盗贼工具）；否则主角硬砸（运动 DC 15）
func _try_door(_by: StringName) -> void:
	if _door == null:
		return
	var who := Game.SL if Game.in_party(Game.SL) else Game.selected
	var chk := {"type": "check", "skill": "sleight_of_hand" if who == Game.SL else "athletics",
		"dc_text": "10" if who == Game.SL else "15", "ability": "", "lie": false}
	var res: Dictionary = await DiceRollPanel.check(chk, Game.sheet(who))
	if res.get("success", false):
		_door.queue_free()
		_door = null
		_door_inter.queue_free()
		rebake()
	else:
		Narrator.say("d1_door_locked")
