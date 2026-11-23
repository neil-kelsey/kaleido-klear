extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LEVEL_CREATOR_SCENE := "res://scenes/editor/level_creator.tscn"
const LEVEL_AUDIT_SCENE := "res://scenes/ui/level_audit.tscn"
const Reminders := preload("res://scritps/StreakReminder.gd")
const SettingsToggleScript := preload("res://scritps/ui/SettingsToggle.gd")
const TITLE_FONT_SIZE := 48
## Standalone Kaleido Klear privacy page on the studio site.
const PRIVACY_POLICY_URL := "https://veilmoth.com/privacy/kaleido-klear/"

## Gold section titles, matching Daily puzzle captions on the nebula.
const SECTION_TITLE_COLOR := Color(1.0, 0.90, 0.62, 0.92)
const SECTION_TITLE_SIZE := 44
const ROW_LABEL_COLOR := Color(0.95, 0.95, 0.97, 1.0)
const HINT_COLOR := Color(1.0, 0.95, 0.85, 0.82)

enum ResetKind { NONE, PROGRESS, TUTORIALS }

@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var nebula_bg: TextureRect = %NebulaBg
@onready var back_button: CircleBackButton = %BackButton
@onready var preferences_title: Label = %PreferencesTitle
@onready var data_title: Label = %DataTitle
@onready var developer_title: Label = %DeveloperTitle
@onready var developer_section: VBoxContainer = %DeveloperSection
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var sound_label: Label = %SoundLabel
@onready var sound_toggle: SettingsToggleScript = %SoundToggle
@onready var develop_mode_row: HBoxContainer = %DevelopModeRow
@onready var develop_mode_label: Label = %DevelopModeLabel
@onready var develop_mode_toggle: SettingsToggleScript = %DevelopModeToggle
@onready var level_creator_button: MenuActionButton = %LevelCreatorButton
@onready var level_audit_button: MenuActionButton = %LevelAuditButton
@onready var reset_tutorials_button: MenuActionButton = %ResetTutorialsButton
@onready var reset_progress_button: MenuActionButton = %ResetProgressButton
@onready var reset_confirm_modal: Control = %ResetConfirmModal
@onready var ads_title: Label = %AdsTitle
@onready var remove_ads_settings_button: MenuActionButton = %RemoveAdsSettingsButton
@onready var restore_purchases_button: MenuActionButton = %RestorePurchasesButton
@onready var privacy_settings_button: MenuActionButton = %PrivacySettingsButton
@onready var privacy_policy_button: MenuActionButton = %PrivacyPolicyButton
@onready var ads_status_label: Label = %AdsStatusLabel
@onready var notifications_title: Label = %NotificationsTitle
@onready var reminder_label: Label = %ReminderLabel
@onready var reminder_toggle: SettingsToggleScript = %ReminderToggle
@onready var reminder_time_row: VBoxContainer = %ReminderTimeRow
@onready var reminder_time_label: Label = %ReminderTimeLabel
@onready var reminder_time_button: Button = %ReminderTimeButton
@onready var reminder_test_button: MenuActionButton = %ReminderTestButton
@onready var time_picker = %TimePicker

var _updating_language_option := false
var _pending_reset: ResetKind = ResetKind.NONE
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0


