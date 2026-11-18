extends Node
## 结算里那份"调试信息"。独立于存档，存在 user://meta.cfg。
## 回档不会让数字倒回去。玩家能找到并删掉，不防。
##
## 也负责异常退出检测：在会卡死的操作之前 arm_crash()，正常退出时清掉。
## 下次启动读到标记 → pending_crash 为真，由对话系统触发"不是说了别点吗"。

const PATH := "user://meta.cfg"

var counters: Dictionary = {}
var pending_crash: StringName = &""   # 上次是被什么卡死的
var playtime_sec: float = 0.0

var _cfg := ConfigFile.new()
var _dirty := false
var _save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _cfg.load(PATH) == OK:
		for k in _cfg.get_section_keys("counters") if _cfg.has_section("counters") else []:
			counters[k] = _cfg.get_value("counters", k, 0)
		playtime_sec = _cfg.get_value("time", "playtime", 0.0)
		pending_crash = StringName(_cfg.get_value("crash", "armed", ""))
		if pending_crash != &"":
			bump("crash_" + String(pending_crash))
		_cfg.set_value("crash", "armed", "")
		_dirty = true
	get_tree().auto_accept_quit = false


func _process(delta: float) -> void:
	playtime_sec += delta
	_save_timer += delta
	if _save_timer > 5.0:
		_save_timer = 0.0
		_dirty = true
	if _dirty:
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()
		get_tree().quit()


func bump(key: String, by := 1) -> void:
	counters[key] = int(counters.get(key, 0)) + by
	_dirty = true


func get_count(key: String) -> int:
	return int(counters.get(key, 0))


## 在真正卡死前调用。之后主线程不会再有机会写盘，所以这里立即落盘。
func arm_crash(reason: StringName) -> void:
	_cfg.set_value("crash", "armed", String(reason))
	save()


func consume_crash() -> StringName:
	var r := pending_crash
	pending_crash = &""
	return r


func save() -> void:
	for k in counters:
		_cfg.set_value("counters", k, counters[k])
	_cfg.set_value("time", "playtime", playtime_sec)
	_cfg.save(PATH)
	_dirty = false
