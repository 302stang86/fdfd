extends Node3D
# Ground patches (short grass, long grass, dirt, rubble) and faint drifting clouds.
# Everything here is visual only: no collision, so it never changes how a match plays.

const DIRT_DARK := Color("#3f3022")
const DIRT_LIGHT := Color("#6b5339")
const GRASS_TINT := Color("#4b6a36")
const PATCH_COUNTS := {"short_grass": 14, "long_grass": 9, "dirt": 12, "rubble": 8}
const CLUMPS := ["grass_clump_a", "grass_clump_b", "grass_clump_c", "grass_clump_d"]
const CHUNKS := ["rubble_block", "rubble_slab", "rubble_wedge", "rubble_shard", "rubble_pile"]
const CLUMP_HEIGHT := 0.5
const CLOUD_GROUPS := 9
const CLOUD_DRIFT := 0.0035 # radians per second

const DIRT_SHADER := """
shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform vec4 dark : source_color = vec4(0.25, 0.19, 0.13, 1.0);
uniform vec4 light : source_color = vec4(0.42, 0.33, 0.22, 1.0);
uniform float large_scale = 2.0;
uniform float fine_scale = 90.0;
uniform float bump_strength = 0.35;
varying vec3 world_pos;
varying vec2 disc;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; disc = UV; }
void fragment() {
	float big = vnoise(world_pos.xz * large_scale * 0.5) * 0.65 + vnoise(world_pos.xz * large_scale * 2.3) * 0.35;
	float grain = vnoise(world_pos.xz * fine_scale);
	float tone = clamp(big * 0.75 + grain * 0.25, 0.0, 1.0);
	ALBEDO = mix(dark.rgb, light.rgb, tone);
	ROUGHNESS = 0.9;
	float bump = vnoise(world_pos.xz * fine_scale * 0.5) - 0.5;
	NORMAL_MAP = vec3(0.5 + bump * bump_strength, 0.5 + (grain - 0.5) * bump_strength, 1.0);
	float edge = length(disc - vec2(0.5)) * 2.0;
	ALPHA = smoothstep(1.0, 0.62 + big * 0.2, edge);
}
"""

var rng := RandomNumberGenerator.new()
var keep_out: Array[Vector3] = [] # x, z, radius of cover objects to stay clear of
var dirt_spots: Array[Vector3] = [] # x, z, radius of dirt patches: no grass grows here
var cloud_ring: Node3D
var area_outline := PackedVector2Array()
var density_noise := FastNoiseLite.new() # separates short grass from tall grass
var rubble_noise := FastNoiseLite.new() # clusters rubble
var clump_meshes: Array[Mesh] = []
var chunk_meshes: Array[Mesh] = []
var grass_material: StandardMaterial3D
var rubble_material: StandardMaterial3D
var dirt_material: ShaderMaterial

# `footprint` is the outline of the urban map's playable area (empty on open fields); patches
# stay inside it and off the central road.
func build(arena: Node3D, arena_edge: float, map_seed: int, footprint: PackedVector2Array = PackedVector2Array()) -> void:
	rng.seed = 7301 + map_seed
	area_outline = footprint
	density_noise.seed = 311 + map_seed
	density_noise.frequency = 0.09
	density_noise.fractal_octaves = 3
	rubble_noise.seed = 977 + map_seed
	rubble_noise.frequency = 0.12
	rubble_noise.fractal_octaves = 2
	load_meshes()
	make_materials()
	collect_cover(arena)
	collect_group_cover(arena)
	var limit := arena_edge - 5.0
	# dirt first so grass can keep clear of it
	for kind in ["dirt", "rubble", "short_grass", "long_grass"]:
		for index in range(PATCH_COUNTS[kind]):
			make_patch(kind, limit)
	make_clouds()

func mesh_of(path: String) -> Mesh:
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var root := scene.instantiate()
	var found: Mesh = null
	var queue: Array = [root]
	while not queue.is_empty() and found == null:
		var node: Node = queue.pop_back()
		if node is MeshInstance3D:
			found = node.mesh
		queue.append_array(node.get_children())
	root.free()
	return found

func load_meshes() -> void:
	for name in CLUMPS:
		var mesh := mesh_of("res://assets/models/scatter/%s.glb" % name)
		if mesh != null:
			clump_meshes.append(mesh)
	for name in CHUNKS:
		var mesh := mesh_of("res://assets/models/scatter/%s.glb" % name)
		if mesh != null:
			chunk_meshes.append(mesh)

