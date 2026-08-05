extends "res://scripts/world.gd"
## Beach Gas as it actually is — built from photographs of Jay's station rather
## than invented.
##
## The other Beach Gas map is a fiction: a night forecourt with a canopy, a
## twelve-lamp lot and a city street. The real place is nothing like it. It's a
## bright gravel clearing cut out of forest, one road past the front, a small
## white store, a wood cabin next door, four pumps and two tanks. No canopy, no
## kerbs, no tarmac, no neighbours.
##
## That difference is the point as a map. Beach Gas is a night fight with cover
## and corners; this is daylight and open ground where the only real cover is
## the buildings and the pump islands, so fights are longer-range and you get
## seen crossing.
##
## Layout, looking down (X right, Z down), 76 x 60:
##
##   -38 ......................................... +38
## -30  #########  forest all the way round  #########
##      #                                           #
##      #   [ TANKS ]      [ STORE ][ SUMMERLEAF ]  #
##      #                                           #
##   0  #            [pumps]    [pumps]             #
##      #                                           #
##      #                    [ pylon sign ]         #
## +26  ============ road across the front ==========
##
## Kept deliberately flat: the real site is flat, and the fight reads better for
## it. The buildings are the only thing that breaks a sightline.

const SITE_X := 38.0
const SITE_Z := 26.0
const ROAD_Z := 30.0

## Wide apart and mostly behind cover, because there is very little of it here.
## Two by the buildings, two by the tanks, two at the pumps, two at the road.
const REAL_SPAWNS: Array[Vector3] = [
	Vector3(-30.0, 0.2, -20.0),
	Vector3(-4.0, 0.2, -22.0),
	Vector3(14.0, 0.2, -20.0),
	Vector3(30.0, 0.2, -14.0),
	Vector3(-30.0, 0.2, 6.0),
	Vector3(30.0, 0.2, 8.0),
	Vector3(-16.0, 0.2, 20.0),
	Vector3(18.0, 0.2, 20.0),
]


func spawn_points() -> Array[Vector3]:
	return REAL_SPAWNS


func wants_traffic() -> bool:
	return true


## Cars on the real road, and two of them pull in to the pumps.
##
## Index 3 is always where a car stops — that is traffic.gd's contract. The two
## drive-through routes put their stop out past the tree line so the pause
## happens off the lot rather than in the middle of the road.
func traffic_routes() -> Array:
	return [
		# Pulls in from the east, stops at the east island, leaves west.
		[Vector3(48, 0, 31), Vector3(18, 0, 30), Vector3(14, 0, 8),
			Vector3(14, 0, 0), Vector3(14, 0, -8), Vector3(-26, 0, -10),
			Vector3(-48, 0, 24)],
		# Pulls in from the west, stops at the west island, leaves east.
		[Vector3(-48, 0, 31), Vector3(-18, 0, 30), Vector3(-14, 0, 8),
			Vector3(-14, 0, 0), Vector3(-14, 0, -8), Vector3(26, 0, -10),
			Vector3(48, 0, 24)],
		# Straight through, west to east. Stop sits at x = -44, out in the trees.
		[Vector3(-54, 0, 31.5), Vector3(-50, 0, 31.5), Vector3(-47, 0, 31.5),
			Vector3(-44, 0, 31.5), Vector3(-10, 0, 31.5), Vector3(20, 0, 31.5),
			Vector3(54, 0, 31.5)],
		# Straight through, east to west, on the other side of the line.
		[Vector3(54, 0, 28.5), Vector3(50, 0, 28.5), Vector3(47, 0, 28.5),
			Vector3(44, 0, 28.5), Vector3(10, 0, 28.5), Vector3(-20, 0, 28.5),
			Vector3(-54, 0, 28.5)],
	]


## Daylight on white gravel is its own light source. The night map lifts ambient
## to 1.05/1.20 to stop players vanishing at the lot edges; here the ground is
## bouncing light everywhere and that much would blow the whole map out.
func _ambient_for(shadows: bool) -> float:
	return 0.62 if shadows else 0.74


func _wants_sun_shadows() -> bool:
	return Settings.shadows_enabled()


func _build_level() -> void:
	_daylight()
	_gravel_lot()
	_forest_ring()
	_road()
	_store()
	_summerleaf()
	_pump_islands()
	_fuel_tanks()
	_lot_poles()
	_pylon_sign()
	_yard_clutter()


# ---------------------------------------------------------------------------
# Sky and ground
# ---------------------------------------------------------------------------

