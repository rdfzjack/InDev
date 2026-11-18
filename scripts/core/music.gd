extends Node
## 背景音乐（autoload: Music）。两个播放器交叉淡入淡出。
##
## 层级：关卡音乐是底；战斗、商店、过场可以盖在上面（push），结束后 pop 回去。
## 曲目文件：assets/audio/music/<id>.ogg（占位曲由 tools/gen_placeholder_music.py 生成，美术到了直接覆盖）。
##
## 设计相关：
##   魔王二阶段：战斗音乐被换成店铺 BGM，一直放到结算（Combat.boss_phase）。
##   村庄的 BGM 是 boss 战音乐：在村庄关卡里设置 level_music = "boss"。

const DIR := "res://assets/audio/music/%s.ogg"
const FADE := 1.2

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _current: StringName = &""
var _base: StringName = &""
var _stack: Array = []   # [[tag, id], ...]，最后一个在放
var volume_db := -6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.volume_db = -80
		add_child(p)
	Combat.combat_started.connect(_on_combat_start)
	Combat.combat_ended.connect(func(_w): pop(&"combat"))
	Combat.boss_phase.connect(_on_boss_phase)


func current() -> StringName:
	return _current


## 关卡底音乐
func set_base(id: StringName) -> void:
	_base = id
	if _stack.is_empty():
		play(id)


func push(id: StringName, tag: StringName = &"") -> void:
	_stack.append([tag if tag != &"" else id, id])
	play(id)


func pop(tag: StringName) -> void:
	for i in range(_stack.size() - 1, -1, -1):
		if _stack[i][0] == tag:
			_stack.remove_at(i)
			break
	play(_stack[-1][1] if not _stack.is_empty() else _base)


## 把某一层换成别的曲子（不弹出）
func replace(tag: StringName, id: StringName) -> void:
	for e in _stack:
		if e[0] == tag:
			e[1] = id
	if not _stack.is_empty() and _stack[-1][0] == tag:
		play(id)


func play(id: StringName) -> void:
	if id == _current or id == &"":
		return
	# "none"：安静（白模区没有底音乐，只有龙那首歌，从龙身上放）
	if id == &"none":
		var tw0 := create_tween().set_parallel(true)
		tw0.tween_interval(FADE)
		for p in [_a, _b]:
			if p.playing:
				tw0.tween_property(p, "volume_db", -80.0, FADE)
		tw0.chain().tween_callback(func():
			_a.stop()
			_b.stop())
		_current = id
		return
	var path := DIR % String(id)
	if not ResourceLoader.exists(path):
		push_warning("Music: missing %s" % path)
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	var from := _a if _a.playing else null
	var to := _b if from == _a else _a
	to.stream = stream
	to.volume_db = -40
	to.play()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(to, "volume_db", volume_db, FADE)
	if from:
		tw.tween_property(from, "volume_db", -80.0, FADE)
		tw.chain().tween_callback(from.stop)
	_current = id
	Meta.bump("music_" + String(id))


func _on_combat_start() -> void:
	var boss := Combat.combatants.any(func(c): return c.sheet.is_monster and Rules.monsters.get(c.sheet.monster_kind, {}).get("boss", false))
	var dragon := Combat.combatants.any(func(c): return c.sheet.monster_kind == "young_red_dragon")
	push(&"dragon" if dragon else (&"boss" if boss else &"combat"), &"combat")


## 魔王二阶段：音乐切成店铺 BGM，不中途修好
func _on_boss_phase(c: Combatant, phase: int) -> void:
	if phase == 2 and c.sheet.monster_kind == "demon_lord":
		replace(&"combat", &"shop")
		Bus.report(&"music_index_wrong")
