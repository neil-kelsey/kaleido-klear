extends Button
class_name CircleBackButton

## Shared circular back control — always pins bottom-left using UiTheme insets.

## 0 = use UiTheme.CIRCLE_BUTTON_SIZE (preferred).
@export var button_size: int = 0:
	set(value):
		button_size = value
		if is_node_ready():
			_apply_style()

## -1 = use UiTheme.CIRCLE_BUTTON_EDGE_INSET.
@export var edge_inset: float = -1.0

## Icon + ring colour (white fill stays). Defaults to primary blue.
@export var accent_color: Color = UiTheme.PRIMARY:
	set(value):
		accent_color = value
		if is_node_ready():
			_apply_style()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)
	_apply_style()
	_apply_tooltip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			_apply_tooltip()


func resolved_size() -> int:
	return button_size if button_size > 0 else UiTheme.CIRCLE_BUTTON_SIZE


func refresh() -> void:
	_apply_style()
	_apply_tooltip()


func _on_viewport_resized() -> void:
	_apply_style()


func _apply_style() -> void:
	var s := resolved_size()
	UiTheme.style_circle_back_button(self, s, accent_color)
	_pin_bottom_left(s)
	queue_redraw()


func _pin_bottom_left(s: int) -> void:
	var sf := float(s)
	var inset := edge_inset if edge_inset >= 0.0 else float(UiTheme.CIRCLE_BUTTON_EDGE_INSET)
	layout_mode = 1  # Anchors (matches .tscn layout_mode = 1)
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(sf, sf)
	size = Vector2(sf, sf)
	offset_left = inset
	offset_bottom = -inset
	offset_right = inset + sf
	offset_top = -inset - sf


func _apply_tooltip() -> void:
	text = ""
	tooltip_text = tr("UI_BACK")


func _draw() -> void:
	var s := size
	FaVector.draw_named(self, "arrow-left", s * 0.5, minf(s.x, s.y) * 0.42, accent_color)
