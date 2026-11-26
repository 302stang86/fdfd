extends Control

const ARENA := preload("res://arena.tscn")
const MAP_FILE := "user://arenas.json"
const CONFIG_FILE := "user://field-day.cfg"
const OUTFITS := ["Army fatigues", "Ninja", "Clown", "Firefighter", "Police officer", "Bunny cosplay", "Robot", "Emo / goth"]
const COLORS := ["#63774b", "#34313d", "#db4f64", "#dcb05a", "#405a86", "#e9b5cb", "#9bb3ba", "#543b64"]
const MARKERS := ["Semi-auto rifle", "Sniper-style marker", "Paint grenade launcher"]
const DESCRIPTIONS := ["Rapid fire · slow reload · mild zoom", "Slow fire · fast reload · scope zoom", "Slow fire · moderate reload · area splash"]

var home: VBoxContainer
var outfits: OptionButton
var markers: OptionButton
var maps: OptionButton
var description: Label
var preview: ColorRect
var saved_maps: Dictionary = {}
var arena: Node
var settings := ConfigFile.new()
var map_name: LineEdit
var grid: GridContainer
var drafting: Dictionary = {}
var editor_status: Label

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
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
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
	preview = ColorRect.new()
	preview.custom_minimum_size.y = 7
	home.add_child(preview)
	outfits.item_selected.connect(func(index: int): preview.color = Color(COLORS[index]))
	preview.color = Color(COLORS[0])
	markers = picker("Paintball marker", MARKERS)
	description = add_label(DESCRIPTIONS[0])
	markers.item_selected.connect(func(index: int): description.text = DESCRIPTIONS[index])
	maps = picker("Map", [])
	refresh_maps()
	add_button("Play match", play_match)
	add_button("Create a map", open_editor)
	add_button("How to play", func(): show_info("How to play",
		"Click the arena to capture the mouse. Use WASD to move, Space to jump, left-click to fire, right-click to aim, and R to reload. Tag all five bots to win. Press Enter after a match to restart, Esc to release the mouse, and M to return to the main menu."))

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

func apply_volume(value: float) -> void:
	AudioServer.set_bus_mute(0, value == 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(value / 100.0, 0.001)))
	settings.set_value("audio", "volume", value)
	settings.save(CONFIG_FILE)

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

func refresh_maps() -> void:
	maps.clear()
	maps.add_item("Field Day Arena")
	maps.add_item("Open Field")
	var names := saved_maps.keys()
	names.sort()
	for title in names:
		maps.add_item(title + " (local)")
		maps.set_item_metadata(maps.item_count - 1, title)
	maps.select(0)

func play_match() -> void:
	arena = ARENA.instantiate()
	arena.marker_id = markers.selected
	arena.outfit_color = Color(COLORS[outfits.selected])
	arena.map_id = maps.selected
	if maps.selected >= 2:
		arena.custom_layout = saved_maps[maps.get_selected_metadata()]
	arena.menu_requested.connect(return_home)
	hide()
	add_child(arena)

func return_home() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	arena.queue_free()
	arena = null
	show()

func open_editor() -> void:
	drafting = {}
	var dialog := AcceptDialog.new()
	dialog.title = "Create an arena"
	dialog.ok_button_text = "Save map"
	dialog.exclusive = true
	dialog.close_requested.connect(dialog.queue_free)
	dialog.dialog_hide_on_ok = false
	var form := VBoxContainer.new()
	dialog.add_child(form)
	map_name = LineEdit.new()
	map_name.placeholder_text = "New map name"
	map_name.max_length = 40
	form.add_child(map_name)
	var instructions := Label.new()
	instructions.text = "Click cells to toggle cover. Spawns and arena walls are added automatically."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	form.add_child(instructions)
	grid = GridContainer.new()
	grid.columns = 12
	form.add_child(grid)
	for z in range(10):
		for x in range(12):
			var tile := Button.new()
			tile.text = "·"
			tile.custom_minimum_size = Vector2(29, 23)
			tile.toggle_mode = true
			var cell := "%d,%d" % [(x * 3) - 16, (z * 3) - 13]
			if cell == "17,-4":
				tile.disabled = true
				tile.tooltip_text = "Bot spawn"
			tile.toggled.connect(func(enabled: bool):
				if enabled:
					drafting[cell] = true
				else:
					drafting.erase(cell)
				tile.text = "■" if enabled else "·"
			)
			grid.add_child(tile)
	editor_status = Label.new()
	form.add_child(editor_status)
	dialog.confirmed.connect(func(): save_map(dialog))
	add_child(dialog)
	dialog.popup_centered(Vector2i(460, 405))

func save_map(dialog: AcceptDialog) -> void:
	var title := map_name.text.strip_edges()
	if title.is_empty() or saved_maps.has(title):
		editor_status.text = "Choose a new, unique map name."
		return
	var layout := {}
	for key in drafting:
		layout[key] = true
	var updated := saved_maps.duplicate()
	updated[title] = layout
	var file := FileAccess.open(MAP_FILE, FileAccess.WRITE)
	if file == null:
		editor_status.text = "The map could not be saved."
		return
	file.store_string(JSON.stringify(updated))
	file.close()
	saved_maps = updated
	refresh_maps()
	for index in range(2, maps.item_count):
		if maps.get_item_metadata(index) == title:
			maps.select(index)
			break
	dialog.queue_free()
