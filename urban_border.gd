extends Node3D
class_name ArenaBorderGenerator

enum Barrier { BUILDING, CHAIN_LINK, WOOD_FENCE, RUBBLE, DESTROYED_CAR }

@export var grid_scale := 3.0
@export var wall_height := 3.5

@export_group("Barrier Prefabs")
@export var building_scenes: Array[PackedScene] = []
@export var chain_link_scenes: Array[PackedScene] = []
@export var wood_fence_scenes: Array[PackedScene] = []
@export var rubble_scenes: Array[PackedScene] = []
@export var destroyed_car_scenes: Array[PackedScene] = []

const LOOP: Array[Vector2i] = [
	Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 1),
	Vector2i(7, 1), Vector2i(7, 3), Vector2i(8, 3), Vector2i(8, 1), Vector2i(10, 1),
	Vector2i(10, 2), Vector2i(12, 2), Vector2i(12, 1), Vector2i(13, 1), Vector2i(13, 3),
	Vector2i(14, 3), Vector2i(14, 4), Vector2i(13, 4), Vector2i(13, 6), Vector2i(15, 6),
	Vector2i(15, 9), Vector2i(14, 9), Vector2i(14, 8), Vector2i(12, 8), Vector2i(12, 10),
	Vector2i(14, 10), Vector2i(14, 11), Vector2i(15, 11), Vector2i(15, 12), Vector2i(12, 12),
	Vector2i(12, 14), Vector2i(10, 14), Vector2i(10, 13), Vector2i(9, 13), Vector2i(9, 14),
	Vector2i(6, 14), Vector2i(6, 12), Vector2i(4, 12), Vector2i(4, 14), Vector2i(1, 14),
	Vector2i(1, 13), Vector2i(2, 13), Vector2i(2, 11), Vector2i(0, 11), Vector2i(0, 9),
	Vector2i(1, 9), Vector2i(1, 7), Vector2i(4, 7), Vector2i(4, 6), Vector2i(1, 6),
	Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 3), Vector2i(1, 3), Vector2i(1, 2),
	Vector2i(2, 2)
]
const GRID_CENTER := Vector2(7.5, 7.5)
const BAY_LENGTH := 6.0 # keep in sync with BAY in blender/make_urban_props.py

func generate_border(collision_host: Node3D) -> void:
	var colliders := StaticBody3D.new()
	colliders.name = "UrbanBorderColliders"
	collision_host.add_child(colliders)
	for index in range(LOOP.size()):
		var start := world_point(LOOP[index])
		var finish := world_point(LOOP[(index + 1) % LOOP.size()])
		build_segment(start, finish, index, colliders)

func draw_footprint() -> void:
	var polygon := PackedVector2Array()
	for vertex in LOOP:
		var point := world_point(vertex)
		polygon.append(Vector2(point.x, point.z))
	var triangles := Geometry2D.triangulate_polygon(polygon)
	if triangles.is_empty():
		return
	var surface := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#676e70")
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	for index in triangles:
		surface.surface_set_normal(Vector3.UP)
		surface.surface_add_vertex(Vector3(polygon[index].x, 0.002, polygon[index].y))
	surface.surface_end()
	var area := MeshInstance3D.new()
	area.mesh = surface
	area.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(area)

func world_point(point: Vector2i) -> Vector3:
	var centered := (Vector2(point) - GRID_CENTER) * grid_scale
	return Vector3(centered.x, 0, centered.y)

func build_segment(start: Vector3, finish: Vector3, index: int, colliders: StaticBody3D) -> void:
	var edge := finish - start
	var length := edge.length()
	if length < 0.05:
		return
	var midpoint := (start + finish) * 0.5
	var yaw := atan2(edge.x, edge.z)
	var type := barrier_type(length, index)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var thickness := 1.55 if type == Barrier.BUILDING else 0.22
	shape.size = Vector3(thickness, wall_height, length + thickness)
	collider.shape = shape
	collider.position = midpoint + Vector3.UP * wall_height * 0.5
	collider.rotation.y = yaw
	colliders.add_child(collider)

	var segment := Node3D.new()
	add_child(segment)
	segment.position = midpoint
	segment.rotation.y = yaw
	if select_prefab(type, index) != null:
		place_prefabs(segment, type, length, index)
	else:
		build_visual(segment, type, length)
		if type == Barrier.RUBBLE or type == Barrier.DESTROYED_CAR:
			fence_wire(segment, length)
		elif type == Barrier.WOOD_FENCE:
			fence_wire(segment, length, 1.62)

func barrier_type(length: float, index: int) -> int:
	if length <= grid_scale * 1.1:
		return Barrier.RUBBLE
	if length >= grid_scale * 2.8:
		return Barrier.BUILDING
	return [Barrier.CHAIN_LINK, Barrier.WOOD_FENCE, Barrier.DESTROYED_CAR][index % 3]

func select_prefab(type: int, index: int) -> PackedScene:
	var pools := [building_scenes, chain_link_scenes, wood_fence_scenes, rubble_scenes, destroyed_car_scenes]
	var pool: Array = pools[type]
	return null if pool.is_empty() else pool[index % pool.size()]

