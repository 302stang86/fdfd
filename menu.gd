extends Control

const STREET_PROPS := preload("res://street_props.gd")
const MAP_EDITOR := preload("res://map_editor.gd")
const ARENA := preload("res://arena.tscn")
const CHARACTER_PREVIEW := preload("res://bot_model.gd")
const CROSSHAIR := preload("res://crosshair.gd")
const MAP_FILE := "user://arenas.json"
const CONFIG_FILE := "user://field-day.cfg"
const CHEAT_HASH := "97aa791eaa8aee573cd373f0c352ea67d7788d6aa00849b0eea29ba3f5fcb0e6" # SHA-256 of the cheat password
const CHEAT_OPTIONS := {
	"god_mode": "God mode (cannot be tagged)",
	"infinite_ammo": "Infinite paintballs",
	"one_hit": "One-hit tags (bots go down in one hit)",
	"fast_reload": "Instant reload",
}
const OUTFITS := ["Army fatigues", "Ninja", "Clown", "Firefighter", "Police officer", "Bunny cosplay", "Robot", "Emo"]
const COLORS := ["#63774b", "#34313d", "#db4f64", "#dcb05a", "#405a86", "#e9b5cb", "#9bb3ba", "#543b64"]
const MARKERS := ["Semi-auto rifle", "Sniper-style marker", "Paint grenade launcher"]
const DESCRIPTIONS := ["Rapid fire · slow reload", "Slow fire · fast reload", "Slow fire · moderate reload · area splash"]

var home: VBoxContainer
var outfits: OptionButton
var markers: OptionButton
var maps: OptionButton
var mode_picker: OptionButton
var ruleset_picker: OptionButton
var mobile_button: CheckButton
var difficulty_picker: OptionButton
var description: Label
var layout: BoxContainer
var header: BoxContainer
var navigation: BoxContainer
var side: BoxContainer
var drawer: PanelContainer
var play_dock: PanelContainer
var drawer_views: Dictionary = {}
var navigation_buttons: Dictionary = {}
var active_drawer := ""
var stage: SubViewportContainer
var turntable: Node3D
var showcase: Node3D
var stage_name: Label
var crouch_preview: CheckButton
var summary: Label
var display_font: FontVariation
var saved_maps: Dictionary = {}
var arena: Node
var settings := ConfigFile.new()
var editor: Node3D
var cheats_unlocked := false # lasts for this run only, the password is asked again next launch
var cheats: Dictionary = {}

