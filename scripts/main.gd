extends Node
## 根场景。结构：
##   Main
##   ├─ WorldView (SubViewportContainer, 低分辨率 + 后处理)
##   │   └─ SubViewport  ← 关卡挂在这里
##   └─ UI (CanvasLayer, 全分辨率——UI 允许是现代的)
##       └─ HUD (Control, UITheme)
##           ├─ Nameplates / OverheadText   名牌、头顶对话
##           ├─ CombatHUD                   先攻条、资源、命中率、飘字
##           ├─ NarratorLog                 旁白（屏幕上方）
##           ├─ PartyPortraits              左侧队伍头像
##           ├─ Minimap                     右上小地图
##           ├─ Hotbar                      底部技能栏
##           ├─ DialogueBox                 对话
##           ├─ MessageLog                  右下日志
##           ├─ InventoryScreen             背包（I 键）
##           ├─ TradeScreen                 交易
##           ├─ LevelUpScreen               升级界面（L 键 / 头像角标）
##           └─ LoadingScreen
##
## 节点在代码里搭，tscn 只挂这个脚本，避免手改场景文件。

## 内部渲染分辨率 = 窗口 / SHRINK。1024x768 / 2 = 512x384
const SHRINK := 2
const POST_SHADER := preload("res://shaders/ps2_post.gdshader")

@export_file("*.tscn") var first_level := "res://scenes/levels/sandbox.tscn"

var world_view: SubViewportContainer
var viewport: SubViewport
var ui: CanvasLayer


func _ready() -> void:
	_build_world_view()
	_build_ui()
	Router.goto(first_level)


func _build_world_view() -> void:
	world_view = SubViewportContainer.new()
	world_view.name = "WorldView"
	world_view.stretch = true
	world_view.stretch_shrink = SHRINK
	world_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = POST_SHADER
	world_view.material = mat
	add_child(world_view)
	viewport = SubViewport.new()
	viewport.name = "SubViewport"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.audio_listener_enable_3d = true
	world_view.add_child(viewport)
	_sync_post_res.call_deferred()
	world_view.resized.connect(_sync_post_res)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_L:
				if not Combat.active:
					LevelUpScreen.open_for(Game.selected)
			KEY_I:
				InventoryScreen.toggle()


func _sync_post_res() -> void:
	(world_view.material as ShaderMaterial).set_shader_parameter("low_res", Vector2(viewport.size))


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var root := Control.new()
	root.name = "HUD"
	root.theme = UITheme.get_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var plates := Nameplates.new()
	plates.name = "Nameplates"
	plates.world_view = world_view
	root.add_child(plates)
	var overhead := OverheadText.new()
	overhead.name = "OverheadText"
	overhead.nameplates = plates
	root.add_child(overhead)
	var combat_hud := CombatHUD.new()
	combat_hud.name = "CombatHUD"
	combat_hud.nameplates = plates
	root.add_child(combat_hud)
	var narr := NarratorLog.new()
	narr.name = "NarratorLog"
	root.add_child(narr)
	# 对话框要先于日志创建（日志订阅它的信号）
	var dlg := DialogueBox.new()
	dlg.name = "DialogueBox"
	var portraits := PartyPortraits.new()
	portraits.name = "PartyPortraits"
	root.add_child(portraits)
	var minimap := Minimap.new()
	minimap.name = "Minimap"
	root.add_child(minimap)
	var hotbar := Hotbar.new()
	hotbar.name = "Hotbar"
	root.add_child(hotbar)
	root.add_child(dlg)
	var log := MessageLog.new()
	log.name = "MessageLog"
	root.add_child(log)
	var inv := InventoryScreen.new()
	inv.name = "InventoryScreen"
	root.add_child(inv)
	var trade := TradeScreen.new()
	trade.name = "TradeScreen"
	root.add_child(trade)
	var lvl := LevelUpScreen.new()
	lvl.name = "LevelUpScreen"
	root.add_child(lvl)
	var loading := LoadingScreen.new()
	loading.name = "LoadingScreen"
	root.add_child(loading)
	# 对话时隐藏技能栏（BG3 也是这样）
	dlg.visibility_changed.connect(func(): hotbar.visible = not dlg.visible)
	Router.register_host(viewport, loading)
