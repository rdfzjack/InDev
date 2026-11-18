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
##           ├─ DiceRollPanel               检定骰子（对话内外通用）
##           ├─ MessageLog                  右下日志
##           ├─ InventoryScreen             背包（I 键）
##           ├─ TradeScreen                 交易
##           ├─ LevelUpScreen               升级界面（L 键 / 头像角标）
##           ├─ NoticeToasts                日志更新横条、好感度提示（左上）
##           ├─ JournalScreen               任务日志（J）
##           ├─ CutscenePlayer              过场（黑边、字幕、按住空格跳过）
##           ├─ ReactionPrompt              反应弹窗（护盾术、借机攻击……用不用）
##           ├─ EndingScreen                结局幻灯片、统计、制作人员
##           ├─ TitleScreen                 标题画面 + 角色创建（只在正式启动时出现）
##           ├─ PauseMenu                   Esc 菜单，F5 快存，F9 快读
##           └─ LoadingScreen
##
## 节点在代码里搭，tscn 只挂这个脚本，避免手改场景文件。

## 内部渲染分辨率 = 窗口 / SHRINK。1024x768 / 2 = 512x384
const SHRINK := 2
const POST_SHADER := preload("res://shaders/ps2_post.gdshader")

@export_file("*.tscn") var first_level := "res://scenes/levels/village.tscn"

var world_view: SubViewportContainer
var viewport: SubViewport
var ui: CanvasLayer


## 正式启动（main 是场景根）先进标题画面；测试把 main 挂在自己下面，直接进关卡
var show_title := false
var title: TitleScreen


func _ready() -> void:
	show_title = get_parent() == get_tree().root
	_build_world_view()
	_build_ui()
	if show_title:
		title.open()
	else:
		title.visible = false
		Router.goto(first_level)


func _start_new_game() -> void:
	Game.new_game()
	Router.goto(first_level)


func _back_to_title() -> void:
	title.open()


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
			KEY_J:
				if not DialogueBox.is_open() and not (title and title.visible):
					JournalScreen.toggle()


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
	var dice := DiceRollPanel.new()
	dice.name = "DiceRollPanel"
	root.add_child(dice)
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
	var toasts := NoticeToasts.new()
	toasts.name = "NoticeToasts"
	root.add_child(toasts)
	var journal := JournalScreen.new()
	journal.name = "JournalScreen"
	root.add_child(journal)
	var cut := CutscenePlayer.new()
	cut.name = "CutscenePlayer"
	root.add_child(cut)
	var react := ReactionPrompt.new()
	react.name = "ReactionPrompt"
	root.add_child(react)
	var pause := PauseMenu.new()
	pause.name = "PauseMenu"
	root.add_child(pause)
	var ending := EndingScreen.new()
	ending.name = "EndingScreen"
	root.add_child(ending)
	ending.finished.connect(_back_to_title)
	title = TitleScreen.new()
	title.name = "TitleScreen"
	root.add_child(title)
	title.new_game_confirmed.connect(_start_new_game)
	pause.move_to_front()
	var loading := LoadingScreen.new()
	loading.name = "LoadingScreen"
	root.add_child(loading)
	# 对话时隐藏 HUD（BG3 电影模式）
	var hide_in_dialogue: Array = [hotbar, portraits, minimap, log, plates, overhead, narr, combat_hud]
	var hide_hud := func(on: bool):
		for n in hide_in_dialogue:
			n.visible = not on
	dlg.cinematic_changed.connect(hide_hud)
	cut.playing_changed.connect(hide_hud)
	Router.register_host(viewport, loading)
