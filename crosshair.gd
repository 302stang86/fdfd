extends Control

const STYLES := ["Classic Cross", "Simple Dot", "Dynamic Ring", "Bracketed Corners"]
const COLOR_NAMES := ["Red", "Yellow", "Blue"]
const COLORS := [Color("#ff3535"), Color("#ffdf00"), Color("#278cff")]
const RETICLE_COLOR_NAMES := ["Red", "Yellow", "Blue", "White"]
const RETICLE_COLORS := [Color("#ff3535"), Color("#ffdf00"), Color("#278cff"), Color("#f5f6f5")]
const MIN_SIZE := 8
const MAX_SIZE := 32
const DEFAULT_SIZE := 16

var style_index := 0
var ink := RETICLE_COLORS[3]
var diameter := DEFAULT_SIZE
var bloom := 0.0

func _ready() -> void:
	set_process(false)
	resized.connect(queue_redraw)

func fired() -> void:
	if style_index == 2:
		bloom = 0.26
		set_process(true)
		queue_redraw()

func _process(delta: float) -> void:
	bloom = move_toward(bloom, 0.0, 1.5 * delta)
	queue_redraw()
	if bloom == 0.0:
		set_process(false)

func _draw() -> void:
	var center := size * 0.5
	var radius := diameter * 0.5
	var stroke := clampf(diameter * 0.035, 1.0, 2.5)
	match style_index:
		0:
			var gap := maxf(1.4, radius * 0.13)
			for axis in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				draw_line(center + axis * gap, center + axis * radius, ink, stroke, true)
		1:
			draw_circle(center, maxf(1.5, radius * 0.24), ink, true, -1.0, true)
		2:
			var outer := radius * (1.0 + bloom)
			var inner := outer * 0.84
			draw_arc(center, outer, 0, TAU, 64, ink, 1.0, true)
			draw_arc(center, inner, 0, TAU, 64, ink, stroke, true)
			for index in range(8):
				var axis := Vector2.from_angle(TAU * index / 8.0)
				var tangent := axis.orthogonal() * maxf(0.75, outer * 0.05)
				var edge := center + axis * outer
				var tip := center + axis * (outer - maxf(1.3, outer * 0.10))
				draw_colored_polygon(PackedVector2Array([edge + tangent, edge - tangent, tip]), ink)
			draw_circle(center, maxf(1.0, radius * 0.085), ink, true, -1.0, true)
		3:
			var arm := radius * 0.55
			for x in [-1.0, 1.0]:
				for y in [-1.0, 1.0]:
					var corner := center + Vector2(x, y) * radius
					var points := PackedVector2Array([corner - Vector2(x * arm, 0), corner, corner - Vector2(0, y * arm)])
					draw_polyline(points, ink, stroke, true)
			draw_circle(center, maxf(1.0, radius * 0.085), ink, true, -1.0, true)
