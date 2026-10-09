extends Control
class_name DifficultyBanner

## Start-of-level sting: level name over the same diamond-ended difficulty chip.

const FONT_SIZE := 53
const TITLE_FONT_SIZE := 36
const TITLE_FONT_MIN := 22
const TITLE_GAP := 10.0
const FADE_IN := 0.28
const HOLD_SEC := 2.2
const FADE_OUT := 0.5
const TITLE_COLOR := Color(1.0, 0.92, 0.72, 0.96)

var _title := ""
var _text := ""
var _fill := Color(0.18, 0.67, 0.32, 1.0)
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	modulate.a = 0.0
	z_index = 20
	_pin()


func present(title: String, rating: String, fill: Color) -> void:
	_title = title.strip_edges()
	_text = rating.strip_edges()
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


func _max_title_width() -> float:
	if is_inside_tree():
		return maxf(get_viewport_rect().size.x * 0.82, 280.0)
	return 720.0


func _title_font_size() -> int:
	if _title.is_empty():
		return TITLE_FONT_SIZE
	var max_w := _max_title_width()
	var size_px := TITLE_FONT_SIZE
	while size_px > TITLE_FONT_MIN:
		var text_size := DiamondTitleBadge.FONT.get_string_size(
			_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px
		)
		if text_size.x <= max_w:
			return size_px
		size_px -= 2
	return TITLE_FONT_MIN


func _title_metrics() -> Dictionary:
	if _title.is_empty():
		return {"size": Vector2.ZERO, "font_size": TITLE_FONT_SIZE}
	var size_px := _title_font_size()
	var text_size := DiamondTitleBadge.FONT.get_string_size(
		_title, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px
	)
	return {"size": text_size, "font_size": size_px}


func _refresh_size() -> void:
	var chip: Vector2 = DiamondTitleBadge.measure(_text, FONT_SIZE).size
	var title_m := _title_metrics()
	var title_size: Vector2 = title_m.size
	var width := maxf(chip.x, title_size.x)
	var height := chip.y
	if title_size.y > 0.0:
		height = title_size.y + TITLE_GAP + chip.y
	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size


func _draw() -> void:
	if _text.strip_edges().is_empty() and _title.is_empty():
		return
	var chip_metrics := DiamondTitleBadge.measure(_text, FONT_SIZE)
	var title_m := _title_metrics()
	var title_size: Vector2 = title_m.size
	var chip_top := 0.0
	if title_size.y > 0.0:
		var title_fs: int = int(title_m.font_size)
		var title_pos := Vector2(
			size.x * 0.5 - title_size.x * 0.5,
			title_size.y * 0.5
			+ (
				DiamondTitleBadge.FONT.get_ascent(title_fs)
				- DiamondTitleBadge.FONT.get_descent(title_fs)
			) * 0.5
		)
		draw_string(
			DiamondTitleBadge.FONT,
			title_pos + Vector2(0, 2),
			_title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			title_fs,
			Color(0, 0, 0, 0.45)
		)
		draw_string(
			DiamondTitleBadge.FONT,
			title_pos,
			_title,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			title_fs,
			TITLE_COLOR
		)
		chip_top = title_size.y + TITLE_GAP
	if _text.strip_edges().is_empty():
		return
	var chip_center := Vector2(size.x * 0.5, chip_top + chip_metrics.size.y * 0.5)
	_draw_shadow(chip_center)
	DiamondTitleBadge.draw_on(self, chip_center, _text, _fill, FONT_SIZE, false, true, 1.0, false)


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
