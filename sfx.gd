extends Node
## Procedural sound effects. Everything is synthesized at startup; no audio files.

const RATE := 22050
var players: Array[AudioStreamPlayer] = []
var streams := {}
var muted := false
var log_events := false
var events: Array = []

func _ready() -> void:
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	seed(1234)
	streams["chomp"] = _wav(_chomp())
	streams["burp"] = _wav(_burp())
	streams["roar"] = _wav(_roar())
	streams["pop"] = _wav(_pop())
	streams["pet"] = _wav(_pet())
	streams["level"] = _wav(_level())
	streams["step"] = _wav(_step())
	streams["plop"] = _wav(_plop())
	streams["crack"] = _wav(_crack())
	streams["buy"] = _wav(_buy())
	streams["coin"] = _wav(_coin())
	streams["buzz"] = _wav(_buzz())
	streams["fire"] = _wav(_fire())
	streams["poof"] = _wav(_poof())
	randomize()

func play(id: String, vol_db := 0.0, pitch := 1.0) -> void:
	if muted or not streams.has(id):
		return
	if log_events:
		events.append([Time.get_unix_time_from_system(), id, vol_db, pitch])
	var pl: AudioStreamPlayer = players[0]
	for p in players:
		if not p.playing:
			pl = p
			break
	pl.stream = streams[id]
	pl.volume_db = vol_db
	pl.pitch_scale = pitch
	pl.play()

func _wav(s: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(RATE * sec))
	return a

func _chomp() -> PackedFloat32Array:
	var o := _buf(0.34)
	var lp := 0.0
	var ph := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var v := 0.0
		for bt in [0.0, 0.15]:
			var dt: float = t - bt
			if dt >= 0.0 and dt < 0.14:
				var env := exp(-dt * 34.0)
				ph += (170.0 - 500.0 * dt) / RATE
				v += (randf() * 2.0 - 1.0) * env * 0.9 + sin(TAU * ph) * env * 0.9
				if randf() < 0.02:
					v += (randf() - 0.5) * 1.6 * env
		lp += (v - lp) * 0.42
		o[i] = tanh(lp * 1.4) * 0.85
	return o

func _burp() -> PackedFloat32Array:
	var dur := 0.8
	var o := _buf(dur)
	var ph := 0.0
	var lp := 0.0
	var lp2 := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var f := 105.0 - 40.0 * t / dur + 14.0 * sin(TAU * 6.0 * t) + randf_range(-10.0, 10.0)
		ph = fmod(ph + f / RATE, 1.0)
		var saw := 2.0 * ph - 1.0
		var env := minf(1.0, t / 0.03) * pow(maxf(0.0, 1.0 - t / dur), 0.7)
		var am := 0.6 + 0.4 * sin(TAU * 27.0 * t + sin(TAU * 3.0 * t) * 2.0)
		var v := (saw * 0.9 + (randf() * 2.0 - 1.0) * 0.25) * env * am
		lp += (v - lp) * 0.2
		lp2 += (lp - lp2) * 0.3
		o[i] = tanh(lp2 * 2.6) * 0.9
	return o

func _roar() -> PackedFloat32Array:
	var dur := 1.6
	var o := _buf(dur)
	var ph := 0.0
	var ph2 := 0.0
	var lpn := 0.0
	var lp := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var x := t / dur
		var f := 110.0 + 70.0 * sin(PI * minf(1.0, x * 1.4)) - 40.0 * x
		f *= 1.0 + 0.05 * sin(TAU * 7.0 * t)
		ph = fmod(ph + f / RATE, 1.0)
		ph2 = fmod(ph2 + f * 1.505 / RATE, 1.0)
		var saw := 2.0 * ph - 1.0
		var saw2 := 2.0 * ph2 - 1.0
		lpn += ((randf() * 2.0 - 1.0) - lpn) * 0.35
		var growl := 0.65 + 0.35 * sin(TAU * 31.0 * t)
		var env := minf(1.0, t / 0.12) * (1.0 if x < 0.62 else pow(maxf(0.0, 1.0 - (x - 0.62) / 0.38), 1.5))
		var v := (saw * 0.7 + saw2 * 0.35 + lpn * 0.9) * growl * env
		lp += (v - lp) * 0.33
		o[i] = tanh(lp * 3.2) * 0.8
	return o

func _pop() -> PackedFloat32Array:
	var o := _buf(0.12)
	var ph := 0.0
	for i in o.size():
		var t := float(i) / RATE
		ph += (420.0 + 9000.0 * t) / RATE
		o[i] = sin(TAU * ph) * exp(-t * 30.0) * 0.6
	return o

