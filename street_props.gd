extends RefCounted
# Urban street dressing and cover (cars, barriers, walls, dumpsters, hedges, small props).
# Models come from blender/make_street_props.py. Collision is one box per prop, sized below as
# (width across, height, length along the model's long axis). Bodies are added straight to the
# arena so arena_scenery.gd treats them as keep-out areas for grass and dirt.

const EDITOR_PARTS := preload("res://editor_parts.gd")
const LADDER_SCRIPT := preload("res://ladder.gd")
const ENTERABLE_SCRIPT := preload("res://enterable.gd")
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
	# climbable and enterable pieces
	["container_20ft", -19.0, 14.0, 90], ["scaffold_tower", 17.0, 4.0, 0], ["gazebo", 18.0, -17.0, 0],
	["generator", 17.0, -8.0, 0], ["cable_spools", -18.0, -17.0, 0], ["flatbed", 20.0, 18.0, 90],
	["porta_potty", -16.0, 21.0, 0], ["porta_potty", 16.0, 8.0, 180], ["container_interior", -19.0, 0.0, 90],
	["utility_cabinet", 18.0, 12.0, 0], ["construction_tent", -17.0, -9.0, 0], ["culvert", 16.0, -2.0, 90],
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

static func label_of(id: String) -> Array:
	if EDITOR_PARTS.LABELS.has(id):
		return [EDITOR_PARTS.LABELS[id], "Placeable terrain or structure piece"]
	if LABELS.has(id):
		return LABELS[id]
	if CLIMB.has(id):
		return CLIMB[id]["label"]
	return ENTER[id]["label"]

static func catalog() -> Array:
	return LABELS.keys() + CLIMB.keys() + ENTER.keys()

