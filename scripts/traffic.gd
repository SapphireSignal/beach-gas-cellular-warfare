extends Node3D
## Cars that pull in, sit at a pump for a bit, and leave.
##
## Purely ambient — traffic has no collision. A two-tonne box moving at 5m/s
## through the exact lanes people fight in would shove players into geometry and
## block doorways, and any drift between machines would mean one player's shot
## is eaten by a car another player can't see. Cosmetic is all upside.
##
## The host decides when a car arrives and broadcasts it; every peer then drives
## it along the same fixed path locally. One tiny reliable packet every fifteen
## seconds or so, and no per-frame position sync at all.

const SPEED := 5.6
const APPROACH_SPEED := 2.4
const ARRIVE_DISTANCE := 0.7
const GAP_MIN := 11.0
const GAP_MAX := 24.0
const WAIT_MIN := 10.0
const WAIT_MAX := 20.0
const MAX_CARS := 3

## Each route drives in off the road, stops beside a pump, then carries on out.
## Index 3 is always the stop, so a car never reverses.
## Lanes sit between and outside the two pump islands (z = 0.5 and 7.5).
const ROUTES: Array[Array] = [
	[Vector3(29, 0, 36), Vector3(29, 0, 4.0), Vector3(13, 0, 4.0), Vector3(0, 0, 4.0),
		Vector3(-9, 0, 4.0), Vector3(-9, 0, 20), Vector3(-9, 0, 36)],
	[Vector3(34, 0, -2.5), Vector3(20, 0, -2.5), Vector3(9, 0, -2.5), Vector3(-3, 0, -2.5),
		Vector3(-10, 0, -2.5), Vector3(-10, 0, 20), Vector3(-10, 0, 36)],
	[Vector3(23, 0, 36), Vector3(23, 0, 10.8), Vector3(10, 0, 10.8), Vector3(-2, 0, 10.8),
		Vector3(-12, 0, 10.8), Vector3(-12, 0, 22), Vector3(-12, 0, 36)],
]
const STOP_INDEX := 3


## Routes come from the map when it offers its own, so a level with a different
## road isn't stuck driving cars through the fictional forecourt's lanes.
func _routes() -> Array:
	if world != null and world.has_method("traffic_routes"):
		var custom: Array = world.traffic_routes()
		if not custom.is_empty():
			return custom
	return ROUTES

const COLOURS: Array[Color] = [
	Color(0.78, 0.78, 0.80), Color(0.14, 0.15, 0.18), Color(0.65, 0.18, 0.16),
	Color(0.18, 0.32, 0.62), Color(0.32, 0.40, 0.34), Color(0.72, 0.60, 0.24),
	Color(0.45, 0.46, 0.50),
]

var world: Node3D = null
var local_only := false     ## menu backdrop: drive without any networking

var _cars: Array = []
var _next_spawn := 6.0
var _clock := 0.0
## Colour index -> a hidden, already-merged car to copy from.
var _templates: Dictionary = {}


func _process(delta: float) -> void:
	_clock += delta
	_drive(delta)

	if not _may_spawn():
		return
	if _clock < _next_spawn or _cars.size() >= MAX_CARS:
		return
	_next_spawn = _clock + randf_range(GAP_MIN, GAP_MAX)

	var route := randi() % _routes().size()
	var colour := randi() % COLOURS.size()
	var wait := randf_range(WAIT_MIN, WAIT_MAX)
	if local_only:
		_arrive(route, colour, wait)
	else:
		_arrive.rpc(route, colour, wait)


## Only the host schedules arrivals, so everyone sees the same cars.
func _may_spawn() -> bool:
	if local_only:
		return true
	return (multiplayer.multiplayer_peer != null and multiplayer.is_server()
		and Net.in_match)


@rpc("authority", "call_local", "reliable")
func _arrive(route_index: int, colour_index: int, wait_seconds: float) -> void:
	if world == null or not world.has_method("build_car"):
		return
	var path: Array = _routes()[route_index % _routes().size()]
	var car := _car_of_colour(colour_index % COLOURS.size())
	if car == null:
		return
	add_child(car)

	car.global_position = path[0]
	car.look_at(path[1], Vector3.UP)

	_cars.append({
		"node": car,
		"path": path,
		"index": 1,
		"wait_until": -1.0,
		"wait_for": wait_seconds,
	})


func _drive(delta: float) -> void:
	var finished := []
	for car in _cars:
		var node: Node3D = car["node"]
		if not is_instance_valid(node):
			finished.append(car)
			continue

		# Parked at the pump.
		if float(car["wait_until"]) > 0.0:
			if _clock < float(car["wait_until"]):
				continue
			car["wait_until"] = -1.0
			car["index"] = int(car["index"]) + 1

		var path: Array = car["path"]
		var index: int = car["index"]
		if index >= path.size():
			node.queue_free()
			finished.append(car)
			continue

		var target: Vector3 = path[index]
		var offset := target - node.global_position
		offset.y = 0.0
		var distance := offset.length()

		if distance < ARRIVE_DISTANCE:
			if index == STOP_INDEX:
				car["wait_until"] = _clock + float(car["wait_for"])
			else:
				car["index"] = index + 1
			continue

		# Ease off on the approach to the pump and out of the final turn.
		var speed := SPEED
		if index == STOP_INDEX:
			speed = lerpf(APPROACH_SPEED, SPEED, clampf(distance / 9.0, 0.0, 1.0))
		node.global_position += offset.normalized() * speed * delta

		# Steer rather than snap, so corners look driven.
		var want := atan2(-offset.x, -offset.z)
		node.rotation.y = lerp_angle(node.rotation.y, want, minf(1.0, delta * 2.4))

	for car in finished:
		_cars.erase(car)


## A car of the given colour, ready to drive.
##
## The first one of each colour is built the slow way — thirty boxes, their
## colliders thrown straight back away, then a SurfaceTool merge — and kept as a
## hidden template. Every later arrival is a duplicate of that template, which
## shares the merged mesh and costs a handful of nodes. Doing the full build
## every time meant a frame-long hitch every fifteen seconds or so, which on a
## phone is exactly the kind of stutter people notice and framerate graphs miss.
func _car_of_colour(index: int) -> Node3D:
	if not _templates.has(index):
		var built: Node3D = world.build_car(COLOURS[index])
		_strip_collision(built)
		MeshMerge.merge_tree(built)

		# merge_tree only *queues* the originals for deletion, so this frame the
		# car still has all thirty of them hanging off it. Lift the merged
		# meshes into a clean root rather than duplicating that.
		var template := Node3D.new()
		template.name = "Template%d" % index
		template.visible = false
		for child in built.get_children():
			if child is MeshInstance3D and not child.is_queued_for_deletion():
				built.remove_child(child)
				template.add_child(child)
		built.queue_free()
		add_child(template)
		_templates[index] = template

	var car: Node3D = (_templates[index] as Node3D).duplicate()
	car.visible = true
	return car


## Traffic is decoration. Nothing about it should ever be solid.
static func _strip_collision(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			child.queue_free()
		else:
			_strip_collision(child)
