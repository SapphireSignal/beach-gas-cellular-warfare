extends Node3D
class_name CharacterRig
## A built character that can move.
##
## Arms are posed with two-bone IK rather than hand-tuned angles: you say "put
## the hand at the mouth" and the shoulder and elbow work themselves out. Hand
## angles were how the arms ended up bending backwards — a sign error in one
## rotation was invisible until you watched somebody drink through their
## shoulder blade.
##
## Idle is off by default. In a match the body is driven by the game and a
## second animator fighting it would look wrong.

## Bone lengths, matching what character_builder.gd actually builds.
const UPPER_ARM := 0.28
const FOREARM := 0.32

## Named handles that character_props.gd registers for the behaviour to drive.
var animated: Dictionary = {}
## "smoke", "drink", "eat", "type", "lean", "cats", "draw", "child", "music",
## "sit", or "" for breathing only.
var behaviour := ""
## How far to drop the rig so a seated character lands on the seat.
var seat_height := 0.0
var idle := false

var _t := 0.0
var _smoke_timer := 0.0
var _stroke_timer := 0.0
var _stroke_index := 0

@onready var _head: Node3D = get_node_or_null("Head")
@onready var _arm_l: Node3D = get_node_or_null("ArmL")
@onready var _arm_r: Node3D = get_node_or_null("ArmR")
## Captured after any seated offset has been applied, so breathing nudges the
## head from where it actually is rather than snapping it back to standing.
@onready var _head_rest_y: float = _head.position.y if _head != null else 1.56


func _process(delta: float) -> void:
	if not idle:
		return
	_t += delta
	_breathe()
	match behaviour:
		"smoke": _do_smoke(delta)
		"drink": _do_drink()
		"eat": _do_eat()
		"type": _do_type()
		"lean": _do_lean()
		"cats": _do_cats(delta)
		"draw": _do_draw(delta)
		"child": _do_child()
		"music": _do_music(delta)
		"bong": _do_bong(delta)
		"rock": _do_rock()
		_: _do_sway()


# ---------------------------------------------------------------------------
# Arm IK
# ---------------------------------------------------------------------------

## Which way is "away from the body" for this arm. Rotating +Z swings a limb
## toward +X, which is outward for the right arm and straight into the ribs for
## the left — so every sideways angle has to be mirrored.
func _side(shoulder: Node3D) -> float:
	return 1.0 if shoulder.position.x >= 0.0 else -1.0


## Put a hand at (y, z) in rig space. `outward` is degrees away from the body,
## and is mirrored per arm — positive is always away, whichever side it's on.
func _reach(shoulder: Node3D, y: float, z: float, outward: float) -> void:
	if shoulder == null:
		return
	var elbow: Node3D = shoulder.get_node_or_null("Elbow")
	if elbow == null:
		return

	var to_y := y - shoulder.position.y
	var to_z := z - shoulder.position.z
	var distance: float = clampf(sqrt(to_y * to_y + to_z * to_z), 0.08,
		UPPER_ARM + FOREARM - 0.02)

	# Angle from the arm's rest direction (straight down) to the target.
	var direct := atan2(-to_z, -to_y)
	# Law of cosines for the shoulder offset and the elbow's interior angle.
	var shoulder_offset := acos(clampf(
		(UPPER_ARM * UPPER_ARM + distance * distance - FOREARM * FOREARM)
		/ (2.0 * UPPER_ARM * distance), -1.0, 1.0))
	var interior := acos(clampf(
		(UPPER_ARM * UPPER_ARM + FOREARM * FOREARM - distance * distance)
		/ (2.0 * UPPER_ARM * FOREARM), -1.0, 1.0))

	shoulder.rotation.x = direct - shoulder_offset
	shoulder.rotation.z = deg_to_rad(outward) * _side(shoulder)
	elbow.rotation.x = PI - interior     # positive folds the forearm forward


## Where this character's mouth is, so "raise it to your face" is one call.
func _mouth() -> Vector2:
	return Vector2(_head_rest_y + 0.05, -0.12)


## Arm hanging at the side. `outward` is mirrored like _reach, and the small
## default keeps hands off the hips.
func _rest_arm(shoulder: Node3D, outward := 5.0) -> void:
	if shoulder == null:
		return
	shoulder.rotation.x = deg_to_rad(sin(_t * 1.3) * 4.0)
	shoulder.rotation.z = deg_to_rad(outward) * _side(shoulder)
	var elbow: Node3D = shoulder.get_node_or_null("Elbow")
	if elbow != null:
		elbow.rotation.x = deg_to_rad(12.0 + sin(_t * 1.3 + 0.7) * 5.0)


