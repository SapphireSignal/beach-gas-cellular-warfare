extends Node3D
class_name Phone
## The weapon. It's a phone.
##
## Three apps:
##   ZAP    a continuous beam. Hold it down and it burns, but it overheats after
##          three seconds and locks you out for five.
##   TRACK  sonar ping that reveals people — but tells them you pinged.
##   CALL   makes their phone ring anywhere on the map. It doesn't care about
##          walls or distance, because phone calls don't.
##
## The intended combo is TRACK to find them, CALL to pin them, ZAP to finish.
## There is no ammo. Heat and cooldowns ration everything.

const MODE_ZAP := 0
const MODE_TRACK := 1
const MODE_CALL := 2
## Kept as an alias so the existing `Phone.MODE_COLORS[mode]` call sites in the
## HUD, beam and radar keep working. The colours themselves live in Palette,
## where the rule about never re-assigning the trio is written down.
const MODE_COLORS := Palette.MODE

# --- zap ---
## Five clean hits to put somebody down, dropping to about eight at max range.
## Long enough that a fight is a fight rather than whoever peeked first.
const ZAP_DAMAGE := 20.0
const ZAP_FALLOFF_DAMAGE := 13.0
const ZAP_FALLOFF_START := 22.0
const ZAP_RANGE := 45.0
## Enough of a gap that shots read as separate hits rather than a blur, short
## enough that it never feels like the trigger is locked. Tapping through it is
## silent on purpose — nothing happens, and the game doesn't tell you off.
const ZAP_COOLDOWN := 0.18

## Heat is the real limiter. Mash the trigger and you get about nine shots —
## one kill plus room to miss — then five seconds of nothing.
const HEAT_PER_SHOT := 0.34
const HEAT_MAX := 3.0
const HEAT_COOL_RATE := 1.0
const HEAT_COOL_DELAY := 0.28
const OVERHEAT_LOCKOUT := 5.0
const BEAM_FADE := 0.11

# --- track ---
const TRACK_COOLDOWN := 5.0
const TRACK_REVEAL := 3.0
const TRACK_PULSE := 0.6

# --- call ---
const CALL_COOLDOWN := 10.0

var player = null

var mode := MODE_ZAP
var heat := 0.0
var overheat_until := 0.0
var zap_ready_at := 0.0
var track_ready_at := 0.0
var call_ready_at := 0.0

## pid -> last pinged position. Deliberately stale between pulses so the radar
## shows you where they *were*, sonar style, not a live GPS dot.
var revealed: Dictionary = {}
var reveal_until := 0.0
var _next_pulse := 0.0

var _owned := false
var _camera: Camera3D
var _screen_mat: StandardMaterial3D
var _bob := 0.0
var _kick := 0.0
var _sway := Vector2.ZERO
## Kept inside the player's 0.36m collision radius on purpose. At the old
## -0.42 the phone sat *further* from the camera than a wall can get, so
## world geometry cut straight through it whenever you stood near one -
## the glitching Jay reported. Nothing can intrude inside 0.36, so this is
## clipping-proof rather than clipping-unlikely.
##
## Pulled in to 60% of the old distance, which also makes it read ~1.7x
## larger on screen; the scale below adds the rest of the size Jay asked
## for. Position is scaled by the same factor so it stays framed where it
## was, just nearer and bigger.
var _rest_position := Vector3(0.141, -0.123, -0.252)
var _rest_rotation := Vector3(-9.0, 14.0, 4.0)

var _last_shot := -99.0
var _last_deny := -99.0
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _beam_flash := 0.0
var _shot_from := Vector3.ZERO
var _shot_to := Vector3.ZERO
var _emitter: MeshInstance3D
var _emitter_mat: StandardMaterial3D
var _muzzle: GPUParticles3D
var _muzzle_light: OmniLight3D
var _muzzle_glow := 0.0
## The ZAP / TRACK / CALL icons on the home screen, in mode order.
var _app_mats: Array[StandardMaterial3D] = []


func setup(is_local: bool, is_bot := false) -> void:
	_camera = get_parent() as Camera3D
	_owned = is_local or is_bot   # a bot's phone works, it just isn't drawn
	visible = is_local
	if is_local:
		_build_viewmodel()
	_build_beam()


