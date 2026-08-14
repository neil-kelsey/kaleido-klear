extends Control

const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

const EDGE_KEYS := ["left", "top", "right", "bottom"]

@onready var back_button: Button = %BackButton
@onready var save_button: Button = %SaveButton
@onready var playtest_button: Button = %PlaytestButton
@onready var clear_button: Button = %ClearButton
@onready var status_label: Label = %StatusLabel
@onready var title_label: Label = %TitleLabel
@onready var tab_switcher: PanelContainer = %TabSwitcher
@onready var setup_tab_button: Button = %SetupTabButton
@onready var blocks_tab_button: Button = %BlocksTabButton
@onready var goals_tab_button: Button = %GoalsTabButton
@onready var setup_scroll: ScrollContainer = %Setup
@onready var blocks_scroll: ScrollContainer = %Blocks
@onready var goals_scroll: ScrollContainer = %Goals
@onready var grid: LevelCreatorGrid = %LevelCreatorGrid
@onready var setup_panel: VBoxContainer = %SetupPanel
@onready var blocks_panel: VBoxContainer = %BlocksPanel
@onready var right_panel: VBoxContainer = %RightPanel
@onready var actions_label: Label = %ActionsLabel

var _draft: LevelConfig = LevelConfig.new()
var _shapes: Array = []
var _selected_shape_index: int = -1
var _selected_color: Block.TileColor = Block.TileColor.RED
var _selected_kind: Block.BlockKind = Block.BlockKind.STANDARD
var _erase_mode: bool = false
var _grid_erase_mode: bool = false
var _active_tab: String = "setup"
var _disabled_cells: Array[Vector2i] = []

var _display_name_edit: LineEdit
var _section_option: OptionButton
var _daily_date_box: VBoxContainer
var _daily_year_spin: SpinBox
var _daily_month_option: OptionButton
var _daily_day_spin: SpinBox
var _columns_field: LineEdit
var _rows_field: LineEdit
var _shapes_list_box: VBoxContainer
var _create_shape_button: Button
var _color_flow: HFlowContainer
var _color_buttons: Array[Button] = []
var _kind_toolbar_buttons: Dictionary = {}
var _edge_panels: Dictionary = {}
var _goals_map: LevelCreatorGoalsMap
var _goal_modal: Control
var _goal_modal_edge: String = ""
var _goal_modal_edit_index: int = -1
var _goal_modal_title: Label
var _goal_modal_color: OptionButton
var _goal_modal_count: OptionButton
var _goal_modal_infinite: CheckBox
var _goal_modal_count_box: VBoxContainer
var _goal_modal_confirm: Button
var _goal_modal_delete: Button
var _refreshing_shape_list: bool = false
var _passed_signature: String = ""
var _baseline_signature: String = ""
var _clear_confirm: ConfirmationDialog
var _back_confirm: ConfirmationDialog


func _ready() -> void:
	if not OS.is_debug_build():
		get_tree().change_scene_to_file(SETTINGS_SCENE)
		return

	_build_setup_panel()
	_build_blocks_panel()
	_build_right_panel()
	_build_goal_modal()
	_apply_translations()
	_style_buttons()
	_style_segmented_tabs()
	_setup_confirm_dialogs()
	var restored_draft := GameSession.consume_playtest_draft()
	var restored_passed := GameSession.consume_playtest_passed()
	if restored_draft != null:
		_draft = restored_draft
		_apply_draft_to_ui()
		_capture_baseline_signature()
		if restored_passed:
			_passed_signature = _current_signature()
			_set_status(tr("UI_CREATOR_PLAYTEST_PASSED"))
		else:
			_set_status(tr("UI_CREATOR_RETURNED_FROM_PLAYTEST"))
	else:
		_new_level()
	await get_tree().process_frame
	_sync_panel_widths()
	resized.connect(_sync_panel_widths)

	grid.cell_clicked.connect(_on_grid_cell_clicked)
	back_button.pressed.connect(_on_back_pressed)
	save_button.pressed.connect(_on_save_pressed)
	playtest_button.pressed.connect(_on_playtest_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	setup_tab_button.pressed.connect(_on_setup_tab_pressed)
	blocks_tab_button.pressed.connect(_on_blocks_tab_pressed)
	goals_tab_button.pressed.connect(_on_goals_tab_pressed)

	_display_name_edit.text_changed.connect(_on_level_field_changed)
	## Section visibility is handled by _on_section_changed (connected in setup build).

	_refresh_save_button()


func _sync_panel_widths() -> void:
	var horizontal_inset := 84.0
	var panel_width: float = maxf(200.0, size.x - horizontal_inset)
	setup_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	blocks_panel.custom_minimum_size = Vector2(panel_width, 0.0)
	right_panel.custom_minimum_size = Vector2(panel_width, 0.0)


func _style_segmented_tabs() -> void:
	var tab_group := ButtonGroup.new()
	setup_tab_button.button_group = tab_group
	blocks_tab_button.button_group = tab_group
	goals_tab_button.button_group = tab_group
	setup_tab_button.button_pressed = true

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.11, 0.12, 0.16, 1.0)
	track_style.corner_radius_top_left = 14
	track_style.corner_radius_top_right = 14
	track_style.corner_radius_bottom_left = 14
	track_style.corner_radius_bottom_right = 14
	track_style.content_margin_left = 4
	track_style.content_margin_top = 4
	track_style.content_margin_right = 4
	track_style.content_margin_bottom = 4
	tab_switcher.add_theme_stylebox_override("panel", track_style)

	_style_segment_tab_button(setup_tab_button)
	_style_segment_tab_button(blocks_tab_button)
	_style_segment_tab_button(goals_tab_button)


func _style_segment_tab_button(button: Button) -> void:
	var radius := 10
	var inactive := StyleBoxFlat.new()
	inactive.bg_color = Color(0, 0, 0, 0)
	inactive.corner_radius_top_left = radius
	inactive.corner_radius_top_right = radius
	inactive.corner_radius_bottom_left = radius
	inactive.corner_radius_bottom_right = radius

	var inactive_hover := inactive.duplicate()
	inactive_hover.bg_color = Color(1, 1, 1, 0.08)

	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.28, 0.32, 0.42, 1.0)
	active.corner_radius_top_left = radius
	active.corner_radius_top_right = radius
	active.corner_radius_bottom_left = radius
	active.corner_radius_bottom_right = radius
	active.shadow_color = Color(0, 0, 0, 0.28)
	active.shadow_size = 3
	active.shadow_offset = Vector2(0, 1)

	button.add_theme_stylebox_override("normal", inactive)
	button.add_theme_stylebox_override("hover", inactive_hover)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover_pressed", active)
	button.add_theme_stylebox_override("focus", inactive)
	## Dark track needs light type — UiTheme.TEXT is near-black (for white menus).
	var inactive_text := Color(0.88, 0.90, 0.95, 1.0)
	button.add_theme_color_override("font_color", inactive_text)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 16)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER


func _on_setup_tab_pressed() -> void:
	_show_creator_tab("setup")


func _on_blocks_tab_pressed() -> void:
	_show_creator_tab("blocks")


func _on_goals_tab_pressed() -> void:
	_show_creator_tab("goals")


func _show_creator_tab(tab: String) -> void:
	_active_tab = tab
	setup_scroll.visible = tab == "setup"
	blocks_scroll.visible = tab == "blocks"
	goals_scroll.visible = tab == "goals"
	_sync_grid()


func _style_buttons() -> void:
	back_button.text = "  " + tr("UI_BACK")
	save_button.text = tr("UI_CREATOR_SAVE")
	playtest_button.text = tr("UI_CREATOR_PLAYTEST")
	clear_button.text = tr("UI_CREATOR_CLEAR")
	_style_compact_secondary_button(back_button)
	_style_compact_secondary_button(clear_button)
	_refresh_action_button_styles()


