extends "res://scripts/world.gd"
## Level 3 Parking — deliberately the opposite of Beach Gas.
##
## Beach Gas is wide, lit and open, with one long sightline down the pump lanes.
## This is low, dim and cluttered: a 3.2m ceiling, a grid of pillars you can
## never see past, and a mezzanine deck over a third of it so fights happen on
## two heights at once.
##
## Everything shared — players, materials, builders, merging — comes from
## world.gd. This file is only the shape of the place.
##
## Layout, looking down (X right, Z down), 56 x 44:
##
##   -28 ..................................... +28
## -22  +-------------------------------------+
##      |  ramp up      [ pillar grid ]       |
##      |  ......   [ MEZZANINE over here ]   |
##   0  |  [ core ]                    [ bays ]|
##      |                                     |
## +22  +------[ street opening ]-------------+

const DECK_X := 28.0
const DECK_Z := 22.0
const CEILING := 3.2
const MEZZ_HEIGHT := 3.6      ## floor height of the upper deck
const MEZZ_CEILING := 3.4

## Four down here, three up top, one on the ramp. Spread so nobody drops in
## looking at somebody's back.
const PARKING_SPAWNS: Array[Vector3] = [
	Vector3(-24.0, 0.2, 18.0),
	Vector3(24.0, 0.2, 18.0),
	Vector3(-24.0, 0.2, -18.0),
	Vector3(24.0, 0.2, -2.0),
	Vector3(-8.0, 3.8, -17.0),
	Vector3(8.0, 3.8, -17.0),
	Vector3(0.0, 3.8, -6.0),
	Vector3(-2.0, 0.2, 8.0),
]


func spawn_points() -> Array[Vector3]:
	return PARKING_SPAWNS


## No forecourt, no road in — nothing for traffic to drive to.
func wants_traffic() -> bool:
	return false


# ---------------------------------------------------------------------------

## Indoors: no sun, no sky. All the light is strip lights and the city glow
## coming in through the openings, which is why this map reads so differently
## from the forecourt even though it uses the same materials.
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.040, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.47, 0.60)
	env.ambient_light_energy = 0.85 if Settings.shadows_enabled() else 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.24, 0.32)
	env.fog_density = 0.010          # heavier than outside; concrete haze
	env.fog_sky_affect = 0.0

	env.glow_enabled = Settings.glow_enabled()
	env.glow_intensity = 0.9
	env.glow_bloom = 0.14
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.7)
	for level in range(3, 7):
		env.set_glow_level(level, 0.0)

	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 0.88   # concrete, not colour

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# A single weak directional standing in for daylight leaking in sideways.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14.0, 68.0, 0.0)
	sun.light_color = Color(0.72, 0.80, 1.0)
	sun.light_energy = 0.30
	sun.shadow_enabled = false
	add_child(sun)

	_env = env
	_sun = sun
	Settings.changed.connect(_apply_quality)


func _build_level() -> void:
	_build_deck()
	_build_shell()
	_build_pillars()
	_build_mezzanine()
	_build_ramp()
	_build_core()
	_build_bays()
	_build_clutter()


# ---------------------------------------------------------------------------

func _build_deck() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(DECK_X * 2.0, 1.0, DECK_Z * 2.0), "asphalt").name = "Ground"

	# Bay markings. Two long ranks down the middle, one along each wall.
	for rank in 2:
		var z := -9.0 + rank * 18.0
		for i in 16:
			_flat(Vector3(-24.0 + i * 3.2, 0.02, z), Vector2(0.14, 5.0), "paint")
		_flat(Vector3(0, 0.02, z - 2.6), Vector2(51.0, 0.14), "paint")
	# Directional arrows down the central lane.
	for i in 7:
		var arrow := _flat(Vector3(-21.0 + i * 7.0, 0.02, 0.0), Vector2(0.6, 2.0), "paint")
		arrow.rotation_degrees.y = 0.0
	# Yellow hatching by the core.
	for i in 5:
		var hatch := _flat(Vector3(-15.0 + i * 1.4, 0.02, 6.0), Vector2(0.14, 2.6), "paint_red")
		hatch.rotation_degrees.y = 34.0


