extends Control
class_name LevelCreatorGrid

signal cell_clicked(cell: Vector2i, button_index: int, is_drag: bool)
signal cell_edit_requested(cell: Vector2i)
signal paint_stroke_ended

## High-contrast editor grid (playfield colors are too close to see seams).
const GRID_FILL := Color(0.26, 0.28, 0.34, 1.0)
const GRID_BORDER := Color(0.08, 0.09, 0.12, 1.0)
const GRID_HOLE := Color(0.12, 0.12, 0.14, 1.0)
const LONG_PRESS_SEC := 0.45
const ZOOM_MIN := 0.5
const ZOOM_MAX := 12.0
const WHEEL_ZOOM_STEP := 0.14
const PINCH_ZOOM_SENSITIVITY := 1.0

var columns: int = 8
var rows: int = 8
var cell_size: int = 48
var grid_origin := Vector2.ZERO

var shapes: Array = []
var selected_shape_index: int = -1
var erase_mode: bool = false
var grid_edit_active: bool = false
var grid_erase_mode: bool = false
var disabled_cells: Array[Vector2i] = []

var _hover_cell := Vector2i(-1, -1)
var _preview_valid: bool = false
var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _press_held := false
var _long_fired := false
var _paint_drag := false
var _last_paint_cell := Vector2i(-1, -1)
var _long_timer: Timer
var _view_zoom := 1.0
var _pan_offset := Vector2.ZERO
var _middle_panning := false
var _pinch_active := false
var _pinch_touches: Dictionary = {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_last_midpoint := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)
	_on_resized()
	_long_timer = Timer.new()
	_long_timer.one_shot = true
	_long_timer.wait_time = LONG_PRESS_SEC
	_long_timer.timeout.connect(_on_long_press_timeout)
	add_child(_long_timer)
	set_process(true)


func _process(_delta: float) -> void:
	if _has_merge_shapes():
		queue_redraw()


func _has_merge_shapes() -> bool:
	for shape in shapes:
		if shape.get("kind", Block.BlockKind.STANDARD) == Block.BlockKind.MERGE:
			return true
	return false


func sync_shapes(
	shape_list: Array,
	grid_columns: int,
	grid_rows: int,
	selected_index: int,
	erase: bool,
	grid_edit: bool = false,
	grid_erase: bool = false,
	disabled: Array[Vector2i] = []
) -> void:
	var size_changed := columns != grid_columns or rows != grid_rows
	columns = grid_columns
	rows = grid_rows
	shapes = shape_list
	selected_shape_index = selected_index
	erase_mode = erase
	grid_edit_active = grid_edit
	grid_erase_mode = grid_erase
	disabled_cells = disabled
	if size_changed:
		_view_zoom = 1.0
		_pan_offset = Vector2.ZERO
	_on_resized()
	queue_redraw()


func is_cell_disabled(cell: Vector2i) -> bool:
	return cell in disabled_cells


func _on_resized() -> void:
	if columns <= 0 or rows <= 0:
		return
	_apply_view_transform()
	queue_redraw()


func _fit_cell_size() -> int:
	if columns <= 0 or rows <= 0 or size.x < 2.0 or size.y < 2.0:
		return 8
	return maxi(2, mini(int(size.x / columns), int(size.y / rows)))


func _apply_view_transform() -> void:
	cell_size = maxi(2, int(round(float(_fit_cell_size()) * _view_zoom)))
	var grid_pixel := Vector2(columns * cell_size, rows * cell_size)
	var centered := ((size - grid_pixel) * 0.5).floor()
	if grid_pixel.x <= size.x:
		_pan_offset.x = 0.0
		grid_origin.x = centered.x
	else:
		grid_origin.x = clampf(centered.x + _pan_offset.x, size.x - grid_pixel.x, 0.0)
		_pan_offset.x = grid_origin.x - centered.x
	if grid_pixel.y <= size.y:
		_pan_offset.y = 0.0
		grid_origin.y = centered.y
	else:
		grid_origin.y = clampf(centered.y + _pan_offset.y, size.y - grid_pixel.y, 0.0)
		_pan_offset.y = grid_origin.y - centered.y