func _setup_confirm_dialogs() -> void:
	_clear_confirm = ConfirmationDialog.new()
	_clear_confirm.dialog_text = tr("UI_CREATOR_CLEAR_CONFIRM")
	_clear_confirm.ok_button_text = tr("UI_CREATOR_CLEAR")
	_clear_confirm.cancel_button_text = tr("UI_CANCEL")
	_clear_confirm.confirmed.connect(_on_clear_confirmed)
	add_child(_clear_confirm)

	_back_confirm = ConfirmationDialog.new()
	_back_confirm.dialog_text = tr("UI_CREATOR_BACK_CONFIRM")
	_back_confirm.ok_button_text = tr("UI_BACK")
	_back_confirm.cancel_button_text = tr("UI_CANCEL")
	_back_confirm.confirmed.connect(_on_back_confirmed)
	add_child(_back_confirm)


func _apply_translations() -> void:
	title_label.text = tr("UI_LEVEL_CREATOR")
	setup_tab_button.text = tr("UI_CREATOR_TAB_SETUP")
	blocks_tab_button.text = tr("UI_CREATOR_TAB_BLOCKS")
	goals_tab_button.text = tr("UI_CREATOR_TAB_GOALS")
	actions_label.text = tr("UI_CREATOR_ACTIONS")
	back_button.text = "  " + tr("UI_BACK")
	save_button.text = tr("UI_CREATOR_SAVE")
	playtest_button.text = tr("UI_CREATOR_PLAYTEST")
	clear_button.text = tr("UI_CREATOR_CLEAR")
	if status_label.text.is_empty() or status_label.text == "Ready":
		status_label.text = tr("UI_CREATOR_READY")
	if _clear_confirm:
		_clear_confirm.dialog_text = tr("UI_CREATOR_CLEAR_CONFIRM")
		_clear_confirm.ok_button_text = tr("UI_CREATOR_CLEAR")
		_clear_confirm.cancel_button_text = tr("UI_CANCEL")
	if _back_confirm:
		_back_confirm.dialog_text = tr("UI_CREATOR_BACK_CONFIRM")
		_back_confirm.ok_button_text = tr("UI_BACK")
		_back_confirm.cancel_button_text = tr("UI_CANCEL")
	if _goals_map != null:
		_goals_map.apply_translations()
	if _goal_modal_infinite != null:
		_goal_modal_infinite.text = tr("UI_CREATOR_GOAL_INFINITE")
	if _goal_modal_delete != null:
		_goal_modal_delete.text = tr("UI_CREATOR_GOAL_DELETE")


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func _build_setup_panel() -> void:
	_display_name_edit = _add_labeled_line_edit(
		setup_panel,
		tr("UI_CREATOR_DISPLAY_NAME"),
		tr("UI_CREATOR_DISPLAY_NAME_PLACEHOLDER")
	)

	var section_box := VBoxContainer.new()
	section_box.add_theme_constant_override("separation", 8)
	setup_panel.add_child(section_box)
	var section_label := Label.new()
	section_label.text = tr("UI_CREATOR_SECTION")
	section_label.add_theme_color_override("font_color", UiTheme.TEXT)
	section_label.add_theme_font_size_override("font_size", 18)
	section_box.add_child(section_label)
	_section_option = OptionButton.new()
	for i in LevelCatalog.SECTIONS.size():
		var title_key: String = LevelCatalog.SECTIONS[i]["title_key"]
		_section_option.add_item(tr(title_key), i)
	_section_option.add_item(tr("UI_DAILY_PUZZLES"), DailyCatalog.SECTION_DAILY)
	UiTheme.style_option_field(_section_option)
	_section_option.item_selected.connect(_on_section_changed)
	section_box.add_child(_section_option)

	_daily_date_box = VBoxContainer.new()
	_daily_date_box.add_theme_constant_override("separation", 8)
	_daily_date_box.visible = false
	section_box.add_child(_daily_date_box)
	var date_label := Label.new()
	date_label.text = tr("UI_CREATOR_DAILY_DATE")
	date_label.add_theme_color_override("font_color", UiTheme.TEXT)
	date_label.add_theme_font_size_override("font_size", 18)
	_daily_date_box.add_child(date_label)
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	_daily_date_box.add_child(date_row)

	_daily_day_spin = SpinBox.new()
	_daily_day_spin.min_value = 1
	_daily_day_spin.max_value = 31
	_daily_day_spin.value = 1
	_daily_day_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_day_spin.value_changed.connect(_on_daily_date_changed)
	date_row.add_child(_daily_day_spin)

	_daily_month_option = OptionButton.new()
	for m in range(1, 13):
		_daily_month_option.add_item(tr("UI_MONTH_%d" % m), m)
	_daily_month_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_option_field(_daily_month_option)
	_daily_month_option.item_selected.connect(_on_daily_month_selected)
	date_row.add_child(_daily_month_option)

	_daily_year_spin = SpinBox.new()
	_daily_year_spin.min_value = 2024
	_daily_year_spin.max_value = 2100
	_daily_year_spin.value = 2026
	_daily_year_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_year_spin.value_changed.connect(_on_daily_date_changed)
	date_row.add_child(_daily_year_spin)
	_set_daily_date_controls_to_today()

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 12)
	setup_panel.add_child(size_row)
	_columns_field = _add_number_field(size_row, tr("UI_CREATOR_COLUMNS"), 3, 12, 8)
	_rows_field = _add_number_field(size_row, tr("UI_CREATOR_ROWS"), 3, 16, 8)
	var apply_row := HBoxContainer.new()
	setup_panel.add_child(apply_row)
	var apply_button := Button.new()
	apply_button.text = tr("UI_CREATOR_APPLY_GRID")
	apply_button.pressed.connect(_on_apply_grid_pressed)
	apply_row.add_child(apply_button)
	_style_compact_action_button(apply_button)

	setup_panel.add_child(_make_spacer(12))
	_add_section_label(setup_panel, tr("UI_CREATOR_GRID_SECTION"))

	var grid_mode_row := HBoxContainer.new()
	grid_mode_row.add_theme_constant_override("separation", 12)
	setup_panel.add_child(grid_mode_row)
	var grid_mode_group := ButtonGroup.new()
	var grid_draw_button := Button.new()
	grid_draw_button.text = tr("UI_CREATOR_GRID_DRAW_MODE")
	grid_draw_button.toggle_mode = true
	grid_draw_button.button_group = grid_mode_group
	grid_draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_draw_button.pressed.connect(_on_grid_draw_selected)
	grid_mode_row.add_child(grid_draw_button)
	var grid_erase_button := Button.new()
	grid_erase_button.text = tr("UI_CREATOR_GRID_ERASE_MODE")
	grid_erase_button.toggle_mode = true
	grid_erase_button.button_group = grid_mode_group
	grid_erase_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_erase_button.pressed.connect(_on_grid_erase_selected)
	grid_mode_row.add_child(grid_erase_button)
	grid_draw_button.button_pressed = true
	_style_selectable_tool_button(grid_draw_button)
	_style_selectable_tool_button(grid_erase_button)

	var grid_hint := Label.new()
	grid_hint.text = tr("UI_CREATOR_GRID_HINT")
	grid_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	setup_panel.add_child(grid_hint)