## Hard blue midday sky, which is how every photo of the place looks. Overrides
## the dusk environment world.gd builds by default.
func _daylight() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Palette.DAY_SKY_TOP
	sky_mat.sky_horizon_color = Palette.DAY_SKY_HORIZON
	sky_mat.ground_horizon_color = Palette.DAY_SKY_HORIZON
	sky_mat.ground_bottom_color = Palette.FOREST_DARK
	sky_mat.sun_angle_max = 18.0
	sky_mat.energy_multiplier = 1.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	if _env != null:
		_env.sky = sky
		_env.fog_enabled = true
		# Very light haze, and only far away — it separates the forest from the
		# lot without putting mist on a sunny day.
		_env.fog_light_color = Palette.DAY_SKY_HORIZON
		_env.fog_density = 0.0016
		_env.fog_sky_affect = 0.1
	if _sun != null:
		_sun.light_color = Palette.DAY_SUN
		_sun.light_energy = 1.15
		_sun.rotation_degrees = Vector3(-52.0, 38.0, 0.0)


func _gravel_lot() -> void:
	# A solid slab, not a _flat(). _flat builds a visual plane with no collision;
	# the floor every other map stands on comes from _build_ground(), which this
	# map's _build_level() override never calls. Without this there is literally
	# nothing under the player and you fall out of the world.
	#
	# Oversized past the tree line so nobody can reach an edge of it.
	_box(Vector3(0, -0.5, 0),
		Vector3(SITE_X * 2.4, 1.0, (SITE_Z + ROAD_Z) * 1.4), "gravel").name = "Ground"


## The road runs past the front, raised barely off the gravel. Two lanes with a
## painted centre line — the yellow one in the aerial shots.
func _road() -> void:
	_flat(Vector3(0, 0.02, ROAD_Z), Vector2(SITE_X * 2.2, 9.0), "asphalt")
	for i in 26:
		# Dashes rather than a solid line; a solid one reads as a wall from a
		# distance on a surface this flat.
		_box(Vector3(-34.0 + i * 2.8, 0.04, ROAD_Z), Vector3(1.4, 0.02, 0.18),
			"paint", false)


# ---------------------------------------------------------------------------
# Forest
# ---------------------------------------------------------------------------

## The clearing is surrounded on every side except the road. Trees are the map
## boundary as well as the look — an invisible wall behind them stops anyone
## walking into the woods.
func _forest_ring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBEACA5      # same trees every time, so the map is learnable

	var edges: Array = [
		[Vector3(-SITE_X - 3.0, 0, 0), Vector3(0, 0, 1), 22],   # west
		[Vector3(SITE_X + 3.0, 0, 0), Vector3(0, 0, 1), 22],    # east
		[Vector3(0, 0, -SITE_Z - 3.0), Vector3(1, 0, 0), 28],   # north
	]
	for edge in edges:
		var origin: Vector3 = edge[0]
		var along: Vector3 = edge[1]
		var count: int = edge[2]
		var span: float = (SITE_Z + 6.0) if along.z > 0.5 else (SITE_X + 6.0)
		for i in count:
			var t := (float(i) / float(count - 1) - 0.5) * 2.0 * span
			# Two staggered rows, so you can't see daylight between trunks.
			for row in 2:
				var jitter := Vector3(rng.randf_range(-2.2, 2.2), 0.0,
					rng.randf_range(-2.2, 2.2))
				var out := (Vector3(1, 0, 0) if along.z > 0.5 else Vector3(0, 0, 1))
				var sign_out: float = signf(origin.x if along.z > 0.5 else origin.z)
				_tree(origin + along * t + out * sign_out * (row * 4.0) + jitter,
					rng.randf_range(0.8, 1.35), rng.randf() < 0.4)

	# The road side gets trees behind the road rather than on the lot.
	for i in 24:
		var x := -34.0 + i * 3.0
		_tree(Vector3(x + rng.randf_range(-1.5, 1.5), 0.0,
			ROAD_Z + 7.0 + rng.randf_range(0.0, 4.0)),
			rng.randf_range(0.9, 1.4), rng.randf() < 0.5)

	# Boundary. Behind the first row of trunks so it never reads as an invisible
	# wall in open ground.
	_invisible_wall(Vector3(-SITE_X - 1.0, 3.0, 0), Vector3(1.0, 6.0, SITE_Z * 2.4))
	_invisible_wall(Vector3(SITE_X + 1.0, 3.0, 0), Vector3(1.0, 6.0, SITE_Z * 2.4))
	_invisible_wall(Vector3(0, 3.0, -SITE_Z - 1.0), Vector3(SITE_X * 2.4, 6.0, 1.0))
	_invisible_wall(Vector3(0, 3.0, ROAD_Z + 5.0), Vector3(SITE_X * 2.4, 6.0, 1.0))


