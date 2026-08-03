extends Node3D
## Beach Gas — the arena.
##
## Generated from code rather than hand-placed, so the whole level is one file
## you can retune in seconds: move a wall, widen the canopy, add a car.
##
## Layout, looking down (X right, Z down), lot is 62 x 48:
##
##   -31 ......................................... +31
## -24 +--------------------------------------------+
##     |  [ STORE ]        [dock]   [ CAR WASH ]    |
##     |                                            |
##  -4 |        [ CANOPY / PUMPS ]      [ parking ] |
##     |                                            |
##     |  [ dumpsters ]      [ air ]    [ parking ] |
## +24 +--------------------------------------------+
##
## Design rules the layout follows:
##   - every enclosed space has at least two ways out
##   - nothing decorative is ever at head height in a doorway
##   - the car wash and the store are the two indoor fights; the canopy is the
##     long sightline; the parking rows are the messy middle
##   - the pylon sign is visible from anywhere, so you can always orient

const PLAYER_SCENE := preload("res://scenes/player.tscn")

const LOT_X := 31.0
const LOT_Z := 24.0
const WALL_H := 3.4

## Spread wide, all in the open, all with at least two exits.
const SPAWNS: Array[Vector3] = [
	Vector3(-27.0, 0.2, 20.0),   # south-west, by the dumpsters
	Vector3(2.0, 0.2, 20.5),     # south lot
	Vector3(27.0, 0.2, 18.0),    # south-east parking
	Vector3(28.0, 0.2, -3.0),    # east, by the wash exit
	Vector3(-13.0, 0.2, -14.0),  # inside the store
	Vector3(-28.0, 0.2, -2.0),   # west, beside the store
	Vector3(19.0, 0.2, -19.0),   # car wash north end
	Vector3(-6.0, 0.2, 6.5),     # under the canopy
]

@onready var players_root: Node3D = $Players

## Set before adding to the tree to build the level for looking at only — the
## menu backdrop doesn't need several hundred collision bodies.
var decorative := false

var _mats: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
## Vehicle roots, merged separately so each stays one movable object.
var _merge_roots: Array[Node3D] = []


func _ready() -> void:
	_build_materials()
	_build_environment()
	_build_level()
	_collapse_geometry()
	if wants_traffic():
		_start_traffic()


## What this map is made of. Overridden by each map script; everything above and
## below it — players, materials, builders, merging — is shared.
func _build_level() -> void:
	_build_ground()
	_build_perimeter()
	_build_surroundings()
	_build_store()
	_build_dock()
	_build_canopy()
	_build_summerleaf()
	_build_parking()
	_build_props()


## Only maps with a road and a forecourt want cars pulling in.
func wants_traffic() -> bool:
	return true


## Where players appear. Overridden per map.
func spawn_points() -> Array[Vector3]:
	return SPAWNS


## Ambient traffic. Added after the merge so its cars aren't folded into the
## static level.
func _start_traffic() -> void:
	var traffic := Node3D.new()
	traffic.name = "Traffic"
	traffic.set_script(preload("res://scripts/traffic.gd"))
	add_child(traffic)
	traffic.world = self
	traffic.local_only = decorative


## The level is authored as a few hundred separate boxes because that's the only
## sane way to write it, and rendered as a couple of dozen meshes because that's
## the only sane way to draw it. Colliders are untouched — they're broadphase
## work, not per-frame work.
func _collapse_geometry() -> void:
	for root in _merge_roots:
		# merge_tree, not merge_children: a plant's leaflets are three pivots
		# deep, and each one is a mesh instance nobody will ever animate.
		MeshMerge.merge_tree(root)
	MeshMerge.merge_children(self)


# ---------------------------------------------------------------------------
# Players
# ---------------------------------------------------------------------------

func spawn_player(pid: int, spawn_index: int) -> void:
	if players_root.has_node(str(pid)):
		return
	var p = PLAYER_SCENE.instantiate()
	p.name = str(pid)
	p.peer_id = pid
	p.is_bot = Net.is_bot(pid)
	p.case_color = Loadout.case_color_for(Net.case_of(pid))
	p.character_index = Net.character_of(pid)
	players_root.add_child(p)
	# Bots have no peer of their own, so the host simulates them.
	p.set_multiplayer_authority(1 if p.is_bot else pid)
	p.global_position = spawn_point(spawn_index)
	p.setup()


func despawn_player(pid: int) -> void:
	var n := players_root.get_node_or_null(str(pid))
	if n:
		n.queue_free()


func get_player(pid: int):
	return players_root.get_node_or_null(str(pid))


## Reads the group rather than Players' children, because transient nodes
## (positional audio, impact particles) also get parented into the world and
## must never be mistaken for a player.
func all_players() -> Array:
	return get_tree().get_nodes_in_group("players")


func local_player():
	return get_player(Net.my_id())


func spawn_point(index: int) -> Vector3:
	var list := spawn_points()
	return list[index % list.size()]


# ---------------------------------------------------------------------------
# Look & feel
# ---------------------------------------------------------------------------

