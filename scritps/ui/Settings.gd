extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"

@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton
@onready var language_label: Label = %LanguageLabel
@onready var language_value_label: Label = %LanguageValueLabel
@onready var sound_label: Label = %SoundLabel
@onready var music_label: Label = %MusicLabel
@onready var develop_mode_row: HBoxContainer = %DevelopModeRow
@onready var develop_mode_label: Label = %DevelopModeLabel
@onready var develop_mode_checkbox: CheckBox = %DevelopModeCheckBox
@onready var level_creator_button: Button = %LevelCreatorButton
@onready var coming_soon_label: Label = %ComingSoonLabel

const LEVEL_CREATOR_SCENE := "res://scenes/editor/level_creator.tscn"


func _ready() -> void:
	_apply_translations()
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	UiTheme.style_settings_row_label(language_label)
	UiTheme.style_settings_row_label(language_value_label)
	UiTheme.style_settings_row_label(sound_label)
	UiTheme.style_settings_row_label(music_label)
	UiTheme.style_settings_row_label(develop_mode_label)
	UiTheme.style_menu_hint(coming_soon_label)
	if OS.is_debug_build():
		develop_mode_checkbox.button_pressed = GameSession.develop_mode
		UiTheme.style_menu_button(level_creator_button)
		level_creator_button.visible = GameSession.develop_mode
	else:
		develop_mode_row.visible = false
		level_creator_button.visible = false


func _apply_translations() -> void:
	title_label.text = tr("UI_SETTINGS_TITLE")
	back_button.text = "  " + tr("UI_BACK")
	language_label.text = tr("UI_LANGUAGE")
	language_value_label.text = tr("UI_LANGUAGE_ENGLISH")
	sound_label.text = tr("UI_SOUND")
	music_label.text = tr("UI_MUSIC")
	develop_mode_label.text = tr("UI_DEVELOP_MODE")
	level_creator_button.text = tr("UI_LEVEL_CREATOR")
	coming_soon_label.text = tr("UI_COMING_SOON")


func _on_develop_mode_checkbox_toggled(enabled: bool) -> void:
	GameSession.set_develop_mode(enabled)
	level_creator_button.visible = enabled


func _on_level_creator_button_pressed() -> void:
	get_tree().change_scene_to_file(LEVEL_CREATOR_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