func _build_blocks_panel() -> void:
	_add_section_label(blocks_panel, tr("UI_CREATOR_BLOCK_TOOLS"))

	var create_shape_row := HBoxContainer.new()
	blocks_panel.add_child(create_shape_row)
	_create_shape_button = Button.new()
	_create_shape_button.text = tr("UI_CREATOR_CREATE_SHAPE")
	_create_shape_button.pressed.connect(_on_create_shape_pressed)
	create_shape_row.add_child(_create_shape_button)
	_style_compact_action_button(_create_shape_button)

	var shapes_header := HBoxContainer.new()
	shapes_header.add_theme_constant_override("separation", 6)
	blocks_panel.add_child(shapes_header)
	var name_header := Label.new()
	name_header.text = tr("UI_CREATOR_SHAPE_NAME")
	name_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_header.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	name_header.add_theme_font_size_override("font_size", 14)
	shapes_header.add_child(name_header)
	var type_header := Label.new()
	type_header.text = tr("UI_CREATOR_SHAPE_TYPE")
	type_header.custom_minimum_size = Vector2(104.0, 0.0)
	type_header.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	type_header.add_theme_font_size_override("font_size", 14)
	shapes_header.add_child(type_header)
	var color_header := Label.new()
	color_header.text = tr("UI_CREATOR_SHAPE_COLOR")
	color_header.custom_minimum_size = Vector2(92.0, 0.0)
	color_header.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	color_header.add_theme_font_size_override("font_size", 14)
	shapes_header.add_child(color_header)
	var delete_header := Label.new()
	delete_header.custom_minimum_size = Vector2(40.0, 0.0)
	shapes_header.add_child(delete_header)

	var shapes_scroll := ScrollContainer.new()
	shapes_scroll.custom_minimum_size = Vector2(0.0, 168.0)
	shapes_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocks_panel.add_child(shapes_scroll)
	_shapes_list_box = VBoxContainer.new()
	_shapes_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shapes_scroll.add_child(_shapes_list_box)

	var color_group := ButtonGroup.new()
	_color_flow = HFlowContainer.new()
	_color_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	blocks_panel.add_child(_color_flow)
	for color in Block.TileColor.values():
		var button := Button.new()
		button.set_meta("tile_color", color)
		button.text = _color_label(color)
		button.toggle_mode = true
		button.button_group = color_group
		button.pressed.connect(_on_color_selected.bind(color, button))
		_color_flow.add_child(button)
		_color_buttons.append(button)
		_style_color_tool_button(button, color)
	if _color_flow.get_child_count() > 0:
		(_color_flow.get_child(0) as Button).button_pressed = true

	var kind_row := HBoxContainer.new()
	blocks_panel.add_child(kind_row)
	var kind_group := ButtonGroup.new()
	var standard_button := Button.new()
	standard_button.text = tr("UI_CREATOR_KIND_STANDARD")
	standard_button.toggle_mode = true
	standard_button.button_group = kind_group
	standard_button.pressed.connect(_on_kind_selected.bind(Block.BlockKind.STANDARD, standard_button))
	kind_row.add_child(standard_button)
	_kind_toolbar_buttons[Block.BlockKind.STANDARD] = standard_button
	var merge_button := Button.new()
	merge_button.text = tr("UI_CREATOR_KIND_MERGE")
	merge_button.toggle_mode = true
	merge_button.button_group = kind_group
	merge_button.pressed.connect(_on_kind_selected.bind(Block.BlockKind.MERGE, merge_button))
	kind_row.add_child(merge_button)
	_kind_toolbar_buttons[Block.BlockKind.MERGE] = merge_button
	var wall_button := Button.new()
	wall_button.text = tr("UI_CREATOR_KIND_WALL")
	wall_button.toggle_mode = true
	wall_button.button_group = kind_group
	wall_button.pressed.connect(_on_kind_selected.bind(Block.BlockKind.WALL, wall_button))
	kind_row.add_child(wall_button)
	_kind_toolbar_buttons[Block.BlockKind.WALL] = wall_button
	standard_button.button_pressed = true
	for child in kind_row.get_children():
		_style_selectable_tool_button(child as Button)

	_sync_color_picker_for_kind()

	blocks_panel.add_child(_make_spacer(8))
	_add_section_label(blocks_panel, tr("UI_CREATOR_MODE"))

	var mode_row := HBoxContainer.new()
	blocks_panel.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	var draw_button := Button.new()
	draw_button.text = tr("UI_CREATOR_DRAW_MODE")
	draw_button.toggle_mode = true
	draw_button.button_group = mode_group
	draw_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	draw_button.pressed.connect(_on_draw_mode_selected)
	mode_row.add_child(draw_button)
	var erase_mode_button := Button.new()
	erase_mode_button.text = tr("UI_CREATOR_ERASE_MODE")
	erase_mode_button.toggle_mode = true
	erase_mode_button.button_group = mode_group
	erase_mode_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	erase_mode_button.pressed.connect(_on_erase_mode_selected)
	mode_row.add_child(erase_mode_button)
	draw_button.button_pressed = true
	_style_selectable_tool_button(draw_button)
	_style_selectable_tool_button(erase_mode_button)

	var hint := Label.new()
	hint.text = tr("UI_CREATOR_PAINT_HINT")
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	blocks_panel.add_child(hint)


func _build_right_panel() -> void:
	for edge_key in EDGE_KEYS:
		_edge_panels[edge_key] = {"goals": []}

	_goals_map = LevelCreatorGoalsMap.new()
	_goals_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goals_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_goals_map.custom_minimum_size = Vector2(0, 360)
	right_panel.add_child(_goals_map)
	_goals_map.add_goal_requested.connect(_on_add_goal_requested)
	_goals_map.edit_goal_requested.connect(_on_edit_goal_requested)
	_goals_map.goals_changed.connect(_on_goals_map_changed)


func _build_goal_modal() -> void:
	_goal_modal = Control.new()
	_goal_modal.visible = false
	_goal_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_goal_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_goal_modal)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.65)
	overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_goal_modal()
	)
	_goal_modal.add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_modal.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.14, 0.18, 1)
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 28
	panel_style.content_margin_top = 28
	panel_style.content_margin_right = 28
	panel_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_goal_modal_title = Label.new()
	_goal_modal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_modal_title.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	_goal_modal_title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_goal_modal_title)

	var color_box := VBoxContainer.new()
	color_box.add_theme_constant_override("separation", 8)
	vbox.add_child(color_box)
	var color_label := Label.new()
	color_label.text = tr("UI_CREATOR_GOAL_COLOR")
	color_label.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	color_box.add_child(color_label)
	_goal_modal_color = OptionButton.new()
	_populate_color_option(_goal_modal_color)
	UiTheme.style_option_field(_goal_modal_color)
	color_box.add_child(_goal_modal_color)

	_goal_modal_infinite = CheckBox.new()
	_goal_modal_infinite.text = tr("UI_CREATOR_GOAL_INFINITE")
	_goal_modal_infinite.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	_goal_modal_infinite.toggled.connect(_on_goal_modal_infinite_toggled)
	vbox.add_child(_goal_modal_infinite)

	_goal_modal_count_box = VBoxContainer.new()
	_goal_modal_count_box.add_theme_constant_override("separation", 8)
	vbox.add_child(_goal_modal_count_box)
	var count_label := Label.new()
	count_label.text = tr("UI_CREATOR_GOAL_COUNT")
	count_label.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	_goal_modal_count_box.add_child(count_label)
	_goal_modal_count = OptionButton.new()
	for n in range(1, 21):
		_goal_modal_count.add_item(str(n), n)
	_goal_modal_count.select(0)
	UiTheme.style_option_field(_goal_modal_count)
	_goal_modal_count_box.add_child(_goal_modal_count)

	_goal_modal_delete = Button.new()
	_goal_modal_delete.text = tr("UI_CREATOR_GOAL_DELETE")
	_goal_modal_delete.visible = false
	_goal_modal_delete.pressed.connect(_on_delete_goal_modal)
	vbox.add_child(_goal_modal_delete)
	UiTheme.style_danger_button(_goal_modal_delete, UiTheme.ButtonScale.COMPACT)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	vbox.add_child(buttons)

	var cancel_button := Button.new()
	cancel_button.text = tr("UI_CANCEL")
	cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_button.pressed.connect(_hide_goal_modal)
	buttons.add_child(cancel_button)
	_style_compact_secondary_button(cancel_button)

	_goal_modal_confirm = Button.new()
	_goal_modal_confirm.text = tr("UI_CREATOR_GOAL_ADD_CONFIRM")
	_goal_modal_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_modal_confirm.pressed.connect(_on_confirm_goal_modal)
	buttons.add_child(_goal_modal_confirm)
	_style_compact_action_button(_goal_modal_confirm)


func _on_goal_modal_infinite_toggled(infinite_on: bool) -> void:
	_goal_modal_count_box.visible = not infinite_on