## A conifer: trunk plus three stacked tapering boxes. Cheap, and at the
## distance these are ever seen the silhouette is all that reads. Merged into
## the level, so a hundred of them still cost one draw call per material.
func _tree(at: Vector3, height_scale: float, pale: bool) -> void:
	var h := 7.0 * height_scale
	_box(at + Vector3(0, h * 0.28, 0), Vector3(0.42, h * 0.56, 0.42), "trunk")
	var key := "forest_light" if pale else "forest_dark"
	for i in 3:
		var f := float(i) / 3.0
		var w := (3.4 - f * 1.9) * height_scale
		_box(at + Vector3(0, h * (0.42 + f * 0.26), 0),
			Vector3(w, h * 0.30, w), key, i == 0)


# ---------------------------------------------------------------------------
# The store
# ---------------------------------------------------------------------------

## White board-and-batten under a black gable, facing the pumps. The round sign,
## the two gooseneck lamps and the string lights are all straight off the
## photographs — they're what makes it recognisably this building rather than a
## generic white shed.
func _store() -> void:
	var at := Vector3(-15.0, 0.0, -17.0)
	var w := 13.0
	var d := 9.0
	var wall_h := 4.0
	var face := at.z + d * 0.5
	var door_x := at.x + 3.6
	# Wide. A 2.2m opening was tight enough that walking in caught the jamb, and
	# a shop you bounce off isn't a shop.
	var door_w := 3.0

	# Walk-in, not a solid block. Four walls with a gap for the door, so the
	# inside is a real room you can be fought in — the counter and the cooler
	# aisle are the only cover on this half of the map.
	_box(Vector3(at.x, 0.05, at.z), Vector3(w, 0.1, d), "concrete")
	_box(Vector3(at.x, wall_h * 0.5, at.z - d * 0.5), Vector3(w, wall_h, 0.3),
		"store_white")                                            # back
	_box(Vector3(at.x - w * 0.5, wall_h * 0.5, at.z), Vector3(0.3, wall_h, d),
		"store_white")                                            # left
	_box(Vector3(at.x + w * 0.5, wall_h * 0.5, at.z), Vector3(0.3, wall_h, d),
		"store_white")                                            # right

	# Front, in two pieces either side of the doorway.
	var left_w: float = (door_x - door_w * 0.5) - (at.x - w * 0.5)
	_box(Vector3(at.x - w * 0.5 + left_w * 0.5, wall_h * 0.5, face),
		Vector3(left_w, wall_h, 0.3), "store_white")
	var right_w: float = (at.x + w * 0.5) - (door_x + door_w * 0.5)
	_box(Vector3(at.x + w * 0.5 - right_w * 0.5, wall_h * 0.5, face),
		Vector3(right_w, wall_h, 0.3), "store_white")
	# Lintel over the door, so the gap reads as a doorway rather than a hole.
	_box(Vector3(door_x, wall_h - 0.4, face), Vector3(door_w, 0.8, 0.3),
		"store_white")

	_store_interior(at, w, d)

	# Gable: two slabs leaned together, with the deep front overhang.
	for side in [-1.0, 1.0]:
		var slab := _box(Vector3(at.x, wall_h + 1.05, at.z + side * (d * 0.25 + 0.15)),
			Vector3(w + 0.9, 0.20, d * 0.62), "roof_black", false)
		slab.rotation_degrees = Vector3(side * -22.0, 0, 0)
	_box(Vector3(at.x, wall_h + 1.55, at.z), Vector3(w + 0.5, 0.22, 0.6),
		"roof_black", false)

	var f := face + 0.2
	_beach_gas_disc(Vector3(at.x - 2.2, 2.6, f), 1.9)
	_box(Vector3(at.x - 5.4, 2.4, f), Vector3(2.6, 1.5, 0.10), "glass", false)
	_box(Vector3(at.x - 5.4, 3.3, f + 0.35), Vector3(2.8, 0.12, 0.9), "cedar", false)

	# Gooseneck lamps and string lights. Emissive rather than omni — the eight
	# omni slots are spent on the lot poles.
	for x: float in [at.x - 4.6, at.x - 0.2]:
		_box(Vector3(x, 3.5, f + 0.2), Vector3(0.14, 0.5, 0.14), "dark_metal", false)
		_box(Vector3(x, 3.25, f + 0.45), Vector3(0.5, 0.22, 0.5), "dark_metal", false)
		_box(Vector3(x, 3.12, f + 0.45), Vector3(0.34, 0.06, 0.34), "lamp", false)
	for i in 11:
		var t := float(i) / 10.0
		var sag := sin(t * PI) * 0.35
		_box(Vector3(at.x - w * 0.45 + t * w * 0.9, 4.6 - sag, f + 0.5),
			Vector3(0.10, 0.16, 0.10), "lamp", false)

	# The porch, straight off the photographs.
	_chair(Vector3(at.x - 3.4, 0, f + 1.9), 0.0, "cream")
	_chair(Vector3(at.x - 0.9, 0, f + 1.9), 0.0, "cream")
	_box(Vector3(at.x - 2.15, 0.28, f + 1.9), Vector3(0.5, 0.56, 0.5), "trunk")
	_chair(Vector3(at.x - 8.2, 0, f + 2.4), 22.0, "chair_blue")
	_chair(Vector3(at.x - 6.4, 0, f + 2.6), 12.0, "chair_blue")
	_box(Vector3(at.x - 5.0, 0.35, f + 1.6), Vector3(0.7, 0.7, 0.7), "pot")
	_plant(Vector3(at.x - 5.0, 0.7, f + 1.6), 0.8)
	_boulder(Vector3(at.x - 7.5, 0, f + 4.2), 1.5)
	_boulder(Vector3(at.x + 5.5, 0, f + 3.4), 1.1)
	for x: float in [at.x - 9.2, at.x - 1.6]:
		_box(Vector3(x, 0.7, f + 0.9), Vector3(0.34, 1.4, 0.34), "trunk")
	# Pepsi machine and bin, moved clear of the doorway — they were close enough
	# to it that walking in meant threading between them.
	_box(Vector3(at.x + 8.4, 1.0, f + 0.5), Vector3(1.0, 2.0, 0.8), "sign")
	_box(Vector3(at.x + 7.2, 0.55, f + 1.3), Vector3(0.8, 1.1, 0.8), "dark_metal")

	_propane_and_firewood(Vector3(at.x - w * 0.5 - 4.5, 0.0, at.z + 1.0))


