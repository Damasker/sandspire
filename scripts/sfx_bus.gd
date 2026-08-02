extends Node
## Lightweight placeholder SFX (procedural beep). No external audio assets (S15).

var _player: AudioStreamPlayer
var _master: float = 0.8
var _sfx: float = 0.7


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)


func apply_volumes(master: float, sfx: float) -> void:
	_master = clampf(master, 0.0, 1.0)
	_sfx = clampf(sfx, 0.0, 1.0)
	var lin := _master * _sfx
	_player.volume_db = linear_to_db(maxi(lin, 0.0001)) if lin > 0.0 else -80.0


func play_ui(kind: String = "click") -> void:
	if _master * _sfx <= 0.001:
		return
	var freq := 660.0
	var ms := 45
	match kind:
		"ok", "place":
			freq = 520.0
			ms = 55
		"warn":
			freq = 220.0
			ms = 80
		"win":
			freq = 880.0
			ms = 120
		_:
			freq = 660.0
			ms = 40
	_player.stream = _make_beep(freq, ms)
	_player.play()


func _make_beep(freq: float, ms: int) -> AudioStreamWAV:
	var sample_rate := 22050
	var n := int(sample_rate * float(ms) / 1000.0)
	n = maxi(n, 8)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / float(sample_rate)
		var env := 1.0 - float(i) / float(n)
		var sample := int(sin(t * freq * TAU) * 0.28 * env * 32767.0)
		data[i * 2] = sample & 0xff
		data[i * 2 + 1] = (sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream
