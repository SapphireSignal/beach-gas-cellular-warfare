extends Node
## Practice opponent. Added as a child of a player body the host is simulating.
##
## Deliberately beatable. It aims with a wobble, reacts on a delay, and takes a
## moment to pick up its phone — so it's something to learn the controls
## against, not something to lose to.

const SIGHT_RANGE := 42.0
const PREFERRED_RANGE := 11.0
const RANGE_SLACK := 4.0
const AIM_SPEED := 5.5
const AIM_WOBBLE := 0.075          ## radians of permanent hand-shake
const WOBBLE_INTERVAL := 0.45
const REACTION_DELAY := 0.3        ## must see you this long before firing
const LOSE_INTEREST := 4.0         ## keeps hunting your last known spot
const STUCK_SPEED := 0.6
const STUCK_TIME := 0.7
const UNSTUCK_TIME := 1.1
## Physics runs at 120Hz. Re-deciding who to shoot at that rate would cost a
## raycast per player per tick for a choice that changes maybe twice a second.
const RETARGET_INTERVAL := 0.09

var player
var phone

var _target = null
var _last_seen_at := -99.0
var _last_seen_pos := Vector3.ZERO
var _first_seen_at := -99.0
var _wobble := Vector2.ZERO
var _next_wobble := 0.0
var _strafe := 1.0
var _next_strafe := 0.0
var _stuck_for := 0.0
var _unstuck_until := 0.0
var _unstuck_turn := 1.0
var _next_track := 3.0
var _next_retarget := 0.0
var _next_call := 6.0


func _ready() -> void:
	player = get_parent()
	phone = player.get_node_or_null("Head/Camera/Phone")


func _physics_process(delta: float) -> void:
	if player == null or phone == null:
		return
	if not player.alive:
		return
	var now := _now()

	_acquire_target(now)

	if _target != null and now - _last_seen_at < LOSE_INTEREST:
		_fight(delta, now)
	else:
		_wander(delta, now)

	_detect_stuck(delta, now)


# ---------------------------------------------------------------------------

func _acquire_target(now: float) -> void:
	if now < _next_retarget:
		return
	_next_retarget = now + RETARGET_INTERVAL

	var world = Net.world
	if world == null:
		return

	var best = null
	var best_distance := INF
	for other in world.all_players():
		if other == player or not other.alive:
			continue
		var d: float = player.global_position.distance_to(other.global_position)
		if d < best_distance:
			best_distance = d
			best = other

	if best == null:
		_target = null
		return

	if best != _target:
		_target = best
		_first_seen_at = -99.0

	if best_distance < SIGHT_RANGE and _can_see(best):
		if now - _last_seen_at > 0.6:
			_first_seen_at = now     # re-acquiring costs it a beat
		_last_seen_at = now
		_last_seen_pos = best.global_position
	elif _first_seen_at > 0.0 and now - _last_seen_at > LOSE_INTEREST:
		_first_seen_at = -99.0


func _can_see(other) -> bool:
	var from: Vector3 = player.global_position + Vector3(0, 1.62, 0)
	var to: Vector3 = other.global_position + Vector3(0, 1.1, 0)
	# Mask 1 only: we're asking whether the level is in the way, not other people.
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [player.get_rid()])
	return get_viewport().world_3d.direct_space_state.intersect_ray(query).is_empty()


