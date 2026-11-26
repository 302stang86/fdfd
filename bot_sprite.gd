extends Sprite3D

const COLORS := [
	["#556947", "#272f24", "#b7a276", "#d3a27b", "#2d261e"],
	["#34303f", "#201e28", "#a23543", "#c99678", "#211e27"],
	["#e9ad48", "#755390", "#e74655", "#fff0dc", "#c76030"],
	["#2b3749", "#1c2837", "#e8d64d", "#cf956c", "#dfaf43"],
	["#334e69", "#202d3d", "#aed3ed", "#d1a07b", "#293747"],
	["#302b34", "#1e1c22", "#f2d6dd", "#efbc9c", "#24202b"],
	["#718998", "#354958", "#60eff4", "#a6bbc8", "#3d525c"],
	["#30263a", "#201d27", "#a450a0", "#ead2d8", "#532648"],
]
const PIXELS_PER_METER := 64.0
const ALLY_COLOR := Color("#61eee8")
enum Direction { FRONT, BACK, LEFT, RIGHT }

var frames: Dictionary = {}
var textures: Dictionary = {}
var texture_versions: Dictionary = {}
var skin_id := 0
var direction := Direction.FRONT
var stride := 0
var walk_phase := 0.0
var stains: Array[Vector2] = []
var stain_colors: Array[Color] = []
var ally_badge: Label3D
var crouching := false

func setup(skin: int, allied: bool) -> void:
	billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pixel_size = 1.0 / PIXELS_PER_METER
	centered = true
	shaded = false
	skin_id = skin
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

