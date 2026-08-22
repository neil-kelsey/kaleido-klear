extends Control

## Develop-mode audit: dimension tables with icon actions and drag-drop reorder.

const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"
const EXIT_CONFIRM_SCENE := preload("res://scenes/ui/exit_confirm_modal.tscn")
const TITLE_FONT_SIZE := 48
const COL_LEVEL_W := 88.0
const COL_ACTIONS_W := 148.0

@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var nebula_bg: TextureRect = %NebulaBg
@onready var scroll: ScrollContainer = %Scroll
@onready var sections_container: VBoxContainer = %SectionsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var count_label: Label = %CountLabel
@onready var back_button: CircleBackButton = %BackButton

var _levels: Array[LevelConfig] = []
var _pending_delete_id: String = ""
var _editing_level: LevelConfig = null
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0

var _open_sections: Dictionary = {}
var _delete_modal: Control
var _edit_modal: Control
var _edit_section_option: OptionButton
var _edit_daily_box: VBoxContainer
var _edit_day_spin: SpinBox
var _edit_month_option: OptionButton
var _edit_year_spin: SpinBox
var _edit_status_label: Label


func _ready() -> void:
	if not OS.is_debug_build() or not GameSession.develop_mode:
		get_tree().change_scene_to_file(SETTINGS_SCENE)
		return
	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_setup_dialogs()
	back_button.pressed.connect(_on_back_button_pressed)
	_apply_translations()
	UiTheme.style_menu_hint(empty_label)
	if count_label != null:
		UiTheme.style_settings_row_label(count_label)
	_style_scrollbar()
	get_viewport().size_changed.connect(_sync_title_badge)
	_sync_title_badge()
	_refresh()


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null and nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)
	BrandRainbow.tick(delta)
	UiTheme.sync_host_rainbow_border(_edit_section_option)
	UiTheme.sync_host_rainbow_border(_edit_month_option)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		_refresh()


func _apply_translations() -> void:
	if title_badge != null:
		title_badge.title = tr("UI_AUDIT_TITLE")
		title_badge.font_size = TITLE_FONT_SIZE
		title_badge.fill_color = UiTheme.PRIMARY
		title_badge.show_rim = false
	empty_label.text = tr("UI_AUDIT_EMPTY")
	_refresh_count_label()
	if _edit_section_option != null:
		_rebuild_edit_section_items()
	_sync_title_badge()


func _style_scrollbar() -> void:
	if scroll == null:
		return
	scroll.scroll_deadzone = 8
	var bar := scroll.get_v_scroll_bar()
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
	bar.add_theme_constant_override("grabber_offset", 0)
	## Sit the bar in the chart card's right padding, clear of the action buttons.
	var panel := get_node_or_null("Margin/Panel") as PanelContainer
	if panel != null:
		var existing := panel.get_theme_stylebox("panel")
		if existing is StyleBoxFlat:
			var flat := (existing as StyleBoxFlat).duplicate() as StyleBoxFlat
			flat.content_margin_right = 20
			panel.add_theme_stylebox_override("panel", flat)
	scroll.add_theme_constant_override("scrollbar_h_separation", 16)


func _sync_title_badge() -> void:
	if title_badge == null:
		return
	var metrics := DiamondTitleBadge.measure(title_badge.title, title_badge.font_size)
	var w: float = metrics.size.x
	var h: float = metrics.size.y
	var pole_y := 108.0
	title_badge.custom_minimum_size = metrics.size
	title_badge.offset_left = -w * 0.5
	title_badge.offset_right = w * 0.5
	title_badge.offset_top = pole_y - h * 0.5
	title_badge.offset_bottom = pole_y + h * 0.5


