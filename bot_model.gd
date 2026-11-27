extends Node3D
# 3D character for a bot. It keeps the interface of the old pixel sprite
# (setup / set_crouching / update_motion / paint) so arena.gd and bot_ai.gd barely change.

const CHARACTER_MODELS := preload("res://character_models.gd")
const PAINT_SPLAT := preload("res://paint_splat.gd")
const LEG_RIG := preload("res://leg_crouch_rig.gd")
const ALLY_COLOR := Color("#61eee8")
const TURN_SPEED := 12.0
const STRIDE_RATE := 3.6
const MAX_STAINS := 14

var skin_id := 0
var model: Node3D
var parts: Dictionary = {}
var leg_rigs: Dictionary = {}
var heading := 0.0
var walk_phase := 0.0
var walk_blend := 0.0
var crouching := false
var crouch_blend := 0.0
var rest_origins := {}
var ally_badge: Label3D
var stains: Array[MeshInstance3D] = []

func setup(skin: int, allied: bool) -> void:
	skin_id = skin
	model = CHARACTER_MODELS.make(skin)
	add_child(model)
	for part_name in CHARACTER_MODELS.PARTS:
		var part := model.find_child(part_name, true, false) as Node3D
		if part != null:
			parts[part_name] = part
			rest_origins[part_name] = part.position
	for key in ["LegA", "LegB"]:
		var part: Node3D = parts.get(key)
		if part != null:
			var rig := LEG_RIG.new()
			if rig.install(part):
				leg_rigs[key] = rig
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
	if ally_badge != null:
		var height: float = CHARACTER_MODELS.CROUCH_HEIGHT if crouching else CHARACTER_MODELS.STAND_HEIGHT
		ally_badge.position.y = height + 0.22

func _process(delta: float) -> void:
	crouch_blend = move_toward(crouch_blend, 1.0 if crouching else 0.0, delta * 6.5)
	var lean := smoothstep(0.0, 1.0, crouch_blend)
	var leg_amplitude: float = CHARACTER_MODELS.LEG_SWING[skin_id]
	var swing := sin(walk_phase) * walk_blend * leg_amplitude * lerpf(1.0, 0.36, lean)
	var drop := 0.27 * lean
	if not leg_rigs.is_empty():
		drop = 0.0
		for rig in leg_rigs.values():
			drop += rig.drop_for(lean)
		drop /= leg_rigs.size()
	var pelvis := Vector3(0, 0.68, 0)
	var shift := Vector3(0, -drop, -0.11 * lean)
	var tilt := 0.30 * lean
	var torso_basis := Basis(Vector3.RIGHT, tilt)
	for key in ["Torso", "ArmA", "ArmB"]:
		var origin: Vector3 = rest_origins.get(key, pelvis)
		var offset := pelvis + torso_basis * (origin - pelvis) + shift - origin
		var angle := tilt
		if key == "ArmA":
			angle -= 0.85 * lean + swing * 0.8
		elif key == "ArmB":
			angle -= 0.70 * lean - swing * 0.8
		pose_part(key, offset, angle)
	pose_leg("LegA", lean, swing)
	pose_leg("LegB", lean, -swing)
	if ally_badge != null:
		ally_badge.position.y = lerpf(CHARACTER_MODELS.STAND_HEIGHT, CHARACTER_MODELS.CROUCH_HEIGHT, lean) + 0.22

func pose_leg(key: String, crouch: float, swing: float) -> void:
	var rig: LEG_RIG = leg_rigs.get(key)
	if rig != null:
		rig.pose(crouch, swing * 0.46, maxf(0.0, swing) * 0.22)
	else:
		pose_part(key, Vector3(0, -0.20, -0.04) * crouch, swing)

func pose_part(key: String, offset: Vector3, angle: float) -> void:
	var part: Node3D = parts.get(key)
	if part != null:
		part.position = rest_origins[key] + offset
		part.rotation.x = angle

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

# A paintball hit leaves a splat on the character. `point` is in world space.
func paint(point: Vector3, normal: Vector3, color: Color) -> void:
	var splat := PAINT_SPLAT.make(color, randf_range(0.083, 0.115))
	var local := model.to_local(point)
	local.x = clampf(local.x, -0.24, 0.24)
	local.z = clampf(local.z, -0.16, 0.16)
	var parent: Node3D = parts.get("Torso", model)
	if local.y < (0.40 if crouching else 0.66):
		parent = parts.get("LegA" if local.x < 0.0 else "LegB", model)
	var world_position := model.to_global(local)
	if local.y < (0.40 if crouching else 0.66):
		var rig: LEG_RIG = leg_rigs.get("LegA" if local.x < 0.0 else "LegB")
		if rig != null:
			parent = rig.stain_parent(world_position)
	parent.add_child(splat)
	PAINT_SPLAT.place(splat, world_position, normal if not normal.is_zero_approx() else model.global_basis.z)
	stains.append(splat)
	if stains.size() > MAX_STAINS:
		stains.pop_front().queue_free()
