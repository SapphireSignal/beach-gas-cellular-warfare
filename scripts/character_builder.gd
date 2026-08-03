extends Node
class_name CharacterBuilder
## Builds a human out of primitives.
##
## The trick to not looking like a blob is proportion and joints: a head that's
## roughly a seventh of the height, a real neck, shoulders wider than the waist,
## arms and legs split into two segments, and an actual face. Boxes are fine —
## the silhouette is what reads at distance, and the face is what reads up close.
##
## Limbs hang off pivot nodes so a character can be posed (seated) or animated
## without rebuilding anything.

const HEIGHT := 1.80
const RIG_SCRIPT := preload("res://scripts/character_rig.gd")


## Returns a Node3D rig. Named children worth knowing about:
##   Head, ArmL, ArmR, HandL, HandR, LegL, LegR, Prop
static func build(entry: Dictionary, with_prop := false) -> Node3D:
	var root := Node3D.new()
	root.set_script(RIG_SCRIPT)
	root.name = "Character"

	var female: bool = bool(entry.get("female", false))
	var skin: Color = entry.get("skin", Color(0.78, 0.60, 0.47))
	var shirt: Color = entry.get("shirt", Color(0.3, 0.3, 0.35))
	var pants: Color = entry.get("pants", Color(0.2, 0.2, 0.25))

	var m_skin := _mat(skin, 0.62)
	var m_shirt := _mat(shirt, 0.85)
	var m_pants := _mat(pants, 0.88)
	var m_shoe := _mat(Color(0.10, 0.10, 0.12), 0.7)
	var m_dark := _mat(Color(0.07, 0.07, 0.09), 0.55)

	# Everyone is the same height and shares one hitbox — the capsule in
	# player.tscn, which the model never touches. Build differences are kept
	# small deliberately: nobody should ever feel like a harder target.
	var shoulder_w := 0.435 if female else 0.46
	var chest_w := 0.362 if female else 0.385
	# Mounted clear of the ribcage, not inside it. Deriving this from the
	# shoulder width put the arms narrower than the chest they hang beside.
	var arm_x := chest_w * 0.5 + 0.055

	# --- torso -------------------------------------------------------------
	_box(root, Vector3(0, 0.94, 0), Vector3(0.32, 0.17, 0.20), m_pants)          # hips
	_box(root, Vector3(0, 1.11, 0), Vector3(chest_w - 0.05, 0.18, 0.185), m_shirt) # waist
	_box(root, Vector3(0, 1.31, 0), Vector3(chest_w, 0.26, 0.21), m_shirt)       # chest
	_box(root, Vector3(0, 1.44, 0), Vector3(shoulder_w, 0.10, 0.20), m_shirt)    # shoulders
	_box(root, Vector3(0, 1.02, 0), Vector3(0.33, 0.045, 0.205), m_dark)         # belt
	_box(root, Vector3(0, 1.50, 0), Vector3(0.095, 0.08, 0.095), m_skin)         # neck

	# --- legs --------------------------------------------------------------
	for side in [-1.0, 1.0]:
		var hip := Node3D.new()
		hip.name = "LegL" if side < 0.0 else "LegR"
		hip.position = Vector3(0.095 * side, 0.90, 0)
		root.add_child(hip)
		_box(hip, Vector3(0, -0.20, 0), Vector3(0.135, 0.40, 0.145), m_pants)

		var knee := Node3D.new()
		knee.name = "Knee"
		knee.position = Vector3(0, -0.40, 0)
		hip.add_child(knee)
		_box(knee, Vector3(0, -0.21, 0), Vector3(0.11, 0.42, 0.12), m_pants)
		_box(knee, Vector3(0, -0.425, -0.035), Vector3(0.118, 0.075, 0.255), m_shoe)
		_box(knee, Vector3(0, -0.455, -0.035), Vector3(0.125, 0.03, 0.265), m_dark)

	# --- arms --------------------------------------------------------------
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.name = "ArmL" if side < 0.0 else "ArmR"
		shoulder.position = Vector3(arm_x * side, 1.42, 0)
		root.add_child(shoulder)
		# Sleeve first, bare forearm below it — reads as clothing, not paint.
		_box(shoulder, Vector3(0, -0.10, 0), Vector3(0.098, 0.20, 0.105), m_shirt)
		_box(shoulder, Vector3(0, -0.235, 0), Vector3(0.085, 0.09, 0.092), m_skin)

		var elbow := Node3D.new()
		elbow.name = "Elbow"
		elbow.position = Vector3(0, -0.28, 0)
		shoulder.add_child(elbow)
		_box(elbow, Vector3(0, -0.13, 0), Vector3(0.082, 0.26, 0.088), m_skin)

		var hand := Node3D.new()
		hand.name = "HandL" if side < 0.0 else "HandR"
		hand.position = Vector3(0, -0.30, 0)
		elbow.add_child(hand)
		_box(hand, Vector3(0, -0.055, 0), Vector3(0.078, 0.11, 0.07), m_skin)

	# --- head --------------------------------------------------------------
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.56, 0)
	root.add_child(head)
	_build_head(head, entry, m_skin, skin)

	# Collapse each limb's boxes into one mesh. A character goes from ~55
	# instances to about eight, which with eight players on screen is the
	# difference between comfortable and not on a phone. Props are skipped —
	# their parts have to stay individually animatable.
	MeshMerge.merge_recursive(root, ["Prop"])

	# Everyone carries a faint drift of their own accent colour. Strong enough
	# on the select screen to read as a signature, dialled right down in a match
	# so it identifies people without turning them into beacons.
	add_aura(root, entry.get("accent", Color(0.9, 0.4, 0.4)),
		1.0 if with_prop else 0.4, str(entry.get("vibe", "chill")))

	if with_prop:
		var prop := Node3D.new()
		prop.name = "Prop"
		root.add_child(prop)
		CharacterProps.build(str(entry.get("prop", "none")), prop, entry, root)
		if bool(entry.get("seated", false)):
			pose_seated(root)
			# Only the body drops onto the seat — the furniture stays put.
			for child in root.get_children():
				if child.name != "Prop":
					child.position.y -= root.seat_height

	return root


