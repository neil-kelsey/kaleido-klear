extends Node2D
class_name Block

enum BlockKind { STANDARD, MERGE, WALL }

enum TileColor { RED, GREEN, BLUE, YELLOW, PURPLE, ORANGE }

const WALL_FILL := Color(0.28, 0.3, 0.34, 1.0)
const WALL_TINT := Color(0.22, 0.24, 0.28, 0.4)

const COLORS := {
	TileColor.RED: Color(0.9, 0.25, 0.25),
	TileColor.GREEN: Color(0.2, 0.75, 0.35),
	TileColor.BLUE: Color(0.25, 0.45, 0.95),
	TileColor.YELLOW: Color(0.95, 0.82, 0.2),
	TileColor.PURPLE: Color(0.62, 0.32, 0.88),
	TileColor.ORANGE: Color(0.95, 0.52, 0.18),
}

const CELL_TINT_ALPHA := 0.15
const MERGE_TINT_ALPHA := 0.36
const MERGE_CORNER_RADIUS_RATIO := 0.13
const MERGE_CORNER_RADIUS_MIN := 5.0
const MERGE_CORNER_ARC_SEGMENTS := 5
const MERGE_PREVIEW_TINT_ALPHA := 0.30
const MERGE_SHINE_SCROLL_SPEED := 20.0
const MERGE_SHINE_PERIOD := 36.0
const MERGE_SHINE_LIFT := 0.09
const MERGE_SHINE_SOFT_LAYERS := [
	[14.0, 0.16],
	[9.0, 0.28],
	[5.0, 0.38],
]
const MERGE_INTERACTION_FADE_IN_SEC := 0.16
const MERGE_INTERACTION_FADE_OUT_SEC := 0.24
const _SHINE_NORMAL := Vector2(0.70710678118, 0.70710678118)
const _SHINE_TANGENT := Vector2(-0.70710678118, 0.70710678118)
const CELL_EDGE_MARGIN_RATIO := 0.17
const MERGE_DRAG_MUTE_DARKEN := 0.38
const MERGE_DRAG_MUTE_GREY_BLEND := 0.52
const MERGE_DRAG_MUTE_GREY := Color(0.26, 0.28, 0.32)
const DRAG_SELECTED_MUTE_DARKEN := 0.18
const DRAG_SELECTED_MUTE_GREY_BLEND := 0.26
const DRAG_FOCUS_COLOR := Color(0.48, 0.74, 0.98, 1.0)
const FOCUS_CHEVRON_SCROLL_SPEED := 11.0
const FOCUS_CHEVRON_STRIPE_WIDTH := 4.5
const FOCUS_CHEVRON_ALPHA := 0.16
const _FOCUS_CHEVRON_NORMAL := Vector2(0.70710678118, 0.70710678118)
const _FOCUS_CHEVRON_TANGENT := Vector2(-0.70710678118, 0.70710678118)

enum InteractionVisual { NONE, DRAG_MUTED, MERGE_TARGET, MERGE_NON_TARGET }

@export var tile_color: TileColor = TileColor.RED
@export var block_kind: BlockKind = BlockKind.STANDARD
@export var shape_id: String = BlockShapes.SINGLE

var grid_pos: Vector2i = Vector2i.ZERO
var shape_cells: Array[Vector2i] = [Vector2i(0, 0)]
var _cell_size: int = 0
var _interaction_mode: InteractionVisual = InteractionVisual.NONE
var _interaction_fade_mode: InteractionVisual = InteractionVisual.NONE
var _interaction_blend: float = 0.0
var _interaction_fill_target: Color = Color.WHITE
var _interaction_tint_target: Color = Color.WHITE
var _interaction_tint_alpha: float = CELL_TINT_ALPHA
var _merge_blend_t: float = -1.0
var _merge_fill_from: Color = Color.WHITE
var _merge_fill_to: Color = Color.WHITE
var _merge_blend_from_moving: Color = Color.WHITE
var _merge_blend_stationary_cells: Array[Vector2i] = []
var _merge_blend_moving_cells: Array[Vector2i] = []
var _merge_impact_offset: Vector2 = Vector2.ZERO
var _drag_focus: bool = false


static func get_color(color: TileColor) -> Color:
	return COLORS[color]


static func is_wall_kind(kind: BlockKind) -> bool:
	return kind == BlockKind.WALL


