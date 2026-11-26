extends Node3D
# Door and hiding logic for enterable props (porta potty, container, culvert...).
# Hinges are the Door_L / Door_R nodes from the model (their origin is the hinge).
# `open_signs` gives each hinge's swing direction: Door_L swings -1, Door_R swings +1 (outward, +z).

@export var door_hinges: Array[Node3D] = []
@export var open_signs: Array[float] = []
@export var open_angle_deg: float = 95.0
@export var hide_area: Area3D
var is_open: bool = false

func _ready() -> void:
	add_to_group("enterables")
	if hide_area:
		hide_area.body_entered.connect(func(b): if b.has_method("set_hiding"): b.set_hiding(true))
		hide_area.body_exited.connect(func(b): if b.has_method("set_hiding"): b.set_hiding(false))

func toggle_door() -> void:
	is_open = not is_open
	for index in range(door_hinges.size()):
		var sign_value: float = open_signs[index] if index < open_signs.size() else 1.0
		var target := deg_to_rad(open_angle_deg if is_open else 0.0) * sign_value
		var tween := create_tween()
		tween.tween_property(door_hinges[index], "rotation:y", target, 0.25).set_trans(Tween.TRANS_SINE)

# Distance from a point to the nearest door (or to the prop itself when it has none).
func reach(point: Vector3) -> float:
	if door_hinges.is_empty():
		return INF
	var best := INF
	for hinge in door_hinges:
		best = minf(best, hinge.global_position.distance_to(point))
	return best