func _process(delta: float) -> void:
	# The beam is drawn for everybody — you need to see other people's lasers.
	_update_beam(delta)

	if visible:
		_update_muzzle(delta)
	if not _owned:
		return
	if visible:
		_animate(delta)
		_update_apps()
	_update_heat(delta)
	_pulse_tracker()


## Muzzle light dies fast — a long flash reads as a lamp, a short one as a shot.
func _update_muzzle(delta: float) -> void:
	if _muzzle_light == null:
		return
	_muzzle_glow = maxf(0.0, _muzzle_glow - delta * 11.0)
	_muzzle_light.light_energy = _muzzle_glow * 5.5
	_muzzle_light.visible = _muzzle_glow > 0.01
	if _emitter_mat != null:
		# The lens sits lit in the current mode colour and flares when it fires,
		# so enemies can read what app you're on from the glow alone.
		_emitter_mat.emission = MODE_COLORS[mode]
		_emitter_mat.emission_energy_multiplier = 1.8 + _muzzle_glow * 9.0
		if is_overheated():
			_emitter_mat.emission = Palette.OVERHEAT
			_emitter_mat.emission_energy_multiplier = 0.6 + 0.4 * sin(_now() * 9.0)


## The app you last used sits lit; the other two idle. Glancing at the screen
## tells you what the lens is set to without any HUD text.
func _update_apps() -> void:
	for i in _app_mats.size():
		var active := i == mode
		_app_mats[i].emission_energy_multiplier = (
			1.8 + 0.5 * sin(_now() * 5.0) if active else 0.45)
		_app_mats[i].albedo_color = (MODE_COLORS[i] if active
			else Color(MODE_COLORS[i]).darkened(0.45))


func _fire_muzzle() -> void:
	_muzzle_glow = 1.0
	if _muzzle != null:
		_muzzle.restart()
	if _muzzle_light != null:
		_muzzle_light.light_color = MODE_COLORS[MODE_ZAP]


# ---------------------------------------------------------------------------
# ZAP — held beam with an overheat
# ---------------------------------------------------------------------------

func zap_cooldown_ratio() -> float:
	return clampf((zap_ready_at - _now()) / ZAP_COOLDOWN, 0.0, 1.0)


## Decaying kick from the last shot, for crosshair bloom. Outlasts the tiny
## fire-rate floor so the reticle still reacts visibly to every shot.
func recoil() -> float:
	return clampf(_kick, 0.0, 1.0)


## True when this phone is the one being looked through.
func is_local_view() -> bool:
	return visible


func is_overheated() -> bool:
	return _now() < overheat_until


func heat_ratio() -> float:
	if is_overheated():
		return 1.0
	return clampf(heat / HEAT_MAX, 0.0, 1.0)


func overheat_seconds() -> float:
	return maxf(0.0, overheat_until - _now())


func can_zap() -> bool:
	return (player.alive and not player.is_busy()
		and not is_overheated() and _now() >= zap_ready_at)


func zap_block_reason() -> String:
	if not player.alive:
		return ""
	if is_overheated():
		return "OVERHEATED  %.1fs" % overheat_seconds()
	if player.is_busy():
		return "can't shoot while your phone is ringing"
	return ""


func try_zap() -> bool:
	if not can_zap():
		# Deliberately silent. Mashing a trigger that isn't ready should feel
		# like nothing happening, not like the game telling you off.
		return false

	zap_ready_at = _now() + ZAP_COOLDOWN
	_last_shot = _now()
	mode = MODE_ZAP
	player.mode = MODE_ZAP
	_kick = 1.0

	_fire_muzzle()
	if is_local_view():
		player.add_shake(0.13)
	heat += HEAT_PER_SHOT
	if heat >= HEAT_MAX:
		_overheat()

	var hit := _trace()
	if hit.is_empty():
		return true
	var victim = hit["player"]
	_show_beam.rpc(_muzzle_position(), hit["end"], hit["normal"], str(hit["surface"]),
		victim != null)
	if victim != null and victim.alive:
		var distance: float = hit["distance"]
		Net.report_zap.rpc_id(1, int(victim.peer_id), _damage_at(distance), distance,
			int(player.peer_id))
	return true