func _setup_dialogs() -> void:
	_delete_modal = EXIT_CONFIRM_SCENE.instantiate()
	add_child(_delete_modal)
	_delete_modal.confirmed.connect(_on_delete_confirmed)

	_edit_modal = EXIT_CONFIRM_SCENE.instantiate()
	add_child(_edit_modal)
	_edit_modal.confirmed.connect(_on_edit_confirmed)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_edit_modal.extra_slot.add_child(body)

	var section_label := Label.new()
	section_label.text = tr("UI_CREATOR_SECTION")
	UiTheme.style_settings_row_label(section_label)
	body.add_child(section_label)

	_edit_section_option = OptionButton.new()
	_edit_section_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_light_option_field(_edit_section_option)
	_edit_section_option.item_selected.connect(_on_edit_section_changed)
	body.add_child(_edit_section_option)

	_edit_daily_box = VBoxContainer.new()
	_edit_daily_box.add_theme_constant_override("separation", 8)
	_edit_daily_box.visible = false
	body.add_child(_edit_daily_box)

	var date_label := Label.new()
	date_label.text = tr("UI_CREATOR_DAILY_DATE")
	UiTheme.style_settings_row_label(date_label)
	_edit_daily_box.add_child(date_label)

	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	_edit_daily_box.add_child(date_row)

	_edit_day_spin = SpinBox.new()
	_edit_day_spin.min_value = 1
	_edit_day_spin.max_value = 31
	_edit_day_spin.value = 1
	_edit_day_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_day_spin.value_changed.connect(_on_edit_date_changed)
	date_row.add_child(_edit_day_spin)

	_edit_month_option = OptionButton.new()
	for m in range(1, 13):
		_edit_month_option.add_item(tr("UI_MONTH_%d" % m), m)
	_edit_month_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_light_option_field(_edit_month_option)
	_edit_month_option.item_selected.connect(_on_edit_month_selected)
	date_row.add_child(_edit_month_option)

	_edit_year_spin = SpinBox.new()
	_edit_year_spin.min_value = 2024
	_edit_year_spin.max_value = 2100
	_edit_year_spin.value = 2026
	_edit_year_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_edit_year_spin.value_changed.connect(_on_edit_date_changed)
	date_row.add_child(_edit_year_spin)

	_edit_status_label = Label.new()
	_edit_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTheme.style_menu_hint(_edit_status_label)
	body.add_child(_edit_status_label)

	_rebuild_edit_section_items()


func _rebuild_edit_section_items() -> void:
	if _edit_section_option == null:
		return
	var selected_id := _edit_section_option.get_selected_id() if _edit_section_option.item_count > 0 else 0
	_edit_section_option.clear()
	for i in LevelCatalog.get_dimension_map_order():
		var title_key: String = LevelCatalog.SECTIONS[i]["title_key"]
		_edit_section_option.add_item(tr(title_key), i)
	_edit_section_option.add_item(tr("UI_DAILY_PUZZLES"), DailyCatalog.SECTION_DAILY)
	var idx := _edit_section_option.get_item_index(selected_id)
	if idx < 0:
		idx = 0
	_edit_section_option.select(idx)
	if _edit_month_option:
		var month_id := _edit_month_option.get_selected_id() if _edit_month_option.item_count > 0 else 1
		_edit_month_option.clear()
		for m in range(1, 13):
			_edit_month_option.add_item(tr("UI_MONTH_%d" % m), m)
		var m_idx := _edit_month_option.get_item_index(month_id)
		_edit_month_option.select(maxi(m_idx, 0))


func _refresh() -> void:
	_levels = CustomLevelStore.list_all_levels()
	_rebuild_sections()


func _dimension_levels(section_id: int) -> Array[LevelConfig]:
	var out: Array[LevelConfig] = []
	for level in _levels:
		var is_daily := DailyCatalog.is_daily_level(level) or level.section_index == DailyCatalog.SECTION_DAILY
		if is_daily:
			continue
		if level.section_index == section_id:
			out.append(level)
	LevelCatalog.sort_levels_by_chapter(out)
	return out


func _group_buckets(levels: Array[LevelConfig]) -> Array[Dictionary]:
	## Preserve chapter order (earliest sort_index in each group), then levels inside.
	var buckets: Array[Dictionary] = []
	var index_by_key: Dictionary = {}
	for level in levels:
		var key := level.group_title_key.strip_edges()
		if not index_by_key.has(key):
			index_by_key[key] = buckets.size()
			buckets.append({"key": key, "levels": [] as Array[LevelConfig]})
		var bucket: Dictionary = buckets[index_by_key[key]]
		var typed: Array[LevelConfig] = bucket["levels"]
		typed.append(level)
		bucket["levels"] = typed
	return buckets


