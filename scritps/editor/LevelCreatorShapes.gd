extends RefCounted
class_name LevelCreatorShapes


static func as_cells(raw: Variant) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if raw is Array:
		for item in raw:
			if item is Vector2i:
				cells.append(item)
	return cells


static func is_orthogonal_neighbor(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


static func is_orthogonally_connected(cells: Array[Vector2i]) -> bool:
	if cells.size() <= 1:
		return true
	var start: Vector2i = cells[0]
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var count: int = 0
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		count += 1
		for other in cells:
			if other in visited:
				continue
			if is_orthogonal_neighbor(current, other):
				visited[other] = true
				queue.append(other)
	return count == cells.size()


static func can_add_cell(
	shape_cells_raw: Variant,
	cell: Vector2i,
	blocked_cells_raw: Variant
) -> bool:
	var shape_cells := as_cells(shape_cells_raw)
	var blocked_cells := as_cells(blocked_cells_raw)
	if cell in blocked_cells:
		return false
	if cell in shape_cells:
		return false
	if shape_cells.is_empty():
		return true
	for existing in shape_cells:
		if is_orthogonal_neighbor(existing, cell):
			return true
	return false


static func can_remove_cell(shape_cells_raw: Variant, cell: Vector2i) -> bool:
	var shape_cells := as_cells(shape_cells_raw)
	if cell not in shape_cells:
		return false
	var remaining: Array[Vector2i] = []
	for existing in shape_cells:
		if existing != cell:
			remaining.append(existing)
	return is_orthogonally_connected(remaining)


static func cells_to_anchor_and_offsets(cells_raw: Variant) -> Dictionary:
	var cells := as_cells(cells_raw)
	if cells.is_empty():
		return {"anchor": Vector2i.ZERO, "offsets": []}
	var min_x: int = cells[0].x
	var min_y: int = cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	var anchor := Vector2i(min_x, min_y)
	var offsets: Array[Vector2i] = []
	for cell in cells:
		offsets.append(cell - anchor)
	return {"anchor": anchor, "offsets": offsets}


static func offsets_to_cells(anchor: Vector2i, offsets: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in offsets:
		if offset is Vector2i:
			cells.append(anchor + offset)
	return cells


static func largest_connected_component(cells: Array[Vector2i]) -> Array[Vector2i]:
	if cells.is_empty():
		return []
	var best: Array[Vector2i] = []
	for start in cells:
		var component: Array[Vector2i] = []
		var visited: Dictionary = {}
		var queue: Array[Vector2i] = [start]
		visited[start] = true
		while not queue.is_empty():
			var current: Vector2i = queue.pop_front()
			component.append(current)
			for other in cells:
				if other in visited:
					continue
				if is_orthogonal_neighbor(current, other):
					visited[other] = true
					queue.append(other)
		if component.size() > best.size():
			best = component
	return best


static func default_shape_name(index: int) -> String:
	return tr("UI_CREATOR_SHAPE_DEFAULT_NAME") % (index + 1)