func _update_heat(delta: float) -> void:
	# Only bleeds off once you've laid off the trigger for a moment.
	if _now() - _last_shot > HEAT_COOL_DELAY:
		heat = maxf(0.0, heat - HEAT_COOL_RATE * delta)


func _overheat() -> void:
	heat = HEAT_MAX
	overheat_until = _now() + OVERHEAT_LOCKOUT
	if visible:
		Sfx.play("overheat", -10.0)
		Sfx.buzz(70)


## Raycast down the barrel. Returns {} on a total miss, otherwise the end point,
## the distance, and the player hit if there was one.
func _trace() -> Dictionary:
	if _camera == null:
		return {}
	var from := _camera.global_position
	var dir := -_camera.global_transform.basis.z
	var to := from + dir * ZAP_RANGE

	var query := PhysicsRayQueryParameters3D.create(from, to, 0b11, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	var end_point := to
	var victim = null
	var surface := "dust"
	var normal := -dir
	if hit:
		end_point = hit["position"]
		normal = hit.get("normal", -dir)
		var collider = hit["collider"]
		if collider != null:
			if collider.is_in_group("players"):
				victim = collider
			elif collider.has_meta("surface"):
				surface = str(collider.get_meta("surface"))
	return {
		"end": end_point,
		"normal": normal,
		"surface": surface,
		"distance": from.distance_to(end_point),
		"player": victim,
	}


func _damage_at(distance: float) -> float:
	if distance <= ZAP_FALLOFF_START:
		return ZAP_DAMAGE
	var t: float = clampf((distance - ZAP_FALLOFF_START) / (ZAP_RANGE - ZAP_FALLOFF_START), 0.0, 1.0)
	return lerpf(ZAP_DAMAGE, ZAP_FALLOFF_DAMAGE, t)


# ---------------------------------------------------------------------------
# Beam visuals & sound
#
# One mesh per player, reused and flashed on each shot, rather than spawning
# and freeing geometry every time somebody pulls the trigger.
# ---------------------------------------------------------------------------

## Everyone draws the shot and hears it, so gunfire gives away position.
@rpc("any_peer", "call_local", "unreliable")
func _show_beam(from: Vector3, to: Vector3, normal: Vector3, surface: String,
		hit_player: bool) -> void:
	_shot_from = from
	_shot_to = to
	_beam_flash = 1.0
	if Net.world != null:
		Beam.impact(Net.world, to, normal, surface, hit_player)
		Sfx.play_at("zap", Net.world, from, -14.0, 50.0)

func _build_beam() -> void:
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.albedo_color = Color(MODE_COLORS[MODE_ZAP].r, MODE_COLORS[MODE_ZAP].g,
		MODE_COLORS[MODE_ZAP].b, 0.9)
	_beam_mat.emission_enabled = true
	_beam_mat.emission = MODE_COLORS[MODE_ZAP]
	_beam_mat.emission_energy_multiplier = 5.5
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.05, 0.05, 1.0)   # scaled to length each frame

	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.material_override = _beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	player.add_child(_beam)


func _update_beam(delta: float) -> void:
	if _beam == null:
		return
	_beam_flash = maxf(0.0, _beam_flash - delta / BEAM_FADE)
	_beam.visible = _beam_flash > 0.02
	if not _beam.visible:
		return

	var length := _shot_from.distance_to(_shot_to)
	if length < 0.1:
		_beam.visible = false
		return

	# Thins out as it fades rather than just going transparent.
	_beam.scale = Vector3(0.35 + 0.65 * _beam_flash, 0.35 + 0.65 * _beam_flash, length)
	_beam.global_position = (_shot_from + _shot_to) * 0.5
	var up := Vector3.UP
	if absf((_shot_to - _shot_from).normalized().dot(Vector3.UP)) > 0.999:
		up = Vector3.RIGHT
	_beam.look_at(_shot_to, up)
	_beam_mat.albedo_color.a = 0.9 * _beam_flash
	_beam_mat.emission_energy_multiplier = 7.0 * _beam_flash


