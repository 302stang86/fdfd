extends Node3D

const BODY := ["#4b5d3b", "#1c1f24", "#f4f4f6", "#2b2d42", "#283950", "#141414", "#8d99ae", "#16141a"]
const ACCENT := ["#2f3a24", "#8b1e24", "#e63946", "#ffb703", "#6186b1", "#ffffff", "#00b4d8", "#4a1942"]
const HEAD := ["#d9a077", "#1c1f24", "#fff0e6", "#d9a077", "#d9a077", "#f2c6a0", "#6c757d", "#f5e6e8"]
const BODY_HEIGHT := 1.5
const CROUCH_HEIGHT := 1.0

func build(skin: int) -> void:
	var base_color := Color(BODY[skin])
	var accent := Color(ACCENT[skin])
	var legs := 0.54 if skin != 5 else 0.44
	var torso := 0.55 if skin != 5 else 0.46
	var face_size := 0.32 if skin != 5 else 0.30
	var head_y := legs + torso + face_size / 2.0
	var face_edge := face_size / 2.0

	for side in [-1, 1]:
		block(Vector3(0.13 * side, legs * 0.5, 0), Vector3(0.20, legs, 0.23), base_color)
		block(Vector3(0.13 * side, 0.055, 0.035), Vector3(0.22, 0.11, 0.30), Color("#20242a"))
		block(Vector3(0.29 * side, legs + torso * 0.62, 0), Vector3(0.14, torso * 0.72, 0.20), base_color)
		block(Vector3(0.29 * side, legs + torso * 0.23, 0.01), Vector3(0.13, 0.12, 0.16), Color(HEAD[skin]))
	block(Vector3(0, legs + torso / 2.0, 0), Vector3(0.45, torso, 0.27), base_color)
	block(Vector3(0, head_y, 0), Vector3(face_size, face_size, face_size), Color(HEAD[skin]))
	if skin != 6:
		for x in [-0.072, 0.072]:
			block(Vector3(x, head_y + 0.035, face_edge + 0.004), Vector3(0.038, 0.028, 0.012), Color("#191921"))
	match skin:
		0:
			block(Vector3(0, head_y + 0.145, 0), Vector3(0.37, 0.09, 0.34), accent)
			for offset in [-0.12, 0.12]:
				block(Vector3(offset, legs + torso * 0.65, 0.14), Vector3(0.13, 0.13, 0.025), accent)
		1:
			block(Vector3(0, head_y + 0.025, face_edge + 0.012), Vector3(0.24, 0.048, 0.01), Color("#bca78b"))
			block(Vector3(0, legs + 0.14, 0.14), Vector3(0.46, 0.08, 0.025), accent)
		2:
			block(Vector3(0, head_y - 0.02, face_edge + 0.042), Vector3(0.08, 0.08, 0.08), accent)
			for side in [-1, 1]:
				block(Vector3(side * 0.19, head_y + 0.075, 0), Vector3(0.12, 0.17, 0.27), accent)
			block(Vector3(0, legs + torso - 0.04, 0.14), Vector3(0.23, 0.07, 0.05), accent)
		3:
			block(Vector3(0, head_y + 0.15, 0.025), Vector3(0.40, 0.08, 0.40), accent)
			for y in [legs + 0.12, legs + 0.32]:
				block(Vector3(0, y, 0.14), Vector3(0.44, 0.065, 0.025), accent)
		4:
			block(Vector3(0, head_y + 0.15, 0.035), Vector3(0.37, 0.08, 0.38), base_color)
			block(Vector3(0.10, legs + torso * 0.73, 0.145), Vector3(0.055, 0.075, 0.015), Color("#efd27d"))
		5:
			for side in [-1, 1]:
				var ear_x: float = side * 0.083
				var ear_y := head_y + face_edge + 0.15
				block(Vector3(ear_x, ear_y, 0), Vector3(0.065, 0.30, 0.075), base_color)
				block(Vector3(ear_x, ear_y - 0.012, 0.041), Vector3(0.032, 0.23, 0.012), Color("#ff758f"))
			block(Vector3(0, legs + torso - 0.015, 0.138), Vector3(0.24, 0.06, 0.028), accent)
			block(Vector3(0, legs + 0.04, -0.16), Vector3(0.12, 0.12, 0.11), accent)
		6:
			block(Vector3(0, head_y + 0.025, face_edge + 0.015), Vector3(0.25, 0.072, 0.03), accent)
			block(Vector3(0, legs + torso * 0.62, 0.145), Vector3(0.23, 0.19, 0.03), accent)
		7:
			var hair := Color("#0d0c10")
			block(Vector3(0, head_y + 0.123, -0.025), Vector3(0.36, 0.10, 0.34), hair)
			block(Vector3(-0.09, head_y + 0.05, face_edge + 0.014), Vector3(0.16, 0.16, 0.026), hair).rotation.z = -0.24
			block(Vector3(0, legs + torso - 0.01, 0.142), Vector3(0.22, 0.05, 0.026), Color("#9d4edd"))
			block(Vector3(0, legs + 0.09, 0), Vector3(0.48, 0.21, 0.33), accent)

func set_crouching(enabled: bool) -> void:
	scale.y = CROUCH_HEIGHT / BODY_HEIGHT if enabled else 1.0

func block(point: Vector3, dimensions: Vector3, color: Color) -> MeshInstance3D:
	var model := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	model.mesh = geometry
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	model.material_override = material
	model.position = point
	add_child(model)
	return model
