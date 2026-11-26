extends Node3D

const SPEED := 5.0
const LOOK := 0.0025
const COUNTDOWN_DURATION := 3.0
const GO_DURATION := 0.55
const MAX_HEALTH := 5
const SPLAT_SECONDS := 4.0
const PLAYER_PAINT := Color("#278cff")
const BOT_PAINT := Color("#fa4eaa")
const PROJECTILE_SPEEDS := [48.0, 66.0, 29.0]

class Paintball:
	var mesh: MeshInstance3D
	var velocity: Vector3
	var excluded: RID
	var color: Color
	var player_shot: bool
	var splash: bool
	var distance_left := 70.0

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
var loss_popup: ColorRect
var return_button: Button
var hit_circles: Array[Panel] = []
var empty_hit_style: StyleBoxFlat
var filled_hit_style: StyleBoxFlat
var crosshair: Label
var countdown_label: Label
var countdown_left := COUNTDOWN_DURATION
var go_left := 0.0
var bots: Array[CharacterBody3D] = []
var bot_velocities: Array[Vector3] = []
var paintballs: Array[Paintball] = []
var arena_splats: Node3D
var paintball_mesh: SphereMesh
var spawn := Vector3(0, 0.1, 19)
var ammo := 16
var health := MAX_HEALTH
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

	arena_splats = Node3D.new()
	add_child(arena_splats)
	paintball_mesh = SphereMesh.new()
	paintball_mesh.radius = 0.06
	paintball_mesh.height = 0.12
	paintball_mesh.radial_segments = 8
	paintball_mesh.rings = 4

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
	create_hit_counter(overlay)
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
	create_loss_popup(overlay)
	start_match()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func actor(point: Vector3, is_bot: bool = false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	if is_bot:
		add_bot_part(body, Vector3(0, 0.55, 0), Vector3(0.55, 0.95, 0.4), Color("#cc6846"))
		add_bot_part(body, Vector3(0, 1.26, 0), Vector3(0.42, 0.42, 0.42), Color("#fed497"))
		body.set_meta("health", MAX_HEALTH)
	else:
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

func add_bot_part(body: CharacterBody3D, point: Vector3, dimensions: Vector3, color: Color) -> void:
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collider.shape = shape
	collider.position = point
	body.add_child(collider)
	box(point, dimensions, color, body, false)

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

func start_match() -> void:
	clear_paintballs()
	for mark in arena_splats.get_children():
		mark.queue_free()
	for bot in bots:
		bot.queue_free()
	bots.clear()
	bot_velocities.clear()
	var locations := [
		Vector3(-18, 0.1, -16), Vector3(18, 0.1, -15), Vector3(0, 0.1, -19),
		Vector3(-17, 0.1, 3), Vector3(17, 0.1, -4)
	]
	for point in locations:
		var bot := actor(point, true)
		bots.append(bot)
		bot_velocities.append(Vector3.ZERO)
	player.position = spawn
	player.rotation.y = 0
	player.velocity = Vector3.ZERO
	camera.rotation.x = 0
	health = MAX_HEALTH
	update_hit_counter()
	ammo = magazine_size()
	reload = 0
	cooldown = 0
	bot_clock = 0
	outcome = ""
	loss_popup.hide()
	fire_requested = false
	countdown_left = COUNTDOWN_DURATION
	go_left = 0.0
	update_countdown()
	update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if loss_popup.visible:
		return
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
	advance_paintballs(delta)
	if outcome != "":
		update_hud()
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
	var aim_fov: float = AIM_FOVS[marker_id] if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) else 78.0
	camera.fov = move_toward(camera.fov, aim_fov, 120.0 * delta)
	cooldown = maxf(cooldown - delta, 0)
	if fire_requested:
		fire_requested = false
		shoot()
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
			var launch_point := bot.position + Vector3.UP * 1.22
			var aim_point := camera.global_position - Vector3.UP * 0.22
			var hit := trace(launch_point, aim_point, bot.get_rid())
			if hit.get("collider") == player:
				launch_paintball(launch_point, aim_point, bot.get_rid(), false)

	update_hud()

func trace(from: Vector3, to: Vector3, excluded: RID) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	ray.exclude = [excluded]
	return get_world_3d().direct_space_state.intersect_ray(ray)

func shoot() -> void:
	if countdown_left > 0.0 or cooldown > 0 or reload > 0 or ammo == 0:
		return
	ammo -= 1
	cooldown = SHOT_INTERVALS[marker_id]
	shot_audio.play()
	var origin := camera.global_position
	var aim_end := origin - camera.global_basis.z * 70
	var hit := trace(origin, aim_end, player.get_rid())
	var target: Vector3 = hit.get("position", aim_end)
	var muzzle := camera.to_global(Vector3(0.27, -0.14, -0.72))
	var muzzle_blocked := trace(origin, muzzle, player.get_rid())
	if not muzzle_blocked.is_empty() or origin.distance_to(target) < 0.8:
		muzzle = origin
	launch_paintball(muzzle, target, player.get_rid(), true)