func _build_materials() -> void:
	_mats["asphalt"] = _mat(Color(0.085, 0.09, 0.11), 0.95)
	_mats["concrete"] = _mat(Color(0.42, 0.42, 0.44), 0.92)
	_mats["curb"] = _mat(Color(0.66, 0.64, 0.60), 0.9)
	_mats["paint"] = _mat(Color(0.80, 0.78, 0.62), 0.85)
	_mats["paint_red"] = _mat(Color(0.72, 0.24, 0.20), 0.85)
	_mats["wall"] = _mat(Color(0.80, 0.78, 0.73), 0.85)
	_mats["wall_dark"] = _mat(Color(0.30, 0.34, 0.40), 0.85)
	_mats["trim"] = _mat(Color(0.13, 0.30, 0.48), 0.6)
	_mats["metal"] = _mat(Color(0.46, 0.48, 0.52), 0.4, 0.7)
	_mats["dark_metal"] = _mat(Color(0.15, 0.16, 0.19), 0.45, 0.55)
	_mats["rubber"] = _mat(Color(0.06, 0.06, 0.07), 0.95)
	_mats["shelf"] = _mat(Color(0.58, 0.56, 0.53), 0.8)
	_mats["stock"] = _mat(Color(0.74, 0.47, 0.29), 0.9)
	_mats["hedge"] = _mat(Color(0.13, 0.23, 0.15), 1.0)
	_mats["chrome"] = _mat(Color(0.82, 0.84, 0.88), 0.12, 0.95)

	_mats["glass"] = _mat(Color(0.55, 0.72, 0.80, 0.20), 0.05, 0.2)
	_mats["glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats["glass"].cull_mode = BaseMaterial3D.CULL_DISABLED

	_mats["car_glass"] = _mat(Color(0.12, 0.16, 0.22, 0.62), 0.05, 0.3)
	_mats["car_glass"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	_mats["cooler"] = _glow(Color(0.62, 0.86, 0.95), Color(0.35, 0.75, 0.95), 1.2)
	_mats["sign"] = _glow(Color(0.95, 0.25, 0.30), Color(1.0, 0.20, 0.26), 2.6)
	_mats["sign_white"] = _glow(Color(0.95, 0.96, 1.0), Color(0.9, 0.94, 1.0), 1.8)
	_mats["sign_cyan"] = _glow(Color(0.35, 0.92, 1.0), Color(0.25, 0.90, 1.0), 2.4)
	_mats["lamp"] = _glow(Color(1.0, 0.96, 0.86), Color(1.0, 0.94, 0.80), 3.4)
	_mats["leaf_sign"] = _glow(Color(0.42, 0.86, 0.34), Color(0.35, 0.95, 0.30), 2.8)
	_mats["grow"] = _glow(Color(0.72, 0.42, 0.95), Color(0.78, 0.35, 1.0), 2.6)
	_mats["plant"] = _mat(Color(0.22, 0.46, 0.20), 0.9)
	_mats["plant_light"] = _mat(Color(0.34, 0.62, 0.26), 0.9)
	_mats["pot"] = _mat(Color(0.52, 0.32, 0.24), 0.9)
	_mats["wall_warm"] = _mat(Color(0.56, 0.50, 0.42), 0.88)
	_mats["headlight"] = _glow(Color(1.0, 0.97, 0.88), Color(1.0, 0.95, 0.82), 3.2)
	_mats["taillight"] = _glow(Color(0.95, 0.16, 0.14), Color(1.0, 0.12, 0.10), 2.2)

	# Unlit additive haze for the fake light shafts. No depth write, no shadow,
	# no lighting — about as cheap as geometry gets, and the mobile renderer
	# can't do real volumetrics anyway.
	var shaft := StandardMaterial3D.new()
	shaft.albedo_color = Color(1.0, 0.94, 0.78, 0.05)
	shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	shaft.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft.disable_receive_shadows = true
	_mats["shaft"] = shaft


func _build_environment() -> void:
	# Dusk rather than night. A dark game is unplayable on a phone screen in a
	# brightly lit gas station, which is exactly where this gets played.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.07, 0.11, 0.24)
	sky_mat.sky_horizon_color = Color(0.42, 0.32, 0.36)
	sky_mat.ground_horizon_color = Color(0.26, 0.22, 0.26)
	sky_mat.ground_bottom_color = Color(0.07, 0.07, 0.10)
	sky_mat.sun_angle_max = 22.0
	sky_mat.energy_multiplier = 0.95

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# Lifted from 0.75: the lot edges were dark enough to lose people in, which
	# on a phone screen in a bright room is worse than it looks here.
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 3.0

	env.fog_enabled = true
	env.fog_light_color = Color(0.28, 0.26, 0.36)
	env.fog_density = 0.0042
	env.fog_sky_affect = 0.4

	# Glow is the one genuinely expensive post effect the mobile renderer still
	# supports, so it runs on the two smallest levels only. Everything meant to
	# shine is emissive, which is free — the glow just blooms it.
	env.glow_enabled = Settings.glow_enabled()
	env.glow_intensity = 0.85
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 1.0)
	env.set_glow_level(2, 0.7)
	for level in range(3, 7):
		env.set_glow_level(level, 0.0)

	# Colour grade: lift contrast, pull a little saturation out so the emissive
	# reds and cyans read as the brightest thing on screen. Part of the tonemap
	# pass, so it costs nothing.
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.02
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.94

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-26.0, 40.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.58)
	sun.light_energy = 0.6
	# Real-time shadow mapping is the single most expensive thing here. Phones
	# never get it, and Low turns it off everywhere; both compensate with
	# brighter ambient, which is also far more readable on a small screen.
	sun.shadow_enabled = Settings.shadows_enabled()
	sun.directional_shadow_max_distance = Settings.shadow_distance()
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	if not sun.shadow_enabled:
		env.ambient_light_energy = 1.20
	add_child(sun)

	_env = env
	_sun = sun
	Settings.changed.connect(_apply_quality)


## Live quality changes, so leaving the settings screen doesn't need a rebuild.
func _apply_quality() -> void:
	if _env == null or _sun == null:
		return
	_env.glow_enabled = Settings.glow_enabled()
	_sun.shadow_enabled = Settings.shadows_enabled()
	_sun.directional_shadow_max_distance = Settings.shadow_distance()
	_env.ambient_light_energy = 0.75 if _sun.shadow_enabled else 0.95


# ---------------------------------------------------------------------------
# Ground & boundary
# ---------------------------------------------------------------------------

func _build_ground() -> void:
	_box(Vector3(0, -0.5, 0), Vector3(LOT_X * 2.0, 1.0, LOT_Z * 2.0), "asphalt").name = "Ground"

	# Concrete apron under the canopy and in front of the store — breaks up a
	# lot that would otherwise read as one flat grey sheet.
	_flat(Vector3(-6.0, 0.012, 4.0), Vector2(26.0, 18.0), "concrete")
	_flat(Vector3(-13.0, 0.012, -8.5), Vector2(23.0, 4.0), "concrete")

	# Parking bays, south-east.
	for i in 7:
		_flat(Vector3(11.0 + i * 2.9, 0.02, 8.0), Vector2(0.16, 5.2), "paint")
	for i in 5:
		_flat(Vector3(13.0 + i * 2.9, 0.02, 18.0), Vector2(0.16, 5.2), "paint")
	# Hatched no-parking zone by the store doors.
	for i in 6:
		var hatch := _flat(Vector3(-16.0 + i * 1.6, 0.02, -8.0), Vector2(0.14, 3.0), "paint_red")
		hatch.rotation_degrees.y = 32.0


## The lot doesn't end in a wall any more. An invisible barrier keeps you in,
## set back beyond the kerb, while the world visibly carries on past it — road,
## sidewalk, streetlights, buildings across the way. A fence says "level
## boundary"; a road going somewhere says "this is a place".
func _build_perimeter() -> void:
	var h := 8.0
	for entry in [
		[Vector3(0, h * 0.5, -LOT_Z - 1.0), Vector3(LOT_X * 2.0 + 6.0, h, 1.0)],
		[Vector3(0, h * 0.5, LOT_Z + 1.0), Vector3(LOT_X * 2.0 + 6.0, h, 1.0)],
		[Vector3(-LOT_X - 1.0, h * 0.5, 0), Vector3(1.0, h, LOT_Z * 2.0 + 6.0)],
		[Vector3(LOT_X + 1.0, h * 0.5, 0), Vector3(1.0, h, LOT_Z * 2.0 + 6.0)],
	]:
		_invisible_wall(entry[0], entry[1])

	# Kerb line, so there's still something to read as the edge of the forecourt.
	for i in 11:
		_box(Vector3(-30.0 + i * 6.0, 0.45, 22.6), Vector3(0.22, 0.9, 0.22), "paint_red")