# Climbable props (ladder up to a standable top). parts: [kind, centre, size]; "cyl" size is (radius, height, radius).
# ladder: face point (x, z) the ladder is on, outward normal (x, z), and the top height.
const CLIMB := {
	"box_truck_climb": {"label": ["Box truck (climbable)", "TK"], "path": "box_truck_climb", "top": 2.8, "at": Vector2(0, 2.85), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 1.75, 0.5), Vector3(2.4, 2.1, 4.7)], ["box", Vector3(0, 1.0, -2.3), Vector3(2.3, 2.0, 1.6)], ["box", Vector3(0, 0.35, 0), Vector3(2.3, 0.7, 6.5)]]},
	"container_20ft": {"label": ["Shipping container 20ft", "C2"], "top": 2.6, "at": Vector2(0, 3.03), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 1.3, 0), Vector3(2.44, 2.6, 6.06)]]},
	"container_40ft": {"label": ["Shipping container 40ft", "C4"], "top": 2.6, "at": Vector2(0, 6.095), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 1.3, 0), Vector3(2.44, 2.6, 12.19)]]},
	"dumpster_climb": {"label": ["Dumpster (climbable)", "DC"], "top": 1.45, "at": Vector2(0.7, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 0.725, 0), Vector3(1.4, 1.45, 2.0)]]},
	"pallet_stairs": {"label": ["Pallet stack stairs", "PS"], "top": 2.1, "at": Vector2(0, 1.8), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 0.35, -1.3), Vector3(1.2, 0.7, 1.0)], ["box", Vector3(0, 0.7, 0), Vector3(1.2, 1.4, 1.0)], ["box", Vector3(0, 1.05, 1.3), Vector3(1.2, 2.1, 1.0)]]},
	"scaffold_tower": {"label": ["Scaffolding tower", "SC"], "top": 3.0, "at": Vector2(0, 1.0), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 2.94, 0), Vector3(2.0, 0.12, 2.0)], ["box", Vector3(-0.95, 1.5, -0.95), Vector3(0.1, 3.0, 0.1)], ["box", Vector3(0.95, 1.5, -0.95), Vector3(0.1, 3.0, 0.1)],
			["box", Vector3(-0.95, 1.5, 0.95), Vector3(0.1, 3.0, 0.1)], ["box", Vector3(0.95, 1.5, 0.95), Vector3(0.1, 3.0, 0.1)]]},
	"jersey_stack": {"label": ["Jersey barrier stack", "JS"], "top": 1.7, "at": Vector2(0, 1.25), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 0.425, 0), Vector3(1.2, 0.85, 2.5)], ["box", Vector3(0, 1.275, 0), Vector3(0.8, 0.85, 2.5)]]},
	"retaining_wall": {"label": ["Retaining wall", "RW"], "top": 2.4, "at": Vector2(0.3, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 1.2, 0), Vector3(0.6, 2.4, 4.0)]]},
	"transformer_climb": {"label": ["Transformer cabinet (climbable)", "TX"], "top": 1.8, "at": Vector2(0, 0.7), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 0.9, 0), Vector3(1.4, 1.8, 1.4)]]},
	"ac_chiller": {"label": ["AC chiller unit", "AC"], "top": 1.6, "at": Vector2(0.6, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 0.8, 0), Vector3(1.2, 1.6, 2.2)]]},
	"gazebo": {"label": ["Gazebo / pergola", "GZ"], "top": 2.6, "at": Vector2(0.9, 1.7), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 2.5, 0), Vector3(3.4, 0.2, 3.4)], ["box", Vector3(-1.4, 1.25, -1.4), Vector3(0.2, 2.5, 0.2)], ["box", Vector3(1.4, 1.25, -1.4), Vector3(0.2, 2.5, 0.2)],
			["box", Vector3(-1.4, 1.25, 1.4), Vector3(0.2, 2.5, 0.2)], ["box", Vector3(1.4, 1.25, 1.4), Vector3(0.2, 2.5, 0.2)]]},
	"bus_stop": {"label": ["Bus stop shelter (roof)", "BS"], "top": 2.4, "at": Vector2(0, -0.78), "n": Vector2(0, -1),
		"parts": [["box", Vector3(0, 2.35, 0), Vector3(3.7, 0.1, 1.56)], ["box", Vector3(0, 1.15, -0.7), Vector3(3.4, 2.3, 0.08)], ["box", Vector3(-1.7, 1.15, 0.65), Vector3(0.1, 2.3, 0.1)], ["box", Vector3(1.7, 1.15, 0.65), Vector3(0.1, 2.3, 0.1)]]},
	"vending_climb": {"label": ["Vending machine (climbable)", "VM"], "top": 2.0, "at": Vector2(0.5, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 1.0, 0), Vector3(1.0, 2.0, 0.85)]]},
	"generator": {"label": ["Generator / light tower", "GN"], "top": 1.7, "at": Vector2(0.5, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 0.85, 0), Vector3(1.0, 1.7, 2.2)]]},
	"water_tank": {"label": ["Water tank", "WT"], "top": 2.5, "at": Vector2(0, 1.2), "n": Vector2(0, 1),
		"parts": [["cyl", Vector3(0, 1.25, 0), Vector3(1.2, 2.5, 1.2)]]},
	"cable_spools": {"label": ["Cable spools", "SP"], "top": 2.1, "at": Vector2(0, 2.6), "n": Vector2(0, 1),
		"parts": [["cyl", Vector3(0, 0.45, -1.7), Vector3(0.8, 0.9, 0.8)], ["cyl", Vector3(0, 0.75, 0), Vector3(0.85, 1.5, 0.85)], ["cyl", Vector3(0, 1.05, 1.7), Vector3(0.9, 2.1, 0.9)]]},
	"flatbed": {"label": ["Flatbed trailer", "FB"], "top": 1.4, "at": Vector2(0, 3.75), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 1.3, 0), Vector3(2.5, 0.2, 7.5)], ["box", Vector3(-1.0, 0.5, 2.85), Vector3(0.4, 1.0, 1.8)], ["box", Vector3(1.0, 0.5, 2.85), Vector3(0.4, 1.0, 1.8)]]},
	"billboard": {"label": ["Billboard platform", "BB"], "top": 3.0, "at": Vector2(0, 0.25), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5)], ["box", Vector3(0, 2.94, -0.3), Vector3(3.0, 0.12, 1.0)]]},
	"fire_escape": {"label": ["Fire escape landing", "FE"], "top": 3.2, "at": Vector2(0, 0.5), "n": Vector2(0, 1),
		"parts": [["box", Vector3(0, 2.0, -0.9), Vector3(3.2, 4.0, 0.4)], ["box", Vector3(0, 3.14, -0.1), Vector3(2.4, 0.12, 1.2)]]},
	"planter_tier": {"label": ["Tiered planter", "TP"], "top": 1.4, "at": Vector2(0.6, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 0.7, 0), Vector3(1.2, 1.4, 3.0)]]},
	"material_bin": {"label": ["Material bin", "MB"], "top": 1.8, "at": Vector2(0.75, 0), "n": Vector2(1, 0),
		"parts": [["box", Vector3(0, 0.9, 0), Vector3(1.5, 1.8, 2.0)]]},
}