func _muzzle_position() -> Vector3:
	if _emitter != null and visible:
		return _emitter.global_position
	# Remote players fire from the phone in their hand, not their face.
	var aim: Basis = _camera.global_transform.basis if _camera else player.global_transform.basis
	return player.global_position + Vector3(0, 1.15, 0) + aim.x * 0.26 - aim.z * 0.3


# ---------------------------------------------------------------------------

func _vm_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


## Cylinder laid on its side so its flat face points down -Z, i.e. at whatever
## you're aiming at. Used for the camera lenses.
func _vm_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 0
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = Vector3(90, 0, 0)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


# ---------------------------------------------------------------------------
# TRACK — the heartbeat sensor
# ---------------------------------------------------------------------------

func track_cooldown_ratio() -> float:
	return clampf((track_ready_at - _now()) / TRACK_COOLDOWN, 0.0, 1.0)


func track_cooldown_seconds() -> float:
	return maxf(0.0, track_ready_at - _now())


func can_track() -> bool:
	return player.alive and _now() >= track_ready_at


func tracking_active() -> bool:
	return _now() < reveal_until


func track_block_reason() -> String:
	if not player.alive:
		return ""
	if _now() < track_ready_at:
		return "sensor recharging  %.0fs" % ceil(track_cooldown_seconds())
	return ""


func try_track() -> bool:
	if not can_track():
		_deny()
		return false

	track_ready_at = _now() + TRACK_COOLDOWN
	reveal_until = _now() + TRACK_REVEAL
	_next_pulse = 0.0
	mode = MODE_TRACK
	player.mode = MODE_TRACK
	if visible:
		Sfx.play("ping", -7.0)

	# Scanning isn't free information. Everyone you light up gets told.
	for other in _enemies():
		_notify(other, "receive_scan", int(player.peer_id))
	return true


func _pulse_tracker() -> void:
	if not tracking_active():
		if not revealed.is_empty() and _now() > reveal_until + 0.5:
			revealed.clear()
		return
	if _now() < _next_pulse:
		return
	_next_pulse = _now() + TRACK_PULSE
	for other in _enemies():
		if other.alive:
			revealed[int(other.peer_id)] = other.global_position
		else:
			revealed.erase(int(other.peer_id))
	if visible and _next_pulse - TRACK_PULSE > 0.0:
		Sfx.play("ping", -14.0, 1.15)


# ---------------------------------------------------------------------------
# CALL
# ---------------------------------------------------------------------------

func call_cooldown_ratio() -> float:
	return clampf((call_ready_at - _now()) / CALL_COOLDOWN, 0.0, 1.0)


func call_cooldown_seconds() -> float:
	return maxf(0.0, call_ready_at - _now())


func can_call() -> bool:
	return (player.alive
		and not player.is_busy()
		and _now() >= call_ready_at
		and pick_call_target() != null)


func call_block_reason() -> String:
	if not player.alive:
		return ""
	if player.is_busy():
		return "your own phone is ringing"
	if _now() < call_ready_at:
		return "call recharging  %.0fs" % ceil(call_cooldown_seconds())
	if pick_call_target() == null:
		return "nobody left to call"
	return ""


## A phone call doesn't care about walls or distance — that's the entire point
## of it. Anybody alive is reachable. When there's more than one candidate,
## prefer whoever you're looking at, then whoever is closest.
func pick_call_target():
	var best = null
	var best_score := -INF
	var origin: Vector3 = _camera.global_position if _camera else player.global_position
	var forward: Vector3 = -_camera.global_transform.basis.z if _camera else Vector3.FORWARD

	for other in _enemies():
		if not other.alive or not other.can_be_called():
			continue
		var offset: Vector3 = other.global_position - origin
		var distance := offset.length()
		var facing := forward.dot(offset / maxf(distance, 0.01))
		var score := facing * 2.0 - distance * 0.02
		if tracking_active() and revealed.has(int(other.peer_id)):
			score += 1.0
		if score > best_score:
			best_score = score
			best = other
	return best


func try_call() -> bool:
	var target = pick_call_target()
	if not player.alive or player.is_busy() or _now() < call_ready_at or target == null:
		_deny()
		return false

	call_ready_at = _now() + CALL_COOLDOWN
	mode = MODE_CALL
	player.mode = MODE_CALL
	if visible:
		Sfx.play("dial", -8.0)
	_notify(target, "receive_call", int(player.peer_id))
	return true