## Everything from the neck up. Face detail is what stops these reading as
## mannequins, so it gets more geometry than anything else on the body.
static func _build_head(head: Node3D, entry: Dictionary, m_skin: StandardMaterial3D, skin: Color) -> void:
	var hair_color: Color = entry.get("hair", Color(0.2, 0.15, 0.1))
	var m_hair := _mat(hair_color, 0.78)
	var m_eye := _mat(Color(0.96, 0.96, 0.97), 0.25)
	var m_iris := _mat(Color(0.16, 0.12, 0.10), 0.2)
	var m_brow := _mat(hair_color.darkened(0.2), 0.8)
	var m_mouth := _mat(skin.darkened(0.45), 0.6)

	# Skull: a slightly narrower jaw under a wider cranium.
	_box(head, Vector3(0, 0.155, 0.005), Vector3(0.205, 0.14, 0.215), m_skin)
	_box(head, Vector3(0, 0.065, 0.0), Vector3(0.185, 0.10, 0.195), m_skin)
	_box(head, Vector3(0, 0.02, -0.005), Vector3(0.155, 0.05, 0.175), m_skin)   # chin
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.103 * side, 0.115, 0.01), Vector3(0.016, 0.055, 0.04), m_skin)  # ears

	# Face, front is -Z.
	for side in [-1.0, 1.0]:
		_box(head, Vector3(0.048 * side, 0.128, -0.101), Vector3(0.044, 0.026, 0.012), m_eye)
		_box(head, Vector3(0.048 * side, 0.128, -0.107), Vector3(0.018, 0.020, 0.008), m_iris)
		_box(head, Vector3(0.048 * side, 0.156, -0.100), Vector3(0.052, 0.012, 0.012), m_brow)
	_box(head, Vector3(0, 0.098, -0.104), Vector3(0.030, 0.045, 0.030), m_skin)   # nose
	_box(head, Vector3(0, 0.055, -0.098), Vector3(0.050, 0.012, 0.012), m_mouth)

	_build_hair(head, str(entry.get("hair_style", "short")), m_hair)

	for accessory in entry.get("accessories", []):
		_build_accessory(head, str(accessory), entry, m_hair)