# Enterable hiding props. hide: [centre, size] of the hide zone; doors: node names (Door_L swings -1, Door_R +1).
const ENTER := {
	"porta_potty": {"label": ["Porta potty", "PP"], "hide": [Vector3(0, 1.15, 0), Vector3(1.0, 2.0, 1.0)], "radius": 1.0},
	"cargo_trailer": {"label": ["Cargo trailer (enterable)", "CT"], "hide": [Vector3(0, 1.6, 0), Vector3(2.3, 2.6, 7.6)], "radius": 4.6},
	"container_interior": {"label": ["Container (enterable)", "CE"], "hide": [Vector3(0, 1.3, 0), Vector3(2.2, 2.4, 5.7)], "radius": 3.4},
	"dumpster_hideout": {"label": ["Dumpster (hideout)", "DH"], "hide": [Vector3(0, 0.7, 0), Vector3(1.2, 1.0, 1.8)], "radius": 1.5},
	"bus_shelter_enclosed": {"label": ["Bus shelter (enclosed)", "BE"], "hide": [Vector3(0, 1.1, 0), Vector3(3.2, 2.0, 1.2)], "radius": 2.1},
	"payphone_booth": {"label": ["Payphone booth", "PB"], "hide": [Vector3(0, 1.15, 0), Vector3(0.9, 2.0, 0.9)], "radius": 0.9},
	"utility_cabinet": {"label": ["Utility cabinet (walk-in)", "UC"], "hide": [Vector3(0, 1.3, 0), Vector3(2.9, 2.3, 2.5)], "radius": 2.2},
	"construction_tent": {"label": ["Construction tent", "CN"], "hide": [Vector3(0, 1.2, 0), Vector3(2.8, 2.2, 2.8)], "radius": 2.1},
	"van_camper": {"label": ["Van / camper", "VC"], "hide": [Vector3(0, 1.2, 0.3), Vector3(1.8, 1.8, 3.2)], "radius": 3.0},
	"culvert": {"label": ["Culvert pipe", "CV"], "hide": [Vector3(0, 1.1, 0), Vector3(1.4, 1.6, 3.8)], "radius": 2.4},
}

var scenes := {}

func build(arena: Node3D) -> void:
	for entry in LAYOUT:
		place(arena, entry[0], Vector2(entry[1], entry[2]), deg_to_rad(entry[3]))

func scene_for(name: String) -> PackedScene:
	if not scenes.has(name):
		if CLIMB.has(name):
			scenes[name] = load("res://assets/models/climb/%s.glb" % name) as PackedScene
			return scenes[name]
		if ENTER.has(name):
			scenes[name] = load("res://assets/models/enterable/%s.glb" % name) as PackedScene
			return scenes[name]
		var info: Array = DIMS[name]
		var path: String = info[2] if info.size() > 2 and info[2] != "" else MODEL_DIR % name
		scenes[name] = load(path) as PackedScene
	return scenes[name]

# Places one prop under `arena` and returns its root node. `height` lifts it off the ground (stacking)
# and `scl` scales it uniformly.
func place(arena: Node3D, name: String, at: Vector2, yaw: float, height: float = 0.0, scl: float = 1.0) -> Node3D:
	var node: Node3D
	if EDITOR_PARTS.LABELS.has(name):
		node = EDITOR_PARTS.build(name)
		node.position = Vector3(at.x, 0.0, at.y)
		node.rotation.y = yaw
		arena.add_child(node)
		if name.ends_with("_tile"):
			node.set_meta("keep_radius", 0.0)
	elif CLIMB.has(name):
		node = place_climbable(arena, name, at, yaw)
	elif ENTER.has(name):
		node = place_enterable(arena, name, at, yaw)
	else:
		node = place_basic(arena, name, at, yaw)
	if node == null:
		return null
	node.position.y = height
	node.scale = Vector3.ONE * scl
	if not node.has_meta("keep_radius"):
		var size: Vector3 = DIMS[name][0] if DIMS.has(name) else Vector3.ONE
		mark_keep_out(node, maxf(size.x, size.z) * 0.6)
	node.set_meta("keep_radius", float(node.get_meta("keep_radius")) * scl)
	return node

