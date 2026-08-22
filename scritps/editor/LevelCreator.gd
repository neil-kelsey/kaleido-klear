extends Control

const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const EXIT_CONFIRM_SCENE := preload("res://scenes/ui/exit_confirm_modal.tscn")
const SHAPE_MODAL_SCENE := preload("res://scenes/editor/shape_editor_modal.tscn")
const BRAND_RAINBOW := preload("res://scritps/ui/BrandRainbow.gd")
const CREATOR_TAB_FONT := 32
const CREATOR_LABEL_FONT := 28
const CREATOR_FIELD_FONT := 28
const CREATOR_FIELD_HEIGHT := 64
const CREATOR_HINT_FONT := 24

const EDGE_KEYS := ["left", "top", "right", "bottom"]

@onready var back_button: Button = %BackButton
@onready var save_button: Button = %SaveButton
@onready var playtest_button: Button = %PlaytestButton
@onready var clear_button: Button = %ClearButton
@onready var status_label: Label = %StatusLabel
@onready var mix_cheat_sheet: VBoxContainer = %MixCheatSheet
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
var _active_tab: String = "setup"
var _disabled_cells: Array[Vector2i] = []

var _display_name_edit: LineEdit
var _section_option: OptionButton
var _subsection_box: VBoxContainer
var _subsection_label: Label
var _subsection_option: OptionButton
var _level_details_label: Label
var _grid_details_label: Label
var _daily_date_box: VBoxContainer
var _daily_year_spin: SpinBox
var _daily_month_option: OptionButton
var _daily_day_spin: SpinBox
var _columns_field: LineEdit
var _rows_field: LineEdit
var _shapes_list_box: VBoxContainer
var _shapes_header: HBoxContainer
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
var _confirm_modal: Control
var _confirm_action: String = ""
var _shape_modal
var _pending_shape_cell := Vector2i(-1, -1)
var _shape_modal_edit_index: int = -1
var _rainbow_hosts: Array[Control] = []


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
	_build_mix_cheat_sheet()
	status_label.visible = false
	_setup_confirm_dialogs()
	_setup_shape_modal()
	set_process(true)
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
	grid.cell_edit_requested.connect(_on_grid_cell_edit_requested)
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
	blocks_panel.custom_minimum_size.x = panel_width
	blocks_panel.custom_minimum_size.y = maxf(blocks_scroll.size.y - 24.0, 360.0)
	right_panel.custom_minimum_size = Vector2(panel_width, 0.0)


func _style_segmented_tabs() -> void:
	var tab_group := ButtonGroup.new()
	setup_tab_button.button_group = tab_group
	blocks_tab_button.button_group = tab_group
	goals_tab_button.button_group = tab_group
	setup_tab_button.button_pressed = true

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = Color(0.97, 0.97, 0.985, 1.0)
	track_style.set_corner_radius_all(28)
	track_style.content_margin_left = 8
	track_style.content_margin_top = 8
	track_style.content_margin_right = 8
	track_style.content_margin_bottom = 8
	track_style.border_color = Color(0.82, 0.68, 0.28, 0.55)
	track_style.set_border_width_all(2)
	tab_switcher.add_theme_stylebox_override("panel", track_style)

	_style_segment_tab_button(setup_tab_button)
	_style_segment_tab_button(blocks_tab_button)
	_style_segment_tab_button(goals_tab_button)


func _style_segment_tab_button(button: Button) -> void:
	var radius := 22
	var inactive := StyleBoxFlat.new()
	inactive.bg_color = Color(0, 0, 0, 0)
	inactive.set_corner_radius_all(radius)

	var inactive_hover := inactive.duplicate() as StyleBoxFlat
	inactive_hover.bg_color = Color(0.0, 0.28, 0.66, 0.08)

	var active := StyleBoxFlat.new()
	active.bg_color = UiTheme.PRIMARY
	active.set_corner_radius_all(radius)

	button.add_theme_stylebox_override("normal", inactive)
	button.add_theme_stylebox_override("hover", inactive_hover)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover_pressed", active)
	button.add_theme_stylebox_override("focus", inactive)
	button.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	button.add_theme_color_override("font_color", UiTheme.PRIMARY)
	button.add_theme_color_override("font_hover_color", UiTheme.PRIMARY)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", CREATOR_TAB_FONT)
	button.custom_minimum_size.y = 64
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
	_refresh_mix_cheat_sheet()
	_sync_grid()


