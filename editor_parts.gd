extends RefCounted

const LABELS := {
	"grass_tile": "Grass patch (4 × 4 m)", "dirt_tile": "Dirt patch (4 × 4 m)",
	"rubble_tile": "Rubble patch (4 × 4 m)",
	"tree_sapling": "Small sapling", "tree_birch": "Birch", "tree_maple": "Maple",
	"tree_pine": "Tall pine", "tree_oak": "Large oak",
	"build_wall": "Wall (4 m)", "build_doorway": "Open doorway wall (4 m)",
	"build_floor": "Floor panel (4 × 4 m)", "build_roof": "Flat roof panel (4 × 4 m)",
}

static func build(id: String) -> Node3D:
	var root := StaticBody3D.new()
	match id:
		"grass_tile", "dirt_tile", "rubble_tile":
			var palette := Color("#627544") if id == "grass_tile" else (Color("#8c6a4e") if id == "dirt_tile" else Color("#666970"))
			block(root, Vector3(0, 0.018, 0), Vector3(4, 0.028, 4), palette, false)
			for index in range(17):
				var x := fposmod(index * 1.763, 3.7) - 1.85
				var z := fposmod(index * 0.947, 3.7) - 1.85
				var height := 0.08 if id == "rubble_tile" else 0.016
				block(root, Vector3(x, 0.037, z), Vector3(0.14 + index % 4 * 0.045, height, 0.12 + index % 3 * 0.05), palette.lightened(index % 3 * 0.075), false)
		"build_wall":
			block(root, Vector3(0, 1.25, 0), Vector3(4, 2.5, 0.24), Color("#947a66"), true)
		"build_doorway":
			for side in [-1, 1]:
				block(root, Vector3(side * 1.37, 1.05, 0), Vector3(1.26, 2.1, 0.24), Color("#947a66"), true)
			block(root, Vector3(0, 2.3, 0), Vector3(4, 0.4, 0.24), Color("#947a66"), true)
		"build_floor":
			block(root, Vector3(0, 0.09, 0), Vector3(4, 0.18, 4), Color("#847a6d"), true)
		"build_roof":
			block(root, Vector3(0, 0.12, 0), Vector3(4, 0.24, 4), Color("#515c65"), true)
		_:
			var size := {"tree_sapling": 1.5, "tree_birch": 2.8, "tree_maple": 3.4, "tree_pine": 4.6, "tree_oak": 5.4}
			var h := float(size[id])
			var trunk := Color("#a6a195") if id == "tree_birch" else Color("#674e38")
			var leaf := Color("#63804a") if id != "tree_maple" else Color("#a36137")
			if id == "tree_pine":
				leaf = Color("#3f6a54")
			var trunk_size := maxf(0.13, h * 0.072)
			block(root, Vector3(0, h * 0.24, 0), Vector3(trunk_size, h * 0.48, trunk_size), trunk, true)
			for index in range(3):
				var canopy: PrimitiveMesh
				if id == "tree_pine":
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = h * (0.22 - index * 0.041)
					cone.height = h * 0.36
					cone.radial_segments = 7
					canopy = cone
				else:
					var crown := SphereMesh.new()
					crown.radius = h * (0.16 if id == "tree_birch" else 0.21)
					crown.height = h * 0.43
					crown.radial_segments = 7
					crown.rings = 4
					canopy = crown
				var spread := 0.0 if id == "tree_pine" else (index - 1) * h * 0.12
				display(root, canopy, Vector3(spread, h * (0.56 + index * 0.10), 0), leaf.lightened(index * 0.09))
	return root

static func block(root: StaticBody3D, point: Vector3, size: Vector3, color: Color, solid: bool) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	display(root, mesh, point, color)
	if solid:
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.position = point
		collider.shape = shape
		root.add_child(collider)

static func display(root: Node3D, mesh: Mesh, point: Vector3, color: Color) -> void:
	var piece := MeshInstance3D.new()
	piece.position = point
	piece.mesh = mesh
	var surface := StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.92
	piece.material_override = surface
	root.add_child(piece)