func launch_paintball(from: Vector3, to: Vector3, excluded: RID, player_shot: bool) -> void:
	var ball := Paintball.new()
	ball.excluded = excluded
	ball.player_shot = player_shot
	ball.splash = player_shot and marker_id == 2
	ball.color = PLAYER_PAINT if player_shot else BOT_PAINT
	var speed: float = PROJECTILE_SPEEDS[marker_id] if player_shot else 35.0
	ball.velocity = from.direction_to(to) * speed
	ball.mesh = MeshInstance3D.new()
	ball.mesh.mesh = paintball_mesh
	ball.mesh.material_override = paint_material(ball.color)
	ball.mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ball.splash:
		ball.mesh.scale = Vector3.ONE * 1.65
	add_child(ball.mesh)
	ball.mesh.global_position = from
	paintballs.append(ball)

func advance_paintballs(delta: float) -> void:
	for index in range(paintballs.size() - 1, -1, -1):
		var ball := paintballs[index]
		var origin := ball.mesh.global_position
		var step := ball.velocity * delta
		ball.distance_left -= step.length()
		var hit := trace(origin, origin + step, ball.excluded)
		if hit.is_empty() and ball.distance_left > 0.0:
			ball.mesh.global_position += step
			continue
		ball.mesh.queue_free()
		paintballs.remove_at(index)
		if not hit.is_empty():
			apply_paint_hit(ball, hit)
			if outcome != "":
				clear_paintballs()
				return

func apply_paint_hit(ball: Paintball, hit: Dictionary) -> void:
	var target = hit["collider"]
	var position_hit: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var direct_bot := target is CharacterBody3D and bots.has(target)
	if target != player:
		var radius := 0.38 if ball.splash and not direct_bot else 0.15
		var surface: Node3D = target if direct_bot else arena_splats
		add_splat(position_hit, normal, ball.color, radius, surface, direct_bot)
	if direct_bot and ball.player_shot:
		damage_bot(target)
	elif target == player and not ball.player_shot:
		health -= 1
		update_hit_counter()
		if health <= 0:
			show_loss_popup()

	if ball.splash:
		var splash_start := position_hit + normal * 0.09
		for bot in bots.duplicate():
			if bot == target or bot.position.distance_to(position_hit) > 4.0:
				continue
			var splash_hit := trace(splash_start, bot.position + Vector3.UP * 0.65, ball.excluded)
			if splash_hit.get("collider") == bot:
				add_splat(splash_hit["position"], splash_hit["normal"], ball.color, 0.15, bot, true)
				damage_bot(bot)
	if bots.is_empty():
		outcome = "Arena cleared! Press Enter to restart."

func damage_bot(bot: CharacterBody3D) -> void:
	var remaining := int(bot.get_meta("health")) - 1
	bot.set_meta("health", remaining)
	if remaining > 0:
		return
	var index := bots.find(bot)
	bots.remove_at(index)
	bot_velocities.remove_at(index)
	bot.queue_free()

func paint_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func add_splat(point: Vector3, normal: Vector3, color: Color, radius: float, parent: Node3D, persistent: bool) -> void:
	if normal.is_zero_approx():
		return
	var geometry := ImmediateMesh.new()
	geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := PackedVector3Array()
	for index in range(18):
		var angle := TAU * index / 18.0
		var edge := radius * randf_range(0.55, 1.12)
		outline.append(Vector3(cos(angle) * edge, sin(angle) * edge, 0))
	for index in range(outline.size()):
		geometry.surface_add_vertex(Vector3.ZERO)
		geometry.surface_add_vertex(outline[index])
		geometry.surface_add_vertex(outline[(index + 1) % outline.size()])
	geometry.surface_end()
	var mark := MeshInstance3D.new()
	mark.mesh = geometry
	mark.material_override = paint_material(color)
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = point + normal * 0.012
	var up := Vector3.FORWARD if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	mark.look_at(mark.global_position + normal, up)
	if not persistent:
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
	var message := Label.new()
	message.text = "Failed-No PTO Approved"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 30)
	layout.add_child(message)
	return_button = Button.new()
	return_button.text = "Return to Main Menu"
	return_button.custom_minimum_size.y = 40
	return_button.pressed.connect(return_from_loss)
	layout.add_child(return_button)

func show_loss_popup() -> void:
	outcome = "failed"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	if outcome.is_empty() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		message = "Click the arena to start the countdown." if countdown_left > 0.0 else "Click the arena to capture the mouse."
	var status := "Reloading" if reload > 0 else "%d / %d paintballs" % [ammo, magazine_size()]
	hud.text = "%s   |   Bots: %d\nWASD move   Space jump   LMB tag   RMB aim   R reload   M menu\n%s" % [
		status, bots.size(), message
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
