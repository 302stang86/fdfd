extends Node3D

const SPEED := 5.0
const LOOK := 0.0025
const MAGAZINE := 16

var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var bots: Array[CharacterBody3D] = []
var bot_velocities: Array[Vector3] = []
var spawn := Vector3(0, 0.1, 19)
var ammo := MAGAZINE
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
		for z in [-16, -6, 5, 14]:
			box(Vector3(side * 13, 0.65, z), Vector3(3, 1.3, 1), Color("#a17443"))
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

	player = actor(spawn)
	player.floor_snap_length = 0.35
	camera = Camera3D.new()
	camera.position.y = 1.35
	camera.current = true
	player.add_child(camera)
	var overlay := CanvasLayer.new()
	add_child(overlay)
	hud = Label.new()
	hud.position = Vector2(20, 18)
	hud.add_theme_font_size_override("font_size", 20)
	hud.add_theme_color_override("font_outline_color", Color("#172021"))
	hud.add_theme_constant_override("outline_size", 6)
	overlay.add_child(hud)
	var crosshair := Label.new()
	crosshair.text = "+"
	overlay.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position -= crosshair.size / 2.0
	start_match()
	if not DisplayServer.get_name() == "headless":
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
	ammo = MAGAZINE
	reload = 0
	cooldown = 0
	bot_clock = 0
	outcome = ""
	fire_requested = false
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_ENTER and outcome != "":
			start_match()
		if event.keycode == KEY_R and reload <= 0 and ammo < MAGAZINE and outcome == "":
			reload = 2.0
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif outcome == "":
			fire_requested = true
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * LOOK)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * LOOK, -1.45, 1.45)

func _physics_process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or outcome != "":
		return
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
	var aim_fov := 62.0 if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 78.0
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
			ammo = MAGAZINE
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
	if cooldown > 0 or reload > 0 or ammo == 0:
		return
	ammo -= 1
	cooldown = 0.11
	var origin := camera.global_position
	var hit := trace(origin, origin - camera.global_basis.z * 70, player)
	var target = hit.get("collider")
	var index := bots.find(target) if target is CharacterBody3D else -1
	if index >= 0:
		bots.remove_at(index)
		bot_velocities.remove_at(index)
		target.queue_free()
		if bots.is_empty():
			outcome = "Arena cleared! Press Enter to restart."
	update_hud()

func update_hud() -> void:
	var status := "Reloading" if reload > 0 else "%d / %d paintballs" % [ammo, MAGAZINE]
	hud.text = "%s   |   Hits remaining: %d   |   Bots: %d\nWASD move   Space jump   LMB tag   RMB aim   R reload\n%s" % [
		status, health, bots.size(), outcome
	]
