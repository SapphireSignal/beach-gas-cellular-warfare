extends CharacterBody3D
## One player. The same scene runs on every phone; whoever owns it drives it and
## everybody else just watches an interpolated copy.
##
## Movement is client authoritative — you own your own body — so your own
## movement never rubber-bands no matter what the network is doing.

signal took_damage(attacker_id: int)
signal hit_confirmed()
signal was_scanned(by_id: int)
signal call_started(from_id: int)
signal call_ended()
signal died(killer_id: int)
signal respawned()

const SPEED := 4.6
const SPRINT_SPEED := 6.7
const ACCEL := 14.0
const AIR_ACCEL := 3.5
const GRAVITY := 20.0
## Peaks around 1.45m, which clears the crates, the counter and a car bonnet.
## At the old 5.6 you couldn't get on top of anything.
const JUMP_VELOCITY := 7.6
const MAX_HEALTH := 100.0

# Getting called doesn't stun you outright. It makes you slow and clumsy and
# takes your gun away until it stops ringing. There's no picking up — you just
# have to live with it, and everyone can see that you're living with it.
const RING_DURATION := 5.0
const RING_SPEED_MULT := 0.45
const RING_LOOK_MULT := 0.5
const CALL_IMMUNITY := 3.0

## Crouch: slower, shorter, and a much smaller target behind a car bonnet.
const CROUCH_EYE := 1.02
const CROUCH_CAPSULE := 1.20
const STAND_EYE := 1.62
const STAND_CAPSULE := 1.80
const CROUCH_SPEED_MULT := 0.45
const CROUCH_LERP := 10.0

## Camera feel. All of this is arithmetic on one node's transform — it costs
## nothing on a phone and is most of what separates "moves" from "feels good".
const BOB_FREQUENCY := 8.5
const BOB_AMOUNT := 0.032
const SPRINT_FOV_KICK := 7.0
const LAND_DIP_MAX := 0.17
const SHAKE_DECAY := 3.4

## Aim assist. Deliberately weak: it takes the edge off thumb precision on a
## small screen without ever taking the shot for you. Inside the cone your drag
## slows down, and there's a gentle pull that gets weaker the closer you already
## are — so it settles you onto a target rather than snapping.
const ASSIST_CONE_DEGREES := 7.5
const ASSIST_PULL := 2.6
const ASSIST_SLOWDOWN := 0.55
const ASSIST_RANGE := 45.0
const AIM_CACHE_SECONDS := 0.06

const NET_TICK := 1.0 / 60.0
const LOOK_SENSITIVITY := 0.0032   # radians per pixel dragged
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.45

# Packed into a single int for the state RPC.
## Position updates per second. These packets are tiny and this is a LAN game,
## so paying for 60 buys visibly smoother enemies than 30 did.
const F_ALIVE := 1
const F_RINGING := 2
const F_MOVING := 4
const F_CROUCH := 8

@export var peer_id := 1
@export var is_bot := false
@export var case_color := Color(0.09, 0.09, 0.12)
@export var character_index := 0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var phone = $Head/Camera/Phone

# --- input, written by the HUD (touch) or read from the keyboard (desktop) ---
var input_move := Vector2.ZERO   ## x = strafe, y = forward
var input_look := Vector2.ZERO   ## accumulated drag in pixels, consumed each frame
var input_jump := false
var input_sprint := false
var input_crouch := false
## Set by the HUD: assist only applies on touch, where it earns its keep.
var aim_assist := false

# --- state ---
var alive := true
var health := MAX_HEALTH
var yaw := 0.0
var pitch := 0.0
var mode := 0                    ## 0 zap, 1 track, 2 call — drives the screen glow
var is_local := false

var ring_until := 0.0
var call_immune_until := 0.0
var caller_id := 0

