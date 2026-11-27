extends RefCounted

const TACTICAL_NODES := preload("res://tactical_nodes.gd")
const ROSTER := preload("res://character_roster.gd")

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
	var personality: Array
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
	var burst_left := 0
	var cover := Vector3.INF
	var peek := Vector3.INF
	var cover_focus := Vector3.INF
	var cover_refresh := 0.0
	var hide_left := 0.0
	var camp_anchor := Vector3.INF
	var camp_time := 0.0
	var action := "patrol"
	var visible_count := 0
	var tactic: Dictionary = {}
	var tactic_refresh := 0.0
	var hide_hold := 0.0
	var hide_cooldown := 0.0
	var climbing := false
	var climb_left := 0.0
	var flank_goal := Vector3.INF
	var flank_focus := Vector3.INF

var states: Dictionary = {}
var team_reports: Dictionary = {}
var nav_region: NavigationRegion3D
var high_ground := PackedVector3Array()
var arena: Node3D
var difficulty: int
var step_timer := 0.0
var tactical_nodes: TACTICAL_NODES

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
	tactical_nodes = TACTICAL_NODES.new(arena)
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

func register(bot: CharacterBody3D, team: int, index: int, skin: int) -> void:
	var bot_state := BotState.new()
	bot_state.personality = ROSTER.profile(skin)
	bot_state.role = ROSTER.pick_role(skin)
	bot_state.team = team
	bot_state.marker = MARKERS[bot_state.role]
	bot_state.ammo = arena.MAGAZINES[bot_state.marker]
	bot_state.facing = Vector3(-bot.position.x, 0, -bot.position.z).normalized()
	bot_state.patrol = Vector3(randf_range(-13, 13), 0.1, randf_range(-12, 12))
	bot_state.think_left = 0.12 * index
	bot_state.tactic_refresh = fmod(0.071 * index, 0.5)
	bot_state.flank = 1.0 if index % 2 == 0 else -1.0
	states[bot] = bot_state
	bot.set_meta("team", team)
	bot.set_meta("personality", bot_state.personality[2])
	bot.set_meta("role", ROLE_NAMES[bot_state.role])
	bot.set_meta("marker", bot_state.marker)
	bot.get_meta("paint_sprite").update_motion(bot_state.facing, 0.0, 0.0)

func remove(bot: CharacterBody3D) -> void:
	states.erase(bot)

func heard(source_team: int, point: Vector3, radius: float) -> void:
	for bot in states:
		var bot_state: BotState = states[bot]
		if bot_state.team != source_team and bot.position.distance_to(point) < radius and not is_instance_valid(bot_state.target) and bot_state.memory_left <= 1.2:
			bot_state.memory = point
			bot_state.memory_left = 2.8

func hit(bot: CharacterBody3D, from: Vector3) -> void:
	var bot_state: BotState = states[bot]
	bot_state.last_threat = from
	bot_state.tactic.clear()
	bot_state.climbing = false
	bot_state.hide_hold = 0.0
	bot_state.hide_cooldown = 2.5
	bot.set_meta("tactical_hidden", false)
	bot_state.cover_refresh = 0.0
	bot_state.hide_left = 0.9
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
		heard(0, arena.player.position, 3.0 if arena.crouched else clampf(Vector2(arena.player.velocity.x, arena.player.velocity.z).length() * 2.1, 5.0, 13.0))
		step_timer = 0.35
	for bot in states:
		tick_bot(bot, states[bot], delta)

