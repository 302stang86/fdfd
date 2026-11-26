extends Node3D

const SPEED := 5.0
const LOOK := 0.0025
const COUNTDOWN_DURATION := 3.0
const GO_DURATION := 0.55
signal menu_requested

const MAGAZINES := [16, 6, 4]
const RELOAD_TIMES := [2.0, 0.85, 1.5]
const SHOT_INTERVALS := [0.11, 0.85, 1.15]
const AIM_FOVS := [62.0, 28.0, 70.0]

var marker_id := 0
var map_id := 0
var outfit_color := Color("#63774b")
var custom_layout: Dictionary = {}
var shot_audio: AudioStreamPlayer

func magazine_size() -> int:
	return MAGAZINES[marker_id]

var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var crosshair: Label
var countdown_label: Label
var countdown_left := COUNTDOWN_DURATION
var go_left := 0.0
var bots: Array[CharacterBody3D] = []
var bot_velocities: Array[Vector3] = []
var spawn := Vector3(0, 0.1, 19)
var ammo := 16
var health := 5
var reload := 0.0
var cooldown := 0.0
var bot_clock := 0.0
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

	box(Vector3(0, -0.25, 0), Vector3(48, 0.5, 48), Color("#485842"))
	for side in [-1, 1]:
		box(Vector3(side * 24, 1.5, 0), Vector3(0.5, 3, 48), Color("#323e43"))
		box(Vector3(0, 1.5, side * 24), Vector3(48, 3, 0.5), Color("#323e43"))
		if map_id != 0:
			continue
		for z in [-16, -6, 5, 14]:
			box(Vector3(side * 13, 0.65, z), Vector3(3, 1.3, 1), Color("#a17443"))
	if map_id == 0:
		build_field_day()
	elif map_id >= 2:
		for cell in custom_layout:
			var coordinates := String(cell).split(",")
			if coordinates.size() != 2 or not coordinates[0].is_valid_int() or not coordinates[1].is_valid_int():
				continue
			var x := coordinates[0].to_int()
			var z := coordinates[1].to_int()
			if absi(x) <= 20 and absi(z) <= 16:
				box(Vector3(x, 0.65, z), Vector3(1.7, 1.3, 1.7), Color("#a17443"))

	player = actor(spawn)
	player.floor_snap_length = 0.35
	camera = Camera3D.new()
	camera.position.y = 1.35
	camera.current = true
	player.add_child(camera)
	box(Vector3(0.32, -0.24, -0.54), Vector3(0.16, 0.15, 0.38), outfit_color, camera, false)
	box(Vector3(0.32, -0.15, -0.68), Vector3(0.09, 0.08, 0.41), Color("#27323b"), camera, false)
	create_shot_audio()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	hud = Label.new()
	hud.position = Vector2(20, 18)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color("#172021"))
	hud.add_theme_constant_override("outline_size", 6)
	overlay.add_child(hud)
	crosshair = Label.new()
	crosshair.text = "+"
	overlay.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= crosshair.size / 2.0
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown_label = Label.new()
	countdown_label.add_theme_font_size_override("font_size", 76)
	countdown_label.add_theme_constant_override("outline_size", 13)
	countdown_label.add_theme_color_override("font_outline_color", Color("#172021"))
	center.add_child(countdown_label)
	start_match()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func actor(point: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.5
	collider.shape = capsule
	collider.position.y = 0.75
	body.add_child(collider)
	add_child(body)
	body.position = point
	return body

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

func start_match() -> void:
	for bot in bots:
		bot.queue_free()
	bots.clear()
	bot_velocities.clear()
	var locations := [
		Vector3(-18, 0.1, -16), Vector3(18, 0.1, -15), Vector3(0, 0.1, -19),
		Vector3(-17, 0.1, 3), Vector3(17, 0.1, -4)
	]
	for point in locations:
		var bot := actor(point)
		box(Vector3(0, 0.55, 0), Vector3(0.55, 0.95, 0.4), Color("#cc6846"), bot, false)
		box(Vector3(0, 1.26, 0), Vector3(0.42, 0.42, 0.42), Color("#fed497"), bot, false)
		bots.append(bot)
		bot_velocities.append(Vector3.ZERO)
	player.position = spawn
	player.rotation.y = 0
	player.velocity = Vector3.ZERO
	camera.rotation.x = 0
	health = 5
	ammo = magazine_size()
	reload = 0
	cooldown = 0
	bot_clock = 0
	outcome = ""
	fire_requested = false
	countdown_left = COUNTDOWN_DURATION
	go_left = 0.0
	update_countdown()
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M and not menu_requested.get_connections().is_empty():
			menu_requested.emit()
			return
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			update_hud()
		if event.keycode == KEY_ENTER and outcome != "":
			start_match()
		if event.keycode == KEY_R and countdown_left <= 0.0 and reload <= 0 and ammo < magazine_size() and outcome == "":
			reload = RELOAD_TIMES[marker_id]
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif outcome == "" and countdown_left <= 0.0:
			fire_requested = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * LOOK)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or outcome != "":
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
	var direction := Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	)
	var movement := player.basis * direction.normalized() * SPEED
	player.velocity.x = movement.x
	player.velocity.z = movement.z
	player.velocity.y -= 12.0 * delta
	if player.is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = 3.3
	player.move_and_slide()
	var aim_fov: float = AIM_FOVS[marker_id] if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 78.0
	camera.fov = move_toward(camera.fov, aim_fov, 120.0 * delta)
	cooldown = maxf(cooldown - delta, 0)
	if fire_requested:
		fire_requested = false
		shoot()
		if outcome != "":
			return
	if reload > 0:
		reload = maxf(reload - delta, 0)
		if reload == 0:
			ammo = magazine_size()
	bot_clock += delta
	var bot_fire := bot_clock >= 1.5
	if bot_fire:
		bot_clock = 0
	for index in range(bots.size()):
		var bot := bots[index]
		var target := player.position - bot.position
		target.y = 0
		var travel := target.normalized()
		var steer := travel.rotated(Vector3.UP, 1.2 if index % 2 == 0 else -1.2)
		if bot.get_slide_collision_count() > 0:
			var obstruction := bot.get_slide_collision(0).get_normal()
			if absf(obstruction.y) < 0.5:
				bot_velocities[index] = steer
		bot_velocities[index] = bot_velocities[index].move_toward(Vector3.ZERO, delta)
		if bot_velocities[index].length_squared() > 0.02:
			travel = bot_velocities[index].normalized()
		var approaching := target.length() > 7.0
		bot.velocity.x = travel.x * 2.3 if approaching else 0.0
		bot.velocity.z = travel.z * 2.3 if approaching else 0.0
		bot.velocity.y -= 12.0 * delta
		bot.move_and_slide()
		if bot_fire and target.length() < 15.0 and randf() < 0.4:
			var hit := trace(bot.position + Vector3.UP * 1.25, camera.global_position, bot)
			if hit.get("collider") == player:
				health -= 1
				if health == 0:
					outcome = "Tagged out! Press Enter to restart."
					break
	update_hud()

