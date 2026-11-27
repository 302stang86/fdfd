extends RefCounted

const ATLAS := preload("res://assets/models/characters/operative_atlas.png")
const FABRIC := preload("res://operative_fabric.gdshader")
const SIDES := 20
const CELL := Vector2(512, 512)

# Atlas landmarks in cell pixels. Each part uses rings from top to bottom.
# Torso row: y, half width, depth radius. Limb row: y, lateral center, half width, depth radius.
const HEAD_TOP := [13, 10, 12, 15, 8, 9]
const SOLE := [498, 498, 498, 500, 500, 500]
const CENTERS := [259, 255, 257, 261, 255, 255]
const TORSO := [
	[[17, 16, 18], [31, 27, 29], [56, 26, 30], [89, 30, 23], [110, 48, 25], [135, 48, 38], [174, 42, 31], [207, 37, 30], [229, 48, 34], [252, 48, 32], [269, 24, 23]],
	[[15, 40, 16], [28, 60, 26], [61, 36, 29], [85, 32, 27], [108, 61, 37], [145, 49, 39], [190, 40, 34], [221, 49, 38], [255, 61, 40], [277, 40, 32]],
	[[17, 17, 18], [33, 26, 28], [61, 24, 29], [86, 17, 20], [104, 46, 29], [137, 48, 37], [171, 40, 32], [197, 39, 34], [222, 50, 36], [251, 50, 36], [274, 32, 25]],
	[[22, 17, 18], [40, 28, 28], [69, 28, 27], [94, 24, 21], [110, 46, 28], [137, 46, 35], [168, 38, 33], [193, 39, 33], [221, 51, 35], [251, 49, 34], [272, 29, 24]],
	[[15, 13, 12], [35, 29, 24], [62, 38, 31], [86, 35, 32], [110, 55, 33], [139, 47, 37], [172, 43, 32], [206, 47, 34], [249, 51, 37], [272, 33, 28]],
	[[13, 18, 18], [29, 31, 33], [58, 33, 37], [77, 25, 27], [97, 50, 39], [124, 58, 48], [156, 46, 42], [185, 43, 37], [214, 55, 41], [246, 46, 36], [274, 31, 30]],
]
const ARM := [
	[[110, 43, 10, 12], [128, 48, 10, 13], [156, 56, 10, 12], [184, 66, 9, 11], [216, 76, 7, 8], [241, 82, 9, 10], [260, 86, 7, 8]],
	[[115, 54, 14, 17], [143, 61, 14, 17], [170, 69, 14, 16], [200, 77, 15, 16], [225, 87, 13, 12], [257, 90, 10, 10], [271, 91, 7, 8]],
	[[106, 42, 12, 13], [132, 50, 12, 14], [163, 58, 12, 13], [192, 68, 10, 11], [221, 78, 9, 10], [243, 85, 10, 10], [264, 87, 7, 8]],
	[[111, 45, 12, 14], [138, 51, 12, 14], [167, 59, 12, 13], [196, 68, 10, 12], [224, 78, 9, 10], [251, 85, 10, 11], [271, 90, 7, 8]],
	[[114, 53, 13, 15], [143, 61, 12, 15], [176, 69, 12, 14], [205, 79, 11, 13], [233, 88, 10, 11], [252, 92, 9, 10], [269, 93, 8, 8]],
	[[102, 53, 13, 16], [130, 63, 15, 19], [157, 70, 13, 16], [182, 79, 14, 16], [211, 89, 11, 13], [236, 95, 11, 13], [263, 98, 8, 10]],
]
const LEG := [
	[[239, 27, 21, 21], [273, 31, 21, 23], [305, 36, 20, 20], [348, 42, 18, 17], [392, 48, 16, 15], [433, 52, 14, 16], [467, 55, 13, 17], [490, 59, 20, 27], [496, 59, 20, 25]],
	[[246, 25, 24, 24], [283, 30, 24, 25], [325, 34, 22, 20], [368, 43, 22, 20], [410, 49, 18, 17], [451, 55, 16, 19], [481, 62, 33, 30], [495, 62, 32, 28]],
	[[239, 26, 24, 23], [279, 31, 23, 23], [315, 37, 21, 21], [353, 43, 20, 19], [395, 48, 20, 18], [437, 52, 15, 17], [468, 54, 15, 18], [491, 57, 18, 27], [496, 57, 18, 25]],
	[[235, 25, 24, 22], [278, 30, 22, 22], [316, 37, 20, 20], [354, 42, 19, 18], [392, 49, 17, 16], [435, 52, 15, 16], [470, 57, 14, 18], [491, 60, 18, 25], [498, 60, 18, 24]],
	[[236, 26, 25, 25], [277, 31, 25, 24], [315, 36, 22, 22], [354, 42, 21, 19], [395, 47, 20, 18], [432, 51, 17, 16], [469, 55, 15, 19], [491, 59, 18, 27], [498, 59, 17, 26]],
	[[238, 27, 24, 25], [279, 33, 25, 26], [319, 39, 22, 22], [355, 44, 23, 21], [394, 49, 21, 20], [434, 53, 17, 17], [467, 55, 17, 20], [490, 57, 19, 27], [498, 57, 19, 26]],
]
static var options: Dictionary = {}