func tick_bot(bot: CharacterBody3D, state: BotState, delta: float) -> void:
	state.think_left -= delta
	state.tactic_refresh -= delta
	state.hide_cooldown -= delta
	state.hide_hold -= delta
	state.memory_left -= delta
	state.reposition_left -= delta
	state.reaction_left -= delta
	state.shot_left -= delta
	state.cover_refresh -= delta
	state.hide_left -= delta
	if state.reload_left > 0.0:
		state.reload_left = maxf(0.0, state.reload_left - delta)
		if state.reload_left == 0.0:
			state.ammo = arena.MAGAZINES[state.marker]
	if state.climbing:
		tick_climb(bot, state, delta)
		return
	if state.think_left <= 0.0:
		state.think_left = THINK_INTERVAL[difficulty]
		think(bot, state)
	var hiding := state.action == "retreat" or (state.action == "cover" and (state.hide_left > 0.0 or state.reload_left > 0.0))
	var kind: String = state.tactic.get("kind", "")
	var position: Vector3 = state.tactic.get("point", Vector3.INF)
	if kind == "climb" and bot.position.distance_to(position) < 0.7:
		state.climbing = true
		state.climb_left = 2.5
		bot.set_meta("tactical_hidden", false)
		arena.set_bot_crouch(bot, false)
		tick_climb(bot, state, delta)
		return
	var concealed := kind == "hide" and bot.position.distance_to(position) < 0.66
	if concealed and not bot.get_meta("tactical_hidden", false):
		state.hide_hold = 3.5
	if concealed and state.hide_hold <= 0.0:
		concealed = false
		state.tactic.clear()
		state.hide_cooldown = 3.5
	bot.set_meta("tactical_hidden", concealed)
	var under_cover := concealed or (hiding and bot.position.distance_to(state.cover) < 1.05)
	arena.set_bot_crouch(bot, under_cover)
	var ambush := concealed and is_instance_valid(state.target) and state.target.position.distance_to(bot.position) < 9.0
	if (not under_cover or ambush) and is_instance_valid(state.target) and state.shot_left <= 0.0 and state.reaction_left <= 0.0 and state.reload_left <= 0.0:
		var ammo_before := state.ammo
		fire(bot, state)
		if concealed and state.ammo < ammo_before:
			bot.set_meta("tactical_hidden", false)
			state.tactic.clear()
			state.hide_cooldown = 3.5
	follow_path(bot, state, delta)

func tick_climb(bot: CharacterBody3D, state: BotState, delta: float) -> void:
	var top: Vector3 = state.tactic["top"]
	var start: Vector3 = state.tactic["point"]
	var rise := Vector3(start.x, top.y, start.z)
	var waypoint := rise if absf(bot.position.y - top.y) > 0.09 else top
	var motion := (waypoint - bot.position).limit_length(3.7 * delta)
	state.climb_left -= delta
	bot.velocity = Vector3.ZERO
	var collision := bot.move_and_collide(motion)
	var facing := top - rise
	facing.y = 0.0
	if not facing.is_zero_approx():
		state.facing = facing.normalized()
	bot.get_meta("paint_sprite").update_motion(state.facing, 0.0, delta)
	if collision != null or state.climb_left <= 0.0 or bot.position.distance_to(top) <= 0.1:
		state.climbing = false
		state.tactic.clear()
		state.path.clear()
		state.destination = Vector3.INF
		state.tactic_refresh = 2.0