func _ready() -> void:
	settings.load(CONFIG_FILE)
	if FileAccess.file_exists(MAP_FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
		if parsed is Dictionary:
			saved_maps = parsed
	install_theme()
	var background := TextureRect.new()
	background.texture = preload("res://assets/ui/menu_arena_dusk.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.028, 0.10, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	frame.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	frame.add_child(scroll)
	var padding := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + edge, 16)
	padding.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padding.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(padding)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 14)
	padding.add_child(main)
	header = BoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main.add_child(header)
	var brand := VBoxContainer.new()
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var eyebrow := heading(brand, "FIRE DEFENSE", 19, Color("#2fd8f5"))
	var wordmark := heading(brand, "FIELD DAY", 49, Color("#ffad38"))
	for line in [eyebrow, wordmark]:
		line.add_theme_font_override("font", display_font)
		line.add_theme_color_override("font_outline_color", Color("#15102d"))
		line.add_theme_constant_override("outline_size", 6)
	var header_actions := HBoxContainer.new()
	header_actions.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header.add_child(header_actions)
	menu_button(header_actions, "Settings", func(): show_drawer("Settings"))
	menu_button(header_actions, "Help", show_help)
	menu_button(header_actions, "Guest", func():
		show_info("Guest account", "You are playing as a guest. Custom maps are saved in this browser profile."))
	layout = BoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 14)
	main.add_child(layout)
	side = BoxContainer.new()
	side.add_theme_constant_override("separation", 12)
	layout.add_child(side)
	navigation = BoxContainer.new()
	navigation.vertical = true
	navigation.add_theme_constant_override("separation", 7)
	side.add_child(navigation)
	drawer = menu_panel(side, Color("#18163de8"))
	var drawer_shell := VBoxContainer.new()
	drawer.add_child(drawer_shell)
	var sections := ["Operative", "Marker", "Paint & Aim", "Arena", "Match Rules", "Settings"]
	var accents := [Color("#ff4fa3"), Color("#ff7a2f"), Color("#2fd8f5"), Color("#b6f23a"), Color("#ffd23f"), Color("#a798ff")]
	for index in range(sections.size()):
		var section: String = sections[index]
		if index < 5:
			var tab := menu_button(navigation, section, show_drawer.bind(section))
			tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
			tab.add_theme_color_override("font_color", Color("#f5f7ff"))
			tab.add_theme_font_override("font", display_font)
			tab.add_theme_stylebox_override("normal", panel_style(Color("#25234bcf"), accents[index].darkened(0.59)))
			tab.add_theme_stylebox_override("pressed", panel_style(Color("#35305fec"), accents[index]))
			navigation_buttons[section] = tab
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 8)
		drawer_shell.add_child(page)
		drawer_views[section] = page
		var title_row := HBoxContainer.new()
		page.add_child(title_row)
		var title := heading(title_row, section, 24, accents[index])
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_button(title_row, "Close", show_drawer.bind(""))
		page.hide()

	home = drawer_views["Operative"]
	outfits = picker("Outfit", OUTFITS)
	outfits.select(saved_option("outfit", 5, outfits.item_count))
	home = drawer_views["Marker"]
	markers = picker("Paintball marker", MARKERS)
	markers.select(saved_option("marker", 0, markers.item_count))
	description = add_label(DESCRIPTIONS[markers.selected])
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	markers.item_selected.connect(func(index: int): description.text = DESCRIPTIONS[index])
	home = drawer_views["Paint & Aim"]
	build_aim_controls()
	home = drawer_views["Arena"]
	maps = picker("Map", [])
	refresh_maps()
	add_button("Create a map", open_editor)
	home = drawer_views["Match Rules"]
	mode_picker = segmented_picker("Match mode", ["1v5", "3v3", "6v6"])
	difficulty_picker = segmented_picker("Bot difficulty", ["Easy", "Normal", "Hard"])
	ruleset_picker = segmented_picker("Scoring", ["5-hit elimination", "Timed"])
	select_rule(mode_picker, saved_option("mode", 0, 3))
	select_rule(difficulty_picker, saved_option("difficulty", 1, 3))
	select_rule(ruleset_picker, saved_option("ruleset", 0, 2))
	home = drawer_views["Settings"]
	add_label("Master volume")
	var volume := HSlider.new()
	volume.max_value = 100
	volume.value = clampf(float(settings.get_value("audio", "volume", 65)), 0, 100)
	home.add_child(volume)
	apply_volume(volume.value)
	volume.value_changed.connect(apply_volume)
	var phone := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	mobile_button = CheckButton.new()
	mobile_button.text = "Mobile controls"
	mobile_button.button_pressed = bool(settings.get_value("match", "mobile", phone))
	home.add_child(mobile_button)
	mobile_button.toggled.connect(func(_active: bool): save_match_setup())
	add_button("Cheat mode", open_cheats)

	build_stage()
	var dock_margin := MarginContainer.new()
	for edge in ["left", "right", "bottom"]:
		dock_margin.add_theme_constant_override("margin_" + edge, 16)
	frame.add_child(dock_margin)
	var dock_wrapper := HBoxContainer.new()
	dock_margin.add_child(dock_wrapper)
	dock_wrapper.alignment = BoxContainer.ALIGNMENT_END
	play_dock = menu_panel(dock_wrapper, Color("#151537ee"))
	var dock_row := HBoxContainer.new()
	dock_row.add_theme_constant_override("separation", 14)
	play_dock.add_child(dock_row)
	summary = heading(dock_row, "", 16, Color("#dfe5ff"))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var play := menu_button(dock_row, "PLAY MATCH", play_match)
	play.add_theme_font_size_override("font_size", 24)
	play.add_theme_font_override("font", display_font)
	play.custom_minimum_size.y = 56
	for state in ["normal", "hover", "pressed"]:
		play.add_theme_stylebox_override(state, panel_style(Color("#bb420f") if state == "pressed" else Color("#da550e"), Color("#ffb44a")))
	for option in [outfits, markers, maps, mode_picker, difficulty_picker, ruleset_picker]:
		option.item_selected.connect(func(_index: int): save_match_setup())
	outfits.item_selected.connect(func(_index: int): refresh_showcase())
	refresh_showcase()
	update_summary()
	resized.connect(update_menu_layout)
	update_menu_layout()
	show_drawer("Match Rules" if size.x >= 900.0 else "")

