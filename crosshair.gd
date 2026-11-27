extends Control

const STYLES := ["Cross", "Dot", "Ring"]
const COLOR_NAMES := ["Red", "Yellow", "Blue"]
const COLORS := [Color("#ff3535"), Color("#ffdf00"), Color("#278cff")]
const MIN_SIZE := 8
const MAX_SIZE := 32
const DEFAULT_SIZE := 16

var style_index := 0
var ink := COLORS[1]
var diameter := DEFAULT_SIZE

func _draw() -> void:
	var center := size * 0.5
	var radius := diameter * 0.5
	var outline := Color(0.04, 0.05, 0.07, 0.92)
	match style_index:
		0:
			for axis in [Vector2.RIGHT, Vector2.DOWN]:
				draw_line(center - axis * (radius + 1.0), center + axis * (radius + 1.0), outline, 4.0, true)
			for axis in [Vector2.RIGHT, Vector2.DOWN]:
				draw_line(center - axis * radius, center + axis * radius, ink, 2.0, true)
		1:
			draw_circle(center, radius * 0.35 + 1.0, outline, true, -1.0, true)
			draw_circle(center, radius * 0.35, ink, true, -1.0, true)
		2:
			draw_arc(center, radius, 0, TAU, 48, outline, 4.0, true)
			draw_arc(center, radius, 0, TAU, 48, ink, 2.0, true)