var _net_accum := 0.0
var _remote_pos := Vector3.ZERO
var _remote_yaw := 0.0
var _remote_pitch := 0.0
var _remote_ring_sound := 0.0
var _body_root: Node3D
var _screen_mat: StandardMaterial3D
var _ice_root: Node3D
var _ice_mat: StandardMaterial3D
var _ice_amount := 0.0
var _call_live := false
var _bob_phase := 0.0
var _land_dip := 0.0
var _fall_speed := 0.0
var _was_on_floor := true
var _shake := 0.0
var _base_fov := 78.0
var _rig: Node3D
var _step_phase := 0.0
var _visual_speed := 0.0
var _prev_body_pos := Vector3.ZERO
var _aim_cache: Dictionary = {}
var _crouch := 0.0
@onready var _collision: CollisionShape3D = $Collision


## Called by world.gd right after authority is assigned.
func setup() -> void:
	# A bot is simulated by the host but is nobody's point of view.
	is_local = is_multiplayer_authority() and not is_bot
	_remote_pos = global_position
	yaw = rotation.y
	_remote_yaw = yaw

	# The capsule is a sub-resource of the scene, so every player shares one
	# instance. Without this copy, one person crouching would shrink everybody.
	_collision.shape = _collision.shape.duplicate()

	_build_body()
	camera.current = is_local
	phone.player = self
	phone.setup(is_local, is_bot)

	# Your own body would fill your screen, so the local player only renders
	# the viewmodel. Everyone else gets the full body and no viewmodel.
	_body_root.visible = not is_local
	set_physics_process(is_multiplayer_authority())

	if is_bot:
		add_child(load("res://scripts/bot.gd").new())
	if is_local:
		Sfx.play("spawn", -6.0)


## True when this device decides what this body does — you, or a bot the host
## is simulating. Everyone else is watching a networked copy.
func owns_input() -> bool:
	return is_local or is_bot


## One-shot camera kick. Small for your own shots, big for taking a hit.
func add_shake(amount: float) -> void:
	_shake = minf(1.0, _shake + amount)


func _process(delta: float) -> void:
	if is_local:
		_apply_look(delta)
		_update_camera(delta)
	elif not is_bot:
		# Bots are simulated here, not received, so they must not be smoothed
		# toward a network position that nobody is sending.
		_interpolate_remote(delta)
		_remote_ring_feedback(delta)
	_update_crouch(delta)
	_update_screen_glow()
	_update_ice(delta)
	if _body_root != null and _body_root.visible:
		_animate_body(delta)


func _physics_process(delta: float) -> void:
	if not owns_input():
		return
	_read_desktop_input()
	_move(delta)

	_net_accum += delta
	if _net_accum >= NET_TICK:
		_net_accum = 0.0
		_net_state.rpc(global_position, yaw, pitch, _pack_flags())

	# Watch for the edge when the ring expires. Testing `is_ringing() and past
	# the deadline` is a contradiction that can never fire, which used to leave
	# the ringtone looping forever.
	if _call_live and not is_ringing():
		_call_live = false
		_end_call()


# ---------------------------------------------------------------------------
# Movement & look
# ---------------------------------------------------------------------------

func _read_desktop_input() -> void:
	if not is_local or OS.has_feature("mobile") or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	var m := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): m.y += 1.0
	if Input.is_key_pressed(KEY_S): m.y -= 1.0
	if Input.is_key_pressed(KEY_D): m.x += 1.0
	if Input.is_key_pressed(KEY_A): m.x -= 1.0
	input_move = m.limit_length(1.0)
	input_sprint = Input.is_key_pressed(KEY_SHIFT)
	input_crouch = Input.is_key_pressed(KEY_C) or Input.is_key_pressed(KEY_CTRL)
	if Input.is_key_pressed(KEY_SPACE):
		input_jump = true


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		input_look += event.relative * (MOUSE_SENSITIVITY / LOOK_SENSITIVITY)


