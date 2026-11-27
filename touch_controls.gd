extends Control

const RADIUS := 49.0
const ACTION_NAMES := ["FIRE", "AIM", "CROUCH", "JUMP", "USE", "MENU"]

var fingers := {}
var sticks := {"move": Vector2.ZERO, "look": Vector2.ZERO}
var presses := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func button_center(index: int) -> Vector2:
	var locations := [Vector2(-153, -58), Vector2(-73, -187), Vector2(-149, -118),
		Vector2(-74, -250), Vector2(-157, -243), Vector2(-48, 50)]
	var offset: Vector2 = locations[index]
	return Vector2(size.x + offset.x, offset.y if ACTION_NAMES[index] == "MENU" else size.y + offset.y)

func stick_center(name: String) -> Vector2:
	return Vector2(84 if name == "move" else size.x - 67, size.y - 73)

func held(action: String) -> bool:
	return fingers.values().has(action)

func consume(action: String) -> bool:
	return presses.erase(action)

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var index: int = event.index
	if event is InputEventScreenTouch:
		if event.pressed:
			var action := ""
			for button in range(ACTION_NAMES.size()):
				if event.position.distance_to(button_center(button)) < 30.0:
					action = ACTION_NAMES[button]
					break
			if action.is_empty():
				for stick in ["move", "look"]:
					if event.position.distance_to(stick_center(stick)) <= RADIUS + 12.0 and not held(stick):
						action = stick
						break
			if action.is_empty():
				return
			fingers[index] = action
			presses[action] = true
		elif fingers.has(index):
			var released: String = fingers[index]
			fingers.erase(index)
			if sticks.has(released):
				sticks[released] = Vector2.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
			return
	if not fingers.has(index):
		return
	var claim: String = fingers[index]
	if sticks.has(claim):
		sticks[claim] = ((event.position - stick_center(claim)) / RADIUS).limit_length()
	queue_redraw()
	get_viewport().set_input_as_handled()

func _draw() -> void:
	var font := ThemeDB.fallback_font
	for stick in ["move", "look"]:
		var center := stick_center(stick)
		draw_circle(center, RADIUS, Color("#18252b9e"))
		draw_arc(center, RADIUS, 0, TAU, 40, Color("#ffffff89"), 2.0, true)
		draw_circle(center + sticks[stick] * RADIUS * 0.7, 19, Color("#97d8d8d0"))
	for index in range(ACTION_NAMES.size()):
		var point := button_center(index)
		var action: String = ACTION_NAMES[index]
		draw_circle(point, 28, Color("#3c8d92dd") if held(action) else Color("#18252bc0"))
		draw_arc(point, 28, 0, TAU, 24, Color("#ffffff89"), 1.5, true)
		var metrics := font.get_string_size(action, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		draw_string(font, point + Vector2(-metrics.x * 0.5, 4), action, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