## Collision with nothing to look at. Used for the map boundary, which should
## stop you without ever being a thing you can see.
func _invisible_wall(pos: Vector3, size: Vector3) -> void:
	if decorative:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "wall")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	add_child(body)


## Everything past the boundary. None of it is reachable; all of it is there so
## the lot reads as somewhere rather than an arena.
func _build_surroundings() -> void:
	# Road along the south frontage, with lane markings and a kerb.
	_flat(Vector3(0, 0.02, 30.0), Vector2(96.0, 13.0), "asphalt")
	_box(Vector3(0, 0.09, 23.6), Vector3(96.0, 0.18, 0.7), "curb", false)
	_box(Vector3(0, 0.09, 36.4), Vector3(96.0, 0.18, 0.7), "curb", false)
	for i in 24:
		_flat(Vector3(-46.0 + i * 4.0, 0.03, 30.0), Vector2(2.0, 0.18), "paint")
	# Same treatment on the east side, so two edges read as through-roads.
	_flat(Vector3(38.0, 0.02, 0.0), Vector2(13.0, 60.0), "asphalt")
	_box(Vector3(31.6, 0.09, 0.0), Vector3(0.7, 0.18, 60.0), "curb", false)
	for i in 14:
		_flat(Vector3(38.0, 0.03, -28.0 + i * 4.0), Vector2(0.18, 2.0), "paint")

	# Streetlights down the far verge.
	for i in 6:
		var lx := -34.0 + i * 14.0
		_box(Vector3(lx, 3.6, 37.6), Vector3(0.28, 7.2, 0.28), "metal", false)
		_box(Vector3(lx, 7.1, 36.6), Vector3(0.24, 0.2, 2.2), "metal", false)
		_box(Vector3(lx, 6.94, 35.7), Vector3(0.7, 0.16, 1.2), "lamp", false)

	# Buildings across the road: blank blocks with lit windows. Nobody will ever
	# get close enough for them to need more than a silhouette.
	var blocks := [
		[Vector3(-32.0, 0, 48.0), Vector3(24.0, 11.0, 14.0)],
		[Vector3(-4.0, 0, 50.0), Vector3(20.0, 8.0, 14.0)],
		[Vector3(24.0, 0, 47.0), Vector3(22.0, 14.0, 14.0)],
		[Vector3(52.0, 0, 6.0), Vector3(16.0, 10.0, 30.0)],
		[Vector3(-46.0, 0, -6.0), Vector3(14.0, 9.0, 26.0)],
		[Vector3(-20.0, 0, -44.0), Vector3(30.0, 12.0, 16.0)],
		[Vector3(20.0, 0, -46.0), Vector3(26.0, 9.0, 16.0)],
	]
	for block in blocks:
		var at: Vector3 = block[0]
		var size: Vector3 = block[1]
		_box(at + Vector3(0, size.y * 0.5, 0), size, "wall_dark", false)
		_box(at + Vector3(0, size.y + 0.3, 0), size + Vector3(0.8, -size.y + 0.6, 0.8),
			"trim", false)
		# Window grid on the face pointing back at the lot.
		var facing: float = -1.0 if at.z > 0.0 else 1.0
		var columns := int(size.x / 3.0)
		var rows := int(size.y / 3.0)
		for c in columns:
			for r in rows:
				if (c * 3 + r * 5) % 7 < 3:
					continue   # some lights are off
				_box(at + Vector3(-size.x * 0.5 + 1.5 + c * 3.0, 2.0 + r * 3.0,
					facing * (size.z * 0.5 + 0.05)), Vector3(1.4, 1.6, 0.08),
					"lamp" if (c + r) % 3 else "sign_cyan", false)


# ---------------------------------------------------------------------------
# Store
# ---------------------------------------------------------------------------