func _daily_levels_by_date() -> Dictionary:
	## date_key -> Array[LevelConfig]
	var by_date: Dictionary = {}
	for level in _levels:
		var is_daily := DailyCatalog.is_daily_level(level) or level.section_index == DailyCatalog.SECTION_DAILY
		if not is_daily:
			continue
		var key := level.daily_date.strip_edges()
		if key.is_empty():
			key = "?"
		var bucket: Array[LevelConfig] = by_date.get(key, [] as Array[LevelConfig])
		bucket.append(level)
		by_date[key] = bucket
	for key in by_date.keys():
		var typed: Array[LevelConfig] = by_date[key]
		_sort_by_order(typed)
		by_date[key] = typed
	return by_date


func _sort_by_order(levels: Array[LevelConfig]) -> void:
	levels.sort_custom(func(a: LevelConfig, b: LevelConfig) -> bool:
		if a.sort_index == b.sort_index:
			return a.level_id < b.level_id
		return a.sort_index < b.sort_index
	)


func _group_key_dimension(section_id: int, group_title_key: String = "") -> String:
	return "dim:%d|%s" % [section_id, group_title_key]


func _group_key_daily(date_key: String) -> String:
	return "daily:%s" % date_key


func _levels_for_group(group_key: String) -> Array[LevelConfig]:
	if group_key.begins_with("dim:"):
		var rest := group_key.substr("dim:".length())
		var pipe := rest.find("|")
		if pipe < 0:
			return _dimension_levels(int(rest))
		var section_id := int(rest.substr(0, pipe))
		var title_key := rest.substr(pipe + 1)
		var out: Array[LevelConfig] = []
		for level in _dimension_levels(section_id):
			if level.group_title_key.strip_edges() == title_key:
				out.append(level)
		return out
	if group_key.begins_with("daily:"):
		var date_key := group_key.substr("daily:".length())
		var by_date := _daily_levels_by_date()
		if by_date.has(date_key):
			return by_date[date_key]
	return []


func _rebuild_sections() -> void:
	for child in sections_container.get_children():
		child.queue_free()
	var any := false
	for i in LevelCatalog.get_dimension_map_order():
		var levels := _dimension_levels(i)
		if levels.is_empty():
			continue
		any = true
		sections_container.add_child(_make_dimension_block(i, levels))
	var by_date := _daily_levels_by_date()
	if not by_date.is_empty():
		any = true
		var daily_key := "daily"
		var daily_block := VBoxContainer.new()
		daily_block.add_theme_constant_override("separation", 28)
		var daily_body := VBoxContainer.new()
		daily_body.add_theme_constant_override("separation", 20)
		daily_block.add_child(_make_fold_header(
			tr("UI_DAILY_PUZZLES"),
			daily_key,
			daily_body,
			UiTheme.PRIMARY
		))
		daily_block.add_child(daily_body)
		var dates: Array = by_date.keys()
		dates.sort()
		for date_key in dates:
			var date_title := str(date_key)
			if date_key != "?":
				date_title = DailyCatalog.format_date_key(str(date_key))
			daily_body.add_child(
				_make_table(date_title, _group_key_daily(str(date_key)), by_date[date_key], 28)
			)
		daily_body.visible = _is_section_open(daily_key)
		sections_container.add_child(daily_block)
	empty_label.visible = not any
	scroll.visible = any
	_refresh_count_label()


func _make_dimension_block(section_id: int, levels: Array[LevelConfig]) -> Control:
	var section_key := "dim:%d" % section_id
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 28)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	block.add_child(_make_fold_header(
		LevelCatalog.get_dimension_title(section_id),
		section_key,
		body,
		LevelCatalog.get_dimension_color(section_id)
	))
	block.add_child(body)

	var buckets := _group_buckets(levels)
	var has_named_group := false
	for bucket in buckets:
		if not str(bucket["key"]).is_empty():
			has_named_group = true
			break

	if not has_named_group:
		body.add_child(
			_make_table("", _group_key_dimension(section_id, ""), levels, 28, false)
		)
	else:
		for bucket in buckets:
			var key := str(bucket["key"])
			var title := tr(key) if not key.is_empty() else tr("UI_AUDIT_UNGROUPED")
			body.add_child(
				_make_table(title, _group_key_dimension(section_id, key), bucket["levels"], 28)
			)
	body.visible = _is_section_open(section_key)
	return block


func _refresh_count_label() -> void:
	if count_label == null:
		return
	count_label.text = tr("UI_AUDIT_TOTAL") % _levels.size()
	count_label.visible = not _levels.is_empty()


func _is_section_open(section_key: String) -> bool:
	return bool(_open_sections.get(section_key, false))