func _ready() -> void:
	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_populate_language_option()
	_apply_translations()
	back_button.pressed.connect(_on_back_button_pressed)
	if time_picker != null:
		time_picker.confirmed.connect(_on_time_confirmed)
		time_picker.cancelled.connect(_on_time_cancelled)
	_style_section_title(preferences_title)
	_style_section_title(data_title)
	_style_section_title(developer_title)
	_style_section_title(ads_title)
	if notifications_title != null:
		_style_section_title(notifications_title)
	UiTheme.style_menu_hint(ads_status_label)
	if ads_status_label != null:
		ads_status_label.add_theme_color_override("font_color", HINT_COLOR)
	Ads.ads_removed_changed.connect(func(_r: bool) -> void: _sync_ads_section())
	Ads.privacy_options_changed.connect(_sync_ads_section)
	Ads.store_status.connect(_on_ads_store_status)
	_sync_ads_section()
	_style_row_label(language_label)
	UiTheme.style_settings_option_field(language_option)
	_style_row_label(sound_label)
	if sound_toggle != null:
		sound_toggle.sync_pressed(GameSession.sfx_enabled)
		_wire_toggle_row(%SoundRow, sound_toggle)
	if reminder_label != null:
		_style_row_label(reminder_label)
	if reminder_toggle != null:
		reminder_toggle.sync_pressed(GameSession.daily_reminders)
		_wire_toggle_row(%ReminderRow, reminder_toggle)
	if reminder_time_label != null:
		_style_row_label(reminder_time_label)
	_style_reminder_time_button()
	_sync_reminder_rows()
	_style_row_label(develop_mode_label)
	if OS.is_debug_build():
		developer_section.visible = true
		develop_mode_row.visible = true
		if develop_mode_toggle != null:
			develop_mode_toggle.sync_pressed(GameSession.develop_mode)
			_wire_toggle_row(develop_mode_row, develop_mode_toggle)
		level_creator_button.visible = GameSession.develop_mode
		level_audit_button.visible = GameSession.develop_mode
		_sync_reminder_test()
	else:
		developer_section.visible = false
		level_creator_button.visible = false
		level_audit_button.visible = false
		_sync_reminder_test()
	_style_scroll()
	get_viewport().size_changed.connect(_sync_title_badge)
	_sync_title_badge()


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null and nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)
	BrandRainbow.tick(delta)
	UiTheme.sync_host_rainbow_border(language_option)
	if reminder_time_button != null and reminder_time_button.visible:
		UiTheme.sync_host_rainbow_border(reminder_time_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func _populate_language_option() -> void:
	_updating_language_option = true
	language_option.clear()
	var selected := 0
	for i in GameSession.AVAILABLE_LOCALES.size():
		var entry: Dictionary = GameSession.AVAILABLE_LOCALES[i]
		var code := str(entry.code)
		language_option.add_item(tr(str(entry.name_key)), i)
		language_option.set_item_metadata(i, code)
		if code == GameSession.locale:
			selected = i
	language_option.select(selected)
	_updating_language_option = false


func _apply_translations() -> void:
	if language_option == null:
		return
	if title_badge != null:
		title_badge.title = tr("UI_SETTINGS_TITLE")
		title_badge.font_size = TITLE_FONT_SIZE
		title_badge.fill_color = UiTheme.PRIMARY
		title_badge.show_rim = false
	language_label.text = tr("UI_LANGUAGE")
	sound_label.text = tr("UI_SOUND")
	develop_mode_label.text = tr("UI_DEVELOP_MODE")
	if preferences_title != null:
		preferences_title.text = tr("UI_SETTINGS_PREFERENCES")
		_style_section_title(preferences_title)
	if data_title != null:
		data_title.text = tr("UI_SETTINGS_DATA")
		_style_section_title(data_title)
	if developer_title != null:
		developer_title.text = tr("UI_SETTINGS_DEVELOPER")
		_style_section_title(developer_title)
	level_creator_button.set_label(tr("UI_LEVEL_CREATOR"))
	level_audit_button.set_label(tr("UI_LEVEL_AUDIT"))
	reset_tutorials_button.set_label(tr("UI_RESET_TUTORIALS"))
	reset_progress_button.set_label(tr("UI_RESET_PROGRESS"))
	if notifications_title != null:
		notifications_title.text = tr("UI_SETTINGS_NOTIFICATIONS")
		_style_section_title(notifications_title)
	if reminder_label != null:
		reminder_label.text = tr("UI_DAILY_REMINDERS")
	if reminder_time_label != null:
		reminder_time_label.text = tr("UI_REMINDER_TIME_LABEL")
	_sync_reminder_rows()
	if reminder_test_button != null:
		reminder_test_button.set_label(tr("UI_REMINDER_TEST"))
	if ads_title != null:
		ads_title.text = tr("UI_SETTINGS_ADS")
		_style_section_title(ads_title)
	remove_ads_settings_button.set_label(tr("UI_REMOVE_ADS"))
	restore_purchases_button.set_label(tr("UI_RESTORE_PURCHASES"))
	privacy_settings_button.set_label(tr("UI_PRIVACY_SETTINGS"))
	if privacy_policy_button != null:
		privacy_policy_button.set_label(tr("UI_PRIVACY_POLICY"))
	_sync_ads_section()
	_populate_language_option()
	_sync_title_badge()


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



func _style_section_title(label: Label) -> void:
	if label == null:
		return
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_color_override("font_color", SECTION_TITLE_COLOR)
	label.add_theme_font_size_override("font_size", SECTION_TITLE_SIZE)
	label.set_meta("ui_section_subtitle", true)


func _style_row_label(label: Label) -> void:
	if label == null:
		return
	UiTheme.style_settings_row_label(label)
	label.add_theme_color_override("font_color", ROW_LABEL_COLOR)


func _style_scroll() -> void:
	var scroll := get_node_or_null("%Scroll") as ScrollContainer
	if scroll == null:
		return
	var bar := scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.custom_minimum_size.x = 12
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.08)
	track.set_corner_radius_all(6)
	track.content_margin_left = 2
	track.content_margin_right = 2
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1.0, 0.90, 0.62, 0.55)
	grab.set_corner_radius_all(6)
	var grab_hi := grab.duplicate()
	grab_hi.bg_color = Color(1.0, 0.90, 0.62, 0.75)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grab)
	bar.add_theme_stylebox_override("grabber_highlight", grab_hi)
	bar.add_theme_stylebox_override("grabber_pressed", grab_hi)


func _wire_toggle_row(row: Control, toggle: SettingsToggleScript) -> void:
	if row == null or toggle == null:
		return
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			var mouse := event as InputEventMouseButton
			if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
				if not toggle.get_global_rect().has_point(mouse.global_position):
					toggle.button_pressed = not toggle.button_pressed
	)


func _on_language_option_item_selected(index: int) -> void:
	if _updating_language_option:
		return
	var code := str(language_option.get_item_metadata(index))
	GameSession.set_locale(code)