## Deliver a message to another player's own copy of themselves. If that body is
## already authoritative on this machine — a bot we simulate, or ourselves being
## shot by a bot — call it directly; Godot rejects an RPC addressed to yourself.
func _notify(target, method: StringName, arg) -> void:
	var pid := int(target.peer_id)
	if Net.is_bot(pid) or pid == Net.my_id():
		target.call(method, arg)
	else:
		target.rpc_id(pid, method, arg)


# ---------------------------------------------------------------------------
# Viewmodel
# ---------------------------------------------------------------------------

## The phone is held with its BACK toward the target and the beam leaves the
## camera lens — the lens is the thing that kills you, which is what sells this
## as a phone rather than a gun. That also puts the screen where only you can
## see it.
func _build_viewmodel() -> void:
	position = _rest_position
	rotation_degrees = _rest_rotation
	# On top of being pulled nearer, the whole viewmodel - phone and the hand
	# holding it - is scaled up. Jay wanted it bigger on screen; combined with
	# the closer rest position it now reads a bit over twice its old size.
	scale = Vector3.ONE * 1.25

	var entry := Characters.get_entry(int(player.character_index))
	var case := player.case_color as Color

	var m_rail := _viewmodel_mat(case.lightened(0.08), false)
	m_rail.metallic = 0.75
	m_rail.roughness = 0.28
	var m_back := _viewmodel_mat(case, false)
	m_back.metallic = 0.35
	m_back.roughness = 0.22
	var m_glass := _viewmodel_mat(Color(0.05, 0.05, 0.07), false)
	m_glass.roughness = 0.08
	var m_module := _viewmodel_mat(case.darkened(0.25), false)
	m_module.metallic = 0.5
	var m_ring := _viewmodel_mat(Color(0.16, 0.16, 0.18), false)
	m_ring.metallic = 0.9
	m_ring.roughness = 0.15
	var m_lensglass := _viewmodel_mat(Color(0.06, 0.09, 0.16), false)
	m_lensglass.roughness = 0.04

	var body := Node3D.new()
	add_child(body)

	# Chassis: metal rail, glass back, glass front.
	_vm_box(body, Vector3.ZERO, Vector3(0.0795, 0.1595, 0.0125), m_rail)
	_vm_box(body, Vector3(0, 0, -0.0064), Vector3(0.0735, 0.1535, 0.0012), m_back)
	_vm_box(body, Vector3(0, 0, 0.0064), Vector3(0.0715, 0.1515, 0.0012), m_glass)

	_build_screen(body)

	# Camera module on the back. The top lens is the emitter.
	_vm_box(body, Vector3(-0.019, 0.0515, -0.0088), Vector3(0.0315, 0.0375, 0.0038), m_module)
	# The emitter keeps its own pivot so the merge below leaves it alone: the
	# muzzle flash is positioned from it, and a freed node would take the beam
	# origin with it.
	var lens_mount := Node3D.new()
	lens_mount.name = "LensMount"
	body.add_child(lens_mount)
	var lenses := [
		[Vector3(-0.0265, 0.0605, -0.0112), 0.0088, true],
		[Vector3(-0.0112, 0.0605, -0.0112), 0.0076, false],
		[Vector3(-0.0189, 0.0435, -0.0112), 0.0076, false],
	]
	for lens in lenses:
		var at: Vector3 = lens[0]
		var r: float = lens[1]
		_vm_cylinder(body, at, r, 0.0034, m_ring)
		_vm_cylinder(body, at + Vector3(0, 0, -0.0012), r * 0.68, 0.0016, m_lensglass)
		if bool(lens[2]):
			_emitter_mat = _viewmodel_mat(MODE_COLORS[MODE_ZAP], true)
			_emitter_mat.emission_energy_multiplier = 2.2
			_emitter = _vm_cylinder(lens_mount, at + Vector3(0, 0, -0.0022), r * 0.42,
				0.0012, _emitter_mat)
	_vm_box(body, Vector3(-0.0035, 0.0505, -0.0102), Vector3(0.0055, 0.0055, 0.0012),
		_viewmodel_mat(Color(1.0, 0.94, 0.72), true))

	# Buttons.
	_vm_box(body, Vector3(0.0408, 0.021, 0), Vector3(0.0026, 0.021, 0.0062), m_rail)
	_vm_box(body, Vector3(-0.0408, 0.036, 0), Vector3(0.0026, 0.015, 0.0062), m_rail)
	_vm_box(body, Vector3(-0.0408, 0.016, 0), Vector3(0.0026, 0.015, 0.0062), m_rail)

	_build_hand(entry)
	_build_muzzle()

	# Roughly sixty mesh instances, none bigger than a fingernail, all of them on
	# screen every frame of the match — it was the largest single block of draw
	# calls in the game. Merging folds them to one draw per material.
	#
	# Order survives because the merge walks materials in first-use order and
	# these all share `no_depth_test`, so what's drawn last still wins.
	MeshMerge.merge_children(body)


