extends Node3D
## Live 3D behind the main menu: the actual map, filmed.
##
## It loads the same level the game plays on rather than a picture of it, so it
## can never go stale — change a wall in world.gd and the menu shows the new
## wall. Collision is skipped, since nothing is going to walk around in here.
##
## Shots are slow dollies with a fixed look target, cut together with a short
## fade to black that menu.gd draws on top.

## Which map the menu films. Its own constant so the shot checker and the
## backdrop can never disagree about what they are testing.
const BACKDROP_MAP := "beach_gas_real"

const SHOT_SECONDS := 9.0
const FADE_SECONDS := 1.1

## Each shot dollies `from` -> `to` while looking at `look`.
const SHOTS: Array[Dictionary] = [
	{   # High and wide across the whole clearing, forest on the far side.
		"from": Vector3(30.0, 13.0, 30.0), "to": Vector3(20.0, 11.5, 22.0),
		"look": Vector3(-4.0, 2.4, -2.0), "fov": 58.0,
	},
	{   # Low, down the lane between the two pump islands.
		"from": Vector3(0.0, 1.7, 16.0), "to": Vector3(0.0, 1.8, 7.0),
		"look": Vector3(0.0, 2.2, -6.0), "fov": 66.0,
	},
	{   # Tracking across the front of the store toward Summerleaf.
		"from": Vector3(-26.0, 2.0, -6.0), "to": Vector3(-18.0, 2.0, -6.0),
		"look": Vector3(4.0, 2.6, -13.0), "fov": 60.0,
	},
	{   # Past the tanks, looking back at the forecourt.
		"from": Vector3(-31.6, 2.2, 5.4), "to": Vector3(-28.6, 2.4, 11.4),
		"look": Vector3(6.0, 2.0, -2.0), "fov": 62.0,
	},
	{   # Up at the pylon sign from the road side.
		"from": Vector3(24.0, 1.6, 28.0), "to": Vector3(21.0, 2.2, 26.0),
		"look": Vector3(20.0, 4.2, 23.0), "fov": 54.0,
	},
	{   # Wide from the east, the whole lot with the forest behind it.
		"from": Vector3(34.0, 2.6, -6.0), "to": Vector3(28.0, 2.8, 2.0),
		"look": Vector3(-14.0, 3.0, -12.0), "fov": 60.0,
	},
]

## 0 = fully visible, 1 = black. menu.gd reads this each frame.
var fade := 1.0

var _camera: Camera3D
var _shot := 0
var _elapsed := 0.0


func _ready() -> void:
	# The backdrop always shows the real station, whichever map is selected in
	# the lobby — it's the one built from photographs, and a menu that opens on
	# the actual place says more than one that opens on the fictional one.
	var world = load(Maps.scene_path(BACKDROP_MAP)).instantiate()
	world.decorative = true
	add_child(world)

	_camera = Camera3D.new()
	_camera.current = true
	add_child(_camera)

	_shot = randi() % SHOTS.size()
	_apply(0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= SHOT_SECONDS:
		_elapsed = 0.0
		_shot = (_shot + 1) % SHOTS.size()

	# Black at both ends of a shot's window, clear through the middle.
	var rising: float = clampf(_elapsed / FADE_SECONDS, 0.0, 1.0)
	var falling: float = clampf((SHOT_SECONDS - _elapsed) / FADE_SECONDS, 0.0, 1.0)
	fade = 1.0 - minf(rising, falling)

	_apply(_elapsed / SHOT_SECONDS)


func _apply(t: float) -> void:
	if _camera == null:
		return
	var shot: Dictionary = SHOTS[_shot]
	# Ease the dolly so it drifts rather than tracking at a constant clip.
	var eased: float = t * t * (3.0 - 2.0 * t)
	_camera.global_position = Vector3(shot["from"]).lerp(Vector3(shot["to"]), eased)
	_camera.fov = float(shot["fov"])
	var target := Vector3(shot["look"])
	if _camera.global_position.distance_to(target) > 0.1:
		_camera.look_at(target, Vector3.UP)
