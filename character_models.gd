extends RefCounted
# The eight outfits, in the same order as OUTFITS in menu.gd and the skin index used by
# the arena. The models come from blender/make_characters.py: feet at y = 0, 1.5 m tall,
# facing +Z, split into Torso / ArmA / ArmB / LegA / LegB nodes whose origins are the joints.

const LEGACY_BACK := preload("res://assets/models/characters/legacy_rear_atlas.png")
const SIDE_MATERIAL := preload("res://character_side_wrap.gdshader")
const ROSTER := preload("res://character_roster.gd")
const TEXTURED_OPERATIVES := preload("res://textured_operatives.gd")
const STAND_HEIGHT := 1.5
const CROUCH_HEIGHT := 1.0
const PARTS := ["Torso", "ArmA", "ArmB", "LegA", "LegB"]
const MODELS: Array[PackedScene] = [
	preload("res://assets/models/characters/char_army.glb"),
	preload("res://assets/models/characters/char_ninja.glb"),
	preload("res://assets/models/characters/char_clown.glb"),
	preload("res://assets/models/characters/char_firefighter.glb"),
	preload("res://assets/models/characters/char_police.glb"),
	preload("res://assets/models/characters/char_bunny.glb"),
	preload("res://assets/models/characters/char_robot.glb"),
]
# How far (radians) each outfit's legs swing while walking. Long coats swing less.
const LEG_SWING := [0.5, 0.5, 0.5, 0.5, 0.5, 0.45, 0.45, 0.43, 0.50, 0.51, 0.46, 0.48, 0.40]

static var profile_meshes: Dictionary = {}

static func make(skin: int) -> Node3D:
	if skin == 4:
		return TEXTURED_OPERATIVES.make(6)
	if skin >= 7:
		return TEXTURED_OPERATIVES.make(skin - 7)
	var skin_index := clampi(skin, 0, MODELS.size() - 1)
	var model := MODELS[skin_index].instantiate()
	add_profile_depth(model, skin_index)
	if skin == 5:
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if mesh.mesh == null:
				continue
			for index in range(mesh.mesh.get_surface_count()):
				var source := mesh.get_active_material(index) as BaseMaterial3D
				if source == null:
					continue
				var opaque := source.duplicate() as BaseMaterial3D
				opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				opaque.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.set_surface_override_material(index, opaque)
		fill_bunny_neckline(model)
	return model

# The original loft follows the width of the front artwork. Add body depth
# before the leg rig skins the mesh so the side view reads at every pose.
static func add_profile_depth(model: Node3D, skin: int) -> void:
	for part_name in PARTS:
		var part := model.find_child(part_name, true, false) as Node3D
		if part == null:
			continue
		var view := part as MeshInstance3D
		if view == null:
			var children := part.find_children("*", "MeshInstance3D", true, false)
			if not children.is_empty():
				view = children[0] as MeshInstance3D
		if view == null or view.mesh == null:
			continue
		var key := "%d/%s" % [skin, part_name]
		if not profile_meshes.has(key):
			var height_offset := part.position.y
			if view != part:
				height_offset += view.position.y
			profile_meshes[key] = shape_profile(view.mesh, part_name, height_offset, skin)
		view.mesh = profile_meshes[key]

