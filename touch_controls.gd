extends Control

const MOVE_RADIUS := 66.0
const BUTTON_RADIUS := 42.0
const DEAD_ZONE := 0.16
const LOOK_RESPONSE := 24.0
const LOOK_MAX_STEP := 28.0
const BUTTONS := ["FIRE_LEFT", "FIRE_RIGHT", "AIM", "CROUCH", "JUMP", "DOOR", "MENU"]

var fingers := {}
var move := Vector2.ZERO
var look_delta := Vector2.ZERO
var move_origin := Vector2.ZERO
var presses := {}
var door_available := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(clear_input)
	visibility_changed.connect(clear_input)

func clear_input() -> void:
	fingers.clear()
	presses.clear()
	move = Vector2.ZERO
	look_delta = Vector2.ZERO
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_input()

func control_scale() -> float:
	return clampf(minf(size.x / 680.0, size.y / 480.0), 0.40, 1.5)

func button_center(action: String) -> Vector2:
	var factor := control_scale()
	match action:
		"FIRE_LEFT": return Vector2(85 * factor, size.y - 245 * factor)
		"FIRE_RIGHT": return size - Vector2(68, 75) * factor
		"AIM": return size - Vector2(165, 75) * factor
		"CROUCH": return size - Vector2(68, 172) * factor
		"JUMP": return size - Vector2(165, 172) * factor
		"DOOR": return size - Vector2(68, 269) * factor
		_: return Vector2(size.x - 64 * factor, 59 * factor)

func move_center() -> Vector2:
	var factor := control_scale()
	return Vector2(98 * factor, size.y - 97 * factor)

func set_door_available(available: bool) -> void:
	if door_available != available:
		door_available = available
		queue_redraw()

func held(action: String) -> bool:
	return fingers.values().has(action)

func firing() -> bool:
	var tapped := presses.erase("FIRE")
	return tapped or held("FIRE_LEFT") or held("FIRE_RIGHT")

func consume(action: String) -> bool:
	return presses.erase(action)

func take_look_delta(delta: float) -> Vector2:
	var motion := (look_delta * (1.0 - exp(-LOOK_RESPONSE * delta))).limit_length(LOOK_MAX_STEP)
	look_delta -= motion
	if look_delta.length_squared() < 0.01:
		look_delta = Vector2.ZERO
	return motion

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var index: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			if fingers.has(index):
				return
			var action := ""
			for button in BUTTONS:
				if button == "DOOR" and not door_available:
					continue
				if event.position.distance_to(button_center(button)) <= (BUTTON_RADIUS + 4.0) * control_scale():
					action = button
					break
			if action.is_empty() and not held("move") and event.position.distance_to(move_center()) <= (MOVE_RADIUS + 22.0) * control_scale():
				action = "move"
				move_origin = event.position
			if action.is_empty() and event.position.x >= size.x * 0.5 and not held("look"):
				action = "look"
				look_delta = Vector2.ZERO
			if action.is_empty():
				return
			fingers[index] = action
			if action.begins_with("FIRE"):
				presses["FIRE"] = true
			elif action in ["JUMP", "DOOR", "MENU"]:
				presses[action] = true
		elif fingers.has(index):
			if fingers[index] == "move":
				move = Vector2.ZERO
			elif fingers[index] == "look" and event.canceled:
				look_delta = Vector2.ZERO
			fingers.erase(index)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if not fingers.has(index):
		return
	var claim: String = fingers[index]
	if claim == "move":
		var offset := (event.position - move_origin) / (MOVE_RADIUS * control_scale())
		var strength := clampf((offset.length() - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
		move = offset.normalized() * strength * strength
	elif claim == "look" and event is InputEventScreenDrag:
		var motion: Vector2 = event.relative / control_scale()
		look_delta = (look_delta + motion.limit_length(54.0)).limit_length(72.0)
	queue_redraw()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var factor := control_scale()
	var radius := MOVE_RADIUS * factor
	var center := move_center()
	draw_circle(center, radius, Color("#18252b9e"))
	draw_arc(center, radius, 0, TAU, 40, Color("#ffffff89"), 2.0, true)
	draw_circle(center + move * radius * 0.7, 22 * factor, Color("#97d8d8d0"))
	var font := ThemeDB.fallback_font
	for action in BUTTONS:
		if action == "DOOR" and not door_available:
			continue
		var point := button_center(action)
		var caption: String = "FIRE" if action.begins_with("FIRE") else action
		draw_circle(point, BUTTON_RADIUS * factor, Color("#3c8d92dd") if held(action) else Color("#18252bc0"))
		draw_arc(point, BUTTON_RADIUS * factor, 0, TAU, 24, Color("#ffffff89"), 1.5, true)
		var font_size := maxi(10, roundi(16 * factor))
		var metrics := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		draw_string(font, point + Vector2(-metrics.x * 0.5, 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
