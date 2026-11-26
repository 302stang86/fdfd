extends Node3D
# 3D character for a bot. It keeps the interface of the old pixel sprite
# (setup / set_crouching / update_motion / paint) so arena.gd and bot_ai.gd barely change.

const CHARACTER_MODELS := preload("res://character_models.gd")
const ALLY_COLOR := Color("#61eee8")
const TURN_SPEED := 12.0
const STRIDE_RATE := 3.6
const MAX_STAINS := 14

var skin_id := 0
var model: Node3D
var parts: Dictionary = {}
var heading := 0.0
var walk_phase := 0.0
var walk_blend := 0.0
var crouching := false
var ally_badge: Label3D
var stains: Array[MeshInstance3D] = []
var stain_mesh: SphereMesh

func setup(skin: int, allied: bool) -> void:
	skin_id = skin
	model = CHARACTER_MODELS.make(skin)
	add_child(model)
	for part_name in CHARACTER_MODELS.PARTS:
		parts[part_name] = model.find_child(part_name, true, false)
	stain_mesh = SphereMesh.new()
	stain_mesh.radius = 0.065
	stain_mesh.height = 0.13
	stain_mesh.radial_segments = 8
	stain_mesh.rings = 4
	if allied:
		ally_badge = Label3D.new()
		ally_badge.text = "◆"
		ally_badge.font_size = 34
		ally_badge.pixel_size = 0.003
		ally_badge.modulate = ALLY_COLOR
		ally_badge.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		add_child(ally_badge)
	refresh()

func set_crouching(enabled: bool) -> void:
	if crouching == enabled:
		return
	crouching = enabled
	refresh()

func refresh() -> void:
	model.scale = CHARACTER_MODELS.crouch_scale(crouching)
	if ally_badge != null:
		var height: float = CHARACTER_MODELS.CROUCH_HEIGHT if crouching else CHARACTER_MODELS.STAND_HEIGHT
		ally_badge.position.y = height + 0.22

# facing: world direction the bot looks; speed: ground speed in m/s. delta == 0 snaps the heading.
func update_motion(facing: Vector3, speed: float, delta: float) -> void:
	if facing.is_zero_approx():
		return
	var target := atan2(facing.x, facing.z)
	heading = target if delta <= 0.0 else lerp_angle(heading, target, clampf(delta * TURN_SPEED, 0.0, 1.0))
	model.rotation.y = heading
	var moving := speed > 0.35
	walk_blend = move_toward(walk_blend, 1.0 if moving else 0.0, maxf(delta, 0.0) * 6.0)
	if moving:
		walk_phase = fposmod(walk_phase + delta * speed * STRIDE_RATE, TAU)
	var swing := sin(walk_phase) * walk_blend * (0.55 if crouching else 1.0)
	var leg_amplitude: float = CHARACTER_MODELS.LEG_SWING[skin_id]
	parts["LegA"].rotation.x = swing * leg_amplitude
	parts["LegB"].rotation.x = -swing * leg_amplitude
	parts["ArmA"].rotation.x = -swing * leg_amplitude * 0.8
	parts["ArmB"].rotation.x = swing * leg_amplitude * 0.8

# A paintball hit leaves a splat on the character. `point` is in world space.
func paint(point: Vector3, color: Color) -> void:
	var splat := MeshInstance3D.new()
	splat.mesh = stain_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	splat.material_override = material
	splat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	splat.scale = Vector3(1.0, 1.0, 0.45) * randf_range(0.9, 1.4)
	model.add_child(splat)
	var local := model.to_local(point)
	local.x = clampf(local.x, -0.24, 0.24)
	local.z = clampf(local.z, -0.16, 0.16)
	splat.position = local
	stains.append(splat)
	if stains.size() > MAX_STAINS:
		stains.pop_front().queue_free()
