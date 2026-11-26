extends RefCounted
# Builds a saved custom map (format version 2) into an arena or the map editor.
#
# layout = {"version": 2, "objects": [entity, ...]}
#   prop:  {"k":"prop", "id":"sedan", "x":0, "y":0 (height), "z":0, "r":0 (degrees), "s":1.0 (scale)}
#   wall:  {"k":"wall", "t":"brick_low", "p":[[x,z], ...], "y":0, "closed":false}
#   road:  {"k":"road", "w":6.0, "p":[[x,z], ...], "walk":true, "t":"asphalt"}
# Older saves (a dictionary of "x,z" cells) are converted by from_legacy().

const STREET_PROPS := preload("res://street_props.gd")

const WALLS := {
	"brick_low": {"label": "Low brick wall", "h": 1.1, "t": 0.35, "color": "#8a4f3e", "cap": "#9a9a95"},
	"brick_tall": {"label": "Tall brick wall", "h": 3.0, "t": 0.35, "color": "#7e4a3a", "cap": "#8d8e8a"},
	"concrete_low": {"label": "Low concrete wall", "h": 1.1, "t": 0.3, "color": "#8d8e8a", "cap": "#6f706d"},
	"concrete_tall": {"label": "Tall concrete wall", "h": 3.0, "t": 0.3, "color": "#8d8e8a", "cap": "#6f706d"},
	"chain_link": {"label": "Chain-link fence", "h": 2.5, "t": 0.1, "color": "#9aa3a7", "cap": "#6c7478", "glass": true},
	"wood_fence": {"label": "Wood fence", "h": 1.9, "t": 0.15, "color": "#8a6a50", "cap": "#6e533d"},
	"hedge": {"label": "Hedge", "h": 1.1, "t": 0.8, "color": "#3b6b34", "cap": "#2f5a2b"},
	"jersey": {"label": "Jersey barriers", "h": 0.85, "t": 0.6, "color": "#a9a8a2", "cap": "#a9a8a2", "model": true},
}
const ROADS := {
	"asphalt": {"label": "Asphalt road", "color": "#3a3d40", "line": "#d9b84a", "side": "#8e8e88"},
	"dirt": {"label": "Dirt road", "color": "#6b5a42", "line": "#6b5a42", "side": "#6b5a42"},
}
const SIDEWALK := 1.6

# --- conversion ------------------------------------------------------------------------------

static func is_v2(layout: Dictionary) -> bool:
	return layout.has("objects")

static func from_legacy(layout: Dictionary) -> Dictionary:
	if is_v2(layout):
		return layout.duplicate(true)
	var objects := []
	for cell in layout:
		var parts := String(cell).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			continue
		var id := "crate"
		var degrees := 0.0
		var value = layout[cell]
		if value is String:
			var bits := (value as String).split(":")
			id = bits[0]
			if bits.size() > 1 and bits[1].is_valid_float():
				degrees = bits[1].to_float()
		objects.append({"k": "prop", "id": id, "x": parts[0].to_float(), "y": 0.0, "z": parts[1].to_float(), "r": degrees, "s": 1.0})
	return {"version": 2, "objects": objects}

# --- building --------------------------------------------------------------------------------

# Builds every entity under `parent`. Returns one Array of nodes per entity (same order).
func build(parent: Node3D, layout: Dictionary) -> Array:
	var objects: Array = layout.get("objects", [])
	var built := []
	for index in range(objects.size()):
		built.append(build_entity(parent, objects[index], objects, index))
	return built

# Builds one entity; returns the nodes it added directly to `parent`.
func build_entity(parent: Node3D, entity: Dictionary, all: Array, index: int) -> Array:
	var before := parent.get_child_count()
	match String(entity.get("k", "prop")):
		"prop":
			var props := STREET_PROPS.new()
			props.place(parent, String(entity.get("id", "crate")), Vector2(entity.get("x", 0.0), entity.get("z", 0.0)),
				deg_to_rad(float(entity.get("r", 0.0))), float(entity.get("y", 0.0)), float(entity.get("s", 1.0)))
		"wall":
			build_wall(parent, entity)
		"road":
			build_road(parent, entity, all, index)
	var nodes := []
	for child_index in range(before, parent.get_child_count()):
		nodes.append(parent.get_child(child_index))
	return nodes

static func points_of(entity: Dictionary) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for point in entity.get("p", []):
		out.append(Vector2(point[0], point[1]))
	return out

