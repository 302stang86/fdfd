extends Node3D

const SPEED := 5.0
const CROUCH_SPEED := 2.65
const STANDING_HEIGHT := 1.5
const CROUCH_HEIGHT := 1.0
const STANDING_EYE := 1.35
const CROUCH_EYE := 0.85
const LOOK := 0.0025
const COUNTDOWN_DURATION := 3.0
const GO_DURATION := 0.55
const MAX_HEALTH := 5
const TIMED_SECONDS := 180.0
const TOUCH_CONTROLS := preload("res://touch_controls.gd")
const ARENA_SIZE := 96.0
const URBAN_MAP := 2
const URBAN_BORDER := preload("res://urban_border.gd")
const BUILDING_MODELS: Array[PackedScene] = [
	preload("res://assets/models/building_brick.glb"),
	preload("res://assets/models/building_boarded.glb"),
	preload("res://assets/opengameart/industrial/warehouse_facade.tscn"),
]
const CHAIN_LINK_MODELS: Array[PackedScene] = [preload("res://assets/models/chain_link_fence.glb")]
const WOOD_FENCE_MODELS: Array[PackedScene] = [preload("res://assets/models/wood_fence.glb")]
const RUBBLE_MODELS: Array[PackedScene] = [preload("res://assets/models/rubble_pile.glb")]
const CAR_WRECK_MODELS: Array[PackedScene] = [preload("res://assets/models/car_wreck.glb")]
const ARENA_EDGE := ARENA_SIZE / 2.0
const BOT_AI := preload("res://bot_ai.gd")
const BOT_MODEL := preload("res://bot_model.gd")
const ARENA_SCENERY := preload("res://arena_scenery.gd")
const STREET_PROPS := preload("res://street_props.gd")
const PLAYER_BODY := preload("res://player_body.gd")
const MAP_LAYOUT := preload("res://map_layout.gd")
const SPLAT_SECONDS := 4.0
const PAINT_SPLAT := preload("res://paint_splat.gd")
const LAUNCHER_SPLIT_DISTANCE := 1.0
const LAUNCHER_SPREAD_RADIUS := 0.34
const LAUNCHER_HIT_CAP := 2
const CROSSHAIR := preload("res://crosshair.gd")
const PLAYER_PAINT := Color("#278cff")
const BOT_PAINT := Color("#fa4eaa")
const SHOT_SOUNDS: Array[AudioStream] = [
	preload("res://assets/opengameart/audio/sks.wav"),
	preload("res://assets/opengameart/audio/mosin.wav"),
	preload("res://assets/opengameart/audio/shotty.wav"),
]
const CONTAINER_COVER: Array[PackedScene] = [
	preload("res://assets/opengameart/industrial/shipping-container-a.glb"),
	preload("res://assets/opengameart/industrial/shipping-container-b.glb"),
]
const MARKER_VIEW := preload("res://marker_view.gd")
const PROJECTILE_SPEEDS := [48.0, 66.0, 29.0]

class LauncherBurst:
	var hits: Dictionary = {}

	func register(target: Node3D) -> bool:
		var id := target.get_instance_id()
		var count := int(hits.get(id, 0))
		if count >= LAUNCHER_HIT_CAP:
			return false
		hits[id] = count + 1
		return true

class Paintball:
	var mesh: MeshInstance3D
	var velocity: Vector3
	var excluded: RID
	var color: Color
	var team: int
	var source: Vector3
	var can_split := false
	var burst: LauncherBurst
	var distance_left := 70.0

signal menu_requested

const MAGAZINES := [16, 6, 4]
const RELOAD_TIMES := [2.0, 0.85, 1.5]
const SHOT_INTERVALS := [0.11, 0.85, 1.15]

var marker_id := 0
var map_id := 0
var outfit_color := Color("#63774b")
var custom_layout: Dictionary = {}
var cheats: Dictionary = {} # set by the menu once cheat mode is unlocked
var shot_audio: AudioStreamPlayer

func magazine_size() -> int:
	return MAGAZINES[marker_id]

var player: CharacterBody3D
var player_collider: CollisionShape3D
var standing_capsule: CapsuleShape3D
var crouching_capsule: CapsuleShape3D
var crouched := false
var camera: Camera3D
var marker_view: MARKER_VIEW
var hud: Label
var loss_popup: ColorRect
var return_button: Button
var hit_circles: Array[Panel] = []
var empty_hit_style: StyleBoxFlat
var filled_hit_style: StyleBoxFlat
var crosshair: CROSSHAIR
var crosshair_style := 0
var crosshair_color := CROSSHAIR.RETICLE_COLORS[3]
var crosshair_size := CROSSHAIR.DEFAULT_SIZE
var player_paint := PLAYER_PAINT
var countdown_label: Label
var countdown_left := COUNTDOWN_DURATION
var go_left := 0.0
var bots: Array[CharacterBody3D] = []
var bot_ai: BOT_AI
var team_match := false
var six_vs_six := false
var timed_match := false
var mobile_mode := false
var time_left := TIMED_SECONDS
var team_hits := [0, 0]
var touch: TOUCH_CONTROLS
var result_message: Label
const COYOTE_SECONDS := 0.12
const JUMP_BUFFER_SECONDS := 0.12

