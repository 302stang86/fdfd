extends RefCounted

enum Role { RUSHER, FLANKER, MARKSMAN, GUARD, WILDCARD }

const MARKERS := [0, 0, 1, 0, 2]
const ROLE_NAMES := ["Rusher", "Flanker", "Marksman", "Guard", "Wildcard"]
const REACTION := [0.64, 0.38, 0.24]
const AIM_SPREAD := [0.105, 0.071, 0.045]
const THINK_INTERVAL := [0.36, 0.26, 0.19]
const SHARE_CHANCE := [0.55, 0.83, 1.0]
const STANDOFF := [6.0, 9.0, 17.0, 12.5, 10.5]

class BotState:
	var role: int
	var team: int
	var marker: int
	var ammo: int
	var facing := Vector3.FORWARD
	var target: CharacterBody3D
	var memory := Vector3.ZERO
	var memory_left := 0.0
	var last_threat := Vector3.ZERO
	var reposition_left := 0.0
	var reaction_left := 0.0
	var think_left := 0.0
	var shot_left := 0.0
	var reload_left := 0.0
	var path := PackedVector3Array()
	var path_index := 0
	var destination := Vector3.INF
	var patrol := Vector3.ZERO
	var flank := 1.0

var states: Dictionary = {}
var team_reports: Dictionary = {}
var nav_region: NavigationRegion3D
var high_ground := PackedVector3Array()
var arena: Node3D
var difficulty: int
var step_timer := 0.0

func _init(owner_arena: Node3D, level: int) -> void:
	arena = owner_arena
	difficulty = clampi(level, 0, 2)

func bake_map() -> void:
	var geometry := NavigationMeshSourceGeometryData3D.new()
	for body in arena.get_children():
		if not body is StaticBody3D:
			continue
		for collider in body.get_children():
			if collider is CollisionShape3D and collider.shape is BoxShape3D:
				geometry.add_faces(box_faces(collider.shape.size), collider.global_transform)
	var mesh := NavigationMesh.new()
	mesh.agent_height = 1.625
	mesh.agent_radius = 0.5
	mesh.agent_max_climb = 0.375
	mesh.agent_max_slope = 40.0
	mesh.cell_size = 0.25
	mesh.cell_height = 0.125
	mesh.region_min_size = 2.0
	NavigationServer3D.bake_from_source_geometry_data(mesh, geometry)
	nav_region = NavigationRegion3D.new()
	nav_region.navigation_mesh = mesh
	var nav_map := NavigationServer3D.map_create()
	NavigationServer3D.map_set_use_async_iterations(nav_map, false)
	NavigationServer3D.map_set_cell_height(nav_map, mesh.cell_height)
	NavigationServer3D.map_set_cell_size(nav_map, mesh.cell_size)
	NavigationServer3D.map_set_active(nav_map, true)
	nav_region.set_navigation_map(nav_map)
	nav_region.tree_exited.connect(func(): NavigationServer3D.free_rid(nav_map))
	arena.add_child(nav_region)
	for vertex in mesh.get_vertices():
		if vertex.y > 0.8 and vertex.y < 3.3:
			high_ground.append(vertex)

func box_faces(size: Vector3) -> PackedVector3Array:
	var half := size * 0.5
	var points := [
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z),
		Vector3(-half.x, half.y, -half.z), Vector3(half.x, half.y, -half.z),
		Vector3(half.x, half.y, half.z), Vector3(-half.x, half.y, half.z)
	]
	var indices := [4, 5, 6, 4, 6, 7, 0, 2, 1, 0, 3, 2,
		0, 1, 5, 0, 5, 4, 1, 2, 6, 1, 6, 5,
		2, 3, 7, 2, 7, 6, 3, 0, 4, 3, 4, 7]
	var faces := PackedVector3Array()
	for index in indices:
		faces.append(points[index])
	return faces

func reset() -> void:
	states.clear()
	team_reports.clear()
	step_timer = 0.0

func register(bot: CharacterBody3D, team: int, index: int) -> void:
	var bot_state := BotState.new()
	bot_state.role = randi_range(0, ROLE_NAMES.size() - 1)
	bot_state.team = team
	bot_state.marker = MARKERS[bot_state.role]
	bot_state.ammo = arena.MAGAZINES[bot_state.marker]
	bot_state.facing = Vector3(-bot.position.x, 0, -bot.position.z).normalized()
	bot_state.patrol = Vector3(randf_range(-13, 13), 0.1, randf_range(-12, 12))
	bot_state.think_left = 0.12 * index
	bot_state.flank = 1.0 if index % 2 == 0 else -1.0
	states[bot] = bot_state
	bot.set_meta("team", team)
	bot.set_meta("role", ROLE_NAMES[bot_state.role])
	bot.set_meta("marker", bot_state.marker)
	bot.get_meta("paint_sprite").update_motion(bot_state.facing, 0.0, 0.0)

func remove(bot: CharacterBody3D) -> void:
	states.erase(bot)