func place_basic(arena: Node3D, name: String, at: Vector2, yaw: float) -> Node3D:
	var scene := scene_for(name) if name != "crate" else null
	if scene == null and name != "crate":
		return null
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
	return body

# One editor cell: value is `true` (older saves: a crate) or "id" / "id:degrees".
func place_cell(arena: Node3D, cell: Vector2, value) -> void:
	var id := "crate"
	var yaw := 0.0
	if value is String:
		var parts := (value as String).split(":")
		id = parts[0]
		if parts.size() > 1 and parts[1].is_valid_float():
			yaw = deg_to_rad(parts[1].to_float())
	if not DIMS.has(id) and not CLIMB.has(id) and not ENTER.has(id) and not EDITOR_PARTS.LABELS.has(id):
		id = "crate"
	place(arena, id, cell, yaw)

func mark_keep_out(root: Node3D, radius: float) -> void:
	root.set_meta("keep_radius", radius)
	root.add_to_group("keep_out")

func place_climbable(arena: Node3D, name: String, at: Vector2, yaw: float) -> Node3D:
	var scene := scene_for(name)
	var data: Dictionary = CLIMB[name]
	if scene == null:
		return null
	var body := StaticBody3D.new()
	body.position = Vector3(at.x, 0.0, at.y)
	body.rotation.y = yaw
	var reach := 0.0
	for part in data["parts"]:
		var shape: Shape3D
		var size: Vector3 = part[2]
		if part[0] == "cyl":
			var cylinder := CylinderShape3D.new()
			cylinder.radius = size.x
			cylinder.height = size.y
			shape = cylinder
		else:
			var box := BoxShape3D.new()
			box.size = size
			shape = box
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = part[1]
		body.add_child(collider)
		reach = maxf(reach, Vector2(part[1].x, part[1].z).length() + maxf(size.x, size.z))
	body.add_child(scene.instantiate())
	# the ladder zone sits at the top of the ladder: local +Z points away from the prop
	var ladder := Area3D.new()
	ladder.set_script(LADDER_SCRIPT)
	var normal: Vector2 = data["n"]
	var top: float = data["top"]
	var face: Vector2 = data["at"]
	ladder.position = Vector3(face.x + normal.x * 0.35, top, face.y + normal.y * 0.35)
	ladder.rotation.y = atan2(normal.x, normal.y)
	var zone := CollisionShape3D.new()
	var zone_shape := BoxShape3D.new()
	zone_shape.size = Vector3(0.9, top + 0.3, 0.7)
	zone.shape = zone_shape
	zone.position = Vector3(0, -(top + 0.3) / 2.0 + 0.25, 0.2)
	ladder.add_child(zone)
	body.add_child(ladder)
	arena.add_child(body)
	mark_keep_out(body, reach * 0.55 + 0.6)
	return body

func place_enterable(arena: Node3D, name: String, at: Vector2, yaw: float) -> Node3D:
	var scene := scene_for(name)
	var data: Dictionary = ENTER[name]
	if scene == null:
		return null
	var root := Node3D.new()
	root.set_script(ENTERABLE_SCRIPT)
	root.position = Vector3(at.x, 0.0, at.y)
	root.rotation.y = yaw
	var model := scene.instantiate()
	root.add_child(model)
	var hinges: Array[Node3D] = []
	var signs: Array[float] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.name == "Shell":
			mesh_node.create_trimesh_collision() # hollow: never a convex hull
		elif String(mesh_node.name).begins_with("Door"):
			mesh_node.create_convex_collision(true, true)
			hinges.append(mesh_node)
			signs.append(-1.0 if String(mesh_node.name).ends_with("L") else 1.0)
	root.door_hinges = hinges
	root.open_signs = signs
	var zone := Area3D.new()
	var zone_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = data["hide"][1]
	zone_shape.shape = box
	zone.position = data["hide"][0]
	zone.add_child(zone_shape)
	root.add_child(zone)
	root.hide_area = zone
	arena.add_child(root)
	mark_keep_out(root, data["radius"])
	return root