func update_motion(facing: Vector3, speed: float, delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or facing.is_zero_approx():
		return
	var toward_viewer := camera.global_position - global_position
	toward_viewer.y = 0.0
	if toward_viewer.is_zero_approx():
		return
	toward_viewer = toward_viewer.normalized()
	var front := facing.dot(toward_viewer)
	var next_direction := Direction.FRONT
	if front < -0.70:
		next_direction = Direction.BACK
	elif front <= 0.70:
		next_direction = Direction.RIGHT if facing.cross(Vector3.UP).dot(toward_viewer) > 0.0 else Direction.LEFT
	var next_stride := 0
	if speed > 0.35:
		walk_phase = fposmod(walk_phase + speed * delta * 2.0, 1.0)
		next_stride = -1 if walk_phase < 0.5 else 1
	else:
		walk_phase = 0.0
	if direction == next_direction and stride == next_stride:
		return
	direction = next_direction
	stride = next_stride
	refresh()

func paint(point: Vector3, color: Color) -> void:
	var camera := get_viewport().get_camera_3d()
	var right := camera.global_basis.x if camera != null else Vector3.RIGHT
	var relative := point - get_parent_node_3d().global_position
	var height := 1.0 if crouching else 1.5
	var x := clampf(0.5 + relative.dot(right), 0.24, 0.76)
	var y := 1.0 - clampf(relative.y / height, 0.08, 0.90)
	stains.append(Vector2(x, y))
	stain_colors.append(color)
	refresh()

func refresh() -> void:
	var key := int(crouching) * 12 + int(direction) * 3 + stride + 1
	if not frames.has(key):
		var original := draw_character(skin_id, crouching, direction, stride)
		frames[key] = original
		textures[key] = ImageTexture.create_from_image(original)
	var frame: Image = frames[key]
	var height := frame.get_height()
	if texture_versions.get(key, 0) != stains.size():
		var painted: Image = frame.duplicate()
		for index in range(stains.size()):
			var point := Vector2i(Vector2(64, height) * stains[index])
			for dy in range(-5, 6):
				for dx in range(-7, 8):
					var x := point.x + dx
					var y := point.y + dy
					if x >= 0 and x < 64 and y >= 0 and y < height and (dx * dx * 2 + dy * dy * 3 < 70 or (dx + dy) % 5 == 0):
						if frame.get_pixel(x, y).a > 0.0:
							painted.set_pixel(x, y, stain_colors[index])
		var current_texture: ImageTexture = textures[key]
		current_texture.update(painted)
		texture_versions[key] = stains.size()
	texture = textures[key]
	position.y = height / PIXELS_PER_METER / 2.0
	if ally_badge != null:
		ally_badge.position.y = position.y + 0.12

static func rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	img.fill_rect(Rect2i(x * 2, y * 2, w * 2, h * 2), color)

static func draw_character(skin: int, low: bool, view: int = Direction.FRONT, step: int = 0) -> Image:
	if view == Direction.LEFT or view == Direction.RIGHT:
		var profile := draw_profile(skin, low, step)
		if view == Direction.LEFT:
			profile.flip_x()
		return profile
	var height := 64 if low else 96
	var image := Image.create_empty(64, height, false, Image.FORMAT_RGBA8)
	var body := Color(COLORS[skin][0])
	var dark := Color(COLORS[skin][1])
	var trim := Color(COLORS[skin][2])
	var face := Color(COLORS[skin][3])
	var hair := Color(COLORS[skin][4])
	var outline := Color("#1b1722")
	var body_lit := body.lightened(0.16)
	var feet := height >> 1
	var torso := 12 if low else 18
	var waist := 23 if low else 33
	var head := 4 if low else 7

	# Legs and boots. The crouched silhouette widens at the knees.
	var spread := 3 if low else 0
	for side in [0, 1]:
		var lx := (5 - spread if side == 0 else 18 + spread)
		var leg_step := step if side == 0 else -step
		var sole := feet - maxi(0, leg_step * 2)
		rect(image, lx, waist - 2, 9, sole - waist + 1, outline)
		rect(image, lx + 1, waist - 2, 7, sole - waist, dark)
		rect(image, lx + 2, waist, 3, sole - waist - 4, body_lit)
		rect(image, lx - 1 + leg_step, sole - 4, 10, 4, outline)
		rect(image, lx + leg_step, sole - 4, 8, 2, dark)

	# Torso, sleeves, seams and hands.
	rect(image, 5, torso + 2, 22, waist - torso, outline)
	rect(image, 8, torso, 16, waist - torso + 1, outline)
	rect(image, 9, torso + 1, 14, waist - torso - 1, body)
	rect(image, 10, torso + 2, 4, waist - torso - 3, body_lit)
	rect(image, 15, torso + 2, 1, waist - torso - 3, dark)
	for side in [0, 1]:
		var sx := 4 if side == 0 else 23
		rect(image, sx, torso + 3, 5, waist - torso - 2, outline)
		rect(image, sx + 1, torso + 4, 3, waist - torso - 4, body_lit)
		rect(image, sx + 1, waist - 2, 3, 3, face)
	rect(image, 8, waist - 3, 16, 2, dark)
	rect(image, 14, waist - 3, 3, 2, trim.darkened(0.18))

	# Face and hair.
	rect(image, 10, head, 12, torso - head + 2, outline)
	rect(image, 11, head + 1, 10, torso - head, face)
	rect(image, 11, head + 1, 10, 3, hair)
	rect(image, 11, head + 4, 2, torso - head - 3, face.darkened(0.23))
	rect(image, 13, head + 5, 2, 1, outline)
	rect(image, 18, head + 5, 2, 1, outline)

	match skin:
		0:
			for cell in [Vector2i(9, 2), Vector2i(18, 3), Vector2i(12, 7), Vector2i(19, 9), Vector2i(10, 11)]:
				if cell.y < waist - torso - 2:
					rect(image, cell.x, torso + cell.y, 3, 2, trim if cell.x % 2 == 0 else dark)
			rect(image, 9, head + 1, 13, 2, dark)
			rect(image, 11, head - 1, 9, 3, body_lit)
		1:
			rect(image, 11, head + 1, 10, torso - head, body)
			rect(image, 12, head + 4, 8, 2, face)
			rect(image, 13, head + 4, 1, 1, outline)
			rect(image, 18, head + 4, 1, 1, outline)
			for line in range(waist - torso - 3):
				rect(image, 20 - (line >> 1), torso + line + 1, 2, 1, trim)
		2:
			rect(image, 8, head + 1, 4, 7, hair)
			rect(image, 20, head + 1, 4, 7, hair.lightened(0.15))
			rect(image, 14, head - 2, 5, 4, trim)
			rect(image, 13, head + 1, 7, 1, dark)
			rect(image, 15, head + 6, 2, 2, trim)
			rect(image, 9, torso, 14, 3, Color("#f7d651"))
			for index in range(3):
				rect(image, 13 + (index % 2) * 5, torso + 4 + index * 2, 2, 2, trim if index % 2 == 0 else Color("#44c1bc"))
		3:
			rect(image, 9, head + 1, 14, 3, trim)
			rect(image, 12, head - 2, 8, 4, hair)
			rect(image, 15, head - 1, 3, 3, dark)
			for band in [torso + 4, waist - 5]:
				rect(image, 6, band, 20, 2, trim)
				rect(image, 6, band + 1, 20, 1, trim.darkened(0.2))
		4:
			rect(image, 11, head - 1, 10, 4, body)
			rect(image, 10, head + 2, 12, 1, outline)
			rect(image, 18, torso + 4, 2, 3, Color("#f2ca6a"))
		5:
			rect(image, 9, head, 4, torso - head, hair)
			rect(image, 20, head, 3, torso - head, hair)
			rect(image, 11, 0, 4, head + 2, outline)
			rect(image, 18, 0, 4, head + 2, outline)
			rect(image, 12, 1, 2, head, Color("#ff758f"))
			rect(image, 19, 1, 2, head, Color("#ff758f"))
			rect(image, 13, torso + 1, 6, 4, trim)
			rect(image, 15, torso + 2, 2, 2, dark)
		6:
			rect(image, 11, head + 1, 10, torso - head, face)
			rect(image, 11, head + 4, 10, 4, dark)
			rect(image, 12, head + 4, 8, 2, trim)
			rect(image, 13, torso + 5, 6, 4, dark)
			rect(image, 15, torso + 6, 2, 2, trim)
		7:
			rect(image, 9, head, 4, torso - head + 2, hair)
			rect(image, 20, head, 3, torso - head + 2, hair)
			rect(image, 11, head - 2, 10, 4, dark)
			rect(image, 11, head + 2, 10, 1, trim)
			rect(image, 12, head + 3, 5, 2, hair)
			rect(image, 13, torso + 1, 6, 1, trim)
			rect(image, 8, waist - 1, 16, 3, dark)
	if view == Direction.BACK:
		draw_back(image, skin, head, torso, waist, body, dark, trim, hair, outline)
	return image

static func draw_back(image: Image, skin: int, head: int, torso: int, waist: int,
		body: Color, dark: Color, trim: Color, hair: Color, outline: Color) -> void:
	var rear := hair
	if skin == 1 or skin == 3 or skin == 4 or skin == 6:
		rear = body
	if skin == 3:
		rear = trim.darkened(0.27)
	rect(image, 10, head + 2, 12, torso - head, outline)
	rect(image, 11, head + 2, 10, torso - head - 1, rear)
	rect(image, 12, head + 3, 3, torso - head - 3, rear.lightened(0.15))
	rect(image, 9, torso + 2, 14, waist - torso - 4, body)
	if skin == 0 or skin == 6:
		rect(image, 12, torso + 3, 8, waist - torso - 6, outline)
		rect(image, 13, torso + 4, 6, waist - torso - 8, dark.lightened(0.15))
	elif skin == 3:
		rect(image, 6, torso + 4, 20, 2, trim)
		rect(image, 6, waist - 5, 20, 2, trim)
	elif skin == 5:
		rect(image, 14, waist - 5, 4, 4, Color("#e8dce5"))
		rect(image, 15, waist - 6, 2, 1, Color("#ffffff"))
	else:
		rect(image, 12, torso + 4, 8, 1, trim.darkened(0.22))

static func draw_profile(skin: int, low: bool, step: int) -> Image:
	var height := 64 if low else 96
	var image := Image.create_empty(64, height, false, Image.FORMAT_RGBA8)
	var body := Color(COLORS[skin][0])
	var dark := Color(COLORS[skin][1])
	var trim := Color(COLORS[skin][2])
	var face := Color(COLORS[skin][3])
	var hair := Color(COLORS[skin][4])
	var outline := Color("#1b1722")
	var feet := height >> 1
	var torso := 12 if low else 18
	var waist := 23 if low else 33
	var head := 4 if low else 7
	var lean := 2 if low else 0
	var front_boot := 16 + step * 2 + lean
	var back_boot := 12 - step * 2
	rect(image, back_boot, waist - 2, 7, feet - waist + 2, outline)
	rect(image, back_boot + 1, waist, 5, feet - waist - 3, dark)
	rect(image, back_boot, feet - 3, 8, 3, outline)
	var sole := feet - maxi(0, step * 2)
	rect(image, front_boot, waist - 2, 7, sole - waist + 2, outline)
	rect(image, front_boot + 1, waist, 5, sole - waist - 3, body)
	rect(image, front_boot, sole - 3, 9, 3, outline)
	rect(image, front_boot + 1, sole - 3, 7, 1, dark)
	rect(image, 10 + lean, torso, 12, waist - torso + 1, outline)
	rect(image, 11 + lean, torso + 1, 10, waist - torso - 1, body)
	rect(image, 14 + lean, torso + 3, 6, waist - torso - 3, dark)
	rect(image, 15 + lean, torso + 3, 4, waist - torso - 5, body.lightened(0.16))
	rect(image, 16 + lean + step, waist - 3, 4, 3, face)
	rect(image, 12 + lean, head, 11, torso - head + 2, outline)
	rect(image, 13 + lean, head + 1, 9, torso - head, face)
	rect(image, 13 + lean, head + 1, 8, 3, hair)
	rect(image, 13 + lean, head + 3, 3, torso - head - 2, hair)
	rect(image, 20 + lean, head + 5, 2, 1, outline)
	rect(image, 22 + lean, head + 6, 1, 2, face)
	match skin:
		0:
			rect(image, 12 + lean, head, 11, 3, dark)
			rect(image, 11 + lean, torso + 4, 3, 4, trim.darkened(0.2))
		1:
			rect(image, 13 + lean, head + 1, 9, torso - head, body)
			rect(image, 19 + lean, head + 4, 3, 2, face)
			rect(image, 11 + lean, waist - 4, 10, 2, trim)
		2:
			rect(image, 11 + lean, head + 1, 4, 7, hair)
			rect(image, 15 + lean, head - 2, 5, 4, trim)
			rect(image, 22 + lean, head + 5, 2, 2, trim)
			rect(image, 12 + lean, torso + 2, 10, 2, Color("#f7d651"))
		3:
			rect(image, 11 + lean, head + 1, 14, 3, trim)
			rect(image, 14 + lean, head - 2, 7, 4, hair)
			for band in [torso + 4, waist - 5]:
				rect(image, 11 + lean, band, 10, 2, trim)
		4:
			rect(image, 13 + lean, head - 1, 9, 4, body)
			rect(image, 20 + lean, head + 2, 4, 1, outline)
		5:
			rect(image, 15 + lean, 0, 4, head + 3, outline)
			rect(image, 16 + lean, 1, 2, head, Color("#ff758f"))
			rect(image, 9 + lean, waist - 4, 3, 3, trim)
			rect(image, 17 + lean, torso + 1, 5, 2, trim)
		6:
			rect(image, 13 + lean, head + 2, 8, torso - head - 1, face)
			rect(image, 18 + lean, head + 4, 5, 3, trim)
		7:
			rect(image, 11 + lean, head, 5, torso - head + 3, hair)
			rect(image, 13 + lean, head - 2, 8, 4, dark)
			rect(image, 12 + lean, head + 2, 9, 1, trim)
			rect(image, 14 + lean, torso + 2, 8, 1, trim)
	return image