static func is_primary_merge_color(color: TileColor) -> bool:
	return (
		color == TileColor.RED
		or color == TileColor.YELLOW
		or color == TileColor.BLUE
	)


static func _primary_flags(color: TileColor) -> int:
	match color:
		TileColor.RED:
			return 1
		TileColor.YELLOW:
			return 2
		TileColor.BLUE:
			return 4
		TileColor.ORANGE:
			return 3
		TileColor.GREEN:
			return 6
		TileColor.PURPLE:
			return 5
		_:
			return 0


static func _color_from_primary_flags(flags: int) -> int:
	match flags:
		1:
			return TileColor.RED
		2:
			return TileColor.YELLOW
		4:
			return TileColor.BLUE
		3:
			return TileColor.ORANGE
		5:
			return TileColor.PURPLE
		6:
			return TileColor.GREEN
		_:
			return -1


static func get_merged_color(a: TileColor, b: TileColor) -> int:
	if a == b:
		return -1

	var fa := _primary_flags(a)
	var fb := _primary_flags(b)
	if fa == 0 or fb == 0:
		return -1

	var xor := fa ^ fb
	var from_xor := _color_from_primary_flags(xor)
	if from_xor != -1:
		return from_xor

	# Full red/yellow/blue combination — pick the secondary that isn't either input.
	if xor == 7:
		if fa == 6 or fb == 6:
			if fa == 1 or fb == 1:
				return TileColor.ORANGE
		if fa == 2 or fb == 2:
			if fa == 5 or fb == 5:
				return TileColor.GREEN
		if fa == 4 or fb == 4:
			if fa == 3 or fb == 3:
				return TileColor.GREEN

	return -1


static func draw_merge_cell_rect(canvas: CanvasItem, rect: Rect2, base: Color, _cell: Vector2i, time_ms: float) -> void:
	var tint := base
	tint.a = MERGE_TINT_ALPHA
	var radius := _merge_corner_radius_for_size(rect.size.x)
	var body_rect := rect.grow(-1.0)
	var body_radius := maxf(3.0, radius - 1.0)
	_draw_rounded_rect_filled(canvas, rect, tint, radius)
	_draw_rounded_rect_filled(canvas, body_rect, base, body_radius)
	var body_poly := _rounded_rect_points(body_rect, body_radius)
	_draw_merge_shine_on_polygon(canvas, body_poly, base, time_ms)


static func can_merge_blocks(a: Block, b: Block) -> bool:
	if is_wall_kind(a.block_kind) or is_wall_kind(b.block_kind):
		return false
	if a.block_kind != BlockKind.MERGE or b.block_kind != BlockKind.MERGE:
		return false
	return get_merged_color(a.tile_color, b.tile_color) != -1


func configure(
	color: TileColor,
	shape: String,
	anchor: Vector2i,
	kind: BlockKind = BlockKind.STANDARD
) -> void:
	tile_color = color
	shape_id = shape
	grid_pos = anchor
	block_kind = kind
	shape_cells = BlockShapes.get_cells(shape_id)
	_refresh_process_state()
	queue_redraw()


func set_shape_cells(cells: Array[Vector2i]) -> void:
	shape_cells = cells
	queue_redraw()


func get_occupied_cells(anchor: Vector2i = grid_pos) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in shape_cells:
		cells.append(anchor + offset)
	return cells


func occupies_cell(cell: Vector2i) -> bool:
	return cell in get_occupied_cells()


func setup(cell_size: int) -> void:
	_cell_size = cell_size
	clear_merge_preview()
	_refresh_process_state()
	queue_redraw()


func _cache_interaction_targets(preview_color: int = -1) -> void:
	var base: Color = COLORS[tile_color]
	match _interaction_mode:
		InteractionVisual.MERGE_TARGET:
			_interaction_fill_target = COLORS[preview_color as TileColor]
			_interaction_tint_target = _interaction_fill_target
			_interaction_tint_alpha = MERGE_PREVIEW_TINT_ALPHA + 0.12
		InteractionVisual.DRAG_MUTED:
			_interaction_fill_target = _muted_drag_selected_color(base)
			_interaction_tint_target = _interaction_fill_target
			_interaction_tint_alpha = MERGE_TINT_ALPHA * 0.22
		InteractionVisual.MERGE_NON_TARGET:
			_interaction_fill_target = _muted_merge_color(base)
			_interaction_tint_target = _interaction_fill_target
			_interaction_tint_alpha = MERGE_TINT_ALPHA * 0.28
		_:
			_interaction_fill_target = base
			_interaction_tint_target = base
			_interaction_tint_alpha = MERGE_TINT_ALPHA


