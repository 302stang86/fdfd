extends Area3D
# A ladder zone. Place the node at the TOP of the ladder (y = the standable top); its local +Z points
# away from the object and -Z points over the roof/deck. The zone box reaches from the ground up.

@export var climb_speed: float = 4.5
@export var top_exit_offset: Vector3 = Vector3(0.0, 0.6, -0.7)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("set_climbing_ladder"):
		body.set_climbing_ladder(true, global_transform, climb_speed, top_exit_offset)

func _on_body_exited(body: Node3D) -> void:
	if body.has_method("set_climbing_ladder"):
		body.set_climbing_ladder(false, Transform3D.IDENTITY, 0.0, Vector3.ZERO)
