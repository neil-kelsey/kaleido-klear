extends RefCounted
class_name LevelGenRules

## Shared constraints for automated level creation / curation.
## - No tiny finger-unfriendly pieces: every clearable block is at least MIN_CELLS.
## - No empty playable cells: every cell is either occupied or disabled.
## - Disabled cells (holes) count as complexity — prefer full fills for easy levels.

const MIN_CELLS := 3


static func validate(config: LevelConfig) -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []
	if config == null:
		return {"ok": false, "errors": ["null config"], "warnings": warnings}

	var cols := config.columns
	var rows := config.rows
	if cols < 1 or rows < 1:
		errors.append("invalid grid size %dx%d" % [cols, rows])
		return {"ok": false, "errors": errors, "warnings": warnings}

	var occupied: Dictionary = {} ## Vector2i -> block index
	var disabled: Dictionary = {}
	for cell in config.disabled_cells:
		disabled[cell] = true

	var block_count := config.block_positions.size()
	for i in block_count:
		var kind := (
			int(config.block_kinds[i]) if i < config.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		var cells := absolute_cells(config, i)
		if cells.is_empty():
			errors.append("block %d has no cells" % i)
			continue
		if not Block.is_wall_kind(kind as Block.BlockKind) and cells.size() < MIN_CELLS:
			errors.append(
				"block %d has %d cells (minimum is %d)" % [i, cells.size(), MIN_CELLS]
			)
		if not _is_orthogonally_connected(cells):
			errors.append(
				"block %d is not orthogonally connected — diagonal-only joins are invalid"
				% i
			)
		if not Block.is_wall_kind(kind as Block.BlockKind) and _is_full_span_bar(cells, cols, rows):
			errors.append(
				"block %d is a full-span straight bar — use a more interesting polyomino" % i
			)
		for cell in cells:
			if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
				errors.append("block %d cell %s out of bounds" % [i, cell])
				continue
			if disabled.has(cell):
				errors.append("block %d overlaps disabled cell %s" % [i, cell])
			if occupied.has(cell):
				errors.append(
					"cell %s overlapped by blocks %d and %d" % [cell, occupied[cell], i]
				)
			occupied[cell] = i

	var empty: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if occupied.has(cell) or disabled.has(cell):
				continue
			empty.append(cell)
	if not empty.is_empty():
		errors.append(
			"board has %d empty playable cell(s); fill with shapes or disable them (e.g. %s)"
			% [empty.size(), empty[0]]
		)

	if not config.disabled_cells.is_empty():
		warnings.append(
			"disabled cells=%d (treated as added complexity)" % config.disabled_cells.size()
		)

	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"occupied": occupied.size(),
		"disabled": disabled.size(),
		"empty": empty.size(),
	}


static func absolute_cells(config: LevelConfig, index: int) -> Array[Vector2i]:
	var anchor := (
		config.block_positions[index] if index < config.block_positions.size() else Vector2i.ZERO
	)
	var offsets := cell_offsets(config, index)
	var out: Array[Vector2i] = []
	for offset in offsets:
		out.append(anchor + offset)
	return out


static func cell_offsets(config: LevelConfig, index: int) -> Array[Vector2i]:
	if (
		index < config.block_cell_patterns.size()
		and config.block_cell_patterns[index] is Array
		and (config.block_cell_patterns[index] as Array).size() > 0
	):
		var pattern: Array[Vector2i] = []
		for cell in config.block_cell_patterns[index]:
			pattern.append(cell as Vector2i)
		return pattern
	var shape_id := (
		str(config.block_shapes[index]) if index < config.block_shapes.size() else BlockShapes.SINGLE
	)
	return BlockShapes.get_cells(shape_id)


## Pack absolute cells into anchor + local offsets (top-left anchor).
static func pack_cells(cells: Array[Vector2i]) -> Dictionary:
	if cells.is_empty():
		return {"anchor": Vector2i.ZERO, "offsets": [] as Array[Vector2i]}
	var anchor := cells[0]
	for cell in cells:
		anchor.x = mini(anchor.x, cell.x)
		anchor.y = mini(anchor.y, cell.y)
	var offsets: Array[Vector2i] = []
	for cell in cells:
		offsets.append(cell - anchor)
	return {"anchor": anchor, "offsets": offsets}


## Edge-adjacent (4-connected) polyomino check. Diagonal-only joins are invalid.
static func _is_orthogonally_connected(cells: Array[Vector2i]) -> bool:
	if cells.size() <= 1:
		return true
	var want: Dictionary = {}
	for cell in cells:
		want[cell] = true
	var stack: Array[Vector2i] = [cells[0]]
	var seen: Dictionary = {cells[0]: true}
	var dirs: Array[Vector2i] = [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for dir in dirs:
			var next: Vector2i = cur + dir
			if want.has(next) and not seen.has(next):
				seen[next] = true
				stack.append(next)
	return seen.size() == want.size()


## True for a 1×N / N×1 line that spans the full board width or height.
static func _is_full_span_bar(cells: Array[Vector2i], cols: int, rows: int) -> bool:
	if cells.size() < 3:
		return false
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var w := max_x - min_x + 1
	var h := max_y - min_y + 1
	if h == 1 and w == cells.size() and w == cols:
		return true
	if w == 1 and h == cells.size() and h == rows:
		return true
	return false
