extends RefCounted

const KNEE_BLEND := 0.075
const ANKLE_BLEND := 0.043

var skeleton: Skeleton3D
var attachments: Array[BoneAttachment3D] = []
var standing_hip := Vector3.ZERO
var standing_ankle := Vector3.ZERO
var segment_length := 0.0

func install(part: Node3D) -> bool:
	var view := part as MeshInstance3D
	if view == null:
		var meshes := part.find_children("*", "MeshInstance3D", true, false)
		if not meshes.is_empty():
			view = meshes[0] as MeshInstance3D
	if view == null or view.mesh == null:
		return false

	var source := view.mesh
	var bounds := source.get_aabb()
	var ankle_height := bounds.position.y + clampf(bounds.size.y * 0.14, 0.045, 0.105)
	standing_ankle = Vector3(0, ankle_height, 0)
	standing_hip.y = maxf(0.0, standing_ankle.y + 0.48)
	segment_length = (standing_hip.y - standing_ankle.y) * 0.5
	var knee := (standing_hip + standing_ankle) * 0.5

	skeleton = Skeleton3D.new()
	skeleton.name = "CrouchLegRig"
	view.add_child(skeleton)
	var skin := Skin.new()
	var joints := [standing_hip, knee, standing_ankle]
	for index in range(joints.size()):
		skeleton.add_bone(["Thigh", "Shin", "Foot"][index])
		var frame := Transform3D(Basis.IDENTITY, joints[index])
		skeleton.set_bone_rest(index, frame)
		skeleton.set_bone_pose_position(index, joints[index])
		skin.add_bind(index, frame.affine_inverse())
		var attachment := BoneAttachment3D.new()
		skeleton.add_child(attachment)
		attachment.bone_idx = index
		attachments.append(attachment)

	var rigged := ArrayMesh.new()
	for surface_index in range(source.get_surface_count()):
		var material := view.get_active_material(surface_index)
		var arrays := source.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		var weights := PackedFloat32Array()
		indices.resize(vertices.size() * 4)
		weights.resize(vertices.size() * 4)
		for index in range(vertices.size()):
			var y := vertices[index].y
			var thigh := smoothstep(knee.y - KNEE_BLEND, knee.y + KNEE_BLEND, y)
			var foot := 1.0 - smoothstep(standing_ankle.y, standing_ankle.y + ANKLE_BLEND, y)
			var offset := index * 4
			indices[offset] = 0
			indices[offset + 1] = 1
			indices[offset + 2] = 2
			weights[offset] = thigh
			weights[offset + 1] = (1.0 - thigh) * (1.0 - foot)
			weights[offset + 2] = (1.0 - thigh) * foot
		arrays[Mesh.ARRAY_BONES] = indices
		arrays[Mesh.ARRAY_WEIGHTS] = weights
		rigged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		rigged.surface_set_material(surface_index, material)
	rigged.custom_aabb = bounds.grow(0.65)
	view.mesh = rigged
	view.skin = skin
	view.skeleton = view.get_path_to(skeleton)
	pose(0.0, 0.0, 0.0)
	return true

func drop_for(crouch: float) -> float:
	return minf(0.39, segment_length * 1.11) * crouch

func pose(crouch: float, forward_step: float, step_lift: float) -> void:
	var ankle := standing_ankle + Vector3(0, step_lift, forward_step)
	var hip := standing_hip + Vector3(0, -drop_for(crouch) - step_lift * 0.16, -0.11 * crouch)
	var axis := hip - ankle
	var distance := axis.length()
	var reach := segment_length * 2.0
	if distance > reach:
		# Correct the pelvis, never pull the ankle off its contact point.
		hip.y = ankle.y + sqrt(maxf(0.0, reach * reach - axis.z * axis.z))
		axis = hip - ankle
		distance = axis.length()
	var side := Vector3(0, -axis.z, axis.y).normalized()
	var knee_offset := sqrt(maxf(0.0, segment_length * segment_length - distance * distance * 0.25))
	var knee := (hip + ankle) * 0.5 + side * knee_offset
	skeleton.set_bone_pose_position(0, hip)
	skeleton.set_bone_pose_rotation(0, Quaternion(Vector3.DOWN, hip.direction_to(knee)))
	skeleton.set_bone_pose_position(1, knee)
	skeleton.set_bone_pose_rotation(1, Quaternion(Vector3.DOWN, knee.direction_to(ankle)))
	skeleton.set_bone_pose_position(2, ankle)


func stain_parent(world_point: Vector3) -> Node3D:
	var local := skeleton.to_local(world_point)
	var nearest := INF
	var parent: Node3D = skeleton
	for index in range(attachments.size()):
		var from := skeleton.get_bone_global_pose(index).origin
		var to := skeleton.get_bone_global_pose(index + 1).origin if index < 2 else from
		var point := Geometry3D.get_closest_point_to_segment(local, from, to) if index < 2 else from
		var distance := local.distance_squared_to(point)
		if distance <= nearest:
			nearest = distance
			parent = attachments[index]
	return parent
