extends Button
class_name CircleBackButton

## Shared circular back control. Size comes from UiTheme.CIRCLE_BUTTON_SIZE
## unless button_size is set > 0. Rect is fitted from edge insets on ready.

## 0 = use UiTheme.CIRCLE_BUTTON_SIZE (preferred).
@export var button_size: int = 0:
	set(value):
		button_size = value
		if is_node_ready():
			_apply_style()


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


func refresh() -> void:
	_apply_style()
	_apply_tooltip()


func _apply_style() -> void:
	var s := resolved_size()
	UiTheme.style_circle_back_button(self, s)
	_fit_rect_to_size(s)


func _fit_rect_to_size(s: int) -> void:
	var sf := float(s)
	custom_minimum_size = Vector2(sf, sf)
	size = Vector2(sf, sf)
	## Bottom-left pin: keep left/bottom insets, derive right/top from size.
	if (
		is_equal_approx(anchor_top, 1.0)
		and is_equal_approx(anchor_bottom, 1.0)
		and is_equal_approx(anchor_left, 0.0)
		and is_equal_approx(anchor_right, 0.0)
	):
		offset_top = offset_bottom - sf
		offset_right = offset_left + sf


func _apply_tooltip() -> void:
	text = ""
	tooltip_text = tr("UI_BACK")
