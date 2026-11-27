extends RefCounted

const SKIN := Color("#e6baa6")
const HAIR := Color("#68283e")
const HAIR_LIGHT := Color("#87394f")
const SHIRT := Color("#ded9d0")
const DENIM := Color("#26252b")
const LEATHER := Color("#18171d")
const METAL := Color("#a8a6ad")

static func make(variant: int = 0) -> Node3D:
	var palettes := [
		[SKIN, HAIR, HAIR_LIGHT, SHIRT, DENIM, LEATHER],
		[Color("#ddd4c8"), Color("#374736"), Color("#596a47"), Color("#514056"), Color("#594759"), Color("#2a252c")],
		[Color("#cb987b"), Color("#352722"), Color("#644638"), Color("#497679"), Color("#746149"), Color("#3d3428")],
		[Color("#e2b9a3"), Color("#a55234"), Color("#cf7950"), Color("#ddd5c6"), Color("#d2c6b1"), Color("#805437")],
		[Color("#818d7a"), Color("#262b25"), Color("#43483f"), Color("#574b40"), Color("#444750"), Color("#302e2c")],
		[Color("#575e6a"), Color("#242830"), Color("#3f4652"), Color("#484d55"), Color("#3c414a"), Color("#222831")],
	]
	var palette: Array = palettes[clampi(variant, 0, palettes.size() - 1)]
	var root := Node3D.new()
	var torso := Node3D.new()
	torso.name = "Torso"
	root.add_child(torso)
	ellipsoid(torso, Vector3(0, 0.79, -0.018), Vector3(0.34, 0.25, 0.25), palette[4])
	ellipsoid(torso, Vector3(0, 0.937, 0.007), Vector3(0.27, 0.29, 0.21), palette[3])
	ellipsoid(torso, Vector3(0, 1.07, 0.003), Vector3(0.34, 0.24, 0.235), palette[3])
	ellipsoid(torso, Vector3(0, 1.16, 0.024), Vector3(0.22, 0.13, 0.15), palette[0])
	ellipsoid(torso, Vector3(0, 1.201, 0.0), Vector3(0.115, 0.17, 0.115), palette[0])
	ellipsoid(torso, Vector3(0, 1.195, 0.004), Vector3(0.124, 0.031, 0.123), palette[5])
	ellipsoid(torso, Vector3(0, 0.835, -0.007), Vector3(0.329, 0.041, 0.244), palette[5])
	ellipsoid(torso, Vector3(0, 0.836, 0.116), Vector3(0.051, 0.032, 0.016), METAL)
	for i in range(-3, 4):
		if i == 0:
			continue
		var x := i * 0.038
		ellipsoid(torso, Vector3(x, 0.837, 0.116 - x * x * 2.0), Vector3(0.009, 0.009, 0.009), METAL)
	for index in range(13):
		var x := (index - 6) * 0.011
		var y := 1.131 + x * x * 8.0
		ellipsoid(torso, Vector3(x, y, 0.101), Vector3.ONE * 0.013, METAL)

	ellipsoid(torso, Vector3(0, 1.373, -0.042), Vector3(0.24, 0.256, 0.225), palette[1])
	ellipsoid(torso, Vector3(0, 1.268, -0.093), Vector3(0.235, 0.278, 0.147), palette[1])
	ellipsoid(torso, Vector3(0, 1.352, 0.029), Vector3(0.183, 0.214, 0.17), palette[0])
	ellipsoid(torso, Vector3(0, 1.311, 0.056), Vector3(0.138, 0.118, 0.132), palette[0])
	ellipsoid(torso, Vector3(0, 1.342, 0.111), Vector3(0.027, 0.055, 0.039), palette[0])
	ellipsoid(torso, Vector3(0, 1.304, 0.114), Vector3(0.040, 0.011, 0.011), Color("#4a202f"))
	for side in [-1.0, 1.0]:
		var x: float = side * 0.042
		ellipsoid(torso, Vector3(x, 1.367, 0.105), Vector3(0.044, 0.017, 0.015), palette[5])
		ellipsoid(torso, Vector3(x, 1.367, 0.113), Vector3(0.022, 0.009, 0.006), Color("#ddd3c8"))
		ellipsoid(torso, Vector3(x, 1.367, 0.117), Vector3(0.010, 0.010, 0.004), Color("#42333d"))
		ellipsoid(torso, Vector3(side * 0.089, 1.286, 0.000), Vector3(0.064, 0.237, 0.135), palette[2]).rotation.z = side * 0.14
		ellipsoid(torso, Vector3(side * 0.095, 1.354, 0.072), Vector3(0.031, 0.046, 0.044), palette[0])
		ellipsoid(torso, Vector3(side * 0.103, 1.337, 0.092), Vector3.ONE * 0.012, METAL)
	for i in range(4):
		var lock := ellipsoid(torso, Vector3(-0.058 + i * 0.035, 1.426 - i * 0.008, 0.087), Vector3(0.063, 0.092, 0.075), palette[2].lerp(palette[1], i * 0.18))
		lock.rotation.z = -0.52

	for index in range(2):
		var side := -1.0 if index == 0 else 1.0
		var suffix := "A" if index == 0 else "B"
		var arm := Node3D.new()
		arm.name = "Arm" + suffix
		arm.position = Vector3(side * 0.166, 1.105, 0)
		root.add_child(arm)
		ellipsoid(arm, Vector3(side * 0.019, -0.076, 0.0), Vector3(0.086, 0.223, 0.095), palette[0]).rotation.z = side * 0.16
		ellipsoid(arm, Vector3(side * 0.043, -0.224, 0.011), Vector3(0.069, 0.175, 0.073), palette[0]).rotation.z = side * 0.12
		ellipsoid(arm, Vector3(side * 0.051, -0.326, 0.020), Vector3(0.073, 0.086, 0.064), palette[5])
		ellipsoid(arm, Vector3(side * 0.051, -0.292, 0.018), Vector3(0.077, 0.020, 0.069), METAL)
		ellipsoid(arm, Vector3(side * 0.050, -0.369, 0.021), Vector3(0.048, 0.039, 0.037), palette[0])
		build_leg(root, side, suffix, palette, variant)
	add_costume(torso, variant)
	return root

