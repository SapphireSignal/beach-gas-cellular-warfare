extends Node
class_name CharacterProps
## The things each character is posing with on the select screen.
##
## Showcase only — none of this follows you into a match. Built from primitives
## like everything else, and registered into `rig.animated` so character_rig.gd
## can move the bits that should move.

static func build(kind: String, prop: Node3D, entry: Dictionary, rig: Node3D) -> void:
	match kind:
		"music": _music(prop, entry, rig)
		"joint": _joint(prop, rig)
		"monster": _monster(prop, rig)
		"computer": _computer(prop, rig)
		"car": _car(prop, rig)
		"sportbike": _sportbike(prop, rig)
		"cats": _cats(prop, rig)
		"gatorade": _gatorade(prop, rig)
		"art": _art(prop, rig)
		"mcdonalds": _mcdonalds(prop, rig)
		"daughter": _daughter(prop, entry, rig)
		"chair": _chair(prop, rig)
		"rocker": _rocker(prop, rig)
		_: pass


# ---------------------------------------------------------------------------
# Held things — these ride in the right hand, which the rig raises and lowers.
# ---------------------------------------------------------------------------

static func _joint(prop: Node3D, rig: Node3D) -> void:
	var hand := _hand(rig)
	var j := _box(hand, Vector3(0, -0.06, -0.03), Vector3(0.012, 0.012, 0.09),
		_mat(Color(0.94, 0.92, 0.86), 0.9))
	_box(j, Vector3(0, 0, -0.052), Vector3(0.014, 0.014, 0.014),
		_glow(Color(1.0, 0.45, 0.15), 3.0))

	# Baggies at his feet rather than a shop run.
	_weed_bag(prop, Vector3(0.58, 0, 0.27), -22.0, 1.00)
	_weed_bag(prop, Vector3(0.82, 0, 0.07), 15.0, 0.86)
	_weed_bag(prop, Vector3(0.71, 0, -0.15), 48.0, 0.93)

	# A bird that has decided he counts as furniture.
	var bird := _bird(prop, Vector3(-0.215, 1.435, 0.015), 26.0)

	rig.animated["hand"] = hand
	rig.animated["smoke_origin"] = j
	rig.animated["bird"] = bird
	rig.behaviour = "smoke"


static func _monster(prop: Node3D, rig: Node3D) -> void:
	var hand := _hand(rig)
	_monster_can(hand, Vector3(0, -0.082, 0))

	# Third one today, and the rest of them stacked at his feet.
	var stack := Node3D.new()
	stack.position = Vector3(0.68, 0, 0.18)
	stack.rotation_degrees.y = -18.0
	prop.add_child(stack)
	for layer in 3:
		_monster_four_pack(stack, Vector3(0, layer * 0.168, 0))
	# A second column, one lower, so it reads as a stash rather than a tower.
	for layer in 2:
		_monster_four_pack(stack, Vector3(0.185, layer * 0.168, 0.03))
	# And a few loose ones in front of it.
	_monster_can(stack, Vector3(-0.15, 0.078, -0.19))
	_monster_can(stack, Vector3(-0.05, 0.078, -0.24))
	_monster_can(stack, Vector3(0.09, 0.078, -0.21))

	rig.animated["hand"] = hand
	rig.behaviour = "drink"


## One can: black body, ribbed ends, claw on both faces so it reads from either
## side. Shared by the one in his hand and every one in the stack.
static func _monster_can(parent: Node3D, at: Vector3) -> MeshInstance3D:
	var black := _mat(Color(0.045, 0.05, 0.045), 0.30, 0.6)
	var can := _cylinder(parent, at, 0.036, 0.155, black)
	_cylinder(can, Vector3(0, 0.080, 0), 0.032, 0.014, _mat(Color(0.62, 0.64, 0.68), 0.2, 0.9))
	_cylinder(can, Vector3(0, -0.079, 0), 0.033, 0.012, black)
	_claw(can, Vector3(0, 0.004, 0), 0.105, 0.0355, true)
	return can


## Four cans in a cardboard sleeve.
static func _monster_four_pack(parent: Node3D, at: Vector3) -> void:
	var pack := Node3D.new()
	pack.position = at
	parent.add_child(pack)

	for col in 2:
		for row in 2:
			_monster_can(pack, Vector3(-0.038 + col * 0.076, 0.078, -0.038 + row * 0.076))

	# Sleeve gripping the bottom third, sized to wrap outside the cans. Kept a
	# good deal lighter than the cans themselves — at true Monster black the
	# whole stack turned into one unreadable smudge on the select screen.
	_box(pack, Vector3(0, 0.044, 0), Vector3(0.168, 0.074, 0.168),
		_mat(Color(0.17, 0.19, 0.17), 0.85))
	for face: float in [-1.0, 1.0]:
		_claw(pack, Vector3(0, 0.046, face * 0.086), 0.056, 0.0, false)


