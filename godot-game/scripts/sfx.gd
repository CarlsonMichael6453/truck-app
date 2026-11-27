class_name Sfx
extends Node

## Small synthesized sounds, built once in code so the export needs no audio files.
## Everything respects Game.sound. On the web the browser keeps audio locked
## until the first tap, and Godot resumes it on that tap.

const RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _streams := {}
var _engine: AudioStreamPlayer
var _engine_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["coin"] = _tone([1318.5, 1760.0], 0.11, 0.32, "square")
	_streams["hit"] = _thud()
	_streams["crash"] = _thud(0.5)
	_streams["boost"] = _sweep(320.0, 1250.0, 0.32, 0.3)
	_streams["mud"] = _sweep(260.0, 90.0, 0.28, 0.32)
	_streams["lane"] = _noise(0.09, 0.12, 2400.0)
	_streams["finish"] = _tone([523.3, 659.3, 784.0, 1046.5], 0.5, 0.3, "triangle")
	_streams["tick"] = _tone([660.0], 0.12, 0.28, "triangle")
	_streams["go"] = _tone([990.0], 0.28, 0.3, "triangle")
	_streams["tap"] = _tone([720.0], 0.04, 0.16, "triangle")
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)
	_engine = AudioStreamPlayer.new()
	_engine.stream = _engine_loop()
	_engine.volume_db = -12.0
	add_child(_engine)
	Game.changed.connect(_on_game)


func play(name: String, pitch: float = 1.0) -> void:
	if not Game.sound or not _streams.has(name):
		return
	var player := _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = _streams[name]
	player.pitch_scale = pitch
	player.play()


## Engine rumble for a run. speed01 is 0 at idle and 1 at full boost.
func engine(on: bool, speed01: float = 0.5) -> void:
	_engine_on = on
	if not on or not Game.sound:
		if _engine.playing:
			_engine.stop()
		return
	if not _engine.playing:
		_engine.play()
	_engine.pitch_scale = lerpf(0.75, 1.65, clampf(speed01, 0.0, 1.0))
	_engine.volume_db = lerpf(-15.0, -9.0, clampf(speed01, 0.0, 1.0))


func _on_game() -> void:
	if not Game.sound and _engine.playing:
		_engine.stop()


func _tone(notes: Array, length: float, gain: float, wave: String) -> AudioStreamWAV:
	var frames := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var per := maxi(1, frames / notes.size())
	var phase := 0.0
	for i in frames:
		var freq := float(notes[mini(i / per, notes.size() - 1)])
		phase = fmod(phase + freq / RATE, 1.0)
		var v := 0.0
		if wave == "square":
			v = 0.6 if phase < 0.5 else -0.6
		else:
			v = 4.0 * absf(phase - 0.5) - 1.0
		var local := float(i % per) / float(per)
		var env := minf(1.0, local * 40.0) * pow(1.0 - local, 1.6)
		samples[i] = v * env * gain
	return _wav(samples, false)


func _thud(length: float = 0.24) -> AudioStreamWAV:
	var frames := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in frames:
		var t := float(i) / RATE
		var freq := lerpf(140.0, 42.0, minf(1.0, t / length))
		phase = fmod(phase + freq / RATE, 1.0)
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.18)
		var env := pow(1.0 - float(i) / frames, 2.2)
		samples[i] = (sin(phase * TAU) * 0.75 + low * 0.55) * env * 0.55
	return _wav(samples, false)


func _sweep(from_hz: float, to_hz: float, length: float, gain: float) -> AudioStreamWAV:
	var frames := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var phase := 0.0
	for i in frames:
		var k := float(i) / frames
		var freq := lerpf(from_hz, to_hz, k)
		phase = fmod(phase + freq / RATE, 1.0)
		var v := 2.0 * phase - 1.0
		var env := minf(1.0, k * 30.0) * pow(1.0 - k, 1.2)
		samples[i] = v * env * gain
	return _wav(samples, false)


func _noise(length: float, gain: float, cutoff: float) -> AudioStreamWAV:
	var frames := int(length * RATE)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var a := clampf(cutoff / RATE * TAU, 0.01, 1.0)
	var y := 0.0
	for i in frames:
		var k := float(i) / frames
		y = lerpf(y, rng.randf_range(-1.0, 1.0), a)
		var env := sin(k * PI)
		samples[i] = y * env * gain * 3.0
	return _wav(samples, false)


func _engine_loop() -> AudioStreamWAV:
	# 0.5 s of a low two-cylinder-ish putter. Whole cycles, so the loop is seamless.
	var base := 44.0
	var frames := int(RATE * 0.5)
	var samples := PackedFloat32Array()
	samples.resize(frames)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var grit := 0.0
	for i in frames:
		var t := float(i) / RATE
		var p := fmod(t * base, 1.0)
		var saw := 2.0 * p - 1.0
		var pulse := 0.5 + 0.5 * sin(t * base * 0.5 * TAU)
		grit = lerpf(grit, rng.randf_range(-1.0, 1.0), 0.08)
		samples[i] = (saw * 0.45 + sin(t * base * 2.0 * TAU) * 0.25 + grit * 0.2) * (0.55 + 0.45 * pulse) * 0.35
	return _wav(samples, true)


func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