func _build_store() -> void:
	# Footprint x -24..-2, z -23..-11.
	var y := WALL_H * 0.5
	var t := 0.35
	var west := -24.0
	var east := -2.0
	var north := -23.0
	var south := -11.0

	# North wall, with a back door at x -8..-5.
	_box(Vector3(-16.5, y, north), Vector3(15.0, WALL_H, t), "wall")
	_box(Vector3(-3.5, y, north), Vector3(3.0, WALL_H, t), "wall")
	_box(Vector3(-6.5, WALL_H - 0.35, north), Vector3(3.0, 0.7, t), "wall")

	# West wall solid, east wall with a side door at z -16..-13.
	_box(Vector3(west, y, -17.0), Vector3(t, WALL_H, 12.0), "wall")
	_box(Vector3(east, y, -20.0), Vector3(t, WALL_H, 6.0), "wall")
	_box(Vector3(east, y, -12.0), Vector3(t, WALL_H, 2.0), "wall")
	_box(Vector3(east, WALL_H - 0.35, -14.5), Vector3(t, 0.7, 3.0), "wall")

	# South frontage: doors in the middle, glazing either side.
	_box(Vector3(-19.0, y, south), Vector3(10.0, WALL_H, t), "wall")
	_box(Vector3(-7.0, y, south), Vector3(10.0, WALL_H, t), "wall")
	_box(Vector3(-13.0, WALL_H - 0.35, south), Vector3(4.0, 0.7, t), "wall")
	_box(Vector3(-19.0, 1.8, south), Vector3(9.0, 2.4, 0.1), "glass")
	_box(Vector3(-7.0, 1.8, south), Vector3(9.0, 2.4, 0.1), "glass")

	# Roof and parapet.
	_box(Vector3(-13.0, WALL_H + 0.2, -17.0), Vector3(22.6, 0.4, 12.6), "trim")
	_box(Vector3(-13.0, WALL_H + 0.6, south - 0.1), Vector3(22.6, 0.5, 0.5), "trim")

	# Floor tiles, so the interior doesn't read as one grey slab.
	for tx in 11:
		for tz in 6:
			if (tx + tz) % 2 == 0:
				_flat(Vector3(-23.0 + tx * 2.0, 0.015, -22.0 + tz * 2.0),
					Vector2(2.0, 2.0), "concrete")

	# Aisles, stocked. Gaps at both ends of every run so no row is a dead end.
	for row in 4:
		var z := -20.0 + row * 2.4
		_shelf_run(Vector3(-19.5, 0, z), 6.5)
		_shelf_run(Vector3(-9.5, 0, z), 7.5)

	# Cooler run along the back wall: framed doors, handles, stock behind glass.
	for i in 6:
		var cxx := -20.5 + i * 2.4
		_box(Vector3(cxx, 1.15, -22.2), Vector3(2.2, 2.3, 0.9), "cooler")
		_box(Vector3(cxx, 1.15, -21.72), Vector3(2.24, 2.34, 0.06), "dark_metal", false)
		_box(Vector3(cxx, 1.15, -21.70), Vector3(1.98, 2.10, 0.03), "glass", false)
		_box(Vector3(cxx + 1.02, 1.15, -21.66), Vector3(0.07, 1.30, 0.07), "chrome", false)
		for shelf_row in 4:
			for bottle in 7:
				_box(Vector3(cxx - 0.84 + bottle * 0.28, 0.42 + shelf_row * 0.52, -22.1),
					Vector3(0.16, 0.34, 0.16), ["sign", "sign_cyan", "leaf_sign", "grow"][
						(bottle + shelf_row + i) % 4], false)

	# Counter: till, card reader, lottery dispenser, hot food, coffee.
	_box(Vector3(-5.5, 0.55, -13.0), Vector3(5.0, 1.1, 1.0), "shelf")
	_box(Vector3(-3.4, 0.55, -14.6), Vector3(1.0, 1.1, 2.2), "shelf")
	_box(Vector3(-5.5, 1.16, -13.0), Vector3(4.6, 0.12, 0.9), "metal", false)
	_box(Vector3(-6.6, 1.40, -13.1), Vector3(0.52, 0.36, 0.44), "dark_metal", false)
	_box(Vector3(-6.6, 1.58, -13.3), Vector3(0.44, 0.26, 0.04), "sign_cyan", false)
	_box(Vector3(-5.8, 1.30, -12.7), Vector3(0.16, 0.16, 0.10), "dark_metal", false)
	_box(Vector3(-4.2, 1.40, -13.0), Vector3(0.60, 0.36, 0.30), "sign", false)
	for i in 4:
		_box(Vector3(-4.45 + i * 0.16, 1.40, -12.84), Vector3(0.11, 0.30, 0.02), "sign_white", false)

	# Hot roller and the coffee station behind the counter.
	_box(Vector3(-8.4, 1.32, -13.6), Vector3(1.3, 0.32, 0.7), "metal", false)
	for i in 5:
		var rx := -8.9 + i * 0.26
		_box(Vector3(rx, 1.50, -13.6), Vector3(0.09, 0.09, 0.62), "chrome", false)
		_box(Vector3(rx, 1.56, -13.6), Vector3(0.10, 0.10, 0.44), "stock", false)
	_box(Vector3(-8.4, 1.72, -13.95), Vector3(1.34, 0.50, 0.06), "glass", false)
	for i in 2:
		_box(Vector3(-2.9 + i * 0.5, 1.42, -15.4), Vector3(0.36, 0.52, 0.36), "dark_metal", false)
		_box(Vector3(-2.9 + i * 0.5, 1.72, -15.4), Vector3(0.30, 0.10, 0.30), "sign", false)
	for i in 3:
		_box(Vector3(-2.2, 1.32 + i * 0.02, -14.6 + i * 0.02), Vector3(0.10, 0.14, 0.10),
			"sign_white", false)

	# Magazine rack and a bin by the door.
	for i in 3:
		_box(Vector3(-1.8, 0.55 + i * 0.42, -12.0), Vector3(0.10, 0.06, 1.5), "metal", false)
		for m in 4:
			_box(Vector3(-1.75, 0.68 + i * 0.42, -12.6 + m * 0.38), Vector3(0.03, 0.30, 0.30),
				["sign", "sign_cyan", "leaf_sign", "sign_white"][m], false)
	_box(Vector3(-2.6, 0.45, -11.6), Vector3(0.55, 0.9, 0.55), "dark_metal", false)
	_box(Vector3(-2.6, 0.92, -11.6), Vector3(0.62, 0.06, 0.62), "metal", false)

	# Ceiling grid.
	for gx in 12:
		_box(Vector3(-23.0 + gx * 1.9, 3.32, -17.0), Vector3(0.05, 0.05, 12.0), "trim", false)
	for gz in 7:
		_box(Vector3(-13.0, 3.32, -22.5 + gz * 1.9), Vector3(22.0, 0.05, 0.05), "trim", false)

	# Stockroom in the west corner. The partition stops well short of the far
	# wall, so it's an alcove you can always walk out of, never a trap.
	_box(Vector3(-21.0, y, -17.5), Vector3(6.0, WALL_H, t), "wall")
	_box(Vector3(-22.0, 0.65, -20.5), Vector3(1.8, 1.3, 1.8), "stock")
	_box(Vector3(-19.5, 0.5, -21.8), Vector3(1.4, 1.0, 1.3), "stock")

	# Ceiling panels do the lighting; two real lights do the illuminating.
	for i in 5:
		_box(Vector3(-21.0 + i * 4.2, 3.18, -17.0), Vector3(2.6, 0.07, 0.6), "lamp", false)
	_lamp(Vector3(-18.0, 3.0, -17.0), Color(0.86, 0.92, 1.0), 4.0, 15.0)
	_lamp(Vector3(-8.0, 3.0, -16.0), Color(0.86, 0.92, 1.0), 3.6, 14.0)

	# Frontage signage, all of it well above head height and non-colliding.
	_box(Vector3(-13.0, 2.95, south - 0.28), Vector3(9.0, 1.15, 0.22), "sign_white", false)
	_sign_text("BEACH GAS", Vector3(-13.0, 2.97, south - 0.40), 0.58, Color(0.07, 0.24, 0.50), 0.0)
	_box(Vector3(-20.5, 2.30, south - 0.30), Vector3(3.0, 0.5, 0.16), "sign", false)
	_sign_text("OPEN 24H", Vector3(-20.5, 2.31, south - 0.39), 0.26, Color(1, 1, 1), 0.0)
	_box(Vector3(-5.5, 2.30, south - 0.30), Vector3(2.6, 0.5, 0.16), "sign_cyan", false)
	_sign_text("ATM", Vector3(-5.5, 2.31, south - 0.39), 0.26, Color(0.02, 0.10, 0.16), 0.0)


## A gondola run with product on it. The unit collides; the stock doesn't —
## nobody should ever get caught on a bag of crisps.
func _shelf_run(at: Vector3, length: float) -> void:
	_box(at + Vector3(0, 0.9, 0), Vector3(length, 1.8, 1.0), "shelf")
	_box(at + Vector3(0, 1.82, 0), Vector3(length + 0.1, 0.06, 1.1), "metal", false)

	var goods := ["sign", "sign_cyan", "leaf_sign", "stock", "grow", "sign_white"]
	var columns := int(length / 0.42)
	for tier in 3:
		var y := 0.52 + tier * 0.48
		# Shelf lip.
		for face: float in [-0.52, 0.52]:
			_box(at + Vector3(0, y - 0.20, face), Vector3(length - 0.1, 0.04, 0.03),
				"metal", false)
		for i in columns:
			var px: float = at.x - length * 0.5 + 0.24 + i * 0.42
			for face: float in [-0.36, 0.36]:
				var pick: int = (i + tier * 2 + int(absf(at.z))) % goods.size()
				var tall: float = 0.16 + float((i + tier) % 3) * 0.06
				_box(Vector3(px, y - 0.10 + tall * 0.5, at.z + face),
					Vector3(0.30, tall, 0.22), goods[pick], false)