## The home screen, facing you and nobody else. Status bar, app grid, dock.
##
## This is where the theme colour from the customise menu actually lands — it's
## your phone, so it should look like your phone. The three app icons that
## matter are ZAP, TRACK and CALL, and the one you last used lights up, so a
## glance down tells you what the lens is currently doing.
func _build_screen(body: Node3D) -> void:
	var accent: Color = Loadout.accent()
	var z := 0.0072
	var w := 0.0655
	var h := 0.1415

	# Wallpaper: near-black washed with your accent, so the theme reads without
	# drowning the icons.
	_screen_mat = _viewmodel_mat(Color(0.03, 0.035, 0.05).lerp(accent, 0.22), true)
	_screen_mat.emission = Color(0.03, 0.035, 0.05).lerp(accent, 0.35)
	_screen_mat.emission_energy_multiplier = 0.55
	_vm_box(body, Vector3(0, -0.002, z), Vector3(w, h, 0.0006), _screen_mat)

	# Dynamic island.
	_vm_box(body, Vector3(0, 0.0645, z + 0.0006), Vector3(0.019, 0.0068, 0.0004),
		_viewmodel_mat(Color(0.02, 0.02, 0.03), false))

	var ink := _viewmodel_mat(Color(0.92, 0.94, 1.0), true)
	ink.emission_energy_multiplier = 1.1

	# Status bar: signal bars, wifi wedge, battery.
	for i in 4:
		_vm_box(body, Vector3(-0.0255 + i * 0.0032, 0.0625 + i * 0.0007, z + 0.0006),
			Vector3(0.0018, 0.0026 + i * 0.0014, 0.0004), ink)
	for i in 3:
		_vm_box(body, Vector3(-0.0105, 0.0618 + i * 0.0018, z + 0.0006),
			Vector3(0.0032 + i * 0.0026, 0.0013, 0.0004), ink)
	_vm_box(body, Vector3(0.0245, 0.0628, z + 0.0006), Vector3(0.0086, 0.0042, 0.0004), ink)
	_vm_box(body, Vector3(0.0232, 0.0628, z + 0.0008), Vector3(0.0052, 0.0028, 0.0004),
		_viewmodel_mat(Color(0.35, 0.95, 0.55), true))

	# App grid. Row one is the three that matter; the rest is set dressing.
	var filler := [
		Color(0.35, 0.62, 0.95), Color(0.95, 0.72, 0.25), Color(0.55, 0.85, 0.45),
		Color(0.88, 0.42, 0.62), Color(0.62, 0.55, 0.92), Color(0.30, 0.78, 0.80),
		Color(0.92, 0.55, 0.30), Color(0.70, 0.72, 0.78), Color(0.85, 0.35, 0.35),
	]
	var icon := 0.0118
	var step_x := 0.0152
	var step_y := 0.0176

	# One material per filler colour rather than one per tile. Thirteen tiles
	# drawing from nine shared materials merges into nine surfaces instead of
	# thirteen, and costs nothing to set up.
	var filler_mats: Array[StandardMaterial3D] = []
	for colour in filler:
		var tile := _viewmodel_mat(colour.darkened(0.15), true)
		tile.emission_energy_multiplier = 0.5
		filler_mats.append(tile)

	_app_mats.clear()
	for row in 4:
		for col in 4:
			var at := Vector3(-step_x * 1.5 + col * step_x, 0.0455 - row * step_y, z + 0.0006)
			if row == 0 and col < 3:
				# ZAP / TRACK / CALL, kept in mode order.
				var mat := _viewmodel_mat(MODE_COLORS[col], true)
				mat.emission_energy_multiplier = 1.0
				_app_mats.append(mat)
				_vm_box(body, at, Vector3(icon, icon, 0.0004), mat)
				# A dot under the live one.
				continue
			_vm_box(body, at, Vector3(icon, icon, 0.0004),
				filler_mats[(row * 4 + col) % filler_mats.size()])

	# Page dots.
	for i in 3:
		_vm_box(body, Vector3(-0.004 + i * 0.004, -0.0405, z + 0.0006),
			Vector3(0.0016, 0.0016, 0.0004), ink)

	# Dock.
	var dock := _viewmodel_mat(Color(1, 1, 1), true)
	dock.albedo_color = Color(1, 1, 1, 0.12)
	dock.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dock.emission = accent
	dock.emission_energy_multiplier = 0.30
	_vm_box(body, Vector3(0, -0.0545, z + 0.0005), Vector3(0.058, 0.0175, 0.0004), dock)
	for i in 4:
		var tile := _viewmodel_mat(filler[(i + 5) % filler.size()].darkened(0.1), true)
		tile.emission_energy_multiplier = 0.55
		_vm_box(body, Vector3(-0.0195 + i * 0.013, -0.0545, z + 0.0008),
			Vector3(0.0102, 0.0102, 0.0004), tile)

	# Home indicator.
	_vm_box(body, Vector3(0, -0.0665, z + 0.0006), Vector3(0.022, 0.0014, 0.0004), ink)


