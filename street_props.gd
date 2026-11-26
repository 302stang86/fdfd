extends RefCounted
# Urban street dressing and cover (cars, barriers, walls, dumpsters, hedges, small props).
# Models come from blender/make_street_props.py. Collision is one box per prop, sized below as
# (width across, height, length along the model's long axis). Bodies are added straight to the
# arena so arena_scenery.gd treats them as keep-out areas for grass and dirt.

const MODEL_DIR := "res://assets/models/street/%s.glb"

# name: [collision size, collides]
const DIMS := {
	"crate": [Vector3(1.7, 1.3, 1.7), true, ""], # the original plain cover block (drawn by arena.gd)
	"car_wreck": [Vector3(1.7, 1.3, 3.3), true, "res://assets/models/car_wreck.glb"],
	"rubble_heap": [Vector3(2.2, 0.9, 2.2), true, "res://assets/models/rubble_pile.glb"],
	"wood_fence": [Vector3(0.3, 1.9, 6.0), true, "res://assets/models/wood_fence.glb"],
	"chain_link_fence": [Vector3(0.3, 3.5, 6.0), true, "res://assets/models/chain_link_fence.glb"],
	"brick_wall_low": [Vector3(0.4, 1.1, 4.0), true],
	"concrete_wall_tall": [Vector3(0.4, 3.0, 4.0), true],
	"jersey_barrier": [Vector3(0.6, 0.85, 2.5), true],
	"crowd_barricade": [Vector3(0.5, 1.1, 2.2), true],
	"bollard": [Vector3(0.32, 0.9, 0.32), true],
	"sedan": [Vector3(1.8, 1.45, 4.4), true],
	"pickup": [Vector3(2.0, 1.8, 5.4), true],
	"box_truck": [Vector3(2.4, 3.1, 6.5), true],
	"dumpster": [Vector3(1.4, 1.3, 2.0), true],
	"pallet_stack": [Vector3(0.85, 0.7, 1.2), true],
	"box_pile": [Vector3(1.2, 0.95, 1.2), true],
	"traffic_cone": [Vector3.ZERO, false],
	"barrel": [Vector3(0.6, 1.0, 0.6), true],
	"sawhorse": [Vector3(0.6, 1.0, 1.2), true],
	"hedge": [Vector3(0.8, 1.1, 2.0), true],
	"planter": [Vector3(0.7, 0.6, 1.5), false],
	"hydrant": [Vector3(0.3, 0.8, 0.3), true],
	"trash_can": [Vector3(0.5, 0.95, 0.5), true],
	"bench": [Vector3(0.6, 0.9, 1.8), false],
	"transformer_box": [Vector3(1.3, 1.2, 1.3), true],
}

# [model, x, z, yaw in degrees]
const LAYOUT := [
	["sedan", -5.5, 22.0, 0], ["pickup", 5.5, 17.0, 180], ["box_truck", -5.5, -20.0, 0], ["sedan", 6.0, -22.0, 10],
	["jersey_barrier", -3.5, 3.0, 90], ["jersey_barrier", 0.2, 3.0, 90],
	["crowd_barricade", -2.0, 25.0, 90], ["crowd_barricade", 2.0, 25.0, 90],
	["traffic_cone", -1.2, 21.0, 0], ["traffic_cone", 1.2, 21.0, 0], ["traffic_cone", 0.0, 19.0, 0],
	["barrel", 7.0, -3.0, 0], ["barrel", 7.8, -3.9, 0], ["sawhorse", 6.0, 11.0, 20], ["sawhorse", -7.0, -6.0, 70],
	["dumpster", -12.0, 0.0, 90], ["dumpster", 12.0, -4.0, 90],
	["pallet_stack", -13.0, -8.0, 10], ["pallet_stack", 13.0, 12.0, -20], ["pallet_stack", -12.0, 17.0, 0],
	["box_pile", -11.0, -7.0, 0], ["box_pile", 14.0, 14.0, 30],
	["brick_wall_low", -13.0, -14.0, 0], ["brick_wall_low", 13.0, -12.0, 0], ["brick_wall_low", -12.0, 5.0, 90],
	["concrete_wall_tall", -14.0, -3.0, 0], ["concrete_wall_tall", 14.0, 0.0, 0],
	["hedge", -10.0, -20.0, 90], ["hedge", 10.0, -24.0, 90], ["hedge", -11.0, 26.0, 90],
	["planter", -9.5, 12.0, 0], ["planter", 9.5, -12.0, 0],
	["hydrant", 8.9, -18.0, 0], ["hydrant", -8.9, 5.0, 0], ["hydrant", 8.9, 22.0, 0],
	["trash_can", 9.0, 3.0, 0], ["trash_can", -9.0, -3.0, 0], ["trash_can", 9.0, -6.0, 0],
	["bench", -9.3, -10.0, 0], ["bench", 9.3, 15.0, 180],
	["bollard", -6.0, 27.0, 0], ["bollard", -4.0, 27.0, 0], ["bollard", 4.0, 27.0, 0], ["bollard", 6.0, 27.0, 0],
	["transformer_box", -13.0, 21.0, 0], ["transformer_box", 11.5, 20.0, 0],
]