func _apply_look(delta: float) -> void:
	if not alive:
		input_look = Vector2.ZERO
		return

	var target = aim_target(ASSIST_CONE_DEGREES) if aim_assist else null

	if input_look != Vector2.ZERO:
		var mult := RING_LOOK_MULT if is_ringing() else 1.0
		mult *= float(Settings.look_sensitivity)
		if target != null:
			mult *= ASSIST_SLOWDOWN   # drag slows while crossing a target
		yaw -= input_look.x * LOOK_SENSITIVITY * mult
		pitch = clampf(pitch - input_look.y * LOOK_SENSITIVITY * mult, -PITCH_LIMIT, PITCH_LIMIT)
		input_look = Vector2.ZERO

	if target != null:
		_pull_toward(target, delta)

	rotation.y = yaw
	head.rotation.x = pitch


func _pull_toward(target, delta: float) -> void:
	var eye := camera.global_position
	var offset: Vector3 = (target.global_position + Vector3(0, 1.1, 0)) - eye
	var flat := Vector2(offset.x, offset.z).length()
	if flat < 0.2:
		return
	var want_yaw := atan2(-offset.x, -offset.z)
	var want_pitch := atan2(offset.y, flat)

	# Strongest at the edge of the cone, fading to nothing once you're on them,
	# so it never fights you for the last few pixels.
	var error := absf(angle_difference(yaw, want_yaw))
	var strength: float = clampf(1.0 - error / deg_to_rad(ASSIST_CONE_DEGREES), 0.0, 1.0)
	var t: float = minf(1.0, delta * ASSIST_PULL * strength)
	yaw = lerp_angle(yaw, want_yaw, t)
	pitch = clampf(lerpf(pitch, want_pitch, t), -PITCH_LIMIT, PITCH_LIMIT)


## Nearest living enemy inside `cone_degrees` of where you're looking, with a
## clear line of sight. Used by both aim assist and auto-fire.
##
## Cached for a few frames: this raycasts once per candidate, and at 120Hz with
## eight players that was several hundred raycasts a second for a result that
## cannot meaningfully change in 60ms.
func aim_target(cone_degrees: float):
	var now := _now()
	var cached = _aim_cache.get(cone_degrees)
	if cached != null and now - float(cached["at"]) < AIM_CACHE_SECONDS:
		var who = cached["who"]
		if who == null or (is_instance_valid(who) and who.alive):
			return who
	var found = _find_aim_target(cone_degrees)
	_aim_cache[cone_degrees] = {"who": found, "at": now}
	return found


func _find_aim_target(cone_degrees: float):
	if not alive or Net.world == null or camera == null:
		return null
	var eye := camera.global_position
	var forward := -camera.global_transform.basis.z
	var limit := cos(deg_to_rad(cone_degrees))

	var best = null
	var best_distance := INF
	for other in Net.world.all_players():
		if other == self or not other.alive:
			continue
		var offset: Vector3 = (other.global_position + Vector3(0, 1.1, 0)) - eye
		var distance := offset.length()
		if distance > ASSIST_RANGE or distance < 0.3:
			continue
		if forward.dot(offset / distance) < limit:
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, eye + offset, 1, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			continue   # wall in the way
		if distance < best_distance:
			best_distance = distance
			best = other
	return best


## Head bob, landing dip, sprint FOV and shake, all applied to the camera's
## local transform so nothing here fights the look angles on the head above it.
func _update_camera(delta: float) -> void:
	var speed := horizontal_speed()
	var grounded := is_on_floor()

	if grounded and speed > 0.5:
		_bob_phase += delta * BOB_FREQUENCY * clampf(speed / SPEED, 0.4, 1.6)
	else:
		_bob_phase += delta * 1.2   # idle breathing, much slower

	var amount: float = BOB_AMOUNT * clampf(speed / SPEED, 0.12, 1.5)
	_land_dip = move_toward(_land_dip, 0.0, delta * 0.75)
	_shake = maxf(0.0, _shake - delta * SHAKE_DECAY)

	var shake_offset := Vector3.ZERO
	if _shake > 0.001:
		var s: float = _shake * _shake * 0.05
		shake_offset = Vector3(randf_range(-s, s), randf_range(-s, s), 0.0)

	camera.position.x = cos(_bob_phase) * amount * 0.55 + shake_offset.x
	camera.position.y = sin(_bob_phase * 2.0) * amount - _land_dip + shake_offset.y
	camera.rotation.z = cos(_bob_phase) * amount * 0.28 + _shake * randf_range(-0.02, 0.02)

	var sprinting: bool = input_sprint and speed > SPEED * 0.92 and grounded
	var want_fov: float = _base_fov + (SPRINT_FOV_KICK if sprinting else 0.0)
	camera.fov = lerpf(camera.fov, want_fov, minf(1.0, delta * 7.0))