## A hand that reads as a hand: palm, four fingers wrapping the far edge with
## their tips visible against the phone, a thumb resting on the screen side,
## and a forearm coming in from the bottom of frame.
func _build_hand(entry: Dictionary) -> void:
	var skin: Color = entry.get("skin", Color(0.76, 0.58, 0.45))
	var sleeve: Color = entry.get("shirt", Color(0.3, 0.3, 0.35))
	var m_skin := _viewmodel_mat(skin, false)
	m_skin.roughness = 0.62
	var m_knuckle := _viewmodel_mat(skin.darkened(0.06), false)
	var m_sleeve := _viewmodel_mat(sleeve, false)

	var hand := Node3D.new()
	add_child(hand)

	_vm_box(hand, Vector3(0.050, -0.030, 0.012), Vector3(0.050, 0.084, 0.052), m_skin, Vector3(0, 0, -7))
	_vm_box(hand, Vector3(0.068, -0.098, 0.030), Vector3(0.056, 0.056, 0.058), m_skin, Vector3(10, 0, -10))
	_vm_box(hand, Vector3(0.082, -0.140, 0.042), Vector3(0.070, 0.048, 0.072), m_sleeve, Vector3(16, 0, -11))
	_vm_box(hand, Vector3(0.104, -0.235, 0.076), Vector3(0.064, 0.165, 0.066), m_sleeve, Vector3(24, 0, -12))

	# Fingers cross behind the phone; the tips come back into view on the far side.
	var rows := [0.032, 0.008, -0.017, -0.041]
	for i in rows.size():
		var y: float = rows[i]
		var thickness: float = 0.0175 - i * 0.0009
		_vm_box(hand, Vector3(0.020, y, -0.001), Vector3(0.047, thickness, 0.0215), m_knuckle,
			Vector3(0, 0, -3.0 + i))
		_vm_box(hand, Vector3(-0.031, y - 0.001, 0.0035), Vector3(0.027, thickness - 0.001, 0.0205),
			m_skin, Vector3(0, 0, -6.0 + i))

	# Thumb, on your side of the phone.
	_vm_box(hand, Vector3(0.044, -0.006, 0.021), Vector3(0.032, 0.020, 0.024), m_skin, Vector3(0, 0, -34))
	_vm_box(hand, Vector3(0.020, 0.017, 0.024), Vector3(0.027, 0.018, 0.021), m_skin, Vector3(0, 0, -56))

	# Fourteen boxes, three materials, nothing here ever moves independently.
	MeshMerge.merge_children(hand)