## Inside the shop. Walking in: the slushie and coffee table is on your left, a
## lit drinks cooler beside it, the till is ahead of you a little way back, and
## the cigarette wall is behind the till.
func _store_interior(at: Vector3, w: float, d: float) -> void:
	var left := at.x - w * 0.5 + 1.2
	var back := at.z - d * 0.5 + 0.9

	# Slushie machine and coffee, on a counter down the left wall.
	_box(Vector3(left + 0.4, 0.5, at.z + 1.6), Vector3(1.6, 1.0, 3.4), "shelf")
	for i in 2:
		# Slushie barrels: lit, so they read from the doorway.
		_box(Vector3(left + 0.4, 1.35, at.z + 0.6 + i * 0.9),
			Vector3(0.62, 0.7, 0.62), "cooler", false)
	_box(Vector3(left + 0.4, 1.25, at.z + 2.9), Vector3(0.9, 0.5, 0.7),
		"dark_metal", false)                                   # coffee urns
	_box(Vector3(left + 0.4, 1.6, at.z + 2.9), Vector3(0.7, 0.2, 0.5),
		"metal", false)

	# Drinks cooler beside it — glass front, lit from inside.
	_box(Vector3(left + 0.5, 1.1, at.z - 1.8), Vector3(1.7, 2.2, 2.6), "dark_metal")
	_box(Vector3(left + 1.4, 1.1, at.z - 1.8), Vector3(0.08, 1.9, 2.3),
		"cooler", false)

	# The till, ahead and a little back as you come through the door.
	_box(Vector3(at.x + 2.2, 0.55, back + 2.6), Vector3(3.4, 1.1, 1.0), "shelf")
	_box(Vector3(at.x + 2.2, 1.24, back + 2.6), Vector3(0.7, 0.28, 0.5),
		"dark_metal", false)                                   # register
	_box(Vector3(at.x + 3.4, 1.22, back + 2.6), Vector3(0.4, 0.24, 0.3),
		"sign_white", false)                                   # lit display

	# Cigarette wall behind the till: a grid of packs against the back wall.
	_box(Vector3(at.x + 2.2, 1.9, back + 0.15), Vector3(4.6, 2.6, 0.3), "dark_metal")
	for row in 5:
		for col in 9:
			_box(Vector3(at.x + 2.2 - 2.0 + col * 0.5, 1.05 + row * 0.44,
				back + 0.34), Vector3(0.4, 0.36, 0.12), "stock", false)

	# Candy rack on the right-hand wall as you walk in — tiered, so the rows
	# step forward toward you the way a real one does.
	var right := at.x + w * 0.5 - 0.9
	_box(Vector3(right, 0.75, at.z + 2.4), Vector3(0.5, 1.5, 2.6), "shelf")
	for row in 4:
		_box(Vector3(right - 0.12 - row * 0.05, 0.5 + row * 0.34, at.z + 2.4),
			Vector3(0.34, 0.1, 2.4), "shelf", false)
		for i in 5:
			_box(Vector3(right - 0.14 - row * 0.05, 0.62 + row * 0.34,
				at.z + 1.4 + i * 0.5), Vector3(0.26, 0.22, 0.36),
				"stock", false)

	# A run of shelving down the middle, so the room has cover in it.
	_shelf_run(Vector3(at.x + 1.0, 0.0, at.z + 2.6), 3.4)