func _ensure_blocks_tab() -> void:
	if _active_tab == "blocks":
		return
	_show_creator_tab("blocks")
	setup_tab_button.set_pressed_no_signal(false)
	blocks_tab_button.set_pressed_no_signal(true)
	goals_tab_button.set_pressed_no_signal(false)


func _process(delta: float) -> void:
	BRAND_RAINBOW.tick(delta)
	for host in _rainbow_hosts:
		if host == null or not is_instance_valid(host):
			continue
		var border := host.get_node_or_null("RainbowBorder") as ColorRect
		if border != null:
			UiTheme.sync_rainbow_border(border, host.size)


func _style_buttons() -> void:
	if save_button is MenuActionButton:
		(save_button as MenuActionButton).set_label(tr("UI_CREATOR_SAVE"))
		(save_button as MenuActionButton).show_trailing_icon = false
		(save_button as MenuActionButton).compact = true
	else:
		save_button.text = tr("UI_CREATOR_SAVE")
	if playtest_button is MenuActionButton:
		(playtest_button as MenuActionButton).set_label(tr("UI_CREATOR_PLAYTEST"))
		(playtest_button as MenuActionButton).show_trailing_icon = false
		(playtest_button as MenuActionButton).compact = true
	else:
		playtest_button.text = tr("UI_CREATOR_PLAYTEST")
	if clear_button is MenuActionButton:
		(clear_button as MenuActionButton).set_label(tr("UI_CREATOR_CLEAR"))
		(clear_button as MenuActionButton).show_trailing_icon = false
		(clear_button as MenuActionButton).compact = true
		(clear_button as MenuActionButton).apply_kind(MenuActionButton.Kind.DESTRUCTIVE)
	else:
		clear_button.text = tr("UI_CREATOR_CLEAR")
		UiTheme.style_danger_button(clear_button, UiTheme.ButtonScale.STANDARD)
	_refresh_action_button_styles()


func _setup_confirm_dialogs() -> void:
	_confirm_modal = EXIT_CONFIRM_SCENE.instantiate()
	add_child(_confirm_modal)
	_confirm_modal.confirmed.connect(_on_confirm_modal_confirmed)


func _setup_shape_modal() -> void:
	_shape_modal = SHAPE_MODAL_SCENE.instantiate()
	add_child(_shape_modal)
	_shape_modal.confirmed.connect(_on_shape_modal_confirmed)
	_shape_modal.deleted.connect(_on_shape_modal_deleted)


