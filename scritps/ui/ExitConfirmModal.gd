extends Control

signal confirmed
signal cancelled

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var extra_slot: VBoxContainer = %ExtraSlot
@onready var yes_button: MenuActionButton = %YesButton
@onready var no_button: MenuActionButton = %NoButton

var _title_key: String = "UI_EXIT_GAME"
var _message_key: String = "UI_EXIT_GAME_CONFIRM"
var _yes_key: String = "UI_YES"
var _no_key: String = "UI_NO"
var _message_args: Array = []
var _destructive_yes: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_translations()
	UiTheme.style_chart_modal_copy(title_label, message_label)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func _apply_translations() -> void:
	if title_label == null:
		return
	title_label.text = tr(_title_key)
	if _message_key.is_empty():
		message_label.visible = false
		message_label.text = ""
	else:
		message_label.visible = true
		if _message_args.is_empty():
			message_label.text = tr(_message_key)
		else:
			message_label.text = tr(_message_key) % _message_args
	yes_button.label_text = tr(_yes_key)
	if _no_key.is_empty():
		no_button.visible = false
	else:
		no_button.visible = true
		no_button.label_text = tr(_no_key)
	yes_button.apply_kind(
		MenuActionButton.Kind.DESTRUCTIVE if _destructive_yes else MenuActionButton.Kind.PRIMARY
	)
	if extra_slot != null:
		extra_slot.visible = extra_slot.get_child_count() > 0


func show_modal(
	title_key: String = "UI_EXIT_GAME",
	message_key: String = "UI_EXIT_GAME_CONFIRM",
	yes_key: String = "UI_YES",
	no_key: String = "UI_NO",
	message_args: Array = [],
	destructive_yes: bool = false
) -> void:
	_title_key = title_key
	_message_key = message_key
	_yes_key = yes_key
	_no_key = no_key
	_message_args = message_args
	_destructive_yes = destructive_yes
	_apply_translations()
	visible = true
	_shrink_panel()


func hide_modal() -> void:
	visible = false


func _shrink_panel() -> void:
	var panel := $Center/Panel as ChartModalPanel
	if panel == null:
		return
	await get_tree().process_frame
	panel.shrink_to_content()


func _on_yes_pressed() -> void:
	hide_modal()
	confirmed.emit()


func _on_no_pressed() -> void:
	hide_modal()
	cancelled.emit()