# ---------------------------------------------------------------------------

func _breathe() -> void:
	if _head == null:
		return
	_head.position.y = _head_rest_y + sin(_t * 1.6) * 0.006
	_head.rotation_degrees.y = sin(_t * 0.5) * 3.5
	_head.rotation_degrees.x = sin(_t * 0.9) * 1.5


func _do_sway() -> void:
	_rest_arm(_arm_l)
	_rest_arm(_arm_r)


## Raise, hold, lower — a slow cycle with a pause at the top.
func _lift(period: float, hold: float) -> float:
	var phase := fmod(_t, period) / period
	if phase < 0.28:
		return smoothstep(0.0, 1.0, phase / 0.28)
	if phase < 0.28 + hold:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (phase - 0.28 - hold) / (0.72 - hold))


## Hand travels from hanging at the hip up to the mouth and back.
func _raise_to_mouth(period: float, hold: float, tilt_head: float) -> float:
	var lift := _lift(period, hold)
	var mouth := _mouth()
	var rest_y: float = _arm_r.position.y - 0.55 if _arm_r != null else 0.9
	var y: float = lerpf(rest_y, mouth.x, lift)
	var z: float = lerpf(0.05, mouth.y, lift)
	_reach(_arm_r, y, z, lerpf(0.0, -20.0, lift))
	if _head != null and tilt_head != 0.0:
		_head.rotation_degrees.x += lift * tilt_head
	_rest_arm(_arm_l)
	return lift


func _do_drink() -> void:
	# Head tips back as the bottle comes up, which is most of what sells it.
	_raise_to_mouth(4.4, 0.24, -16.0)


func _do_eat() -> void:
	_raise_to_mouth(3.0, 0.10, 6.0)


func _do_smoke(delta: float) -> void:
	var lift := _raise_to_mouth(5.2, 0.20, 2.0)
	_smoke_timer -= delta
	var origin: Node3D = animated.get("smoke_origin")
	if origin != null and lift > 0.75 and _smoke_timer <= 0.0:
		_smoke_timer = 0.28
		_puff(origin.global_position, 0.6)


## Jay: notes still orbiting, bong coming up to his mouth, cloud on the exhale.
func _do_bong(delta: float) -> void:
	_orbit_notes()
	if _head != null:
		_head.rotation_degrees.x += sin(_t * 4.2) * 4.0
		_head.rotation_degrees.z = sin(_t * 2.1) * 3.0

	var lift := _raise_to_mouth(6.4, 0.22, -4.0)

	# Ember glows while it's at his lips.
	var ember = animated.get("ember")
	if ember != null:
		ember.emission_energy_multiplier = 0.4 + lift * lift * 7.0

	# The exhale: puffs come from his mouth on the way back down, not from the
	# bong. That's the whole gag.
	_smoke_timer -= delta
	if _head == null or lift > 0.55 or lift < 0.08 or _smoke_timer > 0.0:
		return
	_smoke_timer = 0.16
	_puff(_head.global_transform * Vector3(0, 0.05, -0.16), 0.85)


## One drifting, expanding, fading puff of smoke.
func _puff(at: Vector3, rise: float) -> void:
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.030
	mesh.height = 0.060
	mesh.radial_segments = 7
	mesh.rings = 4
	puff.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86, 0.87, 0.89, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material_override = mat
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(puff)
	puff.global_position = at

	var tween := puff.create_tween()
	tween.set_parallel(true)
	tween.tween_property(puff, "global_position", at + Vector3(
		randf_range(-0.14, 0.14), rise, randf_range(-0.22, -0.06)), 2.5)
	tween.tween_property(puff, "scale", Vector3.ONE * 5.0, 2.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 2.5)
	tween.chain().tween_callback(puff.queue_free)


func _do_type() -> void:
	# Both hands down on the keyboard, fingers rattling.
	# Relative to the head, so it lands on his lap whatever the seat height is.
	# The old absolute figure was computed for a desk that no longer exists.
	var keys_y := _head_rest_y - 0.52
	_reach(_arm_l, keys_y + sin(_t * 12.0) * 0.010, -0.30, -6.0)
	_reach(_arm_r, keys_y + sin(_t * 12.0 + PI) * 0.010, -0.30, -6.0)
	var screens = animated.get("screens")
	if screens != null:
		screens.emission_energy_multiplier = 1.5 + 0.25 * sin(_t * 3.3) + 0.1 * sin(_t * 17.0)


