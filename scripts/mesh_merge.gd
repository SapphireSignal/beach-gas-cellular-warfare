extends Node
class_name MeshMerge
## Collapses a pile of small MeshInstance3D siblings into one mesh.
##
## Everything in this game is built from primitives at runtime, which is lovely
## to author and terrible to render: a character is ~55 nodes and the map is
## ~250. Each one is a scene-tree node to traverse, a transform to push and a
## culling test to run, every frame, on a phone.
##
## Merging siblings that never move relative to each other collapses all of
## that into a single instance with one surface per material. A character drops
## from ~55 instances to about eight; the map from ~250 to under twenty.
##
## The trade is per-object frustum culling — a merged mesh is drawn whole or not
## at all. At this scale that's the right way round: the geometry is a few
## thousand triangles total, and node overhead costs far more than the vertices.

## Merge every direct MeshInstance3D child of `parent` that has no children of
## its own. Meshes are grouped by material *and* shadow setting, so a decal that
## casts no shadow never gets folded in with a wall that does.
static func merge_children(parent: Node3D) -> void:
	if parent == null:
		return

	var groups: Dictionary = {}      # cast_shadow -> { material -> [MeshInstance3D] }
	var originals: Array = []

	for child in parent.get_children():
		if not (child is MeshInstance3D):
			continue
		var mi: MeshInstance3D = child
		if mi.get_child_count() > 0 or mi.mesh == null or mi.material_override == null:
			continue
		# Anything scaled or non-uniformly transformed is still fine — the
		# transform is baked into the vertices — but skip visibility-toggled
		# pieces, which have to stay individually addressable.
		if not mi.visible:
			continue
		var shadow := mi.cast_shadow
		if not groups.has(shadow):
			groups[shadow] = {}
		var by_material: Dictionary = groups[shadow]
		if not by_material.has(mi.material_override):
			by_material[mi.material_override] = []
		by_material[mi.material_override].append(mi)
		originals.append(mi)

	if originals.size() < 3:
		return   # not worth a merged mesh

	for shadow in groups:
		var by_material: Dictionary = groups[shadow]
		var combined := ArrayMesh.new()
		var materials: Array = []
		for material in by_material:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for mi in by_material[material]:
				tool.append_from(mi.mesh, 0, mi.transform)
			tool.index()
			tool.commit(combined)
			materials.append(material)

		if combined.get_surface_count() == 0:
			continue
		for i in materials.size():
			combined.surface_set_material(i, materials[i])

		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = combined
		merged.cast_shadow = shadow
		parent.add_child(merged)

	for mi in originals:
		mi.queue_free()


## Flatten an entire subtree into a single mesh. For decoration that never moves
## a muscle — a plant, a stack of bottles — where even one instance per part is
## far too many. Transforms are composed by walking the parent chain, so this
## works before the node has been added to the scene.
static func merge_tree(root: Node3D) -> void:
	var groups: Dictionary = {}      # cast_shadow -> { material -> [[mesh, transform]] }
	var victims: Array = []
	_gather(root, Transform3D.IDENTITY, groups, victims)
	if victims.size() < 3:
		return

	for shadow in groups:
		var by_material: Dictionary = groups[shadow]
		var combined := ArrayMesh.new()
		var materials: Array = []
		for material in by_material:
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			for pair in by_material[material]:
				tool.append_from(pair[0], 0, pair[1])
			tool.index()
			tool.commit(combined)
			materials.append(material)
		if combined.get_surface_count() == 0:
			continue
		for i in materials.size():
			combined.surface_set_material(i, materials[i])

		var merged := MeshInstance3D.new()
		merged.name = "MergedTree"
		merged.mesh = combined
		merged.cast_shadow = shadow
		root.add_child(merged)

	# Free exactly what was merged, and nothing else. Collision bodies live
	# alongside these meshes and must survive — deleting them would quietly
	# turn every car and plant into a hologram you walk straight through.
	for mi in victims:
		mi.queue_free()
	for child in root.get_children():
		if child is Node3D and not (child is MeshInstance3D) and _is_empty_pivot(child):
			child.queue_free()


static func _is_empty_pivot(node: Node) -> bool:
	# A StaticBody3D contains only a CollisionShape3D, which made it look like
	# an empty pivot and got every car and plant deleted out from under the
	# physics. Anything that *is* a collider is never empty.
	if node is CollisionObject3D:
		return false
	for child in node.get_children():
		if child is Node3D and not (child is MeshInstance3D):
			if not _is_empty_pivot(child):
				return false
	return true


static func _gather(node: Node, accumulated: Transform3D, groups: Dictionary,
		victims: Array) -> void:
	for child in node.get_children():
		if not (child is Node3D) or child is CollisionObject3D:
			continue
		var local: Transform3D = accumulated * (child as Node3D).transform
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			if mi.mesh != null and mi.material_override != null and mi.visible:
				if not groups.has(mi.cast_shadow):
					groups[mi.cast_shadow] = {}
				var by_material: Dictionary = groups[mi.cast_shadow]
				if not by_material.has(mi.material_override):
					by_material[mi.material_override] = []
				by_material[mi.material_override].append([mi.mesh, local])
				victims.append(mi)
		_gather(child, local, groups, victims)


## Merge a node and every descendant pivot in one call. Used for characters,
## where each limb pivot has to stay separate but the meshes inside it don't.
static func merge_recursive(root: Node3D, skip: Array = []) -> void:
	if root == null or root.name in skip:
		return
	# Depth first: children are collapsed before the parent looks at its own.
	for child in root.get_children():
		if child is Node3D and not (child is MeshInstance3D) and not (child is GPUParticles3D):
			merge_recursive(child, skip)
	merge_children(root)