func make_materials() -> void:
	grass_material = StandardMaterial3D.new()
	grass_material.vertex_color_use_as_albedo = true
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.roughness = 1.0
	rubble_material = StandardMaterial3D.new()
	rubble_material.vertex_color_use_as_albedo = true
	rubble_material.roughness = 0.95
	dirt_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DIRT_SHADER
	dirt_material.shader = shader
	dirt_material.set_shader_parameter("dark", DIRT_DARK)
	dirt_material.set_shader_parameter("light", DIRT_LIGHT)

func inside_area(point: Vector2, radius: float) -> bool:
	if area_outline.is_empty():
		return true
	if absf(point.x) < radius + 9.5: # keep the road clear
		return false
	if not Geometry2D.is_point_in_polygon(point, area_outline):
		return false
	for step in range(8):
		var edge := point + Vector2.from_angle(TAU * step / 8.0) * (radius + 1.6)
		if not Geometry2D.is_point_in_polygon(edge, area_outline):
			return false
	return true

func collect_cover(arena: Node3D) -> void:
	for body in arena.get_children():
		if not body is StaticBody3D:
			continue
		for shape_node in body.get_children():
			if shape_node is CollisionShape3D and shape_node.shape is BoxShape3D:
				var size: Vector3 = shape_node.shape.size
				if size.y < 0.6 or maxf(size.x, size.z) > 20.0:
					continue # the floor, the boundary walls and other slabs
				var at: Vector3 = body.global_position
				keep_out.append(Vector3(at.x, at.z, maxf(size.x, size.z) * 0.72))

func collect_group_cover(arena: Node3D) -> void:
	for node in arena.get_tree().get_nodes_in_group("keep_out"):
		if node is Node3D and arena.is_ancestor_of(node):
			var at: Vector3 = node.global_position
			keep_out.append(Vector3(at.x, at.z, float(node.get_meta("keep_radius", 1.0))))

func patch_position(limit: float, radius: float) -> Vector2:
	for attempt in range(40):
		var point := Vector2(rng.randf_range(-limit, limit), rng.randf_range(-limit, limit))
		var clear := point.distance_to(Vector2(0, 35)) > radius + 3.0 and inside_area(point, radius) # player spawn
		for blocker in keep_out:
			if point.distance_to(Vector2(blocker.x, blocker.y)) < radius + blocker.z:
				clear = false
				break
		if clear:
			return point
	return Vector2(INF, INF)

# 0..1 noise value at a ground point.
func sample(noise: FastNoiseLite, point: Vector2) -> float:
	return noise.get_noise_2d(point.x, point.y) * 0.5 + 0.5

func on_dirt(point: Vector2) -> bool:
	for spot in dirt_spots:
		if point.distance_to(Vector2(spot.x, spot.y)) < spot.z * 0.85:
			return true
	return false

func make_patch(kind: String, limit: float) -> void:
	var radius := rng.randf_range(1.8, 3.8)
	if kind == "long_grass":
		radius = rng.randf_range(2.0, 3.6)
	var centre := patch_position(limit, radius)
	if centre.x == INF:
		return
	match kind:
		"dirt":
			dirt_spots.append(Vector3(centre.x, centre.y, radius))
			add_dirt(centre, radius * 1.15)
		"rubble":
			add_rubble(centre, radius)
		_:
			add_grass(centre, radius, kind == "long_grass")