## Propane cages and stacked firewood, left of the store. Both are out front in
## every photo, and they double as the only hard cover on that approach.
func _propane_and_firewood(at: Vector3) -> void:
	# Barbecue bottles in a mesh cage. These were far too big before — a 20lb BBQ
	# tank is about 30cm across and 60cm tall, not the oil drums I first built.
	for cage in 2:
		var cz: float = at.z + cage * 1.9
		_box(Vector3(at.x, 0.05, cz), Vector3(1.6, 0.1, 1.6), "concrete")
		# Frame: four uprights and a top rail, left open so the bottles show.
		for ox: float in [-0.75, 0.75]:
			for oz: float in [-0.75, 0.75]:
				_box(Vector3(at.x + ox, 0.62, cz + oz), Vector3(0.07, 1.25, 0.07),
					"metal")
		_box(Vector3(at.x, 1.24, cz), Vector3(1.6, 0.07, 1.6), "metal")
		for bx in 2:
			for bz in 2:
				_box(Vector3(at.x - 0.34 + bx * 0.68, 0.32, cz - 0.34 + bz * 0.68),
					Vector3(0.3, 0.62, 0.3), "tank_white", false)
		# Mesh, faked with thin bars rather than a transparent texture.
		for i in 4:
			_box(Vector3(at.x, 0.62, cz - 0.75 + i * 0.5), Vector3(1.6, 1.25, 0.03),
				"metal", false)

	# Firewood: bundles stacked on a pallet.
	var wz := at.z + 6.0
	_box(Vector3(at.x, 0.08, wz), Vector3(2.6, 0.16, 1.6), "cedar")
	for row in 3:
		for col in 4:
			_box(Vector3(at.x - 0.95 + col * 0.63, 0.32 + row * 0.34, wz),
				Vector3(0.55, 0.32, 1.3), "trunk")


## The round wall sign: orange-red ring, teal disc, cream lettering. Built as
## flat discs rather than a texture so it stays crisp walking right up to it.
func _beach_gas_disc(at: Vector3, radius: float) -> void:
	_disc(at, radius, 0.10, "orange")
	_disc(at + Vector3(0, 0, 0.03), radius * 0.86, 0.08, "cream")
	_disc(at + Vector3(0, 0, 0.06), radius * 0.78, 0.06, "teal")
	_sign_text("Beach", at + Vector3(-0.05, 0.22, 0.12), 0.60, Palette.BEACH_CREAM, 0.0)
	_sign_text("GAS", at + Vector3(0.0, -0.42, 0.12), 0.42, Palette.BEACH_CREAM, 0.0)


## An n-sided prism standing in for a cylinder face-on. Twelve sides is plenty
## at the size these are ever seen and costs a fraction of a real cylinder.
func _disc(at: Vector3, radius: float, thickness: float, mat_key: String) -> void:
	for i in 6:
		var b := _box(at, Vector3(radius * 2.0, radius * 0.55, thickness),
			mat_key, false)
		b.rotation_degrees = Vector3(0, 0, 180.0 * float(i) / 6.0)


func _chair(at: Vector3, yaw: float, mat_key: String) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees = Vector3(0, yaw, 0)
	add_child(root)
	var mat: Material = _mats[mat_key]
	_local_box(root, Vector3(0, 0.42, 0), Vector3(0.78, 0.09, 0.78), mat)
	for x: float in [-0.34, 0.34]:
		_local_box(root, Vector3(x, 0.21, 0.28), Vector3(0.09, 0.42, 0.09), mat)
		_local_box(root, Vector3(x, 0.21, -0.28), Vector3(0.09, 0.42, 0.09), mat)
	var back := _local_box(root, Vector3(0, 0.86, -0.36), Vector3(0.78, 0.85, 0.08), mat)
	back.rotation_degrees = Vector3(-18.0, 0, 0)
	for x: float in [-0.42, 0.42]:
		_local_box(root, Vector3(x, 0.56, 0.10), Vector3(0.08, 0.07, 0.62), mat)


func _boulder(at: Vector3, size: float) -> void:
	var b := _box(at + Vector3(0, size * 0.34, 0),
		Vector3(size * 1.5, size * 0.8, size * 1.2), "curb")
	b.rotation_degrees = Vector3(6.0, 24.0, -4.0)


# ---------------------------------------------------------------------------
# Summerleaf
# ---------------------------------------------------------------------------

