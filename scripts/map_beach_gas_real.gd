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


## No passing traffic. The real road is a quiet rural one and cars driving
## through a firefight every few seconds would read as a different place.
func wants_traffic() -> bool:
	return false


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
	_flat(Vector3(0, 0, 0), Vector2(SITE_X * 2.0, SITE_Z * 2.0), "gravel")


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

	_box(at + Vector3(0, wall_h * 0.5, 0), Vector3(w, wall_h, d), "store_white")

	# Gable: two slabs leaned against each other. The real roof is a shallow
	# pitch with a deep overhang on the front.
	for side in [-1.0, 1.0]:
		var slab := _box(at + Vector3(0, wall_h + 1.05, side * (d * 0.25 + 0.15)),
			Vector3(w + 0.9, 0.20, d * 0.62), "roof_black", false)
		slab.rotation_degrees = Vector3(side * -22.0, 0, 0)
	_box(at + Vector3(0, wall_h + 1.55, 0), Vector3(w + 0.5, 0.22, 0.6),
		"roof_black", false)

	# Front face, looking south toward the pumps.
	var face := at.z + d * 0.5 + 0.06
	_beach_gas_disc(Vector3(at.x - 2.2, 2.6, face), 1.9)

	# Door: blue-grey, with a window in the top half.
	_box(Vector3(at.x + 3.6, 1.35, face), Vector3(1.5, 2.7, 0.12), "trim")
	_box(Vector3(at.x + 3.6, 2.15, face + 0.05), Vector3(1.1, 0.9, 0.06), "glass")
	# Left window with its wooden awning.
	_box(Vector3(at.x - 5.4, 2.4, face), Vector3(2.6, 1.5, 0.10), "glass")
	_box(Vector3(at.x - 5.4, 3.3, face + 0.35), Vector3(2.8, 0.12, 0.9), "cedar", false)

	# Two gooseneck barn lamps either side of the sign, and the string lights
	# along the eave. Emissive, not omni lights — the mobile renderer only
	# allows eight of those and this map spends them on the lot.
	for x: float in [at.x - 4.6, at.x - 0.2]:
		_box(Vector3(x, 3.5, face + 0.2), Vector3(0.14, 0.5, 0.14), "dark_metal", false)
		_box(Vector3(x, 3.25, face + 0.45), Vector3(0.5, 0.22, 0.5), "dark_metal", false)
		_box(Vector3(x, 3.12, face + 0.45), Vector3(0.34, 0.06, 0.34), "lamp", false)
	for i in 11:
		var t := float(i) / 10.0
		var sag := sin(t * PI) * 0.35
		_box(Vector3(at.x - w * 0.45 + t * w * 0.9, 4.6 - sag, face + 0.5),
			Vector3(0.10, 0.16, 0.10), "lamp", false)

	# The porch: two white Adirondack chairs with a log stump between them, and
	# two blue ones off to the side. They are in every photo of the place.
	_chair(Vector3(at.x - 3.4, 0, face + 1.9), 0.0, "cream")
	_chair(Vector3(at.x - 0.9, 0, face + 1.9), 0.0, "cream")
	_box(Vector3(at.x - 2.15, 0.28, face + 1.9), Vector3(0.5, 0.56, 0.5), "trunk")
	_chair(Vector3(at.x - 8.2, 0, face + 2.4), 22.0, "chair_blue")
	_chair(Vector3(at.x - 6.4, 0, face + 2.6), 12.0, "chair_blue")

	# Potted plant, boulders and driftwood posts.
	_box(Vector3(at.x - 5.0, 0.35, face + 1.6), Vector3(0.7, 0.7, 0.7), "pot")
	_plant(Vector3(at.x - 5.0, 0.7, face + 1.6), 0.8)
	_boulder(Vector3(at.x - 7.5, 0, face + 4.2), 1.5)
	_boulder(Vector3(at.x + 5.5, 0, face + 3.4), 1.1)
	for x: float in [at.x - 9.2, at.x - 1.6]:
		_box(Vector3(x, 0.7, face + 0.9), Vector3(0.34, 1.4, 0.34), "trunk")

	# Pepsi machine and a barrel bin by the door.
	_box(Vector3(at.x + 6.2, 1.0, face + 0.5), Vector3(1.0, 2.0, 0.8), "sign")
	_box(Vector3(at.x + 5.0, 0.55, face + 0.9), Vector3(0.8, 1.1, 0.8), "dark_metal")


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

	_box(at + Vector3(0, h * 0.5, 0), Vector3(w, h, d), "wood")
	_box(at + Vector3(0, h + 0.12, 0), Vector3(w + 0.8, 0.22, d + 0.8),
		"metal", false)

	var face := at.z + d * 0.5 + 0.06
	# Screened windows, the OPEN sign, and the leaf emblem over the door.
	_box(Vector3(at.x - 2.6, 2.1, face), Vector3(2.2, 1.3, 0.10), "glass")
	_box(Vector3(at.x + 2.4, 2.1, face), Vector3(2.0, 1.3, 0.10), "glass")
	_box(Vector3(at.x + 0.0, 1.3, face), Vector3(1.4, 2.6, 0.12), "wood")
	_leaf_emblem(Vector3(at.x, 3.0, face + 0.08), 0.9)
	_box(Vector3(at.x + 3.9, 2.6, face + 0.05), Vector3(0.9, 0.4, 0.06), "sign")

	# Cedar fence running west from it, and a picnic table out front.
	for i in 7:
		_box(Vector3(at.x - w * 0.5 - 0.4 - i * 1.6, 1.0, face + 0.6),
			Vector3(1.5, 2.0, 0.14), "cedar")
	_picnic_table(Vector3(at.x + 6.5, 0, face + 2.2), -14.0)


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
		# The concrete pad each island sits on.
		_box(Vector3(island, 0.06, 0.0), Vector3(7.0, 0.12, 3.4), "concrete")
		for offset: float in [-1.8, 1.8]:
			_pump(Vector3(island + offset, 0.12, 0.0))
		# Bollards: four to a pad, which is what stops a car hitting a pump and
		# what makes the islands read as islands from across the lot.
		for bx: float in [-3.2, 3.2]:
			for bz: float in [-1.4, 1.4]:
				_box(Vector3(island + bx, 0.55, bz), Vector3(0.22, 1.1, 0.22),
					"tank_white")
		# An orange cone by each island. Every photo has them.
		_cone(Vector3(island + 4.0, 0, 2.2))
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
	for i in 2:
		var at := Vector3(-29.0, 0.0, -8.0 + i * 5.5)
		var root := Node3D.new()
		root.position = at
		root.rotation_degrees = Vector3(0, 90.0, 0)
		add_child(root)
		_local_cylinder(root, Vector3(0, 1.7, 0), 1.5, 9.0, _mats["tank_white"])
		# Cradles and the yellow ladder rail.
		for z: float in [-3.2, 3.2]:
			_local_box(root, Vector3(0, 0.35, z), Vector3(3.2, 0.7, 0.7),
				_mats["metal"])
		_local_box(root, Vector3(1.7, 1.2, 3.6), Vector3(0.1, 2.4, 0.1),
			_mats["paint"])


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
	var at := Vector3(20.0, 0.0, 19.0)
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
	_sign_text("149.9", at + Vector3(0, 2.65, 0.30), 0.62, Palette.PRICE_RED, 0.0)

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
