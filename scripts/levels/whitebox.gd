extends LevelBase
## 白模区。从村庄西边那条小路进来，没有任何引导。
## 一片白模，没有杂兵，没有宝箱，没有 NPC。只有一条龙。
## 没有底音乐。龙的歌从龙身上放，离远了听不见。

const VILLAGE := "res://scenes/levels/village.tscn"
const WHITE := Color(0.92, 0.92, 0.9)
const GREY := Color(0.72, 0.72, 0.72)

var _dragon: Dragon


func _init() -> void:
	music = "none"
	level_id = "whitebox"
	sky = Color(0.86, 0.87, 0.88)


func _build() -> void:
	floor_box(Vector3(-10, 0, 0), Vector2(100, 70), WHITE)
	spawn("from_village", Vector3(34, 0.1, 0))
	exit_to(Vector3(38.5, 0, 0), VILLAGE, "from_whitebox", "exit_to_village")
	narrate_zone(Vector3(30, 0, 0), Vector3(4, 2, 10), "whitebox_enter")
	# 没做完的东西：方块、半堵墙、通往半空的台阶、一根柱子。全是灰的。
	block(Vector3(18, 0, -9), Vector3(4, 4, 4), GREY)
	block(Vector3(12, 0, 10), Vector3(2, 6, 2), GREY)
	wall(Vector2(4, -14), Vector2(14, -14), 3.0, GREY)
	for i in 6:
		block(Vector3(-2 + i * 1.0, 0, 12), Vector3(1.0, 0.4 * (i + 1), 2.0), GREY)
	block(Vector3(-8, 0, -16), Vector3(6, 0.5, 6), GREY)
	block(Vector3(24, 0, 14), Vector3(3, 1.5, 3), GREY)
	narrate_zone(Vector3(-14, 0, 0), Vector3(4, 2, 30), "dragon_seen")
	# 龙：站在最空的地方，面朝来路
	_dragon = Dragon.new()
	add_child(_dragon)
	_dragon.position = Vector3(-30, 0.1, 0)
	_dragon.rotation_degrees.y = -90.0


func _after_spawn() -> void:
	DialogueBox.instance.command.connect(_on_cmd)


func _exit_tree() -> void:
	if DialogueBox.instance and DialogueBox.instance.command.is_connected(_on_cmd):
		DialogueBox.instance.command.disconnect(_on_cmd)


func _on_cmd(args: Array) -> void:
	if args.is_empty() or args[0] != "fight" or Combat.active:
		return
	Meta.bump("dragon_fights")
	var enc := Encounter.new()
	enc.radius = 60.0
	enc.size = Vector3(0.1, 0.1, 0.1)
	add_child(enc)
	enc.global_position = _dragon.global_position
	await get_tree().process_frame
	enc.start()