# Wall-style prefabs are modelled one BAY long. They are tiled along the segment
# and stretched slightly so the bays meet exactly at the segment ends. Wrecked cars
# are placed unstretched at the same spacing the blockout used.
func place_prefabs(segment: Node3D, type: int, length: float, index: int) -> void:
	if type == Barrier.DESTROYED_CAR:
		var wrecks := maxi(1, floori(length / 3.5))
		for wreck in range(wrecks):
			var car: Node3D = select_prefab(type, index + wreck).instantiate()
			segment.add_child(car)
			car.position.z = -length * 0.5 + (wreck + 0.5) * length / wrecks
	else:
		tile_bays(segment, type, length, index)
	# Rubble heaps and wrecks are low, so a fence rises above them to match the collider.
	if type == Barrier.RUBBLE or type == Barrier.DESTROYED_CAR:
		if chain_link_scenes.is_empty():
			fence_wire(segment, length)
		else:
			tile_bays(segment, Barrier.CHAIN_LINK, length, index)

func tile_bays(segment: Node3D, type: int, length: float, index: int) -> void:
	var bays := maxi(1, roundi(length / BAY_LENGTH))
	var bay_length := length / bays
	for bay in range(bays):
		var piece: Node3D = select_prefab(type, index + bay).instantiate()
		segment.add_child(piece)
		piece.position.z = -length * 0.5 + (bay + 0.5) * bay_length
		piece.scale.z = bay_length / BAY_LENGTH

func build_visual(segment: Node3D, type: int, length: float) -> void:
	match type:
		Barrier.BUILDING:
			block(segment, Vector3(0, 1.9, 0), Vector3(1.55, 3.8, length + 0.17), Color("#66686c"))
			block(segment, Vector3(0, 3.73, 0), Vector3(1.73, 0.19, length + 0.25), Color("#9b9790"))
			block(segment, Vector3(0, 0.32, 0), Vector3(1.66, 0.64, length), Color("#484b4f"))
			for z in range(1, floori(length / 3.0)):
				for side in [-1, 1]:
					block(segment, Vector3(0.792 * side, 2.54, z * 3.0 - length * 0.5), Vector3(0.045, 0.96, 1.26), Color("#354950"))
		Barrier.CHAIN_LINK:
			fence_wire(segment, length)
		Barrier.WOOD_FENCE:
			var planks := maxi(3, floori(length / 0.42))
			var spacing := length / planks
			for index in range(planks):
				var height := 1.67 + (index % 5) * 0.048
				var shade := Color("#775545").lightened((index % 3) * 0.06)
				block(segment, Vector3(0, height * 0.5, -length * 0.5 + spacing * (index + 0.5)), Vector3(0.18, height, spacing * 0.94), shade)
			for y in [0.48, 1.36]:
				block(segment, Vector3(0, y, 0), Vector3(0.27, 0.095, length), Color("#9a7357"))
		Barrier.DESTROYED_CAR:
			var wrecks := maxi(1, floori(length / 3.5))
			for index in range(wrecks):
				var z := -length * 0.5 + (index + 0.5) * length / wrecks
				var hull := block(segment, Vector3(0, 0.52, z), Vector3(1.55, 0.64, 3.1), Color("#80503c"))
				hull.rotation.z = 0.08
				block(segment, Vector3(0, 1.02, z - 0.15), Vector3(1.28, 0.49, 1.52), Color("#52423e"))
				block(segment, Vector3(0, 1.02, z + 0.625), Vector3(1.16, 0.3, 0.045), Color("#334850"))
				for side in [-1, 1]:
					for offset in [-1.02, 1.02]:
						block(segment, Vector3(side * 0.73, 0.29, z + offset), Vector3(0.3, 0.5, 0.51), Color("#242629"))
		Barrier.RUBBLE:
			var pieces := maxi(4, floori(length / 0.72))
			for index in range(pieces):
				var size := 0.49 + (index % 4) * 0.16
				var z := -length * 0.5 + (index + 0.5) * length / pieces
				var chunk := block(segment, Vector3(((index % 3) - 1) * 0.27, size * 0.38, z), Vector3(size, size * 0.86, size * 1.34), Color("#777572").lightened((index % 3) * 0.07))
				chunk.rotation = Vector3(index * 0.24, index * 1.13, index * 0.38)

func fence_wire(segment: Node3D, length: float, bottom: float = 0.08) -> void:
	var metal := Color("#6f858c")
	for y in [bottom, wall_height - 0.045]:
		block(segment, Vector3(0, y, 0), Vector3(0.1, 0.095, length), metal)
	for fraction in [-0.48, 0.0, 0.48]:
		block(segment, Vector3(0, wall_height * 0.5, length * fraction), Vector3(0.13, wall_height, 0.13), metal)
	var wire := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#9aaeb1")
	wire.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var limit := length * 0.5
	for slope in [-1, 1]:
		for index in range(-ceili(wall_height / 0.25), ceili((length + wall_height) / 0.25) + 1):
			var z := -limit + index * 0.25
			var lower := maxf(bottom + 0.04, -limit - z if slope == 1 else z - limit)
			var upper := minf(wall_height - 0.06, limit - z if slope == 1 else z + limit)
			if upper > lower:
				wire.surface_add_vertex(Vector3(0, lower, z + lower * slope))
				wire.surface_add_vertex(Vector3(0, upper, z + upper * slope))
	wire.surface_end()
	var mesh_view := MeshInstance3D.new()
	mesh_view.mesh = wire
	mesh_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	segment.add_child(mesh_view)

func block(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_view := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_view.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	mesh_view.material_override = material
	mesh_view.position = position
	parent.add_child(mesh_view)
	return mesh_view
