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
const OUTFITS := ["Army fatigues", "Ninja", "Clown", "Firefighter", "Police officer", "Bunny cosplay", "Robot", "Emo / goth"]
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
var preview: ColorRect
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
	var bg := ColorRect.new()
	bg.color = Color("#18262b")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#24373d")
	style.border_color = Color("#65848b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	for side in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		style.set_content_margin(side, 24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	home = VBoxContainer.new()
	home.custom_minimum_size.x = 440
	home.add_theme_constant_override("separation", 9)
	panel.add_child(home)
	var title := Label.new()
	title.text = "Fire Defense Field Day"
	title.add_theme_font_size_override("font_size", 31)
	home.add_child(title)
	var account := Button.new()
	account.text = "Log in / Register"
	account.pressed.connect(func(): show_info("Player account", "You are playing as a guest. Login and registration will be available when Firebase Authentication is connected. Custom maps are saved in this browser profile."))
	home.add_child(account)
	add_label("Master volume")
	var volume := HSlider.new()
	volume.min_value = 0
	volume.max_value = 100
	volume.value = clampf(float(settings.get_value("audio", "volume", 65)), 0, 100)
	home.add_child(volume)
	apply_volume(volume.value)
	volume.value_changed.connect(apply_volume)
	outfits = picker("Character", OUTFITS)
	var character_row := HBoxContainer.new()
	character_row.add_theme_constant_override("separation", 8)
	home.add_child(character_row)
	outfits.reparent(character_row)
	outfits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outfits.select(saved_option("outfit", 5, outfits.item_count))
	var open_preview := Button.new()
	open_preview.text = "Preview"
	open_preview.pressed.connect(show_character_preview)
	character_row.add_child(open_preview)
	preview = ColorRect.new()
	preview.custom_minimum_size.y = 7
	home.add_child(preview)
	outfits.item_selected.connect(func(index: int): preview.color = Color(COLORS[index]))
	preview.color = Color(COLORS[outfits.selected])
	markers = picker("Paintball marker", MARKERS)
	markers.select(saved_option("marker", 0, markers.item_count))
	description = add_label(DESCRIPTIONS[markers.selected])
	markers.item_selected.connect(func(index: int): description.text = DESCRIPTIONS[index])
	maps = picker("Map", [])
	refresh_maps()
	var rules := HBoxContainer.new()
	rules.add_theme_constant_override("separation", 12)
	home.add_child(rules)
	mode_picker = rules_picker(rules, "Match mode", ["1v5", "3v3", "6v6"], saved_option("mode", 0, 3))
	difficulty_picker = rules_picker(rules, "Bot difficulty", ["Easy", "Normal", "Hard"], saved_option("difficulty", 1, 3))
	ruleset_picker = rules_picker(rules, "Scoring", ["5-hit elimination", "Timed · most hits"], saved_option("ruleset", 0, 2))
	var phone := OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile")
	mobile_button = CheckButton.new()
	mobile_button.text = "Mobile controls"
	mobile_button.button_pressed = bool(settings.get_value("match", "mobile", phone))
	home.add_child(mobile_button)
	mobile_button.toggled.connect(func(_active: bool): save_match_setup())
	for option in [outfits, markers, maps, mode_picker, difficulty_picker, ruleset_picker]:
		option.item_selected.connect(func(_index: int): save_match_setup())
	add_button("Play match", play_match)
	add_button("Crosshair & paint color", open_aim_settings)
	add_button("Create a map", open_editor)
	add_button("Cheat mode", open_cheats)
	add_button("How to play", func(): show_info("How to play",
		"Click the arena to capture the mouse and start the countdown.\n\nMove with WASD, hold C to crouch, and press Space to jump. Walk toward a ladder with W to climb, use W/S to move on it, and press Space to let go. Press E to use a nearby door.\n\nLeft-click to fire and hold right-click to steady the marker. Your marker reloads automatically when empty. Tag every opponent to win. In team matches, teammates have teal diamonds. Timed matches last three minutes and count hits without elimination.\n\nFor mobile, turn on Mobile controls and rotate to landscape. Left stick moves, right stick looks, and labeled buttons handle firing, aiming, crouching, jumping, and doors.\n\nEsc releases the mouse. M opens the menu. Press Enter after a win to play again."))

func add_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	home.add_child(label)
	return label

func add_button(value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	home.add_child(button)

func picker(label: String, values: Array) -> OptionButton:
	add_label(label)
	var options := OptionButton.new()
	for value in values:
		options.add_item(value)
	home.add_child(options)
	return options

func rules_picker(row: HBoxContainer, heading: String, items: Array, selected: int) -> OptionButton:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var label := Label.new()
	label.text = heading
	column.add_child(label)
	var options := OptionButton.new()
	for item in items:
		options.add_item(item)
	options.select(selected)
	column.add_child(options)
	return options

func open_aim_settings() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Crosshair & paint color"
	dialog.ok_button_text = "Done"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	dialog.add_child(content)
	var sample := ColorRect.new()
	sample.color = Color("#233237")
	sample.custom_minimum_size.y = 72
	content.add_child(sample)
	var reticle := CROSSHAIR.new()
	sample.add_child(reticle)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	var style := rules_picker(row, "Crosshair", CROSSHAIR.STYLES, aim_option("style", 0, CROSSHAIR.STYLES.size()))
	var color := rules_picker(row, "Crosshair color", CROSSHAIR.RETICLE_COLOR_NAMES, aim_option("color", 3, CROSSHAIR.RETICLE_COLOR_NAMES.size()))
	var paint := rules_picker(row, "Paint color", CROSSHAIR.COLOR_NAMES, aim_option("paint", 2, CROSSHAIR.COLOR_NAMES.size()))
	var size_label := Label.new()
	content.add_child(size_label)
	var scale_slider := HSlider.new()
	scale_slider.min_value = CROSSHAIR.MIN_SIZE
	scale_slider.max_value = CROSSHAIR.MAX_SIZE
	scale_slider.step = 1
	scale_slider.value = aim_size()
	content.add_child(scale_slider)

	var refresh_preview := func():
		reticle.style_index = style.selected
		reticle.ink = CROSSHAIR.RETICLE_COLORS[color.selected]
		reticle.diameter = int(scale_slider.value)
		reticle.queue_redraw()
		size_label.text = "Crosshair size · %d" % reticle.diameter
	var save_preferences := func(_value: float):
		settings.set_value("aim", "style", style.selected)
		settings.set_value("aim", "color", color.selected)
		settings.set_value("aim", "paint", paint.selected)
		settings.set_value("aim", "size", int(scale_slider.value))
		settings.save(CONFIG_FILE)
		refresh_preview.call()
	for option in [style, color, paint]:
		option.item_selected.connect(save_preferences)
	scale_slider.value_changed.connect(save_preferences)
	refresh_preview.call()
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 240))

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

func show_character_preview() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = outfits.get_item_text(outfits.selected)
	dialog.ok_button_text = "Close"
	dialog.confirmed.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	dialog.add_child(content)
	var display := SubViewportContainer.new()
	display.custom_minimum_size = Vector2(380, 280)
	display.stretch = true
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(display)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	display.add_child(viewport)
	var platform := Node3D.new()
	viewport.add_child(platform)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#35474e")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#ffffff")
	world.environment.ambient_light_energy = 0.6
	platform.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-36, 26, 0)
	platform.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.85
	camera.position = Vector3(2.1, 1.36, 4.6)
	platform.add_child(camera)
	var model := CHARACTER_PREVIEW.new()
	platform.add_child(model)
	model.setup(outfits.selected, false)
	var pose := CheckButton.new()
	pose.text = "Crouching pose"
	pose.toggled.connect(model.set_crouching)
	content.add_child(pose)
	add_child(dialog)
	camera.look_at(Vector3(0, 0.76, 0))
	camera.make_current()
	dialog.popup_centered(Vector2i(430, 370))

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