func _apply_translations() -> void:
	title_label.text = tr("UI_LEVEL_CREATOR")
	setup_tab_button.text = tr("UI_CREATOR_TAB_SETUP")
	blocks_tab_button.text = tr("UI_CREATOR_TAB_BLOCKS")
	goals_tab_button.text = tr("UI_CREATOR_TAB_GOALS")
	actions_label.text = tr("UI_CREATOR_ACTIONS")
	actions_label.visible = true
	UiTheme.style_section_subtitle(actions_label)
	if save_button is MenuActionButton:
		(save_button as MenuActionButton).set_label(tr("UI_CREATOR_SAVE"))
	else:
		save_button.text = tr("UI_CREATOR_SAVE")
	if playtest_button is MenuActionButton:
		(playtest_button as MenuActionButton).set_label(tr("UI_CREATOR_PLAYTEST"))
	else:
		playtest_button.text = tr("UI_CREATOR_PLAYTEST")
	if clear_button is MenuActionButton:
		(clear_button as MenuActionButton).set_label(tr("UI_CREATOR_CLEAR"))
	else:
		clear_button.text = tr("UI_CREATOR_CLEAR")
	if _goals_map != null:
		_goals_map.apply_translations()
	if _goal_modal_infinite != null:
		_goal_modal_infinite.text = tr("UI_CREATOR_GOAL_INFINITE")
	if _goal_modal_delete != null:
		_goal_modal_delete.text = tr("UI_CREATOR_GOAL_DELETE")
	if _shapes_header != null:
		_refresh_shape_table_header()
	if _level_details_label != null:
		_level_details_label.text = tr("UI_CREATOR_LEVEL_DETAILS")
	if _grid_details_label != null:
		_grid_details_label.text = tr("UI_CREATOR_GRID_DETAILS")
	if _subsection_label != null:
		_subsection_label.text = tr("UI_CREATOR_SUBSECTION")
	_refresh_subsection_options(_current_subsection_key())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func _build_setup_panel() -> void:
	_level_details_label = Label.new()
	_add_section_label(setup_panel, tr("UI_CREATOR_LEVEL_DETAILS"), _level_details_label)

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
	section_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	section_label.add_theme_color_override("font_color", UiTheme.TEXT)
	section_label.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	section_box.add_child(section_label)
	_section_option = OptionButton.new()
	for i in LevelCatalog.get_dimension_map_order():
		var title_key: String = LevelCatalog.SECTIONS[i]["title_key"]
		_section_option.add_item(tr(title_key), i)
	_section_option.add_item(tr("UI_DAILY_PUZZLES"), DailyCatalog.SECTION_DAILY)
	UiTheme.style_light_option_field(_section_option)
	_register_rainbow_field(_section_option)
	_style_creator_option(_section_option)
	_section_option.item_selected.connect(_on_section_changed)
	section_box.add_child(_section_option)

	_subsection_box = VBoxContainer.new()
	_subsection_box.add_theme_constant_override("separation", 8)
	section_box.add_child(_subsection_box)
	_subsection_label = Label.new()
	_subsection_label.text = tr("UI_CREATOR_SUBSECTION")
	_subsection_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	_subsection_label.add_theme_color_override("font_color", UiTheme.TEXT)
	_subsection_label.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	_subsection_box.add_child(_subsection_label)
	_subsection_option = OptionButton.new()
	UiTheme.style_light_option_field(_subsection_option)
	_register_rainbow_field(_subsection_option)
	_style_creator_option(_subsection_option)
	_subsection_option.item_selected.connect(_on_subsection_changed)
	_subsection_box.add_child(_subsection_option)

	_daily_date_box = VBoxContainer.new()
	_daily_date_box.add_theme_constant_override("separation", 8)
	_daily_date_box.visible = false
	section_box.add_child(_daily_date_box)
	var date_label := Label.new()
	date_label.text = tr("UI_CREATOR_DAILY_DATE")
	date_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	date_label.add_theme_color_override("font_color", UiTheme.TEXT)
	date_label.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
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
	_style_creator_spin(_daily_day_spin)
	date_row.add_child(_daily_day_spin)

	_daily_month_option = OptionButton.new()
	for m in range(1, 13):
		_daily_month_option.add_item(tr("UI_MONTH_%d" % m), m)
	_daily_month_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_light_option_field(_daily_month_option)
	_register_rainbow_field(_daily_month_option)
	_style_creator_option(_daily_month_option)
	_daily_month_option.item_selected.connect(_on_daily_month_selected)
	date_row.add_child(_daily_month_option)

	_daily_year_spin = SpinBox.new()
	_daily_year_spin.min_value = 2024
	_daily_year_spin.max_value = 2100
	_daily_year_spin.value = 2026
	_daily_year_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_year_spin.value_changed.connect(_on_daily_date_changed)
	_style_creator_spin(_daily_year_spin)
	date_row.add_child(_daily_year_spin)
	_set_daily_date_controls_to_today()

	setup_panel.add_child(_make_spacer(28))
	_grid_details_label = Label.new()
	_add_section_label(setup_panel, tr("UI_CREATOR_GRID_DETAILS"), _grid_details_label)

	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 12)
	setup_panel.add_child(size_row)
	_columns_field = _add_number_field(size_row, tr("UI_CREATOR_COLUMNS"), 3, 12, 8)
	_rows_field = _add_number_field(size_row, tr("UI_CREATOR_ROWS"), 3, 16, 8)
	setup_panel.add_child(_make_spacer(20))
	var apply_row := HBoxContainer.new()
	setup_panel.add_child(apply_row)
	var apply_button := _make_cta(MenuActionButton.Kind.PRIMARY, tr("UI_CREATOR_APPLY_GRID"))
	apply_button.pressed.connect(_on_apply_grid_pressed)
	apply_row.add_child(apply_button)
	setup_panel.add_child(_make_spacer(24))


