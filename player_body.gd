extends CharacterBody3D
# The player's body: ladder and hiding state set by ladder.gd and enterable.gd.

var near_ladder := false
var climbing := false
var ladder_transform := Transform3D.IDENTITY
var climb_speed := 4.5
var exit_offset := Vector3(0.0, 0.6, -0.7)
var hiding := false

func set_climbing_ladder(enabled: bool, ladder_xform: Transform3D, speed: float, exit_point: Vector3) -> void:
	near_ladder = enabled
	if enabled:
		ladder_transform = ladder_xform
		climb_speed = speed
		exit_offset = exit_point
	else:
		climbing = false

func set_hiding(enabled: bool) -> void:
	hiding = enabled