func _make_fold_header(title: String, section_key: String, body: Control, accent: Color) -> Button:
	var header := Button.new()
	header.flat = true
	header.focus_mode = Control.FOCUS_NONE
	header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header.custom_minimum_size.y = 88
	header.clip_contents = false
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		header.add_theme_stylebox_override(state, empty)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	header.add_child(row)

	var label := Label.new()
	label.text = title
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.style_section_subtitle(label)
	row.add_child(label)

	var chevron := FaIconView.new()
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.custom_minimum_size = Vector2(36, 36)
	chevron.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chevron.icon_color = accent
	_sync_fold_icon(chevron, _is_section_open(section_key))
	row.add_child(chevron)

	header.pressed.connect(_on_fold_header_pressed.bind(section_key, body, chevron))
	return header


func _on_fold_header_pressed(section_key: String, body: Control, chevron: FaIconView) -> void:
	var open := not _is_section_open(section_key)
	_open_sections[section_key] = open
	if body != null:
		body.visible = open
	_sync_fold_icon(chevron, open)


func _sync_fold_icon(chevron: FaIconView, open: bool) -> void:
	if chevron == null:
		return
	chevron.icon_name = "chevron-down" if open else "chevron-right"
	chevron.queue_redraw()


func _make_table(
	title: String,
	group_key: String,
	levels: Array[LevelConfig],
	title_size: int = 36,
	show_title: bool = true
) -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 12)
	block.set_meta("group_key", group_key)

	if show_title and not title.is_empty():
		var title_label := Label.new()
		title_label.text = title
		title_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
		title_label.add_theme_font_size_override("font_size", title_size)
		title_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
		block.add_child(title_label)

	block.add_child(_make_header_row())

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	rows.set_meta("group_key", group_key)
	block.add_child(rows)

	for i in levels.size():
		rows.add_child(_AuditRow.new(self, group_key, levels[i], i + 1))

	return block


func _make_header_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size.y = 40

	var level_h := _header_cell(tr("UI_AUDIT_COL_LEVEL"), COL_LEVEL_W)
	row.add_child(level_h)

	var name_h := _header_cell(tr("UI_AUDIT_COL_NAME"), 0.0)
	name_h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_h)

	var actions_h := _header_cell(tr("UI_AUDIT_COL_ACTIONS"), COL_ACTIONS_W)
	actions_h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(actions_h)

	return row


