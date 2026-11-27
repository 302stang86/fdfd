extends RefCounted
# The eight outfits, in the same order as OUTFITS in menu.gd and the skin index used by
# the arena. The models come from blender/make_characters.py: feet at y = 0, 1.5 m tall,
# facing +Z, split into Torso / ArmA / ArmB / LegA / LegB nodes whose origins are the joints.

const STAND_HEIGHT := 1.5
const CROUCH_HEIGHT := 1.0
const PARTS := ["Torso", "ArmA", "ArmB", "LegA", "LegB"]
const MODELS: Array[PackedScene] = [
	preload("res://assets/models/characters/char_army.glb"),
	preload("res://assets/models/characters/char_ninja.glb"),
	preload("res://assets/models/characters/char_clown.glb"),
	preload("res://assets/models/characters/char_firefighter.glb"),
	preload("res://assets/models/characters/char_police.glb"),
	preload("res://assets/models/characters/char_bunny.glb"),
	preload("res://assets/models/characters/char_robot.glb"),
	preload("res://assets/models/characters/char_goth.glb"),
]
# How far (radians) each outfit's legs swing while walking. Long coats swing less.
const LEG_SWING := [0.5, 0.5, 0.5, 0.5, 0.5, 0.45, 0.45, 0.3]

static func make(skin: int) -> Node3D:
	var model := MODELS[clampi(skin, 0, MODELS.size() - 1)].instantiate()
	if skin == 5:
		for child in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := child as MeshInstance3D
			if mesh.mesh == null:
				continue
			for index in range(mesh.mesh.get_surface_count()):
				var source := mesh.get_active_material(index) as BaseMaterial3D
				if source == null:
					continue
				var opaque := source.duplicate() as BaseMaterial3D
				opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				opaque.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh.set_surface_override_material(index, opaque)
		fill_bunny_neckline(model)
	return model

# The source silhouette has disconnected neck and bodice rings. Join them with
# a closed fabric insert attached to the torso so it follows the crouch pose.
static func fill_bunny_neckline(model: Node3D) -> void:
	var torso := model.find_child("Torso", true, false) as Node3D
	if torso == null:
		return
	var insert := MeshInstance3D.new()
	insert.name = "NecklineInsert"
	var fabric := StandardMaterial3D.new()
	fabric.albedo_color = Color("#252129")
	fabric.roughness = 0.88
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.060
	mesh.bottom_radius = 0.082
	mesh.height = 0.148
	mesh.radial_segments = 24
	mesh.rings = 0
	mesh.material = fabric
	insert.mesh = mesh
	insert.position = Vector3(0.005, 1.093, 0.003)
	insert.scale.z = 0.72
	torso.add_child(insert)

# Crouching squashes the standing model to the 1.0 m crouch height.
static func crouch_scale(enabled: bool) -> Vector3:
	if not enabled:
		return Vector3.ONE
	return Vector3(1.07, CROUCH_HEIGHT / STAND_HEIGHT, 1.07)