func set_interaction_visual(mode: InteractionVisual, preview_color: int = -1) -> void:
	_interaction_mode = mode
	_interaction_fade_mode = mode
	_cache_interaction_targets(preview_color)
	_refresh_process_state()
	queue_redraw()


func clear_interaction_visual() -> void:
	if _interaction_mode == InteractionVisual.NONE and _interaction_blend <= 0.0:
		return
	_interaction_mode = InteractionVisual.NONE
	_refresh_process_state()
	queue_redraw()


func set_drag_focus(focused: bool) -> void:
	_drag_focus = focused
	_refresh_process_state()
	queue_redraw()


func set_drag_selected(selected: bool) -> void:
	if selected:
		set_interaction_visual(InteractionVisual.DRAG_MUTED)
	else:
		clear_interaction_visual()


func set_merge_target_preview(preview_color: int) -> void:
	set_interaction_visual(InteractionVisual.MERGE_TARGET, preview_color)


func set_merge_non_target_muted() -> void:
	set_interaction_visual(InteractionVisual.MERGE_NON_TARGET)


func is_interaction_active() -> bool:
	return _interaction_blend > 0.001 or _interaction_mode != InteractionVisual.NONE


func _refresh_process_state() -> void:
	var should_process := (
		_drag_focus
		or block_kind == BlockKind.MERGE
		or is_interaction_active()
		or is_merge_blending()
		or _merge_impact_offset != Vector2.ZERO
	)
	set_process(should_process)


func set_merge_preview(preview_color: int) -> void:
	set_merge_target_preview(preview_color)


func clear_merge_preview() -> void:
	clear_interaction_visual()


func start_merge_blend_animation(
	stationary_fill: Color,
	moving_fill: Color,
	end_fill: Color,
	stationary_cells: Array[Vector2i],
	moving_cells: Array[Vector2i]
) -> void:
	_merge_fill_from = stationary_fill
	_merge_blend_from_moving = moving_fill
	_merge_fill_to = end_fill
	_merge_blend_stationary_cells = stationary_cells.duplicate()
	_merge_blend_moving_cells = moving_cells.duplicate()
	_merge_blend_t = 0.0
	_refresh_process_state()
	queue_redraw()


func set_merge_blend_progress(progress: float) -> void:
	_merge_blend_t = clampf(progress, 0.0, 1.0)
	queue_redraw()


func set_merge_impact_offset(offset: Vector2) -> void:
	_merge_impact_offset = offset
	queue_redraw()


func finish_merge_blend_animation() -> void:
	_merge_blend_t = -1.0
	_merge_impact_offset = Vector2.ZERO
	_merge_blend_stationary_cells.clear()
	_merge_blend_moving_cells.clear()
	_refresh_process_state()
	queue_redraw()


func is_merge_blending() -> bool:
	return _merge_blend_t >= 0.0


func _process(delta: float) -> void:
	var needs_redraw := _drag_focus
	var target_blend := 1.0 if _interaction_mode != InteractionVisual.NONE else 0.0
	if not is_equal_approx(_interaction_blend, target_blend):
		if _interaction_blend < target_blend:
			_interaction_blend = minf(
				_interaction_blend + delta / MERGE_INTERACTION_FADE_IN_SEC,
				1.0
			)
		else:
			_interaction_blend = maxf(
				_interaction_blend - delta / MERGE_INTERACTION_FADE_OUT_SEC,
				0.0
			)
		if _interaction_blend <= 0.0:
			_interaction_fade_mode = InteractionVisual.NONE
		needs_redraw = true

	if (
		block_kind == BlockKind.MERGE
		or is_merge_blending()
		or _merge_impact_offset != Vector2.ZERO
	):
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


func _muted_merge_color(base: Color) -> Color:
	return base.darkened(MERGE_DRAG_MUTE_DARKEN).lerp(
		MERGE_DRAG_MUTE_GREY,
		MERGE_DRAG_MUTE_GREY_BLEND
	)


func _muted_drag_selected_color(base: Color) -> Color:
	return base.darkened(DRAG_SELECTED_MUTE_DARKEN).lerp(
		MERGE_DRAG_MUTE_GREY,
		DRAG_SELECTED_MUTE_GREY_BLEND
	)


