extends Control
class_name GoalBorder

enum EdgeKind { LEFT, TOP, RIGHT, BOTTOM }

const BAR_WIDTH := 16
const ZONE_STRIPE_WIDTH := 4.5
const PREVIEW_SCROLL_SPEED := 36.0
const PREVIEW_MIN_ZONE_SIZE := 36.0
const PREVIEW_ZONE_RATIOS := {
	1: 0.72,
	2: 0.42,
	3: 0.15,
}

const _STRIPE_NORMAL := Vector2(-0.70710678118, 0.70710678118)
const _STRIPE_TANGENT := Vector2(0.70710678118, 0.70710678118)
const _STRIPE_NORMAL_HORIZONTAL := Vector2(0.70710678118, 0.70710678118)
const _STRIPE_TANGENT_HORIZONTAL := Vector2(-0.70710678118, 0.70710678118)
const FADE_POWER := 2.75
const FADE_DEPTH_RATIO := 0.72

@export var edge_kind: EdgeKind = EdgeKind.LEFT

@onready var progress_label: Label = %ProgressLabel

var _preview_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	progress_label.add_theme_font_size_override("font_size", 13)
	_layout_label()
	resized.connect(func() -> void: queue_redraw())
	set_process(false)
	queue_redraw()


func apply_state(state: Dictionary) -> void:
	visible = bool(state.get("active", false))
	set_meta("base_color", state.get("base_color", Color.WHITE))
	set_meta("next_color", state.get("next_color", Color.TRANSPARENT))
	set_meta("progress", state.get("progress", 0))
	set_meta("target", state.get("target", 0))
	set_meta("has_next_preview", state.get("has_next_preview", false))

	_preview_active = visible and bool(state.get("has_next_preview", false))
	set_process(_preview_active)

	if not visible:
		progress_label.visible = false
		queue_redraw()
		return

	var progress: int = int(state.get("progress", 0))
	var target: int = int(state.get("target", 0))
	var unlimited: bool = bool(state.get("unlimited", false))
	if not unlimited and target >= 1:
		progress_label.text = "%d/%d" % [progress, target]
		progress_label.visible = true
	else:
		progress_label.visible = false

	queue_redraw()


func _layout_label() -> void:
	match edge_kind:
		EdgeKind.LEFT:
			progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			progress_label.offset_left = 12.0
			progress_label.offset_right = 60.0
		EdgeKind.RIGHT:
			progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			progress_label.offset_left = -60.0
			progress_label.offset_right = -12.0
		EdgeKind.TOP:
			progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			progress_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
			progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
			progress_label.offset_top = 10.0
			progress_label.offset_bottom = 32.0
		EdgeKind.BOTTOM:
			progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			progress_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			progress_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			progress_label.offset_top = -28.0
			progress_label.offset_bottom = -6.0