var jump_held := false
var coyote_left := 0.0
var jump_buffer_left := 0.0
var difficulty := 1
var paintballs: Array[Paintball] = []
var arena_splats: Node3D
var paintball_mesh: SphereMesh
var spawn := Vector3(0, 0.1, 35)
var ammo := 16
var health := MAX_HEALTH
var reload := 0.0
var cooldown := 0.0
var outcome := ""
var fire_requested := false

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#87a7bd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("#cad9ea")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)

	box(Vector3(0, -0.25, 0), Vector3(ARENA_SIZE, 0.5, ARENA_SIZE), Color("#30363a") if map_id == URBAN_MAP else Color("#485842"))
	for side in [-1, 1]:
		if map_id != URBAN_MAP:
			box(Vector3(side * ARENA_EDGE, 1.5, 0), Vector3(0.5, 3, ARENA_SIZE), Color("#323e43"))
			box(Vector3(0, 1.5, side * ARENA_EDGE), Vector3(ARENA_SIZE, 3, 0.5), Color("#323e43"))
		if map_id != 0:
			continue
		for z in [-16, -6, 5, 14]:
			box(Vector3(side * 13, 0.65, z), Vector3(3, 1.3, 1), Color("#a17443"))
	if map_id == 0:
		for side in [-1, 1]:
			for z in [-33, -22, 1, 21, 33]:
				box(Vector3(side * 34, 0.7, z), Vector3(4, 1.4, 1.3), Color("#a17443"))
			for z in [-27, -12, 15, 28]:
				box(Vector3(side * 24, 0.65, z), Vector3(2.4, 1.3, 2.4), Color("#647984"))
			for z in [-39, 25, 39]:
				box(Vector3(side * 9, 0.65, z), Vector3(3.5, 1.3, 1.2), Color("#a17443"))
		build_field_day()
	elif map_id == URBAN_MAP:
		build_urban_arena()
	elif map_id > URBAN_MAP and MAP_LAYOUT.is_v2(custom_layout):
		MAP_LAYOUT.new().build(self, custom_layout)
	elif map_id > URBAN_MAP:
		for cell in custom_layout:
			var coordinates := String(cell).split(",")
			if coordinates.size() != 2 or not coordinates[0].is_valid_int() or not coordinates[1].is_valid_int():
				continue
			var x := coordinates[0].to_int()
			var z := coordinates[1].to_int()
			if absi(x) <= 20 and absi(z) <= 16:
				STREET_PROPS.new().place_cell(self, Vector2(x, z), custom_layout[cell])

	var scenery := ARENA_SCENERY.new()
	add_child(scenery)
	scenery.build(self, ARENA_EDGE, map_id, urban_footprint() if map_id == URBAN_MAP else PackedVector2Array())
	arena_splats = Node3D.new()
	add_child(arena_splats)
	paintball_mesh = SphereMesh.new()
	paintball_mesh.radius = 0.06
	paintball_mesh.height = 0.12
	paintball_mesh.radial_segments = 8
	paintball_mesh.rings = 4

	player = actor(spawn)
	player.floor_snap_length = 0.35
	player.floor_constant_speed = true
	camera = Camera3D.new()
	camera.position.y = STANDING_EYE
	camera.current = true
	player.add_child(camera)
	marker_view = MARKER_VIEW.new()
	camera.add_child(marker_view)
	marker_view.build(marker_id, outfit_color)
	create_shot_audio()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	hud = Label.new()
	hud.position = Vector2(20, 18)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color("#172021"))
	hud.add_theme_constant_override("outline_size", 6)
	overlay.add_child(hud)
	create_hit_counter(overlay)
	crosshair = CROSSHAIR.new()
	crosshair.style_index = crosshair_style
	crosshair.ink = crosshair_color
	crosshair.diameter = crosshair_size
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 76)
	countdown_label.add_theme_constant_override("outline_size", 13)
	countdown_label.add_theme_color_override("font_outline_color", Color("#172021"))
	center.add_child(countdown_label)
	if mobile_mode:
		touch = TOUCH_CONTROLS.new()
		overlay.add_child(touch)
	create_loss_popup(overlay)
	bot_ai = BOT_AI.new(self, difficulty)
	bot_ai.bake_map()
	await get_tree().physics_frame
	await get_tree().physics_frame
	start_match()
	if not mobile_mode and not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func actor(point: Vector3, is_bot: bool = false, team: int = 0, skin: int = 0) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	if is_bot:
		add_bot_part(body, Vector3(0, 0.55, 0), Vector3(0.55, 0.95, 0.4))
		add_bot_part(body, Vector3(0, 1.26, 0), Vector3(0.42, 0.42, 0.42))
		body.set_meta("health", MAX_HEALTH)
		body.set_meta("crouched", false)
		var sprite := BOT_MODEL.new()
		body.add_child(sprite)
		sprite.setup(skin, team == 0)
		body.set_meta("paint_sprite", sprite)
	else:
		body.set_script(PLAYER_BODY)
		standing_capsule = CapsuleShape3D.new()
		standing_capsule.radius = 0.28
		standing_capsule.height = STANDING_HEIGHT
		crouching_capsule = standing_capsule.duplicate()
		crouching_capsule.height = CROUCH_HEIGHT
		player_collider = CollisionShape3D.new()
		player_collider.shape = standing_capsule
		player_collider.position.y = STANDING_HEIGHT / 2.0
		body.add_child(player_collider)
	add_child(body)
	body.position = point
	body.floor_snap_length = 0.35
	return body

