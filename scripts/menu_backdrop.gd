extends Node3D
## Live 3D behind the main menu: the actual map, filmed.
##
## It loads the same level the game plays on rather than a picture of it, so it
## can never go stale — change a wall in world.gd and the menu shows the new
## wall. Collision is skipped, since nothing is going to walk around in here.
##
## Shots are slow dollies with a fixed look target, cut together with a short
## fade to black that menu.gd draws on top.

const SHOT_SECONDS := 9.0
const FADE_SECONDS := 1.1

## Each shot dollies `from` -> `to` while looking at `look`.
const SHOTS: Array[Dictionary] = [
	{   # Wide establishing view across the whole forecourt.
		"from": Vector3(23.0, 11.0, 21.0), "to": Vector3(13.0, 9.5, 16.0),
		"look": Vector3(-10.0, 6.5, 0.0), "fov": 60.0,
	},
	{   # Low, down the lane between the pump islands.
		"from": Vector3(5.0, 1.7, 4.5) , "to": Vector3(-3.0, 1.8, 4.2),
		"look": Vector3(-21.0, 1.7, 4.0), "fov": 68.0,
	},
	{   # Inside the store, looking out through the glass.
		"from": Vector3(-14.4, 1.7, -17.1), "to": Vector3(-14.4, 1.7, -13.1),
		"look": Vector3(-12.0, 1.5, -3.0), "fov": 64.0,
	},
	{   # Past the plant tables into Summerleaf.
		"from": Vector3(19.5, 1.7, -1.5), "to": Vector3(19.2, 1.7, -6.2),
		"look": Vector3(19.0, 2.2, -20.0), "fov": 62.0,
	},
	{   # Looking up at the pylon sign.
		"from": Vector3(-19.5, 1.3, 15.5), "to": Vector3(-22.5, 1.7, 18.0),
		"look": Vector3(-28.0, 7.6, 20.0), "fov": 55.0,
	},
	{   # Along the parking rows toward the store.
		"from": Vector3(30.0, 2.4, 21.0), "to": Vector3(24.0, 2.6, 14.0),
		"look": Vector3(-8.0, 3.0, 2.0), "fov": 60.0,
	},
]

## 0 = fully visible, 1 = black. menu.gd reads this each frame.
var fade := 1.0

var _camera: Camera3D
var _shot := 0
var _elapsed := 0.0


func _ready() -> void:
	# The backdrop always shows Beach Gas: these camera moves are framed for it,
	# and the menu should look the same whichever map is selected in the lobby.
	var world = load(Maps.scene_path(Maps.DEFAULT_ID)).instantiate()
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
