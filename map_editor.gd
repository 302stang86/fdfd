extends Node3D
# In-game map editor. One 3D scene with two views of the same map: a top-down orthographic view
# (default) and a free-fly 3D camera (Tab). Everything you see is built by map_layout.gd, the same
# code the match uses, so what you place is what you play.
#
# Tools (1-4): Select/move, Wall, Road, Intersection. Pick an object in the palette to place props.
# Keys: Tab view, WASD move/pan (Shift fast, Space/C up/down when flying), mouse wheel zoom,
# middle-drag pan, right-drag look (flying), Q/E rotate 15 deg (Shift: 90), PageUp/PageDown height,
# [ ] scale, arrows nudge, Delete remove, Ctrl+C/V/D copy/paste/duplicate, Ctrl+Z/Y undo/redo,
# Ctrl+S save, G snap, Enter or right-click finishes a wall/road, Esc cancels.

signal closed
signal map_saved(title: String, layout: Dictionary)
signal map_deleted(title: String)
signal test_requested(layout: Dictionary)

const MAP_LAYOUT := preload("res://map_layout.gd")
const STREET_PROPS := preload("res://street_props.gd")
const HALF := 48.0
const CATEGORIES := {
	"Cover & barriers": ["crate", "brick_wall_low", "concrete_wall_tall", "jersey_barrier", "crowd_barricade", "bollard", "wood_fence", "chain_link_fence", "sawhorse", "barrel", "traffic_cone", "rubble_heap"],
	"Vehicles": ["sedan", "pickup", "box_truck", "car_wreck", "flatbed", "box_truck_climb"],
	"Alley & industrial": ["dumpster", "pallet_stack", "box_pile", "transformer_box", "generator", "ac_chiller", "material_bin", "cable_spools", "water_tank", "scaffold_tower"],
	"Street furniture": ["hydrant", "trash_can", "bench", "planter", "hedge", "bus_stop", "vending_climb", "billboard", "gazebo", "fire_escape"],
	"Climbable": ["container_20ft", "container_40ft", "dumpster_climb", "pallet_stairs", "jersey_stack", "retaining_wall", "transformer_climb", "planter_tier"],
	"Hideouts (enterable)": ["porta_potty", "cargo_trailer", "container_interior", "dumpster_hideout", "bus_shelter_enclosed", "payphone_booth", "utility_cabinet", "construction_tent", "van_camper", "culvert"],
}
const PLAYER_SPAWN := Vector2(0, 35)
const BOT_SPAWNS := [Vector2(-30, -30), Vector2(30, -30), Vector2(0, -37), Vector2(-32, 8), Vector2(32, -8)]

var saved_maps: Dictionary = {}
var layout_builder := MAP_LAYOUT.new()
var entities: Array = []
var built: Array = []
var layout_root: Node3D
var selection: Array[int] = []
var tool := "select"
var place_id := ""
var wall_style := "brick_low"
var road_type := "asphalt"
var road_width := 6.0
var road_walk := true
var snap_on := true
var snap_size := 1.0
var stack_on := true
var place_rot := 0.0
var draft: Array[Vector2] = []
var clipboard: Array = []
var undo_stack: Array[String] = []
var redo_stack: Array[String] = []
var dirty := false
var loaded_title := ""

var camera: Camera3D
var top_down := true
var zoom := 70.0
var focus := Vector2(0, 0)
var fly_yaw := 0.0
var fly_pitch := -0.5
var looking := false
var panning := false
var cursor := Vector2.ZERO
var cursor_valid := false
var ghost_root: Node3D
var overlay: ImmediateMesh
var drag := {}
var suppress_ui := false

var name_edit: LineEdit
var status: Label
var info: Label
var open_menu: MenuButton
var palette_list: ItemList
var category_pick: OptionButton
var tool_buttons := {}
var wall_pick: OptionButton
var road_pick: OptionButton
var width_spin: SpinBox
var walk_check: CheckBox
var snap_check: CheckBox
var snap_pick: OptionButton
var stack_check: CheckBox
var view_button: Button
var props_box: VBoxContainer
var prop_title: Label
var spin := {}
var style_pick: OptionButton
var closed_check: CheckBox
var confirm: ConfirmationDialog
var pending_confirm := Callable()
# mini window: shows the 3D view while the main view is top-down, and the top-down map while flying
var mini_panel: PanelContainer
var mini_container: SubViewportContainer
var mini_viewport: SubViewport
var mini_camera: Camera3D
var mini_label: Label
var mini_check: CheckBox
var mini_yaw := 0.6
var mini_elevation := 0.75
var mini_distance := 42.0
var mini_zoom := 80.0
var cam_marker: Node3D

func _ready() -> void:
	build_world()
	build_ui()
	set_tool("select")
	apply_camera()
	set_status("Pick an object on the left to place it, or use the Wall / Road tools.")

# --- world -----------------------------------------------------------------------------------

func build_world() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("#6f879a")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(HALF * 2.0, 0.5, HALF * 2.0)
	floor_mesh.mesh = box
	floor_mesh.position.y = -0.25
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#485842")
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	var grid := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for step in range(-24, 25):
		var value := step * 2.0
		var major := step % 5 == 0
		lines.surface_set_color(Color(1, 1, 1, 0.28 if major else 0.1))
		lines.surface_add_vertex(Vector3(value, 0.03, -HALF))
		lines.surface_add_vertex(Vector3(value, 0.03, HALF))
		lines.surface_set_color(Color(1, 1, 1, 0.28 if major else 0.1))
		lines.surface_add_vertex(Vector3(-HALF, 0.03, value))
		lines.surface_add_vertex(Vector3(HALF, 0.03, value))
	lines.surface_end()
	grid.mesh = lines
	grid.material_override = line_material()
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)
	for spawn_point in [PLAYER_SPAWN] + BOT_SPAWNS:
		var marker := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 1.0
		disc.bottom_radius = 1.0
		disc.height = 0.06
		marker.mesh = disc
		marker.position = Vector3(spawn_point.x, 0.05, spawn_point.y)
		var paint := StandardMaterial3D.new()
		paint.albedo_color = Color("#3b8bd9") if spawn_point == PLAYER_SPAWN else Color("#d9553b")
		paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.material_override = paint
		add_child(marker)
	layout_root = Node3D.new()
	layout_root.name = "Layout"
	add_child(layout_root)
	ghost_root = Node3D.new()
	add_child(ghost_root)
	var overlay_node := MeshInstance3D.new()
	overlay = ImmediateMesh.new()
	overlay_node.mesh = overlay
	var overlay_material := line_material()
	overlay_material.no_depth_test = true
	overlay_material.render_priority = 10
	overlay_node.material_override = overlay_material
	overlay_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(overlay_node)
	camera = Camera3D.new()
	camera.far = 500.0
	camera.cull_mask = 1 # layer 2 holds the camera marker, which only the mini window shows
	add_child(camera)
	cam_marker = Node3D.new()
	var arrow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(3.0, 5.0, 1.0)
	arrow.mesh = prism
	arrow.rotation.x = -PI / 2.0 # the tip points along -Z, the way the camera looks
	arrow.layers = 2
	var arrow_paint := StandardMaterial3D.new()
	arrow_paint.albedo_color = Color("#ffb020")
	arrow_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow.material_override = arrow_paint
	cam_marker.add_child(arrow)
	cam_marker.visible = false
	add_child(cam_marker)