func _build_blocks_panel() -> void:
	blocks_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chart := ChartModalPanel.new()
	chart.shrink_wrap = false
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	blocks_panel.add_child(chart)

	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 12)
	chart.add_child(inner)

	_shapes_header = HBoxContainer.new()
	_shapes_header.add_theme_constant_override("separation", 12)
	_shapes_header.custom_minimum_size.y = 40
	inner.add_child(_shapes_header)
	_refresh_shape_table_header()

	_shapes_list_box = VBoxContainer.new()
	_shapes_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shapes_list_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shapes_list_box.add_theme_constant_override("separation", 4)
	inner.add_child(_shapes_list_box)
	_style_blocks_scrollbar()


func _refresh_shape_table_header() -> void:
	if _shapes_header == null:
		return
	for child in _shapes_header.get_children():
		child.queue_free()
	var name_h := _shape_header_cell(tr("UI_CREATOR_SHAPE_NAME"), 0.0)
	name_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shapes_header.add_child(name_h)
	_shapes_header.add_child(_shape_header_cell(tr("UI_CREATOR_SHAPE_TYPE"), 150.0))
	_shapes_header.add_child(_shape_header_cell(tr("UI_CREATOR_SHAPE_COLOR"), 150.0))
	var actions_h := _shape_header_cell(tr("UI_AUDIT_COL_ACTIONS"), 80.0)
	actions_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shapes_header.add_child(actions_h)


func _shape_header_cell(text: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	if width > 0.0:
		label.custom_minimum_size.x = width
	return label


func _style_blocks_scrollbar() -> void:
	var bar := blocks_scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.custom_minimum_size.x = 40
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.82, 0.78, 0.70, 0.55)
	track.set_corner_radius_all(12)
	track.content_margin_left = 4
	track.content_margin_right = 4
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = UiTheme.PRIMARY
	grabber.set_corner_radius_all(12)
	var grabber_hover := grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = UiTheme.PRIMARY_HOVER
	var grabber_pressed := grabber.duplicate() as StyleBoxFlat
	grabber_pressed.bg_color = UiTheme.PRIMARY_PRESSED
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
	blocks_scroll.add_theme_constant_override("scrollbar_h_separation", 16)
	blocks_scroll.scroll_deadzone = 8


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
	UiTheme.style_light_option_field(_goal_modal_color)
	_register_rainbow_field(_goal_modal_color)
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
	UiTheme.style_light_option_field(_goal_modal_count)
	_register_rainbow_field(_goal_modal_count)
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
	_draft.group_title_key = ""
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
	_refresh_subsection_options(_draft.group_title_key.strip_edges())
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
		_draft.group_title_key = ""
	else:
		_draft.daily_date = ""
		_draft.group_title_key = _current_subsection_key()
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
	_ensure_blocks_tab()
	if cell in _disabled_cells:
		return

	var hit := grid.find_shape_at_cell(cell)
	if hit != -1:
		if _erase_mode:
			_erase_cell_from_shape(hit, cell)
			return
		if hit == _selected_shape_index:
			_open_shape_modal_edit(hit)
			return
		_on_select_shape(hit)
		return

	if _erase_mode:
		return

	if (
		_selected_shape_index >= 0
		and _selected_shape_index < _shapes.size()
		and LevelCreatorShapes.can_add_cell(
			LevelCreatorShapes.as_cells(_shapes[_selected_shape_index]["cells"]),
			cell,
			_blocked_cells_except(_selected_shape_index)
		)
	):
		var shape_cells: Array[Vector2i] = LevelCreatorShapes.as_cells(
			_shapes[_selected_shape_index]["cells"]
		)
		shape_cells.append(cell)
		_shapes[_selected_shape_index]["cells"] = shape_cells
		_sync_grid()
		return

	_open_shape_modal_create(cell)


