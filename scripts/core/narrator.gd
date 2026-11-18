extends Node
## 旁白。庄严文学腔，内容是引擎日志。
## 它只报告看得懂的；表里没有旁白 key 的故障它就不说。
## 角色听不见旁白——旁白不调用任何角色逻辑，只发信号给 UI。

signal line_shown(text: String)
## 旁白处理完一个故障（说了或没说），队友可以开口了
signal event_done(ev: BugEvent)

## 每个汉字的阅读时间，用来决定队友多久之后接话
const SEC_PER_CHAR := 0.06
const MIN_GAP := 0.6


func _ready() -> void:
	Bus.reported.connect(_on_bug)


func _on_bug(ev: BugEvent) -> void:
	var text := ""
	if ev.narrator_key != "":
		text = TextDB.line("narrator", ev.narrator_key)
	if text != "":
		show_text(text)
		await get_tree().create_timer(MIN_GAP + text.length() * SEC_PER_CHAR).timeout
	event_done.emit(ev)


## 直接按 key 说一句（剧情用）
func say(key: String) -> void:
	var t := TextDB.line("narrator", key)
	if t == "":
		push_warning("Narrator: missing key %s" % key)
		return
	show_text(t)


func show_text(text: String) -> void:
	line_shown.emit(text)
