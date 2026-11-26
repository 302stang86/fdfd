extends Node3D
# Menu preview: the same 3D model the bots use, turning slowly on the spot.

const CHARACTER_MODELS := preload("res://character_models.gd")
const TURN_RATE := 0.6

func build(skin: int) -> void:
	add_child(CHARACTER_MODELS.make(skin))

func set_crouching(enabled: bool) -> void:
	scale = CHARACTER_MODELS.crouch_scale(enabled)

func _process(delta: float) -> void:
	rotation.y += TURN_RATE * delta