func _on_grid_cell_edit_requested(cell: Vector2i) -> void:
	_ensure_blocks_tab()
	var hit := grid.find_shape_at_cell(cell)
	if hit == -1:
		return
	_open_shape_modal_edit(hit)


func _erase_cell_from_shape(shape_index: int, cell: Vector2i) -> void:
	var cells: Array[Vector2i] = LevelCreatorShapes.as_cells(_shapes[shape_index]["cells"])
	if not LevelCreatorShapes.can_remove_cell(cells, cell):
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
		_sync_toolbar_from_selected_shape()
	_sync_grid()


func _blocked_cells_except(ignore_index: int) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for i in _shapes.size():
		if i == ignore_index:
			continue
		for cell in LevelCreatorShapes.as_cells(_shapes[i]["cells"]):
			blocked.append(cell)
	return blocked


func _on_create_shape_pressed() -> void:
	_open_shape_modal_create(Vector2i(-1, -1))


func _open_shape_modal_create(cell: Vector2i) -> void:
	_pending_shape_cell = cell
	_shape_modal_edit_index = -1
	if _shape_modal == null:
		return
	_shape_modal.show_create(
		LevelCreatorShapes.default_shape_name(_shapes.size()),
		_selected_kind,
		_selected_color
	)


func _open_shape_modal_edit(index: int) -> void:
	if index < 0 or index >= _shapes.size() or _shape_modal == null:
		return
	_on_select_shape(index)
	_pending_shape_cell = Vector2i(-1, -1)
	_shape_modal_edit_index = index
	var shape: Dictionary = _shapes[index]
	_shape_modal.show_edit(
		str(shape.get("name", "")),
		shape.get("kind", Block.BlockKind.STANDARD),
		shape.get("color", Block.TileColor.RED)
	)


func _on_shape_modal_confirmed(shape_name: String, kind: int, color: int) -> void:
	if _shape_modal_edit_index >= 0:
		if _shape_modal_edit_index >= _shapes.size():
			_shape_modal_edit_index = -1
			return
		var shape: Dictionary = _shapes[_shape_modal_edit_index]
		shape["name"] = shape_name
		shape["kind"] = kind
		shape["color"] = color
		_shapes[_shape_modal_edit_index] = shape
		_selected_kind = kind as Block.BlockKind
		_selected_color = color as Block.TileColor
		_rebuild_shape_list_ui()
		_sync_toolbar_from_selected_shape()
		_sync_grid()
		_shape_modal_edit_index = -1
		_refresh_save_button()
		return

	var cells: Array[Vector2i] = []
	if _pending_shape_cell.x >= 0:
		cells.append(_pending_shape_cell)
	_shapes.append({
		"name": shape_name,
		"cells": cells,
		"color": color,
		"kind": kind,
	})
	_selected_shape_index = _shapes.size() - 1
	_selected_kind = kind as Block.BlockKind
	_selected_color = color as Block.TileColor
	_pending_shape_cell = Vector2i(-1, -1)
	_rebuild_shape_list_ui()
	_sync_toolbar_from_selected_shape()
	_sync_grid()
	_refresh_save_button()


func _on_shape_modal_deleted() -> void:
	var index := _shape_modal_edit_index
	_shape_modal_edit_index = -1
	_on_delete_shape(index)


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
		_shapes_list_box.add_child(_make_shape_table_row(i))
	_refreshing_shape_list = false