func _pet() -> PackedFloat32Array:
	var dur := 0.36
	var o := _buf(dur)
	var ph := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var f := 560.0 + 300.0 * sin(PI * t / dur) + 40.0 * sin(TAU * 28.0 * t)
		ph = fmod(ph + f / RATE, 1.0)
		var tri := 1.0 - 4.0 * absf(ph - 0.5)
		var env := minf(1.0, t / 0.02) * maxf(0.0, 1.0 - t / dur)
		o[i] = tri * env * 0.5
	return o

func _level() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99, 1046.5]
	var o := _buf(0.7)
	var ph := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var idx := mini(int(t / 0.09), 3)
		var nt := t - idx * 0.09
		ph = fmod(ph + notes[idx] / RATE, 1.0)
		var sq := 1.0 if ph < 0.5 else -1.0
		var tri := 1.0 - 4.0 * absf(ph - 0.5)
		var dec := 12.0 if idx < 3 else 4.5
		o[i] = (sq * 0.25 + tri * 0.5) * exp(-nt * dec) * 0.55
	return o

func _step() -> PackedFloat32Array:
	var o := _buf(0.22)
	var ph := 0.0
	var lp := 0.0
	for i in o.size():
		var t := float(i) / RATE
		ph += (70.0 - 80.0 * t) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * 0.1
		o[i] = tanh((sin(TAU * ph) * 1.2 + lp * 0.6) * exp(-t * 18.0) * 1.5) * 0.9
	return o

func _plop() -> PackedFloat32Array:
	var o := _buf(0.12)
	var ph := 0.0
	for i in o.size():
		var t := float(i) / RATE
		ph += (320.0 - 1500.0 * t) / RATE
		o[i] = sin(TAU * ph) * exp(-t * 28.0) * 0.5
	return o

func _crack() -> PackedFloat32Array:
	var o := _buf(0.18)
	var lp := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var v := (randf() * 2.0 - 1.0) * exp(-t * 40.0)
		if randf() < 0.01:
			v += randf() - 0.5
		lp += (v - lp) * 0.7
		o[i] = lp * 0.8
	return o

func dump(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	for id in streams:
		(streams[id] as AudioStreamWAV).save_to_wav(dir + "/" + id + ".wav")
	var f := FileAccess.open(dir + "/events.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(events))


func _buy() -> PackedFloat32Array:
	# cash-register ka-ching: metallic thunk + two bright bells
	var o := _buf(0.75)
	for i in o.size():
		var t := float(i) / RATE
		var v := 0.0
		if t < 0.06:
			v += (randf() * 2.0 - 1.0) * exp(-t * 60.0) * 0.6 + sin(TAU * 140.0 * t) * exp(-t * 40.0) * 0.6
		for b in [[0.08, 1568.0], [0.17, 2093.0]]:
			var dt: float = t - b[0]
			if dt > 0.0:
				var f: float = b[1]
				v += (sin(TAU * f * dt) + 0.5 * sin(TAU * f * 2.76 * dt) + 0.25 * sin(TAU * f * 5.4 * dt)) * exp(-dt * 7.0) * 0.32
		o[i] = tanh(v)
	return o

func _coin() -> PackedFloat32Array:
	var o := _buf(0.22)
	for i in o.size():
		var t := float(i) / RATE
		var f := 1318.0 if t < 0.06 else 1760.0
		o[i] = (sin(TAU * f * t) * 0.5 + 0.25 * sin(TAU * f * 2.0 * t)) * exp(-t * 14.0) * 0.8
	return o

func _buzz() -> PackedFloat32Array:
	var o := _buf(0.32)
	for i in o.size():
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
		var env := 1.0 if (t < 0.12 or (t > 0.16 and t < 0.28)) else 0.0
		o[i] = sq * env * 0.32 * (1.0 - t * 2.0)
	return o

func _fire() -> PackedFloat32Array:
	# whooshy roaring flame, ~1.4 s (looped by re-triggering)
	var o := _buf(1.5)
	var lp := 0.0; var lp2 := 0.0
	for i in o.size():
		var t := float(i) / RATE
		var env := minf(1.0, t * 8.0) * minf(1.0, (1.5 - t) * 3.0)
		var n := randf() * 2.0 - 1.0
		lp += (n - lp) * (0.18 + 0.1 * sin(t * 23.0))
		lp2 += (lp - lp2) * 0.5
		var crackle := 0.0
		if randf() < 0.004:
			crackle = randf_range(-1.0, 1.0)
		o[i] = tanh((lp2 * 2.6 + crackle) * env) * 0.8
	return o

func _poof() -> PackedFloat32Array:
	var o := _buf(0.45)
	var lp := 0.0
	for i in o.size():
		var t := float(i) / RATE
		lp += ((randf() * 2.0 - 1.0) - lp) * (0.25 - t * 0.4)
		o[i] = lp * exp(-t * 8.0) * 1.6 + sin(TAU * (600.0 + 900.0 * t) * t) * exp(-t * 10.0) * 0.25
	return o