func _zoom_at_local(local_point: Vector2, new_zoom: float) -> void:
	var old_cell := float(maxi(cell_size, 1))
	var old_origin := grid_origin
	var cell_pos := (local_point - old_origin) / old_cell
	_view_zoom = clampf(new_zoom, ZOOM_MIN, ZOOM_MAX)
	_apply_view_transform()
	var desired_origin := local_point - cell_pos * float(cell_size)
	_pan_offset += desired_origin - grid_origin
	_apply_view_transform()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_local(mb.position, _view_zoom * (1.0 + WHEEL_ZOOM_STEP))
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_local(mb.position, _view_zoom * (1.0 - WHEEL_ZOOM_STEP))
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_middle_panning = mb.pressed
			accept_event()
			return

	if event is InputEventScreenTouch:
		if _handle_pinch_touch(event as InputEventScreenTouch):
			accept_event()
			return

	if event is InputEventScreenDrag:
		if _handle_pinch_drag(event as InputEventScreenDrag):
			accept_event()
			return

	if _pinch_active:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _middle_panning:
			_pan_offset += motion.relative
			_apply_view_transform()
			queue_redraw()
			accept_event()
			return
		_hover_cell = _pixel_to_cell(motion.position)
		_update_hover_preview()
		queue_redraw()
		if _press_held and not _long_fired:
			_try_paint_drag(_hover_cell)
		return

	if event is InputEventMouseButton:
		var cell := _pixel_to_cell(event.position)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and cell.x >= 0:
			_cancel_press()
			cell_edit_requested.emit(cell)
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			if cell.x < 0:
				return
			_press_cell = cell
			_press_pos = event.position
			_press_held = true
			_long_fired = false
			_paint_drag = false
			_last_paint_cell = Vector2i(-1, -1)
			_long_timer.start()
			accept_event()
		else:
			var emit_cell := _press_cell
			var fired := _long_fired
			var painted := _paint_drag
			_cancel_press()
			if not fired and not painted and emit_cell.x >= 0:
				cell_clicked.emit(emit_cell, MOUSE_BUTTON_LEFT, false)
			paint_stroke_ended.emit()
			accept_event()


func _handle_pinch_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_pinch_touches[event.index] = event.position
		if _pinch_touches.size() >= 2:
			_cancel_press()
			_begin_pinch()
			return true
		return false
	var pinching := _pinch_active or _pinch_touches.size() >= 2
	_pinch_touches.erase(event.index)
	if _pinch_touches.size() < 2:
		_pinch_active = false
	return pinching


func _handle_pinch_drag(event: InputEventScreenDrag) -> bool:
	if not _pinch_touches.has(event.index):
		return false
	_pinch_touches[event.index] = event.position
	if _pinch_touches.size() < 2:
		return false
	if not _pinch_active:
		_cancel_press()
		_begin_pinch()
	_update_pinch()
	return true


func _pinch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in _pinch_touches.keys():
		points.append(_pinch_touches[key])
		if points.size() >= 2:
			break
	return points


func _begin_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2:
		return
	_pinch_active = true
	_pinch_start_distance = points[0].distance_to(points[1])
	_pinch_start_zoom = _view_zoom
	_pinch_last_midpoint = (points[0] + points[1]) * 0.5


func _update_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2 or _pinch_start_distance <= 0.001:
		return
	var midpoint := (points[0] + points[1]) * 0.5
	var distance := points[0].distance_to(points[1])
	var target_zoom := _pinch_start_zoom * (distance / _pinch_start_distance) * PINCH_ZOOM_SENSITIVITY
	_zoom_at_local(midpoint, target_zoom)
	var mid_delta := midpoint - _pinch_last_midpoint
	if mid_delta.length_squared() > 0.01:
		_pan_offset += mid_delta
		_apply_view_transform()
		queue_redraw()
	_pinch_last_midpoint = midpoint


func _on_long_press_timeout() -> void:
	if not _press_held or _press_cell.x < 0 or _paint_drag:
		return
	_long_fired = true
	cell_edit_requested.emit(_press_cell)


func _try_paint_drag(cell: Vector2i) -> void:
	if cell.x < 0:
		return
	if not _paint_drag:
		if cell == _press_cell:
			return
		_paint_drag = true
		if _long_timer != null:
			_long_timer.stop()
		if _press_cell.x >= 0:
			cell_clicked.emit(_press_cell, MOUSE_BUTTON_LEFT, true)
			_last_paint_cell = _press_cell
	if cell == _last_paint_cell:
		return
	for step in _cells_on_line(_last_paint_cell, cell):
		if step == _last_paint_cell:
			continue
		_last_paint_cell = step
		cell_clicked.emit(step, MOUSE_BUTTON_LEFT, true)