func _make_shape_table_row(index: int) -> PanelContainer:
	var shape: Dictionary = _shapes[index]
	var shape_kind: Block.BlockKind = shape.get("kind", Block.BlockKind.STANDARD)
	var shape_color: Block.TileColor = shape.get("color", Block.TileColor.RED)
	var selected := index == _selected_shape_index

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size.y = 72
	row.add_theme_stylebox_override("panel", _shape_row_style(selected))
	row.gui_input.connect(_on_shape_row_gui_input.bind(index))

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)

	var name_label := Label.new()
	name_label.text = str(shape.get("name", ""))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	name_label.add_theme_font_size_override("font_size", 26)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)

	var type_label := Label.new()
	type_label.text = _kind_label(shape_kind)
	type_label.custom_minimum_size.x = 150
	type_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	type_label.add_theme_font_size_override("font_size", 24)
	type_label.add_theme_color_override("font_color", UiTheme.TEXT)
	type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	type_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(type_label)

	line.add_child(_make_color_badge(shape_kind, shape_color))

	var actions := HBoxContainer.new()
	actions.custom_minimum_size.x = 80
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(actions)
	var edit_btn := CircleIconButton.new()
	edit_btn.button_size = 56
	edit_btn.fa_icon = "pencil"
	edit_btn.tooltip_key = "UI_AUDIT_EDIT"
	edit_btn.accent_color = UiTheme.PRIMARY
	edit_btn.pressed.connect(_open_shape_modal_edit.bind(index))
	actions.add_child(edit_btn)
	return row