# Names shown in the map editor, in palette order, with a short label for the grid button.
const LABELS := {
	"crate": ["Crate (cover block)", "■"], "brick_wall_low": ["Low brick wall", "BW"], "concrete_wall_tall": ["Tall concrete wall", "CW"],
	"jersey_barrier": ["Jersey barrier", "JB"], "crowd_barricade": ["Crowd barricade", "CB"], "bollard": ["Bollard", "bo"],
	"sedan": ["Sedan", "SD"], "pickup": ["Pickup truck", "PU"], "box_truck": ["Box truck", "BT"], "car_wreck": ["Car wreck", "CR"],
	"dumpster": ["Dumpster", "DM"], "pallet_stack": ["Pallet stack", "PL"], "box_pile": ["Cardboard boxes", "BX"],
	"traffic_cone": ["Traffic cone", "tc"], "barrel": ["Barrel", "BA"], "sawhorse": ["Sawhorse", "SH"], "hedge": ["Hedge", "HG"],
	"planter": ["Planter", "PT"], "hydrant": ["Fire hydrant", "FH"], "trash_can": ["Trash can", "TC"], "bench": ["Bench", "BN"],
	"transformer_box": ["Transformer box", "TF"], "rubble_heap": ["Rubble heap", "RB"], "wood_fence": ["Wood fence", "WF"],
	"chain_link_fence": ["Chain-link fence", "CL"],
}

static func catalog() -> Array:
	return LABELS.keys()

var scenes := {}

func build(arena: Node3D) -> void:
	for entry in LAYOUT:
		place(arena, entry[0], Vector2(entry[1], entry[2]), deg_to_rad(entry[3]))

func scene_for(name: String) -> PackedScene:
	if not scenes.has(name):
		var info: Array = DIMS[name]
		var path: String = info[2] if info.size() > 2 and info[2] != "" else MODEL_DIR % name
		scenes[name] = load(path) as PackedScene
	return scenes[name]

func place(arena: Node3D, name: String, at: Vector2, yaw: float) -> void:
	var scene := scene_for(name) if name != "crate" else null
	if scene == null and name != "crate":
		return
	var info: Array = DIMS[name]
	var body := StaticBody3D.new()
	body.position = Vector3(at.x, 0.0, at.y)
	body.rotation.y = yaw
	if info[1]:
		var size: Vector3 = info[0]
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position.y = size.y * 0.5
		body.add_child(collider)
	if scene != null:
		body.add_child(scene.instantiate())
	else: # crate: the original plain block
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = info[0]
		block.mesh = mesh
		block.position.y = info[0].y * 0.5
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("#a17443")
		block.material_override = paint
		body.add_child(block)
	arena.add_child(body)

# One editor cell: value is `true` (older saves: a crate) or "id" / "id:degrees".
func place_cell(arena: Node3D, cell: Vector2, value) -> void:
	var id := "crate"
	var yaw := 0.0
	if value is String:
		var parts := (value as String).split(":")
		id = parts[0]
		if parts.size() > 1 and parts[1].is_valid_float():
			yaw = deg_to_rad(parts[1].to_float())
	if not DIMS.has(id):
		id = "crate"
	place(arena, id, cell, yaw)
