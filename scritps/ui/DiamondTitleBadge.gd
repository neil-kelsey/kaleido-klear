extends Control
class_name DiamondTitleBadge

## One title chip for map + level select. Padding and point depth scale with type size
## so a 18px world title and a 53px HUD title keep the same proportions.

const FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
## Reference size used on the focused dimension map title.
const REF_FONT := 18.0
const REF_PAD_X := 22.0
const REF_PAD_Y := 12.0
const REF_TIP := 22.0

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

@export var selected: bool = true:
	set(value):
		selected = value
		queue_redraw()

@export var show_rim: bool = true:
	set(value):
		show_rim = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_min_size()


func _refresh_min_size() -> void:
	var metrics := measure(title, font_size)
	custom_minimum_size = metrics.size
	size = metrics.size


func _draw() -> void:
	draw_on(self, size * 0.5, title, fill_color, font_size, washed, selected, 1.0, show_rim)


static func _scale_for(size_px: int) -> float:
	return float(size_px) / REF_FONT


static func measure(text: String, size_px: int) -> Dictionary:
	var s := _scale_for(size_px)
	var pad_x := REF_PAD_X * s
	var pad_y := REF_PAD_Y * s
	var tip := REF_TIP * s
	var text_size := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var body_w := text_size.x + pad_x * 2.0
	var h := maxf(text_size.y + pad_y * 2.0, 22.0 * s)
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
	is_selected: bool = false,
	opacity: float = 1.0,
	draw_rim: bool = true
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
	if draw_rim:
		var rim := Color(1, 1, 1, 0.55)
		if washed_out:
			rim = Color(1, 1, 1, 0.28)
		if is_selected:
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
