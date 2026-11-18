extends Node
## 故障广播。所有"出了问题"的地方都调 Bus.report(glitch_id, instigator, location)。
## glitch_id 对应 data/glitches.tsv 的一行，类型、严重度、旁白 key 都从表里读。
##
## 顺序：旁白先报告（Narrator 订阅 reported），队友后评论（Banter 订阅 narrated_done）。

signal reported(ev: BugEvent)

## 引擎日志式的调试输出，开发期间看触发是否正确
var debug_print := true
## 结局开始以后游戏就不再坏了：什么都不广播
var muted := false


func report(glitch_id: StringName, instigator: StringName = &"", location := Vector3.ZERO) -> BugEvent:
	var ev := BugEvent.new()
	if muted:
		return ev
	ev.glitch_id = glitch_id
	ev.instigator = instigator
	ev.location = location
	var r := TextDB.row("glitches", String(glitch_id))
	if r.is_empty():
		push_warning("Bus: glitch not in table: %s" % glitch_id)
	ev.type = StringName(r.get("type", "misc"))
	ev.severity = StringName(r.get("severity", "funny"))
	ev.narrator_key = r.get("narrator", "")
	ev.silence = float(r.get("silence", "-1")) if r.get("silence", "") != "" else -1.0
	if debug_print:
		print("[Bug] %s by=%s type=%s" % [glitch_id, instigator, ev.type])
	Meta.bump("bug_" + String(glitch_id))
	reported.emit(ev)
	return ev