func update_menu_layout() -> void:
	var compact := size.x < 900.0
	header.vertical = size.x < 520.0
	layout.vertical = compact
	side.vertical = compact
	navigation.vertical = not compact
	for button in navigation_buttons.values():
		button.custom_minimum_size.x = 0 if compact else 148
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.vertical = not compact or size.x < 640.0
	drawer.custom_minimum_size.x = 0 if compact else 300
	stage.custom_minimum_size.y = 260 if compact else 340
	play_dock.custom_minimum_size.x = 0 if compact else 465
	play_dock.size_flags_horizontal = Control.SIZE_EXPAND_FILL if compact else Control.SIZE_SHRINK_END

func show_drawer(section: String) -> void:
	active_drawer = "" if section == active_drawer else section
	drawer.visible = not active_drawer.is_empty()
	for key in drawer_views:
		drawer_views[key].visible = key == active_drawer
	for key in navigation_buttons:
		var button: Button = navigation_buttons[key]
		button.set_pressed_no_signal(key == active_drawer)

func update_summary() -> void:
	if summary != null and maps.selected >= 0:
		summary.text = "%s\n%s  ·  %s bots  ·  %s" % [
			maps.get_item_text(maps.selected), mode_picker.text, difficulty_picker.text, ruleset_picker.text]

func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	for side_id in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side_id, 12)
	return style

func install_theme() -> void:
	theme = Theme.new()
	theme.default_font_size = 16
	display_font = FontVariation.new()
	display_font.base_font = ThemeDB.fallback_font
	display_font.variation_embolden = 0.85
	for type_id in ["Button", "OptionButton"]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var highlight: bool = state == "pressed" or state == "focus"
			var fill := Color("#373a7c") if state != "normal" else Color("#252b62")
			theme.set_stylebox(state, type_id, panel_style(fill, Color("#8d99ef") if highlight else Color("#454778")))

func menu_panel(parent: Control, fill: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style(fill, Color("#464a7d")))
	parent.add_child(panel)
	return panel