func _header_cell(text: String, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	if width > 0.0:
		label.custom_minimum_size.x = width
	return label


func reorder_group(group_key: String, from_index: int, to_index: int) -> void:
	if from_index == to_index or from_index < 0 or to_index < 0:
		return
	var levels := _levels_for_group(group_key)
	if from_index >= levels.size() or to_index >= levels.size():
		return
	var moved: LevelConfig = levels[from_index]
	levels.remove_at(from_index)
	levels.insert(to_index, moved)

	## Keep other chapters' sort ranges; only permute this table's existing indexes.
	var slots: Array[int] = []
	for level in levels:
		slots.append(level.sort_index)
	slots.sort()
	var to_save: Array[LevelConfig] = []
	for i in levels.size():
		if levels[i].sort_index == slots[i]:
			continue
		levels[i].sort_index = slots[i]
		to_save.append(levels[i])
	if not to_save.is_empty():
		var err := CustomLevelStore.save_levels(to_save)
		if err != OK:
			push_warning("Audit reorder save failed: %s" % error_string(err))
	call_deferred("_refresh")


func _on_delete_pressed(level_id: String) -> void:
	_pending_delete_id = level_id
	var level := _find_level(level_id)
	var label := LevelCatalog.get_level_label(level) if level else level_id
	_delete_modal.show_modal(
		"UI_AUDIT_DELETE_TITLE",
		"UI_AUDIT_DELETE_CONFIRM",
		"UI_AUDIT_DELETE",
		"UI_CANCEL",
		[label],
		true
	)


func _on_delete_confirmed() -> void:
	if _pending_delete_id.is_empty():
		return
	var err := CustomLevelStore.delete_level(_pending_delete_id)
	_pending_delete_id = ""
	if err != OK:
		push_warning("Level audit delete failed: %s" % error_string(err))
	_refresh()


func _on_edit_pressed(level_id: String) -> void:
	var level := CustomLevelStore.load_level(level_id)
	if level == null:
		return
	_editing_level = level
	_edit_status_label.text = ""
	var section_id := DailyCatalog.SECTION_DAILY if DailyCatalog.is_daily_level(level) else level.section_index
	var idx := _edit_section_option.get_item_index(section_id)
	_edit_section_option.select(maxi(idx, 0))
	if DailyCatalog.is_daily_level(level):
		_set_edit_date_from_key(level.daily_date)
	else:
		_set_edit_date_from_key(DailyCatalog.today_key())
	_refresh_edit_daily_visibility()
	_edit_modal.show_modal(
		"UI_AUDIT_EDIT_TITLE",
		"",
		"UI_AUDIT_SAVE",
		"UI_CANCEL"
	)


func _on_edit_section_changed(_index: int = 0) -> void:
	_refresh_edit_daily_visibility()


func _refresh_edit_daily_visibility() -> void:
	if _edit_daily_box == null or _edit_section_option == null:
		return
	_edit_daily_box.visible = _edit_section_option.get_selected_id() == DailyCatalog.SECTION_DAILY


func _on_edit_month_selected(_index: int = 0) -> void:
	_clamp_edit_day()


func _on_edit_date_changed(_value: float = 0.0) -> void:
	_clamp_edit_day()


func _clamp_edit_day() -> void:
	if _edit_day_spin == null or _edit_month_option == null or _edit_year_spin == null:
		return
	var year := int(_edit_year_spin.value)
	var month := _edit_month_option.get_selected_id()
	var max_day := _days_in_month(year, month)
	_edit_day_spin.max_value = max_day
	if int(_edit_day_spin.value) > max_day:
		_edit_day_spin.value = max_day


func _days_in_month(year: int, month: int) -> int:
	var lengths: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if month < 1 or month > 12:
		return 31
	var days := lengths[month - 1]
	if month == 2 and ((year % 4 == 0 and year % 100 != 0) or year % 400 == 0):
		days = 29
	return days


func _set_edit_date_from_key(date_key: String) -> void:
	var parts := date_key.strip_edges().split("-")
	if parts.size() != 3:
		return
	_edit_year_spin.value = int(parts[0])
	var m_idx := _edit_month_option.get_item_index(int(parts[1]))
	_edit_month_option.select(maxi(m_idx, 0))
	_edit_day_spin.value = int(parts[2])
	_clamp_edit_day()


func _edit_date_key() -> String:
	var year := int(_edit_year_spin.value)
	var month := _edit_month_option.get_selected_id()
	var day := int(_edit_day_spin.value)
	return "%04d-%02d-%02d" % [year, month, day]


func _on_edit_confirmed() -> void:
	if _editing_level == null:
		return
	var section_id := _edit_section_option.get_selected_id()
	if section_id == DailyCatalog.SECTION_DAILY:
		var date_key := _edit_date_key()
		if date_key.is_empty():
			_edit_status_label.text = tr("UI_CREATOR_ERROR_DAILY_DATE")
			call_deferred("_reopen_edit_dialog")
			return
		_editing_level.section_index = DailyCatalog.SECTION_DAILY
		_editing_level.daily_date = date_key
	else:
		_editing_level.section_index = section_id
		_editing_level.daily_date = ""
	var err := CustomLevelStore.save_level(_editing_level)
	_editing_level = null
	if err != OK:
		push_warning("Level audit save failed: %s" % error_string(err))
	elif not CustomLevelStore.saves_to_project() and LevelCatalog != null:
		LevelCatalog.reload_levels()
	_refresh()


func _reopen_edit_dialog() -> void:
	if _edit_modal:
		_edit_modal.show_modal(
			"UI_AUDIT_EDIT_TITLE",
			"",
			"UI_AUDIT_SAVE",
			"UI_CANCEL"
		)


func _find_level(level_id: String) -> LevelConfig:
	for level in _levels:
		if level.level_id == level_id:
			return level
	return null


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func handle_back() -> void:
	if _edit_modal != null and _edit_modal.visible:
		_edit_modal.hide_modal()
		_editing_level = null
		return
	if _delete_modal != null and _delete_modal.visible:
		_delete_modal.hide_modal()
		_pending_delete_id = ""
		return
	_on_back_button_pressed()


class _AuditRow extends PanelContainer:
	const ROW_H := 72.0
	const LEVEL_W := 60.0
	const ACTIONS_W := 148.0
	const BTN := 56

	var audit: Control
	var group_key: String = ""
	var level_id: String = ""
	var order_index: int = 1
	var _order_label: Label
	var _name_label: Label

	func _init(host: Control, key: String, level: LevelConfig, order: int) -> void:
		audit = host
		group_key = key
		level_id = level.level_id
		order_index = order
		## PASS lets click-drag on the name scroll the list; reorder stays on the handle.
		mouse_filter = Control.MOUSE_FILTER_PASS
		custom_minimum_size.y = ROW_H
		_build(level)

	func _build(level: LevelConfig) -> void:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.55)
		style.set_corner_radius_all(16)
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 8
		style.content_margin_bottom = 8
		add_theme_stylebox_override("panel", style)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(row)

		var drag_zone := _DragZone.new(self)
		row.add_child(drag_zone)

		_name_label = Label.new()
		_name_label.text = LevelCatalog.get_level_label(level)
		_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_name_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
		_name_label.add_theme_font_size_override("font_size", 26)
		_name_label.add_theme_color_override("font_color", UiTheme.TEXT)
		_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_name_label.clip_text = true
		_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_name_label)

		var actions := HBoxContainer.new()
		actions.custom_minimum_size.x = ACTIONS_W
		actions.alignment = BoxContainer.ALIGNMENT_CENTER
		actions.add_theme_constant_override("separation", 10)
		actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(actions)

		var edit_btn := CircleIconButton.new()
		edit_btn.button_size = BTN
		edit_btn.fa_icon = "pencil"
		edit_btn.tooltip_key = "UI_AUDIT_EDIT"
		edit_btn.accent_color = UiTheme.PRIMARY
		edit_btn.pressed.connect(func() -> void: audit._on_edit_pressed(level_id))
		actions.add_child(edit_btn)

		var delete_btn := CircleIconButton.new()
		delete_btn.button_size = BTN
		delete_btn.fa_icon = "trash"
		delete_btn.tooltip_key = "UI_AUDIT_DELETE"
		delete_btn.accent_color = UiTheme.PLAY
		delete_btn.pressed.connect(func() -> void: audit._on_delete_pressed(level_id))
		actions.add_child(delete_btn)

	func _drag_payload() -> Dictionary:
		return {"group_key": group_key, "from_index": order_index - 1, "level_id": level_id}

	func _drag_preview_text() -> String:
		return _name_label.text if _name_label else level_id

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END:
			modulate = Color.WHITE

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		return str(data.get("group_key", "")) == group_key

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		if not _can_drop_data(_at_position, data):
			return
		var from_index := int(data.get("from_index", -1))
		## Dropping on a row moves the dragged level to that row's index.
		var to_index := order_index - 1
		if audit != null and audit.has_method("reorder_group"):
			audit.reorder_group(group_key, from_index, to_index)