func _do_lean() -> void:
	rotation_degrees.z = -3.0
	_rest_arm(_arm_l, 15.0)
	_rest_arm(_arm_r, 9.0)
	var lamp = animated.get("headlights")
	if lamp != null:
		lamp.emission_energy_multiplier = 3.0 + 1.4 * sin(_t * 1.8)


func _do_cats(delta: float) -> void:
	var cats = animated.get("cats")
	if cats != null:
		for i in cats.size():
			var pivot: Node3D = cats[i]
			pivot.rotation_degrees.y += delta * (14.0 + i * 5.0)
			pivot.position.y = absf(sin(_t * 3.0 + i * 1.7)) * 0.03
	for i in 3:
		var tail: Node3D = animated.get("tail_%d" % i)
		if tail != null:
			tail.rotation_degrees.z = sin(_t * 2.4 + i) * 22.0
	# Reaching down to scratch one behind the ears.
	_reach(_arm_r, 0.62 + sin(_t * 1.1) * 0.05, -0.34, -14.0)
	_rest_arm(_arm_l)


func _do_draw(delta: float) -> void:
	# Brush hand working across the paper on the easel.
	_reach(_arm_r, 1.02 + sin(_t * 3.4) * 0.10, -0.26 + sin(_t * 2.1) * 0.06, 26.0)
	_rest_arm(_arm_l, 9.0)
	if _head != null:
		_head.rotation_degrees.x += 8.0

	var strokes = animated.get("strokes")
	if strokes == null or strokes.is_empty():
		return
	_stroke_timer += delta
	if _stroke_timer > 1.1:
		_stroke_timer = 0.0
		if _stroke_index < strokes.size():
			strokes[_stroke_index].visible = true
			_stroke_index += 1
		else:
			for s in strokes:
				s.visible = false
			_stroke_index = 0


func _do_child() -> void:
	var kid: Node3D = animated.get("kid")
	if kid != null:
		# Two year olds do not stand still.
		kid.position.y = absf(sin(_t * 3.6)) * 0.05
		kid.rotation_degrees.y = -22.0 + sin(_t * 1.5) * 12.0
	# Arm down and out, holding a small hand.
	_reach(_arm_r, 0.95, 0.06, 22.0)
	_rest_arm(_arm_l)


## Rocking chair. The whole rig tips, chair included, pivoting about the floor
## where the runners actually touch.
func _do_rock() -> void:
	var tip := sin(_t * 1.15)
	rotation_degrees.x = tip * 7.5
	position.z = -tip * 0.05
	# Left arm on the armrest, right arm holding her phone up where she can
	# actually look at it — she is not rocking with her hands in her lap.
	_rest_arm(_arm_l, 17.0)
	_reach(_arm_r, _head_rest_y - 0.14 + sin(_t * 0.9) * 0.02, -0.30, -7.0)
	if _head != null:
		_head.rotation_degrees.x += 10.0 - tip * 2.5


func _do_music(_delta: float) -> void:
	# Head nodding on the beat, one hand tapping his thigh.
	if _head != null:
		_head.rotation_degrees.x += sin(_t * 4.2) * 6.0
		_head.rotation_degrees.z = sin(_t * 2.1) * 4.0
	_rest_arm(_arm_l)
	_reach(_arm_r, 0.92 + absf(sin(_t * 4.2)) * 0.05, 0.02, 7.0)
	_orbit_notes()


func _orbit_notes() -> void:
	var notes = animated.get("notes")
	if notes == null:
		return
	for i in notes.size():
		var note: Node3D = notes[i]
		var phase: float = _t * 0.9 + float(i) * (TAU / float(notes.size()))
		var rise: float = fmod(_t * 0.45 + float(i) * 0.31, 1.0)
		note.position = Vector3(sin(phase) * 0.34, _head_rest_y + 0.20 + rise * 0.55,
			cos(phase) * 0.34)
		note.rotation_degrees.y = rad_to_deg(phase) + 40.0
		note.rotation_degrees.z = sin(_t * 3.0 + i) * 18.0
		note.scale = Vector3.ONE * (0.4 + (1.0 - rise) * 0.7)
	var halo = animated.get("halo")
	if halo != null:
		halo.emission_energy_multiplier = 1.4 + 0.7 * sin(_t * 4.2)
