extends Button
class_name CircleIconButton

## Shared circular icon control. Size comes from UiTheme.CIRCLE_BUTTON_SIZE
## unless button_size is set > 0.

## 0 = use UiTheme.CIRCLE_BUTTON_SIZE (preferred).
@export var button_size: int = 0:
	set(value):
		button_size = value
		if is_node_ready():
			_apply_style()

@export var icon_texture: Texture2D:
	set(value):
		icon_texture = value
		if is_node_ready():
			_apply_style()

@export var tooltip_key: String = "":
	set(value):
		tooltip_key = value
		if is_node_ready():
			_apply_tooltip()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	_apply_style()
	_apply_tooltip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_apply_tooltip()


func resolved_size() -> int:
	return button_size if button_size > 0 else UiTheme.CIRCLE_BUTTON_SIZE


func _apply_style() -> void:
	if icon_texture == null:
		return
	var s := resolved_size()
	UiTheme.style_circle_icon_button(self, icon_texture, s)
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)


func _apply_tooltip() -> void:
	text = ""
	if tooltip_key.is_empty():
		tooltip_text = ""
	else:
		tooltip_text = tr(tooltip_key)
