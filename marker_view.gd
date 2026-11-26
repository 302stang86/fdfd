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
var metal: StandardMaterial3D
var edge: StandardMaterial3D
var polymer: StandardMaterial3D
var rubber: StandardMaterial3D
var cue: StandardMaterial3D
var lens: StandardMaterial3D
var sleeve: StandardMaterial3D
var glove: StandardMaterial3D
var seam: StandardMaterial3D

func build(marker: int, outfit_tint: Color) -> void:
	kind = marker
	metal = material(Color("#414951"), 0.66, 0.42)
	edge = material(Color("#77838c"), 0.73, 0.35)
	polymer = material(Color("#283039"), 0.08, 0.76)
	rubber = material(Color("#171c22"), 0.0, 0.92)
	cue = material(Color("#d58a3d"), 0.12, 0.48)
	lens = material(Color("#508a8e"), 0.37, 0.26)
	sleeve = material(outfit_tint.darkened(0.13), 0.0, 0.85)
	glove = material(Color("#2c3034"), 0.0, 0.9)
	seam = material(Color("#52575b"), 0.0, 0.8)
	position = HIP
	muzzle = Marker3D.new()
	add_child(muzzle)
	match kind:
		1: build_sniper()
		2: build_launcher()
		_: build_semi_auto()
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

func build_semi_auto() -> void:
	receiver(0.146, 0.35)
	box(Vector3(0, -0.063, -0.30), Vector3(0.156, 0.119, 0.28), polymer)
	tube(Vector3(0, -0.006, -0.41), Vector3(0, -0.006, -0.69), 0.022, metal)
	tube(Vector3(0, -0.006, -0.65), Vector3(0, -0.006, -0.72), 0.038, edge)
	muzzle_at(Vector3(0, -0.006, -0.72), 0.034)
	box(Vector3(0, 0.069, -0.18), Vector3(0.076, 0.028, 0.36), metal)
	rails(-0.02, 0.33, 0.089)
	tube(Vector3(-0.062, 0.07, -0.064), Vector3(-0.064, 0.159, -0.105), 0.031, polymer)
	rounded(Vector3(-0.074, 0.165, -0.125), Vector3(0.158, 0.11, 0.20), rubber)
	box(Vector3(-0.077, 0.218, -0.125), Vector3(0.10, 0.012, 0.13), polymer)
	tube(Vector3(0, -0.121, 0.14), Vector3(0, -0.121, 0.29), 0.057, polymer)

func build_sniper() -> void:
	receiver(0.127, 0.42)
	box(Vector3(0, -0.098, -0.226), Vector3(0.119, 0.112, 0.34), polymer)
	tube(Vector3(0, 0.002, -0.30), Vector3(0, 0.002, -0.83), 0.018, metal)
	tube(Vector3(0, 0.002, -0.64), Vector3(0, 0.002, -0.81), 0.025, edge)
	muzzle_at(Vector3(0, 0.002, -0.85), 0.030)
	for z in [-0.076, -0.235]:
		box(Vector3(0, 0.082, z), Vector3(0.056, 0.06, 0.035), edge)
	tube(Vector3(0, 0.122, 0.015), Vector3(0, 0.122, -0.30), 0.030, metal)
	tube(Vector3(0, 0.122, -0.25), Vector3(0, 0.122, -0.365), 0.045, polymer)
	tube(Vector3(0, 0.122, 0.044), Vector3(0, 0.122, -0.04), 0.048, rubber)
	tube(Vector3(0, 0.122, 0.046), Vector3(0, 0.122, 0.042), 0.039, lens)
	tube(Vector3(0, 0.15, -0.159), Vector3(0, 0.189, -0.159), 0.016, edge)
	box(Vector3(0, -0.082, 0.18), Vector3(0.113, 0.085, 0.24), polymer)

func build_launcher() -> void:
	receiver(0.181, 0.32)
	tube(Vector3(0, -0.033, -0.109), Vector3(0, -0.033, -0.338), 0.127, polymer)
	tube(Vector3(0, -0.033, -0.32), Vector3(0, -0.033, -0.352), 0.122, edge)
	for index in range(6):
		var angle := TAU * index / 6.0
		var p := Vector3(cos(angle) * 0.077, -0.033 + sin(angle) * 0.077, -0.352)
		tube(p, p + Vector3(0, 0, -0.016), 0.03, cue)
	box(Vector3(0, 0.094, -0.30), Vector3(0.111, 0.036, 0.28), polymer)
	tube(Vector3(0, 0.028, -0.31), Vector3(0, 0.028, -0.67), 0.054, metal)
	tube(Vector3(0, 0.028, -0.57), Vector3(0, 0.028, -0.665), 0.063, polymer)
	muzzle_at(Vector3(0, 0.028, -0.69), 0.061)
	rails(-0.18, 0.19, 0.113)
	box(Vector3(0, -0.074, 0.17), Vector3(0.128, 0.088, 0.22), polymer)

func receiver(width: float, length: float) -> void:
	box(Vector3(0, 0, -0.10), Vector3(width, 0.106, length), metal)
	box(Vector3(0, 0.057, -0.10), Vector3(width * 0.90, 0.021, length * 0.91), edge)
	box(Vector3(0, -0.08, -0.067), Vector3(width * 0.86, 0.068, length * 0.78), polymer)
	for side in [-1, 1]:
		for z in [-0.017, -0.137]:
			box(Vector3(side * width * 0.505, 0.016, z), Vector3(0.017, 0.018, 0.028), edge)
	var grip := box(Vector3(0, -0.163, 0.046), Vector3(0.075, 0.17, 0.10), rubber)
	grip.rotation.x = -0.24
	box(Vector3(0, -0.154, -0.055), Vector3(0.036, 0.017, 0.112), metal)
	box(Vector3(0, -0.119, -0.11), Vector3(0.036, 0.077, 0.019), metal)

func rails(start: float, length: float, y: float) -> void:
	for index in range(6):
		box(Vector3(0, y, start - length * index / 5.0), Vector3(0.085, 0.012, 0.020), edge)

func muzzle_at(point: Vector3, radius: float) -> void:
	tube(point + Vector3(0, 0, 0.021), point, radius, cue)
	tube(point, point + Vector3(0, 0, -0.003), radius * 0.61, rubber)
	muzzle.position = point + Vector3(0, 0, -0.007)

func build_hands() -> void:
	var rear := rounded(Vector3(0.035, -0.175, 0.035), Vector3(0.113, 0.115, 0.122), glove)
	rear.rotation.x = -0.28
	tube(Vector3(0.061, -0.19, 0.08), Vector3(0.18, -0.28, 0.35), 0.066, sleeve)
	var support_z := -0.322 if kind != 2 else -0.395
	rounded(Vector3(-0.059, -0.138, support_z), Vector3(0.117, 0.09, 0.139), glove)
	tube(Vector3(-0.08, -0.164, support_z + 0.049), Vector3(-0.20, -0.27, 0.14), 0.063, sleeve)
	for index in range(3):
		box(Vector3(-0.067, -0.107, support_z - 0.043 + index * 0.035), Vector3(0.079, 0.014, 0.012), seam)

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