static func build_leg(root: Node3D, side: float, suffix: String, palette: Array, variant: int) -> void:
	var leg := MeshInstance3D.new()
	leg.name = "Leg" + suffix
	leg.position = Vector3(side * 0.078, 0.76, -0.006)
	var mesh := ArrayMesh.new()
	add_shape(mesh, Vector3(0, -0.143, 0), Vector3(0.158, 0.395, 0.178), palette[4])
	add_shape(mesh, Vector3(side * 0.019, -0.399, -0.014), Vector3(0.126, 0.356, 0.139), palette[4])
	add_shape(mesh, Vector3(side * 0.024, -0.601, -0.012), Vector3(0.124, 0.238, 0.139), palette[5])
	add_shape(mesh, Vector3(side * 0.025, -0.707, 0.049), Vector3(0.133, 0.105, 0.233), palette[5])
	add_shape(mesh, Vector3(side * 0.025, -0.735, 0.051), Vector3(0.134, 0.050, 0.237), Color("#333039"))
	for index in range(3 if variant == 0 or variant == 4 else 0):
		var y := -0.19 - index * 0.075 + side * 0.013
		add_shape(mesh, Vector3(side * 0.009, y, 0.081 - index * 0.007), Vector3(0.068 - index * 0.008, 0.012, 0.013), palette[0])
	leg.mesh = mesh
	root.add_child(leg)

static func add_costume(torso: Node3D, variant: int) -> void:
	match variant:
		1:
			ellipsoid(torso, Vector3(0, 1.343, 0.131), Vector3.ONE * 0.038, Color("#8d302e"))
			for index in range(8):
				var angle := TAU * index / 8.0
				ellipsoid(torso, Vector3(cos(angle) * 0.145, 1.143, sin(angle) * 0.102), Vector3(0.057, 0.093, 0.052), Color("#a28755") if index % 2 == 0 else Color("#514056"))
				ellipsoid(torso, Vector3(cos(angle) * 0.16, 1.102, sin(angle) * 0.115), Vector3.ONE * 0.029, Color("#a07844"))
		2:
			ellipsoid(torso, Vector3(0, 1.038, -0.127), Vector3(0.19, 0.235, 0.145), Color("#88713e"))
			for index in range(5):
				var offset := index * 0.031
				ellipsoid(torso, Vector3(0.029, 1.255 - offset, -0.122 - offset * 0.33), Vector3(0.061 - offset * 0.21, 0.058, 0.050), Color("#523525"))
			for side in [-1.0, 1.0]:
				ellipsoid(torso, Vector3(side * 0.105, 1.040, 0.099), Vector3(0.035, 0.19, 0.036), Color("#8a7750"))
		3:
			for index in range(7):
				var band := ellipsoid(torso, Vector3(0, 0.87 + index * 0.039, 0.018), Vector3(0.275 + index * 0.007, 0.018, 0.226), Color("#bcb19c"))
				band.rotation.z = 0.14 if index % 2 == 0 else -0.12
			for side in [-1.0, 1.0]:
				var strap := ellipsoid(torso, Vector3(side * 0.091, 1.008, 0.106), Vector3(0.036, 0.29, 0.021), Color("#a86a42"))
				strap.rotation.z = side * 0.15
		4:
			ellipsoid(torso, Vector3(0, 1.163, -0.015), Vector3(0.252, 0.109, 0.197), Color("#514139"))
			for side in [-1.0, 1.0]:
				ellipsoid(torso, Vector3(side * 0.045, 1.368, 0.12), Vector3(0.012, 0.009, 0.008), Color("#c7d685"))
			ellipsoid(torso, Vector3(-0.111, 0.815, 0.08), Vector3(0.096, 0.10, 0.074), Color("#7a6649"))
		5:
			ellipsoid(torso, Vector3(0, 1.36, 0.021), Vector3(0.242, 0.265, 0.225), Color("#333b47"))
			ellipsoid(torso, Vector3(0, 1.381, 0.122), Vector3(0.195, 0.043, 0.054), Color("#ef9e38"))
			ellipsoid(torso, Vector3(0, 1.027, 0.094), Vector3(0.31, 0.22, 0.115), Color("#5b616b"))
			ellipsoid(torso, Vector3(0, 1.02, -0.117), Vector3(0.239, 0.245, 0.145), Color("#2d3541"))

static func ellipsoid(parent: Node3D, center: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := sphere()
	mesh.material = material(color)
	node.mesh = mesh
	node.position = center
	node.scale = dimensions
	parent.add_child(node)
	return node

static func add_shape(target: ArrayMesh, center: Vector3, dimensions: Vector3, color: Color) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(sphere(), 0, Transform3D(Basis.from_scale(dimensions), center))
	tool.set_material(material(color))
	tool.commit(target)

static func sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 12
	mesh.rings = 8
	return mesh

static func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.86
	return result