func heard(source_team: int, point: Vector3, radius: float) -> void:
	for bot in states:
		var bot_state: BotState = states[bot]
		if bot_state.team != source_team and bot.position.distance_to(point) < radius and not is_instance_valid(bot_state.target):
			bot_state.memory = point
			bot_state.memory_left = 4.0

func hit(bot: CharacterBody3D, from: Vector3) -> void:
	var bot_state: BotState = states[bot]
	bot_state.last_threat = from
	bot_state.memory = from
	bot_state.memory_left = 4.0
	bot_state.reposition_left = 2.4 if bot_state.role != Role.WILDCARD else 1.0
	bot_state.think_left = 0.0
	bot_state.path.clear()
	bot_state.destination = Vector3.INF

func update(delta: float) -> void:
	for team in team_reports.keys():
		team_reports[team]["remaining"] -= delta
		if team_reports[team]["remaining"] <= 0.0:
			team_reports.erase(team)
	step_timer -= delta
	if step_timer <= 0.0 and arena.player.is_on_floor() and Vector2(arena.player.velocity.x, arena.player.velocity.z).length() > 0.5:
		heard(0, arena.player.position, 3.0 if arena.crouched else 9.0)
		step_timer = 0.35
	for bot in states:
		tick_bot(bot, states[bot], delta)

func tick_bot(bot: CharacterBody3D, state: BotState, delta: float) -> void:
	state.think_left -= delta
	state.memory_left -= delta
	state.reposition_left -= delta
	state.reaction_left -= delta
	state.shot_left -= delta
	if state.reload_left > 0.0:
		state.reload_left = maxf(0.0, state.reload_left - delta)
		if state.reload_left == 0.0:
			state.ammo = arena.MAGAZINES[state.marker]
	if state.think_left <= 0.0:
		state.think_left = THINK_INTERVAL[difficulty]
		think(bot, state)
	if is_instance_valid(state.target) and state.shot_left <= 0.0 and state.reaction_left <= 0.0 and state.reload_left <= 0.0:
		fire(bot, state)
	arena.set_bot_crouch(bot, state.reload_left > 0.0 or state.reposition_left > 0.0 and state.role == Role.GUARD)
	follow_path(bot, state, delta)

func think(bot: CharacterBody3D, state: BotState) -> void:
	var target := visible_target(bot, state)
	if target != state.target:
		state.reaction_left = REACTION[difficulty]
	state.target = target
	if is_instance_valid(target):
		state.memory = target.position
		state.memory_left = 5.0
		if randf() <= SHARE_CHANCE[difficulty]:
			team_reports[state.team] = {"point": state.memory, "remaining": 3.0}
	elif state.memory_left <= 0.0 and team_reports.has(state.team):
		state.memory = team_reports[state.team]["point"]
		state.memory_left = 2.5

	var informed := state.memory_left > 0.0
	var focus := state.memory if informed else state.patrol
	var away := Vector3(bot.position.x - focus.x, 0, bot.position.z - focus.z).normalized()
	var destination := focus
	var wounded := int(bot.get_meta("health")) <= 1
	var has_enemy := is_instance_valid(target)
	if not informed and bot.position.distance_to(focus) < 1.4:
		state.patrol = Vector3(randf_range(-17, 17), 0.1, randf_range(-15, 15))
		destination = state.patrol
	if state.role == Role.MARKSMAN and not high_ground.is_empty():
		destination = elevated_position(bot, state, focus)
	elif (state.reposition_left > 0.0 and state.role != Role.RUSHER) or state.reload_left > 0.0:
		var threat := state.last_threat if state.reposition_left > 0.0 else focus
		destination = cover_position(bot, threat)
	elif informed:
		match state.role:
			Role.RUSHER:
				destination = focus + away * (8.0 if wounded and state.reposition_left > 0.0 else 5.0)
			Role.FLANKER:
				if has_enemy and bot.position.distance_to(focus) < 7.0:
					destination = bot.position
				else:
					destination = focus + away.rotated(Vector3.UP, state.flank * 1.25) * 8.0
			Role.GUARD:
				if has_enemy and not wounded and bot.position.distance_to(focus) <= 14.0:
					destination = bot.position
				elif wounded:
					destination = cover_position(bot, focus)
				else:
					destination = focus + away * STANDOFF[state.role]
			Role.WILDCARD:
				destination = focus + away.rotated(Vector3.UP, state.flank * 0.65) * (7.0 if wounded else 11.0)
			_:
				destination = focus + away * STANDOFF[state.role]
	set_destination(bot, state, destination)

