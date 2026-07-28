extends Control

## Develop-mode audit: list every level, reassign placement, delete with confirm.

const SETTINGS_SCENE := "res://scenes/ui/settings.tscn"

@onready var title_label: Label = %TitleLabel
@onready var summary_label: Label = %SummaryLabel
@onready var rows_container: VBoxContainer = %RowsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var back_button: Button = %BackButton

var _levels: Array[LevelConfig] = []
var _pending_delete_id: String = ""
var _editing_level: LevelConfig = null

var _delete_confirm: ConfirmationDialog
var _edit_dialog: ConfirmationDialog
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
	_setup_dialogs()
	_apply_translations()
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_hint(summary_label)
	UiTheme.style_menu_hint(empty_label)
	UiTheme.style_nav_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		_refresh()


func _apply_translations() -> void:
	title_label.text = tr("UI_AUDIT_TITLE")
	back_button.text = "  " + tr("UI_BACK")
	empty_label.text = tr("UI_AUDIT_EMPTY")
	if _delete_confirm:
		_delete_confirm.title = tr("UI_AUDIT_DELETE_TITLE")
		_delete_confirm.ok_button_text = tr("UI_AUDIT_DELETE")
		_delete_confirm.cancel_button_text = tr("UI_CANCEL")
	if _edit_dialog:
		_edit_dialog.title = tr("UI_AUDIT_EDIT_TITLE")
		_edit_dialog.ok_button_text = tr("UI_AUDIT_SAVE")
		_edit_dialog.cancel_button_text = tr("UI_CANCEL")
		_rebuild_edit_section_items()


func _setup_dialogs() -> void:
	_delete_confirm = ConfirmationDialog.new()
	_delete_confirm.confirmed.connect(_on_delete_confirmed)
	add_child(_delete_confirm)

	_edit_dialog = ConfirmationDialog.new()
	_edit_dialog.min_size = Vector2(520, 360)
	_edit_dialog.dialog_text = ""
	_edit_dialog.confirmed.connect(_on_edit_confirmed)
	add_child(_edit_dialog)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	_edit_dialog.add_child(body)

	var section_label := Label.new()
	section_label.text = tr("UI_CREATOR_SECTION")
	body.add_child(section_label)

	_edit_section_option = OptionButton.new()
	_edit_section_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_option_field(_edit_section_option)
	_edit_section_option.item_selected.connect(_on_edit_section_changed)
	body.add_child(_edit_section_option)

	_edit_daily_box = VBoxContainer.new()
	_edit_daily_box.add_theme_constant_override("separation", 8)
	_edit_daily_box.visible = false
	body.add_child(_edit_daily_box)

	var date_label := Label.new()
	date_label.text = tr("UI_CREATOR_DAILY_DATE")
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
	UiTheme.style_option_field(_edit_month_option)
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
	body.add_child(_edit_status_label)

	_rebuild_edit_section_items()


func _rebuild_edit_section_items() -> void:
	if _edit_section_option == null:
		return
	var selected_id := _edit_section_option.get_selected_id() if _edit_section_option.item_count > 0 else 0
	_edit_section_option.clear()
	for i in LevelCatalog.SECTIONS.size():
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
	_rebuild_summary()
	_rebuild_rows()


func _rebuild_summary() -> void:
	var lines: PackedStringArray = []
	var dim_counts: Array[int] = []
	dim_counts.resize(LevelCatalog.SECTIONS.size())
	dim_counts.fill(0)
	var daily_by_date: Dictionary = {}
	var daily_total := 0

	for level in _levels:
		if DailyCatalog.is_daily_level(level) or level.section_index == DailyCatalog.SECTION_DAILY:
			daily_total += 1
			var key := level.daily_date.strip_edges()
			if key.is_empty():
				key = "?"
			daily_by_date[key] = int(daily_by_date.get(key, 0)) + 1
		else:
			var idx := clampi(level.section_index, 0, LevelCatalog.SECTIONS.size() - 1)
			dim_counts[idx] += 1

	lines.append(tr("UI_AUDIT_TOTAL") % _levels.size())
	for i in dim_counts.size():
		lines.append("%s: %d" % [LevelCatalog.get_dimension_title(i), dim_counts[i]])

	lines.append(tr("UI_AUDIT_DAILY_TOTAL") % [daily_total, daily_by_date.size()])
	var missing := _missing_daily_dates(daily_by_date)
	if daily_by_date.is_empty():
		lines.append(tr("UI_AUDIT_DAILY_NONE"))
	elif missing.is_empty():
		lines.append(tr("UI_AUDIT_DAILY_COMPLETE"))
	else:
		var shown: PackedStringArray = []
		for i in mini(missing.size(), 8):
			shown.append(DailyCatalog.format_date_key(missing[i]))
		var extra := missing.size() - shown.size()
		var missing_text := ", ".join(shown)
		if extra > 0:
			missing_text += tr("UI_AUDIT_DAILY_MORE") % extra
		lines.append(tr("UI_AUDIT_DAILY_GAPS") % missing_text)

	summary_label.text = "\n".join(lines)