func _on_add_goal_requested(edge_key: String) -> void:
	_open_goal_modal(edge_key, -1)


func _on_edit_goal_requested(edge_key: String, index: int) -> void:
	_open_goal_modal(edge_key, index)


func _open_goal_modal(edge_key: String, edit_index: int) -> void:
	_goal_modal_edge = edge_key
	_goal_modal_edit_index = edit_index
	## Keep panel data aligned with the map before reading.
	_edge_panels[edge_key]["goals"] = _goals_map.get_edge_goals(edge_key)
	var edge_label := tr("UI_CREATOR_GOAL_%s" % edge_key.to_upper())
	var editing := edit_index >= 0
	if editing:
		_goal_modal_title.text = tr("UI_CREATOR_EDIT_GOAL_TITLE") % edge_label
		_goal_modal_confirm.text = tr("UI_CREATOR_GOAL_SAVE")
		_goal_modal_delete.visible = true
		_goal_modal_delete.text = tr("UI_CREATOR_GOAL_DELETE")
		var goals: Array = _edge_panels[edge_key]["goals"]
		if edit_index >= goals.size():
			_hide_goal_modal()
			return
		var goal: Dictionary = goals[edit_index]
		_select_option_by_id(_goal_modal_color, int(goal["color"]))
		var unlimited: bool = bool(goal.get("unlimited", false))
		_goal_modal_infinite.button_pressed = unlimited
		_goal_modal_count_box.visible = not unlimited
		var count := clampi(int(goal.get("count", 1)), 1, 20)
		_select_option_by_id(_goal_modal_count, count)
	else:
		_goal_modal_title.text = tr("UI_CREATOR_ADD_GOAL_TITLE") % edge_label
		_goal_modal_confirm.text = tr("UI_CREATOR_GOAL_ADD_CONFIRM")
		_goal_modal_delete.visible = false
		_goal_modal_color.select(0)
		_goal_modal_infinite.button_pressed = false
		_goal_modal_count_box.visible = true
		_goal_modal_count.select(0)
	_goal_modal_infinite.text = tr("UI_CREATOR_GOAL_INFINITE")
	_goal_modal.visible = true


func _select_option_by_id(option: OptionButton, id: int) -> void:
	for i in option.item_count:
		if option.get_item_id(i) == id:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _hide_goal_modal() -> void:
	if _goal_modal != null:
		_goal_modal.visible = false
	_goal_modal_edge = ""
	_goal_modal_edit_index = -1


func _read_goal_from_modal() -> Dictionary:
	var unlimited: bool = _goal_modal_infinite.button_pressed
	return {
		"color": _goal_modal_color.get_selected_id() as Block.TileColor,
		"unlimited": unlimited,
		"count": _goal_modal_count.get_selected_id() if not unlimited else 1,
	}


func _on_confirm_goal_modal() -> void:
	if _goal_modal_edge.is_empty() or not _edge_panels.has(_goal_modal_edge):
		_hide_goal_modal()
		return
	var goal := _read_goal_from_modal()
	var goals: Array = _edge_panels[_goal_modal_edge]["goals"]
	if _goal_modal_edit_index >= 0:
		if _goal_modal_edit_index >= goals.size():
			_hide_goal_modal()
			return
		goals[_goal_modal_edit_index] = goal
	else:
		goals.append(goal)
	_goals_map.set_edge_goals(_goal_modal_edge, goals)
	_hide_goal_modal()
	_refresh_save_button()


func _on_delete_goal_modal() -> void:
	if _goal_modal_edge.is_empty() or _goal_modal_edit_index < 0:
		_hide_goal_modal()
		return
	var goals: Array = _edge_panels[_goal_modal_edge]["goals"]
	if _goal_modal_edit_index >= goals.size():
		_hide_goal_modal()
		return
	goals.remove_at(_goal_modal_edit_index)
	_goals_map.set_edge_goals(_goal_modal_edge, goals)
	_hide_goal_modal()
	_refresh_save_button()


func _on_goals_map_changed() -> void:
	for edge_key in EDGE_KEYS:
		_edge_panels[edge_key]["goals"] = _goals_map.get_edge_goals(edge_key)
	_refresh_save_button()


func _new_level() -> void:
	_draft = LevelConfig.new()
	var stamp := int(Time.get_unix_time_from_system())
	_draft.level_id = "custom_level_%d" % stamp
	_draft.display_name = tr("UI_CREATOR_DEFAULT_DISPLAY_NAME")
	_draft.section_index = 0
	_draft.daily_date = ""
	_draft.sort_index = stamp
	_draft.columns = 8
	_draft.rows = 8
	_draft.multi_goal_mode = false
	_draft.block_positions.clear()
	_draft.block_colors.clear()
	_draft.block_shapes.clear()
	_draft.block_kinds.clear()
	_draft.block_cell_patterns.clear()
	_draft.block_shape_names.clear()
	_draft.disabled_cells.clear()
	_disabled_cells.clear()
	_draft.goal_left_phases.clear()
	_draft.goal_top_phases.clear()
	_draft.goal_right_phases.clear()
	_draft.goal_bottom_phases.clear()
	_draft.goal_left_enabled = false
	_draft.goal_top_enabled = false
	_draft.goal_right_enabled = false
	_draft.goal_bottom_enabled = false
	_shapes.clear()
	_selected_shape_index = -1
	_passed_signature = ""
	_apply_draft_to_ui()
	_capture_baseline_signature()
	_refresh_save_button()
	_set_status(tr("UI_CREATOR_NEW_LEVEL"))


func _apply_draft_to_ui() -> void:
	_display_name_edit.text = _draft.display_name
	_select_section_option(_draft.section_index if _draft.daily_date.is_empty() else DailyCatalog.SECTION_DAILY)
	if not _draft.daily_date.is_empty():
		_set_daily_date_controls_from_key(_draft.daily_date)
	else:
		_set_daily_date_controls_to_today()
	_refresh_daily_date_visibility()
	_columns_field.text = str(_draft.columns)
	_rows_field.text = str(_draft.rows)

	_disabled_cells = LevelCreatorShapes.as_cells(_draft.disabled_cells)

	_shapes_from_draft()
	_rebuild_shape_list_ui()
	_sync_toolbar_from_selected_shape()
	_sync_grid()

	_apply_edge_goals_to_ui("left", _draft.goal_left_phases)
	_apply_edge_goals_to_ui("top", _draft.goal_top_phases)
	_apply_edge_goals_to_ui("right", _draft.goal_right_phases)
	_apply_edge_goals_to_ui("bottom", _draft.goal_bottom_phases)


func _apply_edge_goals_to_ui(edge_key: String, phases: Array[GoalPhase]) -> void:
	var goals: Array = []
	for phase in phases:
		goals.append({
			"color": phase.color,
			"unlimited": phase.unlimited,
			"count": maxi(1, phase.count),
		})
	_edge_panels[edge_key]["goals"] = goals
	if _goals_map != null:
		_goals_map.set_edge_goals(edge_key, goals)


func _collect_draft_from_ui() -> void:
	_draft.display_name = _display_name_edit.text.strip_edges()
	_draft.section_index = _section_option.get_selected_id()
	if _draft.section_index == DailyCatalog.SECTION_DAILY:
		_draft.daily_date = _daily_date_key_from_controls()
		## Keep campaign index unused for dailies.
		_draft.section_index = DailyCatalog.SECTION_DAILY
	else:
		_draft.daily_date = ""
	_draft.columns = _read_number_field(_columns_field, 3, 12, 8)
	_draft.rows = _read_number_field(_rows_field, 3, 16, 8)
	_draft.multi_goal_mode = _any_edge_has_goals()

	var disabled: Array[Vector2i] = []
	for cell in _disabled_cells:
		if cell.x >= 0 and cell.y >= 0 and cell.x < _draft.columns and cell.y < _draft.rows:
			disabled.append(cell)
	_disabled_cells = disabled
	_draft.disabled_cells = disabled.duplicate()

	_shapes_to_draft()

	_collect_edge_goals_from_ui("left")
	_collect_edge_goals_from_ui("top")
	_collect_edge_goals_from_ui("right")
	_collect_edge_goals_from_ui("bottom")