func _build_shell() -> void:
	var y := CEILING * 0.5

	# Solid on three sides; the fourth is open to the street behind barriers.
	_box(Vector3(0, y, -DECK_Z), Vector3(DECK_X * 2.0, CEILING, 0.6), "concrete")
	_box(Vector3(-DECK_X, y, 0), Vector3(0.6, CEILING, DECK_Z * 2.0), "concrete")
	_box(Vector3(DECK_X, y, 0), Vector3(0.6, CEILING, DECK_Z * 2.0), "concrete")

	# Street side: waist-high barrier with the ceiling coming down to meet it,
	# so you get a strip of city light and no way out.
	_box(Vector3(0, 0.55, DECK_Z), Vector3(DECK_X * 2.0, 1.1, 0.5), "concrete")
	_box(Vector3(0, CEILING - 0.35, DECK_Z), Vector3(DECK_X * 2.0, 0.7, 0.5), "concrete")
	for i in 15:
		_box(Vector3(-26.0 + i * 3.7, 1.75, DECK_Z), Vector3(0.22, 1.3, 0.4), "metal", false)
	_invisible_wall(Vector3(0, 4.0, DECK_Z + 1.2), Vector3(DECK_X * 2.0, 8.0, 1.0))

	# Ceiling slab and the beams under it.
	_box(Vector3(0, CEILING + 0.25, 0), Vector3(DECK_X * 2.0, 0.5, DECK_Z * 2.0), "trim")
	for i in 8:
		_box(Vector3(-24.5 + i * 7.0, CEILING - 0.18, 0), Vector3(0.6, 0.36, DECK_Z * 2.0),
			"concrete", false)

	# City glow through the opening — an unlit additive strip, no real light.
	_box(Vector3(0, 1.72, DECK_Z - 0.6), Vector3(DECK_X * 2.0, 1.2, 0.06), "shaft", false)


## The defining feature. A regular grid you can never see through, so every
## engagement starts at short range and somebody is always about to appear.
func _build_pillars() -> void:
	for col in 7:
		for row in 4:
			var at := Vector3(-21.0 + col * 7.0, 0, -13.5 + row * 9.0)
			_box(at + Vector3(0, CEILING * 0.5, 0), Vector3(0.9, CEILING, 0.9), "concrete")
			_box(at + Vector3(0, 0.08, 0), Vector3(1.15, 0.16, 1.15), "curb", false)
			# Bay number stencilled at head height, so you can call out positions.
			_box(at + Vector3(0, 1.9, -0.47), Vector3(0.62, 0.44, 0.03), "paint", false)
			_sign_text("%d%s" % [col + 1, char(65 + row)],
				at + Vector3(0, 1.9, -0.50), 0.30, Color(0.10, 0.11, 0.14), 180.0)
			# Strip light on the side of every other pillar.
			if (col + row) % 2 == 0:
				_box(at + Vector3(0, CEILING - 0.45, 0), Vector3(0.30, 0.10, 2.6), "lamp", false)


## Upper deck over the northern third. Half the map has a roof over it and a
## firing position above it.
func _build_mezzanine() -> void:
	var west := -14.0
	var east := 14.0
	var north := -DECK_Z
	var south := -4.0
	var mid_x := (west + east) * 0.5
	var mid_z := (north + south) * 0.5
	var width := east - west
	var depth := south - north

	# Slab, kerb and the underside beams.
	_box(Vector3(mid_x, MEZZ_HEIGHT - 0.2, mid_z), Vector3(width, 0.4, depth), "concrete")
	_box(Vector3(mid_x, MEZZ_HEIGHT + 0.12, south), Vector3(width, 0.24, 0.5), "paint_red", false)
	for i in 5:
		_box(Vector3(west + 1.0 + i * 3.0, MEZZ_HEIGHT - 0.55, mid_z),
			Vector3(0.4, 0.3, depth), "concrete", false)

	# Railing along the open edge — cover you can shoot over, not through.
	_box(Vector3(mid_x, MEZZ_HEIGHT + 0.55, south), Vector3(width, 0.9, 0.16), "metal")
	for i in 10:
		_box(Vector3(west + 0.8 + i * 3.0, MEZZ_HEIGHT + 0.55, south),
			Vector3(0.14, 0.9, 0.22), "metal", false)

	# Upper ceiling and its lights.
	_box(Vector3(mid_x, MEZZ_HEIGHT + MEZZ_CEILING + 0.25, mid_z),
		Vector3(width, 0.5, depth), "trim")
	for i in 3:
		for j in 2:
			_box(Vector3(west + 3.5 + i * 3.5, MEZZ_HEIGHT + MEZZ_CEILING - 0.2,
				north + 4.0 + j * 8.0), Vector3(2.4, 0.09, 0.5), "lamp", false)
	_lamp(Vector3(mid_x, MEZZ_HEIGHT + 2.4, mid_z), Color(0.90, 0.94, 1.0), 4.2, 18.0)

	# Pillars carrying it.
	for col in 3:
		for row in 2:
			var at := Vector3(west + 3.0 + col * 4.0, 0, north + 4.5 + row * 9.0)
			_box(at + Vector3(0, MEZZ_HEIGHT * 0.5, 0), Vector3(0.8, MEZZ_HEIGHT, 0.8), "concrete")
			_box(at + Vector3(0, MEZZ_HEIGHT + MEZZ_CEILING * 0.5, 0),
				Vector3(0.8, MEZZ_CEILING, 0.8), "concrete")

	# Bays and a couple of cars up top.
	for i in 6:
		_flat(Vector3(west + 2.0 + i * 2.4, MEZZ_HEIGHT + 0.02, north + 6.0),
			Vector2(0.14, 4.6), "paint")
	_deck_car(Vector3(-9.0, MEZZ_HEIGHT, -17.5), 2.0, Color(0.16, 0.18, 0.22))
	_deck_car(Vector3(9.5, MEZZ_HEIGHT, -14.0), 178.0, Color(0.62, 0.20, 0.18))