## Raised loading dock off the store's east end. The ramp is the only proper
## piece of verticality on the map, which makes the roofline worth contesting.
func _build_dock() -> void:
	_box(Vector3(2.0, 0.55, -19.0), Vector3(8.0, 1.1, 8.0), "concrete")
	_box(Vector3(2.0, 1.15, -19.0), Vector3(8.2, 0.1, 8.2), "curb", false)

	# Ramp down to the lot, built as shallow steps so it's walkable.
	for i in 6:
		_box(Vector3(2.0, 0.09 + i * 0.18, -14.6 + i * 0.62),
			Vector3(5.0, 0.18 + i * 0.18, 0.64), "concrete")

	# Roller shutters into the store's east wall, and crates for cover up top.
	for i in 2:
		_box(Vector3(-1.6, 1.9, -21.0 + i * 3.4), Vector3(0.2, 1.5, 2.6), "metal", false)
	_box(Vector3(4.2, 1.7, -21.0), Vector3(1.6, 1.2, 1.6), "stock")
	_box(Vector3(0.2, 1.6, -21.6), Vector3(1.4, 1.0, 1.4), "stock")
	_box(Vector3(4.6, 1.6, -17.0), Vector3(1.2, 1.0, 1.2), "stock")
	_lamp(Vector3(2.0, 3.0, -17.0), Color(1.0, 0.86, 0.62), 2.6, 10.0)
	_box(Vector3(2.0, 3.15, -17.0), Vector3(1.2, 0.1, 0.4), "lamp", false)


# ---------------------------------------------------------------------------
# Forecourt
# ---------------------------------------------------------------------------

func _build_canopy() -> void:
	var cx := -6.0
	var cz := 4.0
	_box(Vector3(cx, 5.25, cz), Vector3(24.0, 0.55, 16.0), "trim")
	_box(Vector3(cx, 4.85, cz - 8.0), Vector3(24.0, 0.55, 0.35), "sign_white", false)
	_box(Vector3(cx, 4.85, cz + 8.0), Vector3(24.0, 0.55, 0.35), "sign_white", false)
	_box(Vector3(cx - 12.0, 4.85, cz), Vector3(0.35, 0.55, 16.0), "sign_white", false)
	_box(Vector3(cx + 12.0, 4.85, cz), Vector3(0.35, 0.55, 16.0), "sign_white", false)

	for sx in [-17.0, -6.0, 5.0]:
		for sz in [-3.4, 11.4]:
			_box(Vector3(sx, 2.5, sz), Vector3(0.6, 5.0, 0.6), "metal")
			_box(Vector3(sx, 0.15, sz), Vector3(0.9, 0.3, 0.9), "curb")

	# Two pump islands, four pumps each. Eight is what a real forecourt this
	# size has, and it leaves proper driving lanes between them instead of a
	# wall of hardware.
	for island in 2:
		var z := 0.5 + island * 7.0
		_box(Vector3(cx, 0.14, z), Vector3(15.0, 0.28, 2.4), "curb")
		_box(Vector3(cx, 0.30, z - 1.16), Vector3(15.0, 0.08, 0.10), "paint_red", false)
		_box(Vector3(cx, 0.30, z + 1.16), Vector3(15.0, 0.08, 0.10), "paint_red", false)
		for i in 4:
			_pump(Vector3(cx - 6.0 + i * 4.0, 0.0, z))
		# Bollards guarding each island end.
		for end_x: float in [cx - 7.2, cx + 7.2]:
			_box(Vector3(end_x, 0.75, z), Vector3(0.22, 1.2, 0.22), "paint_red")
			_box(Vector3(end_x, 1.3, z), Vector3(0.24, 0.10, 0.24), "sign_white", false)

	# Six emissive panels you can see, three real lights doing the work.
	for i in 3:
		for j in 2:
			_box(Vector3(-16.0 + i * 10.0, 4.94, 0.0 + j * 8.0), Vector3(3.0, 0.09, 1.2),
				"lamp", false)
	for i in 3:
		_lamp(Vector3(-16.0 + i * 10.0, 4.8, 4.0), Color(1.0, 0.95, 0.85), 5.0, 19.0)

	# Fake light shafts. Real volumetrics are Forward+ only; a very faint
	# additive cone under each fixture reads as haze in the beam for almost
	# nothing.
	for i in 3:
		var shaft := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 1.1
		cone.bottom_radius = 4.0
		cone.height = 4.8
		cone.radial_segments = 12
		cone.rings = 0
		shaft.mesh = cone
		shaft.material_override = _mats["shaft"]
		shaft.position = Vector3(-16.0 + i * 10.0, 2.45, 4.0)
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shaft)

	# Pylon sign, tall enough to see over the canopy from anywhere on the lot.
	_box(Vector3(-28.0, 4.0, 20.0), Vector3(0.55, 8.0, 0.55), "metal")
	_box(Vector3(-28.0, 8.4, 20.0), Vector3(6.4, 2.0, 0.36), "sign_white", false)
	_box(Vector3(-28.0, 6.4, 20.0), Vector3(4.4, 1.5, 0.34), "sign", false)
	for face in [[20.20, 0.0], [19.80, 180.0]]:
		_sign_text("BEACH GAS", Vector3(-28.0, 8.42, face[0]), 0.74, Color(0.07, 0.24, 0.50), face[1])
		_sign_text("$4.19", Vector3(-28.0, 6.40, face[0]), 0.56, Color(1, 1, 1), face[1])