func _any_edge_has_goals() -> bool:
	for edge_key in EDGE_KEYS:
		if not _edge_panels[edge_key]["goals"].is_empty():
			return true
	return false


func _collect_edge_goals_from_ui(edge_key: String) -> void:
	var panel_data: Dictionary = _edge_panels[edge_key]
	var phases: Array[GoalPhase] = []
	for goal in panel_data["goals"]:
		var phase := GoalPhase.new()
		phase.color = goal["color"]
		phase.unlimited = goal["unlimited"]
		phase.count = int(goal["count"]) if not goal["unlimited"] else 1
		phases.append(phase)
	var enabled := not phases.is_empty()
	var color: Block.TileColor = phases[0].color if not phases.is_empty() else Block.TileColor.RED

	match edge_key:
		"left":
			_draft.goal_left_enabled = enabled
			_draft.goal_left_color = color
			_draft.goal_left_phases = phases
		"top":
			_draft.goal_top_enabled = enabled
			_draft.goal_top_color = color
			_draft.goal_top_phases = phases
		"right":
			_draft.goal_right_enabled = enabled
			_draft.goal_right_color = color
			_draft.goal_right_phases = phases
		"bottom":
			_draft.goal_bottom_enabled = enabled
			_draft.goal_bottom_color = color
			_draft.goal_bottom_phases = phases


func _on_apply_grid_pressed() -> void:
	_draft.columns = _read_number_field(_columns_field, 3, 12, 8)
	_draft.rows = _read_number_field(_rows_field, 3, 16, 8)
	_trim_shapes_to_grid()
	_sync_grid()
	_set_status(tr("UI_CREATOR_GRID_APPLIED"))


func _trim_shapes_to_grid() -> void:
	var kept_shapes: Array = []
	for shape in _shapes:
		var in_bounds: Array[Vector2i] = []
		for cell in LevelCreatorShapes.as_cells(shape["cells"]):
			if cell.x < 0 or cell.y < 0 or cell.x >= _draft.columns or cell.y >= _draft.rows:
				continue
			in_bounds.append(cell)
		if in_bounds.is_empty():
			continue
		if not LevelCreatorShapes.is_orthogonally_connected(in_bounds):
			in_bounds = LevelCreatorShapes.largest_connected_component(in_bounds)
		if in_bounds.is_empty():
			continue
		var trimmed: Dictionary = shape.duplicate(true)
		trimmed["cells"] = in_bounds
		kept_shapes.append(trimmed)
	_shapes = kept_shapes
	if _selected_shape_index >= _shapes.size():
		_selected_shape_index = _shapes.size() - 1

	var kept_disabled: Array[Vector2i] = []
	for cell in _disabled_cells:
		if cell.x >= 0 and cell.y >= 0 and cell.x < _draft.columns and cell.y < _draft.rows:
			kept_disabled.append(cell)
	_disabled_cells = kept_disabled