## The three-slash claw, at whatever size. Both faces on a can so it reads from
## either side; one face on a cardboard sleeve.
static func _claw(parent: Node3D, at: Vector3, height: float, depth: float,
		both_faces: bool) -> void:
	var mat := _glow(Color(0.42, 0.98, 0.16), 2.8)
	var faces: Array = [-1.0, 1.0] if both_faces else [1.0]
	var step := height * 0.19
	for i in 3:
		var lean: float = -13.0 + float(i) * 13.0
		var length: float = height - absf(float(i) - 1.0) * step
		for side: float in faces:
			_box(parent, at + Vector3((float(i) - 1.0) * step, 0.0, side * depth),
				Vector3(height * 0.105, length, 0.003), mat, Vector3(0, 0, lean))


## A shop bag with cartons of smokes standing in it.
##
## Cartons rather than loose packs: nobody at a gas station buys one packet at a
## time, and a carton's long flat top is what makes the bag read as full of
## cigarettes from across the select screen.
## A pinched sandwich baggie with buds showing through it. Deliberately small —
## these read as something dropped at his feet, not as the point of the pose.
static func _weed_bag(parent: Node3D, at: Vector3, yaw: float, size: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	root.scale = Vector3(size, size, size)
	parent.add_child(root)

	# Barely-there plastic. At the first attempt this was alpha 0.4 and the bags
	# rendered as plain white blocks — indistinguishable from the cigarette bags
	# they replaced. The contents have to be the thing you see; the bag is just
	# a sheen over them.
	var plastic := _mat(Color(0.88, 0.94, 0.90, 0.15), 0.06)
	plastic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	plastic.cull_mode = BaseMaterial3D.CULL_DISABLED
	var seal := _mat(Color(0.55, 0.68, 0.62, 0.55), 0.24)
	seal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Slumped: wider than it is tall, because it's lying on concrete.
	_box(root, Vector3(0, 0.042, 0), Vector3(0.21, 0.084, 0.16), plastic)
	_box(root, Vector3(0, 0.090, 0), Vector3(0.215, 0.013, 0.165), seal)

	# Buds, big enough to read as the contents rather than a texture. Three
	# tones so it doesn't flatten into one green block.
	var greens := [Color(0.30, 0.52, 0.20), Color(0.38, 0.62, 0.26), Color(0.24, 0.43, 0.17)]
	for i in 3:
		var bud := _box(root, Vector3(-0.052 + i * 0.052, 0.042, -0.014 + (i % 2) * 0.028),
			Vector3(0.062, 0.062, 0.058), _mat(greens[i], 0.90),
			Vector3(0, -20.0 + i * 24.0, 8.0 - i * 7.0))
		_box(bud, Vector3(0.005, 0.030, 0.006), Vector3(0.042, 0.038, 0.038),
			_mat(greens[(i + 1) % 3], 0.92), Vector3(0, 30.0, -12.0))


## A bird perched on a shoulder. Built in labelled pieces because the rig moves
## it — a bird that holds perfectly still reads as a statue, and the whole point
## of it is that Josh has stopped noticing something alive is sitting on him.
static func _bird(parent: Node3D, at: Vector3, yaw: float) -> Dictionary:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	# Oversized on purpose. At true scale it vanished against his shoulder from
	# where the select-screen camera sits, and a detail nobody can see is worth
	# nothing. Reads as a small bird; measures as a slightly unreasonable one.
	root.scale = Vector3(1.45, 1.45, 1.45)
	parent.add_child(root)

	# Bright enough to separate from a dark green shirt.
	var feather := _mat(Color(0.30, 0.44, 0.62), 0.68)
	var belly := _mat(Color(0.88, 0.90, 0.94), 0.76)
	var beak_mat := _mat(Color(1.00, 0.72, 0.18), 0.50)
	var eye := _mat(Color(0.04, 0.04, 0.06), 0.20)

	var body := _box(root, Vector3(0, 0.052, 0), Vector3(0.062, 0.070, 0.098), feather)
	_box(body, Vector3(0, -0.016, 0.012), Vector3(0.050, 0.038, 0.070), belly)
	_box(body, Vector3(0, 0.004, -0.070), Vector3(0.030, 0.022, 0.070), feather,
		Vector3(14.0, 0, 0))                                        # tail

	var head := _box(root, Vector3(0, 0.108, 0.036), Vector3(0.050, 0.048, 0.050), feather)
	_box(head, Vector3(0, -0.004, 0.036), Vector3(0.016, 0.013, 0.030), beak_mat)
	for side: float in [-0.017, 0.017]:
		_box(head, Vector3(side, 0.010, 0.022), Vector3(0.010, 0.010, 0.008), eye)

	var wing_l := _box(body, Vector3(-0.034, 0.008, -0.004), Vector3(0.012, 0.046, 0.078), feather)
	var wing_r := _box(body, Vector3(0.034, 0.008, -0.004), Vector3(0.012, 0.046, 0.078), feather)

	for side: float in [-0.016, 0.016]:
		_box(root, Vector3(side, 0.012, 0.014), Vector3(0.009, 0.024, 0.009), beak_mat)

	return {"root": root, "head": head, "wing_l": wing_l, "wing_r": wing_r, "rest_y": at.y}


## Two-hopper slushy machine, green and blue. The machine Jay spends his shift
## standing next to, so it may as well stand next to him here.
static func _slushy_machine(parent: Node3D, at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	var steel := _mat(Color(0.62, 0.64, 0.68), 0.32, 0.65)
	var dark := _mat(Color(0.12, 0.13, 0.16), 0.45)
	var tray := _mat(Color(0.30, 0.32, 0.36), 0.40, 0.35)

	_box(root, Vector3(0, 0.200, 0), Vector3(0.62, 0.40, 0.44), dark)
	_box(root, Vector3(0, 0.415, 0), Vector3(0.66, 0.04, 0.48), steel)
	# Drip tray, because every one of these in the world is sticky.
	_box(root, Vector3(0, 0.145, 0.235), Vector3(0.46, 0.022, 0.10), tray)

	var flavours := [Color(0.22, 0.85, 0.36), Color(0.20, 0.52, 0.95)]
	for i in 2:
		var x: float = -0.155 + i * 0.310
		var liquid := _glow(flavours[i], 0.55)
		liquid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		liquid.albedo_color = Color(flavours[i].r, flavours[i].g, flavours[i].b, 0.88)

		var glass := _mat(Color(0.86, 0.92, 0.96, 0.20), 0.05)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED

		_box(root, Vector3(x, 0.600, 0), Vector3(0.235, 0.33, 0.235), liquid)
		_box(root, Vector3(x, 0.625, 0), Vector3(0.260, 0.38, 0.260), glass)
		_box(root, Vector3(x, 0.835, 0), Vector3(0.225, 0.055, 0.225), steel)
		_cylinder(root, Vector3(x, 0.885, 0), 0.055, 0.055, steel)
		_cylinder(root, Vector3(x, 0.600, 0), 0.028, 0.30, steel)   # auger
		# Tap and handle on the front face.
		_box(root, Vector3(x, 0.455, 0.138), Vector3(0.055, 0.075, 0.055), steel)
		_box(root, Vector3(x, 0.505, 0.178), Vector3(0.030, 0.100, 0.030), dark,
			Vector3(-22.0, 0, 0))


static func _cigarette_bag(parent: Node3D, at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation_degrees.y = yaw
	parent.add_child(root)

	var plastic := _mat(Color(0.84, 0.85, 0.89), 0.88)
	var crease := _mat(Color(0.72, 0.73, 0.78), 0.9)

	# Body, a little wider at the base than the mouth so it sits like a full bag.
	_box(root, Vector3(0, 0.135, 0), Vector3(0.34, 0.27, 0.23), plastic)
	_box(root, Vector3(0, 0.275, 0), Vector3(0.295, 0.06, 0.195), crease)
	# Two pinched handles.
	for side: float in [-0.095, 0.095]:
		_box(root, Vector3(side, 0.365, 0), Vector3(0.026, 0.125, 0.13), crease)

	# Cartons standing in the bag, most of their height clearing the rim — that
	# tall band of colour is the only thing that says "cigarettes" rather than
	# "white box" from where the camera actually sits.
	var wrappers := [Color(0.86, 0.11, 0.13), Color(0.95, 0.78, 0.22), Color(0.13, 0.35, 0.62)]
	for i in 3:
		var carton := _box(root, Vector3(-0.086 + i * 0.086, 0.375, 0.0),
			Vector3(0.078, 0.235, 0.15), _mat(wrappers[i], 0.68),
			Vector3(0, 0, -6.0 + i * 6.0))
		# The white band every packet has near its base. Slightly proud of the
		# carton on every side, so the two faces can't z-fight.
		_box(carton, Vector3(0, -0.082, 0), Vector3(0.081, 0.06, 0.153),
			_mat(Color(0.94, 0.94, 0.96), 0.7))
		# Lid seam across the top.
		_box(carton, Vector3(0, 0.108, 0), Vector3(0.081, 0.016, 0.153),
			_mat(Color(wrappers[i]).darkened(0.35), 0.7))


static func _gatorade(prop: Node3D, rig: Node3D) -> void:
	_bottle(_hand(rig), Vector3(0, -0.085, 0), 1.0, Color(0.98, 0.55, 0.10))

	# Thirty of them stacked beside him, three crates high. Flavours cycle so
	# it reads as a shop display rather than one bottle copy-pasted.
	var flavours := [
		Color(0.98, 0.55, 0.10), Color(0.30, 0.70, 0.35), Color(0.30, 0.55, 0.95),
		Color(0.85, 0.25, 0.35), Color(0.75, 0.45, 0.90),
	]
	var stack := Node3D.new()
	stack.position = Vector3(0.78, 0, 0.22)
	stack.rotation_degrees.y = -16.0
	prop.add_child(stack)

	var crate := _mat(Color(0.30, 0.32, 0.36), 0.8)
	for layer in 3:
		var base := layer * 0.30
		_box(stack, Vector3(0.16, base + 0.012, 0.05), Vector3(0.78, 0.025, 0.30), crate)
		for column in 5:
			for depth in 2:
				var index := layer * 10 + column * 2 + depth
				_bottle(stack,
					Vector3(-0.14 + column * 0.15, base + 0.10, -0.06 + depth * 0.15),
					0.92, flavours[index % flavours.size()])
	rig.behaviour = "drink"


## One Gatorade: tinted body, white cap, dark label band.
static func _bottle(parent: Node3D, at: Vector3, scale: float, colour: Color) -> void:
	var body := _cylinder(parent, at, 0.034 * scale, 0.155 * scale,
		_mat(Color(colour.r, colour.g, colour.b, 0.9), 0.15))
	_cylinder(body, Vector3(0, 0.088 * scale, 0), 0.017 * scale, 0.03 * scale,
		_mat(Color(0.92, 0.92, 0.94), 0.3))
	_box(body, Vector3(0, 0.0, 0), Vector3(0.072 * scale, 0.05 * scale, 0.072 * scale),
		_mat(Color(0.10, 0.28, 0.18), 0.6))


static func _mcdonalds(prop: Node3D, rig: Node3D) -> void:
	var red := _mat(Color(0.83, 0.11, 0.10), 0.7)
	var fry := _mat(Color(0.98, 0.80, 0.28), 0.85)

	# Fries in hand: tapered red carton, arches on the front, fries poking out.
	var hand := _hand(rig)
	var carton := _box(hand, Vector3(0, -0.085, -0.02), Vector3(0.072, 0.095, 0.048), red)
	_box(carton, Vector3(0, 0.052, 0), Vector3(0.086, 0.045, 0.058), red)
	_arches(carton, Vector3(0, 0.004, -0.026), 0.05)
	for i in 6:
		_box(carton, Vector3(-0.026 + i * 0.0105, 0.088 + (i % 3) * 0.008,
			-0.012 + float(i % 2) * 0.016), Vector3(0.008, 0.075, 0.008), fry,
			Vector3(0, 0, -8.0 + i * 3.0))

	# Bag on the floor beside him, with the arches on it too.
	var bag := _box(prop, Vector3(0.46, 0.11, 0.16), Vector3(0.24, 0.22, 0.16),
		_mat(Color(0.88, 0.72, 0.44), 0.9), Vector3(0, -14.0, 0))
	_box(bag, Vector3(-0.05, 0.13, 0), Vector3(0.06, 0.05, 0.14),
		_mat(Color(0.82, 0.66, 0.40), 0.9))
	_box(bag, Vector3(0.05, 0.13, 0), Vector3(0.06, 0.05, 0.14),
		_mat(Color(0.82, 0.66, 0.40), 0.9))
	_arches(bag, Vector3(0, 0.01, -0.082), 0.10)

	# Cup with a lid and a straw.
	var cup := _cylinder(prop, Vector3(0.72, 0.085, 0.02), 0.048, 0.17, red)
	_cylinder(cup, Vector3(0, 0.09, 0), 0.052, 0.018, _mat(Color(0.92, 0.92, 0.94), 0.5))
	_cylinder(cup, Vector3(0.012, 0.16, 0), 0.007, 0.14, _mat(Color(0.95, 0.95, 0.96), 0.4))
	_arches(cup, Vector3(0, 0.01, -0.048), 0.06)

	rig.animated["hand"] = hand
	rig.behaviour = "eat"


## The golden arches, as an M. Four strokes is all it takes to be unmistakable.
static func _arches(parent: Node3D, at: Vector3, size: float) -> void:
	var gold := _glow(Color(0.99, 0.78, 0.09), 1.1)
	var thickness := size * 0.20
	var root := Node3D.new()
	root.position = at
	parent.add_child(root)
	# Two uprights.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(size * 0.42 * side, 0, 0), Vector3(thickness, size, 0.004), gold)
	# Two diagonals meeting at the middle.
	for side in [-1.0, 1.0]:
		_box(root, Vector3(size * 0.21 * side, size * 0.06, 0),
			Vector3(thickness, size * 0.86, 0.004), gold, Vector3(0, 0, 26.0 * side))


static func _music(prop: Node3D, entry: Dictionary, rig: Node3D) -> void:
	var accent: Color = entry.get("accent", Color(0.9, 0.3, 0.35))

	# Halo of sound above his head.
	var halo_mat := _glow(accent, 1.6)
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(accent.r, accent.g, accent.b, 0.55)
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.20
	torus.outer_radius = 0.25
	torus.rings = 20
	torus.ring_segments = 5
	halo.mesh = torus
	halo.mesh.material = halo_mat
	halo.position = Vector3(0, 1.98, 0)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.add_child(halo)

	# Notes drifting up around him. The rig orbits and fades them.
	var notes: Array[Node3D] = []
	for i in 6:
		var note := Node3D.new()
		prop.add_child(note)
		_note(note, accent if i % 2 == 0 else Color(0.95, 0.96, 1.0))
		notes.append(note)

	# Bong in his right hand. Glass tube, water chamber, bowl on a side stem,
	# and an ember that lights up when it reaches his mouth.
	var glass := _mat(Color(0.34, 0.62, 0.42, 0.55), 0.06)
	var hand := _hand(rig)
	var chamber := _cylinder(hand, Vector3(0, -0.115, -0.01), 0.052, 0.13, glass)
	_cylinder(chamber, Vector3(0, -0.068, 0), 0.056, 0.016, _mat(Color(0.22, 0.42, 0.30), 0.3))
	_cylinder(chamber, Vector3(0, -0.030, 0), 0.048, 0.055,
		_mat(Color(0.30, 0.70, 0.45, 0.7), 0.05))   # water line
	var tube := _cylinder(chamber, Vector3(0, 0.135, 0), 0.026, 0.24, glass)
	_cylinder(tube, Vector3(0, 0.128, 0), 0.036, 0.026, glass)   # mouthpiece flare
	var stem := _cylinder(chamber, Vector3(0.055, 0.02, -0.03), 0.013, 0.10, glass)
	stem.rotation_degrees = Vector3(-24, 0, -58)
	var bowl := _cylinder(stem, Vector3(0, 0.062, 0), 0.026, 0.032, glass)
	var ember_mat := _glow(Color(1.0, 0.42, 0.10), 0.5)
	_cylinder(bowl, Vector3(0, 0.017, 0), 0.019, 0.008, ember_mat)

	# The slushy machine he is never more than a few steps from.
	_slushy_machine(prop, Vector3(0.86, 0, 0.10), -24.0)

	rig.animated["notes"] = notes
	rig.animated["halo"] = halo_mat
	rig.animated["ember"] = ember_mat
	rig.animated["hand"] = hand
	rig.behaviour = "bong"


## A quaver: round head, stem, flag.
static func _note(parent: Node3D, colour: Color) -> void:
	var mat := _glow(colour, 2.0)
	var head := _cylinder(parent, Vector3(0, 0, 0), 0.036, 0.016, mat)
	head.rotation_degrees = Vector3(90, 0, 18)
	_box(parent, Vector3(0.032, 0.075, 0), Vector3(0.012, 0.15, 0.012), mat)
	_box(parent, Vector3(0.058, 0.126, 0), Vector3(0.045, 0.012, 0.012), mat,
		Vector3(0, 0, -32.0))


# ---------------------------------------------------------------------------
# Scene props
# ---------------------------------------------------------------------------

## Roger, on a chair with a laptop balanced on his knees. No desk — he isn't at
## a workstation, he's just brought it with him.
static func _computer(prop: Node3D, rig: Node3D) -> void:
	_chair(prop, rig)

	var shell := _mat(Color(0.34, 0.36, 0.40), 0.30, 0.75)
	var dark := _mat(Color(0.09, 0.09, 0.11), 0.4)
	var screen_mat := _glow(Color(0.35, 0.70, 1.0), 1.6)

	# Base across his lap.
	var base := _box(prop, Vector3(0, 0.565, -0.28), Vector3(0.36, 0.018, 0.25), shell,
		Vector3(-6, 0, 0))
	_box(base, Vector3(0, 0.012, 0.012), Vector3(0.30, 0.004, 0.15), dark)   # keys
	for row in 4:
		for col in 11:
			_box(base, Vector3(-0.138 + col * 0.0276, 0.016, -0.026 + row * 0.0175),
				Vector3(0.022, 0.003, 0.013), _mat(Color(0.16, 0.17, 0.20), 0.5))
	_box(base, Vector3(0, 0.014, 0.086), Vector3(0.10, 0.003, 0.058),
		_mat(Color(0.22, 0.23, 0.27), 0.35))                                  # trackpad

	# Lid hinged at the far edge, leaning back toward him.
	var lid := _box(prop, Vector3(0, 0.672, -0.372), Vector3(0.36, 0.235, 0.012), shell,
		Vector3(14, 0, 0))
	_box(lid, Vector3(0, 0, 0.0075), Vector3(0.335, 0.212, 0.003), dark)
	_box(lid, Vector3(0, 0, 0.0095), Vector3(0.318, 0.196, 0.002), screen_mat)
	_box(lid, Vector3(0, 0.118, 0.004), Vector3(0.012, 0.012, 0.006),
		_glow(Color(0.30, 1.0, 0.45), 0.8))                                   # webcam light

	# The laptop is the only light source on him, which is the whole look.
	_light(prop, Vector3(0, 0.72, -0.30), Color(0.45, 0.72, 1.0), 2.4, 2.4)
	rig.animated["screens"] = screen_mat
	rig.behaviour = "type"
	rig.seat_height = 0.46


static func _chair(prop: Node3D, rig: Node3D) -> void:
	var m := _mat(Color(0.16, 0.17, 0.20), 0.7)
	_box(prop, Vector3(0, 0.44, 0.02), Vector3(0.50, 0.06, 0.48), m)
	_box(prop, Vector3(0, 0.72, 0.24), Vector3(0.48, 0.52, 0.06), m)
	_cylinder(prop, Vector3(0, 0.22, 0.02), 0.045, 0.44, _mat(Color(0.30, 0.31, 0.34), 0.4, 0.6))
	for i in 5:
		var a := TAU * float(i) / 5.0
		var leg := _box(prop, Vector3(sin(a) * 0.13, 0.04, 0.02 + cos(a) * 0.13),
			Vector3(0.05, 0.04, 0.26), _mat(Color(0.22, 0.23, 0.26), 0.5))
		leg.rotation_degrees.y = rad_to_deg(a)
	if rig.seat_height <= 0.0:
		rig.seat_height = 0.46
	if rig.behaviour == "":
		rig.behaviour = "sit"


## Wooden rocking chair: curved runners, slatted back, arms. The rig rocks the
## whole character with it, which is most of the charm.
static func _rocker(prop: Node3D, rig: Node3D) -> void:
	var wood := _mat(Color(0.16, 0.30, 0.56), 0.7)
	var wood_light := _mat(Color(0.26, 0.44, 0.74), 0.7)
	var cushion := _mat(Color(0.80, 0.84, 0.92), 0.95)
	_phone_in_hand(rig, Color(0.10, 0.12, 0.18))

	# Runners: an arc approximated by seven short angled segments a side.
	for side in [-0.26, 0.26]:
		for i in 7:
			var t := (float(i) - 3.0) / 3.0          # -1 .. 1
			_box(prop, Vector3(side, 0.05 + t * t * 0.10, t * 0.42),
				Vector3(0.055, 0.06, 0.16), wood, Vector3(t * 26.0, 0, 0))

	# Legs up to the seat.
	for side in [-0.26, 0.26]:
		for z in [-0.22, 0.20]:
			_box(prop, Vector3(side, 0.26, z), Vector3(0.05, 0.38, 0.05), wood)

	_box(prop, Vector3(0, 0.455, 0.0), Vector3(0.60, 0.05, 0.52), wood_light)
	_box(prop, Vector3(0, 0.49, 0.0), Vector3(0.54, 0.04, 0.46), cushion)

	# Slatted back, leaning away.
	for side in [-0.27, 0.27]:
		_box(prop, Vector3(side, 0.78, 0.27), Vector3(0.05, 0.66, 0.05), wood, Vector3(-12, 0, 0))
	for i in 5:
		_box(prop, Vector3(-0.20 + i * 0.10, 0.78, 0.28), Vector3(0.045, 0.60, 0.03),
			wood_light, Vector3(-12, 0, 0))
	_box(prop, Vector3(0, 1.10, 0.20), Vector3(0.62, 0.07, 0.06), wood, Vector3(-12, 0, 0))

	# Armrests.
	for side in [-0.29, 0.29]:
		_box(prop, Vector3(side, 0.72, -0.02), Vector3(0.06, 0.05, 0.48), wood)
		_box(prop, Vector3(side, 0.60, -0.20), Vector3(0.05, 0.24, 0.05), wood)

	rig.seat_height = 0.47
	rig.behaviour = "rock"


static func _car(prop: Node3D, rig: Node3D) -> void:
	var body := _mat(Color(0.13, 0.32, 0.78), 0.25, 0.5)
	var glass := _mat(Color(0.35, 0.45, 0.55, 0.5), 0.1)
	var root := Node3D.new()
	root.position = Vector3(1.75, 0, 0.25)
	root.rotation_degrees.y = -12.0
	prop.add_child(root)

	_box(root, Vector3(0, 0.62, 0), Vector3(1.85, 0.55, 4.30), body)
	_box(root, Vector3(0, 1.02, 0.15), Vector3(1.62, 0.42, 2.10), body)
	_box(root, Vector3(0, 1.03, 0.14), Vector3(1.66, 0.34, 2.00), glass)
	_box(root, Vector3(0, 0.40, 0), Vector3(1.90, 0.16, 4.20), _mat(Color(0.08, 0.08, 0.09), 0.8))
	for sx in [-0.92, 0.92]:
		for sz in [-1.42, 1.42]:
			var wheel := _cylinder(root, Vector3(sx, 0.34, sz), 0.34, 0.22,
				_mat(Color(0.06, 0.06, 0.07), 0.9))
			wheel.rotation_degrees.z = 90.0
			var hub := _cylinder(wheel, Vector3(0, 0.113, 0), 0.19, 0.02,
				_mat(Color(0.72, 0.74, 0.78), 0.2, 0.9))
			hub.rotation_degrees = Vector3.ZERO
	var lamp := _glow(Color(1.0, 0.95, 0.85), 3.0)
	for sx in [-0.62, 0.62]:
		_box(root, Vector3(sx, 0.72, -2.14), Vector3(0.40, 0.16, 0.06), lamp)
		_box(root, Vector3(sx, 0.74, 2.14), Vector3(0.38, 0.14, 0.06), _glow(Color(1.0, 0.20, 0.15), 2.2))
	_light(prop, Vector3(1.75, 1.4, -1.6), Color(0.45, 0.60, 1.0), 1.6, 4.0)
	rig.animated["headlights"] = lamp
	rig.behaviour = "lean"


static func _sportbike(prop: Node3D, rig: Node3D) -> void:
	var root := Node3D.new()
	root.position = Vector3(1.15, 0, 0.15)
	root.rotation_degrees.y = -22.0
	prop.add_child(root)

	var fairing := _mat(Color(0.88, 0.10, 0.12), 0.15, 0.4)
	var trim := _mat(Color(0.07, 0.07, 0.08), 0.35)
	var chrome := _mat(Color(0.80, 0.82, 0.86), 0.12, 0.95)

	# Wheels, forks, swingarm.
	for entry in [[-0.72, 0.33], [0.78, 0.31]]:
		var wheel := _cylinder(root, Vector3(0, entry[1], entry[0]), entry[1], 0.13,
			_mat(Color(0.05, 0.05, 0.06), 0.9))
		wheel.rotation_degrees.z = 90.0
		for i in 5:
			var spoke := _box(wheel, Vector3(0, 0, 0), Vector3(entry[1] * 1.7, 0.14, 0.035), chrome)
			spoke.rotation_degrees = Vector3(0, 0, 0)
			spoke.rotate_y(TAU * float(i) / 5.0)
	_box(root, Vector3(0, 0.62, -0.62), Vector3(0.10, 0.62, 0.10), chrome, Vector3(24, 0, 0))
	_box(root, Vector3(0, 0.42, 0.55), Vector3(0.10, 0.10, 0.52), trim)

	# Body: tank, seat, tail, nose fairing.
	_box(root, Vector3(0, 0.70, 0.06), Vector3(0.34, 0.26, 0.62), fairing)
	_box(root, Vector3(0, 0.60, 0.20), Vector3(0.40, 0.22, 0.50), trim)
	_box(root, Vector3(0, 0.80, 0.44), Vector3(0.26, 0.12, 0.44), trim)
	_box(root, Vector3(0, 0.90, 0.58), Vector3(0.24, 0.18, 0.26), fairing, Vector3(-14, 0, 0))
	_box(root, Vector3(0, 0.86, -0.44), Vector3(0.36, 0.34, 0.40), fairing, Vector3(16, 0, 0))
	_box(root, Vector3(0, 1.02, -0.56), Vector3(0.26, 0.16, 0.22),
		_mat(Color(0.15, 0.20, 0.28, 0.65), 0.05), Vector3(28, 0, 0))
	var headlight := _glow(Color(1.0, 0.92, 0.75), 4.5)
	_box(root, Vector3(0, 0.84, -0.62), Vector3(0.22, 0.12, 0.06), headlight, Vector3(16, 0, 0))

	# Bars, mirrors, pipes.
	_box(root, Vector3(0, 0.98, -0.36), Vector3(0.58, 0.05, 0.05), chrome)
	for sx in [-0.30, 0.30]:
		_box(root, Vector3(sx, 1.10, -0.40), Vector3(0.03, 0.14, 0.03), trim)
		_box(root, Vector3(sx, 1.18, -0.40), Vector3(0.12, 0.07, 0.03), chrome)
	var pipe := _cylinder(root, Vector3(0.17, 0.42, 0.50), 0.075, 0.42, chrome)
	pipe.rotation_degrees = Vector3(90, 0, 0)
	_box(root, Vector3(0, 0.30, 0.06), Vector3(0.30, 0.24, 0.44), _mat(Color(0.30, 0.31, 0.34), 0.3, 0.8))

	_light(prop, Vector3(1.15, 0.9, -1.1), Color(1.0, 0.45, 0.35), 2.4, 3.5)
	_light(prop, Vector3(1.15, 1.2, 0.9), Color(0.4, 0.6, 1.0), 1.6, 3.0)
	rig.animated["headlights"] = headlight
	rig.behaviour = "lean"


static func _cats(prop: Node3D, rig: Node3D) -> void:
	var colors := [Color(0.86, 0.48, 0.16), Color(0.86, 0.48, 0.16), Color(0.10, 0.10, 0.12)]
	var orbit: Array[Node3D] = []
	for i in 3:
		var pivot := Node3D.new()
		pivot.rotation_degrees.y = 120.0 * float(i)
		prop.add_child(pivot)

		var cat := Node3D.new()
		cat.position = Vector3(0, 0, 0.78)
		pivot.add_child(cat)

		var fur := _mat(colors[i], 0.9)
		_box(cat, Vector3(0, 0.16, 0), Vector3(0.14, 0.15, 0.34), fur)
		var head := _box(cat, Vector3(0, 0.245, -0.20), Vector3(0.14, 0.13, 0.13), fur)
		_box(head, Vector3(-0.042, 0.082, 0.01), Vector3(0.045, 0.06, 0.02), fur, Vector3(0, 0, -14))
		_box(head, Vector3(0.042, 0.082, 0.01), Vector3(0.045, 0.06, 0.02), fur, Vector3(0, 0, 14))
		for sx in [-0.034, 0.034]:
			_box(head, Vector3(sx, 0.012, -0.066), Vector3(0.022, 0.016, 0.006),
				_glow(Color(0.75, 0.95, 0.35), 0.8))
		for sx in [-0.045, 0.045]:
			for sz in [-0.11, 0.11]:
				_box(cat, Vector3(sx, 0.045, sz), Vector3(0.04, 0.09, 0.045), fur)
		var tail := _box(cat, Vector3(0, 0.24, 0.19), Vector3(0.045, 0.045, 0.20), fur, Vector3(-38, 0, 0))
		orbit.append(pivot)
		rig.animated["tail_%d" % i] = tail
	rig.animated["cats"] = orbit
	rig.behaviour = "cats"


static func _art(prop: Node3D, rig: Node3D) -> void:
	var wood := _mat(Color(0.52, 0.36, 0.20), 0.85)
	_box(prop, Vector3(0.55, 0.62, -0.10), Vector3(0.06, 1.24, 0.06), wood, Vector3(10, 0, -6))
	_box(prop, Vector3(0.86, 0.62, -0.10), Vector3(0.06, 1.24, 0.06), wood, Vector3(10, 0, 6))
	_box(prop, Vector3(0.70, 0.30, 0.16), Vector3(0.06, 1.24, 0.06), wood, Vector3(-22, 0, 0))
	_box(prop, Vector3(0.70, 0.78, -0.14), Vector3(0.62, 0.03, 0.10), wood)

	var paper := _box(prop, Vector3(0.70, 1.06, -0.12), Vector3(0.52, 0.66, 0.012),
		_mat(Color(0.96, 0.95, 0.92), 0.9), Vector3(10, 0, 0))
	# Strokes appear one by one as the rig "draws".
	var strokes: Array[Node3D] = []
	var palette := [Color(0.90, 0.35, 0.30), Color(0.35, 0.60, 0.90), Color(0.95, 0.78, 0.30),
		Color(0.40, 0.75, 0.45), Color(0.65, 0.45, 0.85)]
	for i in 5:
		var s := _box(paper, Vector3(-0.16 + i * 0.08, -0.16 + sin(float(i)) * 0.10, -0.008),
			Vector3(0.045, 0.30 + sin(float(i) * 1.7) * 0.12, 0.004),
			_mat(palette[i], 0.85))
		s.visible = false
		strokes.append(s)

	var hand := _hand(rig)
	_box(hand, Vector3(0, -0.07, -0.02), Vector3(0.012, 0.13, 0.012), wood)
	rig.animated["hand"] = hand
	rig.animated["strokes"] = strokes
	rig.behaviour = "draw"


## Built inline rather than by recursing into CharacterBuilder — that would make
## the two classes reference each other, which GDScript handles badly. A toddler
## also isn't an adult at half scale: the head is enormous and the legs are
## stubby, so it wants its own proportions anyway.
static func _daughter(prop: Node3D, entry: Dictionary, rig: Node3D) -> void:
	var kid := Node3D.new()
	kid.position = Vector3(0.50, 0, 0.12)
	kid.rotation_degrees.y = -22.0
	prop.add_child(kid)

	var skin := _mat(entry.get("skin", Color(0.88, 0.72, 0.60)), 0.6)
	var top := _mat(Color(0.96, 0.62, 0.72), 0.85)
	var bottoms := _mat(Color(0.55, 0.62, 0.85), 0.88)
	var hair := _mat(Color(0.68, 0.50, 0.26), 0.78)

	for sx in [-0.048, 0.048]:
		_box(kid, Vector3(sx, 0.10, 0), Vector3(0.062, 0.20, 0.07), bottoms)
		_box(kid, Vector3(sx, 0.015, -0.015), Vector3(0.068, 0.045, 0.10),
			_mat(Color(0.92, 0.92, 0.94), 0.7))
	_box(kid, Vector3(0, 0.30, 0), Vector3(0.19, 0.22, 0.13), top)
	for sx in [-0.115, 0.115]:
		_box(kid, Vector3(sx, 0.30, 0), Vector3(0.05, 0.19, 0.055), top)
		_box(kid, Vector3(sx, 0.185, 0), Vector3(0.045, 0.05, 0.05), skin)
	_box(kid, Vector3(0, 0.425, 0), Vector3(0.055, 0.045, 0.055), skin)

	var head := Node3D.new()
	head.position = Vector3(0, 0.52, 0)
	kid.add_child(head)
	_box(head, Vector3(0, 0, 0.004), Vector3(0.155, 0.145, 0.15), skin)
	_box(head, Vector3(0, 0.072, 0.004), Vector3(0.162, 0.05, 0.158), hair)
	_box(head, Vector3(0, 0.05, 0.082), Vector3(0.05, 0.14, 0.05), hair)
	for sx in [-0.036, 0.036]:
		_box(head, Vector3(sx, 0.005, -0.072), Vector3(0.026, 0.022, 0.008),
			_mat(Color(0.96, 0.96, 0.97), 0.25))
		_box(head, Vector3(sx, 0.005, -0.077), Vector3(0.013, 0.016, 0.005),
			_mat(Color(0.20, 0.14, 0.10), 0.2))
	_box(head, Vector3(0, -0.042, -0.070), Vector3(0.034, 0.010, 0.008),
		_mat(Color(0.80, 0.45, 0.42), 0.6))

	rig.animated["kid"] = kid
	rig.behaviour = "child"


# ---------------------------------------------------------------------------

## A phone in the right hand, screen toward its owner. Same shape as the one
## everybody carries in a match, so a character posing with it reads as the
## same object.
static func _phone_in_hand(rig: Node3D, case_colour: Color) -> void:
	var hand := _hand(rig)
	var shell := _box(hand, Vector3(0, -0.095, -0.045), Vector3(0.076, 0.152, 0.013),
		_mat(case_colour, 0.25, 0.4), Vector3(-58, 0, 0))
	_box(shell, Vector3(0, 0, 0.0075), Vector3(0.066, 0.138, 0.002),
		_glow(Color(0.62, 0.80, 1.0), 1.5))
	_box(shell, Vector3(-0.019, 0.050, -0.008), Vector3(0.030, 0.036, 0.004),
		_mat(case_colour.darkened(0.3), 0.3))


## Right hand of the rig, used as a mount point for anything held.
static func _hand(rig: Node3D) -> Node3D:
	var hand: Node3D = rig.get_node_or_null("ArmR/Elbow/HandR")
	return hand if hand != null else rig


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	parent.add_child(m)
	return m


static func _cylinder(parent: Node3D, pos: Vector3, radius: float, height: float,
		mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 14
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	parent.add_child(m)
	return m


static func _light(parent: Node3D, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = false
	parent.add_child(l)


static func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(color, 0.3)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m