## Two shallow flights up the west side. Wide enough to fight on.
func _build_ramp() -> void:
	var x := -21.0
	var steps := 16
	for i in steps:
		var t := float(i) / float(steps - 1)
		var y: float = MEZZ_HEIGHT * t
		var z: float = 2.0 - t * 14.0
		_box(Vector3(x, y * 0.5, z), Vector3(6.0, maxf(y, 0.12), 0.95), "concrete")
	# Kerbs either side so you can't slide off it.
	for side: float in [-1.0, 1.0]:
		for i in 8:
			var t := float(i) / 7.0
			_box(Vector3(x + side * 3.1, MEZZ_HEIGHT * t + 0.4, 2.0 - t * 14.0),
				Vector3(0.24, 0.8, 1.9), "paint_red", false)
	_box(Vector3(x, MEZZ_HEIGHT + 0.1, -13.0), Vector3(6.0, 0.4, 3.0), "concrete")
	# UP arrow at the bottom.
	var arrow := _flat(Vector3(x, 0.03, 3.4), Vector2(1.0, 2.4), "paint")
	arrow.rotation_degrees.y = 0.0


## Stairwell and lift core: an enclosed room in the middle with two doors, so
## it's a shortcut and a trap at the same time.
func _build_core() -> void:
	var cx := -14.0
	var cz := 8.0
	var y := CEILING * 0.5

	_box(Vector3(cx, y, cz - 3.0), Vector3(8.0, CEILING, 0.35), "wall_dark")
	_box(Vector3(cx, y, cz + 3.0), Vector3(8.0, CEILING, 0.35), "wall_dark")
	_box(Vector3(cx - 4.0, y, cz), Vector3(0.35, CEILING, 6.0), "wall_dark")
	# East side has the doorway.
	_box(Vector3(cx + 4.0, y, cz - 2.0), Vector3(0.35, CEILING, 2.4), "wall_dark")
	_box(Vector3(cx + 4.0, y, cz + 2.4), Vector3(0.35, CEILING, 1.6), "wall_dark")
	_box(Vector3(cx + 4.0, CEILING - 0.4, cz + 0.4), Vector3(0.35, 0.8, 1.6), "wall_dark")
	# And a second doorway on the north wall, so it's never a dead end.
	_box(Vector3(cx - 1.6, y, cz - 3.0), Vector3(4.8, CEILING, 0.4), "wall_dark")

	# Lift doors, call button, and the sign.
	_box(Vector3(cx - 2.0, 1.1, cz + 2.7), Vector3(2.2, 2.2, 0.12), "metal", false)
	_box(Vector3(cx - 2.0, 1.1, cz + 2.62), Vector3(0.06, 2.1, 0.04), "dark_metal", false)
	_box(Vector3(cx - 0.6, 1.2, cz + 2.62), Vector3(0.16, 0.24, 0.05), "sign_cyan", false)
	_box(Vector3(cx - 2.0, 2.5, cz + 2.62), Vector3(0.9, 0.5, 0.05), "sign", false)
	_sign_text("LEVEL 3", Vector3(cx - 2.0, 2.5, cz + 2.70), 0.26, Color(1, 1, 1), 0.0)

	# Interior light, spilling out of both doors.
	_box(Vector3(cx, CEILING - 0.25, cz), Vector3(2.6, 0.09, 0.6), "lamp", false)
	_lamp(Vector3(cx, 2.4, cz), Color(0.86, 0.92, 1.0), 3.0, 9.0)

	# Big painted level number on the outside of the core.
	_box(Vector3(cx + 4.3, 2.1, cz - 6.4), Vector3(0.06, 1.6, 3.2), "paint", false)
	_sign_text("3", Vector3(cx + 4.4, 2.1, cz - 6.4), 1.1, Color(0.12, 0.14, 0.18), 90.0)


