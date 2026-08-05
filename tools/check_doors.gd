extends SceneTree
## Can a player actually walk through the doorways?
##
##     "$GODOT" --headless --path . --script res://tools/check_doors.gd
##
## Both shop doorways have been reported blocked twice, and eyeballing the box
## maths did not find it either time. So ask the physics engine instead: sweep
## the player's own capsule along the path you'd walk, and report the first
## point it collides.
##
## Uses the real capsule radius from player.tscn rather than a guess — a gap
## that clears a point but not a 0.36m radius body is exactly the failure that
## reads as "the door is blocked".

const MAP := "res://scenes/beach_gas_real.tscn"

const RADIUS := 0.36
const HEIGHT := 1.8
## Sampled along each walk-through path.
const STEPS := 24

## from -> to, walking in through each door.
const DOORS: Array[Dictionary] = [
	{"name": "store", "from": Vector3(-11.4, 0.0, -8.5), "to": Vector3(-11.4, 0.0, -16.0)},
	{"name": "summerleaf", "from": Vector3(2.0, 0.0, -10.0), "to": Vector3(2.0, 0.0, -18.0)},
]


func _initialize() -> void:
	var world = load(MAP).instantiate()
	world.decorative = false
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame

	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape := CapsuleShape3D.new()
	shape.radius = RADIUS
	shape.height = HEIGHT

	var blocked := 0
	for door in DOORS:
		var from := Vector3(door["from"])
		var to := Vector3(door["to"])
		var hits: Array[String] = []
		for i in STEPS + 1:
			var t := float(i) / float(STEPS)
			var at := from.lerp(to, t)
			# Capsule centre sits half its height off the floor, like the player's.
			at.y = HEIGHT * 0.5 + 0.1
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = shape
			q.transform = Transform3D(Basis(), at)
			var res := space.intersect_shape(q, 4)
			if not res.is_empty():
				var names: Array[String] = []
				for r in res:
					var c = r.get("collider")
					if c != null:
						names.append(str(c.name))
				hits.append("z=%.1f hit %s" % [at.z, ", ".join(names)])

		if hits.is_empty():
			print("  %-12s CLEAR" % door["name"])
		else:
			blocked += 1
			print("  %-12s BLOCKED at %d of %d samples" % [door["name"], hits.size(), STEPS + 1])
			for h in hits.slice(0, 4):
				print("                 %s" % h)

	print("")
	print("both doorways walkable" if blocked == 0
		else "%d doorway(s) blocked" % blocked)
	quit(0 if blocked == 0 else 1)