## One fuel pump, in the detail you'd actually see standing next to it: lit
## price display, grade buttons, keypad, card reader, receipt slot, and a nozzle
## on a drooping hose. Only the body collides — none of the fittings should ever
## be something you snag on.
func _pump(at: Vector3) -> void:
	var x := at.x
	var z := at.z

	# Body and canopy cap.
	_box(Vector3(x, 1.15, z), Vector3(1.2, 2.0, 0.8), "dark_metal")
	_box(Vector3(x, 2.22, z), Vector3(1.34, 0.14, 0.94), "metal", false)
	_box(Vector3(x, 2.34, z), Vector3(1.10, 0.10, 0.76), "sign_white", false)
	_box(Vector3(x, 0.30, z), Vector3(1.26, 0.14, 0.86), "metal", false)

	for face: float in [-1.0, 1.0]:
		var fz: float = z + face * 0.41

		# Price display and the pump number above it.
		_box(Vector3(x, 1.86, fz), Vector3(0.80, 0.44, 0.04), "sign_white", false)
		_box(Vector3(x, 1.86, fz + face * 0.022), Vector3(0.70, 0.34, 0.01), "dark_metal", false)
		for row in 3:
			_box(Vector3(x - 0.18, 1.98 - row * 0.11, fz + face * 0.03),
				Vector3(0.26, 0.055, 0.008), "sign_cyan", false)
			_box(Vector3(x + 0.16, 1.98 - row * 0.11, fz + face * 0.03),
				Vector3(0.18, 0.055, 0.008), "sign", false)

		# Grade selector buttons.
		for i in 3:
			_box(Vector3(x - 0.30 + i * 0.30, 1.50, fz + face * 0.02),
				Vector3(0.22, 0.16, 0.03), "sign_white" if i == 1 else "metal", false)

		# Keypad and card reader.
		_box(Vector3(x - 0.24, 1.18, fz + face * 0.02), Vector3(0.40, 0.34, 0.03), "metal", false)
		for row in 4:
			for col in 3:
				_box(Vector3(x - 0.36 + col * 0.12, 1.30 - row * 0.075, fz + face * 0.035),
					Vector3(0.075, 0.05, 0.012), "dark_metal", false)
		_box(Vector3(x + 0.26, 1.24, fz + face * 0.025), Vector3(0.26, 0.18, 0.05), "dark_metal", false)
		_box(Vector3(x + 0.26, 1.24, fz + face * 0.05), Vector3(0.16, 0.02, 0.01), "sign_cyan", false)
		# Receipt slot.
		_box(Vector3(x + 0.26, 1.02, fz + face * 0.02), Vector3(0.22, 0.03, 0.02), "trim", false)

	# Nozzle holsters and hoses, one each side.
	for side: float in [-1.0, 1.0]:
		var hx: float = x + side * 0.66
		_box(Vector3(hx, 1.42, z), Vector3(0.14, 0.30, 0.26), "metal", false)
		_box(Vector3(hx + side * 0.04, 1.24, z), Vector3(0.10, 0.26, 0.12), "sign", false)
		_box(Vector3(hx + side * 0.04, 1.05, z), Vector3(0.05, 0.18, 0.05), "metal", false)
		# Hose drooping back to the body.
		for i in 6:
			var t := float(i) / 5.0
			_box(Vector3(lerpf(hx, x + side * 0.58, t), 1.34 - sin(t * PI) * 0.42 - t * 0.10, z),
				Vector3(0.055, 0.14, 0.055), "rubber", false)

	# Squeegee bucket beside every other pump.
	if int(round(x)) % 8 == 0:
		_box(Vector3(x + 1.5, 0.62, z), Vector3(0.34, 0.62, 0.34), "sign", false)
		_box(Vector3(x + 1.5, 1.05, z), Vector3(0.06, 0.34, 0.06), "metal", false)
		_box(Vector3(x + 1.5, 1.24, z), Vector3(0.26, 0.05, 0.10), "rubber", false)


## Summerleaf — the dispensary next door. Second indoor fight on the map, with
## a completely different palette from the store (magenta grow lights against
## the store's cold white) so you always know which building you're in.
func _build_summerleaf() -> void:
	var y := WALL_H * 0.5
	var west := 12.0
	var east := 26.0
	var north := -22.0
	var south := -8.0
	var t := 0.35

	# Side walls solid, front door south, back door north — two ways out.
	_box(Vector3(west, y, -15.0), Vector3(t, WALL_H, 14.0), "wall_warm")
	_box(Vector3(east, y, -15.0), Vector3(t, WALL_H, 14.0), "wall_warm")
	_box(Vector3(14.5, y, south), Vector3(5.4, WALL_H, t), "wall_warm")
	_box(Vector3(23.5, y, south), Vector3(5.4, WALL_H, t), "wall_warm")
	_box(Vector3(19.0, WALL_H - 0.4, south), Vector3(4.0, 0.8, t), "wall_warm")
	_box(Vector3(15.0, y, north), Vector3(6.4, WALL_H, t), "wall_warm")
	_box(Vector3(24.2, y, north), Vector3(4.0, WALL_H, t), "wall_warm")
	_box(Vector3(21.0, WALL_H - 0.4, north), Vector3(3.0, 0.8, t), "wall_warm")

	# Glazing either side of the front door.
	_box(Vector3(14.5, 1.8, south), Vector3(4.6, 2.4, 0.1), "glass")
	_box(Vector3(23.5, 1.8, south), Vector3(4.6, 2.4, 0.1), "glass")
	_box(Vector3(19.0, WALL_H + 0.2, -15.0), Vector3(14.4, 0.4, 14.4), "trim")
	_box(Vector3(19.0, WALL_H + 0.6, south - 0.1), Vector3(14.4, 0.5, 0.5), "trim")

	# Display counters and a back wall of stock.
	for i in 2:
		_box(Vector3(15.4 + i * 7.2, 0.55, -13.0), Vector3(4.6, 1.1, 1.0), "shelf")
		_box(Vector3(15.4 + i * 7.2, 1.16, -13.0), Vector3(4.2, 0.12, 0.9), "glass", false)
	_box(Vector3(19.0, 0.9, -17.5), Vector3(6.0, 1.8, 1.0), "shelf")
	for i in 4:
		_box(Vector3(13.6 + i * 3.6, 1.15, -21.2), Vector3(3.0, 2.3, 0.8), "shelf")
	_box(Vector3(24.4, 0.55, -12.0), Vector3(1.0, 1.1, 2.6), "shelf")

	# Grow lights: magenta panels plus one real light. Cheap and unmistakable.
	for i in 3:
		for j in 2:
			_box(Vector3(15.5 + i * 3.5, 3.24, -18.0 + j * 5.0), Vector3(2.4, 0.08, 0.7),
				"grow", false)
	_lamp(Vector3(19.0, 3.0, -15.0), Color(0.78, 0.40, 1.0), 4.4, 17.0)

	# Frontage: name board and a leaf, both above head height, neither solid.
	_box(Vector3(19.0, 2.95, south - 0.28), Vector3(7.6, 1.15, 0.22), "leaf_sign", false)
	_sign_text("SUMMERLEAF", Vector3(19.0, 2.97, south - 0.40), 0.50, Color(0.04, 0.16, 0.05), 0.0)
	_leaf_emblem(Vector3(19.0, 4.35, south - 0.34), 1.0)
	_box(Vector3(24.0, 2.25, south - 0.30), Vector3(2.4, 0.5, 0.16), "grow", false)
	_sign_text("21+", Vector3(24.0, 2.26, south - 0.39), 0.26, Color(0.06, 0.02, 0.10), 0.0)

	# Plants for sale on trestle tables out front. Also decent low cover.
	for i in 5:
		var x := 13.4 + i * 3.0
		_box(Vector3(x, 0.42, -6.4), Vector3(2.4, 0.12, 1.5), "stock")
		for leg in [-1.0, 1.0]:
			_box(Vector3(x + leg * 1.0, 0.19, -6.4), Vector3(0.12, 0.38, 1.3), "stock", false)
		_plant(Vector3(x - 0.6, 0.48, -6.7), 1.0)
		_plant(Vector3(x + 0.55, 0.48, -6.2), 0.82)
	# A few big ones straight on the ground.
	for entry in [Vector3(11.4, 0, -5.0), Vector3(27.0, 0, -5.4), Vector3(27.2, 0, -9.5)]:
		_plant(entry, 1.5)


