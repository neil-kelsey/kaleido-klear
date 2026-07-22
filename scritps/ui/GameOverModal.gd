extends Control

signal replay_level_pressed
signal level_select_pressed
signal closed

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var replay_button: Button = %ReplayButton
@onready var level_select_button: Button = %LevelSelectButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	_apply_translations()
	UiTheme.style_menu_button(replay_button)
	UiTheme.style_menu_button(level_select_button)
	UiTheme.style_close_button(close_button)
	close_button.tooltip_text = tr("UI_CLOSE")


func _apply_translations() -> void:
	title_label.text = tr("UI_LEVEL_FAILED")
	message_label.text = tr("UI_TRY_AGAIN_PROMPT")
	replay_button.text = tr("UI_REPLAY_LEVEL")
	level_select_button.text = tr("UI_BACK_TO_LEVEL_SELECT")


func show_modal() -> void:
	_apply_translations()
	visible = true


func hide_modal() -> void:
	visible = false


func _on_close_button_pressed() -> void:
	hide_modal()
	closed.emit()


func _on_replay_button_pressed() -> void:
	replay_level_pressed.emit()


func _on_level_select_button_pressed() -> void:
	level_select_pressed.emit()