func add_bot_part(body: CharacterBody3D, point: Vector3, dimensions: Vector3) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position = point
	body.add_child(collider)

func set_bot_crouch(bot: CharacterBody3D, enabled: bool) -> void:
	if bot.get_meta("crouched") == enabled:
		return
	bot.set_meta("crouched", enabled)
	const STANDING_CENTERS := [0.55, 1.26]
	const STANDING_SIZES := [0.95, 0.42]
	var ratio := CROUCH_HEIGHT / STANDING_HEIGHT if enabled else 1.0
	for part in range(2):
		var collider := bot.get_child(part) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		collider.position.y = STANDING_CENTERS[part] * ratio
		shape.size.y = STANDING_SIZES[part] * ratio
	var sprite: BOT_MODEL = bot.get_meta("paint_sprite")
	sprite.set_crouching(enabled)

func box(point: Vector3, dimensions: Vector3, color: Color, parent: Node3D = null,
		collision: bool = true, visible_mesh: bool = true) -> Node3D:
	var object: Node3D = StaticBody3D.new() if collision else Node3D.new()
	if collision:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		object.add_child(collider)
	if visible_mesh:
		var display := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		display.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		display.material_override = material
		object.add_child(display)
	var container := parent if parent != null else self
	container.add_child(object)
	object.position = point
	return object

func clear_paintballs() -> void:
	for ball in paintballs:
		ball.mesh.queue_free()
	paintballs.clear()

func random_spawn_positions(enemy_count: int, ally_count: int) -> Array[Vector3]:
	var nav_map := bot_ai.nav_region.get_navigation_map()
	var outline := urban_footprint() if map_id == URBAN_MAP else PackedVector2Array()
	var candidates: Array[Vector3] = []
	var clearance := BoxShape3D.new()
	clearance.size = Vector3(1.7, 1.65, 1.7)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = clearance
	var excluded: Array[RID] = [player.get_rid()]
	for bot in bots:
		excluded.append(bot.get_rid())
	query.exclude = excluded
	var space := get_world_3d().direct_space_state
	for x in range(-44, 45, 4):
		for z in range(-44, 45, 4):
			var sample := Vector3(x + randf_range(-1.3, 1.3), 0.0, z + randf_range(-1.3, 1.3))
			var floor_point := NavigationServer3D.map_get_closest_point(nav_map, sample)
			if floor_point.distance_to(sample) > 1.4 or absf(floor_point.y) > 0.65:
				continue
			if not outline.is_empty() and not Geometry2D.is_point_in_polygon(Vector2(floor_point.x, floor_point.z), outline):
				continue
			query.transform = Transform3D(Basis.IDENTITY, floor_point + Vector3.UP * 0.99)
			if space.intersect_shape(query, 1).is_empty():
				candidates.append(floor_point + Vector3.UP * 0.09)
	if candidates.size() < enemy_count + ally_count + 1:
		push_warning("Not enough clear spawn points to start the match.")
		return []
	candidates.shuffle()
	var positions: Array[Vector3] = [candidates.pop_back()]
	for index in range(enemy_count + ally_count):
		var best_index := 0
		var best_score := -INF
		for candidate_index in range(candidates.size()):
			var point := candidates[candidate_index]
			var nearest := INF
			for used in positions:
				nearest = minf(nearest, point.distance_to(used))
			var player_distance := point.distance_to(positions[0])
			var score := nearest + randf_range(0.0, 2.0)
			if index < enemy_count:
				score += minf(player_distance, 52.0) * 0.42
				if player_distance < 27.0:
					score -= 95.0
			else:
				for enemy_index in range(1, enemy_count + 1):
					if point.distance_to(positions[enemy_index]) < 25.0:
						score -= 32.0
			if score > best_score:
				best_score = score
				best_index = candidate_index
		positions.append(candidates.pop_at(best_index))
	return positions