## A potted cannabis plant: pot, stalk, and three tiers of seven-point leaves.
func _plant(pos: Vector3, plant_scale: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * plant_scale
	root.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(root)

	_local_cylinder(root, Vector3(0, 0.16, 0), 0.20, 0.32, _mats["pot"])
	_local_cylinder(root, Vector3(0, 0.33, 0), 0.21, 0.05, _mats["pot"])
	_local_box(root, Vector3(0, 0.62, 0), Vector3(0.05, 0.62, 0.05), _mats["plant"])
	_merge_roots.append(root)

	for tier in 3:
		var height := 0.48 + tier * 0.22
		var spread := 0.30 - tier * 0.07
		var count := 5 - tier
		for i in count:
			var angle := TAU * float(i) / float(count) + tier * 0.6
			var frond := Node3D.new()
			frond.position = Vector3(0, height, 0)
			frond.rotation_degrees = Vector3(-28.0 - tier * 6.0, rad_to_deg(angle), 0)
			root.add_child(frond)
			_leaf(frond, spread, tier == 2)


## Seven leaflets fanned from a point — the recognisable shape, in six boxes.
func _leaf(parent: Node3D, size: float, pale: bool) -> void:
	var mat: Material = _mats["plant_light"] if pale else _mats["plant"]
	for i in 7:
		var t := (float(i) - 3.0) / 3.0                 # -1 .. 1
		var length: float = size * (1.0 - absf(t) * 0.45)
		var m := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size * 0.10, 0.012, length)
		m.mesh = mesh
		m.material_override = mat
		m.position = Vector3(0, 0, -length * 0.5)
		m.rotation_degrees = Vector3(0, t * 52.0, 0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new()
		pivot.rotation_degrees.y = t * 52.0
		parent.add_child(pivot)
		m.rotation_degrees = Vector3.ZERO
		pivot.add_child(m)


## The same shape, big and lit, for the shop sign.
func _leaf_emblem(pos: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(90, 0, 0)
	add_child(root)
	for i in 7:
		var t := (float(i) - 3.0) / 3.0
		var length: float = size * (1.05 - absf(t) * 0.42)
		var pivot := Node3D.new()
		pivot.rotation_degrees.y = t * 50.0
		root.add_child(pivot)
		var m := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size * 0.13, 0.06, length)
		m.mesh = mesh
		m.material_override = _mats["leaf_sign"]
		m.position = Vector3(0, 0, -length * 0.5)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(m)


func _build_parking() -> void:
	# South-east rows, angled slightly so the lot doesn't feel like a grid.
	_car(Vector3(12.5, 0, 8.0), 4.0, Color(0.72, 0.16, 0.14))
	_car(Vector3(18.3, 0, 8.0), -3.0, Color(0.14, 0.16, 0.20))
	_car(Vector3(24.1, 0, 8.0), 2.0, Color(0.78, 0.76, 0.72))
	_car(Vector3(14.5, 0, 18.0), 180.0, Color(0.16, 0.34, 0.72))
	_car(Vector3(20.3, 0, 18.0), 176.0, Color(0.30, 0.44, 0.32))

	# One parked askew by the store doors, and a van behind the dock.
	_car(Vector3(-9.0, 0, -6.5), 96.0, Color(0.62, 0.52, 0.20))
	_van(Vector3(7.5, 0, -8.0), 12.0, Color(0.86, 0.86, 0.88))


func _build_props() -> void:
	# Ice box and propane cage by the store front.
	_box(Vector3(-2.4, 0.9, -9.6), Vector3(2.4, 1.8, 1.3), "cooler")
	_box(Vector3(-25.6, 0.85, -9.6), Vector3(2.0, 1.7, 1.3), "metal")

	# Air & vacuum island, east of the canopy.
	_box(Vector3(9.5, 0.14, 6.0), Vector3(4.4, 0.28, 2.6), "curb")
	_box(Vector3(8.5, 0.95, 6.0), Vector3(0.9, 1.6, 0.9), "sign_white", false)
	_box(Vector3(8.5, 0.95, 6.0), Vector3(0.85, 1.55, 0.85), "dark_metal")
	_box(Vector3(10.5, 0.95, 6.0), Vector3(0.9, 1.6, 0.9), "dark_metal")
	_lamp(Vector3(9.5, 2.4, 6.0), Color(0.9, 0.95, 1.0), 1.6, 6.0)

	# Dumpster corral, south-west. Three walls, open to the east.
	_box(Vector3(-23.0, 1.1, 14.0), Vector3(10.0, 2.2, 0.35), "wall_dark")
	_box(Vector3(-28.0, 1.1, 18.0), Vector3(0.35, 2.2, 8.0), "wall_dark")
	_box(Vector3(-23.0, 1.1, 22.0), Vector3(10.0, 2.2, 0.35), "wall_dark")
	_box(Vector3(-25.5, 0.75, 16.5), Vector3(2.8, 1.5, 1.9), "hedge")
	_box(Vector3(-25.5, 0.75, 19.8), Vector3(2.8, 1.5, 1.9), "hedge")
	_box(Vector3(-21.0, 0.6, 20.5), Vector3(1.4, 1.2, 1.4), "stock")

	# Planters breaking up the long open runs.
	for entry in [Vector3(-2.0, 0, 16.0), Vector3(4.0, 0, 13.0), Vector3(-16.0, 0, 18.0)]:
		_box(entry + Vector3(0, 0.35, 0), Vector3(2.6, 0.7, 2.6), "curb")
		_box(entry + Vector3(0, 0.95, 0), Vector3(2.2, 0.7, 2.2), "hedge")

	# Lot lighting. The canopy and the two shops were the only lit things, which
	# left the outer thirds of the map a place to disappear into. Four poles
	# cover the corners nobody could see into.
	for at: Vector3 in [Vector3(-27.0, 0, 6.0), Vector3(27.0, 0, 3.0),
			Vector3(-14.0, 0, 20.0), Vector3(27.0, 0, 20.0)]:
		_box(at + Vector3(0, 3.5, 0), Vector3(0.32, 7.0, 0.32), "metal")
		_box(at + Vector3(0, 6.9, -0.9), Vector3(0.26, 0.22, 1.9), "metal", false)
		_box(at + Vector3(0, 6.72, -1.7), Vector3(0.8, 0.18, 1.3), "lamp", false)
		_lamp(at + Vector3(0, 6.5, -1.7), Color(1.0, 0.94, 0.84), 4.4, 24.0)

	# Loose crates and a pallet stack in the middle of the lot.
	_box(Vector3(1.5, 0.5, 11.0), Vector3(1.5, 1.0, 1.5), "stock")
	_box(Vector3(2.7, 0.5, 9.9), Vector3(1.3, 1.0, 1.3), "stock")
	_box(Vector3(1.9, 1.35, 10.6), Vector3(1.1, 0.7, 1.1), "stock")
	_box(Vector3(-20.0, 0.35, 6.0), Vector3(2.4, 0.7, 1.6), "stock")


# ---------------------------------------------------------------------------
# Vehicles
# ---------------------------------------------------------------------------

## A car you can take cover behind, shoot the glass out of the sightline of,
## and jump onto. Roof sits at 1.5m, which the jump clears.
func _car(pos: Vector3, yaw: float, colour: Color) -> void:
	var root := build_car(colour)
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	_merge_roots.append(root)


## The same car, unparented, for traffic.gd to drive around. Merged on the spot
## so a moving vehicle is one mesh rather than thirty.
func build_car(colour: Color) -> Node3D:
	var body := _mat(colour, 0.28, 0.45)
	var root := Node3D.new()

	_local_box(root, Vector3(0, 0.62, 0), Vector3(1.90, 0.60, 4.45), body)
	_local_box(root, Vector3(0, 0.95, -0.30), Vector3(1.72, 0.20, 2.30), body)
	_local_box(root, Vector3(0, 1.18, 0.20), Vector3(1.62, 0.52, 2.00), body)
	_local_box(root, Vector3(0, 1.20, 0.18), Vector3(1.66, 0.42, 1.92), _mats["car_glass"])
	_local_box(root, Vector3(0, 1.46, 0.20), Vector3(1.56, 0.10, 1.90), body)
	_local_box(root, Vector3(0, 0.38, 0), Vector3(1.96, 0.18, 4.30), _mats["rubber"])

	for sx in [-0.95, 0.95]:
		for sz in [-1.48, 1.48]:
			var wheel := _local_cylinder(root, Vector3(sx, 0.35, sz), 0.35, 0.24, _mats["rubber"])
			wheel.rotation_degrees.z = 90.0
			_local_cylinder(wheel, Vector3(0, 0.125, 0), 0.19, 0.03, _mats["chrome"])
		_local_box(root, Vector3(sx * 0.98, 0.60, -1.48), Vector3(0.10, 0.42, 0.95), _mats["dark_metal"])
		_local_box(root, Vector3(sx * 0.98, 0.60, 1.48), Vector3(0.10, 0.42, 0.95), _mats["dark_metal"])
		_local_box(root, Vector3(sx * 0.92, 1.24, -0.72), Vector3(0.16, 0.10, 0.20), _mats["dark_metal"])

	for sx in [-0.62, 0.62]:
		_local_box(root, Vector3(sx, 0.72, -2.24), Vector3(0.42, 0.18, 0.06), _mats["headlight"])
		_local_box(root, Vector3(sx, 0.78, 2.24), Vector3(0.40, 0.16, 0.06), _mats["taillight"])
	_local_box(root, Vector3(0, 0.50, -2.26), Vector3(1.50, 0.20, 0.08), _mats["dark_metal"])
	_local_box(root, Vector3(0, 0.50, 2.26), Vector3(1.50, 0.20, 0.08), _mats["dark_metal"])
	return root


func _van(pos: Vector3, yaw: float, colour: Color) -> void:
	var body := _mat(colour, 0.4, 0.2)
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees.y = yaw
	add_child(root)
	_merge_roots.append(root)

	_local_box(root, Vector3(0, 1.30, 0.35), Vector3(2.10, 1.90, 3.70), body)
	_local_box(root, Vector3(0, 1.00, -1.90), Vector3(2.05, 1.30, 1.20), body)
	_local_box(root, Vector3(0, 1.35, -2.44), Vector3(1.85, 0.55, 0.14), _mats["car_glass"])
	_local_box(root, Vector3(0, 0.42, 0), Vector3(2.14, 0.20, 5.00), _mats["rubber"])
	for sx in [-1.02, 1.02]:
		for sz in [-1.70, 1.60]:
			var wheel := _local_cylinder(root, Vector3(sx, 0.38, sz), 0.38, 0.26, _mats["rubber"])
			wheel.rotation_degrees.z = 90.0
			_local_cylinder(wheel, Vector3(0, 0.135, 0), 0.20, 0.03, _mats["chrome"])
	for sx in [-0.68, 0.68]:
		_local_box(root, Vector3(sx, 0.74, -2.50), Vector3(0.40, 0.20, 0.06), _mats["headlight"])
		_local_box(root, Vector3(sx, 0.90, 2.22), Vector3(0.34, 0.44, 0.06), _mats["taillight"])
	_local_box(root, Vector3(1.06, 1.30, 0.40), Vector3(0.06, 1.10, 2.20), _mats["sign_white"])


# ---------------------------------------------------------------------------
# Builders
# ---------------------------------------------------------------------------

func _box(pos: Vector3, size: Vector3, mat_key: String, collide := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = _mats[mat_key]
	m.position = pos
	add_child(m)

	if collide and not decorative:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		# Lets a laser hit know whether it just struck a fuel pump or a hedge.
		body.set_meta("surface", mat_key)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = pos
		add_child(body)
	return m


## Ground decal: a flat plane, no collision, no shadow. Used for paint and
## concrete patches that only exist to break up the tarmac.
func _flat(pos: Vector3, size: Vector2, mat_key: String) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = size
	m.mesh = plane
	m.material_override = _mats[mat_key]
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m


## Mesh parented to a vehicle root, with a matching collider so you can hide
## behind it and stand on it.
func _local_box(root: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	root.add_child(m)

	if not decorative:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("surface", "metal")
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = pos
		root.add_child(body)
	return m


func _local_cylinder(root: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(m)
	return m


func _lamp(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	add_child(l)


## Text painted onto a sign face. Fixed orientation, never billboarded: sign
## writing belongs to the sign, and turning it to follow the camera makes
## back-to-back faces slide over each other into an unreadable mess.
## `facing_y` is the yaw the text reads from — 0 looks south down +Z.
func _sign_text(text: String, pos: Vector3, size: float, color: Color, facing_y: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.rotation_degrees = Vector3(0, facing_y, 0)
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.double_sided = false
	l.no_depth_test = false
	# Renders in the opaque pass so walls actually occlude it — otherwise you
	# can read the shop sign from inside the stockroom.
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	add_child(l)


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


func _glow(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(albedo, 0.35)
	m.emission_enabled = true
	m.emission = emission
	m.emission_energy_multiplier = energy
	return m
