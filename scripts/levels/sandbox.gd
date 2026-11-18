extends Node3D
## 测试场：几何体 + 名字牌，先把时机跑通。
## 调试键：
##   F1 诗人掉出地图      F2 随机报一个故障     F3 主角躺着
##   F4 主角说一句"我不知道"（测试 banter）    F5 重载关卡（诗人回来）
##   F6 开关老公约谈（约谈中他点不动）        T  直接和老公对话

const NAV_BAKE_LAYER := 1


func _ready() -> void:
	for id in [Game.HUSBAND, Game.POET, Game.SL]:
		Game.join(id)
	var nav := NavigationRegion3D.new()
	nav.name = "Nav"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = NAV_BAKE_LAYER
	nm.agent_radius = 0.5
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav.navigation_mesh = nm
	add_child(nav)
	_build_geometry(nav)
	nav.bake_navigation_mesh(false)

	var spawn := Marker3D.new()
	spawn.name = "Start"
	spawn.add_to_group("spawns")
	add_child(spawn)
	spawn.position = Vector3(0, 0.1, 6)

	var pc := PartyController.new()
	pc.name = "Party"
	add_child(pc)

	var rig := CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.global_position = spawn.position
	await get_tree().process_frame
	await get_tree().process_frame
	rig.target = pc.leader

	var trap := Trap.new()
	trap.name = "Trap"
	add_child(trap)
	trap.position = Vector3(-4, 0, 0)

	var jam := DoorJam.new()
	jam.name = "TavernDoorJam"
	add_child(jam)
	jam.position = Vector3(6, 0, -8)


func _build_geometry(parent: Node3D) -> void:
	var floor := Placeholders.static_box(Vector3(40, 1, 40), Color(0.55, 0.62, 0.45), 0.25)
	floor.position.y = -0.5
	parent.add_child(floor)
	# 一面带门洞的墙（酒馆门）
	for x in [-4.0, 16.0]:
		var w := Placeholders.static_box(Vector3(18.0, 3, 0.5), Color(0.7, 0.55, 0.4))
		w.position = Vector3(x - 3.0 if x < 0 else x - 1.0, 1.5, -10)
		parent.add_child(w)
	# 几根柱子，看顶点抖动和 affine
	for i in 5:
		var p := Placeholders.static_box(Vector3(1, 4, 1), Color(0.8, 0.8, 0.85))
		p.position = Vector3(-12 + i * 3.0, 2, -4)
		parent.add_child(p)
	# 白模区：纯白、没贴图色
	var white := Placeholders.static_box(Vector3(10, 0.2, 10), Color(1, 1, 1))
	white.position = Vector3(-14, 0.1, 12)
	parent.add_child(white)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var pc: PartyController = get_node_or_null("Party")
	match e.keycode:
		KEY_F1:
			var poet: Poet = pc.members.get(Game.POET) if pc else null
			if poet:
				poet.fall_out_of_map()
		KEY_F2:
			var ids := ["clip_wall", "interact_failed", "text_key_missing", "music_index_wrong", "lighting_unbaked"]
			var who: StringName = [Game.PROTAGONIST, Game.HUSBAND, Game.POET, Game.SL].pick_random()
			Bus.report(StringName(ids.pick_random()), who)
		KEY_F3:
			Meta.bump("lay_down")
			Bus.report(&"player_lay_down", Game.PROTAGONIST)
		KEY_F4:
			Bus.report(&"weapon_missing", Game.PROTAGONIST)
		KEY_F5:
			Router.goto(Router.current_path)
		KEY_F6:
			Game.set_flag(&"husband_summons_pending", not Game.flag(&"husband_summons_pending"))
			print("husband_summons_pending: ", Game.flag(&"husband_summons_pending"))
		KEY_T:
			DialogueBox.open("res://data/dialogue/husband.dlg", "talk")