func start_match() -> void:
	var enemy_count := 6 if six_vs_six else (3 if team_match else 5)
	var ally_count := enemy_count - 1 if team_match else 0
	var locations := random_spawn_positions(enemy_count, ally_count)
	if locations.is_empty():
		show_match_result("This arena needs more open space to spawn all players.")
		return
	clear_paintballs()
	for mark in arena_splats.get_children():
		mark.queue_free()
	for bot in bots:
		bot.queue_free()
	bots.clear()
	bot_ai.reset()
	spawn = locations[0]
	var skins := [0, 1, 2, 3, 4, 5, 6, 7]
	skins.shuffle()
	for index in range(locations.size() - 1):
		var team := 0 if index >= enemy_count else 1
		var bot := actor(locations[index + 1], true, team, skins[index % skins.size()])
		bots.append(bot)
		bot_ai.register(bot, team, index)
	player.position = spawn
	set_crouched(false)
	camera.position.y = STANDING_EYE
	var toward_center := -Vector2(spawn.x, spawn.z)
	player.rotation.y = atan2(-toward_center.x, -toward_center.y)
	player.velocity = Vector3.ZERO
	jump_held = Input.is_physical_key_pressed(KEY_SPACE)
	coyote_left = 0.0
	jump_buffer_left = 0.0
	camera.rotation.x = 0
	marker_view.reset_motion()
	health = MAX_HEALTH
	time_left = TIMED_SECONDS
	team_hits = [0, 0]
	if touch != null:
		touch.show()
	update_hit_counter()
	ammo = magazine_size()
	reload = 0
	cooldown = 0
	outcome = ""
	loss_popup.hide()
	fire_requested = false
	countdown_left = COUNTDOWN_DURATION
	go_left = 0.0
	update_countdown()
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if loss_popup.visible or mobile_mode and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and not menu_requested.get_connections().is_empty():
			menu_requested.emit()
			return
		if event.keycode == KEY_E and outcome == "" and countdown_left <= 0.0:
			var door := nearest_door()
			if door != null:
				door.toggle_door()
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			update_hud()
		if event.keycode == KEY_ENTER and outcome != "":
			start_match()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif outcome == "" and countdown_left <= 0.0:
			fire_requested = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * LOOK)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if outcome != "" or (not mobile_mode and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		return
	if touch != null and touch.consume("MENU"):
		return_from_loss()
		return
	if countdown_left > 0.0:
		countdown_left = maxf(0.0, countdown_left - delta)
		if countdown_left == 0.0:
			go_left = GO_DURATION
		update_countdown()
		update_hud()
		return
	if go_left > 0.0:
		go_left = maxf(0.0, go_left - delta)
		if go_left == 0.0:
			update_countdown()
	if timed_match:
		time_left = maxf(0.0, time_left - delta)
		if time_left == 0.0:
			var title := "Draw" if team_hits[0] == team_hits[1] else ("Time up — your team wins" if team_hits[0] > team_hits[1] else "Time up — opponents win")
			show_match_result("%s\nHits: %d – %d" % [title, team_hits[0], team_hits[1]])
			return
	advance_paintballs(delta)
	if outcome != "":
		update_hud()
		return
	var direction := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var was_jump_held := jump_held
	jump_held = Input.is_physical_key_pressed(KEY_SPACE)
	if touch != null:
		var move: Vector2 = touch.sticks["move"]
		var look: Vector2 = touch.sticks["look"]
		direction = Vector3(move.x, 0.0, move.y)
		player.rotate_y(-look.x * 2.5 * delta)
		camera.rotation.x = clampf(camera.rotation.x - look.y * 1.85 * delta, -1.45, 1.45)
		jump_held = touch.held("JUMP")
		if touch.consume("FIRE"):
			fire_requested = true
		if touch.consume("USE"):
			var door := nearest_door()
			if door != null:
				door.toggle_door()
	var jump_pressed := jump_held and not was_jump_held
	if touch != null:
		jump_pressed = touch.consume("JUMP") or jump_pressed
	update_crouch(delta)
	var movement := player.basis * direction.limit_length() * (CROUCH_SPEED if crouched else SPEED)
	if update_climbing(-direction.z, jump_pressed):
		movement = Vector3.ZERO
		coyote_left = 0.0
		jump_buffer_left = 0.0
	else:
		player.velocity.x = movement.x
		player.velocity.z = movement.z
		player.velocity.y -= 12.0 * delta
		if crouched:
			coyote_left = 0.0
			jump_buffer_left = 0.0
		else:
			coyote_left = COYOTE_SECONDS if player.is_on_floor() else maxf(0.0, coyote_left - delta)
			jump_buffer_left = JUMP_BUFFER_SECONDS if jump_pressed else maxf(0.0, jump_buffer_left - delta)
			if coyote_left > 0.0 and jump_buffer_left > 0.0:
				player.velocity.y = 3.3
				coyote_left = 0.0
				jump_buffer_left = 0.0
	player.move_and_slide()
	var aiming := (touch.held("AIM") if touch != null else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and reload <= 0.0
	var reload_progress := 1.0 - reload / float(RELOAD_TIMES[marker_id]) if reload > 0.0 else 0.0
	marker_view.animate(delta, aiming, reload_progress, movement.length() > 0.1 and player.is_on_floor())
	cooldown = maxf(cooldown - delta, 0)
	if fire_requested:
		fire_requested = false
		shoot()
	if reload > 0:
		reload = maxf(reload - delta, 0)
		if reload == 0:
			ammo = magazine_size()
	bot_ai.update(delta)
	update_hud()

# Ladder climbing: W near a ladder (facing it) starts a climb; W/S move up and down, Space lets go.
# Returns true while the player is on a ladder (normal walking and gravity are skipped).
func update_climbing(up_input: float, jump_pressed: bool) -> bool:
	if not player.near_ladder and not player.climbing:
		return false
	if not player.climbing:
		var facing: Vector3 = -player.global_transform.basis.z
		var inward: Vector3 = -player.ladder_transform.basis.z
		if up_input > 0.0 and not crouched and facing.dot(inward) > 0.3:
			player.climbing = true
		else:
			return false
	if jump_pressed:
		player.climbing = false
		player.velocity = Vector3(0, 2.0, 0) + player.global_transform.basis.z * 1.5
		return true
	player.velocity = Vector3(0, up_input * player.climb_speed, 0)
	var top_y: float = player.ladder_transform.origin.y
	if up_input > 0.0 and player.global_position.y >= top_y - 0.05:
		player.global_position = player.ladder_transform * player.exit_offset
		player.velocity = Vector3.ZERO
		player.climbing = false
	elif up_input < 0.0 and player.is_on_floor():
		player.climbing = false
	return true

func nearest_door() -> Node:
	var best: Node = null
	var best_distance := 3.2
	for node in get_tree().get_nodes_in_group("enterables"):
		if not is_ancestor_of(node):
			continue
		var distance: float = node.reach(player.global_position)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best

func update_crouch(delta: float) -> void:
	if (touch.held("CROUCH") if touch != null else Input.is_physical_key_pressed(KEY_C)):
		set_crouched(true)
	elif crouched and has_standing_room():
		set_crouched(false)
	var eye_height := CROUCH_EYE if crouched else STANDING_EYE
	camera.position.y = move_toward(camera.position.y, eye_height, 5.5 * delta)

func set_crouched(enabled: bool) -> void:
	if crouched == enabled:
		return
	crouched = enabled
	player_collider.shape = crouching_capsule if crouched else standing_capsule
	player_collider.position.y = (CROUCH_HEIGHT if crouched else STANDING_HEIGHT) / 2.0

func has_standing_room() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_capsule
	query.transform.origin = player.global_position + Vector3.UP * (STANDING_HEIGHT / 2.0 + 0.02)
	query.exclude = [player.get_rid()]
	query.collision_mask = player.collision_mask
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func trace(from: Vector3, to: Vector3, excluded: RID) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = [excluded]
	return get_world_3d().direct_space_state.intersect_ray(ray)

func shoot() -> void:
	if countdown_left > 0.0 or cooldown > 0 or reload > 0 or ammo == 0:
		return
	if not cheats.get("infinite_ammo", false):
		ammo -= 1
		if ammo == 0:
			reload = 0.01 if cheats.get("fast_reload", false) else RELOAD_TIMES[marker_id]
	cooldown = SHOT_INTERVALS[marker_id]
	shot_audio.play()
	marker_view.punch()
	crosshair.fired()
	var origin := camera.global_position
	var aim_end := origin - camera.global_basis.z * 70
	var hit := trace(origin, aim_end, player.get_rid())
	var target: Vector3 = hit.get("position", aim_end)
	var muzzle := marker_view.muzzle.global_position
	var muzzle_blocked := trace(origin, muzzle, player.get_rid())
	if not muzzle_blocked.is_empty() or origin.distance_to(target) < 0.8:
		muzzle = origin
	launch_paintball(muzzle, target, player.get_rid(), 0, marker_id, player_paint)

func launch_paintball(from: Vector3, to: Vector3, excluded: RID, team: int, marker: int, paint := Color.TRANSPARENT) -> void:
	var ball := Paintball.new()
	ball.excluded = excluded
	ball.team = team
	ball.source = from
	ball.can_split = marker == 2
	ball.color = paint if paint.a > 0.0 else (PLAYER_PAINT if team == 0 else BOT_PAINT)
	ball.velocity = from.direction_to(to) * float(PROJECTILE_SPEEDS[marker])
	bot_ai.heard(team, from, 20.0 if ball.can_split else 15.0)
	spawn_projectile(ball, from, 1.65 if ball.can_split else 1.0)

func spawn_projectile(ball: Paintball, from: Vector3, model_scale: float) -> void:
	ball.mesh = MeshInstance3D.new()
	ball.mesh.mesh = paintball_mesh
	ball.mesh.material_override = paint_material(ball.color)
	ball.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball.mesh.scale = Vector3.ONE * model_scale
	add_child(ball.mesh)
	ball.mesh.global_position = from
	paintballs.append(ball)

func split_launcher_round(ball: Paintball, point: Vector3, contact: Vector3, direction: Vector3) -> void:
	var burst := LauncherBurst.new()
	var guide := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var right := direction.cross(guide).normalized()
	var up := right.cross(direction).normalized()
	var rotation_offset := randf_range(0.0, TAU)
	for index in range(5):
		var aim := contact
		if index > 0:
			var angle := rotation_offset + (index - 1) * TAU / 4.0
			var radius := LAUNCHER_SPREAD_RADIUS * randf_range(0.83, 1.10)
			aim += (right * cos(angle) + up * sin(angle)) * radius
		var fragment := Paintball.new()
		fragment.excluded = ball.excluded
		fragment.team = ball.team
		fragment.source = ball.source
		fragment.color = ball.color
		fragment.burst = burst
		fragment.velocity = point.direction_to(aim) * ball.velocity.length()
		if fragment.velocity.is_zero_approx():
			fragment.velocity = ball.velocity
		fragment.distance_left = 2.65
		spawn_projectile(fragment, point, 0.82)

func advance_paintballs(delta: float) -> void:
	for index in range(paintballs.size() - 1, -1, -1):
		var ball := paintballs[index]
		var origin := ball.mesh.global_position
		var direction := ball.velocity.normalized()
		var travel := minf(ball.velocity.length() * delta, ball.distance_left)
		var lookahead := minf(travel + LAUNCHER_SPLIT_DISTANCE, ball.distance_left) if ball.can_split else travel
		var hit := trace(origin, origin + direction * lookahead, ball.excluded)
		if ball.can_split and not hit.is_empty():
			var contact: Vector3 = hit["position"]
			var split_after := maxf(0.0, origin.distance_to(contact) - LAUNCHER_SPLIT_DISTANCE)
			if split_after <= travel:
				ball.mesh.queue_free()
				paintballs.remove_at(index)
				split_launcher_round(ball, origin + direction * split_after, contact, direction)
				continue
		ball.distance_left -= travel
		if hit.is_empty() and ball.distance_left > 0.0:
			ball.mesh.global_position += direction * travel
			continue
		ball.mesh.queue_free()
		paintballs.remove_at(index)
		if not hit.is_empty():
			apply_paint_hit(ball, hit)
			if outcome != "":
				clear_paintballs()
				return

func apply_paint_hit(ball: Paintball, hit: Dictionary) -> void:
	var target: Node3D = hit["collider"]
	var position_hit: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	if target == player:
		if ball.team != 0 and (ball.burst == null or ball.burst.register(player)):
			hurt_player()
	elif target is CharacterBody3D:
		if bots.has(target) and int(target.get_meta("team")) != ball.team:
			target.get_meta("paint_sprite").paint(position_hit, normal, ball.color)
			if ball.burst == null or ball.burst.register(target):
				damage_bot(target, ball.source, ball.team)
	else:
		add_splat(position_hit, normal, ball.color, 0.15)
	if not timed_match and outcome.is_empty() and remaining_opponents() == 0:
		if mobile_mode:
			show_match_result("Arena cleared!")
		else:
			outcome = "Arena cleared! Press Enter to restart."

func hurt_player() -> void:
	if cheats.get("god_mode", false):
		return
	if timed_match:
		team_hits[1] += 1
		return
	health -= 1
	update_hit_counter()
	if health <= 0:
		show_loss_popup()

func remaining_opponents() -> int:
	var count := 0
	for bot in bots:
		if int(bot.get_meta("team")) == 1:
			count += 1
	return count

func damage_bot(bot: CharacterBody3D, from: Vector3, scoring_team: int) -> void:
	if timed_match:
		team_hits[scoring_team] += 1
		bot_ai.hit(bot, from)
		return
	var remaining := 0 if cheats.get("one_hit", false) else int(bot.get_meta("health")) - 1
	bot.set_meta("health", remaining)
	if remaining > 0:
		bot_ai.hit(bot, from)
		return
	bots.erase(bot)
	bot_ai.remove(bot)
	bot.queue_free()

func paint_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func add_splat(point: Vector3, normal: Vector3, color: Color, radius: float) -> void:
	if normal.is_zero_approx():
		return
	var mark := PAINT_SPLAT.make(color, radius)
	arena_splats.add_child(mark)
	PAINT_SPLAT.place(mark, point, normal)
	get_tree().create_timer(SPLAT_SECONDS).timeout.connect(mark.queue_free)

func update_countdown() -> void:
	crosshair.visible = countdown_left <= 0.0
	countdown_label.visible = countdown_left > 0.0 or go_left > 0.0
	countdown_label.text = str(ceili(countdown_left)) if countdown_left > 0.0 else "GO!"

func create_loss_popup(overlay: CanvasLayer) -> void:
	loss_popup = ColorRect.new()
	loss_popup.color = Color("#0a1015bb")
	loss_popup.hide()
	overlay.add_child(loss_popup)
	loss_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	loss_popup.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#24373d")
	style.border_color = Color("#65848b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	panel.add_child(layout)
	result_message = Label.new()
	result_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_message.add_theme_font_size_override("font_size", 30)
	layout.add_child(result_message)
	return_button = Button.new()
	return_button.text = "Return to Main Menu"
	return_button.custom_minimum_size.y = 40
	return_button.pressed.connect(return_from_loss)
	layout.add_child(return_button)

func show_loss_popup() -> void:
	show_match_result("Failed-No PTO Approved")

func show_match_result(label: String) -> void:
	outcome = label
	result_message.text = label
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if touch != null:
		touch.hide()
	loss_popup.show()
	return_button.grab_focus()

func return_from_loss() -> void:
	if menu_requested.get_connections().is_empty():
		get_tree().change_scene_to_file("res://menu.tscn")
	else:
		menu_requested.emit()

func create_hit_counter(overlay: CanvasLayer) -> void:
	var circle_size := 22
	var separation := 8
	var width := MAX_HEALTH * circle_size + (MAX_HEALTH - 1) * separation
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.visible = not timed_match
	row.add_theme_constant_override("separation", separation)
	overlay.add_child(row)
	row.anchor_left = 0.5
	row.anchor_right = 0.5
	row.offset_left = -width / 2.0
	row.offset_right = width / 2.0
	row.offset_top = 18
	row.offset_bottom = 18 + circle_size
	empty_hit_style = StyleBoxFlat.new()
	empty_hit_style.bg_color = Color("#263147")
	empty_hit_style.border_color = Color("#e8dbff")
	empty_hit_style.set_border_width_all(2)
	empty_hit_style.set_corner_radius_all(ceili(circle_size / 2.0))
	filled_hit_style = empty_hit_style.duplicate()
	filled_hit_style.bg_color = Color("#a34df5")
	for index in range(MAX_HEALTH):
		var circle := Panel.new()
		circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		circle.custom_minimum_size = Vector2(circle_size, circle_size)
		row.add_child(circle)
		hit_circles.append(circle)

func update_hit_counter() -> void:
	var hits := MAX_HEALTH - health
	for index in range(hit_circles.size()):
		var style := filled_hit_style if index < hits else empty_hit_style
		hit_circles[index].add_theme_stylebox_override("panel", style)

func update_hud() -> void:
	var message := "" if loss_popup.visible else outcome
	if not mobile_mode and outcome.is_empty() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		message = "Click the arena to start the countdown." if countdown_left > 0.0 else "Click the arena to capture the mouse."
	var status := "Reloading" if reload > 0 else "%d / %d paintballs" % [ammo, magazine_size()]
	if not cheats.is_empty():
		status += "   |   CHEATS ON"
	if outcome.is_empty() and player != null:
		var hint := ""
		if player.climbing:
			hint = "Climbing: W up, S down, Space let go"
		elif player.near_ladder:
			hint = "Face the ladder and hold W to climb"
		elif nearest_door() != null:
			hint = "E open / close door"
		if player.hiding:
			hint = ("HIDDEN   " + hint).strip_edges()
		if not hint.is_empty():
			message = hint if message.is_empty() else message + "   " + hint
	var summary := "Opponents: %d" % remaining_opponents()
	if timed_match:
		var seconds := ceili(time_left)
		summary = "%d:%02d   |   Hits: %d – %d" % [floori(seconds / 60.0), seconds % 60, team_hits[0], team_hits[1]]
	var controls := "WASD move   Hold C crouch   Space jump   E door   LMB tag   RMB aim   M menu"
	if mobile_mode:
		controls = "Left stick: move    Right stick: look"
		if player.climbing:
			message = "Move stick up/down to climb. Jump to let go."
		elif player.near_ladder:
			message = "Face the ladder and move forward."
		elif nearest_door() != null:
			message = "Tap USE to open or close the door."
	hud.text = "%s   |   %s\n%s\n%s" % [status, summary, controls, message]

func urban_footprint() -> PackedVector2Array:
	var outline := PackedVector2Array()
	for vertex in URBAN_BORDER.LOOP:
		outline.append((Vector2(vertex) - URBAN_BORDER.GRID_CENTER) * 6.0)
	return outline

func build_urban_arena() -> void:
	spawn = Vector3(0, 0.1, 31.8)
	var border := URBAN_BORDER.new()
	border.grid_scale = 6.0
	border.building_scenes = BUILDING_MODELS
	border.chain_link_scenes = CHAIN_LINK_MODELS
	border.wood_fence_scenes = WOOD_FENCE_MODELS
	border.rubble_scenes = RUBBLE_MODELS
	border.destroyed_car_scenes = CAR_WRECK_MODELS
	add_child(border)
	border.generate_border(self)
	border.draw_footprint()
	box(Vector3(0, 0.005, 2), Vector3(16, 0.01, 54), Color("#3f454a"), self, false)
	for x in [-8, 8]:
		box(Vector3(x, 0.028, 2), Vector3(1.5, 0.055, 54), Color("#a29d90"), self, false)
	for z in range(-23, 29, 5):
		box(Vector3(0, 0.012, z), Vector3(0.14, 0.015, 2.0), Color("#d2ad5c"), self, false)
	for x in [-16, 16]:
		for z in [-19, 9, 23]:
			box(Vector3(x, 0.62, z), Vector3(3.8, 1.24, 1.5), Color("#777b78"))
			box(Vector3(x, 1.18, z), Vector3(3.9, 0.13, 1.58), Color("#b08f56"), self, false)
	build_field_day()
	STREET_PROPS.new().build(self)

func build_field_day() -> void:
	var cover_points := [Vector3(-4, 0.6, 13), Vector3(5, 0.6, 8), Vector3(-6, 0.6, -12), Vector3(7, 0.6, -14)]
	var cover_size := Vector3(2, 1.2, 2)
	# Dimensions from the imported GLB, including its authored node scale.
	var container_size := Vector3(1.38, 1.289185, 3.046667) * 0.27
	for index in range(cover_points.size()):
		var cover := box(cover_points[index], cover_size, Color.WHITE, self, true, false)
		var display := Node3D.new()
		display.position.y = -cover_size.y * 0.5
		display.scale = cover_size / container_size
		cover.add_child(display)
		display.add_child(CONTAINER_COVER[index % CONTAINER_COVER.size()].instantiate())

	var building := Color("#695943")
	box(Vector3(0, 1.95, -4), Vector3(8, 0.1, 6), building)
	box(Vector3(0, 3.95, -4), Vector3(8, 0.1, 6), building)
	for x in [-3.9, 3.9]:
		box(Vector3(x, 1, -4), Vector3(0.2, 2, 6), building)
	box(Vector3(0, 1, -6.9), Vector3(8, 2, 0.2), building)
	box(Vector3(0, 2.4, -6.9), Vector3(8, 0.8, 0.2), building)
	box(Vector3(0, 2.4, -1.1), Vector3(8, 0.8, 0.2), building)
	box(Vector3(4.85, 1.94, -2.48), Vector3(2.4, 0.12, 2.5), building)
	# Raised exterior steps. Each tread rises 0.2 m.
	for step in range(10):
		var height := (step + 1) * 0.2
		box(Vector3(5, height / 2.0, 4 - step * 0.55),
			Vector3(1.8, height, 0.56), Color("#7b6b55"), self, false)
	# A continuous collision ramp lets CharacterBody3D climb the visible steps.
	var ramp := box(Vector3(5, 0.94, 1.525), Vector3(1.75, 0.12, 5.89),
		building, self, true, false)
	ramp.rotation.x = atan2(2.0, 5.5)


func create_shot_audio() -> void:
	shot_audio = AudioStreamPlayer.new()
	shot_audio.stream = SHOT_SOUNDS[marker_id]
	shot_audio.volume_db = -13.0
	shot_audio.max_polyphony = 3
	add_child(shot_audio)