func _on_sound_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_sfx_enabled(enabled)


func _style_reminder_time_button() -> void:
	if reminder_time_button == null:
		return
	var normal := UiTheme.settings_option_field_stylebox(false)
	var focus := UiTheme.settings_option_field_stylebox(true)
	reminder_time_button.add_theme_stylebox_override("normal", normal)
	reminder_time_button.add_theme_stylebox_override("hover", focus)
	reminder_time_button.add_theme_stylebox_override("pressed", focus)
	reminder_time_button.add_theme_stylebox_override("focus", focus)
	reminder_time_button.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	reminder_time_button.add_theme_font_size_override("font_size", 32)
	reminder_time_button.add_theme_color_override("font_color", UiTheme.TEXT)
	reminder_time_button.add_theme_color_override("font_hover_color", UiTheme.TEXT)
	reminder_time_button.add_theme_color_override("font_pressed_color", UiTheme.TEXT)
	reminder_time_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	reminder_time_button.custom_minimum_size = Vector2(0, 72)


func _sync_reminder_rows() -> void:
	if reminder_toggle != null:
		reminder_toggle.sync_pressed(GameSession.daily_reminders)
	if reminder_time_row != null:
		reminder_time_row.visible = GameSession.daily_reminders
	if reminder_time_button != null:
		reminder_time_button.text = Reminders.format_clock(GameSession.reminder_hour, GameSession.reminder_minute)


func _sync_reminder_test() -> void:
	if reminder_test_button == null:
		return
	reminder_test_button.visible = OS.is_debug_build() and GameSession.develop_mode


func _on_reminder_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_daily_reminders(enabled)
	_sync_reminder_rows()


func _on_reminder_time_pressed() -> void:
	if time_picker != null:
		time_picker.open_at(GameSession.reminder_hour, GameSession.reminder_minute)


func _on_time_confirmed(hour: int, minute: int) -> void:
	GameSession.set_reminder_time(hour, minute)
	_sync_reminder_rows()


func _on_time_cancelled() -> void:
	pass


func _on_reminder_test_button_pressed() -> void:
	GameSession.test_daily_reminder()


func _on_develop_mode_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_develop_mode(enabled)
	level_creator_button.visible = enabled
	level_audit_button.visible = enabled
	_sync_reminder_test()


func _on_level_creator_button_pressed() -> void:
	GameSession.begin_fresh_creator()
	get_tree().change_scene_to_file(LEVEL_CREATOR_SCENE)


func _on_level_audit_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_AUDIT_SCENE)


func _on_reset_tutorials_button_pressed() -> void:
	_pending_reset = ResetKind.TUTORIALS
	reset_confirm_modal.show_modal(
		"UI_RESET_TUTORIALS_TITLE",
		"UI_RESET_TUTORIALS_CONFIRM",
		"UI_RESET_TUTORIALS_YES",
		"UI_NO"
	)


func _on_reset_progress_button_pressed() -> void:
	_pending_reset = ResetKind.PROGRESS
	reset_confirm_modal.show_modal(
		"UI_RESET_PROGRESS_TITLE",
		"UI_RESET_PROGRESS_CONFIRM",
		"UI_RESET_PROGRESS_YES",
		"UI_NO"
	)


func _on_reset_confirm_modal_confirmed() -> void:
	match _pending_reset:
		ResetKind.TUTORIALS:
			GameSession.reset_tutorials()
		ResetKind.PROGRESS:
			GameSession.reset_progress()
	_pending_reset = ResetKind.NONE


func _on_reset_confirm_modal_cancelled() -> void:
	_pending_reset = ResetKind.NONE


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func handle_back() -> void:
	if time_picker != null and time_picker.visible:
		time_picker.close()
		return
	if reset_confirm_modal != null and reset_confirm_modal.visible:
		reset_confirm_modal.hide_modal()
		_pending_reset = ResetKind.NONE
		return
	_on_back_button_pressed()


# --- Ads / Remove ads ---------------------------------------------------------

var _ads_status_key := ""


func _sync_ads_section() -> void:
	if remove_ads_settings_button == null:
		return
	remove_ads_settings_button.visible = not Ads.ads_removed
	privacy_settings_button.visible = Ads.is_privacy_options_required()
	if Ads.ads_removed and _ads_status_key.is_empty():
		_ads_status_key = "UI_ADS_REMOVED"
	ads_status_label.visible = not _ads_status_key.is_empty()
	ads_status_label.text = tr(_ads_status_key) if not _ads_status_key.is_empty() else ""


func _on_ads_store_status(key: String) -> void:
	_ads_status_key = key
	_sync_ads_section()


func _on_remove_ads_settings_button_pressed() -> void:
	Ads.purchase_remove_ads()


func _on_restore_purchases_button_pressed() -> void:
	Ads.restore_purchases()


func _on_privacy_settings_button_pressed() -> void:
	Ads.show_privacy_options()


func _on_privacy_policy_button_pressed() -> void:
	OS.shell_open(PRIVACY_POLICY_URL)