static func shape_profile(source: Mesh, part_name: String, height_offset: float, skin: int) -> ArrayMesh:
	var result := ArrayMesh.new()
	for surface in range(source.get_surface_count()):
		var arrays := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals := PackedVector3Array()
		var smooth_normals: Dictionary = {}
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]
		for index in range(vertices.size()):
			var vertex := vertices[index]
			var height := vertex.y + height_offset
			var multiplier := profile_scale(part_name, height, skin, vertex.x)
			var slope := 0.0
			if index < normals.size():
				var gradient := (profile_scale(part_name, height + 0.002, skin, vertex.x) - profile_scale(part_name, height - 0.002, skin, vertex.x)) / 0.004
				slope = (profile_center(part_name, height + 0.002, skin, vertex.x) - profile_center(part_name, height - 0.002, skin, vertex.x)) / 0.004
				var normal := normals[index]
				normal.z /= multiplier
				normal.y -= normal.z * (vertex.z * gradient + slope)
				if skin == 5 and part_name == "Torso":
					var depth_gradient := (profile_scale(part_name, height, skin, vertex.x + 0.002) - profile_scale(part_name, height, skin, vertex.x - 0.002)) / 0.004
					var center_gradient := (profile_center(part_name, height, skin, vertex.x + 0.002) - profile_center(part_name, height, skin, vertex.x - 0.002)) / 0.004
					normal.x -= normal.z * (vertex.z * depth_gradient + center_gradient)
				normals[index] = normal.normalized()
			vertex.z = vertex.z * multiplier + profile_center(part_name, height, skin, vertex.x)
			vertices[index] = vertex
			if index < normals.size():
				var key := vertex.snapped(Vector3.ONE * 0.0001)
				var average: Vector3 = smooth_normals.get(key, Vector3.ZERO)
				smooth_normals[key] = average + normals[index]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		if not normals.is_empty():
			for index in range(normals.size()):
				var average: Vector3 = smooth_normals[vertices[index].snapped(Vector3.ONE * 0.0001)]
				if not average.is_zero_approx():
					normals[index] = average.normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var original := source.surface_get_material(surface) as BaseMaterial3D
		if original != null and original.albedo_texture != null:
			var wrapped := ShaderMaterial.new()
			wrapped.shader = SIDE_MATERIAL
			wrapped.set_shader_parameter("atlas", original.albedo_texture)
			wrapped.set_shader_parameter("rear_atlas", LEGACY_BACK)
			var rear_index := skin if skin < 4 else skin - 1
			var rear_col := rear_index % 3
			var lower := rear_index >= 3
			var front_center := [176.0, 176.0, 173.0, 175.0, 176.0, 176.0, 177.0]
			var rear_width := [1.02, 1.00, 1.13, 1.09, 1.0, 0.93, 1.04]
			wrapped.set_shader_parameter("rear_layout", Vector4(
				256.0 + rear_col * 512.0, 493.0 if lower else 13.0,
				484.0 if lower else 451.0, rear_width[skin]))
			wrapped.set_shader_parameter("front_center", front_center[skin])
			wrapped.set_shader_parameter("bunny_head", skin == 5 and part_name == "Torso")
			result.surface_set_material(surface, wrapped)
		else:
			result.surface_set_material(surface, source.surface_get_material(surface))
	return result

static func profile_scale(part_name: String, height: float, skin: int, x: float) -> float:
	if part_name == "Torso":
		var body := smoothstep(0.52, 0.83, height) * (1.0 - smoothstep(1.15, 1.31, height))
		var scale := 1.03 + 0.72 * body
		if skin == 5:
			# The lower hair rings include part of the shoulder silhouette.
			# Taper their depth while retaining volume around the skull.
			var lower_hair := smoothstep(1.155, 1.177, height) * (1.0 - smoothstep(1.23, 1.30, height))
			lower_hair *= 1.0 - smoothstep(0.11, 0.14, absf(x))
			scale = lerpf(scale, 0.61, lower_hair)
		return scale
	if part_name.begins_with("Arm"):
		return lerpf(1.62, 1.2, smoothstep(0.78, 1.08, height))
	return lerpf(1.04, 1.27, smoothstep(0.08, 0.28, height))

static func profile_center(part_name: String, height: float, skin: int, x: float) -> float:
	if part_name == "Torso":
		var chest := exp(-pow((height - 1.025) / 0.17, 2.0)) * 0.025
		var pelvis := exp(-pow((height - 0.70) / 0.12, 2.0)) * 0.024
		var face := exp(-pow((height - 1.32) / 0.055, 2.0)) * 0.012
		if skin == 5:
			var head := smoothstep(1.155, 1.19, height) * (1.0 - smoothstep(1.34, 1.40, height))
			var nose := exp(-pow((height - 1.288) / 0.019, 2.0) - pow((x - 0.004) / 0.026, 2.0))
			return lerpf(chest - pelvis + face, -0.005 + nose * 0.022, head)
		return chest - pelvis + face
	if part_name.begins_with("Leg"):
		return -exp(-pow((height - 0.36) / 0.11, 2.0)) * 0.017
	return 0.0

# The source silhouette has disconnected neck and bodice rings. Join them with
# a closed fabric insert attached to the torso so it follows the crouch pose.
static func fill_bunny_neckline(model: Node3D) -> void:
	var torso := model.find_child("Torso", true, false) as Node3D
	if torso == null:
		return
	var insert := MeshInstance3D.new()
	insert.name = "NecklineInsert"
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color("#252129")
	fabric.roughness = 0.88
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.060
	mesh.bottom_radius = 0.082
	mesh.height = 0.148
	mesh.radial_segments = 24
	mesh.rings = 0
	mesh.material = fabric
	insert.mesh = mesh
	insert.position = Vector3(0.005, 1.093, 0.003)
	insert.scale.z = 0.72
	torso.add_child(insert)

# Crouching squashes the standing model to the 1.0 m crouch height.
static func crouch_scale(enabled: bool) -> Vector3:
	if not enabled:
		return Vector3.ONE
	return Vector3(1.07, CROUCH_HEIGHT / STAND_HEIGHT, 1.07)
