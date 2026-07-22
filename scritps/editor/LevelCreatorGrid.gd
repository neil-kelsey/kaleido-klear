extends Control
class_name LevelCreatorGrid

signal cell_clicked(cell: Vector2i, button_index: int)

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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_on_resized()
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
	columns = grid_columns
	rows = grid_rows
	shapes = shape_list
	selected_shape_index = selected_index
	erase_mode = erase
	grid_edit_active = grid_edit
	grid_erase_mode = grid_erase
	disabled_cells = disabled
	_on_resized()
	queue_redraw()


func is_cell_disabled(cell: Vector2i) -> bool:
	return cell in disabled_cells


func _on_resized() -> void:
	if columns <= 0 or rows <= 0:
		return
	cell_size = mini(int(size.x / columns), int(size.y / rows))
	var grid_pixel := Vector2(columns * cell_size, rows * cell_size)
	grid_origin = (size - grid_pixel) * 0.5
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_cell = _pixel_to_cell(event.position)
		_update_hover_preview()
		queue_redraw()
		return

	if event is InputEventMouseButton and event.pressed:
		var cell := _pixel_to_cell(event.position)
		if cell.x >= 0:
			cell_clicked.emit(cell, event.button_index)


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
	if columns <= 0 or rows <= 0:
		return

	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			var rect := _cell_rect(cell)
			if is_cell_disabled(cell):
				draw_rect(rect, UiTheme.HOLE_TINT)
				continue
			draw_rect(rect, UiTheme.PLAYFIELD_TILE_BORDER)
			draw_rect(rect.grow(-1.0), UiTheme.PLAYFIELD_TILE)

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
		grid_origin + Vector2(cell) * float(cell_size),
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
