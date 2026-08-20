extends PanelContainer
class_name ChartModalPanel

## Cream star-chart card for modals over the dark nebula screens.
## Settings reuses this face but fills its parent — leave shrink_wrap off there.

const CHART_TEX := preload("res://assets/backgrounds/level_star_chart.png")
const PAPER := Color(0.97, 0.97, 0.985, 1.0)
const GOLD_WASH := Color(1.0, 0.88, 0.50, 0.26)
const GOLD_EDGE := Color(0.82, 0.68, 0.28, 0.7)

## When true (centered modals), size to content. When false (Settings), fill parent.
@export var shrink_wrap: bool = true


func _ready() -> void:
	clip_contents = true
	if shrink_wrap:
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.set_corner_radius_all(36)
	style.content_margin_left = 72
	style.content_margin_top = 56
	style.content_margin_right = 72
	style.content_margin_bottom = 64
	style.border_color = GOLD_EDGE
	style.set_border_width_all(3)
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	add_theme_stylebox_override("panel", style)
	resized.connect(queue_redraw)
	queue_redraw()


func shrink_to_content() -> void:
	if not shrink_wrap:
		return
	reset_size()
	queue_redraw()


func _draw() -> void:
	if CHART_TEX == null:
		return
	var tex_size := CHART_TEX.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var s := maxf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size := tex_size * s
	var origin := (size - draw_size) * 0.5
	draw_texture_rect(CHART_TEX, Rect2(origin, draw_size), false, GOLD_WASH)
