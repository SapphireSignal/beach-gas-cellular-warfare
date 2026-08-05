extends SceneTree
## Checks the menu backdrop's camera shots against the real level geometry.
##
##     "$GODOT" --headless --path . --script res://tools/check_shots.gd
##
## The backdrop builds with `decorative = true`, which skips every collision
## shape — so at runtime there is nothing for a camera to detect and nothing
## stopping a shot from dollying straight through a wall. Adding collision back
## just for the menu would undo the launch-time work, so instead this builds the
## level *with* collision once, offline, and reports which shots are bad.
##
## Two failure modes, and they look different on screen:
##
##   INSIDE    the camera is within solid geometry — the view fills with the
##             inside face of a wall, or goes black
##   BLOCKED   the camera is in open air but something sits between it and what
##             it is looking at, so the shot is of a wall rather than the lot
##
## Fix the numbers in menu_backdrop.gd and rerun until it comes back clean.

const BACKDROP := preload("res://scripts/menu_backdrop.gd")

## How far along the dolly to sample. The ends are where shots usually go wrong,
## but a path can dip through a pump island in the middle and look fine at both.
const SAMPLES := 9
## Camera near plane is small, but geometry within this of the lens still reads
## as "we are inside something".
const CLEARANCE := 0.6


func _initialize() -> void:
	var world = load(Maps.scene_path(Maps.DEFAULT_ID)).instantiate()
	world.decorative = false        # the whole point: we want the collision
	root.add_child(world)

	# Physics needs a tick before queries return anything.
	await process_frame
	await physics_frame
	await physics_frame

	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shots: Array = BACKDROP.SHOTS
	var bad := 0

	print("checking %d backdrop shots against Beach Gas geometry" % shots.size())
	print("")

	for i in shots.size():
		var shot: Dictionary = shots[i]
		var from := Vector3(shot["from"])
		var to := Vector3(shot["to"])
		var look := Vector3(shot["look"])

		var inside: Array[float] = []
		var blocked: Array[float] = []

		for s in SAMPLES:
			var t := float(s) / float(SAMPLES - 1)
			var eased := t * t * (3.0 - 2.0 * t)
			var pos := from.lerp(to, eased)

			# Is the lens itself buried? A tiny sphere is a better test than a
			# point — a camera 10cm inside a wall still shows the wall.
			var shape := SphereShape3D.new()
			shape.radius = CLEARANCE
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), pos)
			if not space.intersect_shape(q, 1).is_empty():
				inside.append(t)
				continue

			# Is the subject actually visible from here?
			var ray := PhysicsRayQueryParameters3D.create(pos, look)
			var hit: Dictionary = space.intersect_ray(ray)
			if not hit.is_empty():
				var d: float = pos.distance_to(hit["position"])
				# Something very close to the lens is an obstruction; something
				# near the look target is probably the thing being looked at.
				if d < pos.distance_to(look) - 1.5:
					blocked.append(t)

		var note: String = str(shot.get("note", ""))
		if inside.is_empty() and blocked.is_empty():
			print("  shot %d  OK        %s" % [i, note])
		else:
			bad += 1
			var parts: Array[String] = []
			if not inside.is_empty():
				parts.append("INSIDE at t=%s" % [inside])
			if not blocked.is_empty():
				parts.append("BLOCKED at t=%s" % [blocked])
			print("  shot %d  %s" % [i, "  ".join(parts)])
			print("            from %s -> %s  looking at %s"
				% [from, to, look])

	print("")
	if bad == 0:
		print("all %d shots clear" % shots.size())
		quit(0)
		return

	print("%d of %d shots need their numbers changed" % [bad, shots.size()])
	print("")
	print("searching for clear replacements...")
	print("")
	for i in shots.size():
		if _shot_ok(space, shots[i]):
			continue
		_suggest(space, i, shots[i])
	quit(1)


## Is every sample along this dolly both out of geometry and able to see its
## subject?
func _shot_ok(space: PhysicsDirectSpaceState3D, shot: Dictionary) -> bool:
	var from := Vector3(shot["from"])
	var to := Vector3(shot["to"])
	var look := Vector3(shot["look"])
	for s in SAMPLES:
		var t := float(s) / float(SAMPLES - 1)
		var eased := t * t * (3.0 - 2.0 * t)
		if not _point_ok(space, from.lerp(to, eased), look):
			return false
	return true


func _point_ok(space: PhysicsDirectSpaceState3D, pos: Vector3, look: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = CLEARANCE
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pos)
	if not space.intersect_shape(q, 1).is_empty():
		return false
	var ray := PhysicsRayQueryParameters3D.create(pos, look)
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		return true
	return pos.distance_to(hit["position"]) >= pos.distance_to(look) - 1.5


## Nudge the whole shot — both ends together, so the move keeps its shape — and
## report the first offset that comes back clear. Height first, because lifting
## a camera over a pump island or a car is almost always the fix and it keeps
## the framing the author intended.
func _suggest(space: PhysicsDirectSpaceState3D, index: int, shot: Dictionary) -> void:
	var offsets: Array[Vector3] = []
	for dy: float in [0.0, 1.0, 2.0, 3.0, 4.5, 6.0, 8.0]:
		for r: float in [0.0, 2.0, 4.0, 6.0]:
			for a in 8:
				var ang := TAU * float(a) / 8.0
				offsets.append(Vector3(cos(ang) * r, dy, sin(ang) * r))

	for off in offsets:
		var trial := shot.duplicate()
		trial["from"] = Vector3(shot["from"]) + off
		trial["to"] = Vector3(shot["to"]) + off
		if _shot_ok(space, trial):
			print('  shot %d  ->  "from": Vector3(%.1f, %.1f, %.1f), "to": Vector3(%.1f, %.1f, %.1f),'
				% [index,
				   trial["from"].x, trial["from"].y, trial["from"].z,
				   trial["to"].x, trial["to"].y, trial["to"].z])
			print("            (offset %+.1f,%+.1f,%+.1f from the original)"
				% [off.x, off.y, off.z])
			return

	print("  shot %d  no clear position found nearby — needs reframing by hand" % index)