## The wood cabin east of the store. Darker, lower and rougher — weathered board
## against the store's fresh white, which is exactly how the two read in the
## photos.
func _summerleaf() -> void:
	var at := Vector3(2.0, 0.0, -17.5)
	var w := 10.0
	var d := 8.0
	var h := 3.4

	var wall_z := at.z + d * 0.5
	var door_w := 3.0

	# Walk-in, like the store. Four walls with a doorway rather than a solid
	# block — verified with tools/check_doors.gd, which is how we found this was
	# still sealed after it was supposed to have been opened up.
	_box(Vector3(at.x, 0.05, at.z), Vector3(w, 0.1, d), "concrete")
	_box(Vector3(at.x, h * 0.5, at.z - d * 0.5), Vector3(w, h, 0.3), "wood")
	_box(Vector3(at.x - w * 0.5, h * 0.5, at.z), Vector3(0.3, h, d), "wood")
	_box(Vector3(at.x + w * 0.5, h * 0.5, at.z), Vector3(0.3, h, d), "wood")

	var seg: float = (w - door_w) * 0.5
	_box(Vector3(at.x - (door_w + seg) * 0.5, h * 0.5, wall_z),
		Vector3(seg, h, 0.3), "wood")
	_box(Vector3(at.x + (door_w + seg) * 0.5, h * 0.5, wall_z),
		Vector3(seg, h, 0.3), "wood")
	# Lintel, high enough to walk under.
	_box(Vector3(at.x, h - 0.3, wall_z), Vector3(door_w, 0.6, 0.3), "wood", false)

	_box(at + Vector3(0, h + 0.12, 0), Vector3(w + 0.8, 0.22, d + 0.8),
		"metal", false)

	_summerleaf_interior(at, w, d)

	var face := wall_z + 0.2
	# Windows either side, the OPEN sign, and the leaf emblem over the door.
	# All non-colliding — a pane of glass you bounce off is not a window.
	_box(Vector3(at.x - 3.4, 2.1, face), Vector3(2.0, 1.3, 0.10), "glass", false)
	_box(Vector3(at.x + 3.4, 2.1, face), Vector3(2.0, 1.3, 0.10), "glass", false)
	_leaf_emblem(Vector3(at.x, 3.0, face + 0.08), 0.9)
	_box(Vector3(at.x + 4.2, 2.6, face + 0.05), Vector3(0.9, 0.4, 0.06),
		"sign", false)

	# Cedar fence. It used to start 0.4m off Summerleaf's west wall and run
	# straight across the front of the STORE's doorway — check_doors.gd caught
	# it as Collision_cedar sitting in the walk-in path. It now stops well short.
	for i in 3:
		_box(Vector3(at.x - w * 0.5 - 1.2 - i * 1.6, 1.0, face + 0.6),
			Vector3(1.5, 2.0, 0.14), "cedar")
	_picnic_table(Vector3(at.x + 6.5, 0, face + 2.2), -14.0)

	# Floaties on a rack beside the bench — they're for sale and they're the
	# brightest thing on this side of the lot, which makes them a landmark.
	var rack := Vector3(at.x + 9.6, 0.0, face + 1.4)
	for post: float in [-0.9, 0.9]:
		_box(rack + Vector3(post, 1.0, 0), Vector3(0.09, 2.0, 0.09), "metal")
	_box(rack + Vector3(0, 2.0, 0), Vector3(1.9, 0.09, 0.09), "metal", false)
	var rings: Array[String] = ["sign", "sign_cyan", "leaf_sign", "grow"]
	for i in 4:
		var ring := rack + Vector3(-0.66 + i * 0.44, 1.35, 0.0)
		# A ring read as a flat torus: four bars round a gap.
		for side in 4:
			var a := TAU * float(side) / 4.0
			_box(ring + Vector3(cos(a) * 0.26, sin(a) * 0.26, 0.0),
				Vector3(0.34, 0.14, 0.14), rings[i], false)