func _process(_delta: float) -> void:
	if _preview_active:
		queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var base_color: Color = get_meta("base_color", Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), base_color)

	if not _preview_active:
		return

	var next_color: Color = get_meta("next_color", Color.TRANSPARENT)
	var progress: int = int(get_meta("progress", 0))
	var target: int = int(get_meta("target", 0))
	var remaining: int = maxi(1, target - progress)
	var zone_size: float = _preview_zone_size(remaining)
	var scroll: float = Time.get_ticks_msec() / 1000.0 * PREVIEW_SCROLL_SPEED

	match edge_kind:
		EdgeKind.LEFT, EdgeKind.RIGHT:
			var vertical_zone := Rect2(0.0, 0.0, size.x, zone_size)
			_draw_end_zone_chevrons(vertical_zone, next_color, scroll, false)
			draw_set_transform(Vector2(0.0, size.y), 0.0, Vector2(1.0, -1.0))
			_draw_end_zone_chevrons(vertical_zone, next_color, scroll, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		EdgeKind.TOP, EdgeKind.BOTTOM:
			var horizontal_zone := Rect2(0.0, 0.0, zone_size, size.y)
			_draw_end_zone_chevrons(horizontal_zone, next_color, scroll, true)
			draw_set_transform(Vector2(size.x, 0.0), 0.0, Vector2(-1.0, 1.0))
			_draw_end_zone_chevrons(horizontal_zone, next_color, scroll, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _preview_zone_size(remaining: int) -> float:
	var clamped_remaining: int = mini(remaining, 3)
	var ratio: float = float(PREVIEW_ZONE_RATIOS.get(
		clamped_remaining,
		PREVIEW_ZONE_RATIOS[3]
	))
	var max_ratio: float = 0.72 if clamped_remaining == 1 else 0.45
	return clampf(
		_long_side() * ratio,
		PREVIEW_MIN_ZONE_SIZE,
		_long_side() * max_ratio
	)


func _long_side() -> float:
	return maxf(size.x, size.y)


func _draw_end_zone_chevrons(
	zone: Rect2,
	accent: Color,
	scroll: float,
	horizontal: bool
) -> void:
	var step: float = ZONE_STRIPE_WIDTH
	var normal: Vector2 = _STRIPE_NORMAL_HORIZONTAL if horizontal else _STRIPE_NORMAL
	var tangent: Vector2 = _STRIPE_TANGENT_HORIZONTAL if horizontal else _STRIPE_TANGENT
	var zone_poly := _rect_polygon(zone)

	var corners: Array[Vector2] = [
		zone.position,
		zone.position + Vector2(zone.size.x, 0.0),
		zone.position + zone.size,
		zone.position + Vector2(0.0, zone.size.y),
	]
	var min_d: float = INF
	var max_d: float = -INF
	var min_t: float = INF
	var max_t: float = -INF
	for corner in corners:
		var d: float = corner.dot(normal)
		var t: float = corner.dot(tangent)
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
		min_t = minf(min_t, t)
		max_t = maxf(max_t, t)

	var extent: float = (max_t - min_t) * 0.5 + step
	var index_start: int = int(floor((min_d - scroll) / step)) - 1
	var index_end: int = int(ceil((max_d - scroll) / step)) + 1

	for index in range(index_start, index_end + 1):
		if index % 2 != 0:
			continue
		var d0: float = float(index) * step + scroll
		var d1: float = d0 + step
		_draw_clipped_stripe_band(
			normal,
			tangent,
			d0,
			d1,
			extent,
			accent,
			zone,
			zone_poly,
			horizontal
		)


func _draw_clipped_stripe_band(
	normal: Vector2,
	tangent: Vector2,
	d0: float,
	d1: float,
	extent: float,
	color: Color,
	zone: Rect2,
	clip_poly: PackedVector2Array,
	horizontal: bool
) -> void:
	var center0: Vector2 = normal * d0
	var center1: Vector2 = normal * d1
	var points := PackedVector2Array([
		center0 - tangent * extent,
		center1 - tangent * extent,
		center1 + tangent * extent,
		center0 + tangent * extent,
	])
	var clipped: Array = Geometry2D.intersect_polygons(points, clip_poly)
	for poly in clipped:
		if poly.size() >= 3:
			var clipped_poly: PackedVector2Array = poly
			var stripe_color := color
			stripe_color.a *= _fade_alpha_for_poly(clipped_poly, zone, horizontal)
			if stripe_color.a > 0.01:
				draw_colored_polygon(clipped_poly, stripe_color)


func _fade_alpha_for_poly(
	poly: PackedVector2Array,
	zone: Rect2,
	horizontal: bool
) -> float:
	var depth: float = zone.size.x if horizontal else zone.size.y
	if depth <= 0.0:
		return 0.0

	var total_alpha: float = 0.0
	for point in poly:
		var dist: float = point.x if horizontal else point.y
		var fade_depth: float = depth * FADE_DEPTH_RATIO
		var t: float = clampf(dist / fade_depth, 0.0, 1.0)
		var alpha: float = pow(1.0 - t, FADE_POWER)
		total_alpha += alpha

	return total_alpha / float(poly.size())


func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size,
		rect.position + Vector2(0.0, rect.size.y),
	])