func trace(from: Vector3, to: Vector3, excluded: CharacterBody3D) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = [excluded.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray)

func shoot() -> void:
	if countdown_left > 0.0 or cooldown > 0 or reload > 0 or ammo == 0:
		return
	ammo -= 1
	cooldown = SHOT_INTERVALS[marker_id]
	shot_audio.play()
	var origin := camera.global_position
	var hit := trace(origin, origin - camera.global_basis.z * 70, player)
	var tagged: Array[CharacterBody3D] = []
	var target = hit.get("collider")
	if target is CharacterBody3D and bots.has(target):
		tagged.append(target)
	if marker_id == 2 and not hit.is_empty():
		var impact: Vector3 = hit["position"]
		var splash_origin: Vector3 = impact + hit["normal"] * 0.08
		for bot in bots:
			if tagged.has(bot) or bot.position.distance_to(impact) > 4.0:
				continue
			var splash := trace(splash_origin, bot.position + Vector3.UP * 0.75, player)
			if splash.get("collider") == bot:
				tagged.append(bot)
	for bot in tagged:
		var index := bots.find(bot)
		bots.remove_at(index)
		bot_velocities.remove_at(index)
		bot.queue_free()
	if bots.is_empty():
		outcome = "Arena cleared! Press Enter to restart."
	update_hud()

func update_countdown() -> void:
	crosshair.visible = countdown_left <= 0.0
	countdown_label.visible = countdown_left > 0.0 or go_left > 0.0
	countdown_label.text = str(ceili(countdown_left)) if countdown_left > 0.0 else "GO!"

func update_hud() -> void:
	var message := outcome
	if outcome.is_empty() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		message = "Click the arena to start the countdown." if countdown_left > 0.0 else "Click the arena to capture the mouse."
	var status := "Reloading" if reload > 0 else "%d / %d paintballs" % [ammo, magazine_size()]
	hud.text = "%s   |   Hits remaining: %d   |   Bots: %d\nWASD move   Space jump   LMB tag   RMB aim   R reload   M menu\n%s" % [
		status, health, bots.size(), message
	]

func build_field_day() -> void:
	for point in [Vector3(-4, 0.6, 13), Vector3(5, 0.6, 8), Vector3(-6, 0.6, -12), Vector3(7, 0.6, -14)]:
		box(point, Vector3(2, 1.2, 2), Color("#647984"))

	var building := Color("#695943")
	box(Vector3(0, 1.95, -4), Vector3(8, 0.1, 6), building)
	box(Vector3(0, 3.95, -4), Vector3(8, 0.1, 6), building)
	for x in [-3.9, 3.9]:
		box(Vector3(x, 1, -4), Vector3(0.2, 2, 6), building)
	box(Vector3(0, 1, -6.9), Vector3(8, 2, 0.2), building)
	box(Vector3(0, 2.4, -6.9), Vector3(8, 0.8, 0.2), building)
	box(Vector3(0, 2.4, -1.1), Vector3(8, 0.8, 0.2), building)
	# Raised exterior steps. Each tread rises 0.2 m.
	for step in range(10):
		var height := (step + 1) * 0.2
		box(Vector3(5, height / 2.0, 4 - step * 0.55),
			Vector3(1.8, height, 0.56), Color("#7b6b55"), self, false)
	# A continuous collision ramp lets CharacterBody3D climb the visible steps.
	var ramp := box(Vector3(5, 0.90, 1.525), Vector3(1.75, 0.12, 5.89),
		building, self, true, false)
	ramp.rotation.x = atan2(2.0, 5.5)


func create_shot_audio() -> void:
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = 22050
	var samples := PackedByteArray()
	var length := 1100
	samples.resize(length * 2)
	for frame in range(length):
		var fade := 1.0 - float(frame) / float(length)
		var click := sin(float(frame) * (0.21 - marker_id * 0.04))
		var sample := (click * 0.6 + randf_range(-0.4, 0.4)) * fade * fade
		samples.encode_s16(frame * 2, int(sample * 14000))
	clip.data = samples
	shot_audio = AudioStreamPlayer.new()
	shot_audio.stream = clip
	add_child(shot_audio)