func think(bot: CharacterBody3D, state: BotState) -> void:
	var target := visible_target(bot, state)
	if target != state.target:
		state.reaction_left = REACTION[difficulty] * float(state.personality[7]) * randf_range(0.8, 1.3)
		state.burst_left = 0
		state.target = target
	var visible := is_instance_valid(target)
	if visible:
		state.memory = target.position
		state.memory_left = 5.0
		if state.memory.distance_to(state.camp_anchor) > 1.9:
			state.camp_anchor = state.memory
			state.camp_time = 0.0
		else:
			state.camp_time += THINK_INTERVAL[difficulty]
		if randf() <= SHARE_CHANCE[difficulty]:
			team_reports[state.team] = {"point": state.memory, "remaining": 3.0, "observer": bot}
	elif team_reports.has(state.team):
		var report: Dictionary = team_reports[state.team]
		var observer := report.get("observer") as CharacterBody3D
		if is_instance_valid(observer) and observer != bot and bot.position.distance_to(observer.position) < 26.0:
			state.memory = report["point"]
			state.memory_left = maxf(state.memory_left, float(report["remaining"]))
	if state.memory_left <= 0.0 and not bot.get_meta("tactical_hidden", false):
		state.tactic.clear()
		state.camp_time = 0.0
		state.camp_anchor = Vector3.INF
		state.action = "patrol"
		if bot.position.distance_to(state.patrol) < 1.4:
			state.patrol = Vector3(randf_range(-17, 17), 0.1, randf_range(-15, 15))
		var patrol := state.patrol
		if state.role == Role.MARKSMAN and not high_ground.is_empty():
			patrol = elevated_position(bot, state, patrol)
		set_destination(bot, state, patrol)
		return
	var focus := state.memory
	var away := Vector3(bot.position.x - focus.x, 0, bot.position.z - focus.z).normalized()
	if away.is_zero_approx():
		away = Vector3.FORWARD
	var previous := state.action
	state.action = choose_action(bot, state, visible)
	var destination := focus
	if bot.get_meta("tactical_hidden", false) and state.hide_hold > 0.0 and not state.tactic.is_empty():
		set_destination(bot, state, state.tactic["point"])
		return
	if state.tactic_refresh <= 0.0:
		state.tactic_refresh = 0.5 + randf_range(-0.05, 0.05)
		var kinds: Array[String] = []
		if state.action == "cover" or state.action == "retreat":
			kinds.append("cover")
		if not visible and state.hide_cooldown <= 0.0 and state.role in [Role.FLANKER, Role.GUARD]:
			kinds.append("hide")
		if state.role == Role.MARKSMAN and state.action != "retreat" and state.reload_left <= 0.0:
			kinds.append("climb")
		state.tactic = tactical_nodes.evaluate(bot, nav_region.get_navigation_map(), focus, kinds,
			1.0 + float(state.personality[6]) * 0.3, 1.0 + float(state.personality[5]) * 0.25,
			1.65 if state.role == Role.MARKSMAN else 0.75)
	var kind: String = state.tactic.get("kind", "")
	if kind == "climb" or (kind == "hide" and not visible):
		set_destination(bot, state, state.tactic["point"])
		return
	match state.action:
		"search":
			if bot.position.distance_to(focus) < 1.2:
				destination = focus + away.rotated(Vector3.UP, state.flank * 1.3) * 3.0
		"retreat", "cover":
			var retreat := state.action == "retreat"
			if previous != state.action or state.cover_refresh <= 0.0 or state.cover_focus.distance_to(focus) > 3.5:
				var positions := PackedVector3Array([state.tactic["point"], state.tactic["peek"]]) if kind == "cover" else cover_position(bot, focus, retreat)
				state.cover = positions[0]
				state.peek = positions[1]
				state.cover_focus = focus
				state.cover_refresh = 1.65
				if previous != state.action:
					state.hide_left = 0.7
			destination = state.cover
			if not retreat and state.reload_left <= 0.0 and state.hide_left <= 0.0 and state.peek.is_finite():
				destination = state.peek
			if not destination.is_finite():
				destination = focus + away * (bot.position.distance_to(focus) + 5.0)
		"flank":
			if previous != state.action or state.flank_focus.distance_to(focus) > 3.5:
				state.flank_goal = focus + away.rotated(Vector3.UP, state.flank * 1.12) * STANDOFF[state.role]
				state.flank_focus = focus
			destination = state.flank_goal
			if bot.position.distance_to(destination) < 1.6:
				state.action = "engage"
				state.camp_time = 0.0
				destination = bot.position
		"engage":
			if state.role == Role.MARKSMAN and not high_ground.is_empty():
				destination = elevated_position(bot, state, focus)
			elif bot.position.distance_to(focus) <= STANDOFF[state.role] + 3.5:
				destination = bot.position
			else:
				destination = focus + away * STANDOFF[state.role]
	set_destination(bot, state, destination)

func choose_action(bot: CharacterBody3D, state: BotState, visible: bool) -> String:
	var allies := 0
	var threats := {}
	if visible:
		threats[state.target] = true
	for teammate in states:
		var other: BotState = states[teammate]
		if teammate == bot or other.team != state.team or bot.position.distance_to(teammate.position) > 16.0:
			continue
		allies += 1
		if is_instance_valid(other.target):
			threats[other.target] = true
	var wounded := int(bot.get_meta("health")) <= 2
	var pressure := maxi(0, maxi(state.visible_count, threats.size()) - allies - 1)
	var camper := clampf(state.camp_time / 4.0, 0.0, 1.0)
	var scores := {
		"search": 2.5 if not visible else -1.0,
		"engage": 3.6 if visible else 0.0,
		"flank": (3.35 if state.role == Role.FLANKER else 1.2) + camper * 4.0 + minf(allies, 2) * 0.4 + float(state.personality[5]),
		"cover": 0.65 + float(state.personality[6]) + (6.0 if state.reload_left > 0.0 else 0.0) + (4.0 if state.reposition_left > 0.0 else 0.0),
		"retreat": (4.8 if wounded and (state.reposition_left > -2.0 or state.visible_count > 1) else 0.0) + pressure * 2.6,
	}
	var best := "search"
	var highest := -INF
	for action in scores:
		var score: float = scores[action] + (0.35 if action == state.action else 0.0)
		if score > highest:
			best = action
			highest = score
	return best