## Parked cars. Hard cover at chest height, and roofs you can jump onto.
func _build_bays() -> void:
	var colours := [
		Color(0.72, 0.74, 0.78), Color(0.14, 0.15, 0.18), Color(0.55, 0.16, 0.15),
		Color(0.18, 0.30, 0.58), Color(0.30, 0.40, 0.33), Color(0.68, 0.56, 0.22),
	]
	var slots := [
		[-21.5, -9.0, 0.0], [-14.5, -9.0, 0.0], [-0.5, -9.0, 0.0], [13.0, -9.0, 0.0],
		[20.0, -9.0, 0.0], [-17.5, 9.0, 180.0], [-3.0, 9.0, 180.0], [4.5, 9.0, 180.0],
		[18.0, 9.0, 180.0], [24.5, 9.0, 180.0],
	]
	for i in slots.size():
		var s: Array = slots[i]
		_deck_car(Vector3(s[0], 0, s[1]), s[2], colours[i % colours.size()])


## A car sitting on a given deck height. Reuses the shared builder so it's the
## same vehicle you see on the forecourt.
func _deck_car(at: Vector3, yaw: float, colour: Color) -> void:
	var root := build_car(colour)
	root.position = at
	root.rotation_degrees.y = yaw
	add_child(root)
	_merge_roots.append(root)


func _build_clutter() -> void:
	# Service bay in the north-east corner.
	_box(Vector3(23.0, 1.0, -19.0), Vector3(9.0, 2.0, 0.3), "wall_dark")
	_box(Vector3(18.6, 1.0, -16.0), Vector3(0.3, 2.0, 6.0), "wall_dark")
	_box(Vector3(21.5, 0.7, -17.5), Vector3(2.6, 1.4, 1.8), "hedge")
	_box(Vector3(25.0, 0.6, -17.8), Vector3(1.4, 1.2, 1.4), "stock")
	_box(Vector3(24.5, 1.5, -17.8), Vector3(1.2, 0.6, 1.2), "stock")

	# Trolley bay and stacked pallets mid-floor.
	for i in 4:
		_box(Vector3(6.0 + i * 0.55, 0.55, 15.5), Vector3(0.6, 1.1, 1.0), "metal", false)
	_box(Vector3(6.8, 0.5, 15.5), Vector3(3.2, 1.0, 1.2), "metal")
	_box(Vector3(-6.0, 0.35, 15.0), Vector3(2.4, 0.7, 1.6), "stock")
	_box(Vector3(-6.0, 0.95, 15.0), Vector3(2.2, 0.5, 1.5), "stock")

	# Payment machines against the west wall.
	for i in 2:
		_box(Vector3(-26.5, 0.85, -4.0 + i * 3.0), Vector3(0.7, 1.7, 1.0), "dark_metal")
		_box(Vector3(-26.05, 1.35, -4.0 + i * 3.0), Vector3(0.06, 0.5, 0.6), "sign_cyan", false)

	# A few dead strip lights, so the ceiling isn't uniform.
	for at: Vector3 in [Vector3(-10.0, 0, 4.0), Vector3(12.0, 0, -4.0), Vector3(20.0, 0, 12.0)]:
		_box(at + Vector3(0, CEILING - 0.22, 0), Vector3(3.0, 0.10, 0.4), "metal", false)

	# Real lights, kept few. Emissive strips do the rest of the work.
	_lamp(Vector3(-16.0, CEILING - 0.5, -6.0), Color(0.88, 0.93, 1.0), 3.6, 17.0)
	_lamp(Vector3(6.0, CEILING - 0.5, -6.0), Color(0.88, 0.93, 1.0), 3.6, 17.0)
	_lamp(Vector3(-8.0, CEILING - 0.5, 12.0), Color(0.88, 0.93, 1.0), 3.4, 16.0)
	_lamp(Vector3(16.0, CEILING - 0.5, 10.0), Color(0.90, 0.86, 0.78), 3.2, 15.0)