func solid(parent: Node3D, at: Vector3, yaw: float, size: Vector3, color: Color, alpha := 1.0, mesh_size := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation.y = yaw
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	var display := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size if mesh_size == Vector3.ZERO else mesh_size
	display.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.95
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	display.material_override = material
	body.add_child(display)
	parent.add_child(body)
	return body

func build_wall(parent: Node3D, entity: Dictionary) -> void:
	var style: Dictionary = WALLS.get(String(entity.get("t", "brick_low")), WALLS["brick_low"])
	var points := points_of(entity)
	if bool(entity.get("closed", false)) and points.size() > 2:
		points.append(points[0])
	var base := float(entity.get("y", 0.0))
	var height: float = style["h"]
	var thick: float = style["t"]
	var color := Color(style["color"] as String)
	var cap := Color(style["cap"] as String)
	var glass: bool = style.get("glass", false)
	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var length := a.distance_to(b)
		if length < 0.05:
			continue
		var middle := (a + b) * 0.5
		var yaw := atan2(b.x - a.x, b.y - a.y)
		if style.get("model", false):
			jersey_run(parent, a, b, base, yaw)
			continue
		var body := solid(parent, Vector3(middle.x, base + height / 2.0, middle.y), yaw, Vector3(thick, height, length + thick),
			color, 0.4 if glass else 1.0)
		if not glass:
			var top := MeshInstance3D.new()
			var top_mesh := BoxMesh.new()
			top_mesh.size = Vector3(thick * 1.12, 0.07, length + thick * 1.12)
			top.mesh = top_mesh
			var top_material := StandardMaterial3D.new()
			top_material.albedo_color = cap
			top.material_override = top_material
			top.position.y = height / 2.0 + 0.03
			body.add_child(top)
	# a post at every vertex so corners and T-joints close up cleanly
	if not style.get("model", false):
		for point in points:
			solid(parent, Vector3(point.x, base + height / 2.0 + 0.02, point.y), 0.0,
				Vector3(thick * 1.1, height + 0.04, thick * 1.1), cap if glass else color.darkened(0.08))
	mark_run(parent, points, thick * 0.5 + 0.9)

func jersey_run(parent: Node3D, a: Vector2, b: Vector2, base: float, yaw: float) -> void:
	var length := a.distance_to(b)
	var pieces := maxi(1, int(round(length / 2.5)))
	var piece := length / pieces
	var scene := STREET_PROPS.new().scene_for("jersey_barrier")
	for index in range(pieces):
		var centre := a.lerp(b, (index + 0.5) / pieces)
		var body := StaticBody3D.new()
		body.position = Vector3(centre.x, base, centre.y)
		body.rotation.y = yaw
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.6, 0.85, piece)
		collider.shape = shape
		collider.position.y = 0.425
		body.add_child(collider)
		if scene != null:
			var model := scene.instantiate() as Node3D
			model.scale = Vector3(1, 1, piece / 2.5)
			body.add_child(model)
		parent.add_child(body)

# Invisible markers every few metres so grass, dirt and rubble stay off walls and roads.
func mark_run(parent: Node3D, points: Array[Vector2], radius: float) -> void:
	for index in range(points.size() - 1):
		var a := points[index]
		var b := points[index + 1]
		var steps := maxi(1, int(a.distance_to(b) / 2.0))
		for step in range(steps + 1):
			var at := a.lerp(b, float(step) / steps)
			var marker := Node3D.new()
			marker.position = Vector3(at.x, 0, at.y)
			marker.set_meta("keep_radius", radius)
			marker.add_to_group("keep_out")
			parent.add_child(marker)

# --- roads -----------------------------------------------------------------------------------

func build_road(parent: Node3D, entity: Dictionary, all: Array, index: int) -> void:
	var style: Dictionary = ROADS.get(String(entity.get("t", "asphalt")), ROADS["asphalt"])
	var width := float(entity.get("w", 6.0))
	var points := points_of(entity)
	if points.size() < 2:
		return
	var level := 0.02 + float(index % 6) * 0.0012
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curbs := SurfaceTool.new()
	curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(points.size() - 1):
		strip(surface, points[segment], points[segment + 1], width, level)
		if entity.get("walk", true):
			strip(curbs, points[segment], points[segment + 1], width + SIDEWALK * 2.0, 0.013)
	for joint in range(1, points.size() - 1): # fill the wedge on the outside of every bend
		disc(surface, points[joint], width * 0.5, level)
		if entity.get("walk", true):
			disc(curbs, points[joint], width * 0.5 + SIDEWALK, 0.013)
	if String(entity.get("t", "asphalt")) == "asphalt":
		for segment in range(points.size() - 1):
			markings(paint, points, segment, width, level + 0.006, all, index)
		for junction in junction_crosswalks(points, width, all, index):
			crosswalk(paint, junction[0], junction[1], width, level + 0.006)
	var root := Node3D.new()
	root.name = "Road"
	parent.add_child(root)
	root.add_child(road_mesh(curbs, Color(style["side"] as String)))
	root.add_child(road_mesh(surface, Color(style["color"] as String)))
	root.add_child(road_mesh(paint, Color(style["line"] as String) if false else Color("#e8e6df")))
	mark_run(root, points, width * 0.5 + (SIDEWALK if entity.get("walk", true) else 0.0) + 0.4)