func _apply_interaction_color(base: Color, tint_mode: bool) -> Color:
	if _interaction_blend <= 0.0:
		return base
	var target := _interaction_tint_target if tint_mode else _interaction_fill_target
	return base.lerp(target, _interaction_blend)


func _current_fill_color() -> Color:
	if is_wall_kind(block_kind):
		return WALL_FILL
	if _merge_blend_t >= 0.0:
		return _merge_fill_from.lerp(_merge_fill_to, _merge_blend_t)
	var base: Color = COLORS[tile_color]
	if is_interaction_active():
		return _apply_interaction_color(base, false)
	return base


func _merge_region_fill_color(from_color: Color) -> Color:
	return from_color.lerp(_merge_fill_to, _merge_blend_t)


func _current_tint_color() -> Color:
	if is_wall_kind(block_kind):
		return WALL_TINT
	var base: Color = COLORS[tile_color]
	var alpha := MERGE_TINT_ALPHA if block_kind == BlockKind.MERGE else CELL_TINT_ALPHA
	var tint: Color
	if is_interaction_active():
		tint = _apply_interaction_color(base, true)
		alpha = lerpf(alpha, _interaction_tint_alpha, _interaction_blend)
	elif is_merge_blending() and not _merge_blend_moving_cells.is_empty():
		var stationary := _merge_region_fill_color(_merge_fill_from)
		var moving := _merge_region_fill_color(_merge_blend_from_moving)
		tint = stationary.lerp(moving, 0.5)
	else:
		tint = _current_fill_color()
	tint.a = alpha
	return tint


func _cell_edge_margin() -> float:
	return maxf(3.0, _cell_size * CELL_EDGE_MARGIN_RATIO)


func _shape_cells_set() -> Dictionary:
	var cells: Dictionary = {}
	for offset in shape_cells:
		cells[offset] = true
	return cells


func _grid_vertex_to_pixel(vertex: Vector2i, half: float, cell_size: float) -> Vector2:
	return Vector2(vertex.x * cell_size - half, vertex.y * cell_size - half)


func _add_boundary_edge(
	edge_map: Dictionary,
	from_vertex: Vector2i,
	to_vertex: Vector2i,
	cell: Vector2i,
	side: String
) -> void:
	edge_map[from_vertex] = {"to": to_vertex, "cell": cell, "side": side}


func _chain_boundary_edges(cells: Dictionary) -> Array:
	var edge_map: Dictionary = {}

	for cell_offset: Vector2i in cells.keys():
		var ox: int = cell_offset.x
		var oy: int = cell_offset.y
		if not cells.has(cell_offset + Vector2i(0, -1)):
			_add_boundary_edge(
				edge_map,
				Vector2i(ox, oy),
				Vector2i(ox + 1, oy),
				cell_offset,
				"north"
			)
		if not cells.has(cell_offset + Vector2i(1, 0)):
			_add_boundary_edge(
				edge_map,
				Vector2i(ox + 1, oy),
				Vector2i(ox + 1, oy + 1),
				cell_offset,
				"east"
			)
		if not cells.has(cell_offset + Vector2i(0, 1)):
			_add_boundary_edge(
				edge_map,
				Vector2i(ox + 1, oy + 1),
				Vector2i(ox, oy + 1),
				cell_offset,
				"south"
			)
		if not cells.has(cell_offset + Vector2i(-1, 0)):
			_add_boundary_edge(
				edge_map,
				Vector2i(ox, oy + 1),
				Vector2i(ox, oy),
				cell_offset,
				"west"
			)

	if edge_map.is_empty():
		return []

	var start := Vector2i(2147483647, 2147483647)
	for from_vertex: Vector2i in edge_map.keys():
		if from_vertex.x < start.x or (from_vertex.x == start.x and from_vertex.y < start.y):
			start = from_vertex

	var loop: Array = []
	var current: Vector2i = start
	for _step in edge_map.size() + 1:
		var data: Dictionary = edge_map[current]
		loop.append({
			"from_v": current,
			"to_v": data["to"],
			"cell": data["cell"],
			"side": data["side"],
		})
		current = data["to"]
		if current == start:
			break

	return loop


