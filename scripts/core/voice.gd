extends Node
## 语音（autoload: Voice）。
##
## 有正式录音就放 assets/audio/voice/<台词 id>.ogg，speak_line() 会优先播它。
## 没有录音时用占位"嘟嘟声"：每个字一个短音，音高按角色（data/text/characters.tsv 的 voice 列）：
##   low / mid / high / girl / none。大汉配的是 girl。
## 无头模式（测试）不出声。

const VOICES := {
	"low": [95.0, 0.18],     # 基频 Hz, 随机起伏
	"mid": [150.0, 0.2],
	"high": [230.0, 0.22],
	"girl": [420.0, 0.28],
}
const RATE := 22050.0
const SYLLABLE_SEC := 0.085

var enabled := true
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	_player.volume_db = -14.0
	add_child(_player)


func voice_of(who: StringName) -> String:
	var r := TextDB.row("characters", String(who))
	var v: String = r.get("voice", "")
	return v if v != "" else "mid"


## 对话 / 过场里说一句。line_id 有录音就播录音。
func speak(who: StringName, text: String, line_id := "") -> void:
	if not enabled or DisplayServer.get_name() == "headless" or who == &"narrator":
		return
	Meta.bump("voice_lines_" + String(who))
	if line_id != "":
		var p := "res://assets/audio/voice/%s.ogg" % line_id
		if ResourceLoader.exists(p):
			_player.stream = load(p)
			_player.play()
			return
	var v := voice_of(who)
	if not VOICES.has(v):
		return
	_player.stream = _babble(text, VOICES[v][0], VOICES[v][1])
	_player.play()


func stop() -> void:
	_player.stop()


## 每个字一个带包络的短音，最多 24 个字
func _babble(text: String, base: float, wobble: float) -> AudioStreamWAV:
	_rng.seed = hash(text)
	var n := mini(text.length(), 24)
	var per := int(RATE * SYLLABLE_SEC)
	var data := PackedByteArray()
	data.resize(n * per * 2)
	var phase := 0.0
	for i in n:
		var ch := text[i]
		var silent := ch in "，。、！？…… ,.!?—：；"
		var f := base * (1.0 + _rng.randf_range(-wobble, wobble))
		for k in per:
			var env := sin(PI * float(k) / per)
			phase += TAU * f / RATE
			var s := 0.0 if silent else (sin(phase) * 0.6 + sin(phase * 2.0) * 0.25) * env
			data.encode_s16((i * per + k) * 2, int(clampf(s, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = int(RATE)
	w.stereo = false
	w.data = data
	return w
