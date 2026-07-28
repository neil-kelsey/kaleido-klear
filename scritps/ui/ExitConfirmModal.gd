extends Control

signal confirmed
signal cancelled

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var yes_button: Button = %YesButton
@onready var no_button: Button = %NoButton

var _title_key: String = "UI_EXIT_GAME"
var _message_key: String = "UI_EXIT_GAME_CONFIRM"
var _yes_key: String = "UI_YES"
var _no_key: String = "UI_NO"


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_translations()
	UiTheme.style_primary_button(yes_button)
	UiTheme.style_secondary_button(no_button)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func _apply_translations() -> void:
	if title_label == null:
		return
	title_label.text = tr(_title_key)
	message_label.text = tr(_message_key)
	yes_button.text = tr(_yes_key)
	no_button.text = tr(_no_key)


func show_modal(
	title_key: String = "UI_EXIT_GAME",
	message_key: String = "UI_EXIT_GAME_CONFIRM",
	yes_key: String = "UI_YES",
	no_key: String = "UI_NO"
) -> void:
	_title_key = title_key
	_message_key = message_key
	_yes_key = yes_key
	_no_key = no_key
	_apply_translations()
	visible = true


func hide_modal() -> void:
	visible = false


func _on_yes_pressed() -> void:
	hide_modal()
	confirmed.emit()


func _on_no_pressed() -> void:
	hide_modal()
	cancelled.emit()