func visible_target(bot: CharacterBody3D, state: BotState) -> CharacterBody3D:
	var candidates: Array = arena.bots.duplicate()
	if state.team != 0:
		candidates.append(arena.player)
	var best: CharacterBody3D
	var best_distance := 31.0
	state.visible_count = 0
	var origin := bot.position + Vector3.UP * (0.78 if bot.get_meta("crouched") else 1.22)
	for candidate in candidates:
		if candidate == bot or int(candidate.get_meta("team", 0)) == state.team:
			continue
		var end: Vector3 = candidate.position + Vector3.UP * (0.72 if (arena.crouched if candidate == arena.player else candidate.get_meta("crouched", false)) else 1.12)
		var difference := end - origin
		var distance := difference.length()
		if candidate.get_meta("tactical_hidden", false) and distance > 3.0:
			continue
		if distance >= 31.0:
			continue
		if candidate == arena.player and arena.player.get("hiding") and distance > 5.0:
			continue # hiding inside a prop: only spotted from close range
		if distance > 5.0 and candidate != state.target and state.facing.dot(difference.normalized()) < 0.28:
			continue
		var hit: Dictionary = arena.trace(origin, end, bot.get_rid())
		if hit.get("collider") == candidate:
			state.visible_count += 1
			if distance < best_distance:
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

func cover_position(bot: CharacterBody3D, threat: Vector3, retreat: bool) -> PackedVector3Array:
	var origin := threat + Vector3.UP * 1.14
	var best := Vector3.INF
	var best_peek := Vector3.INF
	var best_score := -INF
	var nav_map := nav_region.get_navigation_map()
	for index in range(12):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, index * TAU / 12.0)
		var point := NavigationServer3D.map_get_closest_point(nav_map, bot.position + direction * (3.2 if index % 2 == 0 else 6.0))
		var distance := bot.position.distance_to(point)
		if distance > 9.0 or absf(point.y - bot.position.y) > 0.8:
			continue
		var hit: Dictionary = arena.trace(point + Vector3.UP * 0.78, origin, bot.get_rid())
		if not hit.get("collider") is StaticBody3D:
			continue
		var path := NavigationServer3D.map_get_path(nav_map, bot.position, point, true)
		if path.is_empty() or path[-1].distance_to(point) > 0.75:
			continue
		var side := Vector3(point.z - threat.z, 0, threat.x - point.x).normalized()
		var peek := Vector3.INF
		for sign_value in [-1.0, 1.0]:
			var open_point := NavigationServer3D.map_get_closest_point(nav_map, point + side * sign_value * 1.55)
			if open_point.distance_to(point) > 2.0 or absf(open_point.y - point.y) > 0.5:
				continue
			var lane: Dictionary = arena.trace(open_point + Vector3.UP * 1.22, origin, bot.get_rid())
			if not lane.get("collider") is StaticBody3D:
				var peek_path := NavigationServer3D.map_get_path(nav_map, point, open_point, true)
				if not peek_path.is_empty() and peek_path[-1].distance_to(open_point) < 0.6:
					peek = open_point
					break
		var score := (point.distance_to(threat) - bot.position.distance_to(threat)) * (0.7 if retreat else 0.18) - distance * 0.45
		if peek.is_finite():
			score += 0.8 if retreat else 3.8
		if score > best_score:
			best = point
			best_peek = peek
			best_score = score
	return PackedVector3Array([best, best_peek])

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
		var face := state.memory - bot.position
		face.y = 0
		state.facing = state.facing.lerp(face.normalized(), clampf(delta * 8.0, 0.0, 1.0)).normalized()
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
	if state.burst_left <= 0:
		state.burst_left = randi_range(2, 4) if state.marker == 0 else 1
	state.burst_left -= 1
	state.shot_left = maxf(float(arena.SHOT_INTERVALS[state.marker]), 0.22) * randf_range(1.04, 1.32)
	if state.burst_left == 0:
		state.shot_left += randf_range(0.45, 0.88)
	state.ammo -= 1
	if state.ammo == 0:
		state.reload_left = arena.RELOAD_TIMES[state.marker]