func _on_grid_cell_clicked(cell: Vector2i, button_index: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return

	if _active_tab == "goals":
		return

	if _active_tab == "setup":
		_edit_grid_cell(cell)
		return

	if _erase_mode:
		var shape_index := grid.find_shape_at_cell(cell)
		if shape_index == -1:
			return
		var cells: Array[Vector2i] = LevelCreatorShapes.as_cells(_shapes[shape_index]["cells"])
		if not LevelCreatorShapes.can_remove_cell(cells, cell):
			_set_status(tr("UI_CREATOR_INVALID_CELL"))
			return
		cells.erase(cell)
		_shapes[shape_index]["cells"] = cells
		if cells.is_empty():
			_shapes.remove_at(shape_index)
			if _selected_shape_index == shape_index:
				_selected_shape_index = mini(shape_index, _shapes.size() - 1)
			elif _selected_shape_index > shape_index:
				_selected_shape_index -= 1
			_rebuild_shape_list_ui()
		_sync_grid()
		_set_status(tr("UI_CREATOR_CELL_REMOVED"))
		return

	if _selected_shape_index < 0 or _selected_shape_index >= _shapes.size():
		_set_status(tr("UI_CREATOR_NO_SHAPE_SELECTED"))
		return

	if cell in _disabled_cells:
		_set_status(tr("UI_CREATOR_CELL_DISABLED"))
		return

	var blocked := _blocked_cells_except(_selected_shape_index)
	var shape_cells: Array[Vector2i] = LevelCreatorShapes.as_cells(_shapes[_selected_shape_index]["cells"])
	if not LevelCreatorShapes.can_add_cell(shape_cells, cell, blocked):
		_set_status(tr("UI_CREATOR_INVALID_CELL"))
		return

	shape_cells.append(cell)
	_shapes[_selected_shape_index]["cells"] = shape_cells
	_sync_grid()
	_set_status(tr("UI_CREATOR_CELL_ADDED"))


func _edit_grid_cell(cell: Vector2i) -> void:
	if _grid_erase_mode:
		if cell in _disabled_cells:
			return
		if grid.find_shape_at_cell(cell) != -1:
			_set_status(tr("UI_CREATOR_SQUARE_OCCUPIED"))
			return
		_disabled_cells.append(cell)
		_sync_grid()
		_set_status(tr("UI_CREATOR_SQUARE_REMOVED"))
		return

	if cell not in _disabled_cells:
		return
	_disabled_cells.erase(cell)
	_sync_grid()
	_set_status(tr("UI_CREATOR_SQUARE_ADDED"))


func _blocked_cells_except(ignore_index: int) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for i in _shapes.size():
		if i == ignore_index:
			continue
		for cell in LevelCreatorShapes.as_cells(_shapes[i]["cells"]):
			blocked.append(cell)
	return blocked


func _on_create_shape_pressed() -> void:
	var cells: Array[Vector2i] = []
	var shape := {
		"name": LevelCreatorShapes.default_shape_name(_shapes.size()),
		"cells": cells,
		"color": _selected_color,
		"kind": _selected_kind,
	}
	_shapes.append(shape)
	_selected_shape_index = _shapes.size() - 1
	_rebuild_shape_list_ui()
	_sync_toolbar_from_selected_shape()
	_sync_grid()
	_set_status(tr("UI_CREATOR_SHAPE_CREATED"))


func _on_select_shape(index: int) -> void:
	if index < 0 or index >= _shapes.size():
		return
	_selected_shape_index = index
	var shape: Dictionary = _shapes[index]
	_selected_color = shape.get("color", Block.TileColor.RED)
	_selected_kind = shape.get("kind", Block.BlockKind.STANDARD)
	_sync_toolbar_from_selected_shape()
	_sync_grid()


func _on_shape_row_kind_changed(
	selected_index: int,
	shape_index: int,
	kind_option: OptionButton,
	color_option: OptionButton
) -> void:
	if _refreshing_shape_list:
		return
	if shape_index < 0 or shape_index >= _shapes.size():
		return
	var kind: Block.BlockKind = kind_option.get_item_id(selected_index)
	_shapes[shape_index]["kind"] = kind
	color_option.disabled = Block.is_wall_kind(kind)
	if shape_index == _selected_shape_index:
		_selected_kind = kind
		_sync_toolbar_kind_buttons()
		_sync_color_picker_for_kind()
	_sync_grid()
	_refresh_save_button()


func _on_shape_row_color_changed(
	selected_index: int,
	shape_index: int,
	color_option: OptionButton
) -> void:
	if _refreshing_shape_list:
		return
	if shape_index < 0 or shape_index >= _shapes.size():
		return
	if Block.is_wall_kind(_shapes[shape_index].get("kind", Block.BlockKind.STANDARD)):
		return
	var color: Block.TileColor = color_option.get_item_id(selected_index)
	_shapes[shape_index]["color"] = color
	_style_shape_color_option(color_option, color)
	if shape_index == _selected_shape_index:
		_selected_color = color
		_sync_toolbar_color_buttons()
	_sync_grid()
	_refresh_save_button()


func _on_shape_renamed(index: int, new_name: String) -> void:
	if _refreshing_shape_list:
		return
	if index < 0 or index >= _shapes.size():
		return
	_shapes[index]["name"] = new_name.strip_edges()
	_refresh_save_button()


func _on_delete_shape(index: int) -> void:
	if index < 0 or index >= _shapes.size():
		return
	_shapes.remove_at(index)
	if _selected_shape_index == index:
		_selected_shape_index = mini(index, _shapes.size() - 1)
	elif _selected_shape_index > index:
		_selected_shape_index -= 1
	_rebuild_shape_list_ui()
	_sync_toolbar_from_selected_shape()
	_sync_grid()
	_set_status(tr("UI_CREATOR_SHAPE_DELETED"))


func _rebuild_shape_list_ui() -> void:
	_refreshing_shape_list = true
	for child in _shapes_list_box.get_children():
		child.queue_free()
	for i in _shapes.size():
		var shape: Dictionary = _shapes[i]
		var shape_kind: Block.BlockKind = shape.get("kind", Block.BlockKind.STANDARD)
		var shape_color: Block.TileColor = shape.get("color", Block.TileColor.RED)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_shapes_list_box.add_child(row)

		var name_edit := LineEdit.new()
		name_edit.text = shape["name"]
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.focus_entered.connect(_on_select_shape.bind(i))
		name_edit.text_changed.connect(_on_shape_renamed.bind(i))
		UiTheme.style_row_text_field(name_edit)
		row.add_child(name_edit)

		var kind_option := OptionButton.new()
		_populate_kind_option(kind_option)
		UiTheme.style_row_option_field(kind_option)
		kind_option.custom_minimum_size = Vector2(104.0, 0.0)
		var kind_index := kind_option.get_item_index(shape_kind)
		if kind_index >= 0:
			kind_option.select(kind_index)
		row.add_child(kind_option)

		var color_option := OptionButton.new()
		_populate_color_option(color_option)
		UiTheme.style_row_option_field(color_option)
		color_option.custom_minimum_size = Vector2(92.0, 0.0)
		var color_index := color_option.get_item_index(shape_color)
		if color_index >= 0:
			color_option.select(color_index)
		_style_shape_color_option(color_option, shape_color)
		color_option.disabled = Block.is_wall_kind(shape_kind)
		color_option.item_selected.connect(
			_on_shape_row_color_changed.bind(i, color_option)
		)
		kind_option.item_selected.connect(
			_on_shape_row_kind_changed.bind(i, kind_option, color_option)
		)
		row.add_child(color_option)

		var delete_button := Button.new()
		delete_button.text = "X"
		delete_button.pressed.connect(_on_delete_shape.bind(i))
		delete_button.custom_minimum_size = Vector2(40.0, 0.0)
		row.add_child(delete_button)
		_style_selectable_tool_button(delete_button)

		if i == _selected_shape_index:
			row.modulate = Color(1.15, 1.15, 1.15, 1.0)
	_refreshing_shape_list = false


func _shapes_from_draft() -> void:
	_shapes.clear()
	for i in _draft.block_positions.size():
		var anchor: Vector2i = _draft.block_positions[i]
		var cells: Array[Vector2i] = []
		if (
			i < _draft.block_cell_patterns.size()
			and _draft.block_cell_patterns[i] is Array
			and _draft.block_cell_patterns[i].size() > 0
		):
			cells = LevelCreatorShapes.offsets_to_cells(anchor, _draft.block_cell_patterns[i])
		else:
			var shape_id: String = (
				_draft.block_shapes[i] if i < _draft.block_shapes.size() else BlockShapes.SINGLE
			)
			for offset in BlockShapes.get_cells(shape_id):
				cells.append(anchor + offset)
		var shape_name := LevelCreatorShapes.default_shape_name(i)
		if i < _draft.block_shape_names.size() and not _draft.block_shape_names[i].is_empty():
			shape_name = _draft.block_shape_names[i]
		_shapes.append({
			"name": shape_name,
			"cells": cells,
			"color": _draft.block_colors[i] if i < _draft.block_colors.size() else Block.TileColor.RED,
			"kind": _draft.block_kinds[i] if i < _draft.block_kinds.size() else Block.BlockKind.STANDARD,
		})
	_selected_shape_index = 0 if not _shapes.is_empty() else -1
	if _selected_shape_index >= 0:
		var selected: Dictionary = _shapes[_selected_shape_index]
		_selected_kind = selected.get("kind", Block.BlockKind.STANDARD)
		_selected_color = selected.get("color", Block.TileColor.RED)


func _shapes_to_draft() -> void:
	_draft.block_positions.clear()
	_draft.block_colors.clear()
	_draft.block_shapes.clear()
	_draft.block_kinds.clear()
	_draft.block_cell_patterns.clear()
	_draft.block_shape_names.clear()
	for shape in _shapes:
		var cells: Array[Vector2i] = LevelCreatorShapes.as_cells(shape["cells"])
		if cells.is_empty():
			continue
		var packed: Dictionary = LevelCreatorShapes.cells_to_anchor_and_offsets(cells)
		_draft.block_positions.append(packed["anchor"])
		_draft.block_colors.append(shape.get("color", Block.TileColor.RED))
		_draft.block_shapes.append(BlockShapes.SINGLE)
		_draft.block_kinds.append(shape.get("kind", Block.BlockKind.STANDARD))
		_draft.block_cell_patterns.append(packed["offsets"])
		_draft.block_shape_names.append(shape.get("name", ""))


func _has_valid_blocks() -> bool:
	for shape in _shapes:
		if not shape["cells"].is_empty():
			return true
	return false


func _sync_grid() -> void:
	grid.sync_shapes(
		_shapes,
		int(_read_number_field(_columns_field, 3, 12, 8)),
		int(_read_number_field(_rows_field, 3, 16, 8)),
		_selected_shape_index,
		_erase_mode,
		_active_tab == "setup",
		_grid_erase_mode,
		_disabled_cells
	)
	_update_shape_list_row_widgets()
	_refresh_save_button()


func _update_shape_list_row_widgets() -> void:
	_refreshing_shape_list = true
	for i in _shapes_list_box.get_child_count():
		if i >= _shapes.size():
			break
		var row := _shapes_list_box.get_child(i) as HBoxContainer
		if row == null or row.get_child_count() < 4:
			continue
		var shape: Dictionary = _shapes[i]
		var kind_option := row.get_child(1) as OptionButton
		var color_option := row.get_child(2) as OptionButton
		if kind_option == null or color_option == null:
			continue
		var kind: Block.BlockKind = shape.get("kind", Block.BlockKind.STANDARD)
		var color: Block.TileColor = shape.get("color", Block.TileColor.RED)
		var kind_index := kind_option.get_item_index(kind)
		if kind_index >= 0:
			kind_option.select(kind_index)
		var color_index := color_option.get_item_index(color)
		if color_index >= 0:
			color_option.select(color_index)
		_style_shape_color_option(color_option, color)
		color_option.disabled = Block.is_wall_kind(kind)
		row.modulate = Color(1.15, 1.15, 1.15) if i == _selected_shape_index else Color.WHITE
	_refreshing_shape_list = false


func _on_color_selected(color: Block.TileColor, _button: Button) -> void:
	if _selected_kind == Block.BlockKind.WALL:
		return
	_selected_color = color
	if _selected_shape_index >= 0 and _selected_shape_index < _shapes.size():
		_shapes[_selected_shape_index]["color"] = color
	_update_shape_list_row_widgets()
	_sync_grid()


func _on_kind_selected(kind: Block.BlockKind, _button: Button) -> void:
	_selected_kind = kind
	if _selected_shape_index >= 0 and _selected_shape_index < _shapes.size():
		_shapes[_selected_shape_index]["kind"] = kind
	_sync_color_picker_for_kind()
	_update_shape_list_row_widgets()
	_sync_grid()


func _sync_toolbar_from_selected_shape() -> void:
	if _selected_shape_index < 0 or _selected_shape_index >= _shapes.size():
		_sync_color_picker_for_kind()
		return
	var shape: Dictionary = _shapes[_selected_shape_index]
	_selected_kind = shape.get("kind", Block.BlockKind.STANDARD)
	_selected_color = shape.get("color", Block.TileColor.RED)
	_sync_toolbar_kind_buttons()
	_sync_toolbar_color_buttons()
	_sync_color_picker_for_kind()


func _sync_toolbar_kind_buttons() -> void:
	for kind_key in _kind_toolbar_buttons:
		var button: Button = _kind_toolbar_buttons[kind_key]
		button.set_block_signals(true)
		button.button_pressed = int(kind_key) == int(_selected_kind)
		button.set_block_signals(false)


func _sync_toolbar_color_buttons() -> void:
	for button in _color_buttons:
		var color: Block.TileColor = button.get_meta("tile_color")
		button.set_block_signals(true)
		button.button_pressed = color == _selected_color
		button.set_block_signals(false)


func _sync_color_picker_for_kind() -> void:
	var wall_selected := _selected_kind == Block.BlockKind.WALL
	for button in _color_buttons:
		button.disabled = wall_selected
		button.modulate = Color(0.55, 0.55, 0.58, 0.55) if wall_selected else Color.WHITE


func _on_draw_mode_selected() -> void:
	_erase_mode = false
	_sync_grid()


func _on_erase_mode_selected() -> void:
	_erase_mode = true
	_sync_grid()


func _on_grid_draw_selected() -> void:
	_grid_erase_mode = false
	_sync_grid()


func _on_grid_erase_selected() -> void:
	_grid_erase_mode = true
	_sync_grid()


func _on_save_pressed() -> void:
	if not _is_playtest_passed():
		_set_status(tr("UI_CREATOR_SAVE_NEEDS_PLAYTEST"))
		return
	_collect_draft_from_ui()
	if _draft.display_name.is_empty():
		_set_status(tr("UI_CREATOR_ERROR_DISPLAY_NAME"))
		return
	if _draft.level_id.is_empty():
		var stamp := int(Time.get_unix_time_from_system())
		if not _draft.daily_date.is_empty():
			_draft.level_id = "daily_%s_%d" % [_draft.daily_date, stamp]
		else:
			_draft.level_id = "custom_level_%d" % stamp
		_draft.sort_index = stamp
	elif _draft.sort_index <= 0:
		_draft.sort_index = int(Time.get_unix_time_from_system())
	## Keep daily ids aligned with their date when reassigned.
	if not _draft.daily_date.is_empty() and not _draft.level_id.begins_with("daily_%s_" % _draft.daily_date):
		var stamp2 := int(Time.get_unix_time_from_system())
		_draft.level_id = "daily_%s_%d" % [_draft.daily_date, stamp2]
	if _draft.section_index == DailyCatalog.SECTION_DAILY and _draft.daily_date.is_empty():
		_set_status(tr("UI_CREATOR_ERROR_DAILY_DATE"))
		return
	if not _has_valid_blocks():
		_set_status(tr("UI_CREATOR_ERROR_BLOCKS"))
		return

	var error := CustomLevelStore.save_level(_draft)
	if error != OK:
		_set_status(tr("UI_CREATOR_ERROR_SAVE") % str(error))
		return

	if CustomLevelStore.saves_to_project():
		_set_status("%s (project)" % (tr("UI_CREATOR_SAVED") % _draft.display_name))
	else:
		_set_status(tr("UI_CREATOR_SAVED") % _draft.display_name)
	_capture_baseline_signature()


func _capture_baseline_signature() -> void:
	_baseline_signature = _current_signature()


func _has_unsaved_changes() -> bool:
	return _current_signature() != _baseline_signature


func _on_playtest_pressed() -> void:
	_collect_draft_from_ui()
	if not _has_valid_blocks():
		_set_status(tr("UI_CREATOR_ERROR_BLOCKS"))
		return
	var test_level := _draft.duplicate(true) as LevelConfig
	GameSession.start_playtest(test_level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_level_field_changed(_value: Variant = null) -> void:
	_refresh_save_button()


func _on_section_changed(_index: int = 0) -> void:
	_refresh_daily_date_visibility()
	_on_level_field_changed()


func _on_daily_month_selected(_index: int = 0) -> void:
	_clamp_daily_day_to_month()
	_on_level_field_changed()


func _on_daily_date_changed(_value: float = 0.0) -> void:
	_clamp_daily_day_to_month()
	_on_level_field_changed()


func _refresh_daily_date_visibility() -> void:
	if _daily_date_box == null or _section_option == null:
		return
	var selected_id := _section_option.get_selected_id()
	var show_date := selected_id == DailyCatalog.SECTION_DAILY
	_daily_date_box.visible = show_date
	## Keep layout from collapsing oddly in the scroll panel.
	_daily_date_box.custom_minimum_size = Vector2(0, 96) if show_date else Vector2.ZERO


func _select_section_option(section_id: int) -> void:
	if _section_option == null:
		return
	var idx := _section_option.get_item_index(section_id)
	if idx < 0:
		idx = 0
	_section_option.select(idx)


func _set_daily_date_controls_to_today() -> void:
	_set_daily_date_controls_from_key(DailyCatalog.today_key())


func _set_daily_date_controls_from_key(date_key: String) -> void:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if _daily_year_spin:
		_daily_year_spin.value = year
	if _daily_month_option:
		var m_idx := _daily_month_option.get_item_index(month)
		if m_idx >= 0:
			_daily_month_option.select(m_idx)
	if _daily_day_spin:
		_daily_day_spin.value = day
	_clamp_daily_day_to_month()


func _daily_date_key_from_controls() -> String:
	if _daily_year_spin == null or _daily_month_option == null or _daily_day_spin == null:
		return DailyCatalog.today_key()
	_clamp_daily_day_to_month()
	var year := int(_daily_year_spin.value)
	var month := _daily_month_option.get_selected_id()
	var day := int(_daily_day_spin.value)
	return "%04d-%02d-%02d" % [year, month, day]


func _clamp_daily_day_to_month() -> void:
	if _daily_year_spin == null or _daily_month_option == null or _daily_day_spin == null:
		return
	var year := int(_daily_year_spin.value)
	var month := _daily_month_option.get_selected_id()
	var max_day := _days_in_month(year, month)
	_daily_day_spin.max_value = max_day
	if int(_daily_day_spin.value) > max_day:
		_daily_day_spin.value = max_day


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		2:
			var leap := (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0)
			return 29 if leap else 28
		_:
			return 31


func _is_playtest_passed() -> bool:
	return not _passed_signature.is_empty() and _passed_signature == _current_signature()


func _refresh_save_button() -> void:
	_refresh_action_button_styles()


func _refresh_action_button_styles() -> void:
	var can_save := _is_playtest_passed()
	save_button.disabled = not can_save
	if can_save:
		_style_compact_action_button(save_button)
		_style_compact_secondary_button(playtest_button)
	else:
		_style_compact_secondary_button(save_button)
		_apply_compact_disabled_style(save_button)
		_style_compact_action_button(playtest_button)


func _current_signature() -> String:
	_collect_draft_from_ui()
	var parts: Array = []
	parts.append("%dx%d" % [_draft.columns, _draft.rows])
	parts.append("section:%d" % _draft.section_index)
	parts.append("daily:%s" % _draft.daily_date)
	parts.append("mg:%s" % str(_draft.multi_goal_mode))

	var block_parts: Array = []
	for i in _draft.block_positions.size():
		var pattern: Array = (
			_draft.block_cell_patterns[i] if i < _draft.block_cell_patterns.size() else []
		)
		var color: int = _draft.block_colors[i] if i < _draft.block_colors.size() else 0
		var kind: int = _draft.block_kinds[i] if i < _draft.block_kinds.size() else 0
		block_parts.append("%s|%s|%d|%d" % [
			str(_draft.block_positions[i]),
			str(pattern),
			color,
			kind,
		])
	parts.append("blocks:%s" % "/".join(block_parts))

	var disabled_parts: Array = []
	for cell in _draft.disabled_cells:
		disabled_parts.append(str(cell))
	disabled_parts.sort()
	parts.append("holes:%s" % ",".join(disabled_parts))

	for edge_key in EDGE_KEYS:
		parts.append(_edge_signature(edge_key))

	return "~".join(parts)


func _edge_signature(edge_key: String) -> String:
	var enabled: bool
	var color: int
	var phases: Array[GoalPhase]
	match edge_key:
		"left":
			enabled = _draft.goal_left_enabled
			color = int(_draft.goal_left_color)
			phases = _draft.goal_left_phases
		"top":
			enabled = _draft.goal_top_enabled
			color = int(_draft.goal_top_color)
			phases = _draft.goal_top_phases
		"right":
			enabled = _draft.goal_right_enabled
			color = int(_draft.goal_right_color)
			phases = _draft.goal_right_phases
		_:
			enabled = _draft.goal_bottom_enabled
			color = int(_draft.goal_bottom_color)
			phases = _draft.goal_bottom_phases
	var phase_parts: Array = []
	for phase in phases:
		phase_parts.append("%d:%d:%s" % [int(phase.color), phase.count, str(phase.unlimited)])
	return "%s(%s,%d,[%s])" % [edge_key, str(enabled), color, ",".join(phase_parts)]


func _on_clear_pressed() -> void:
	_clear_confirm.popup_centered()


func _on_clear_confirmed() -> void:
	_new_level()


func _on_back_pressed() -> void:
	if not _has_unsaved_changes():
		_on_back_confirmed()
		return
	_back_confirm.popup_centered()


func handle_back() -> void:
	_on_back_pressed()


func _on_back_confirmed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _set_status(message: String) -> void:
	status_label.text = message


func _add_section_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	parent.add_child(label)


func _add_labeled_line_edit(parent: Control, caption: String, placeholder: String = "") -> LineEdit:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	label.add_theme_font_size_override("font_size", 18)
	box.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	UiTheme.style_text_field(edit)
	box.add_child(edit)
	return edit


func _add_number_field(
	parent: Control,
	caption: String,
	min_value: int,
	max_value: int,
	value: int
) -> LineEdit:
	var edit := _add_labeled_line_edit(parent, caption, str(value))
	edit.text_changed.connect(_on_number_field_changed.bind(edit, min_value, max_value))
	return edit


func _on_number_field_changed(edit: LineEdit, min_value: int, max_value: int, _new_text: String = "") -> void:
	if edit.text.is_empty():
		_on_level_field_changed()
		return
	if not edit.text.is_valid_int():
		return
	var number := clampi(int(edit.text), min_value, max_value)
	if edit.text != str(number):
		edit.text = str(number)
	_on_level_field_changed()


func _read_number_field(edit: LineEdit, min_value: int, max_value: int, fallback: int) -> int:
	if edit.text.is_empty() or not edit.text.is_valid_int():
		return fallback
	return clampi(int(edit.text), min_value, max_value)


func _make_spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, height)
	return spacer


func _populate_color_option(option: OptionButton) -> void:
	option.clear()
	for color in Block.TileColor.values():
		option.add_item(_color_label(color), color)


func _populate_kind_option(option: OptionButton) -> void:
	option.clear()
	option.add_item(tr("UI_CREATOR_KIND_STANDARD"), Block.BlockKind.STANDARD)
	option.add_item(tr("UI_CREATOR_KIND_MERGE"), Block.BlockKind.MERGE)
	option.add_item(tr("UI_CREATOR_KIND_WALL"), Block.BlockKind.WALL)


func _style_shape_color_option(option: OptionButton, tile_color: Block.TileColor) -> void:
	var fill := Block.get_color(tile_color)

	var normal := UiTheme.row_option_field_stylebox(false)
	normal.border_width_left = 5
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.border_color = fill

	var focused := UiTheme.row_option_field_stylebox(true)
	focused.border_width_left = 5
	focused.border_width_top = 3
	focused.border_width_right = 3
	focused.border_width_bottom = 3
	focused.border_color = fill.lightened(0.08)

	option.add_theme_stylebox_override("normal", normal)
	option.add_theme_stylebox_override("pressed", normal)
	option.add_theme_stylebox_override("hover", focused)
	option.add_theme_stylebox_override("focus", focused)
	option.add_theme_constant_override("arrow_margin", 12)


func _color_label(color: Block.TileColor) -> String:
	match color:
		Block.TileColor.RED:
			return tr("UI_COLOR_RED")
		Block.TileColor.GREEN:
			return tr("UI_COLOR_GREEN")
		Block.TileColor.BLUE:
			return tr("UI_COLOR_BLUE")
		Block.TileColor.YELLOW:
			return tr("UI_COLOR_YELLOW")
		Block.TileColor.PURPLE:
			return tr("UI_COLOR_PURPLE")
		Block.TileColor.ORANGE:
			return tr("UI_COLOR_ORANGE")
		_:
			return tr("UI_COLOR")


func _style_compact_action_button(button: Button) -> void:
	UiTheme.style_primary_button(button, UiTheme.ButtonScale.COMPACT)


func _style_compact_secondary_button(button: Button) -> void:
	UiTheme.style_secondary_button(button, UiTheme.ButtonScale.COMPACT)


func _apply_compact_disabled_style(button: Button) -> void:
	var radius := 10
	button.add_theme_stylebox_override(
		"disabled",
		UiTheme.rounded_stylebox(Color(0.12, 0.13, 0.17, 1.0), radius)
	)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))


