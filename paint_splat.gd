extends RefCounted

static var variants: Array[ImmediateMesh] = []

static func make(color: Color, radius: float) -> MeshInstance3D:
	if variants.is_empty():
		for index in range(4):
			var rng := RandomNumberGenerator.new()
			rng.seed = 431 + index * 73
			variants.append(make_mesh(rng))
	var mark := MeshInstance3D.new()
	mark.mesh = variants.pick_random()
	mark.scale = Vector3.ONE * radius
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mark

static func place(mark: MeshInstance3D, point: Vector3, normal: Vector3) -> void:
	mark.global_position = point + normal * 0.012
	var up := Vector3.FORWARD if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	mark.look_at(mark.global_position + normal, up)
	mark.rotate_object_local(Vector3.FORWARD, randf_range(0.0, TAU))

static func make_mesh(rng: RandomNumberGenerator) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector2Array()
	for index in range(60):
		var ray := Vector2.from_angle(TAU * index / 60.0)
		var radius := rng.randf_range(0.54, 0.76)
		if index % 9 == 4:
			radius *= rng.randf_range(1.55, 2.06)
		elif index % 9 == 3 or index % 9 == 5:
			radius *= 1.15
		outline.append(ray * radius * Vector2(1.0, 0.88))
	for index in range(outline.size()):
		triangle(mesh, Vector2.ZERO, outline[index], outline[(index + 1) % outline.size()], 0.77, 0.96)
	for index in range(25):
		var angle := rng.randf_range(0.0, TAU)
		var direction := Vector2.from_angle(angle)
		var side := direction.orthogonal()
		var center := direction * rng.randf_range(0.87, 1.54)
		var width := rng.randf_range(0.022, 0.071)
		var length := width * rng.randf_range(1.12, 2.7)
		for edge in range(8):
			var a := Vector2.from_angle(TAU * edge / 8.0)
			var b := Vector2.from_angle(TAU * (edge + 1) / 8.0)
			triangle(mesh, center, center + direction * a.x * length + side * a.y * width,
				center + direction * b.x * length + side * b.y * width, 0.91, 0.72)
	mesh.surface_end()
	return mesh

static func triangle(mesh: ImmediateMesh, center: Vector2, a: Vector2, b: Vector2, inner: float, edge: float) -> void:
	mesh.surface_set_color(Color(inner, inner, inner))
	mesh.surface_add_vertex(Vector3(center.x, center.y, 0))
	mesh.surface_set_color(Color(edge, edge, edge))
	mesh.surface_add_vertex(Vector3(a.x, a.y, 0))
	mesh.surface_set_color(Color(edge, edge, edge))
	mesh.surface_add_vertex(Vector3(b.x, b.y, 0))