# Soft-edged dirt disc with the layered noise shader on it.
func add_dirt(centre: Vector2, radius: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var instance := MeshInstance3D.new()
	instance.mesh = plane
	instance.material_override = dirt_material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.position = Vector3(centre.x, 0.02 + rng.randf() * 0.01, centre.y)
	instance.rotation.y = rng.randf() * TAU
	add_child(instance)

func add_grass(centre: Vector2, radius: float, tall_patch: bool) -> void:
	if clump_meshes.is_empty():
		return
	var per_mesh: Array = []
	for index in range(clump_meshes.size()):
		per_mesh.append([])
	var tries := int(radius * radius * (24 if tall_patch else 34))
	for attempt in range(tries):
		var angle := rng.randf() * TAU
		var offset := Vector2(cos(angle), sin(angle)) * radius * sqrt(rng.randf())
		var point := centre + offset
		if on_dirt(point):
			continue
		var mask := sample(density_noise, point)
		# colour-ramp style mask: tall grass only where the noise is high, short grass fills the rest
		var tall_chance := smoothstep(0.5, 0.62, mask)
		if tall_patch:
			tall_chance = maxf(tall_chance, 0.55)
		var tall := rng.randf() < tall_chance
		var edge_fade := 1.0 - offset.length() / radius
		if rng.randf() > 0.35 + edge_fade * 0.9:
			continue
		var height := rng.randf_range(0.35, 0.8) if tall else rng.randf_range(0.05, 0.15)
		var vertical := height / CLUMP_HEIGHT
		var wide := rng.randf_range(0.7, 1.15) * (1.0 if tall else 1.6)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, vertical, wide)) # Z-only rotation
		per_mesh[rng.randi() % clump_meshes.size()].append([Transform3D(basis, Vector3(point.x, 0.0, point.y)), mask])
	for index in range(per_mesh.size()):
		var items: Array = per_mesh[index]
		if items.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = clump_meshes[index]
		multi.instance_count = items.size()
		for item_index in range(items.size()):
			multi.set_instance_transform(item_index, items[item_index][0])
			var warm := float(items[item_index][1])
			var tint := Color(0.78, 0.9, 0.7).lerp(Color(1.05, 0.98, 0.72), warm).lerp(Color.BLACK, rng.randf_range(0.0, 0.2))
			multi.set_instance_color(item_index, tint)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = grass_material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)

# Rubble is clustered: a chunk only lands where the cluster noise is in the 0.65 - 0.80+ band.
func add_rubble(centre: Vector2, radius: float) -> void:
	if chunk_meshes.is_empty():
		return
	var per_mesh: Array = []
	for index in range(chunk_meshes.size()):
		per_mesh.append([])
	for attempt in range(int(radius * radius * 30)):
		var angle := rng.randf() * TAU
		var point := centre + Vector2(cos(angle), sin(angle)) * radius * sqrt(rng.randf())
		var cluster := sample(rubble_noise, point)
		if cluster < 0.5 + rng.randf() * 0.15:
			continue
		var size := rng.randf_range(0.6, 1.5)
		var basis := Basis.from_euler(Vector3(rng.randf() * 0.7, rng.randf() * TAU, rng.randf() * 0.7)).scaled(Vector3.ONE * size)
		per_mesh[rng.randi() % chunk_meshes.size()].append(Transform3D(basis, Vector3(point.x, -rng.randf_range(0.02, 0.05), point.y)))
	for index in range(per_mesh.size()):
		var items: Array = per_mesh[index]
		if items.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = chunk_meshes[index]
		multi.instance_count = items.size()
		for item_index in range(items.size()):
			multi.set_instance_transform(item_index, items[item_index])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = rubble_material
		add_child(instance)

# Faint clouds: soft sprites far out and high up that drift slowly around the arena.
func make_clouds() -> void:
	cloud_ring = Node3D.new()
	add_child(cloud_ring)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	for group in range(CLOUD_GROUPS):
		var angle := TAU * (group + rng.randf_range(-0.25, 0.25)) / CLOUD_GROUPS
		var distance := rng.randf_range(150.0, 230.0)
		var height := rng.randf_range(38.0, 80.0)
		var anchor := Vector3(cos(angle) * distance, height, sin(angle) * distance)
		for puff in range(rng.randi_range(4, 7)):
			var sprite := Sprite3D.new()
			sprite.texture = texture
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.shaded = false
			sprite.double_sided = true
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sprite.modulate = Color(1, 1, 1, rng.randf_range(0.14, 0.26))
			sprite.pixel_size = rng.randf_range(0.5, 0.85)
			sprite.scale = Vector3(rng.randf_range(1.3, 2.2), rng.randf_range(0.55, 0.85), 1.0)
			sprite.position = anchor + Vector3(rng.randf_range(-45, 45), rng.randf_range(-6, 6), rng.randf_range(-30, 30))
			cloud_ring.add_child(sprite)

func _process(delta: float) -> void:
	if cloud_ring != null:
		cloud_ring.rotation.y += CLOUD_DRIFT * delta