func _move(delta: float) -> void:
	if not alive:
		velocity = Vector3.ZERO
		input_jump = false
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif input_jump:
		velocity.y = JUMP_VELOCITY
	input_jump = false

	var speed := SPRINT_SPEED if (input_sprint and input_move.y > 0.1 and not input_crouch) else SPEED
	if input_crouch:
		speed *= CROUCH_SPEED_MULT
	if is_ringing():
		speed *= RING_SPEED_MULT

	var basis_dir := (transform.basis * Vector3(input_move.x, 0.0, -input_move.y))
	basis_dir.y = 0.0
	var wish := basis_dir.normalized() * speed * minf(input_move.length(), 1.0)

	var a := ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, wish.x, a * delta * 4.0)
	velocity.z = move_toward(velocity.z, wish.z, a * delta * 4.0)

	_fall_speed = velocity.y
	move_and_slide()

	# Landing dip, scaled by how hard you came down.
	var grounded := is_on_floor()
	if grounded and not _was_on_floor and _fall_speed < -2.0:
		_land_dip = clampf(-_fall_speed * 0.019, 0.02, LAND_DIP_MAX)
		if is_local and _fall_speed < -7.0:
			add_shake(0.22)
	_was_on_floor = grounded

	# Fell out of the world somehow.
	if global_position.y < -12.0:
		global_position = Vector3(0, 2, 8)
		velocity = Vector3.ZERO


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# ---------------------------------------------------------------------------
# Being called
# ---------------------------------------------------------------------------

func is_ringing() -> bool:
	return _now() < ring_until


func is_busy() -> bool:
	return is_ringing()


func can_be_called() -> bool:
	return alive and not is_ringing() and _now() >= call_immune_until


## Sent by the caller directly to the victim's own device.
@rpc("any_peer", "call_remote", "reliable")
func receive_call(from_id: int) -> void:
	if not owns_input() or not can_be_called():
		return
	caller_id = from_id
	ring_until = _now() + RING_DURATION
	_call_live = true
	if is_local:
		Sfx.start_ringing()
	call_started.emit(from_id)


func _end_call() -> void:
	ring_until = 0.0
	call_immune_until = _now() + CALL_IMMUNITY
	if is_local:
		Sfx.stop_ringing()
	call_ended.emit()


@rpc("any_peer", "call_remote", "reliable")
func receive_scan(from_id: int) -> void:
	if not owns_input():
		return
	if is_local:
		Sfx.play("scanned", -7.0)
	was_scanned.emit(from_id)


# ---------------------------------------------------------------------------
# Damage, death, respawn (driven by the host through Net)
# ---------------------------------------------------------------------------

func on_health_changed(hp: float, attacker_id: int) -> void:
	var lost := hp < health
	health = hp
	if not lost:
		return
	if is_local:
		Sfx.play("hit", -7.0)
		add_shake(0.45)
		took_damage.emit(attacker_id)
	if attacker_id == Net.my_id() and not is_local:
		# We're the shooter watching someone else's health drop.
		var shooter = Net.world.local_player() if Net.world else null
		if shooter:
			shooter.hit_confirmed.emit()
			Sfx.play("hitmark", -8.0)


func on_died(killer_id: int) -> void:
	alive = false
	velocity = Vector3.ZERO
	ring_until = 0.0
	_call_live = false
	_ice_amount = 0.0
	_body_root.visible = false
	if is_local:
		Sfx.stop_ringing()
		Sfx.play("death", -6.0)
		add_shake(0.8)
		# Drop and roll the view so being killed is felt, not just displayed.
		var fall := create_tween()
		fall.set_parallel(true)
		fall.tween_property(head, "position:y", 0.42, 0.55).set_ease(Tween.EASE_OUT)
		fall.tween_property(head, "rotation:z", deg_to_rad(24.0), 0.55).set_ease(Tween.EASE_OUT)
		died.emit(killer_id)