static func _build_hair(head: Node3D, style: String, m_hair: StandardMaterial3D) -> void:
	match style:
		"buzz":
			_box(head, Vector3(0, 0.222, 0.005), Vector3(0.208, 0.04, 0.218), m_hair)
		"short":
			_box(head, Vector3(0, 0.232, 0.005), Vector3(0.215, 0.062, 0.225), m_hair)
			_box(head, Vector3(0, 0.175, 0.106), Vector3(0.19, 0.10, 0.03), m_hair)
		"curly":
			_box(head, Vector3(0, 0.225, 0.005), Vector3(0.20, 0.05, 0.21), m_hair)
			for i in 6:
				var a := TAU * float(i) / 6.0
				_sphere(head, Vector3(sin(a) * 0.085, 0.255 + cos(a * 2.0) * 0.018, cos(a) * 0.09),
					0.055, m_hair)
		"mohawk":
			for i in 7:
				var t := float(i) / 6.0
				var tall: float = 0.09 + sin(t * PI) * 0.15
				_box(head, Vector3(0, 0.215 + tall * 0.5, 0.10 - t * 0.20),
					Vector3(0.055, tall, 0.032), m_hair)
		"long":
			# Crown, a full sheet down the back, and curtains past the jaw. The
			# silhouette is what reads at distance, so it needs real volume.
			_box(head, Vector3(0, 0.240, 0.005), Vector3(0.224, 0.075, 0.234), m_hair)
			_box(head, Vector3(0, 0.190, 0.108), Vector3(0.222, 0.11, 0.055), m_hair)
			_box(head, Vector3(0, 0.020, 0.128), Vector3(0.226, 0.46, 0.060), m_hair)
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.108 * side, 0.135, 0.030), Vector3(0.042, 0.29, 0.215), m_hair)
				_box(head, Vector3(0.096 * side, 0.010, 0.075), Vector3(0.050, 0.22, 0.115), m_hair)
			_box(head, Vector3(0, 0.238, -0.098), Vector3(0.20, 0.055, 0.055), m_hair)   # fringe
		"ponytail":
			_box(head, Vector3(0, 0.238, 0.005), Vector3(0.220, 0.068, 0.230), m_hair)
			_box(head, Vector3(0, 0.180, 0.108), Vector3(0.190, 0.115, 0.042), m_hair)
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.106 * side, 0.165, 0.030), Vector3(0.036, 0.16, 0.200), m_hair)
			_box(head, Vector3(0, 0.095, 0.160), Vector3(0.082, 0.26, 0.082), m_hair,
				Vector3(12, 0, 0))
		"bun":
			# Swept up, but still obviously a full head of hair — the old version
			# was a skullcap and a ball, which read as bald from the front.
			_box(head, Vector3(0, 0.242, 0.005), Vector3(0.226, 0.080, 0.236), m_hair)
			_box(head, Vector3(0, 0.238, -0.100), Vector3(0.206, 0.062, 0.052), m_hair)
			_box(head, Vector3(0, 0.186, 0.110), Vector3(0.200, 0.120, 0.048), m_hair)
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.108 * side, 0.180, 0.020), Vector3(0.040, 0.145, 0.215), m_hair)
				# A strand escaping in front of the ear.
				_box(head, Vector3(0.100 * side, 0.095, -0.055), Vector3(0.024, 0.115, 0.030),
					m_hair, Vector3(0, 0, 6.0 * side))
			_sphere(head, Vector3(0, 0.250, 0.150), 0.072, m_hair)
			_box(head, Vector3(0, 0.250, 0.108), Vector3(0.070, 0.030, 0.060), m_hair)
		_:
			_box(head, Vector3(0, 0.232, 0.005), Vector3(0.215, 0.062, 0.225), m_hair)