func line_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

# --- UI --------------------------------------------------------------------------------------

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# top bar
	var top := PanelContainer.new()
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Map name"
	name_edit.max_length = 40
	name_edit.custom_minimum_size.x = 170
	bar.add_child(name_edit)
	add_button(bar, "Save", save_map, "Save (Ctrl+S). Saving over an existing name replaces that map.")
	open_menu = MenuButton.new()
	open_menu.text = "Open"
	open_menu.about_to_popup.connect(refresh_open_menu)
	open_menu.get_popup().id_pressed.connect(open_from_menu)
	bar.add_child(open_menu)
	add_button(bar, "New", func(): ask("Start a new empty map?", new_map))
	add_button(bar, "Del map", delete_map, "Delete the saved map with the name in the box")
	bar.add_child(VSeparator.new())
	add_button(bar, "Undo", undo)
	add_button(bar, "Redo", redo)
	bar.add_child(VSeparator.new())
	snap_check = CheckBox.new()
	snap_check.text = "Snap"
	snap_check.button_pressed = true
	snap_check.toggled.connect(func(on: bool): snap_on = on)
	bar.add_child(snap_check)
	snap_pick = OptionButton.new()
	for size_value in [0.25, 0.5, 1.0, 2.0, 3.0]:
		snap_pick.add_item("%s m" % size_value)
		snap_pick.set_item_metadata(snap_pick.item_count - 1, size_value)
	snap_pick.select(2)
	snap_pick.item_selected.connect(func(index: int): snap_size = snap_pick.get_item_metadata(index))
	bar.add_child(snap_pick)
	stack_check = CheckBox.new()
	stack_check.text = "Stack"
	stack_check.button_pressed = true
	stack_check.tooltip_text = "Placed and dragged props rest on whatever is below them"
	stack_check.toggled.connect(func(on: bool): stack_on = on)
	bar.add_child(stack_check)
	mini_check = CheckBox.new()
	mini_check.text = "Mini view"
	mini_check.button_pressed = true
	mini_check.tooltip_text = "Show the small picture-in-picture window (3D preview or top-down map)"
	bar.add_child(mini_check)
	view_button = add_button(bar, "Top-down", toggle_view, "Switch between top-down and free-fly 3D (Tab)")
	add_button(bar, "Test play", func(): test_requested.emit(current_layout()))
	add_button(bar, "Exit", func(): if dirty: ask("Leave the editor? Unsaved changes will be lost.", func(): closed.emit()) else: closed.emit())
	# left panel
	var left := PanelContainer.new()
	root.add_child(left)
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_top = 44
	left.offset_right = 230
	left.offset_bottom = -30
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	var tools := GridContainer.new()
	tools.columns = 2
	left_box.add_child(tools)
	for entry in [["select", "1 Select"], ["wall", "2 Wall"], ["road", "3 Road"], ["intersection", "4 Intersection"]]:
		var button := Button.new()
		button.text = entry[1]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_tool.bind(entry[0]))
		tools.add_child(button)
		tool_buttons[entry[0]] = button
	wall_pick = OptionButton.new()
	for key in MAP_LAYOUT.WALLS:
		wall_pick.add_item(MAP_LAYOUT.WALLS[key]["label"])
		wall_pick.set_item_metadata(wall_pick.item_count - 1, key)
	wall_pick.item_selected.connect(func(index: int): wall_style = wall_pick.get_item_metadata(index))
	left_box.add_child(wall_pick)
	road_pick = OptionButton.new()
	for key in MAP_LAYOUT.ROADS:
		road_pick.add_item(MAP_LAYOUT.ROADS[key]["label"])
		road_pick.set_item_metadata(road_pick.item_count - 1, key)
	road_pick.item_selected.connect(func(index: int): road_type = road_pick.get_item_metadata(index))
	left_box.add_child(road_pick)
	var road_row := HBoxContainer.new()
	left_box.add_child(road_row)
	var width_label := Label.new()
	width_label.text = "Road width"
	road_row.add_child(width_label)
	width_spin = SpinBox.new()
	width_spin.min_value = 3.0
	width_spin.max_value = 16.0
	width_spin.step = 1.0
	width_spin.value = 6.0
	width_spin.value_changed.connect(func(value: float): road_width = value)
	road_row.add_child(width_spin)
	walk_check = CheckBox.new()
	walk_check.text = "Sidewalks"
	walk_check.button_pressed = true
	walk_check.toggled.connect(func(on: bool): road_walk = on)
	left_box.add_child(walk_check)
	left_box.add_child(HSeparator.new())
	category_pick = OptionButton.new()
	for category in CATEGORIES:
		category_pick.add_item(category)
	category_pick.item_selected.connect(fill_palette)
	left_box.add_child(category_pick)
	palette_list = ItemList.new()
	palette_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_list.item_selected.connect(func(index: int):
		place_id = palette_list.get_item_metadata(index)
		set_tool("place"))
	left_box.add_child(palette_list)
	fill_palette(0)
	# right panel
	var right := PanelContainer.new()
	root.add_child(right)
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_top = 44
	right.offset_left = -230
	right.offset_bottom = -30
	props_box = VBoxContainer.new()
	right.add_child(props_box)
	prop_title = Label.new()
	prop_title.text = "Nothing selected"
	prop_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	props_box.add_child(prop_title)
	for entry in [["x", "X", -HALF, HALF, 0.25], ["z", "Z", -HALF, HALF, 0.25], ["y", "Height", 0.0, 12.0, 0.05], ["r", "Rotation", -360.0, 360.0, 1.0], ["s", "Scale", 0.3, 3.0, 0.05]]:
		var row := HBoxContainer.new()
		props_box.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 64
		row.add_child(label)
		var field := SpinBox.new()
		field.min_value = entry[2]
		field.max_value = entry[3]
		field.step = entry[4]
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.value_changed.connect(func(value: float): property_changed(entry[0], value))
		row.add_child(field)
		spin[entry[0]] = [row, field]
	style_pick = OptionButton.new()
	style_pick.item_selected.connect(func(index: int): property_changed("t", style_pick.get_item_metadata(index)))
	props_box.add_child(style_pick)
	closed_check = CheckBox.new()
	closed_check.text = "Closed loop"
	closed_check.toggled.connect(func(on: bool): property_changed("closed", on))
	props_box.add_child(closed_check)
	var buttons := HFlowContainer.new()
	props_box.add_child(buttons)
	add_button(buttons, "Delete", delete_selection)
	add_button(buttons, "Duplicate", duplicate_selection)
	add_button(buttons, "Drop to ground", func(): property_changed("y", 0.0))
	add_button(buttons, "Select all", func():
		selection.clear()
		for index in range(entities.size()):
			selection.append(index)
		selection_changed())
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	props_box.add_child(info)
	right.offset_bottom = -(30 + 236)
	build_mini(root)
	# status line
	var bottom := PanelContainer.new()
	root.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	status = Label.new()
	bottom.add_child(status)
	confirm = ConfirmationDialog.new()
	confirm.confirmed.connect(func():
		if pending_confirm.is_valid():
			pending_confirm.call())
	add_child(confirm)
	selection_changed()