func road_mesh(tool: SurfaceTool, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := tool.commit()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

func quad(tool: SurfaceTool, corners: Array, level: float) -> void:
	for tri in [[0, 1, 2], [0, 2, 3]]:
		for corner_index in tri:
			var corner: Vector2 = corners[corner_index]
			tool.set_normal(Vector3.UP)
			tool.add_vertex(Vector3(corner.x, level, corner.y))

func strip(tool: SurfaceTool, a: Vector2, b: Vector2, width: float, level: float) -> void:
	var direction := (b - a).normalized()
	var side := Vector2(-direction.y, direction.x) * width * 0.5
	quad(tool, [a - side, b - side, b + side, a + side], level)

func disc(tool: SurfaceTool, centre: Vector2, radius: float, level: float) -> void:
	var count := 20
	for step in range(count):
		var first := centre + Vector2.from_angle(TAU * step / count) * radius
		var second := centre + Vector2.from_angle(TAU * (step + 1) / count) * radius
		for corner in [centre, second, first]:
			tool.set_normal(Vector3.UP)
			tool.add_vertex(Vector3(corner.x, level, corner.y))

func distance_to_other_roads(point: Vector2, all: Array, index: int, extra := 0.0) -> bool:
	for other_index in range(all.size()):
		var other: Dictionary = all[other_index]
		if other_index == index or other.get("k", "") != "road":
			continue
		var other_points := points_of(other)
		var reach := float(other.get("w", 6.0)) * 0.5 + extra
		for segment in range(other_points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, other_points[segment], other_points[segment + 1])
			if closest.distance_to(point) < reach:
				return true
	return false

func markings(tool: SurfaceTool, points: Array[Vector2], segment: int, width: float, level: float, all: Array, index: int) -> void:
	var a := points[segment]
	var b := points[segment + 1]
	var length := a.distance_to(b)
	var direction := (b - a) / maxf(length, 0.001)
	var side := Vector2(-direction.y, direction.x)
	var distance := 1.0
	while distance < length - 1.0:
		var start := a + direction * distance
		var finish := a + direction * minf(distance + 2.0, length - 0.5)
		if not distance_to_other_roads(start, all, index, 0.8) and not distance_to_other_roads(finish, all, index, 0.8):
			quad(tool, [start - side * 0.07, finish - side * 0.07, finish + side * 0.07, start + side * 0.07], level)
		distance += 4.5
	if width >= 7.0: # wider roads get white edge lines
		for sign_value in [-1.0, 1.0]:
			var edge_offset: Vector2 = side * (width * 0.5 - 0.35) * sign_value
			if length > 1.0:
				quad(tool, [a + edge_offset - side * 0.05, b + edge_offset - side * 0.05, b + edge_offset + side * 0.05, a + edge_offset + side * 0.05], level)

# Crosswalk positions: where this road meets or crosses another road, one on each approach.
func junction_crosswalks(points: Array[Vector2], width: float, all: Array, index: int) -> Array:
	var found := []
	for segment in range(points.size() - 1):
		var a := points[segment]
		var b := points[segment + 1]
		var length := a.distance_to(b)
		if length < 0.5:
			continue
		var direction := (b - a) / length
		for other_index in range(all.size()):
			var other: Dictionary = all[other_index]
			if other_index == index or other.get("k", "") != "road":
				continue
			var other_points := points_of(other)
			var other_half := float(other.get("w", 6.0)) * 0.5
			for other_segment in range(other_points.size() - 1):
				var hit = Geometry2D.segment_intersects_segment(a, b, other_points[other_segment], other_points[other_segment + 1])
				if hit == null:
					for end_point in [a, b]:
						var closest := Geometry2D.get_closest_point_to_segment(end_point, other_points[other_segment], other_points[other_segment + 1])
						if closest.distance_to(end_point) < 0.4:
							hit = closest
							break
				if hit == null:
					continue
				var along: float = (hit - a).dot(direction)
				for sign_value in [-1.0, 1.0]:
					var spot: float = along + sign_value * (other_half + SIDEWALK * 0.5 + 1.4)
					if spot > 0.6 and spot < length - 0.6:
						found.append([a + direction * spot, direction])
	return found

func crosswalk(tool: SurfaceTool, centre: Vector2, direction: Vector2, width: float, level: float) -> void:
	var side := Vector2(-direction.y, direction.x)
	var count := int((width - 0.6) / 0.9)
	for step in range(count):
		var offset := (step - (count - 1) / 2.0) * 0.9
		var middle: Vector2 = centre + side * offset
		quad(tool, [middle - direction * 1.2 - side * 0.22, middle + direction * 1.2 - side * 0.22,
			middle + direction * 1.2 + side * 0.22, middle - direction * 1.2 + side * 0.22], level)