func on_respawn(pos: Vector3) -> void:
	alive = true
	health = MAX_HEALTH
	global_position = pos
	_remote_pos = pos
	velocity = Vector3.ZERO
	call_immune_until = _now() + 2.0
	_body_root.visible = not is_local
	if is_local:
		head.position.y = 1.62
		head.rotation.z = 0.0
		camera.position = Vector3.ZERO
		camera.rotation.z = 0.0
		_shake = 0.0
		_land_dip = 0.0
		# Face roughly toward the middle of the lot so you're not staring at a wall.
		yaw = atan2(-pos.x, -pos.z)
		rotation.y = yaw
		Sfx.play("spawn", -6.0)
		respawned.emit()


# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

func _pack_flags() -> int:
	var f := 0
	if alive: f |= F_ALIVE
	if is_ringing(): f |= F_RINGING
	if horizontal_speed() > 0.6: f |= F_MOVING
	if input_crouch: f |= F_CROUCH
	return f | (mode << 4)


@rpc("authority", "call_remote", "unreliable_ordered")
func _net_state(pos: Vector3, y: float, p: float, flags: int) -> void:
	_remote_pos = pos
	_remote_yaw = y
	_remote_pitch = p
	var was_alive := alive
	alive = bool(flags & F_ALIVE)
	ring_until = _now() + 1.0 if (flags & F_RINGING) else 0.0
	input_crouch = bool(flags & F_CROUCH)
	mode = (flags >> 4) & 3
	if _body_root:
		_body_root.visible = alive
	if was_alive and not alive:
		_remote_ring_sound = 0.0


func _interpolate_remote(delta: float) -> void:
	# Snap on big jumps (respawn), smooth otherwise. The exponential form is
	# properly framerate independent, unlike a raw delta * k factor.
	if global_position.distance_to(_remote_pos) > 6.0:
		global_position = _remote_pos
		rotation.y = _remote_yaw
		head.rotation.x = _remote_pitch
		return
	var t: float = 1.0 - exp(-28.0 * delta)
	global_position = global_position.lerp(_remote_pos, t)
	rotation.y = lerp_angle(rotation.y, _remote_yaw, t)
	head.rotation.x = lerp_angle(head.rotation.x, _remote_pitch, t)


## A ringing phone is loud. If you hear one nearby, someone just got called and
## they're standing right there.
func _remote_ring_feedback(delta: float) -> void:
	if not is_ringing() or not alive:
		return
	_remote_ring_sound -= delta
	if _remote_ring_sound <= 0.0:
		_remote_ring_sound = 1.0
		Sfx.play_at("ring", Net.world, global_position, -11.0, 28.0)


# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

func team_color() -> Color:
	# Stable per-peer colour so you can tell people apart at a glance.
	var hues: Array[float] = [0.02, 0.55, 0.28, 0.12, 0.78, 0.42, 0.90, 0.66]
	return Color.from_hsv(hues[peer_id % hues.size()], 0.62, 0.95)


func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)

	var rig := CharacterBuilder.build(Characters.get_entry(character_index), false)
	_body_root.add_child(rig)
	_rig = rig
	_prev_body_pos = global_position

	# The phone they're holding, in the right hand where you'd actually hold it.
	# Its screen glows, which is the single most useful tell on the map: a
	# floating patch of light at chest height is a person.
	var mount: Node3D = rig.get_node_or_null("ArmR/Elbow/HandR")
	if mount == null:
		mount = _body_root

	var shell := MeshInstance3D.new()
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(0.078, 0.155, 0.014)
	shell.mesh = shell_mesh
	shell.material_override = _mat_flat(case_color)
	shell.position = Vector3(0.0, -0.10, -0.055)
	shell.rotation_degrees = Vector3(-62, 0, 0)
	mount.add_child(shell)

	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_color = Color(0.9, 0.95, 1.0)
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(1, 1, 1)
	_screen_mat.emission_energy_multiplier = 2.0

	var screen := MeshInstance3D.new()
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(0.066, 0.138, 0.004)
	screen.mesh = screen_mesh
	screen.material_override = _screen_mat
	screen.position = Vector3(0, 0, -0.010)
	shell.add_child(screen)

	_build_ice()