func build_mini(root: Control) -> void:
	mini_panel = PanelContainer.new()
	root.add_child(mini_panel)
	mini_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	mini_panel.offset_left = -230
	mini_panel.offset_top = -234
	mini_panel.offset_bottom = -30
	var column := VBoxContainer.new()
	mini_panel.add_child(column)
	mini_label = Label.new()
	column.add_child(mini_label)
	mini_container = SubViewportContainer.new()
	mini_container.stretch = true
	mini_container.custom_minimum_size = Vector2(218, 164)
	mini_container.gui_input.connect(mini_input)
	column.add_child(mini_container)
	mini_viewport = SubViewport.new()
	mini_viewport.world_3d = get_viewport().world_3d # the same map, seen by a second camera
	mini_viewport.size = Vector2i(218, 164)
	mini_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mini_container.add_child(mini_viewport)
	mini_camera = Camera3D.new()
	mini_camera.far = 500.0
	mini_camera.cull_mask = 3
	mini_viewport.add_child(mini_camera)

func mini_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var factor := 0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1
			if top_down:
				mini_distance = clampf(mini_distance * factor, 12.0, 120.0)
			else:
				mini_zoom = clampf(mini_zoom * factor, 20.0, 130.0)
		elif event.button_index == MOUSE_BUTTON_LEFT and not top_down:
			mini_jump(event.position)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		if top_down: # drag to orbit the 3D preview
			mini_yaw -= event.relative.x * 0.012
			mini_elevation = clampf(mini_elevation + event.relative.y * 0.01, 0.15, 1.5)
		else: # drag across the map to move the flying camera
			mini_jump(event.position)

# Click or drag on the mini map to move the free-fly camera over that spot.
func mini_jump(local: Vector2) -> void:
	var size := mini_container.size
	var spot := Vector2(camera.position.x, camera.position.z) + (local - size / 2.0) / size.y * mini_zoom
	camera.position.x = clampf(spot.x, -HALF, HALF)
	camera.position.z = clampf(spot.y, -HALF, HALF)

func update_mini() -> void:
	if mini_camera == null:
		return
	mini_panel.visible = mini_check.button_pressed
	if not mini_panel.visible:
		cam_marker.visible = false
		return
	if top_down:
		mini_label.text = "3D preview (drag to orbit)"
		var target := Vector3(focus.x, 0.0, focus.y)
		var offset := Vector3(sin(mini_yaw) * cos(mini_elevation), sin(mini_elevation), cos(mini_yaw) * cos(mini_elevation)) * mini_distance
		mini_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		mini_camera.fov = 60.0
		mini_camera.position = target + offset
		mini_camera.look_at(target)
		cam_marker.visible = false
	else:
		mini_label.text = "Top-down map (click to move)"
		mini_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		mini_camera.size = mini_zoom
		mini_camera.position = Vector3(camera.position.x, 120.0, camera.position.z)
		mini_camera.rotation = Vector3(-PI / 2.0, 0, 0)
		cam_marker.visible = true
		cam_marker.position = Vector3(camera.position.x, 60.0, camera.position.z)
		cam_marker.rotation = Vector3(0, fly_yaw, 0)