func _cells_set_from_offsets(offsets: Array[Vector2i]) -> Dictionary:
	var cells: Dictionary = {}
	for offset in offsets:
		cells[offset] = true
	return cells


func _build_outer_polygon(edge_loop: Array, half: float, cell_size: float) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for edge_variant in edge_loop:
		var edge: Dictionary = edge_variant
		polygon.append(_grid_vertex_to_pixel(edge["from_v"], half, cell_size))
	return polygon


func _build_body_polygon(outer_polygon: PackedVector2Array, margin: float) -> PackedVector2Array:
	var inset_polygons := Geometry2D.offset_polygon(
		outer_polygon,
		-margin,
		Geometry2D.JOIN_MITER
	)
	if inset_polygons.is_empty():
		return outer_polygon
	return inset_polygons[0]


func _merge_corner_radius() -> float:
	var max_radius := maxf(2.0, _cell_edge_margin() - 1.5)
	return minf(
		maxf(MERGE_CORNER_RADIUS_MIN, _cell_size * MERGE_CORNER_RADIUS_RATIO),
		max_radius
	)


static func _merge_corner_radius_for_size(cell_size: float) -> float:
	var margin := maxf(3.0, cell_size * CELL_EDGE_MARGIN_RATIO)
	var max_radius := maxf(2.0, margin - 1.5)
	return minf(
		maxf(MERGE_CORNER_RADIUS_MIN, cell_size * MERGE_CORNER_RADIUS_RATIO),
		max_radius
	)


static func _rounded_rect_points(rect: Rect2, radius: float, segments: int = MERGE_CORNER_ARC_SEGMENTS) -> PackedVector2Array:
	var points := PackedVector2Array()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return points

	radius = minf(radius, minf(rect.size.x * 0.5, rect.size.y * 0.5))
	if radius <= 0.0:
		points.append_array(PackedVector2Array([
			rect.position,
			rect.position + Vector2(rect.size.x, 0.0),
			rect.position + rect.size,
			rect.position + Vector2(0.0, rect.size.y),
		]))
		return points

	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x
	var bottom := rect.position.y + rect.size.y
	var corners := [
		{"center": Vector2(right - radius, top + radius), "start": PI * 1.5, "end": PI * 2.0},
		{"center": Vector2(right - radius, bottom - radius), "start": 0.0, "end": PI * 0.5},
		{"center": Vector2(left + radius, bottom - radius), "start": PI * 0.5, "end": PI},
		{"center": Vector2(left + radius, top + radius), "start": PI, "end": PI * 1.5},
	]

	for corner in corners:
		var center: Vector2 = corner["center"]
		var start_angle: float = corner["start"]
		var end_angle: float = corner["end"]
		for segment in range(segments + 1):
			var t := float(segment) / float(segments)
			var angle := lerpf(start_angle, end_angle, t)
			points.append(center + Vector2.from_angle(angle) * radius)

	return points


static func _draw_rounded_rect_filled(
	canvas: CanvasItem,
	rect: Rect2,
	color: Color,
	radius: float
) -> void:
	var points := _rounded_rect_points(rect, radius)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _round_convex_corners(polygon: PackedVector2Array, radius: float) -> PackedVector2Array:
	var count := polygon.size()
	if count < 3 or radius <= 0.0:
		return polygon

	var ccw := _polygon_area(polygon) > 0.0
	var rounded := PackedVector2Array()

	for index in count:
		var prev := polygon[(index - 1 + count) % count]
		var curr := polygon[index]
		var next := polygon[(index + 1) % count]
		var in_edge := curr - prev
		var out_edge := next - curr
		var in_len := in_edge.length()
		var out_len := out_edge.length()
		if in_len < 0.001 or out_len < 0.001:
			rounded.append(curr)
			continue

		var in_dir := in_edge / in_len
		var out_dir := out_edge / out_len
		var cross := in_dir.x * out_dir.y - in_dir.y * out_dir.x
		var is_convex := cross > 0.0 if ccw else cross < 0.0
		if not is_convex:
			rounded.append(curr)
			continue

		var trim := minf(radius, minf(in_len, out_len) * 0.45)
		var start := curr - in_dir * trim
		var end := curr + out_dir * trim
		var inward := Vector2(-in_dir.y, in_dir.x) if ccw else Vector2(in_dir.y, -in_dir.x)
		if inward.dot(out_dir) < 0.0:
			inward = -inward
		var center := start + inward * trim

		rounded.append(start)
		var angle_start := (start - center).angle()
		var angle_end := (end - center).angle()
		for segment in range(1, MERGE_CORNER_ARC_SEGMENTS):
			var t := float(segment) / float(MERGE_CORNER_ARC_SEGMENTS)
			var angle := lerp_angle(angle_start, angle_end, t)
			rounded.append(center + Vector2.from_angle(angle) * trim)
		rounded.append(end)

	return rounded