func _missing_daily_dates(daily_by_date: Dictionary) -> PackedStringArray:
	var keys: Array = daily_by_date.keys()
	keys = keys.filter(func(k: Variant) -> bool: return str(k) != "?" and str(k).length() == 10)
	keys.sort()
	if keys.size() < 2:
		return PackedStringArray()
	var missing: PackedStringArray = []
	var cursor := str(keys[0])
	var end_key := str(keys[keys.size() - 1])
	while cursor < end_key:
		cursor = _next_day_key(cursor)
		if cursor >= end_key:
			break
		if not daily_by_date.has(cursor):
			missing.append(cursor)
	return missing


func _next_day_key(date_key: String) -> String:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return date_key
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	})
	var next := Time.get_datetime_dict_from_unix_time(unix + 86400)
	return "%04d-%02d-%02d" % [int(next.year), int(next.month), int(next.day)]


func _rebuild_rows() -> void:
	for child in rows_container.get_children():
		child.queue_free()
	empty_label.visible = _levels.is_empty()
	for level in _levels:
		rows_container.add_child(_make_row(level))


func _make_row(level: LevelConfig) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.18, 1.0)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var name_label := Label.new()
	name_label.text = LevelCatalog.get_level_label(level)
	name_label.add_theme_color_override("font_color", UiTheme.TEXT_ON_DARK)
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)

	var place_label := Label.new()
	place_label.text = _placement_text(level)
	place_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78, 1.0))
	place_label.add_theme_font_size_override("font_size", 22)
	place_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(place_label)

	var id_label := Label.new()
	id_label.text = level.level_id
	id_label.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58, 1.0))
	id_label.add_theme_font_size_override("font_size", 18)
	id_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(id_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	col.add_child(actions)

	var edit_button := Button.new()
	edit_button.text = tr("UI_AUDIT_EDIT")
	edit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_secondary_button(edit_button, UiTheme.ButtonScale.HUD)
	edit_button.pressed.connect(_on_edit_pressed.bind(level.level_id))
	actions.add_child(edit_button)

	var delete_button := Button.new()
	delete_button.text = tr("UI_AUDIT_DELETE")
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_danger_button(delete_button, UiTheme.ButtonScale.HUD)
	delete_button.pressed.connect(_on_delete_pressed.bind(level.level_id))
	actions.add_child(delete_button)

	return panel


func _placement_text(level: LevelConfig) -> String:
	if DailyCatalog.is_daily_level(level) or level.section_index == DailyCatalog.SECTION_DAILY:
		var date_key := level.daily_date.strip_edges()
		if date_key.is_empty():
			return tr("UI_DAILY_PUZZLES")
		return "%s · %s" % [tr("UI_DAILY_PUZZLES"), DailyCatalog.format_date_key(date_key)]
	return LevelCatalog.get_dimension_title(clampi(level.section_index, 0, LevelCatalog.SECTIONS.size() - 1))


func _on_delete_pressed(level_id: String) -> void:
	_pending_delete_id = level_id
	var level := _find_level(level_id)
	var label := LevelCatalog.get_level_label(level) if level else level_id
	_delete_confirm.dialog_text = tr("UI_AUDIT_DELETE_CONFIRM") % label
	_delete_confirm.popup_centered()


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
	_edit_dialog.popup_centered()


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
		## Editor save_level already reloads; user:// saves need an explicit refresh.
		LevelCatalog.reload_levels()
	_refresh()


func _reopen_edit_dialog() -> void:
	if _edit_dialog:
		_edit_dialog.popup_centered()


func _find_level(level_id: String) -> LevelConfig:
	for level in _levels:
		if level.level_id == level_id:
			return level
	return null


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(SETTINGS_SCENE)


func handle_back() -> void:
	_on_back_button_pressed()
