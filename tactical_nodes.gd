extends RefCounted

const RADIUS := 30.0
const LIMIT := 12
const EYE := Vector3(0, 1.18, 0)
const CROUCHED_EYE := Vector3(0, 0.76, 0)

var arena: Node3D
var nodes: Array[Dictionary] = []

func _init(host: Node3D) -> void:
	arena = host
	for child in arena.find_children("*", "Node3D", true, false):
		var point := child as Node3D
		var label := String(point.name)
		if label.begins_with("COVER_"):
			nodes.append({"kind": "cover", "point": point.global_position})
		elif label.begins_with("HIDE_"):
			nodes.append({"kind": "hide", "point": point.global_position, "prop": point.get_parent()})
		elif label.begins_with("CLIMB_START_"):
			var top := point.get_parent().get_node_or_null("CLIMB_TOP_" + label.trim_prefix("CLIMB_START_")) as Node3D
			if top != null and top.global_position.y > point.global_position.y + 0.45:
				nodes.append({"kind": "climb", "point": point.global_position, "top": top.global_position})
	for child in arena.get_children():
		if child is StaticBody3D:
			add_box_cover(child)

func add_box_cover(body: StaticBody3D) -> void:
	for child in body.get_children():
		if not (child is CollisionShape3D and child.shape is BoxShape3D):
			continue
		var dimensions: Vector3 = child.shape.size
		if dimensions.y < 0.65 or dimensions.y > 6.0 or maxf(dimensions.x, dimensions.z) > 12.0:
			continue
		var center: Vector3 = child.global_position
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			var offset: Vector3 = direction * (dimensions * 0.5 + Vector3.ONE * 0.92)
			var position: Vector3 = center + child.global_basis * offset
			position.y = center.y - dimensions.y * 0.5 + 0.08
			nodes.append({"kind": "cover", "point": position})

func blocked(from: Vector3, target: Vector3, excluded: RID) -> bool:
	return arena.trace(from, target, excluded).get("collider") is StaticBody3D

func path_to(nav_map: RID, from: Vector3, to: Vector3) -> PackedVector3Array:
	var path := NavigationServer3D.map_get_path(nav_map, from, to, true)
	if path.is_empty() or path[-1].distance_to(to) > 0.8:
		return PackedVector3Array()
	return path

func evaluate(bot: CharacterBody3D, nav_map: RID, threat: Vector3, kinds: Array[String], caution: float, stealth: float, verticality: float) -> Dictionary:
	var near: Array[Dictionary] = []
	for node in nodes:
		if kinds.has(node["kind"]) and bot.position.distance_squared_to(node["point"]) < RADIUS * RADIUS:
			near.append(node)
	near.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return bot.position.distance_squared_to(a["point"]) < bot.position.distance_squared_to(b["point"]))
	var enemy_eye := threat + EYE
	var best := {}
	var highest := 0.0
	for index in range(mini(LIMIT, near.size())):
		var node := near[index]
		var point: Vector3 = node["point"]
		var path := path_to(nav_map, bot.position, point)
		if path.is_empty():
			continue
		var distance := bot.position.distance_to(point)
		var score := 0.0
		var peek := Vector3.INF
		match node["kind"]:
			"cover":
				if not blocked(point + CROUCHED_EYE, enemy_eye, bot.get_rid()):
					continue
				peek = find_peek(bot, point, enemy_eye, nav_map)
				score = 50.0 * caution * (1.18 if peek.is_finite() else 0.8)
			"hide":
				var prop: Node3D = node["prop"]
				if not prop.get("door_hinges") == null and not prop.get("door_hinges").is_empty() and not prop.get("is_open"):
					continue
				if not blocked(bot.position + EYE, enemy_eye, bot.get_rid()) or not blocked(point + CROUCHED_EYE, enemy_eye, bot.get_rid()):
					continue
				if not concealed_path(bot, path, point, enemy_eye):
					continue
				score = 60.0 * stealth
			"climb":
				var top: Vector3 = node["top"]
				if not blocked(point + EYE, enemy_eye, bot.get_rid()) or blocked(top + EYE, enemy_eye, bot.get_rid()):
					continue
				if top.distance_to(threat) > 29.0:
					continue
				score = 45.0 * verticality
		score *= 1.0 - distance / RADIUS
		if score > highest:
			highest = score
			best = node.duplicate()
			best["peek"] = peek
	return best

func concealed_path(bot: CharacterBody3D, path: PackedVector3Array, point: Vector3, enemy_eye: Vector3) -> bool:
	if blocked(path[-1] + CROUCHED_EYE, point + CROUCHED_EYE, bot.get_rid()):
		return false
	for index in range(path.size()):
		if not blocked(path[index] + CROUCHED_EYE, enemy_eye, bot.get_rid()):
			return false
		if index > 0 and not blocked(path[index - 1].lerp(path[index], 0.5) + CROUCHED_EYE, enemy_eye, bot.get_rid()):
			return false
	return true

func find_peek(bot: CharacterBody3D, point: Vector3, enemy_eye: Vector3, nav_map: RID) -> Vector3:
	var offset := point - enemy_eye
	var side := Vector3(offset.z, 0, -offset.x).normalized()
	for sign_value in [-1.0, 1.0]:
		var peek := NavigationServer3D.map_get_closest_point(nav_map, point + side * sign_value * 1.45)
		if peek.distance_to(point) < 2.2 and not blocked(peek + EYE, enemy_eye, bot.get_rid()):
			if not path_to(nav_map, point, peek).is_empty():
				return peek
	return Vector3.INF