func heading(parent: Control, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func menu_button(parent: Control, value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	parent.add_child(button)
	button.pressed.connect(callback)
	if parent == navigation:
		button.toggle_mode = true
	return button

func add_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	home.add_child(label)
	return label

func add_button(value: String, callback: Callable) -> void:
	menu_button(home, value, callback)

func picker(label: String, values: Array) -> OptionButton:
	add_label(label)
	var options := OptionButton.new()
	for value in values:
		options.add_item(value)
	home.add_child(options)
	return options

func segmented_picker(label: String, values: Array) -> OptionButton:
	add_label(label)
	var picker_value := OptionButton.new()
	home.add_child(picker_value)
	picker_value.hide()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	home.add_child(row)
	var buttons: Array[Button] = []
	var group := ButtonGroup.new()
	for index in range(values.size()):
		var button := menu_button(row, values[index], func():
			picker_value.select(index)
			picker_value.item_selected.emit(index))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_stylebox_override("pressed", panel_style(Color("#ffcf35"), Color("#ffefa0")))
		button.add_theme_color_override("font_pressed_color", Color("#17132b"))
		buttons.append(button)
		picker_value.add_item(values[index])
	picker_value.set_meta("segments", buttons)
	return picker_value

func select_rule(picker_value: OptionButton, index: int) -> void:
	picker_value.select(index)
	var button: Button = picker_value.get_meta("segments")[index]
	button.button_pressed = true

func build_aim_controls() -> void:
	var sample := ColorRect.new()
	sample.color = Color("#101635")
	sample.custom_minimum_size.y = 72
	home.add_child(sample)
	var reticle := CROSSHAIR.new()
	sample.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := picker("Crosshair", CROSSHAIR.STYLES)
	var color := picker("Crosshair color", CROSSHAIR.RETICLE_COLOR_NAMES)
	var paint := picker("Paint color", CROSSHAIR.COLOR_NAMES)
	style.select(aim_option("style", 0, CROSSHAIR.STYLES.size()))
	color.select(aim_option("color", 3, CROSSHAIR.RETICLE_COLOR_NAMES.size()))
	paint.select(aim_option("paint", 2, CROSSHAIR.COLOR_NAMES.size()))
	var size_label := add_label("Crosshair size")
	var size_slider := HSlider.new()
	size_slider.min_value = CROSSHAIR.MIN_SIZE
	size_slider.max_value = CROSSHAIR.MAX_SIZE
	size_slider.step = 1
	size_slider.value = aim_size()
	home.add_child(size_slider)
	var refresh := func():
		reticle.style_index = style.selected
		reticle.ink = CROSSHAIR.RETICLE_COLORS[color.selected]
		reticle.diameter = int(size_slider.value)
		reticle.queue_redraw()
		size_label.text = "Crosshair size · %d" % reticle.diameter
	var save_aim := func(_value: float):
		settings.set_value("aim", "style", style.selected)
		settings.set_value("aim", "color", color.selected)
		settings.set_value("aim", "paint", paint.selected)
		settings.set_value("aim", "size", int(size_slider.value))
		settings.save(CONFIG_FILE)
		refresh.call()
	for option in [style, color, paint]:
		option.item_selected.connect(save_aim)
	size_slider.value_changed.connect(save_aim)
	refresh.call()

func aim_option(key: String, default_value: int, count: int) -> int:
	var option := int(settings.get_value("aim", key, default_value))
	return option if option >= 0 and option < count else default_value

func aim_size() -> int:
	return clampi(int(settings.get_value("aim", "size", CROSSHAIR.DEFAULT_SIZE)), CROSSHAIR.MIN_SIZE, CROSSHAIR.MAX_SIZE)

func apply_aim_settings() -> void:
	arena.crosshair_style = aim_option("style", 0, CROSSHAIR.STYLES.size())
	arena.crosshair_color = CROSSHAIR.RETICLE_COLORS[aim_option("color", 3, CROSSHAIR.RETICLE_COLOR_NAMES.size())]
	arena.crosshair_size = aim_size()
	arena.player_paint = CROSSHAIR.COLORS[aim_option("paint", 2, CROSSHAIR.COLOR_NAMES.size())]

func apply_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value == 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.001)))
	settings.set_value("audio", "volume", value)
	settings.save(CONFIG_FILE)