static func make(variant: int) -> Node3D:
	var root := Node3D.new()
	var key := clampi(variant, 0, TORSO.size() - 1)
	if not options.has(key):
		options[key] = build_outfit(key)
	for item in options[key]:
		var part := MeshInstance3D.new()
		part.name = item[0]
		part.position = item[1]
		part.mesh = item[2]
		root.add_child(part)
	return root

static func build_outfit(variant: int) -> Array:
	var result := []
	var unit := 1.5 / float(SOLE[variant] - HEAD_TOP[variant])
	var fabric := ShaderMaterial.new()
	fabric.shader = FABRIC
	fabric.set_shader_parameter("atlas", ATLAS)
	fabric.set_shader_parameter("row_start", (512.0 if variant >= 3 else 0.0) / 1024.0)
	fabric.set_shader_parameter("hood_color", [Color("#482133"), Color("#3e492e"), Color("#443429"),
		Color("#783d28"), Color("#414034"), Color("#34383e")][variant])
	result.append(["Torso", Vector3.ZERO, loft(TORSO[variant], variant, 0.0, unit, Vector3.ZERO, fabric)])
	for sign_value in [-1.0, 1.0]:
		var letter := "A" if sign_value < 0.0 else "B"
		var arms: Array = ARM[variant]
		var legs: Array = LEG[variant]
		var arm_origin := anchor(arms[0], variant, sign_value, unit)
		var leg_origin := anchor(legs[0], variant, sign_value, unit)
		result.append(["Arm" + letter, arm_origin, loft(arms, variant, sign_value, unit, arm_origin, fabric)])
		result.append(["Leg" + letter, leg_origin, loft(legs, variant, sign_value, unit, leg_origin, fabric)])
	return result

static func anchor(row: Array, variant: int, side: float, unit: float) -> Vector3:
	return Vector3(float(row[1]) * side * unit, (SOLE[variant] - float(row[0])) * unit, 0)

static func loft(rows: Array, variant: int, side: float, unit: float, pivot: Vector3, fabric: Material) -> ArrayMesh:
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var column_offset := float(variant % 3) * CELL.x
	var row_offset := CELL.y if variant >= 3 else 0.0
	for row_index in range(rows.size()):
		var row: Array = rows[row_index]
		var center := 0.0 if side == 0.0 else float(row[1]) * side
		var width := float(row[1] if side == 0.0 else row[2])
		var depth := float(row[2] if side == 0.0 else row[3])
		var height: float = (SOLE[variant] - float(row[0])) * unit
		var boot := 0.0
		if side != 0.0 and height < 0.16:
			boot = (1.0 - height / 0.16) * 0.035
		for segment in range(SIDES):
			var angle := TAU * segment / SIDES
			var x := cos(angle)
			var z := sin(angle)
			positions.append(Vector3((center + width * x) * unit, height, z * depth * unit + boot) - pivot)
			normals.append(Vector3(x / width, 0, z / depth).normalized())
			var atlas_x: float = column_offset + CENTERS[variant] + center + x * maxf(2.0, width - 4.0)
			uv.append(Vector2(atlas_x / 1536.0, (row_offset + float(row[0])) / 1024.0))
			if row_index < rows.size() - 1:
				var a := row_index * SIDES + segment
				var b := row_index * SIDES + (segment + 1) % SIDES
				indices.append_array(PackedInt32Array([a, a + SIDES, b, b, a + SIDES, b + SIDES]))
	for cap in [0, rows.size() - 1]:
		var base := int(cap) * SIDES
		var tip := positions.size()
		var row: Array = rows[cap]
		var center := 0.0 if side == 0.0 else float(row[1]) * side
		var point := Vector3(center * unit, (SOLE[variant] - float(row[0])) * unit, 0) - pivot
		if cap == 0:
			point.y += 0.007
		else:
			point.y = maxf(0.0, point.y + pivot.y - 0.008) - pivot.y
		positions.append(point)
		normals.append(Vector3.UP if cap == 0 else Vector3.DOWN)
		uv.append(Vector2((column_offset + CENTERS[variant] + center) / 1536.0, (row_offset + float(row[0])) / 1024.0))
		for segment in range(SIDES):
			var a := base + segment
			var b := base + (segment + 1) % SIDES
			indices.append_array(PackedInt32Array([tip, a, b] if cap == 0 else [tip, b, a]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, fabric)
	return mesh