## Inside Summerleaf: plants growing down one wall under the purple lights, and
## jars on the shelving behind the counter. It's a dispensary — the plants and
## the product are the room.
func _summerleaf_interior(at: Vector3, w: float, d: float) -> void:
	var back := at.z - d * 0.5 + 0.8

	# Counter across the back with the jar shelving behind it.
	_box(Vector3(at.x, 0.55, back + 1.4), Vector3(6.0, 1.1, 0.9), "shelf")
	_box(Vector3(at.x, 1.6, back + 0.2), Vector3(6.4, 2.2, 0.3), "wood")
	for row in 3:
		_box(Vector3(at.x, 1.0 + row * 0.62, back + 0.42),
			Vector3(6.0, 0.09, 0.36), "shelf", false)
		for i in 9:
			# Jars, lit slightly so the shelf reads from the doorway.
			_box(Vector3(at.x - 2.6 + i * 0.65, 1.2 + row * 0.62, back + 0.42),
				Vector3(0.3, 0.34, 0.3), "grow", false)

	# Plants along the left wall, each under its own grow light. The lights are
	# emissive, not omni — this map spends its eight slots on the lot poles.
	for i in 3:
		var pz: float = at.z - 1.2 + i * 1.6
		_box(Vector3(at.x - w * 0.5 + 1.3, 0.3, pz), Vector3(0.8, 0.6, 0.8), "pot")
		_plant(Vector3(at.x - w * 0.5 + 1.3, 0.6, pz), 1.15)
		_box(Vector3(at.x - w * 0.5 + 1.3, 2.7, pz), Vector3(0.9, 0.1, 0.6),
			"grow", false)

	# A low display table down the right, so the room has something in it.
	_box(Vector3(at.x + 2.8, 0.45, at.z + 0.8), Vector3(1.4, 0.9, 2.6), "shelf")
	for i in 3:
		_box(Vector3(at.x + 2.8, 1.06, at.z + 0.0 + i * 0.9),
			Vector3(0.34, 0.32, 0.34), "grow", false)