func add_button(parent: Control, text: String, action: Callable, tip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func ask(question: String, action: Callable) -> void:
	confirm.dialog_text = question
	pending_confirm = action
	confirm.popup_centered()

func set_status(text: String) -> void:
	if status != null:
		status.text = text

func fill_palette(index: int) -> void:
	palette_list.clear()
	var category: String = category_pick.get_item_text(index)
	for id in CATEGORIES[category]:
		palette_list.add_item(STREET_PROPS.label_of(id)[0])
		palette_list.set_item_metadata(palette_list.item_count - 1, id)

# --- tools -----------------------------------------------------------------------------------

func set_tool(name: String) -> void:
	finish_draft(false)
	tool = name
	for key in tool_buttons:
		tool_buttons[key].button_pressed = key == name
	wall_pick.visible = name == "wall"
	road_pick.visible = name == "road" or name == "intersection"
	width_spin.get_parent().visible = name == "road" or name == "intersection"
	walk_check.visible = name == "road" or name == "intersection"
	if name != "place":
		palette_list.deselect_all()
		clear_ghost()
	else:
		rebuild_ghost()
	match name:
		"select": set_status("Click to select, drag to move. Alt+click a wall/road segment adds a point; Ctrl+click a point removes it.")
		"wall": set_status("Click to add wall points (they snap to other walls so corners connect). Enter / right-click to finish. Click the first point to close a loop.")
		"road": set_status("Click to lay road points. Enter / right-click to finish. Roads that touch get crosswalks automatically.")
		"intersection": set_status("Click to drop a 4-way intersection (two crossing roads using the road settings).")
		"place": set_status("Click to place. Q/E rotate, PageUp/PageDown height, right-click or Esc to stop.")

func clear_ghost() -> void:
	for child in ghost_root.get_children():
		child.queue_free()

func rebuild_ghost() -> void:
	clear_ghost()
	if place_id == "":
		return
	var node := STREET_PROPS.new().place(ghost_root, place_id, Vector2.ZERO, 0.0)
	if node == null:
		return
	for child in node.find_children("*", "CollisionObject3D", true, false):
		child.collision_layer = 0
		child.collision_mask = 0
	for child in node.find_children("*", "GeometryInstance3D", true, false):
		child.transparency = 0.45
	node.remove_from_group("keep_out")
	node.set_meta("ghost", true)

# --- camera ----------------------------------------------------------------------------------

func toggle_view() -> void:
	top_down = not top_down
	if not top_down:
		camera.position = Vector3(focus.x, 22.0, focus.y + 22.0)
		fly_yaw = 0.0
		fly_pitch = -0.6
	else:
		focus = (Vector2(camera.position.x, camera.position.z) + Vector2(0, -22.0)).clamp(Vector2(-HALF, -HALF), Vector2(HALF, HALF))
	view_button.text = "Top-down" if top_down else "Free-fly 3D"
	apply_camera()

func apply_camera() -> void:
	if top_down:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = zoom
		camera.position = Vector3(focus.x, 120.0, focus.y)
		camera.rotation = Vector3(-PI / 2.0, 0, 0)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 70.0
		camera.rotation = Vector3(fly_pitch, fly_yaw, 0)

func make_current() -> void:
	camera.make_current()

func _process(delta: float) -> void:
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var typing := get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is SpinBox
	var fast := 2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if not typing and move != Vector2.ZERO and not Input.is_key_pressed(KEY_CTRL):
		if top_down:
			focus += move * zoom * 0.7 * fast * delta
			focus = focus.clamp(Vector2(-HALF, -HALF), Vector2(HALF, HALF))
		else:
			var basis := camera.global_transform.basis
			var heading := Vector3(basis.x.x, 0, basis.x.z).normalized() * move.x + Vector3(basis.z.x, 0, basis.z.z).normalized() * move.y
			var lift := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_C))
			camera.position += (heading + Vector3.UP * lift) * 14.0 * fast * delta
	elif not typing and not top_down:
		var lift_only := float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_C))
		camera.position.y += lift_only * 14.0 * fast * delta
	apply_camera()
	update_cursor()
	update_ghost()
	draw_overlay()
	update_mini()

func ground_point(screen: Vector2, level: float) -> Variant:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	return Plane(Vector3.UP, level).intersects_ray(origin, direction)

func update_cursor() -> void:
	var mouse := get_viewport().get_mouse_position()
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var hit = ground_point(mouse, 0.0)
	cursor_valid = hit != null and not over_ui and not looking
	if hit != null:
		cursor = Vector2(hit.x, hit.z)

# --- snapping and stacking -------------------------------------------------------------------

func snap_value(point: Vector2) -> Vector2:
	if not snap_on:
		return point
	return Vector2(snappedf(point.x, snap_size), snappedf(point.y, snap_size))

# Snap to an existing wall/road point when close (so lines connect), otherwise to the grid.
func snap_vertex(point: Vector2, skip_entity := -1, skip_vertex := -1) -> Vector2:
	var best := point
	var best_distance := 1.0
	for index in range(entities.size()):
		var entity: Dictionary = entities[index]
		if entity.get("k", "") == "prop":
			continue
		var points := MAP_LAYOUT.points_of(entity)
		for vertex in range(points.size()):
			if index == skip_entity and vertex == skip_vertex:
				continue
			var distance := points[vertex].distance_to(point)
			if distance < best_distance:
				best_distance = distance
				best = points[vertex]
	if best != point:
		return best
	return snap_value(point)

func surface_height(at: Vector2, exclude: Array) -> float:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, 40.0, at.y), Vector3(at.x, -1.0, at.y))
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return maxf(0.0, snappedf(hit["position"].y, 0.05))

func bodies_of(nodes: Array) -> Array:
	var found := []
	for node in nodes:
		if not is_instance_valid(node):
			continue
		if node is CollisionObject3D:
			found.append(node.get_rid())
		for child in node.find_children("*", "CollisionObject3D", true, false):
			found.append(child.get_rid())
	return found

func update_ghost() -> void:
	if ghost_root.get_child_count() == 0:
		return
	var ghost := ghost_root.get_child(0) as Node3D
	ghost.visible = tool == "place" and cursor_valid
	if not ghost.visible:
		return
	var at := snap_value(cursor)
	var height := surface_height(at, bodies_of([ghost])) if stack_on else 0.0
	ghost.position = Vector3(at.x, height, at.y)
	ghost.rotation.y = deg_to_rad(place_rot)

# --- overlay (selection, drafts, handles) ----------------------------------------------------