## Muzzle flash at the lens: a burst of sparks plus a light that dies almost
## immediately. The light is what sells it — it throws real illumination onto
## whatever you're standing next to.
func _build_muzzle() -> void:
	var at := Vector3(-0.0265, 0.0605, -0.016)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.position = at
	_muzzle_light.light_color = MODE_COLORS[MODE_ZAP]
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 3.2
	_muzzle_light.shadow_enabled = false
	add_child(_muzzle_light)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.008
	process.direction = Vector3(0, 0, -1)
	process.spread = 26.0
	process.initial_velocity_min = 1.1
	process.initial_velocity_max = 3.4
	process.gravity = Vector3.ZERO
	process.damping_min = 4.0
	process.damping_max = 9.0
	process.scale_min = 0.4
	process.scale_max = 1.1

	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.80, 1.0))
	ramp.set_color(1, Color(1.0, 0.20, 0.24, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.016, 0.016)
	var spark := StandardMaterial3D.new()
	spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark.vertex_color_use_as_albedo = true
	spark.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark.disable_receive_shadows = true
	quad.material = spark

	_muzzle = GPUParticles3D.new()
	_muzzle.position = at
	# Mobile budget: a dozen quads for a third of a second. Bigger counts look
	# no better at this size and are exactly what cooks a phone.
	_muzzle.amount = 12
	_muzzle.lifetime = 0.28
	_muzzle.one_shot = true
	_muzzle.explosiveness = 0.95
	_muzzle.emitting = false
	_muzzle.local_coords = false   # sparks stay put as you swing the camera
	_muzzle.process_material = process
	_muzzle.draw_pass_1 = quad
	add_child(_muzzle)


## Viewmodel materials skip the depth test so the phone never clips into a wall
## when you back up against one.
func _viewmodel_mat(color: Color, emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.45
	m.no_depth_test = true
	m.render_priority = 12
	if emissive:
		m.emission_enabled = true
		m.emission = MODE_COLORS[MODE_ZAP]
		m.emission_energy_multiplier = 1.9
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _animate(delta: float) -> void:
	_kick = maxf(0.0, _kick - delta * 5.0)

	# Sway lags your look input a little, so whipping the camera around throws
	# the phone. Costs nothing, adds a lot.
	var look: Vector2 = player.input_look
	_sway = _sway.lerp(Vector2(-look.x, -look.y) * 0.00045, minf(1.0, delta * 12.0))
	_sway = _sway.limit_length(0.05)

	var speed: float = player.horizontal_speed()
	_bob += delta * speed * 1.9
	var bob_amount: float = clampf(speed / player.SPEED, 0.0, 1.4) * 0.014
	var bob := Vector3(cos(_bob) * bob_amount, absf(sin(_bob)) * bob_amount * 0.8, 0.0)

	var busy_drop := Vector3.ZERO
	var busy_tilt := Vector3.ZERO
	if player.is_busy():
		# Phone comes up to your ear-ish when it's ringing. You aren't shooting.
		busy_drop = Vector3(-0.06, 0.10, 0.05)
		busy_tilt = Vector3(18.0, -28.0, -22.0)
	elif is_overheated():
		# Held out and away while it cools off.
		busy_drop = Vector3(0.02, -0.07, 0.06)
		busy_tilt = Vector3(-32.0, 6.0, 10.0)

	var target_pos := _rest_position + bob + busy_drop + Vector3(_sway.x, _sway.y, _kick * 0.03)
	var target_rot := _rest_rotation + busy_tilt + Vector3(-_kick * 5.0, _sway.x * 90.0, 0.0)
	position = position.lerp(target_pos, minf(1.0, delta * 14.0))
	rotation_degrees = rotation_degrees.lerp(target_rot, minf(1.0, delta * 14.0))


# ---------------------------------------------------------------------------

## Rate limited, or mashing a button that isn't ready machine-guns the buzzer.
func _deny() -> void:
	if not visible or _now() - _last_deny < 0.35:
		return
	_last_deny = _now()
	Sfx.play("deny", -8.0)


func _enemies() -> Array:
	var out := []
	if Net.world == null:
		return out
	for p in Net.world.all_players():
		if p != player:
			out.append(p)
	return out


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