func _cells_on_line(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var dx := absi(to_cell.x - from_cell.x)
	var dy := -absi(to_cell.y - from_cell.y)
	var sx := 1 if from_cell.x < to_cell.x else -1
	var sy := 1 if from_cell.y < to_cell.y else -1
	var err := dx + dy
	var x := from_cell.x
	var y := from_cell.y
	while true:
		cells.append(Vector2i(x, y))
		if x == to_cell.x and y == to_cell.y:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x += sx
		if e2 <= dx:
			err += dx
			y += sy
	return cells


func _cancel_press() -> void:
	_press_held = false
	_press_cell = Vector2i(-1, -1)
	_paint_drag = false
	_last_paint_cell = Vector2i(-1, -1)
	if _long_timer != null:
		_long_timer.stop()


func _update_hover_preview() -> void:
	_preview_valid = false
	if _hover_cell.x < 0:
		return
	if grid_edit_active:
		if grid_erase_mode:
			_preview_valid = (
				not is_cell_disabled(_hover_cell)
				and find_shape_at_cell(_hover_cell) == -1
			)
		else:
			_preview_valid = is_cell_disabled(_hover_cell)
		return
	if erase_mode:
		_preview_valid = find_shape_at_cell(_hover_cell) != -1
		return
	if selected_shape_index < 0 or selected_shape_index >= shapes.size():
		return
	if is_cell_disabled(_hover_cell):
		return
	var shape: Dictionary = shapes[selected_shape_index]
	var blocked := _blocked_cells_except(selected_shape_index)
	_preview_valid = LevelCreatorShapes.can_add_cell(shape["cells"], _hover_cell, blocked)


func _draw() -> void:
	if columns <= 0 or rows <= 0 or cell_size <= 2:
		return

	## Same approach as the playfield: full cell = border color, inset = fill.
	## Dark border on lighter fill keeps every seam visible under UI scale.
	var view := Rect2(Vector2.ZERO, size).grow(float(cell_size))
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			if not view.intersects(rect):
				continue
			if is_cell_disabled(cell):
				draw_rect(rect, GRID_HOLE)
				continue
			draw_rect(rect, GRID_BORDER)
			draw_rect(
				Rect2(rect.position + Vector2.ONE, Vector2(cell_size - 2, cell_size - 2)),
				GRID_FILL
			)

	for i in shapes.size():
		_draw_shape(i)

	if _hover_cell.x >= 0:
		if grid_edit_active:
			var rect := _cell_rect(_hover_cell)
			if grid_erase_mode:
				if not is_cell_disabled(_hover_cell) and find_shape_at_cell(_hover_cell) == -1:
					draw_rect(rect.grow(-2.0), Color(0.95, 0.4, 0.4, 0.9), false, 2.0)
			elif is_cell_disabled(_hover_cell):
				draw_rect(rect.grow(-2.0), Color(0.4, 0.85, 0.5, 0.9), false, 2.0)
		elif erase_mode:
			if find_shape_at_cell(_hover_cell) != -1:
				var rect := _cell_rect(_hover_cell)
				draw_rect(rect, Color(0.95, 0.3, 0.3, 0.55))
		elif selected_shape_index >= 0 and selected_shape_index < shapes.size():
			_draw_hover_preview()


func _draw_shape(index: int) -> void:
	if index < 0 or index >= shapes.size():
		return
	var shape: Dictionary = shapes[index]
	var kind: Block.BlockKind = shape.get("kind", Block.BlockKind.STANDARD)
	var fill := Block.WALL_FILL if Block.is_wall_kind(kind) else Block.get_color(shape.get("color", Block.TileColor.RED))
	var is_selected := index == selected_shape_index
	for cell in LevelCreatorShapes.as_cells(shape["cells"]):
		var rect := _cell_rect(cell)
		if kind == Block.BlockKind.MERGE:
			Block.draw_merge_cell_rect(self, rect, fill, cell, float(Time.get_ticks_msec()))
		else:
			draw_rect(rect, fill)
		if is_selected:
			draw_rect(rect.grow(-2.0), Color(1.0, 1.0, 1.0, 0.35), false, 2.0)


func _draw_hover_preview() -> void:
	var shape: Dictionary = shapes[selected_shape_index]
	var kind: Block.BlockKind = shape.get("kind", Block.BlockKind.STANDARD)
	var fill := Block.WALL_FILL if Block.is_wall_kind(kind) else Block.get_color(shape.get("color", Block.TileColor.RED))
	fill.a = 0.45 if _preview_valid else 0.35
	if not _preview_valid:
		fill = Color(fill.r * 0.5 + 0.5, fill.g * 0.3, fill.b * 0.3, fill.a)
	draw_rect(_cell_rect(_hover_cell), fill)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(
		grid_origin + Vector2(cell.x * cell_size, cell.y * cell_size),
		Vector2(cell_size, cell_size)
	)


func _pixel_to_cell(position: Vector2) -> Vector2i:
	var local := position - grid_origin
	if local.x < 0.0 or local.y < 0.0:
		return Vector2i(-1, -1)
	var cell := Vector2i(int(local.x / cell_size), int(local.y / cell_size))
	if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
		return Vector2i(-1, -1)
	return cell


func find_shape_at_cell(cell: Vector2i) -> int:
	for i in shapes.size():
		if cell in LevelCreatorShapes.as_cells(shapes[i]["cells"]):
			return i
	return -1


func _blocked_cells_except(ignore_index: int) -> Array[Vector2i]:
	var blocked: Array[Vector2i] = []
	for i in shapes.size():
		if i == ignore_index:
			continue
		for cell in LevelCreatorShapes.as_cells(shapes[i]["cells"]):
			blocked.append(cell)
	return blocked