func _merge_body_polygon(body_polygon: PackedVector2Array) -> PackedVector2Array:
	if block_kind != BlockKind.MERGE:
		return body_polygon
	return _round_convex_corners(body_polygon, _merge_corner_radius())


func _polygon_area(polygon: PackedVector2Array) -> float:
	var count := polygon.size()
	if count < 3:
		return 0.0

	var area := 0.0
	for index in count:
		var next := (index + 1) % count
		area += polygon[index].x * polygon[next].y
		area -= polygon[next].x * polygon[index].y
	return area * 0.5


func _moving_blend_overlay(
	full_body: PackedVector2Array,
	half: float,
	cell_size: float
) -> PackedVector2Array:
	var moving_loop := _chain_boundary_edges(_cells_set_from_offsets(_merge_blend_moving_cells))
	if moving_loop.is_empty():
		return PackedVector2Array()

	var moving_outer := _build_outer_polygon(moving_loop, half, cell_size)
	var clipped := Geometry2D.intersect_polygons(full_body, moving_outer)
	if clipped.is_empty():
		return PackedVector2Array()

	var largest := clipped[0]
	var largest_area := absf(_polygon_area(largest))
	for polygon in clipped:
		var area := absf(_polygon_area(polygon))
		if area > largest_area:
			largest = polygon
			largest_area = area
	return largest


