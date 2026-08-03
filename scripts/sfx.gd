extends Node
## Autoload: "Sfx"
##
## Every sound in the game is synthesised at load time instead of shipped as
## audio files, so the project has zero binary assets. Sound matters a lot here:
## hearing a zap across the lot, or a sonar ping going off behind you, is most
## of what makes the hunt tense.

const RATE := 22050

var _bank: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_index := 0
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_3d_index := 0
var _ring: AudioStreamPlayer


func _ready() -> void:
	_build_bank()
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	# Positional voices, built once and reused forever. Parented here until a
	# world asks for one.
	for i in 14:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 8.0
		add_child(p)
		_pool_3d.append(p)

	_ring = AudioStreamPlayer.new()
	_ring.bus = "SFX"     # was Master, so the effects slider didn't touch it
	_ring.volume_db = -9.0
	add_child(_ring)


## Play a 2D (non-positional) sound. Use for your own actions and UI.
func play(id: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _bank.has(id):
		return
	var p := _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = _bank[id]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Play a sound at a point in the world. Use for anything an enemy does, so you
## can hear which direction it came from.
##
## Pooled. Eight players firing five times a second was creating and freeing
## forty audio nodes a second, which is pure allocation churn — the worst kind
## of cost on a phone because it shows up as stutter rather than framerate.
func play_at(id: String, world_node: Node3D, position: Vector3, volume_db := 0.0,
		max_distance := 60.0) -> void:
	if not _bank.has(id) or world_node == null:
		return
	var p := _next_3d()
	# Reparent rather than rebuild: positional audio has to live in the world's
	# tree to be heard in the right place.
	if p.get_parent() != world_node:
		if p.get_parent() != null:
			p.get_parent().remove_child(p)
		world_node.add_child(p)
	p.stream = _bank[id]
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.global_position = position
	p.play()


func _next_3d() -> AudioStreamPlayer3D:
	# Prefer a free voice; if every one is busy, steal the oldest. Stealing is
	# fine here — a shot you can't hear over eight others isn't a loss.
	for i in _pool_3d.size():
		var index := (_pool_3d_index + i) % _pool_3d.size()
		if not _pool_3d[index].playing:
			_pool_3d_index = (index + 1) % _pool_3d.size()
			return _pool_3d[index]
	var stolen := _pool_3d[_pool_3d_index]
	_pool_3d_index = (_pool_3d_index + 1) % _pool_3d.size()
	return stolen


func start_ringing() -> void:
	if _ring.playing:
		return
	_ring.stream = _bank["ring"]
	_ring.play()


func stop_ringing() -> void:
	_ring.stop()


func stream(id: String) -> AudioStreamWAV:
	return _bank.get(id)


# ---------------------------------------------------------------------------
# Synthesis
# ---------------------------------------------------------------------------

func _build_bank() -> void:
	# One shot: a bright descending zip with a noise edge on it.
	_bank["zap"] = _render(0.20, func(t: float) -> float:
		var env: float = exp(-t * 16.0)
		var f: float = 1500.0 - 1100.0 * t / 0.20
		var body: float = sin(TAU * f * t) * 0.42 + _saw(f * 0.5 * t) * 0.16
		var edge: float = _noise(t * 40000.0) * exp(-t * 60.0) * 0.24
		return (body + edge) * env
	)

	# The emitter giving up: a hiss and a falling whine.
	_bank["overheat"] = _render(0.5, func(t: float) -> float:
		var hiss: float = _noise(t * 18000.0) * exp(-t * 5.0) * 0.34
		var whine: float = sin(TAU * (900.0 - 700.0 * t / 0.5) * t) * exp(-t * 4.0) * 0.30
		return hiss + whine
	)

	# Taking a hit: a dull thud with a little grit. Was summing to 1.1 and
	# clipping flat, which is why it read as a crackle rather than an impact.
	_bank["hit"] = _render(0.20, func(t: float) -> float:
		var env: float = exp(-t * 20.0)
		var thud: float = sin(TAU * 128.0 * t * (1.0 - t * 0.8)) * 0.55
		var grit: float = _noise(t * 12000.0) * exp(-t * 55.0) * 0.18
		return (thud + grit) * env
	)

	# Confirmation that your zap connected. Short, high, satisfying.
	_bank["hitmark"] = _render(0.07, func(t: float) -> float:
		return sin(TAU * 2100.0 * t) * exp(-t * 45.0) * 0.5
	)

	# Sonar ping: the heartbeat sensor firing. Warm, with a tail.
	_bank["ping"] = _render(0.55, func(t: float) -> float:
		var a: float = sin(TAU * 1320.0 * t) * exp(-t * 9.0)
		var b: float = sin(TAU * 990.0 * (t - 0.16)) * exp(-(t - 0.16) * 9.0) if t > 0.16 else 0.0
		return (a + b * 0.55) * 0.42
	)

	# What the *victim* hears when somebody scans them. Low and ominous.
	_bank["scanned"] = _render(0.6, func(t: float) -> float:
		var pulse: float = 1.0 if fmod(t, 0.28) < 0.13 else 0.0
		return sin(TAU * 190.0 * t) * pulse * exp(-t * 2.2) * 0.48
	)

	# Incoming call. Two-tone warble, loops for as long as it rings.
	_bank["ring"] = _render(1.0, func(t: float) -> float:
		var on: float = 1.0 if t < 0.62 else 0.0
		var warble: float = 1.0 if fmod(t, 0.09) < 0.045 else 0.0
		var tone: float = sin(TAU * 480.0 * t) * 0.5 + sin(TAU * 620.0 * t) * 0.5
		return tone * on * (0.35 + 0.65 * warble) * 0.50
	, true)

	# Placing a call. Outgoing dial blip.
	_bank["dial"] = _render(0.25, func(t: float) -> float:
		var f: float = 700.0 + 400.0 * t / 0.25
		return sin(TAU * f * t) * exp(-t * 10.0) * 0.45
	)

	# Death: everything falling apart.
	_bank["death"] = _render(0.75, func(t: float) -> float:
		var f: float = 420.0 * exp(-t * 2.4)
		return (sin(TAU * f * t) * 0.62 + _noise(t * 3000.0) * 0.14) * exp(-t * 3.2) * 0.58
	)

	# Battery empty / action refused.
	_bank["deny"] = _render(0.16, func(t: float) -> float:
		return _saw(180.0 * t) * exp(-t * 16.0) * 0.35
	)

	# Respawn / round start.
	_bank["spawn"] = _render(0.45, func(t: float) -> float:
		var f: float = 300.0 + 500.0 * t / 0.45
		return (sin(TAU * f * t) * 0.5 + sin(TAU * f * 1.5 * t) * 0.25) * exp(-t * 5.0) * 0.5
	)

	_bank["win"] = _render(0.9, func(t: float) -> float:
		var step := int(t / 0.16)
		var freqs := [523.0, 659.0, 784.0, 1046.0, 1046.0, 1318.0]
		var f: float = freqs[mini(step, freqs.size() - 1)]
		return sin(TAU * f * t) * exp(-fmod(t, 0.16) * 9.0) * 0.4
	)

	_bank["lose"] = _render(0.9, func(t: float) -> float:
		var step := int(t / 0.22)
		var freqs := [392.0, 349.0, 294.0, 233.0]
		var f: float = freqs[mini(step, freqs.size() - 1)]
		return sin(TAU * f * t) * exp(-fmod(t, 0.22) * 6.0) * 0.4
	)


const ATTACK := 0.0025
const RELEASE := 0.004
## Everything is mixed to peak here rather than at 1.0. Anything that reached
## full scale was clipping against the clamp below, which is what turns a thump
## into a crackle.
const HEADROOM := 0.72


func _render(duration: float, generator: Callable, looping := false) -> AudioStreamWAV:
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / float(RATE)
		var v: float = float(generator.call(t)) * HEADROOM

		if not looping:
			# Fade both ends. Noise-based sounds start at full deflection, and
			# a waveform that begins away from zero is a click — that's the
			# static you hear on the front of an impact.
			if t < ATTACK:
				v *= t / ATTACK
			var tail := float(count - i) / float(RATE)
			if tail < RELEASE:
				v *= tail / RELEASE

		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))

	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if looping:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = count - 1
	return s


static func _saw(phase: float) -> float:
	return fmod(phase, 1.0) * 2.0 - 1.0


## Cheap deterministic noise. Doesn't need to be good, just needs to hiss.
static func _noise(x: float) -> float:
	return fmod(sin(x * 12.9898) * 43758.5453, 2.0) - 1.0
