class_name Cutscene
extends RefCounted
## 过场（level sequence）。关卡脚本里拼步骤，交给 CutscenePlayer.play() 播放：
##
##   var cs := Cutscene.new(&"murder")
##   cs.cam(Vector3(...), Vector3(...))              # 切镜头：机位，看向
##   cs.cam_move(Vector3(...), Vector3(...), 3.0)    # 推 / 摇镜头（不等，下一步马上开始）
##   cs.line("murder_01")                            # 字幕（data/text/cutscene.tsv，说话人在表里），按长度自动停留
##   cs.wait(1.5)
##   cs.run(func(): ...)                             # 摆演员、播动画（要能瞬间完成：跳过时照样执行）
##   cs.finally(func(): ...)                         # 结束或跳过后都会执行（把演员复位）
##   await CutscenePlayer.play(cs)
##
## 跳过：按住空格。skip_breaks_at < 1 = 跳过是坏的，进度圈转到这里就停住。

var id: StringName
var steps: Array = []
var skip_breaks_at := 1.0
var on_end: Array[Callable] = []


func _init(id_: StringName) -> void:
	id = id_


func cam(pos: Vector3, look: Vector3) -> Cutscene:
	steps.append({"t": "cam", "pos": pos, "look": look})
	return self


func cam_move(pos: Vector3, look: Vector3, sec: float) -> Cutscene:
	steps.append({"t": "cam_move", "pos": pos, "look": look, "sec": sec})
	return self


func line(key: String) -> Cutscene:
	steps.append({"t": "line", "key": key})
	return self


func wait(sec: float) -> Cutscene:
	steps.append({"t": "wait", "sec": sec})
	return self


func run(f: Callable) -> Cutscene:
	steps.append({"t": "run", "f": f})
	return self


func finally(f: Callable) -> Cutscene:
	on_end.append(f)
	return self