## Ice that grows over anyone whose phone is going off. It's the only way to
## tell from across the lot that a call has actually landed — before this the
## mechanic worked but was completely invisible.
func _build_ice() -> void:
	_ice_root = Node3D.new()
	_ice_root.name = "Ice"
	_ice_root.visible = false
	_body_root.add_child(_ice_root)

	_ice_mat = StandardMaterial3D.new()
	_ice_mat.albedo_color = Color(0.60, 0.86, 1.0, 0.0)
	_ice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ice_mat.emission_enabled = true
	_ice_mat.emission = Color(0.45, 0.80, 1.0)
	_ice_mat.emission_energy_multiplier = 0.8
	_ice_mat.roughness = 0.08
	_ice_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var block := MeshInstance3D.new()
	var block_mesh := BoxMesh.new()
	block_mesh.size = Vector3(0.92, 1.98, 0.92)
	block.mesh = block_mesh
	block.material_override = _ice_mat
	block.position = Vector3(0, 0.99, 0)
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ice_root.add_child(block)

	# Shards jutting out, so the silhouette reads as ice and not a glass box.
	var shard_mesh := PrismMesh.new()
	shard_mesh.size = Vector3(0.24, 0.62, 0.24)
	for i in 7:
		var shard := MeshInstance3D.new()
		shard.mesh = shard_mesh
		shard.material_override = _ice_mat
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * float(i) / 7.0
		var height := 0.35 + fmod(float(i) * 0.37, 1.0) * 1.3
		shard.position = Vector3(sin(angle) * 0.44, height, cos(angle) * 0.44)
		shard.rotation_degrees = Vector3(
			rad_to_deg(sin(angle * 2.0)) * 0.35 - 20.0,
			rad_to_deg(angle),
			rad_to_deg(cos(angle * 3.0)) * 0.35)
		_ice_root.add_child(shard)


## Crouch is animated rather than snapped: the capsule, the eyeline and the
## body all ease between the two heights so it reads as ducking rather than
## teleporting. Runs for remote players too, off the networked flag.
func _update_crouch(delta: float) -> void:
	var want := 1.0 if (input_crouch and alive) else 0.0
	if _crouch == want:
		return
	_crouch = move_toward(_crouch, want, delta * CROUCH_LERP)

	var height: float = lerpf(STAND_CAPSULE, CROUCH_CAPSULE, _crouch)
	if _collision != null and _collision.shape is CapsuleShape3D:
		_collision.shape.height = height
		_collision.position.y = height * 0.5
	if is_local:
		head.position.y = lerpf(STAND_EYE, CROUCH_EYE, _crouch)