func _style_selectable_tool_button(button: Button) -> void:
	var radius := 10
	button.add_theme_stylebox_override("normal", UiTheme.rounded_stylebox(UiTheme.BUTTON, radius))
	button.add_theme_stylebox_override("hover", UiTheme.rounded_stylebox(UiTheme.BUTTON_HOVER, radius))
	button.add_theme_stylebox_override("pressed", UiTheme.rounded_stylebox(UiTheme.ACCENT, radius))
	button.add_theme_stylebox_override(
		"hover_pressed",
		UiTheme.rounded_stylebox(UiTheme.ACCENT.lightened(0.12), radius)
	)
	button.add_theme_stylebox_override("focus", UiTheme.rounded_stylebox(UiTheme.BUTTON_HOVER, radius))
	button.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	button.add_theme_color_override("font_hover_color", UiTheme.TEXT_ON_DARK)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)


func _style_color_tool_button(button: Button, tile_color: Block.TileColor) -> void:
	var fill := Block.get_color(tile_color)
	var radius := 10
	var off := UiTheme.rounded_stylebox(UiTheme.BUTTON, radius)
	off.border_width_left = 4
	off.border_width_top = 4
	off.border_width_right = 4
	off.border_width_bottom = 4
	off.border_color = fill
	var on := UiTheme.rounded_stylebox(fill, radius)
	var on_hover := UiTheme.rounded_stylebox(fill.lightened(0.1), radius)
	var text_on := _readable_text_color(fill)
	button.add_theme_stylebox_override("normal", off)
	button.add_theme_stylebox_override("hover", UiTheme.rounded_stylebox(UiTheme.BUTTON_HOVER, radius))
	button.add_theme_stylebox_override("pressed", on)
	button.add_theme_stylebox_override("hover_pressed", on_hover)
	button.add_theme_stylebox_override("focus", off)
	button.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	button.add_theme_color_override("font_hover_color", UiTheme.TEXT_ON_DARK)
	button.add_theme_color_override("font_pressed_color", text_on)
	button.add_theme_color_override("font_hover_pressed_color", text_on)
	button.add_theme_font_size_override("font_size", 18)


func _readable_text_color(background: Color) -> Color:
	var luminance := 0.299 * background.r + 0.587 * background.g + 0.114 * background.b
	return Color.BLACK if luminance > 0.62 else Color.WHITE