func _shape_row_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.93, 1.0, 0.9) if selected else Color(1, 1, 1, 0.55)
	style.set_corner_radius_all(16)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _make_color_badge(kind: Block.BlockKind, color: Block.TileColor) -> PanelContainer:
	var fill := Block.WALL_FILL if Block.is_wall_kind(kind) else Block.get_color(color)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(150, 40)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(18)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	badge.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.text = tr("UI_CREATOR_KIND_WALL") if Block.is_wall_kind(kind) else _color_label(color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", _readable_text_color(fill))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _kind_label(kind: Block.BlockKind) -> String:
	match kind:
		Block.BlockKind.MERGE:
			return tr("UI_CREATOR_KIND_MERGE")
		Block.BlockKind.WALL:
			return tr("UI_CREATOR_KIND_WALL")
		_:
			return tr("UI_CREATOR_KIND_STANDARD")


func _on_shape_row_gui_input(index: int, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index == _selected_shape_index:
			_open_shape_modal_edit(index)
		else:
			_on_select_shape(index)


func _update_shape_list_row_widgets() -> void:
	_rebuild_shape_list_ui()


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
		false,
		false,
		_disabled_cells
	)
	_update_shape_list_row_widgets()
	_refresh_save_button()


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
	_sync_toolbar_kind_buttons()
	_update_shape_list_row_widgets()
	_refresh_mix_cheat_sheet()
	_sync_grid()


func _sync_toolbar_from_selected_shape() -> void:
	if _selected_shape_index < 0 or _selected_shape_index >= _shapes.size():
		_sync_color_picker_for_kind()
		_refresh_mix_cheat_sheet()
		return
	var shape: Dictionary = _shapes[_selected_shape_index]
	_selected_kind = shape.get("kind", Block.BlockKind.STANDARD)
	_selected_color = shape.get("color", Block.TileColor.RED)
	_sync_toolbar_kind_buttons()
	_sync_toolbar_color_buttons()
	_sync_color_picker_for_kind()
	_refresh_mix_cheat_sheet()


func _sync_toolbar_kind_buttons() -> void:
	for kind_key in _kind_toolbar_buttons:
		var button: Button = _kind_toolbar_buttons[kind_key]
		var selected := int(kind_key) == int(_selected_kind)
		button.set_block_signals(true)
		button.button_pressed = selected
		button.set_block_signals(false)
		if selected:
			UiTheme.style_primary_button(button, UiTheme.ButtonScale.COMPACT)
		else:
			UiTheme.style_secondary_button(button, UiTheme.ButtonScale.COMPACT)


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
	_refresh_subsection_options("")
	_on_level_field_changed()


func _on_subsection_changed(_index: int = 0) -> void:
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
	if _subsection_box != null:
		_subsection_box.visible = not show_date


func _current_subsection_key() -> String:
	if _subsection_option == null or _subsection_option.item_count <= 0:
		return ""
	var idx := _subsection_option.selected
	if idx < 0:
		return ""
	return str(_subsection_option.get_item_metadata(idx))


func _refresh_subsection_options(preferred_key: String) -> void:
	if _subsection_option == null or _section_option == null:
		return
	var section_id := _section_option.get_selected_id()
	var show_sub := section_id != DailyCatalog.SECTION_DAILY
	if _subsection_box != null:
		_subsection_box.visible = show_sub
	_subsection_option.clear()
	if not show_sub:
		return
	_subsection_option.add_item(tr("UI_CREATOR_SUBSECTION_NONE"))
	_subsection_option.set_item_metadata(0, "")
	var keys := LevelCatalog.list_group_title_keys(section_id)
	if not preferred_key.is_empty() and not keys.has(preferred_key):
		keys.append(preferred_key)
		keys.sort()
	for key in keys:
		var idx := _subsection_option.item_count
		_subsection_option.add_item(tr(key))
		_subsection_option.set_item_metadata(idx, key)
	var select_idx := 0
	for i in _subsection_option.item_count:
		if str(_subsection_option.get_item_metadata(i)) == preferred_key:
			select_idx = i
			break
	_subsection_option.select(select_idx)


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
	if save_button is MenuActionButton:
		(save_button as MenuActionButton).apply_kind(
			MenuActionButton.Kind.PRIMARY if can_save else MenuActionButton.Kind.SECONDARY
		)
		(playtest_button as MenuActionButton).apply_kind(
			MenuActionButton.Kind.SECONDARY if can_save else MenuActionButton.Kind.PRIMARY
		)
	elif can_save:
		UiTheme.style_primary_button(save_button, UiTheme.ButtonScale.STANDARD)
		UiTheme.style_secondary_button(playtest_button, UiTheme.ButtonScale.STANDARD)
	else:
		UiTheme.style_secondary_button(save_button, UiTheme.ButtonScale.STANDARD)
		_apply_compact_disabled_style(save_button)
		UiTheme.style_primary_button(playtest_button, UiTheme.ButtonScale.STANDARD)


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
	_confirm_action = "clear"
	if _confirm_modal != null and _confirm_modal.has_method("show_modal"):
		_confirm_modal.show_modal(
			"UI_CREATOR_CONFIRM_TITLE",
			"UI_CREATOR_CLEAR_CONFIRM",
			"UI_CREATOR_CLEAR",
			"UI_CANCEL"
		)


func _on_confirm_modal_confirmed() -> void:
	if _confirm_action == "clear":
		_on_clear_confirmed()
	elif _confirm_action == "back":
		_on_back_confirmed()
	_confirm_action = ""


func _on_clear_confirmed() -> void:
	_new_level()


func _on_back_pressed() -> void:
	if not _has_unsaved_changes():
		_on_back_confirmed()
		return
	_confirm_action = "back"
	if _confirm_modal != null and _confirm_modal.has_method("show_modal"):
		_confirm_modal.show_modal(
			"UI_CREATOR_CONFIRM_TITLE",
			"UI_CREATOR_BACK_CONFIRM",
			"UI_BACK",
			"UI_CANCEL"
		)


func handle_back() -> void:
	_on_back_pressed()


func _on_back_confirmed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func _set_status(_message: String) -> void:
	pass


func _register_rainbow_field(host: Control) -> void:
	if host != null and not _rainbow_hosts.has(host):
		_rainbow_hosts.append(host)


func _make_cta(kind: MenuActionButton.Kind, caption: String) -> MenuActionButton:
	var button := MenuActionButton.new()
	button.compact = true
	button.show_trailing_icon = false
	button.kind = kind
	button.label_text = caption
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


func _build_mix_cheat_sheet() -> void:
	for child in mix_cheat_sheet.get_children():
		child.queue_free()
	var title := Label.new()
	title.text = tr("UI_CREATOR_MERGE_CHEAT_TITLE")
	title.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	title.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	title.add_theme_color_override("font_color", UiTheme.TEXT)
	mix_cheat_sheet.add_child(title)
	var pairs: Array = [
		[Block.TileColor.RED, Block.TileColor.YELLOW, Block.TileColor.ORANGE],
		[Block.TileColor.YELLOW, Block.TileColor.BLUE, Block.TileColor.GREEN],
		[Block.TileColor.RED, Block.TileColor.BLUE, Block.TileColor.PURPLE],
	]
	for pair in pairs:
		mix_cheat_sheet.add_child(_make_mix_row(pair[0], pair[1], pair[2]))
	_refresh_mix_cheat_sheet()


func _make_mix_row(a: Block.TileColor, b: Block.TileColor, result: Block.TileColor) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_make_color_chip(a))
	row.add_child(_make_mix_symbol("+"))
	row.add_child(_make_color_chip(b))
	row.add_child(_make_mix_symbol("="))
	row.add_child(_make_color_chip(result))
	var name_label := Label.new()
	name_label.text = _color_label(result)
	name_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	name_label.add_theme_font_size_override("font_size", CREATOR_HINT_FONT)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT)
	row.add_child(name_label)
	return row


