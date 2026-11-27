extends Control

const MOVE_RADIUS := 54.0
const BUTTON_RADIUS := 28.0
const BUTTONS := ["FIRE_LEFT", "FIRE_RIGHT", "AIM", "CROUCH", "JUMP", "DOOR", "MENU"]

var fingers := {}
var move := Vector2.ZERO
var look_delta := Vector2.ZERO
var presses := {}
var door_available := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	visibility_changed.connect(clear_input)

func clear_input() -> void:
	fingers.clear()
	presses.clear()
	move = Vector2.ZERO
	look_delta = Vector2.ZERO
	queue_redraw()

func button_center(action: String) -> Vector2:
	match action:
		"FIRE_LEFT": return Vector2(72, size.y - 180)
		"FIRE_RIGHT": return size - Vector2(62, 65)
		"AIM": return size - Vector2(128, 65)
		"CROUCH": return size - Vector2(62, 131)
		"JUMP": return size - Vector2(128, 131)
		"DOOR": return size - Vector2(62, 197)
		_: return Vector2(size.x - 54, 48)

func move_center() -> Vector2:
	return Vector2(81, size.y - 80)

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

func take_look_delta() -> Vector2:
	var motion := look_delta
	look_delta = Vector2.ZERO
	return motion

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var index: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			var action := ""
			for button in BUTTONS:
				if button == "DOOR" and not door_available:
					continue
				if event.position.distance_to(button_center(button)) <= BUTTON_RADIUS + 4.0:
					action = button
					break
			if action.is_empty() and not held("move") and event.position.distance_to(move_center()) <= MOVE_RADIUS + 14.0:
				action = "move"
			if action.is_empty() and event.position.x >= size.x * 0.5 and not held("look"):
				action = "look"
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
			fingers.erase(index)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if not fingers.has(index):
		return
	var claim: String = fingers[index]
	if claim == "move":
		move = ((event.position - move_center()) / MOVE_RADIUS).limit_length()
	elif claim == "look" and event is InputEventScreenDrag:
		look_delta += event.relative
	queue_redraw()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var center := move_center()
	draw_circle(center, MOVE_RADIUS, Color("#18252b9e"))
	draw_arc(center, MOVE_RADIUS, 0, TAU, 40, Color("#ffffff89"), 2.0, true)
	draw_circle(center + move * MOVE_RADIUS * 0.7, 19, Color("#97d8d8d0"))
	var font := ThemeDB.fallback_font
	for action in BUTTONS:
		if action == "DOOR" and not door_available:
			continue
		var point := button_center(action)
		var caption: String = "FIRE" if action.begins_with("FIRE") else action
		draw_circle(point, BUTTON_RADIUS, Color("#3c8d92dd") if held(action) else Color("#18252bc0"))
		draw_arc(point, BUTTON_RADIUS, 0, TAU, 24, Color("#ffffff89"), 1.5, true)
		var metrics := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
		draw_string(font, point + Vector2(-metrics.x * 0.5, 4), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