static func _build_accessory(head: Node3D, kind: String, entry: Dictionary, m_hair: StandardMaterial3D) -> void:
	var accent: Color = entry.get("accent", Color(0.9, 0.3, 0.35))
	match kind:
		"cap":
			var cap_color: Color = entry.get("cap_color", accent.darkened(0.35))
			_box(head, Vector3(0, 0.262, 0.005), Vector3(0.228, 0.095, 0.238), _mat(cap_color, 0.8))
			_box(head, Vector3(0, 0.222, -0.16), Vector3(0.216, 0.022, 0.16),
				_mat(cap_color.darkened(0.25), 0.8))
			_box(head, Vector3(0, 0.308, 0.005), Vector3(0.03, 0.02, 0.03), _mat(accent, 0.7))
		"airpods":
			var m_pod := _mat(Color(0.96, 0.96, 0.97), 0.25)
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.108 * side, 0.118, 0.005), Vector3(0.026, 0.030, 0.026), m_pod)
				_box(head, Vector3(0.108 * side, 0.082, 0.012), Vector3(0.014, 0.048, 0.014), m_pod)
		"glasses":
			var m_frame := _mat(Color(0.09, 0.09, 0.11), 0.35)
			var m_lens := _mat(Color(0.55, 0.72, 0.85, 0.35), 0.1)
			m_lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.050 * side, 0.128, -0.112), Vector3(0.062, 0.050, 0.006), m_lens)
				_box(head, Vector3(0.050 * side, 0.153, -0.114), Vector3(0.066, 0.008, 0.008), m_frame)
				_box(head, Vector3(0.082 * side, 0.128, -0.06), Vector3(0.006, 0.008, 0.11), m_frame)
			_box(head, Vector3(0, 0.140, -0.114), Vector3(0.026, 0.007, 0.007), m_frame)
		"beard":
			_box(head, Vector3(0, 0.040, -0.072), Vector3(0.148, 0.075, 0.10), m_hair)
			for side in [-1.0, 1.0]:
				_box(head, Vector3(0.078 * side, 0.075, -0.02), Vector3(0.022, 0.09, 0.13), m_hair)
		"earrings":
			var m_gold := _mat(Color(0.95, 0.78, 0.30), 0.2, 0.85)
			for side in [-1.0, 1.0]:
				_sphere(head, Vector3(0.106 * side, 0.088, 0.012), 0.014, m_gold)