func _polygon_with_offset(polygon: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	if offset == Vector2.ZERO:
		return polygon

	var shifted := PackedVector2Array()
	shifted.resize(polygon.size())
	for index in polygon.size():
		shifted[index] = polygon[index] + offset
	return shifted


func _draw_drag_focus_border(body_polygon: PackedVector2Array) -> void:
	if not _drag_focus or body_polygon.size() < 3:
		return

	var base_fill := DRAG_FOCUS_COLOR
	base_fill.a = FOCUS_CHEVRON_ALPHA * 0.35
	draw_colored_polygon(body_polygon, base_fill)

	var scroll := Time.get_ticks_msec() / 1000.0 * FOCUS_CHEVRON_SCROLL_SPEED
	_draw_focus_chevrons_on_polygon(body_polygon, scroll)


static func _draw_diagonal_bands_on_polygon(
	canvas: CanvasItem,
	clip_polygon: PackedVector2Array,
	scroll: float,
	period: float,
	layers: Array,
	color: Color,
	normal: Vector2,
	tangent: Vector2
) -> void:
	if clip_polygon.size() < 3 or period <= 0.0:
		return

	var min_d := INF
	var max_d := -INF
	var min_t := INF
	var max_t := -INF
	for point in clip_polygon:
		var d: float = point.dot(normal)
		var t: float = point.dot(tangent)
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
		min_t = minf(min_t, t)
		max_t = maxf(max_t, t)

	var tangent_mid := (min_t + max_t) * 0.5
	var max_layer_width := 0.0
	for layer_variant in layers:
		max_layer_width = maxf(max_layer_width, float(layer_variant[0]))
	var tangent_half := (max_t - min_t) * 0.5 + max_layer_width
	var band_offset := tangent * tangent_mid
	var index_start: int = int(floor((min_d - scroll) / period)) - 1
	var index_end: int = int(ceil((max_d - scroll) / period)) + 1

	for index in range(index_start, index_end + 1):
		var wave_center_d := float(index) * period + scroll
		for layer_variant in layers:
			var layer_width: float = layer_variant[0]
			var layer_alpha: float = layer_variant[1]
			var half_width := layer_width * 0.5
			var d0 := wave_center_d - half_width
			var d1 := wave_center_d + half_width
			var center0: Vector2 = normal * d0 + band_offset
			var center1: Vector2 = normal * d1 + band_offset
			var points := PackedVector2Array([
				center0 - tangent * tangent_half,
				center1 - tangent * tangent_half,
				center1 + tangent * tangent_half,
				center0 + tangent * tangent_half,
			])
			var band_color := color
			band_color.a = layer_alpha
			var clipped: Array = Geometry2D.intersect_polygons(points, clip_polygon)
			for poly in clipped:
				if poly.size() >= 3:
					canvas.draw_colored_polygon(poly, band_color)


static func _draw_merge_shine_on_polygon(
	canvas: CanvasItem,
	clip_polygon: PackedVector2Array,
	base_color: Color,
	time_ms: float
) -> void:
	if clip_polygon.size() < 3:
		return
	var scroll := time_ms / 1000.0 * MERGE_SHINE_SCROLL_SPEED
	var shine_color := base_color.lightened(MERGE_SHINE_LIFT)
	_draw_diagonal_bands_on_polygon(
		canvas,
		clip_polygon,
		scroll,
		MERGE_SHINE_PERIOD,
		MERGE_SHINE_SOFT_LAYERS,
		shine_color,
		_SHINE_NORMAL,
		_SHINE_TANGENT
	)


func _draw_focus_chevrons_on_polygon(clip_polygon: PackedVector2Array, scroll: float) -> void:
	var stripe_color := DRAG_FOCUS_COLOR
	stripe_color.a = FOCUS_CHEVRON_ALPHA
	var step := FOCUS_CHEVRON_STRIPE_WIDTH
	var normal := _FOCUS_CHEVRON_NORMAL
	var tangent := _FOCUS_CHEVRON_TANGENT
	var min_d := INF
	var max_d := -INF
	var min_t := INF
	var max_t := -INF
	for point in clip_polygon:
		var d: float = point.dot(normal)
		var t: float = point.dot(tangent)
		min_d = minf(min_d, d)
		max_d = maxf(max_d, d)
		min_t = minf(min_t, t)
		max_t = maxf(max_t, t)

	var tangent_mid := (min_t + max_t) * 0.5
	var tangent_half := (max_t - min_t) * 0.5 + step * 2.0
	var band_offset := tangent * tangent_mid
	var index_start: int = int(floor((min_d - scroll) / step)) - 1
	var index_end: int = int(ceil((max_d - scroll) / step)) + 1

	for index in range(index_start, index_end + 1):
		var d0: float = float(index) * step + scroll
		var d1: float = d0 + step
		var center0: Vector2 = normal * d0 + band_offset
		var center1: Vector2 = normal * d1 + band_offset
		var points := PackedVector2Array([
			center0 - tangent * tangent_half,
			center1 - tangent * tangent_half,
			center1 + tangent * tangent_half,
			center0 + tangent * tangent_half,
		])
		stripe_color.a = FOCUS_CHEVRON_ALPHA if index % 2 == 0 else FOCUS_CHEVRON_ALPHA * 0.2
		var clipped: Array = Geometry2D.intersect_polygons(points, clip_polygon)
		for poly in clipped:
			if poly.size() >= 3:
				draw_colored_polygon(poly, stripe_color)


func _draw() -> void:
	if _cell_size <= 0:
		return

	var half := _cell_size / 2.0
	var cell_size := float(_cell_size)
	var margin := _cell_edge_margin()
	var edge_loop := _chain_boundary_edges(_shape_cells_set())
	if edge_loop.is_empty():
		return

	var outer_polygon := _build_outer_polygon(edge_loop, half, cell_size)
	var body_polygon := _merge_body_polygon(_build_body_polygon(outer_polygon, margin))
	var nudged_body := _polygon_with_offset(body_polygon, _merge_impact_offset)
	draw_colored_polygon(outer_polygon, _current_tint_color())

	if is_merge_blending() and not _merge_blend_moving_cells.is_empty():
		draw_colored_polygon(nudged_body, _merge_region_fill_color(_merge_fill_from))
		var moving_overlay := _moving_blend_overlay(body_polygon, half, cell_size)
		if not moving_overlay.is_empty():
			draw_colored_polygon(
				_polygon_with_offset(moving_overlay, _merge_impact_offset),
				_merge_region_fill_color(_merge_blend_from_moving)
			)
		return

	var fill_color := _current_fill_color()
	draw_colored_polygon(nudged_body, fill_color)
	if block_kind == BlockKind.MERGE and not is_interaction_active():
		_draw_merge_shine_on_polygon(self, nudged_body, fill_color, float(Time.get_ticks_msec()))
	_draw_drag_focus_border(nudged_body)
