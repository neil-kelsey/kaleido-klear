extends Control
class_name DifficultyBanner

## Start-of-level hardness sting, drawn as the same diamond-ended chip as dimension titles.

const FONT_SIZE := 53
const FADE_IN := 0.28
const HOLD_SEC := 2.2
const FADE_OUT := 0.5

var _text := ""
var _fill := Color(0.18, 0.67, 0.32, 1.0)
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	z_index = 20
	_pin()


func present(text: String, fill: Color) -> void:
	_text = text
	_fill = fill
	_refresh_size()
	queue_redraw()
	visible = true
	modulate.a = 0.0
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD_SEC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func() -> void: visible = false)


func pin_below(control: Control) -> void:
	var top := 160.0
	if control != null:
		top = control.offset_bottom + 28.0
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END
	_refresh_size()
	var min_size := custom_minimum_size
	offset_left = -min_size.x * 0.5
	offset_right = min_size.x * 0.5
	offset_top = top
	offset_bottom = top + min_size.y


func _pin() -> void:
	pin_below(null)


func _refresh_size() -> void:
	var metrics := DiamondTitleBadge.measure(_text, FONT_SIZE)
	var chip: Vector2 = metrics.size
	custom_minimum_size = chip
	size = chip


func _draw() -> void:
	if _text.strip_edges().is_empty():
		return
	var center := size * 0.5
	_draw_shadow(center)
	DiamondTitleBadge.draw_on(self, center, _text, _fill, FONT_SIZE, false, true, 1.0, false)


func _draw_shadow(center: Vector2) -> void:
	var metrics := DiamondTitleBadge.measure(_text, FONT_SIZE)
	var h: float = metrics.h
	var half_h := h * 0.5
	var half_body: float = metrics.body_w * 0.5
	var tip: float = metrics.tip
	var half_total := half_body + tip
	var shadow_c := center + Vector2(0, 6)
	var pts := PackedVector2Array([
		shadow_c + Vector2(-half_total, 0.0),
		shadow_c + Vector2(-half_body, -half_h),
		shadow_c + Vector2(half_body, -half_h),
		shadow_c + Vector2(half_total, 0.0),
		shadow_c + Vector2(half_body, half_h),
		shadow_c + Vector2(-half_body, half_h),
	])
	draw_colored_polygon(pts, Color(0, 0, 0, 0.32))
