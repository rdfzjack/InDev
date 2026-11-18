extends Node
## 根场景。结构：
##   Main
##   ├─ WorldView (SubViewportContainer, 低分辨率 + 后处理)
##   │   └─ SubViewport  ← 关卡挂在这里
##   └─ UI (CanvasLayer, 全分辨率——UI 允许是现代的)
##       ├─ Nameplates
##       ├─ BanterLog
##       ├─ NarratorLog
##       ├─ DialogueBox
##       └─ LoadingScreen
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


func _sync_post_res() -> void:
	(world_view.material as ShaderMaterial).set_shader_parameter("low_res", Vector2(viewport.size))


func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)
	var plates := Nameplates.new()
	plates.name = "Nameplates"
	plates.world_view = world_view
	ui.add_child(plates)
	var banter := BanterLog.new()
	banter.name = "BanterLog"
	ui.add_child(banter)
	var narr := NarratorLog.new()
	narr.name = "NarratorLog"
	ui.add_child(narr)
	var dlg := DialogueBox.new()
	dlg.name = "DialogueBox"
	ui.add_child(dlg)
	var loading := LoadingScreen.new()
	loading.name = "LoadingScreen"
	ui.add_child(loading)
	Router.register_host(viewport, loading)