func _make_mix_symbol(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	return label


func _make_color_chip(color: Block.TileColor) -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 4)
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	var chip := ColorRect.new()
	chip.custom_minimum_size = Vector2(36, 36)
	chip.color = Block.get_color(color)
	wrap.add_child(chip)
	var label := Label.new()
	label.text = _color_label(color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	wrap.add_child(label)
	return wrap


func _refresh_mix_cheat_sheet() -> void:
	if mix_cheat_sheet == null:
		return
	mix_cheat_sheet.visible = (
		_active_tab == "blocks" and _selected_kind == Block.BlockKind.MERGE
	)


func _add_section_label(parent: Control, text: String, label: Label = null) -> void:
	if label == null:
		label = Label.new()
	label.text = text
	UiTheme.style_section_subtitle(label)
	parent.add_child(label)


func _add_labeled_line_edit(parent: Control, caption: String, placeholder: String = "") -> LineEdit:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_color_override("font_color", UiTheme.TEXT)
	label.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	box.add_child(label)
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	UiTheme.style_light_text_field(edit)
	_register_rainbow_field(edit)
	_style_creator_line_edit(edit)
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


func _style_creator_line_edit(edit: LineEdit) -> void:
	edit.custom_minimum_size.y = maxf(edit.custom_minimum_size.y, 72.0)
	edit.add_theme_font_size_override("font_size", CREATOR_FIELD_FONT)
	edit.add_theme_font_override("font", UiTheme.BUTTON_FONT)


func _style_creator_option(option: OptionButton) -> void:
	option.custom_minimum_size.y = maxf(option.custom_minimum_size.y, 72.0)
	option.add_theme_font_size_override("font_size", CREATOR_FIELD_FONT)
	option.add_theme_font_override("font", UiTheme.BUTTON_FONT)


func _style_creator_spin(spin: SpinBox) -> void:
	spin.custom_minimum_size.y = CREATOR_FIELD_HEIGHT
	spin.add_theme_font_size_override("font_size", CREATOR_FIELD_FONT)


func _style_compact_action_button(button: Button) -> void:
	UiTheme.style_primary_button(button, UiTheme.ButtonScale.STANDARD)


func _style_compact_secondary_button(button: Button) -> void:
	UiTheme.style_secondary_button(button, UiTheme.ButtonScale.STANDARD)


func _apply_compact_disabled_style(button: Button) -> void:
	var radius := 10
	button.add_theme_stylebox_override(
		"disabled",
		UiTheme.rounded_stylebox(Color(0.12, 0.13, 0.17, 1.0), radius)
	)
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.57, 0.62, 1.0))


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
	button.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	button.add_theme_font_size_override("font_size", CREATOR_LABEL_FONT)
	button.custom_minimum_size.y = CREATOR_FIELD_HEIGHT


func _readable_text_color(background: Color) -> Color:
	var luminance := 0.299 * background.r + 0.587 * background.g + 0.114 * background.b
	return Color.BLACK if luminance > 0.62 else Color.WHITE
