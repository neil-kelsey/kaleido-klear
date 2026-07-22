extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const LEVEL_CREATOR_SCENE := "res://scenes/editor/level_creator.tscn"

@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton
@onready var language_label: Label = %LanguageLabel
@onready var language_option: OptionButton = %LanguageOption
@onready var sound_label: Label = %SoundLabel
@onready var music_label: Label = %MusicLabel
@onready var develop_mode_row: HBoxContainer = %DevelopModeRow
@onready var develop_mode_label: Label = %DevelopModeLabel
@onready var develop_mode_checkbox: CheckBox = %DevelopModeCheckBox
@onready var level_creator_button: Button = %LevelCreatorButton
@onready var coming_soon_label: Label = %ComingSoonLabel

var _updating_language_option := false


func _ready() -> void:
	_populate_language_option()
	_apply_translations()
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	UiTheme.style_settings_row_label(language_label)
	UiTheme.style_settings_option_field(language_option)
	UiTheme.style_settings_row_label(sound_label)
	UiTheme.style_settings_row_label(music_label)
	UiTheme.style_settings_row_label(develop_mode_label)
	UiTheme.style_menu_hint(coming_soon_label)
	if OS.is_debug_build():
		develop_mode_checkbox.button_pressed = GameSession.develop_mode
		develop_mode_checkbox.custom_minimum_size = Vector2(64, 64)
		UiTheme.style_menu_button(level_creator_button)
		level_creator_button.visible = GameSession.develop_mode
	else:
		develop_mode_row.visible = false
		level_creator_button.visible = false


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
	if title_label == null or language_option == null:
		return
	title_label.text = tr("UI_SETTINGS_TITLE")
	back_button.text = "  " + tr("UI_BACK")
	language_label.text = tr("UI_LANGUAGE")
	sound_label.text = tr("UI_SOUND")
	music_label.text = tr("UI_MUSIC")
	develop_mode_label.text = tr("UI_DEVELOP_MODE")
	level_creator_button.text = tr("UI_LEVEL_CREATOR")
	coming_soon_label.text = tr("UI_COMING_SOON")
	## Refresh option labels in the newly selected tongue.
	_populate_language_option()


func _on_language_option_item_selected(index: int) -> void:
	if _updating_language_option:
		return
	var code := str(language_option.get_item_metadata(index))
	GameSession.set_locale(code)


func _on_develop_mode_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_develop_mode(enabled)
	level_creator_button.visible = enabled


func _on_level_creator_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_CREATOR_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
