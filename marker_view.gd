extends Node3D

const HIP := Vector3(0.33, -0.305, -0.44)
const AIM := Vector3(0.035, -0.225, -0.49)
const KICK := [0.055, 0.11, 0.145]

var muzzle: Marker3D
var kind := 0
var recoil := 0.0
var aim_blend := 0.0
var walking_phase := 0.0
var moving_blend := 0.0
const MARKER_MESHES: Array[Mesh] = [
	preload("res://assets/opengameart/markers/m16.obj"),
	preload("res://assets/opengameart/markers/sniper.obj"),
	preload("res://assets/opengameart/markers/launcher.obj"),
]
const VIEW_SCALE := [1.0, 0.84, 0.48]
const VIEW_OFFSET := [Vector3(0, -0.028, -0.206), Vector3(0, 0.164, -0.268), Vector3(0, 0.015, -0.212)]
const BARREL_TIP := [Vector3(-0.00005, 0.02844, -0.51407), Vector3(0, -0.19222, -0.69333), Vector3(0, 0, -0.99668)]
var sleeve: StandardMaterial3D
var glove: StandardMaterial3D
var seam: StandardMaterial3D

func build(marker: int, outfit_tint: Color) -> void:
	kind = marker
	sleeve = material(outfit_tint.darkened(0.13), 0.0, 0.85)
	glove = material(Color("#2c3034"), 0.0, 0.9)
	seam = material(Color("#52575b"), 0.0, 0.8)
	position = HIP
	muzzle = Marker3D.new()
	add_child(muzzle)
	var model := part(MARKER_MESHES[kind], VIEW_OFFSET[kind], null)
	model.scale = Vector3.ONE * VIEW_SCALE[kind]
	muzzle.position = model.position + BARREL_TIP[kind] * VIEW_SCALE[kind] + Vector3(0, 0, -0.007)
	build_hands()

func reset_motion() -> void:
	recoil = 0.0
	aim_blend = 0.0
	moving_blend = 0.0
	walking_phase = 0.0
	position = HIP
	rotation = Vector3.ZERO

func punch() -> void:
	recoil = KICK[kind]

func animate(delta: float, aiming: bool, reload_progress: float, moving: bool) -> void:
	aim_blend = move_toward(aim_blend, 1.0 if aiming else 0.0, delta * 6.5)
	moving_blend = move_toward(moving_blend, 1.0 if moving else 0.0, delta * 6.0)
	walking_phase = fposmod(walking_phase + delta * 9.0, TAU)
	var sway := Vector3(sin(walking_phase) * 0.009, cos(walking_phase * 2.0) * 0.008, 0)
	sway *= moving_blend * (1.0 - aim_blend * 0.8)
	var dip := sin(PI * clampf(reload_progress, 0.0, 1.0))
	position = HIP.lerp(AIM, aim_blend) + sway + Vector3(0.09 * dip, -0.27 * dip, recoil)
	rotation = Vector3(0.95 * recoil - dip * 0.44, 0.18 * dip, -0.42 * dip)
	recoil = move_toward(recoil, 0.0, delta * 0.56)

func build_hands() -> void:
	var rear := rounded(Vector3(0.035, -0.175, 0.035), Vector3(0.113, 0.115, 0.122), glove)
	rear.rotation.x = -0.28
	tube(Vector3(0.061, -0.19, 0.08), Vector3(0.18, -0.28, 0.35), 0.066, sleeve)
	var support_z := -0.322 if kind != 2 else -0.395
	rounded(Vector3(-0.040, -0.088, support_z), Vector3(0.117, 0.09, 0.139), glove)
	tube(Vector3(-0.062, -0.115, support_z + 0.049), Vector3(-0.20, -0.27, 0.14), 0.063, sleeve)
	for index in range(3):
		box(Vector3(-0.049, -0.059, support_z - 0.043 + index * 0.035), Vector3(0.079, 0.014, 0.012), seam)

func material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	return result

func part(geometry: Mesh, point: Vector3, surface: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = geometry
	item.material_override = surface
	item.position = point
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(item)
	return item

func box(point: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var geometry := BoxMesh.new()
	geometry.size = size
	return part(geometry, point, surface)

func rounded(point: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var geometry := SphereMesh.new()
	geometry.radial_segments = 16
	geometry.rings = 8
	var item := part(geometry, point, surface)
	item.scale = size
	return item

func tube(start: Vector3, finish: Vector3, radius: float, surface: Material) -> MeshInstance3D:
	var geometry := CylinderMesh.new()
	geometry.top_radius = radius
	geometry.bottom_radius = radius
	geometry.height = start.distance_to(finish)
	geometry.radial_segments = 16
	geometry.rings = 1
	var item := part(geometry, (start + finish) * 0.5, surface)
	item.quaternion = Quaternion(Vector3.UP, start.direction_to(finish))
	return item
