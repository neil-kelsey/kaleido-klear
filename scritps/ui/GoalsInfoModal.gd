extends Control
class_name GoalsInfoModal

signal closed

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var map_host: Control = %MapHost

var _map: GoalsOverviewMap


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_close_button(close_button)
	close_button.pressed.connect(hide_modal)
	_map = GoalsOverviewMap.new()
	_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_host.add_child(_map)
	_apply_translations()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		if _map != null:
			_map.apply_translations()


func _apply_translations() -> void:
	if title_label == null:
		return
	title_label.text = tr("UI_GOALS_INFO_TITLE")
	close_button.tooltip_text = tr("UI_CLOSE")


func show_overview(goals_by_edge: Dictionary) -> void:
	if _map != null:
		_map.set_overview(goals_by_edge)
	_apply_translations()
	visible = true


func refresh_overview(goals_by_edge: Dictionary) -> void:
	if not visible or _map == null:
		return
	_map.set_overview(goals_by_edge)


func hide_modal() -> void:
	visible = false
	closed.emit()