func entity_bounds(index: int) -> AABB:
	var entity: Dictionary = entities[index]
	if entity.get("k", "prop") != "prop":
		var points := MAP_LAYOUT.points_of(entity)
		var base := float(entity.get("y", 0.0))
		var box := AABB(Vector3(points[0].x, base, points[0].y), Vector3.ZERO)
		for point in points:
			box = box.expand(Vector3(point.x, base, point.y))
		var extra := float(entity.get("w", 1.0)) * 0.5 if entity["k"] == "road" else 0.6
		return box.grow(extra).expand(Vector3(box.position.x, base + 1.0, box.position.z))
	var nodes: Array = built[index]
	var result := AABB()
	var first := true
	for node in nodes:
		if not is_instance_valid(node) or not node is Node3D:
			continue
		for mesh in node.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = (mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
			result = box if first else result.merge(box)
			first = false
	if first:
		result = AABB(Vector3(entity["x"] - 0.5, entity["y"], entity["z"] - 0.5), Vector3(1, 1, 1))
	return result

func line_box(box: AABB, color: Color) -> void:
	var corners := []
	for index in range(8):
		corners.append(box.position + Vector3(box.size.x * (index & 1), box.size.y * ((index >> 1) & 1), box.size.z * ((index >> 2) & 1)))
	for pair in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		overlay.surface_set_color(color)
		overlay.surface_add_vertex(corners[pair[0]])
		overlay.surface_set_color(color)
		overlay.surface_add_vertex(corners[pair[1]])

func line_between(a: Vector3, b: Vector3, color: Color) -> void:
	overlay.surface_set_color(color)
	overlay.surface_add_vertex(a)
	overlay.surface_set_color(color)
	overlay.surface_add_vertex(b)

func handle_size() -> float:
	return zoom * 0.012 if top_down else camera.global_position.distance_to(Vector3(cursor.x, 0, cursor.y)) * 0.02

func draw_overlay() -> void:
	overlay.clear_surfaces()
	overlay.surface_begin(Mesh.PRIMITIVE_LINES)
	var any := false
	var size := handle_size()
	for index in selection:
		if index >= entities.size():
			continue
		var entity: Dictionary = entities[index]
		line_box(entity_bounds(index), Color("#ffd24a"))
		any = true
		if entity.get("k", "prop") != "prop":
			for point in MAP_LAYOUT.points_of(entity):
				var base := float(entity.get("y", 0.0)) + 0.1
				line_between(Vector3(point.x - size, base, point.y), Vector3(point.x + size, base, point.y), Color("#4ae0ff"))
				line_between(Vector3(point.x, base, point.y - size), Vector3(point.x, base, point.y + size), Color("#4ae0ff"))
				line_between(Vector3(point.x - size, base, point.y - size), Vector3(point.x + size, base, point.y + size), Color("#4ae0ff"))
				line_between(Vector3(point.x - size, base, point.y + size), Vector3(point.x + size, base, point.y - size), Color("#4ae0ff"))
	if (tool == "wall" or tool == "road") and not draft.is_empty():
		var half := road_width * 0.5 if tool == "road" else 0.15
		var previous := draft[0]
		var points := draft.duplicate()
		if cursor_valid:
			points.append(snap_vertex(cursor))
		for point_index in range(points.size()):
			var point: Vector2 = points[point_index]
			line_between(Vector3(point.x - size, 0.2, point.y), Vector3(point.x + size, 0.2, point.y), Color("#7dff6a"))
			line_between(Vector3(point.x, 0.2, point.y - size), Vector3(point.x, 0.2, point.y + size), Color("#7dff6a"))
			if point_index > 0:
				var from: Vector2 = points[point_index - 1]
				line_between(Vector3(from.x, 0.2, from.y), Vector3(point.x, 0.2, point.y), Color("#7dff6a"))
				var direction := (point - from).normalized()
				var side := Vector2(-direction.y, direction.x) * half
				for sign_value in [-1.0, 1.0]:
					var shift: Vector2 = side * sign_value
					line_between(Vector3(from.x + shift.x, 0.2, from.y + shift.y), Vector3(point.x + shift.x, 0.2, point.y + shift.y), Color(0.49, 1.0, 0.42, 0.5))
			previous = point
		any = true
	elif cursor_valid and (tool == "wall" or tool == "road" or tool == "intersection"):
		var spot := snap_vertex(cursor)
		line_between(Vector3(spot.x - size, 0.2, spot.y), Vector3(spot.x + size, 0.2, spot.y), Color("#7dff6a"))
		line_between(Vector3(spot.x, 0.2, spot.y - size), Vector3(spot.x, 0.2, spot.y + size), Color("#7dff6a"))
		any = true
	if not any:
		line_between(Vector3.ZERO, Vector3.ZERO, Color(0, 0, 0, 0))
	overlay.surface_end()

# --- entities --------------------------------------------------------------------------------

func current_layout() -> Dictionary:
	return {"version": 2, "objects": entities.duplicate(true)}

func rebuild_all() -> void:
	for child in layout_root.get_children():
		layout_root.remove_child(child)
		child.queue_free()
	built = layout_builder.build(layout_root, {"objects": entities})
	selection.assign(selection.filter(func(index: int): return index < entities.size()))
	selection_changed()

func rebuild_entity(index: int) -> void:
	for node in built[index]:
		if is_instance_valid(node):
			layout_root.remove_child(node)
			node.queue_free()
	built[index] = layout_builder.build_entity(layout_root, entities[index], entities, index)

func checkpoint() -> void:
	undo_stack.append(JSON.stringify(entities))
	if undo_stack.size() > 120:
		undo_stack.pop_front()
	redo_stack.clear()
	dirty = true

func restore(snapshot: String) -> void:
	var parsed = JSON.parse_string(snapshot)
	entities = parsed if parsed is Array else []
	rebuild_all()

func undo() -> void:
	if undo_stack.is_empty():
		return
	redo_stack.append(JSON.stringify(entities))
	restore(undo_stack.pop_back())
	dirty = true

func redo() -> void:
	if redo_stack.is_empty():
		return
	undo_stack.append(JSON.stringify(entities))
	restore(redo_stack.pop_back())
	dirty = true

func add_entity(entity: Dictionary) -> int:
	entities.append(entity)
	built.append(layout_builder.build_entity(layout_root, entity, entities, entities.size() - 1))
	return entities.size() - 1

func new_map() -> void:
	checkpoint()
	entities.clear()
	selection.clear()
	loaded_title = ""
	name_edit.text = ""
	rebuild_all()

func load_layout(layout: Dictionary, title: String) -> void:
	entities = MAP_LAYOUT.from_legacy(layout)["objects"]
	undo_stack.clear()
	redo_stack.clear()
	selection.clear()
	loaded_title = title
	name_edit.text = title
	dirty = false
	rebuild_all()
	set_status("Opened \"%s\" (%d objects)." % [title, entities.size()])

func refresh_open_menu() -> void:
	var popup := open_menu.get_popup()
	popup.clear()
	var names := saved_maps.keys()
	names.sort()
	for index in range(names.size()):
		popup.add_item(String(names[index]), index)
	if names.is_empty():
		popup.add_item("(no saved maps yet)", 0)
		popup.set_item_disabled(0, true)

func open_from_menu(id: int) -> void:
	var names := saved_maps.keys()
	names.sort()
	if id < names.size():
		var title := String(names[id])
		load_layout(saved_maps[title], title)

func save_map() -> void:
	var title := name_edit.text.strip_edges()
	if title.is_empty():
		set_status("Type a map name first.")
		return
	var replacing := saved_maps.has(title)
	var layout := current_layout()
	saved_maps[title] = layout
	loaded_title = title
	dirty = false
	map_saved.emit(title, layout)
	set_status("%s \"%s\" (%d objects)." % ["Replaced" if replacing else "Saved", title, entities.size()])

func delete_map() -> void:
	var title := name_edit.text.strip_edges()
	if not saved_maps.has(title):
		set_status("That name is not a saved map.")
		return
	ask("Delete the saved map \"%s\" for good?" % title, func():
		saved_maps.erase(title)
		map_deleted.emit(title)
		set_status("Deleted \"%s\"." % title))

# --- selection and properties ----------------------------------------------------------------

func selection_changed() -> void:
	if props_box == null:
		return
	suppress_ui = true
	var has := not selection.is_empty()
	for key in spin:
		spin[key][0].visible = false
	style_pick.visible = false
	closed_check.visible = false
	if not has:
		prop_title.text = "Nothing selected"
	else:
		var entity: Dictionary = entities[selection[0]]
		var kind := String(entity.get("k", "prop"))
		var extra := "" if selection.size() == 1 else "  (+%d more)" % (selection.size() - 1)
		if kind == "prop":
			prop_title.text = STREET_PROPS.label_of(String(entity["id"]))[0] + extra
			for key in ["x", "z", "y", "r", "s"]:
				spin[key][0].visible = true
				spin[key][1].value = float(entity.get(key, 1.0 if key == "s" else 0.0))
		elif kind == "wall":
			prop_title.text = "Wall (%d points)%s" % [entity["p"].size(), extra]
			spin["y"][0].visible = true
			spin["y"][1].value = float(entity.get("y", 0.0))
			style_pick.visible = true
			style_pick.clear()
			for key in MAP_LAYOUT.WALLS:
				style_pick.add_item(MAP_LAYOUT.WALLS[key]["label"])
				style_pick.set_item_metadata(style_pick.item_count - 1, key)
				if key == entity.get("t", "brick_low"):
					style_pick.select(style_pick.item_count - 1)
			closed_check.visible = true
			closed_check.button_pressed = bool(entity.get("closed", false))
		else:
			prop_title.text = "Road (%d points)%s" % [entity["p"].size(), extra]
			spin["s"][0].visible = true
			spin["s"][1].min_value = 3.0
			spin["s"][1].max_value = 16.0
			spin["s"][1].value = float(entity.get("w", 6.0))
			closed_check.visible = true
			closed_check.text = "Sidewalks"
			closed_check.button_pressed = bool(entity.get("walk", true))
	if not has or entities[selection[0]].get("k", "prop") != "road":
		spin["s"][1].min_value = 0.3
		spin["s"][1].max_value = 3.0
		closed_check.text = "Closed loop"
	info.text = "%d objects on the map" % entities.size()
	suppress_ui = false

func property_changed(key: String, value) -> void:
	if suppress_ui or selection.is_empty():
		return
	checkpoint()
	for index in selection:
		var entity: Dictionary = entities[index]
		var kind := String(entity.get("k", "prop"))
		if kind == "road" and key == "s":
			entity["w"] = value
		elif kind == "road" and key == "closed":
			entity["walk"] = value
		elif key in ["x", "z"] and selection.size() > 1:
			continue
		else:
			entity[key] = value
		if kind == "prop":
			apply_prop(index)
		else:
			rebuild_entity(index)

func apply_prop(index: int) -> void:
	var entity: Dictionary = entities[index]
	var nodes: Array = built[index]
	if nodes.is_empty() or not is_instance_valid(nodes[0]):
		return
	var root := nodes[0] as Node3D
	root.position = Vector3(entity["x"], entity["y"], entity["z"])
	root.rotation.y = deg_to_rad(float(entity["r"]))
	var scl := float(entity["s"])
	var old_scale := root.scale.x
	root.scale = Vector3.ONE * scl
	if root.has_meta("keep_radius") and old_scale != 0.0:
		root.set_meta("keep_radius", float(root.get_meta("keep_radius")) * scl / old_scale)

func delete_selection() -> void:
	if selection.is_empty():
		return
	checkpoint()
	var doomed := selection.duplicate()
	doomed.sort()
	doomed.reverse()
	for index in doomed:
		for node in built[index]:
			if is_instance_valid(node):
				layout_root.remove_child(node)
				node.queue_free()
		entities.remove_at(index)
		built.remove_at(index)
	selection.clear()
	rebuild_all()

func copy_selection() -> void:
	clipboard.clear()
	for index in selection:
		clipboard.append(entities[index].duplicate(true))
	set_status("Copied %d object(s)." % clipboard.size())

func entity_centre(entity: Dictionary) -> Vector2:
	if entity.get("k", "prop") == "prop":
		return Vector2(entity["x"], entity["z"])
	var points := MAP_LAYOUT.points_of(entity)
	var total := Vector2.ZERO
	for point in points:
		total += point
	return total / maxf(points.size(), 1.0)

func shift_entity(entity: Dictionary, offset: Vector2) -> void:
	if entity.get("k", "prop") == "prop":
		entity["x"] = float(entity["x"]) + offset.x
		entity["z"] = float(entity["z"]) + offset.y
	else:
		for point in entity["p"]:
			point[0] = float(point[0]) + offset.x
			point[1] = float(point[1]) + offset.y

func paste(at: Vector2, snap_it := true) -> void:
	if clipboard.is_empty():
		return
	checkpoint()
	var centre := Vector2.ZERO
	for entity in clipboard:
		centre += entity_centre(entity)
	centre /= clipboard.size()
	var offset := (snap_value(at) if snap_it else at) - centre
	selection.clear()
	for entity in clipboard:
		var copy: Dictionary = entity.duplicate(true)
		shift_entity(copy, offset)
		selection.append(add_entity(copy))
	selection_changed()

func duplicate_selection() -> void:
	copy_selection()
	if clipboard.is_empty():
		return
	var centre := Vector2.ZERO
	for entity in clipboard:
		centre += entity_centre(entity)
	paste(centre / clipboard.size() + Vector2(snap_size * 2.0 + 1.0, snap_size * 2.0 + 1.0), false)

func rotate_selection(degrees: float) -> void:
	if tool == "place":
		place_rot = fmod(place_rot + degrees, 360.0)
		return
	if selection.is_empty():
		return
	checkpoint()
	for index in selection:
		var entity: Dictionary = entities[index]
		if entity.get("k", "prop") == "prop":
			entity["r"] = fmod(float(entity["r"]) + degrees, 360.0)
			apply_prop(index)
		else:
			var centre := entity_centre(entity)
			for point in entity["p"]:
				var turned := (Vector2(point[0], point[1]) - centre).rotated(deg_to_rad(degrees)) + centre
				point[0] = snappedf(turned.x, 0.05)
				point[1] = snappedf(turned.y, 0.05)
			rebuild_entity(index)
	selection_changed()

func nudge_selection(offset: Vector2) -> void:
	if selection.is_empty():
		return
	checkpoint()
	for index in selection:
		shift_entity(entities[index], offset)
		if entities[index].get("k", "prop") == "prop":
			apply_prop(index)
		else:
			rebuild_entity(index)
	selection_changed()

func change_height(amount: float) -> void:
	if tool == "place" or selection.is_empty():
		return
	checkpoint()
	for index in selection:
		entities[index]["y"] = clampf(float(entities[index].get("y", 0.0)) + amount, 0.0, 12.0)
		if entities[index].get("k", "prop") == "prop":
			apply_prop(index)
		else:
			rebuild_entity(index)
	selection_changed()

func change_scale(factor: float) -> void:
	if selection.is_empty():
		return
	checkpoint()
	for index in selection:
		if entities[index].get("k", "prop") == "prop":
			entities[index]["s"] = clampf(float(entities[index]["s"]) * factor, 0.3, 3.0)
			apply_prop(index)
	selection_changed()

# --- picking ---------------------------------------------------------------------------------

func distance_to_polyline(point: Vector2, points: Array[Vector2]) -> float:
	var best := INF
	for index in range(points.size() - 1):
		best = minf(best, Geometry2D.get_closest_point_to_segment(point, points[index], points[index + 1]).distance_to(point))
	return best

func pick(screen: Vector2) -> int:
	var origin := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var best := -1
	var best_score := INF
	var wall_plane = Plane(Vector3.UP, 0.5).intersects_ray(origin, direction)
	var road_plane = Plane(Vector3.UP, 0.02).intersects_ray(origin, direction)
	for index in range(entities.size()):
		var entity: Dictionary = entities[index]
		var kind := String(entity.get("k", "prop"))
		var score := INF
		if kind == "prop":
			var hit = entity_bounds(index).intersects_ray(origin, direction)
			if hit != null:
				score = origin.distance_to(hit)
		elif kind == "wall" and wall_plane != null:
			var style: Dictionary = MAP_LAYOUT.WALLS.get(String(entity.get("t", "brick_low")), MAP_LAYOUT.WALLS["brick_low"])
			var points := MAP_LAYOUT.points_of(entity)
			if bool(entity.get("closed", false)) and points.size() > 2:
				points.append(points[0])
			if distance_to_polyline(Vector2(wall_plane.x, wall_plane.z), points) < float(style["t"]) * 0.5 + 0.45:
				score = origin.distance_to(wall_plane)
		elif kind == "road" and road_plane != null:
			var reach := float(entity.get("w", 6.0)) * 0.5
			if distance_to_polyline(Vector2(road_plane.x, road_plane.z), MAP_LAYOUT.points_of(entity)) < reach:
				score = 1000.0 + origin.distance_to(road_plane)
		if score < best_score:
			best_score = score
			best = index
	return best

func handle_at(screen: Vector2) -> Array:
	for index in selection:
		var entity: Dictionary = entities[index]
		if entity.get("k", "prop") == "prop":
			continue
		var points := MAP_LAYOUT.points_of(entity)
		for vertex in range(points.size()):
			var world := Vector3(points[vertex].x, float(entity.get("y", 0.0)), points[vertex].y)
			if camera.is_position_behind(world):
				continue
			if camera.unproject_position(world).distance_to(screen) < 13.0:
				return [index, vertex]
	return []

func segment_at(screen: Vector2) -> Array:
	var hit = ground_point(screen, 0.3)
	if hit == null:
		return []
	var point := Vector2(hit.x, hit.z)
	for index in selection:
		var entity: Dictionary = entities[index]
		if entity.get("k", "prop") == "prop":
			continue
		var points := MAP_LAYOUT.points_of(entity)
		for vertex in range(points.size() - 1):
			var closest := Geometry2D.get_closest_point_to_segment(point, points[vertex], points[vertex + 1])
			if closest.distance_to(point) < 1.2:
				return [index, vertex, closest]
	return []

# --- input -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		handle_key(event)

func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		if event.pressed:
			var factor := 0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.14
			if top_down:
				zoom = clampf(zoom * factor, 10.0, 130.0)
			else:
				camera.position += -camera.global_transform.basis.z * (4.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -4.0)
		return
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		panning = event.pressed
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if tool == "wall" or tool == "road":
				if draft.size() >= 2:
					finish_draft(true)
				else:
					finish_draft(false)
					set_tool("select")
			elif tool == "place" or tool == "intersection":
				set_tool("select")
			elif not top_down:
				looking = true
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif looking:
			looking = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		end_drag()
		return
	get_viewport().gui_release_focus()
	var mouse := event.position
	match tool:
		"select": begin_select(mouse, event)
		"place": place_here()
		"wall", "road": add_draft_point(mouse)
		"intersection": drop_intersection()

func handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if looking:
		fly_yaw -= event.relative.x * 0.003
		fly_pitch = clampf(fly_pitch - event.relative.y * 0.003, -1.5, 1.5)
		return
	if panning:
		if top_down:
			var per_pixel := zoom / get_viewport().get_visible_rect().size.y
			focus -= Vector2(event.relative.x, event.relative.y) * per_pixel
			focus = focus.clamp(Vector2(-HALF, -HALF), Vector2(HALF, HALF))
		else:
			camera.position -= camera.global_transform.basis.x * event.relative.x * 0.05 - camera.global_transform.basis.y * event.relative.y * 0.05
		return
	if not drag.is_empty():
		update_drag(event.position)

func handle_key(event: InputEventKey) -> void:
	var ctrl := event.ctrl_pressed or event.meta_pressed
	match event.keycode:
		KEY_1: set_tool("select")
		KEY_2: set_tool("wall")
		KEY_3: set_tool("road")
		KEY_4: set_tool("intersection")
		KEY_TAB: toggle_view()
		KEY_G: snap_check.button_pressed = not snap_on
		KEY_ESCAPE:
			if not draft.is_empty():
				finish_draft(false)
			elif tool != "select":
				set_tool("select")
			else:
				selection.clear()
				selection_changed()
		KEY_ENTER, KEY_KP_ENTER: finish_draft(true)
		KEY_DELETE, KEY_BACKSPACE: delete_selection()
		KEY_Q: rotate_selection(-90.0 if event.shift_pressed else -15.0)
		KEY_E: rotate_selection(90.0 if event.shift_pressed else 15.0)
		KEY_PAGEUP: change_height(0.25)
		KEY_PAGEDOWN: change_height(-0.25)
		KEY_BRACKETLEFT: change_scale(0.9)
		KEY_BRACKETRIGHT: change_scale(1.1)
		KEY_LEFT: nudge_selection(Vector2(-snap_size, 0))
		KEY_RIGHT: nudge_selection(Vector2(snap_size, 0))
		KEY_UP: nudge_selection(Vector2(0, -snap_size))
		KEY_DOWN: nudge_selection(Vector2(0, snap_size))
		KEY_Z:
			if ctrl:
				redo() if event.shift_pressed else undo()
		KEY_Y:
			if ctrl:
				redo()
		KEY_C:
			if ctrl:
				copy_selection()
		KEY_V:
			if ctrl:
				paste(cursor if cursor_valid else Vector2.ZERO)
		KEY_D:
			if ctrl:
				duplicate_selection()
		KEY_S:
			if ctrl:
				save_map()
		KEY_A:
			if ctrl:
				selection.clear()
				for index in range(entities.size()):
					selection.append(index)
				selection_changed()

# --- select / drag ---------------------------------------------------------------------------

func begin_select(mouse: Vector2, event: InputEventMouseButton) -> void:
	var handle := handle_at(mouse)
	if not handle.is_empty():
		if event.ctrl_pressed:
			var entity: Dictionary = entities[handle[0]]
			if entity["p"].size() > 2:
				checkpoint()
				entity["p"].remove_at(handle[1])
				rebuild_entity(handle[0])
			return
		checkpoint()
		drag = {"kind": "vertex", "entity": handle[0], "vertex": handle[1], "moved": false}
		return
	if event.alt_pressed:
		var segment := segment_at(mouse)
		if not segment.is_empty():
			checkpoint()
			var entity: Dictionary = entities[segment[0]]
			var spot: Vector2 = snap_value(segment[2])
			entity["p"].insert(segment[1] + 1, [spot.x, spot.y])
			rebuild_entity(segment[0])
			drag = {"kind": "vertex", "entity": segment[0], "vertex": segment[1] + 1, "moved": false}
			return
	var hit := pick(mouse)
	if hit < 0:
		if not event.shift_pressed:
			selection.clear()
			selection_changed()
		return
	if event.shift_pressed:
		if selection.has(hit):
			selection.erase(hit)
		else:
			selection.append(hit)
	elif not selection.has(hit):
		selection = [hit]
	selection_changed()
	var level := float(entities[hit].get("y", 0.0))
	var start = ground_point(mouse, level)
	if start == null:
		return
	checkpoint()
	var originals := {}
	for index in selection:
		var entity: Dictionary = entities[index]
		originals[index] = entity.duplicate(true)
	drag = {"kind": "move", "start": Vector2(start.x, start.z), "level": level, "orig": originals, "moved": false}

func update_drag(mouse: Vector2) -> void:
	if drag["kind"] == "vertex":
		var entity: Dictionary = entities[drag["entity"]]
		var hit = ground_point(mouse, float(entity.get("y", 0.0)))
		if hit == null:
			return
		var spot := snap_vertex(Vector2(hit.x, hit.z), drag["entity"], drag["vertex"])
		entity["p"][drag["vertex"]] = [spot.x, spot.y]
		drag["moved"] = true
		rebuild_entity(drag["entity"])
		return
	var hit = ground_point(mouse, drag["level"])
	if hit == null:
		return
	var delta := Vector2(hit.x, hit.z) - Vector2(drag["start"])
	var originals: Dictionary = drag["orig"]
	var first_index: int = originals.keys()[0]
	var anchor := entity_centre(originals[first_index])
	var target := snap_value(anchor + delta)
	var offset := target - anchor
	if offset == Vector2.ZERO and not drag["moved"]:
		return
	drag["moved"] = true
	for index in originals:
		var entity: Dictionary = entities[index]
		var original: Dictionary = originals[index]
		if entity.get("k", "prop") == "prop":
			entity["x"] = float(original["x"]) + offset.x
			entity["z"] = float(original["z"]) + offset.y
			if stack_on and originals.size() == 1:
				entity["y"] = surface_height(Vector2(entity["x"], entity["z"]), bodies_of(built[index]))
			apply_prop(index)
		else:
			for point_index in range(entity["p"].size()):
				entity["p"][point_index] = [float(original["p"][point_index][0]) + offset.x, float(original["p"][point_index][1]) + offset.y]
			rebuild_entity(index)
	selection_changed()

func end_drag() -> void:
	if drag.is_empty():
		return
	if not drag["moved"] and not undo_stack.is_empty():
		undo_stack.pop_back()
	drag = {}

# --- placing / drawing -----------------------------------------------------------------------

func place_here() -> void:
	if place_id == "" or not cursor_valid:
		return
	checkpoint()
	var at := snap_value(cursor)
	var height := 0.0
	if stack_on and ghost_root.get_child_count() > 0:
		height = surface_height(at, bodies_of([ghost_root.get_child(0)]))
	var index := add_entity({"k": "prop", "id": place_id, "x": at.x, "y": height, "z": at.y, "r": place_rot, "s": 1.0})
	selection = [index]
	selection_changed()

func add_draft_point(mouse: Vector2) -> void:
	var hit = ground_point(mouse, 0.0)
	if hit == null:
		return
	var spot := snap_vertex(Vector2(hit.x, hit.z))
	spot = spot.clamp(Vector2(-HALF, -HALF), Vector2(HALF, HALF))
	if tool == "wall" and draft.size() >= 3 and spot.distance_to(draft[0]) < 0.6:
		finish_draft(true, true)
		return
	if not draft.is_empty() and spot.distance_to(draft[-1]) < 0.05:
		return
	draft.append(spot)

func finish_draft(commit: bool, closed := false) -> void:
	if commit and draft.size() >= 2:
		checkpoint()
		var points := []
		for point in draft:
			points.append([point.x, point.y])
		var entity := {}
		if tool == "wall":
			entity = {"k": "wall", "t": wall_style, "p": points, "y": 0.0, "closed": closed}
		else:
			entity = {"k": "road", "t": road_type, "w": road_width, "p": points, "walk": road_walk}
		var index := add_entity(entity)
		if tool == "road":
			for other in range(entities.size() - 1): # roads that now meet this one need new crosswalks
				if entities[other].get("k", "") == "road":
					rebuild_entity(other)
		selection = [index]
		selection_changed()
	draft.clear()

func drop_intersection() -> void:
	if not cursor_valid:
		return
	checkpoint()
	var centre := snap_value(cursor)
	var reach := 24.0
	var first := add_entity({"k": "road", "t": road_type, "w": road_width, "walk": road_walk,
		"p": [[centre.x - reach, centre.y], [centre.x + reach, centre.y]]})
	var second := add_entity({"k": "road", "t": road_type, "w": road_width, "walk": road_walk,
		"p": [[centre.x, centre.y - reach], [centre.x, centre.y + reach]]})
	for index in range(entities.size()):
		if entities[index].get("k", "") == "road":
			rebuild_entity(index)
	selection = [first, second]
	selection_changed()
