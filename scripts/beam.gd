extends Node
class_name Beam
## Impact effects for the laser.
##
## Mobile budget: one short-lived particle node per hit, ten quads or fewer,
## unlit and additive. Quads are close to free on mobile GPUs; meshes are not.
## Surface decides the look — sparks off metal, dust off concrete, a red mist
## off a person — which is most of what makes shooting read as physical.

const LIFETIME := 0.34
const MAX_PARTICLES := 10

## Built once per style and reused. Creating a ParticleProcessMaterial per hit
## forces a fresh material setup on the GPU every shot, which is exactly the
## kind of thing that stutters on a phone.
static var _cache: Dictionary = {}

## World material key -> impact style.
const SURFACES := {
	"metal": "spark", "dark_metal": "spark", "cooler": "spark",
	"sign": "spark", "sign_white": "spark", "lamp": "spark",
	"wall": "dust", "curb": "dust", "asphalt": "dust", "trim": "dust",
	"shelf": "splinter", "stock": "splinter",
	"hedge": "leaf", "glass": "glass",
}


## How many bursts and flashes are kept alive per world. Eight players firing
## every fifth of a second never has more than a handful in the air at once.
const POOL := 10


static func impact(parent: Node3D, at: Vector3, normal: Vector3, surface: String,
		hit_player: bool) -> void:
	if not is_instance_valid(parent):
		return
	var style := "flesh" if hit_player else str(SURFACES.get(surface, "dust"))
	var look := _style(style)
	var assets := _assets(style, look)
	var process: ParticleProcessMaterial = assets["process"]

	# Only the spray direction changes per hit; everything else is shared.
	process.direction = normal if normal.length_squared() > 0.01 else Vector3.UP

	var burst := _take(parent, "Bursts", POOL, _make_burst)
	if burst == null:
		return
	burst.draw_pass_1 = assets["quad"]
	burst.process_material = process
	burst.amount = mini(int(look["count"]), MAX_PARTICLES)
	burst.global_position = at
	burst.restart()

	_flash(parent, at, look["hot"], hit_player)


## A brief bright point at the contact, so a hit registers even at a distance
## where individual particles are a couple of pixels.
static func _flash(parent: Node3D, at: Vector3, color: Color, hit_player: bool) -> void:
	var flash := _take(parent, "Flashes", POOL, _make_flash)
	if flash == null:
		return
	var mat: StandardMaterial3D = flash.material_override
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	flash.mesh = _flash_mesh(hit_player)
	flash.global_position = at
	flash.scale = Vector3.ONE * 0.5
	flash.visible = true

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.6, 0.13)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.13)
	tween.chain().tween_callback(func(): flash.visible = false)


static func _flash_mesh(hit_player: bool) -> QuadMesh:
	var key := "flash_%s" % ("player" if hit_player else "world")
	if not _cache.has(key):
		var shared := QuadMesh.new()
		shared.size = Vector2(0.34, 0.34) if hit_player else Vector2(0.22, 0.22)
		_cache[key] = shared
	return _cache[key]


## Next node from a ring buffer of reusable effect nodes, built once per world.
##
## These used to be created and freed per shot. A GPUParticles3D in particular
## is not a cheap node to build — it allocates its own GPU buffers — and doing
## that on every trigger pull is exactly the kind of cost that shows up as a
## stutter when you shoot rather than as a lower framerate.
##
## The pool hangs off the world, so it dies with the level and there's nothing
## to clean up by hand.
static func _take(parent: Node3D, group: String, size: int, make: Callable) -> Node3D:
	var root := parent.get_node_or_null(group)
	if root == null:
		root = Node3D.new()
		root.name = group
		parent.add_child(root)
	var index := int(root.get_meta("next", 0))
	root.set_meta("next", (index + 1) % size)
	if index < root.get_child_count():
		return root.get_child(index)
	var made: Node3D = make.call()
	root.add_child(made)
	return made


static func _make_burst() -> Node3D:
	var burst := GPUParticles3D.new()
	burst.lifetime = LIFETIME
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.emitting = false
	burst.local_coords = false
	return burst


static func _make_flash() -> Node3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.disable_receive_shadows = true

	var flash := MeshInstance3D.new()
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	return flash


static func _assets(style: String, look: Dictionary) -> Dictionary:
	if _cache.has(style):
		return _cache[style]

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.04
	process.spread = look["spread"]
	process.initial_velocity_min = look["speed"] * 0.4
	process.initial_velocity_max = look["speed"]
	process.gravity = Vector3(0, look["gravity"], 0)
	process.damping_min = look["damping"] * 0.6
	process.damping_max = look["damping"]
	process.scale_min = 0.5
	process.scale_max = 1.3

	var ramp := Gradient.new()
	ramp.set_color(0, look["hot"])
	ramp.set_color(1, Color(look["cool"].r, look["cool"].g, look["cool"].b, 0.0))
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	process.color_ramp = ramp_tex

	var quad := QuadMesh.new()
	quad.size = look["size"]
	quad.material = _quad_material(bool(look["additive"]))

	_cache[style] = {"process": process, "quad": quad}
	return _cache[style]


static func _quad_material(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_receive_shadows = true
	return m


static func _style(kind: String) -> Dictionary:
	match kind:
		"spark":
			return {"count": 10, "speed": 4.5, "spread": 42.0, "gravity": -6.0, "damping": 5.0,
				"hot": Color(1.0, 0.95, 0.70, 1.0), "cool": Color(1.0, 0.45, 0.10),
				"size": Vector2(0.03, 0.03), "additive": true}
		"dust":
			return {"count": 8, "speed": 1.6, "spread": 58.0, "gravity": -1.2, "damping": 3.0,
				"hot": Color(0.62, 0.60, 0.58, 0.75), "cool": Color(0.45, 0.44, 0.44),
				"size": Vector2(0.09, 0.09), "additive": false}
		"splinter":
			return {"count": 8, "speed": 2.6, "spread": 48.0, "gravity": -5.0, "damping": 4.0,
				"hot": Color(0.72, 0.58, 0.38, 0.9), "cool": Color(0.45, 0.34, 0.22),
				"size": Vector2(0.045, 0.045), "additive": false}
		"leaf":
			return {"count": 7, "speed": 2.0, "spread": 60.0, "gravity": -3.0, "damping": 4.5,
				"hot": Color(0.30, 0.52, 0.28, 0.9), "cool": Color(0.18, 0.30, 0.18),
				"size": Vector2(0.06, 0.06), "additive": false}
		"glass":
			return {"count": 9, "speed": 3.4, "spread": 50.0, "gravity": -7.0, "damping": 3.5,
				"hot": Color(0.85, 0.94, 1.0, 0.95), "cool": Color(0.55, 0.72, 0.88),
				"size": Vector2(0.035, 0.035), "additive": true}
		_:
			return {"count": 10, "speed": 3.0, "spread": 46.0, "gravity": -3.5, "damping": 4.0,
				"hot": Color(1.0, 0.35, 0.32, 1.0), "cool": Color(0.55, 0.06, 0.08),
				"size": Vector2(0.05, 0.05), "additive": false}