func _fight(delta: float, now: float) -> void:
	var visible_now := now - _last_seen_at < 0.15
	var aim_at: Vector3 = _last_seen_pos if not visible_now else _target.global_position
	_aim(aim_at + Vector3(0, 1.05, 0), delta, now)

	var offset: Vector3 = aim_at - player.global_position
	offset.y = 0.0
	var distance := offset.length()

	# Hold a middle distance: close in from far, back off when crowded — and
	# break contact entirely while the emitter is cooling, since it has nothing
	# to shoot back with.
	var advance := 0.0
	if phone.is_overheated():
		advance = -1.0
	elif distance > PREFERRED_RANGE + RANGE_SLACK:
		advance = 1.0
	elif distance < PREFERRED_RANGE - RANGE_SLACK:
		advance = -0.8

	if now > _next_strafe:
		_next_strafe = now + randf_range(0.8, 2.0)
		_strafe = [-1.0, 1.0].pick_random()

	_drive(advance, _strafe * 0.75, now)

	# Fires only when it actually has a shot. The overheat rule applies to it
	# too, so it burns itself out if it gets greedy.
	var reacted := now - _first_seen_at >= REACTION_DELAY
	if not visible_now or not reacted:
		return
	if distance < phone.ZAP_RANGE and _roughly_on_target(aim_at):
		phone.try_zap()

	if now > _next_track and distance > 18.0:
		_next_track = now + randf_range(7.0, 12.0)
		phone.try_track()

	if now > _next_call and distance < 30.0:
		_next_call = now + randf_range(14.0, 22.0)
		phone.try_call()


func _wander(delta: float, now: float) -> void:
	# Nothing in sight: drift toward where the target was last seen, or just
	# keep moving so it isn't standing in a corner waiting to be shot.
	if _target != null and _last_seen_at > 0.0:
		var offset: Vector3 = _last_seen_pos - player.global_position
		offset.y = 0.0
		if offset.length() > 2.5:
			_face(offset, delta)
			_drive(1.0, 0.0, now)
			return

	if now > _next_strafe:
		_next_strafe = now + randf_range(1.5, 3.5)
		player.yaw += randf_range(-1.4, 1.4)
		player.rotation.y = player.yaw
	_drive(1.0, 0.0, now)


# ---------------------------------------------------------------------------

func _aim(at: Vector3, delta: float, now: float) -> void:
	if now > _next_wobble:
		_next_wobble = now + WOBBLE_INTERVAL
		_wobble = Vector2(randf_range(-AIM_WOBBLE, AIM_WOBBLE), randf_range(-AIM_WOBBLE, AIM_WOBBLE))

	var eye: Vector3 = player.global_position + Vector3(0, 1.62, 0)
	var offset := at - eye
	var flat := Vector2(offset.x, offset.z).length()

	var want_yaw := atan2(-offset.x, -offset.z) + _wobble.x
	var want_pitch := atan2(offset.y, maxf(flat, 0.01)) + _wobble.y

	var t: float = minf(1.0, delta * AIM_SPEED)
	player.yaw = lerp_angle(player.yaw, want_yaw, t)
	player.pitch = clampf(lerpf(player.pitch, want_pitch, t), -1.4, 1.4)
	player.rotation.y = player.yaw
	player.head.rotation.x = player.pitch


func _face(direction: Vector3, delta: float) -> void:
	var want := atan2(-direction.x, -direction.z)
	player.yaw = lerp_angle(player.yaw, want, minf(1.0, delta * 4.0))
	player.rotation.y = player.yaw


func _roughly_on_target(at: Vector3) -> bool:
	var eye: Vector3 = player.global_position + Vector3(0, 1.62, 0)
	var forward: Vector3 = -player.global_transform.basis.z.rotated(
		player.global_transform.basis.x, player.pitch)
	return forward.dot((at + Vector3(0, 1.05, 0) - eye).normalized()) > 0.985


func _drive(forward: float, strafe: float, now: float) -> void:
	if now < _unstuck_until:
		player.input_move = Vector2(_unstuck_turn, 0.35)
		return
	player.input_move = Vector2(strafe, forward).limit_length(1.0)


## No navmesh here, so instead of pathfinding it notices when it has been
## grinding against a wall and sidesteps for a moment. Cheap and good enough
## for a lot this size.
func _detect_stuck(delta: float, now: float) -> void:
	if now < _unstuck_until:
		return
	if player.input_move.length() > 0.2 and player.horizontal_speed() < STUCK_SPEED:
		_stuck_for += delta
		if _stuck_for > STUCK_TIME:
			_stuck_for = 0.0
			_unstuck_until = now + UNSTUCK_TIME
			_unstuck_turn = [-1.0, 1.0].pick_random()
			player.yaw += _unstuck_turn * randf_range(0.8, 1.8)
			player.rotation.y = player.yaw
	else:
		_stuck_for = 0.0


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
