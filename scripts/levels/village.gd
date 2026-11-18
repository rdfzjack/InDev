extends LevelBase
## 村庄（白模）。枢纽，笑点密度最高。一条主街，酒馆 / 商店 / 村长家 / 神殿，一个广场。走一圈两分钟。
##
## 主街东西向（x 轴）。北边尽头是魔王门（地图上一直标着），西边是白模区小路和营地，东边是地窖。
## 村庄 BGM 是 boss 战音乐（音乐轨道索引错误）。
##
## TODO（下一轮）：被害村民（跳过是坏的）、铁匠（碰撞体太大）、女王/庄严 NPC 的错别字字幕、
##   大汉配少女音、白模区和龙。

const DUNGEON := "res://scenes/levels/dungeon_1.tscn"
const CAMP := "res://scenes/levels/camp.tscn"

const STONE := Color(0.62, 0.6, 0.55)
const WOOD := Color(0.62, 0.45, 0.3)
const PLASTER := Color(0.85, 0.8, 0.68)


func _init() -> void:
	music = "boss"
	level_id = "village"


func _build() -> void:
	# 地面：主街 + 广场
	floor_box(Vector3(0, 0, 0), Vector2(80, 60), Color(0.5, 0.58, 0.4))
	# 路面只是画面层（不重叠碰撞、不做台阶），层间留几厘米，避免 z-fighting
	ground_decal(Vector3(0, 0, 0), Vector2(70, 8), STONE, 0.04)                    # 主街
	ground_decal(Vector3(0, 0, -2), Vector2(16, 16), STONE.lightened(0.1), 0.08)   # 广场
	ground_decal(Vector3(0, 0, -18), Vector2(6, 20), STONE, 0.04)                  # 去魔王门的路
	block(Vector3(0, 0, -2), Vector3(2.5, 1.2, 2.5), STONE.darkened(0.2))   # 广场中间的井

	# 商店（西北）
	room(Vector2(-16, -12), Vector2(10, 8), [["s", 0.5, 2.0]], 3.5, PLASTER)
	# 酒馆（东北），门洞只有 1.4 米宽，四个人进门要打转
	room(Vector2(16, -12), Vector2(12, 9), [["s", 0.5, 1.4]], 3.5, WOOD)
	# 村长家（西南）
	room(Vector2(-16, 12), Vector2(10, 8), [["n", 0.5, 2.0]], 3.5, PLASTER)
	# 神殿（东南）
	room(Vector2(16, 12), Vector2(10, 10), [["n", 0.5, 3.0]], 5.0, Color(0.9, 0.88, 0.82))
	block(Vector3(16, 0, 14.5), Vector3(3, 1.0, 1.2), Color(0.95, 0.95, 0.9))   # 祭坛

	# 魔王门（北）：一直锁着，门后有音乐（店铺 BGM）
	wall(Vector2(-12, -28), Vector2(-2, -28), 6, Color(0.3, 0.28, 0.3))
	wall(Vector2(2, -28), Vector2(12, -28), 6, Color(0.3, 0.28, 0.3))
	var gate := Interactable.new()
	gate.name = "BossGate"
	gate.label_key = "obj_boss_gate"
	gate.size = Vector3(4, 5, 0.6)
	gate.color = Color(0.2, 0.15, 0.15)
	add_child(gate)
	gate.position = Vector3(0, 0, -28)
	gate.interacted.connect(func(_by): Narrator.say("boss_gate"))
	gate.add_to_group("map_marker")
	gate.set_meta("blink", true)
	gate.set_meta("color", Color(1, 0.3, 0.25))
	var behind := AudioStreamPlayer3D.new()
	behind.stream = load("res://assets/audio/music/shop.ogg")
	(behind.stream as AudioStreamOggVorbis).loop = true
	behind.unit_size = 4.0
	behind.max_distance = 22.0
	behind.autoplay = true
	add_child(behind)
	behind.position = Vector3(0, 1.5, -30)

	# 卡在墙里的鸡（商店东墙）
	var chicken := Interactable.new()
	chicken.name = "Chicken"
	chicken.label_key = "obj_chicken"
	chicken.size = Vector3(0.3, 0.35, 0.3)
	chicken.color = Color(0.95, 0.92, 0.85)
	add_child(chicken)
	chicken.position = Vector3(-10.9, 1.2, -10)
	chicken.interacted.connect(func(_by): Narrator.say("chicken"))

	# 出口
	exit_to(Vector3(36, 0, 0), DUNGEON, "from_village", "exit_to_dungeon1")
	exit_to(Vector3(-36, 0, 6), CAMP, "from_village", "exit_to_camp")
	exit_to(Vector3(-36, 0, -6), "res://scenes/levels/sandbox.tscn", "Start", "exit_to_whitebox")

	# 出生点
	spawn("start", Vector3(0, 0.1, 8))
	spawn("from_dungeon", Vector3(32, 0.1, 0))
	spawn("from_camp", Vector3(-32, 0.1, 6))

	# NPC
	npc(&"shopkeeper", Vector3(-16, 0.1, -13), "res://data/dialogue/shopkeeper.dlg", "start", Color(0.75, 0.6, 0.35))
	npc(&"NPC_Villager_04", Vector3(17, 0.1, -13), "res://data/dialogue/villager04.dlg", "start", Color(0.55, 0.55, 0.6))
	npc(&"chief", Vector3(-16, 0.1, 13), "res://data/dialogue/chief.dlg", "start", Color(0.5, 0.45, 0.6))
	if not Game.in_party(Game.SL):
		npc(&"sl", Vector3(3, 0.1, -4), "res://data/dialogue/sl.dlg", "recruit", PartyController.COLORS[&"sl"])
	if not Game.in_party(Game.HUSBAND):
		npc(&"husband", Vector3(-30, 0.1, 0), "res://data/dialogue/husband.dlg", "recruit", PartyController.COLORS[&"husband"])

	# 酒馆门口打转
	var jam := DoorJam.new()
	jam.size = Vector3(5, 2, 4)
	add_child(jam)
	jam.position = Vector3(16, 0, -7.5)

	narrate_zone(Vector3(0, 0, 4), Vector3(16, 2, 4), "village_enter", "music_index_wrong")


func _after_spawn() -> void:
	if not Game.flag(&"intro_done"):
		Game.set_flag(&"intro_done")