## Walk and run cycle for anybody whose body you can actually see. Driven by how
## far they've physically moved rather than their velocity, because a remote
## player's position is interpolated rather than simulated and has no velocity
## to read.
func _animate_body(delta: float) -> void:
	if _rig == null:
		return
	var moved := global_position.distance_to(_prev_body_pos)
	_prev_body_pos = global_position
	var instant: float = clampf(moved / maxf(delta, 0.0005), 0.0, SPRINT_SPEED * 1.4)
	_visual_speed = lerpf(_visual_speed, instant, minf(1.0, delta * 9.0))

	var gait: float = clampf(_visual_speed / SPEED, 0.0, 1.4)
	var walking := gait > 0.06
	_step_phase += delta * (5.2 + _visual_speed * 1.25) * (1.0 if walking else 0.25)

	var swing := deg_to_rad(30.0) * gait
	var bend := deg_to_rad(58.0) * gait

	_swing_leg(_rig.get_node_or_null("LegL"), _step_phase, swing, bend)
	_swing_leg(_rig.get_node_or_null("LegR"), _step_phase + PI, swing, bend)

	# Left arm swings against the legs.
	var arm_l: Node3D = _rig.get_node_or_null("ArmL")
	if arm_l != null:
		arm_l.rotation.x = -sin(_step_phase) * swing * 0.8
		# Negative Z is outward for a left arm. Positive drove it into the ribs.
		arm_l.rotation.z = deg_to_rad(-7.0)
		var elbow_l: Node3D = arm_l.get_node_or_null("Elbow")
		if elbow_l != null:
			elbow_l.rotation.x = deg_to_rad(16.0) + maxf(0.0, sin(_step_phase)) * bend * 0.3

	# Right arm keeps the phone up in front and follows where they're looking,
	# so you can read somebody's aim off their body from across the lot.
	var arm_r: Node3D = _rig.get_node_or_null("ArmR")
	if arm_r != null:
		arm_r.rotation.x = deg_to_rad(54.0) - head.rotation.x * 0.5 + sin(_step_phase) * 0.035 * gait
		arm_r.rotation.z = deg_to_rad(-15.0)
		var elbow_r: Node3D = arm_r.get_node_or_null("Elbow")
		if elbow_r != null:
			elbow_r.rotation.x = deg_to_rad(72.0)

	# Crouch folds the legs and drops the body, so a ducking player is visibly
	# smaller from across the lot and not just shorter in the collision box.
	if _crouch > 0.01:
		for leg_name in ["LegL", "LegR"]:
			var hip: Node3D = _rig.get_node_or_null(leg_name)
			if hip == null:
				continue
			hip.rotation.x += deg_to_rad(34.0) * _crouch
			var knee: Node3D = hip.get_node_or_null("Knee")
			if knee != null:
				knee.rotation.x -= deg_to_rad(66.0) * _crouch

	# Bob, roll and a forward lean that grows with the run.
	_rig.position.y = absf(sin(_step_phase)) * 0.035 * gait - 0.30 * _crouch
	_rig.rotation.z = -sin(_step_phase) * deg_to_rad(2.4) * gait
	_rig.rotation.x = deg_to_rad(5.0) * gait


func _swing_leg(hip, phase: float, swing: float, bend: float) -> void:
	if hip == null:
		return
	hip.rotation.x = sin(phase) * swing
	var knee: Node3D = hip.get_node_or_null("Knee")
	if knee != null:
		# Knees fold backward, so this is negative — the heel comes up behind.
		knee.rotation.x = -maxf(0.0, -sin(phase)) * bend


func _update_ice(delta: float) -> void:
	if _ice_root == null:
		return
	# Full frost while the phone rings. It's the only outward sign that someone
	# is slowed and disarmed, so it needs to be unmistakable from across the lot.
	var target := 1.0 if (alive and is_ringing()) else 0.0
	_ice_amount = move_toward(_ice_amount, target, delta * (7.0 if target > _ice_amount else 3.0))

	_ice_root.visible = _ice_amount > 0.02
	if not _ice_root.visible:
		return

	_ice_mat.albedo_color = Color(0.60, 0.86, 1.0, 0.62 * _ice_amount)
	_ice_mat.emission_energy_multiplier = 0.5 + 1.6 * _ice_amount
	var shimmer := 1.0 + 0.03 * sin(_now() * 9.0)
	_ice_root.scale = Vector3.ONE * (0.55 + 0.45 * _ice_amount) * shimmer
	_ice_root.rotation.y += delta * 0.35


func _update_screen_glow() -> void:
	if _screen_mat == null:
		return
	var c: Color = Phone.MODE_COLORS[clampi(mode, 0, 2)]
	var energy := 2.0
	if is_ringing():
		# Flashing screen while it rings. Extremely visible in the dark.
		c = Color(0.4, 0.9, 1.0)
		energy = 2.0 + 4.0 * (0.5 + 0.5 * sin(_now() * 22.0))
	_screen_mat.emission = c
	_screen_mat.emission_energy_multiplier = energy


func _mat_flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
