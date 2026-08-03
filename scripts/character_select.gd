extends SubViewportContainer
## Live 3D turntable of the selected character, posed with whatever they're
## doing, rendered into the menu.
##
## It builds the real rig rather than showing a picture, so a character can
## never look different here than they do in a match — and the props (bike,
## cats, computer) only ever exist on this screen.

const TURN_SPEED := 0.32

## How far back the camera needs to sit for each prop to fit in frame.
const FRAMING := {
	"sportbike": {"distance": 5.2, "height": 1.6, "target": 1.05},
	"car": {"distance": 7.4, "height": 2.3, "target": 1.15},
	"computer": {"distance": 4.2, "height": 1.5, "target": 0.95},
	"art": {"distance": 4.0, "height": 1.5, "target": 1.05},
	"cats": {"distance": 3.9, "height": 1.4, "target": 0.90},
	"daughter": {"distance": 3.4, "height": 1.4, "target": 0.95},
	"mcdonalds": {"distance": 3.4, "height": 1.4, "target": 1.00},
	"chair": {"distance": 3.2, "height": 1.3, "target": 0.85},
	# These three have shopping on the floor beside them, which the default
	# framing cropped straight off the edge of the disc.
	"joint": {"distance": 3.4, "height": 1.4, "target": 0.95},
	"music": {"distance": 3.5, "height": 1.45, "target": 1.00},
	"monster": {"distance": 3.3, "height": 1.4, "target": 0.95},
}
const DEFAULT_FRAMING := {"distance": 2.9, "height": 1.35, "target": 1.05}

var _viewport: SubViewport
var _camera: Camera3D
var _turntable: Node3D
var _rig: Node3D
var _rim: DirectionalLight3D
var _ring_mat: StandardMaterial3D
var _disc_mat: StandardMaterial3D
var _index := -1


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_viewport = SubViewport.new()
	# Its own world, or it would inherit the menu backdrop's gas station.
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	_build_stage()
	show_character(Loadout.character_index)


func _process(delta: float) -> void:
	if _turntable != null:
		_turntable.rotate_y(delta * TURN_SPEED)


## Disabling _process alone doesn't stop a SubViewport rendering — it keeps
## drawing a 3D scene nobody is looking at. This turns the render target off
## with the panel.
func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if _viewport != null:
		_viewport.render_target_update_mode = (SubViewport.UPDATE_ALWAYS if active
			else SubViewport.UPDATE_DISABLED)


func show_character(index: int) -> void:
	if index == _index:
		return
	_index = index
	if _rig != null:
		_rig.queue_free()
		_rig = null

	# Reset the turntable so a new pick always starts face-on. Without this you
	# land on whatever angle the previous character happened to be spun to,
	# which is often the back of their head.
	_turntable.rotation = Vector3.ZERO

	var entry := Characters.get_entry(index)
	_rig = CharacterBuilder.build(entry, true)
	_rig.idle = true             # only the select screen animates
	_rig.rotation_degrees.y = 172.0   # facing camera, a few degrees off square
	_turntable.add_child(_rig)

	var frame: Dictionary = FRAMING.get(str(entry.get("prop", "none")), DEFAULT_FRAMING)
	_camera.position = Vector3(0, float(frame["height"]), float(frame["distance"]))
	_camera.look_at(Vector3(0, float(frame["target"]), 0), Vector3.UP)

	# The whole stage takes their colour — rim light, platform edge, floor glow.
	# It's the cheapest way to make twelve people on the same disc feel like
	# twelve different people rather than a lineup.
	var accent: Color = entry.get("accent", Color(0.5, 0.7, 1.0))
	if _rim != null:
		_rim.light_color = accent.lerp(Color(0.6, 0.7, 1.0), 0.35)
	if _ring_mat != null:
		_ring_mat.albedo_color = accent
		_ring_mat.emission = accent
	if _disc_mat != null:
		_disc_mat.albedo_color = Color(0.08, 0.09, 0.13).lerp(accent, 0.16)


## A small studio: key light, cool fill, warm rim, and a lit disc to stand on.
func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.045, 0.065)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	if Settings.glow_enabled():
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.1
		env.set_glow_level(1, 1.0)
		env.set_glow_level(2, 0.6)

	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32.0, 38.0, 0.0)
	key.light_energy = 1.5
	key.light_color = Color(1.0, 0.94, 0.86)
	key.shadow_enabled = false
	_viewport.add_child(key)

	_rim = DirectionalLight3D.new()
	_rim.rotation_degrees = Vector3(-14.0, -150.0, 0.0)
	_rim.light_energy = 1.1
	_rim.light_color = Color(0.45, 0.62, 1.0)
	_rim.shadow_enabled = false
	_viewport.add_child(_rim)

	_turntable = Node3D.new()
	_viewport.add_child(_turntable)

	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.35
	cyl.bottom_radius = 1.5
	cyl.height = 0.06
	cyl.radial_segments = 32
	disc.mesh = cyl
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.albedo_color = Color(0.10, 0.12, 0.17)
	_disc_mat.roughness = 0.35
	_disc_mat.metallic = 0.5
	disc.mesh.material = _disc_mat
	disc.position = Vector3(0, -0.03, 0)
	_turntable.add_child(disc)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.46
	torus.outer_radius = 1.54
	torus.rings = 24
	torus.ring_segments = 6
	ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Loadout.accent()
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Loadout.accent()
	_ring_mat.emission_energy_multiplier = 2.0
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.mesh.material = _ring_mat
	ring.position = Vector3(0, 0.01, 0)
	_turntable.add_child(ring)

	_camera = Camera3D.new()
	_camera.fov = 42.0
	_camera.current = true
	_viewport.add_child(_camera)
