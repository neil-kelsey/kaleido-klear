extends Button
class_name CircleIconButton

## Circular control that draws a Font Awesome glyph as vectors (not a bitmap).

@export var button_size: int = 0:
	set(value):
		button_size = value
		if is_node_ready():
			_apply_style()

## Font Awesome classic solid name: undo, refresh, bullseye, arrow-left, ...
@export var fa_icon: String = "undo":
	set(value):
		fa_icon = value
		queue_redraw()

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
	var s := resolved_size()
	UiTheme.style_circle_icon_button(self, s)
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)
	queue_redraw()


func _draw() -> void:
	if fa_icon.is_empty():
		return
	var s := size
	var pad := minf(s.x, s.y) * 0.42
	FaVector.draw_named(self, fa_icon, s * 0.5, pad, Color.WHITE)


func _apply_tooltip() -> void:
	text = ""
	if tooltip_key.is_empty():
		tooltip_text = ""
	else:
		tooltip_text = tr(tooltip_key)