func _picnic_table(at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees = Vector3(0, yaw, 0)
	add_child(root)
	var mat: Material = _mats["cedar"]
	_local_box(root, Vector3(0, 0.74, 0), Vector3(2.2, 0.10, 0.9), mat)
	for z: float in [-0.78, 0.78]:
		_local_box(root, Vector3(0, 0.42, z), Vector3(2.2, 0.09, 0.34), mat)
	for x: float in [-0.9, 0.9]:
		_local_box(root, Vector3(x, 0.37, 0), Vector3(0.11, 0.74, 1.8), mat)


# ---------------------------------------------------------------------------
# The forecourt
# ---------------------------------------------------------------------------

## Four pumps on two islands, each ringed by the white bollards that are all
## over the photos. No canopy — the real station doesn't have one, and its
## absence is most of why this map plays open.
func _pump_islands() -> void:
	for island: float in [-9.0, 9.0]:
		# The pad runs front-to-back with one pump behind the other, so two cars
		# queue nose to tail at the same island. That's how the real ones are
		# laid out, and it opens the lanes up sideways.
		_box(Vector3(island, 0.06, 0.0), Vector3(3.4, 0.12, 9.0), "concrete")
		for offset: float in [-2.4, 2.4]:
			_pump(Vector3(island, 0.12, offset))
		# Bollards: four to a pad, which is what stops a car hitting a pump and
		# what makes the islands read as islands from across the lot.
		for bx: float in [-1.4, 1.4]:
			for bz: float in [-4.2, 4.2]:
				_box(Vector3(island + bx, 0.55, bz), Vector3(0.22, 1.1, 0.22),
					"tank_white")
		# An orange cone by each island. Every photo has them.
		_cone(Vector3(island + 4.0, 0, 2.2))

		# Black bin with the squeegee bucket under it — one per island. These
		# are props now and interaction points later: washing a windscreen is
		# part of the shift mode, and the wiper has to live somewhere you can
		# walk to.
		var bin := Vector3(island - 4.2, 0.0, 1.9)
		_box(bin + Vector3(0, 0.55, 0), Vector3(0.86, 1.1, 0.86), "dark_metal")
		_box(bin + Vector3(0, 1.14, 0), Vector3(0.94, 0.08, 0.94),
			"dark_metal", false)
		# Squeegee bucket and handle, hanging off the side.
		_box(bin + Vector3(0.62, 0.34, 0), Vector3(0.36, 0.5, 0.36), "metal")
		_box(bin + Vector3(0.62, 0.95, 0), Vector3(0.06, 0.9, 0.06),
			"trunk", false)
		_box(bin + Vector3(0.62, 1.42, 0), Vector3(0.42, 0.10, 0.10),
			"rubber", false)
	_cone(Vector3(-2.0, 0, 4.6))


## Traffic cone: a stack of tapering boxes on a square base.
func _cone(at: Vector3) -> void:
	_box(at + Vector3(0, 0.04, 0), Vector3(0.52, 0.08, 0.52), "paint_red", false)
	for i in 3:
		var f := float(i) / 3.0
		var w := 0.34 - f * 0.20
		_box(at + Vector3(0, 0.16 + f * 0.5, 0), Vector3(w, 0.24, w),
			"paint_red", false)


## The two horizontal tanks on the west side, on their steel cradles.
func _fuel_tanks() -> void:
	# In the open ground to the right of Summerleaf, which is where they stand.
	# These are the bulk tanks the whole station is supplied from, so they're
	# big — 2.2m across, 13m long — and they're the largest piece of hard cover
	# anywhere on the map.
	for i in 2:
		var at := Vector3(23.0, 0.0, -19.0 + i * 6.5)
		var root := Node3D.new()
		root.position = at
		root.rotation_degrees = Vector3(0, 90.0, 0)
		add_child(root)
		_local_cylinder(root, Vector3(0, 2.4, 0), 2.2, 13.0, _mats["tank_white"])
		# Steel saddles under each end, the ladder rail, and the top fitting.
		for z: float in [-4.6, 4.6]:
			_local_box(root, Vector3(0, 0.5, z), Vector3(4.6, 1.0, 1.0),
				_mats["metal"])
		_local_box(root, Vector3(2.4, 1.9, 5.2), Vector3(0.12, 3.4, 0.12),
			_mats["paint"])
		_local_box(root, Vector3(0, 4.7, 0), Vector3(0.5, 0.4, 0.5), _mats["metal"])
		for bz: float in [-6.0, 0.0, 6.0]:
			_local_box(root, Vector3(3.4, 0.6, bz), Vector3(0.24, 1.2, 0.24),
				_mats["tank_white"])


## Tall white poles with the flat rectangular heads from the photos. These carry
## the map's omni lights — four of them, well inside the mobile eight-light cap,
## with the rest of the budget spare because it is daytime.
func _lot_poles() -> void:
	for at: Vector3 in [Vector3(-22.0, 0, 4.0), Vector3(-2.0, 0, -6.0),
			Vector3(18.0, 0, 4.0), Vector3(26.0, 0, -12.0)]:
		_box(at + Vector3(0, 4.0, 0), Vector3(0.28, 8.0, 0.28), "tank_white")
		_box(at + Vector3(0, 8.05, 0.5), Vector3(1.6, 0.16, 1.1), "tank_white", false)
		_box(at + Vector3(0, 7.94, 0.5), Vector3(1.3, 0.06, 0.9), "lamp", false)
		_lamp(at + Vector3(0, 7.7, 0.5), Color(1.0, 0.98, 0.94), 2.2, 16.0)


## The wooden pylon by the road: the oval sign, the red LED price digits, and
## the Summerleaf board underneath it.
func _pylon_sign() -> void:
	var at := Vector3(20.0, 0.0, 23.0)
	for x: float in [-2.4, 2.4]:
		_box(at + Vector3(x, 2.6, 0), Vector3(0.34, 5.2, 0.34), "cedar")
	_box(at + Vector3(0, 5.1, 0), Vector3(5.4, 0.3, 0.34), "cedar")
	_box(at + Vector3(0, 2.0, 0), Vector3(5.4, 0.26, 0.34), "cedar", false)

	# The oval sign, on the road-facing side.
	_disc(at + Vector3(0, 3.9, 0.24), 1.25, 0.14, "orange")
	_disc(at + Vector3(0, 3.9, 0.32), 1.06, 0.10, "teal")
	_sign_text("Beach", at + Vector3(-0.04, 4.05, 0.40), 0.42, Palette.BEACH_CREAM, 0.0)
	_sign_text("GAS", at + Vector3(0.0, 3.62, 0.40), 0.30, Palette.BEACH_CREAM, 0.0)

	# LED price board. Emissive, so it glows without a light.
	_box(at + Vector3(0, 2.65, 0.2), Vector3(3.4, 0.9, 0.16), "dark_metal", false)
	_sign_text("1.539", at + Vector3(0, 2.65, 0.30), 0.62, Palette.PRICE_RED, 0.0)

	# Summerleaf's board below.
	_box(at + Vector3(0, 1.3, 0.2), Vector3(3.6, 1.2, 0.14), "cream", false)
	_leaf_emblem(at + Vector3(0, 1.55, 0.30), 0.5)
	_sign_text("SUMMER LEAF", at + Vector3(0, 0.98, 0.30), 0.26,
		Palette.FOREST_DARK, 0.0)

	# The planted bed of boulders it sits in.
	for i in 5:
		_boulder(at + Vector3(-4.0 + i * 2.0, 0, 2.2), 0.7 + float(i % 3) * 0.2)


## Odds and ends that make it look worked-in rather than staged: a parked car or
## two, bins, and the propane cage.
func _yard_clutter() -> void:
	_car(Vector3(-20.0, 0, 12.0), 12.0, Color(0.72, 0.16, 0.12))
	_car(Vector3(24.0, 0, -20.0), 96.0, Color(0.85, 0.86, 0.88))
	_van(Vector3(-33.0, 0, -20.0), 74.0, Color(0.55, 0.57, 0.62))
	_box(Vector3(-8.0, 0.55, -12.0), Vector3(0.9, 1.1, 0.9), "dark_metal")
	_box(Vector3(12.0, 0.7, -11.0), Vector3(2.2, 1.4, 1.2), "metal")
