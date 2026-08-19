extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LEVEL_CREATOR_SCENE := "res://scenes/editor/level_creator.tscn"
const LEVEL_AUDIT_SCENE := "res://scenes/ui/level_audit.tscn"
const TITLE_FONT_SIZE := 48

@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var nebula_bg: TextureRect = %NebulaBg
@onready var back_button: CircleBackButton = %BackButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var sound_label: Label = %SoundLabel
@onready var music_label: Label = %MusicLabel
@onready var develop_mode_row: HBoxContainer = %DevelopModeRow
@onready var develop_mode_label: Label = %DevelopModeLabel
@onready var develop_mode_checkbox: CheckBox = %DevelopModeCheckBox
@onready var level_creator_button: MenuActionButton = %LevelCreatorButton
@onready var level_audit_button: MenuActionButton = %LevelAuditButton
@onready var reset_progress_button: MenuActionButton = %ResetProgressButton
@onready var coming_soon_label: Label = %ComingSoonLabel
@onready var reset_confirm_modal: Control = %ResetConfirmModal

var _updating_language_option := false
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0


func _ready() -> void:
	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_populate_language_option()
	_apply_translations()
	back_button.pressed.connect(_on_back_button_pressed)
	UiTheme.style_settings_row_label(language_label)
	UiTheme.style_settings_option_field(language_option)
	UiTheme.style_settings_row_label(sound_label)
	UiTheme.style_settings_row_label(music_label)
	UiTheme.style_settings_row_label(develop_mode_label)
	UiTheme.style_menu_hint(coming_soon_label)
	if OS.is_debug_build():
		develop_mode_checkbox.button_pressed = GameSession.develop_mode
		UiTheme.style_settings_checkbox(develop_mode_checkbox)
		level_creator_button.visible = GameSession.develop_mode
		level_audit_button.visible = GameSession.develop_mode
	else:
		develop_mode_row.visible = false
		level_creator_button.visible = false
		level_audit_button.visible = false
	get_viewport().size_changed.connect(_sync_title_badge)
	_sync_title_badge()


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null and nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)


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
	music_label.text = tr("UI_MUSIC")
	develop_mode_label.text = tr("UI_DEVELOP_MODE")
	level_creator_button.set_label(tr("UI_LEVEL_CREATOR"))
	level_audit_button.set_label(tr("UI_LEVEL_AUDIT"))
	reset_progress_button.set_label(tr("UI_RESET_PROGRESS"))
	coming_soon_label.text = tr("UI_COMING_SOON")
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


func _on_language_option_item_selected(index: int) -> void:
	if _updating_language_option:
		return
	var code := str(language_option.get_item_metadata(index))
	GameSession.set_locale(code)


func _on_develop_mode_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_develop_mode(enabled)
	level_creator_button.visible = enabled
	level_audit_button.visible = enabled


func _on_level_creator_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_CREATOR_SCENE)


func _on_level_audit_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_AUDIT_SCENE)


func _on_reset_progress_button_pressed() -> void:
	reset_confirm_modal.show_modal(
		"UI_RESET_PROGRESS_TITLE",
		"UI_RESET_PROGRESS_CONFIRM",
		"UI_RESET_PROGRESS_YES",
		"UI_NO"
	)


func _on_reset_confirm_modal_confirmed() -> void:
	GameSession.reset_progress()


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func handle_back() -> void:
	if reset_confirm_modal != null and reset_confirm_modal.visible:
		reset_confirm_modal.hide_modal()
		return
	_on_back_button_pressed()