## Each character's own drift of accent-coloured motes. The style is what makes
## twelve people in the same clothes feel like twelve different people: Edward
## throws sparks, Josh hazes, Roger's are tight and digital, Kerissa's barely
## move. Unlit additive quads throughout — the cheapest particle a mobile GPU
## can draw.
static func add_aura(root: Node3D, colour: Color, intensity: float, style := "chill") -> void:
	if intensity <= 0.01:
		return
	var look := _aura_style(style)

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = look["extents"]
	process.direction = Vector3.UP
	process.spread = look["spread"]
	process.initial_velocity_min = look["speed_min"]
	process.initial_velocity_max = look["speed_max"]
	process.gravity = Vector3(0, look["rise"], 0)
	process.scale_min = 0.35
	process.scale_max = 1.1
	process.damping_min = 0.0
	process.damping_max = 0.6

	var ramp := Gradient.new()
	ramp.set_color(0, Color(colour.r, colour.g, colour.b, 0.0))
	ramp.add_point(0.32, Color(colour.r, colour.g, colour.b, float(look["alpha"]) * intensity))
	ramp.set_color(1, Color(colour.r, colour.g, colour.b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(look["size"], look["size"])
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_receive_shadows = true
	quad.material = mat

	var aura := GPUParticles3D.new()
	aura.name = "Aura"
	aura.amount = maxi(4, int(float(look["count"]) * intensity))
	aura.lifetime = look["life"]
	aura.preprocess = float(look["life"]) * 0.6
	aura.position = Vector3(0, 0.95, 0)
	aura.process_material = process
	aura.draw_pass_1 = quad
	root.add_child(aura)


static func _aura_style(style: String) -> Dictionary:
	match style:
		"smoke":
			return {"count": 10, "size": 0.105, "speed_min": 0.04, "speed_max": 0.17,
				"spread": 28.0, "rise": 0.10, "life": 3.6, "alpha": 0.30,
				"extents": Vector3(0.30, 0.90, 0.26)}
		"sparks":
			return {"count": 15, "size": 0.021, "speed_min": 0.40, "speed_max": 1.05,
				"spread": 58.0, "rise": -0.55, "life": 1.3, "alpha": 1.0,
				"extents": Vector3(0.34, 0.92, 0.28)}
		"tech":
			return {"count": 15, "size": 0.019, "speed_min": 0.20, "speed_max": 0.48,
				"spread": 9.0, "rise": 0.22, "life": 2.0, "alpha": 0.95,
				"extents": Vector3(0.42, 1.02, 0.34)}
		"buzz":
			return {"count": 13, "size": 0.030, "speed_min": 0.30, "speed_max": 0.75,
				"spread": 44.0, "rise": 0.05, "life": 1.2, "alpha": 0.92,
				"extents": Vector3(0.32, 0.86, 0.26)}
		"warm":
			return {"count": 10, "size": 0.048, "speed_min": 0.05, "speed_max": 0.20,
				"spread": 22.0, "rise": 0.08, "life": 3.2, "alpha": 0.70,
				"extents": Vector3(0.38, 0.92, 0.30)}
		"paint":
			return {"count": 12, "size": 0.040, "speed_min": 0.14, "speed_max": 0.52,
				"spread": 48.0, "rise": -0.10, "life": 2.4, "alpha": 0.90,
				"extents": Vector3(0.40, 0.95, 0.32)}
		"calm":
			return {"count": 8, "size": 0.056, "speed_min": 0.025, "speed_max": 0.11,
				"spread": 15.0, "rise": 0.03, "life": 4.4, "alpha": 0.55,
				"extents": Vector3(0.44, 1.00, 0.36)}
		_:
			return {"count": 10, "size": 0.034, "speed_min": 0.10, "speed_max": 0.32,
				"spread": 18.0, "rise": 0.06, "life": 2.6, "alpha": 0.85,
				"extents": Vector3(0.32, 0.86, 0.26)}


## Fold the legs for a character who's sitting down. Returns the height the rig
## should be dropped by so the backside lands on the seat.
static func pose_seated(rig: Node3D) -> float:
	# Positive X swings a hanging limb forward, negative swings it back. The
	# thigh goes forward off the hip; the shin then folds back down under it.
	for leg_name in ["LegL", "LegR"]:
		var hip: Node3D = rig.get_node_or_null(leg_name)
		if hip == null:
			continue
		hip.rotation_degrees.x = 86.0
		var knee: Node3D = hip.get_node_or_null("Knee")
		if knee != null:
			knee.rotation_degrees.x = -84.0
	for arm_name in ["ArmL", "ArmR"]:
		var shoulder: Node3D = rig.get_node_or_null(arm_name)
		if shoulder != null:
			shoulder.rotation_degrees.x = 16.0
	return 0.42


# ---------------------------------------------------------------------------

static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	# Eight players' worth of eyebrows and earrings casting shadows buys nothing
	# and costs a shadow-map draw each. The body silhouette is enough.
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


static func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
