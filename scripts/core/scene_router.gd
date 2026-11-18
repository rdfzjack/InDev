extends Node
## 传统关卡切换（不是无缝）。加载画面是笑点，诗人也靠这个回来。
##
## 关卡场景放进 Main 的低分辨率 SubViewport 里。
## 加载画面至少显示 MIN_LOADING_SEC，再快也要让人看到那条提示。

signal level_loaded(level: Node)

const MIN_LOADING_SEC := 1.6

var current_level: Node
var current_path := ""
var _host: Node            # SubViewport
var _loading: CanvasItem   # 加载画面
var _busy := false


func register_host(host: Node, loading_screen: CanvasItem) -> void:
	_host = host
	_loading = loading_screen
	_loading.visible = false


func is_busy() -> bool:
	return _busy


## spawn：关卡里 Marker3D 的名字（放在 "spawns" 组里），玩家落点
func goto(path: String, spawn := "") -> void:
	if _busy:
		return
	_busy = true
	_loading.visible = true
	if _loading.has_method("on_show"):
		_loading.on_show()
	Meta.bump("level_loads")
	var t0 := Time.get_ticks_msec()
	if current_level:
		current_level.queue_free()
		current_level = null
	ResourceLoader.load_threaded_request(path)
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	while Time.get_ticks_msec() - t0 < MIN_LOADING_SEC * 1000.0:
		await get_tree().process_frame
	if packed == null:
		push_error("Router: failed to load %s" % path)
		_busy = false
		return
	current_level = packed.instantiate()
	current_path = path
	current_level.set_meta("spawn", spawn)
	_host.add_child(current_level)
	Game.on_level_loaded()
	if current_level.has_meta("music"):
		Music.set_base(StringName(current_level.get_meta("music")))
	level_loaded.emit(current_level)
	_loading.visible = false
	_busy = false