func build_stage() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	layout.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	panel.add_child(content)
	stage = SubViewportContainer.new()
	stage.stretch = true
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.gui_input.connect(rotate_showcase)
	content.add_child(stage)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	stage.add_child(viewport)
	var scene_root := Node3D.new()
	viewport.add_child(scene_root)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_CLEAR_COLOR
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#c2ccff")
	world.environment.ambient_light_energy = 0.65
	scene_root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34, 22, 0)
	key.light_color = Color("#ffe4c3")
	scene_root.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-17, 170, 0)
	rim.light_color = Color("#6de1ff")
	rim.light_energy = 0.7
	scene_root.add_child(rim)
	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.62
	disc.bottom_radius = 0.68
	disc.height = 0.13
	plinth.mesh = disc
	var finish := StandardMaterial3D.new()
	finish.albedo_color = Color("#555064")
	finish.roughness = 0.71
	plinth.material_override = finish
	plinth.position.y = -0.065
	scene_root.add_child(plinth)
	turntable = Node3D.new()
	scene_root.add_child(turntable)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.79
	camera.position = Vector3(0.8, 1.05, 4.5)
	scene_root.add_child(camera)
	camera.look_at(Vector3(0, 0.74, 0))
	camera.make_current()
	var caption_wrap := menu_panel(content, Color("#161537d9"))
	caption_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var caption := HBoxContainer.new()
	caption.add_theme_constant_override("separation", 16)
	caption_wrap.add_child(caption)
	stage_name = heading(caption, "", 20, Color("#f5f7ff"))
	stage_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crouch_preview = CheckButton.new()
	crouch_preview.text = "Crouch"
	crouch_preview.toggled.connect(func(enabled: bool): showcase.set_crouching(enabled))
	caption.add_child(crouch_preview)
	var hint := heading(content, "Drag to rotate", 14, Color("#a6afdc"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func refresh_showcase() -> void:
	if is_instance_valid(showcase):
		showcase.queue_free()
	showcase = CHARACTER_PREVIEW.new()
	turntable.add_child(showcase)
	showcase.setup(outfits.selected, false)
	showcase.set_crouching(crouch_preview.button_pressed)
	stage_name.text = outfits.text

func rotate_showcase(event: InputEvent) -> void:
	if event is InputEventScreenDrag or (event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		turntable.rotate_y(event.relative.x * 0.012)
		stage.accept_event()

func show_help() -> void:
	show_info("How to play", "Click the arena to capture the mouse and start the countdown.\n\nMove with WASD, hold C to crouch, and press Space to jump. Walk toward a ladder with W to climb, use W/S to move on it, and press Space to let go. Press E to use a nearby door.\n\nLeft-click to fire and hold right-click to steady the marker. Your marker reloads automatically when empty. Tag every opponent to win. In team matches, teammates have teal diamonds. Timed matches count hits without elimination.\n\nFor mobile, turn on Mobile controls in Settings and rotate to landscape. Left stick moves, right stick looks. Use the labeled buttons for actions.\n\nEsc releases the mouse. M opens the menu.")

func show_info(title: String, body: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = body
	dialog.dialog_autowrap = true
	dialog.min_size = Vector2i(460, 130)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func saved_option(key: String, fallback: int, count: int) -> int:
	var index := int(settings.get_value("match", key, fallback))
	return index if index >= 0 and index < count else fallback

func save_match_setup() -> void:
	settings.set_value("match", "outfit", outfits.selected)
	settings.set_value("match", "marker", markers.selected)
	settings.set_value("match", "mode", mode_picker.selected)
	settings.set_value("match", "difficulty", difficulty_picker.selected)
	settings.set_value("match", "ruleset", ruleset_picker.selected)
	settings.set_value("match", "mobile", mobile_button.button_pressed)
	settings.set_value("match", "map", maps.get_selected_metadata())
	settings.save(CONFIG_FILE)
	update_summary()

func refresh_maps() -> void:
	var selected: Variant = maps.get_selected_metadata()
	if selected == null:
		selected = settings.get_value("match", "map", "builtin:urban")
	maps.clear()
	maps.add_item("Field Day Arena")
	maps.set_item_metadata(0, "builtin:field_day")
	maps.add_item("Open Field")
	maps.set_item_metadata(1, "builtin:open_field")
	maps.add_item("Urban Perimeter")
	maps.set_item_metadata(2, "builtin:urban")
	var names := saved_maps.keys()
	names.sort()
	for title in names:
		maps.add_item(title + " (local)")
		maps.set_item_metadata(maps.item_count - 1, "local:" + title)
	maps.select(2)
	for index in range(maps.item_count):
		if maps.get_item_metadata(index) == selected:
			maps.select(index)
			break
	update_summary()

func play_match() -> void:
	arena = ARENA.instantiate()
	apply_aim_settings()
	arena.marker_id = markers.selected
	arena.outfit_color = Color(COLORS[outfits.selected])
	arena.map_id = maps.selected
	arena.team_match = mode_picker.selected > 0
	arena.six_vs_six = mode_picker.selected == 2
	arena.timed_match = ruleset_picker.selected == 1
	arena.mobile_mode = mobile_button.button_pressed
	arena.difficulty = difficulty_picker.selected
	arena.cheats = cheats.duplicate()
	if maps.selected >= 3:
		arena.custom_layout = saved_maps[String(maps.get_selected_metadata()).trim_prefix("local:")]
	arena.menu_requested.connect(return_home)
	hide()
	add_child(arena)

func open_cheats() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Cheat mode"
	dialog.ok_button_text = "Close"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 340
	form.add_theme_constant_override("separation", 8)
	dialog.add_child(form)
	if cheats_unlocked:
		build_cheat_toggles(form)
	else:
		add_dialog_label(form, "Enter the password to unlock cheat mode.")
		var password := LineEdit.new()
		password.secret = true
		password.placeholder_text = "Password"
		form.add_child(password)
		var status := add_dialog_label(form, "")
		var unlock := Button.new()
		unlock.text = "Unlock"
		form.add_child(unlock)
		var try_unlock := func():
			if password.text.sha256_text() == CHEAT_HASH:
				cheats_unlocked = true
				for child in form.get_children():
					child.queue_free()
				build_cheat_toggles(form)
				dialog.reset_size()
			else:
				status.text = "Wrong password."
				password.clear()
		unlock.pressed.connect(try_unlock)
		password.text_submitted.connect(func(_text: String): try_unlock.call())
	add_child(dialog)
	dialog.popup_centered()

func add_dialog_label(parent: Control, value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func build_cheat_toggles(form: VBoxContainer) -> void:
	add_dialog_label(form, "Cheats apply to the next match you start.")
	for key in CHEAT_OPTIONS:
		var toggle := CheckBox.new()
		toggle.text = CHEAT_OPTIONS[key]
		toggle.button_pressed = cheats.get(key, false)
		toggle.toggled.connect(func(on: bool):
			if on:
				cheats[key] = true
			else:
				cheats.erase(key))
		form.add_child(toggle)

func return_home() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	arena = null
	show()

func open_editor() -> void:
	editor = MAP_EDITOR.new()
	editor.saved_maps = saved_maps.duplicate(true)
	editor.map_saved.connect(on_editor_saved)
	editor.map_deleted.connect(on_editor_deleted)
	editor.closed.connect(close_editor)
	editor.test_requested.connect(test_layout)
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(editor)
	editor.make_current()

func write_maps() -> bool:
	var file := FileAccess.open(MAP_FILE, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(saved_maps))
	file.close()
	return true

func select_saved_map(title: String) -> void:
	refresh_maps()
	for index in range(3, maps.item_count):
		if maps.get_item_metadata(index) == "local:" + title:
			maps.select(index)
			save_match_setup()
			break

func on_editor_saved(title: String, layout: Dictionary) -> void:
	saved_maps[title] = layout
	if not write_maps():
		editor.set_status("The map could not be written to disk.")
	select_saved_map(title)

func on_editor_deleted(title: String) -> void:
	saved_maps.erase(title)
	write_maps()
	refresh_maps()

func close_editor() -> void:
	if editor != null:
		editor.queue_free()
		editor = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()

# Test-play the map being edited. The editor leaves the scene tree while the match runs.
func test_layout(layout: Dictionary) -> void:
	remove_child(editor)
	arena = ARENA.instantiate()
	apply_aim_settings()
	arena.marker_id = markers.selected
	arena.outfit_color = Color(COLORS[outfits.selected])
	arena.map_id = 3
	arena.team_match = mode_picker.selected > 0
	arena.six_vs_six = mode_picker.selected == 2
	arena.timed_match = ruleset_picker.selected == 1
	arena.mobile_mode = mobile_button.button_pressed
	arena.difficulty = difficulty_picker.selected
	arena.cheats = cheats.duplicate()
	arena.custom_layout = layout
	arena.menu_requested.connect(return_to_editor)
	add_child(arena)

func return_to_editor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	arena = null
	add_child(editor)
	editor.make_current()