func visible_target(bot: CharacterBody3D, state: BotState) -> CharacterBody3D:
	var candidates: Array = arena.bots.duplicate()
	if state.team != 0:
		candidates.append(arena.player)
	var best: CharacterBody3D
	var best_distance := 31.0
	var origin := bot.position + Vector3.UP * (0.78 if bot.get_meta("crouched") else 1.22)
	for candidate in candidates:
		if candidate == bot or int(candidate.get_meta("team", 0)) == state.team:
			continue
		var end: Vector3 = candidate.position + Vector3.UP * (0.72 if (arena.crouched if candidate == arena.player else candidate.get_meta("crouched", false)) else 1.12)
		var difference := end - origin
		var distance := difference.length()
		if distance >= best_distance:
			continue
		if candidate == arena.player and arena.player.get("hiding") and distance > 5.0:
			continue # hiding inside a prop: only spotted from close range
		if distance > 5.0 and candidate != state.target and state.facing.dot(difference.normalized()) < 0.28:
			continue
		var hit: Dictionary = arena.trace(origin, end, bot.get_rid())
		if hit.get("collider") == candidate:
			best = candidate
			best_distance = distance
	return best

func elevated_position(bot: CharacterBody3D, state: BotState, focus: Vector3) -> Vector3:
	var best := bot.position
	var best_score := -INF
	var nav_map := nav_region.get_navigation_map()
	var checked := 0
	for point in high_ground:
		checked += 1
		if checked % maxi(1, floori(high_ground.size() / 24.0)) != 0:
			continue
		var distance := bot.position.distance_to(point)
		var path := NavigationServer3D.map_get_path(nav_map, bot.position, point, true)
		if path.is_empty() or path[-1].distance_to(point) > 1.15:
			continue
		var score := -distance * 0.8 - absf(point.distance_to(focus) - 13.0) * 0.24
		if state.reposition_left > 0.0 and distance < 3.0:
			score -= 12.0
		if score > best_score:
			best = point
			best_score = score
	return best

func cover_position(bot: CharacterBody3D, threat: Vector3) -> Vector3:
	var origin := threat + Vector3.UP * 1.14
	var best := bot.position
	var best_score := -INF
	var nav_map := nav_region.get_navigation_map()
	for index in range(12):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, index * TAU / 12.0)
		var point := NavigationServer3D.map_get_closest_point(nav_map, bot.position + direction * 5.0)
		var distance := bot.position.distance_to(point)
		if distance < 1.0 or distance > 9.0 or absf(point.y - bot.position.y) > 0.8:
			continue
		var hit: Dictionary = arena.trace(origin, point + Vector3.UP * 0.85, bot.get_rid())
		var score := point.distance_to(threat) * 0.3 - distance * 0.1
		if hit.get("collider") is StaticBody3D:
			score += 9.0
		if score > best_score:
			best = point
			best_score = score
	return best

func set_destination(bot: CharacterBody3D, state: BotState, destination: Vector3) -> void:
	if bot.position.distance_to(destination) < 0.75:
		state.path.clear()
		return
	if state.destination.distance_to(destination) < 0.9 and state.path_index < state.path.size():
		return
	state.destination = destination
	state.path = NavigationServer3D.map_get_path(nav_region.get_navigation_map(), bot.position, destination, true)
	state.path_index = 1

func follow_path(bot: CharacterBody3D, state: BotState, delta: float) -> void:
	var travel := Vector3.ZERO
	while state.path_index < state.path.size():
		var offset := state.path[state.path_index] - bot.position
		offset.y = 0
		if offset.length() > 0.43:
			travel = offset.normalized()
			break
		state.path_index += 1
	if is_instance_valid(state.target):
		var face := state.target.position - bot.position
		face.y = 0
		state.facing = face.normalized()
	elif not travel.is_zero_approx():
		state.facing = travel
	var speed := 1.7 if bot.get_meta("crouched") else (3.35 if state.role == Role.RUSHER else 2.7)
	bot.velocity.x = travel.x * speed
	bot.velocity.z = travel.z * speed
	bot.velocity.y -= 12.0 * delta
	bot.move_and_slide()
	var motion := bot.get_real_velocity()
	motion.y = 0.0
	bot.get_meta("paint_sprite").update_motion(state.facing, motion.length(), delta)

func fire(bot: CharacterBody3D, state: BotState) -> void:
	var origin := bot.position + Vector3.UP * (0.72 if bot.get_meta("crouched") else 1.22)
	var aim := state.target.position + Vector3.UP * (0.58 if (arena.crouched if state.target == arena.player else state.target.get_meta("crouched", false)) else 0.86)
	var distance := origin.distance_to(aim)
	var max_range := 29.0 if state.marker == 1 else 21.0
	if distance > max_range or (state.marker == 2 and distance < 4.0):
		return
	var hit: Dictionary = arena.trace(origin, aim, bot.get_rid())
	if hit.get("collider") != state.target:
		return
	var spread: float = AIM_SPREAD[difficulty] * maxf(4.0, distance) * (1.18 if state.target.velocity.length() > 1.0 else 0.83)
	var offset := Vector3(randfn(0.0, spread), randfn(0.0, spread * 0.66), randfn(0.0, spread))
	arena.launch_paintball(origin, aim + offset, bot.get_rid(), state.team, state.marker)
	state.shot_left = maxf(float(arena.SHOT_INTERVALS[state.marker]), 0.53) * randf_range(1.08, 1.45)
	state.ammo -= 1
	if state.ammo == 0:
		state.reload_left = arena.RELOAD_TIMES[state.marker]
