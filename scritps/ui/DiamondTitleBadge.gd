extends Control
class_name DiamondTitleBadge

## Stretched-diamond title chip used on the dimension map and level select.

const FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")

@export var title: String = "":
	set(value):
		title = value
		queue_redraw()
		_refresh_min_size()

@export var fill_color: Color = Color(0.0, 0.28, 0.66, 1.0):
	set(value):
		fill_color = value
		queue_redraw()

@export var font_size: int = 36:
	set(value):
		font_size = value
		queue_redraw()
		_refresh_min_size()

@export var washed: bool = false:
	set(value):
		washed = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_min_size()


func _refresh_min_size() -> void:
	var metrics := measure(title, font_size)
	custom_minimum_size = metrics.size


func _draw() -> void:
	draw_on(self, size * 0.5, title, fill_color, font_size, washed)


static func measure(text: String, size_px: int, pad_x: float = 22.0, pad_y: float = 12.0, tip: float = 22.0) -> Dictionary:
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var body_w := text_size.x + pad_x * 2.0
	var h := maxf(text_size.y + pad_y * 2.0, 22.0)
	return {
		"text_size": text_size,
		"size": Vector2(body_w + tip * 2.0, h),
		"body_w": body_w,
		"h": h,
		"tip": tip,
	}


static func draw_on(
	item: CanvasItem,
	center: Vector2,
	text: String,
	theme: Color,
	size_px: int,
	washed_out: bool = false,
	selected: bool = false,
	opacity: float = 1.0
) -> Vector2:
	var metrics := measure(text, size_px)
	var text_size: Vector2 = metrics.text_size
	var h: float = metrics.h
	var half_h := h * 0.5
	var half_body: float = metrics.body_w * 0.5
	var tip: float = metrics.tip
	var half_total := half_body + tip
	var pts := PackedVector2Array([
		center + Vector2(-half_total, 0.0),
		center + Vector2(-half_body, -half_h),
		center + Vector2(half_body, -half_h),
		center + Vector2(half_total, 0.0),
		center + Vector2(half_body, half_h),
		center + Vector2(-half_body, half_h),
	])
	var fill := theme
	if washed_out:
		fill = theme.lerp(Color(0.94, 0.95, 0.97, 1.0), 0.58)
		fill.a = 0.75
	fill.a *= opacity
	item.draw_colored_polygon(pts, fill)
	var rim := Color(1, 1, 1, 0.55)
	if washed_out:
		rim = Color(1, 1, 1, 0.28)
	if selected:
		rim = Color(1, 1, 1, 0.7)
	rim.a *= opacity
	item.draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 1.4, true)
	var text_col := Color(0.22, 0.26, 0.34, 0.88) if washed_out else Color(1, 1, 1, 0.98)
	text_col.a *= opacity
	var text_pos := Vector2(
		center.x - text_size.x * 0.5,
		center.y + (FONT.get_ascent(size_px) - FONT.get_descent(size_px)) * 0.5
	)
	item.draw_string(FONT, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, text_col)
	return metrics.size