class _DragZone extends HBoxContainer:
	var _row: _AuditRow

	func _init(row: _AuditRow) -> void:
		_row = row
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_constant_override("separation", 12)
		alignment = BoxContainer.ALIGNMENT_CENTER

		var grip := _GripIcon.new()
		grip.custom_minimum_size = Vector2(28, 28)
		grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(grip)

		var order := Label.new()
		order.text = str(row.order_index)
		order.custom_minimum_size.x = _AuditRow.LEVEL_W
		order.add_theme_font_override("font", UiTheme.BUTTON_FONT)
		order.add_theme_font_size_override("font_size", 28)
		order.add_theme_color_override("font_color", UiTheme.TEXT)
		order.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		order.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(order)
		row._order_label = order

	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		return _row._can_drop_data(at_position, data)

	func _drop_data(at_position: Vector2, data: Variant) -> void:
		_row._drop_data(at_position, data)

	func _get_drag_data(_at_position: Vector2) -> Variant:
		var preview := Label.new()
		preview.text = _row._drag_preview_text()
		preview.add_theme_font_size_override("font_size", 24)
		preview.add_theme_color_override("font_color", UiTheme.TEXT)
		set_drag_preview(preview)
		_row.modulate = Color(1, 1, 1, 0.45)
		return _row._drag_payload()


class _GripIcon extends Control:
	func _draw() -> void:
		FaVector.draw_named(self, "bars", size * 0.5, minf(size.x, size.y) * 0.7, UiTheme.TEXT_MUTED)
