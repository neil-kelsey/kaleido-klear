extends RefCounted
class_name LevelDifficulty

## Heuristic complexity score for distributing levels across dimensions.
## Lower = easier (early dimensions). Higher = harder (later dimensions).


static func rate(config: LevelConfig, min_moves: int = -1) -> Dictionary:
	var area := float(maxi(config.columns, 1) * maxi(config.rows, 1))
	var colors := _unique_colors(config)
	var block_count := config.block_positions.size()
	var wall_count := 0
	var merge_count := 0
	var shape_cells := 0
	for i in block_count:
		var kind := (
			int(config.block_kinds[i]) if i < config.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if kind == int(Block.BlockKind.WALL):
			wall_count += 1
		elif kind == int(Block.BlockKind.MERGE):
			merge_count += 1
		shape_cells += _cell_count(config, i)

	var hole_count := config.disabled_cells.size()
	var goal_edges := 0
	if config.goal_left_enabled:
		goal_edges += 1
	if config.goal_top_enabled:
		goal_edges += 1
	if config.goal_right_enabled:
		goal_edges += 1
	if config.goal_bottom_enabled:
		goal_edges += 1

	var score := 0.0
	score += area / 5.0
	score += float(colors) * 2.2
	score += float(block_count) * 1.1
	## Fat pieces are required now (min 3); only mild weight for oversized / awkward shapes.
	score += float(maxi(shape_cells - block_count * 3, 0)) * 0.25
	score += float(wall_count) * 2.5
	score += float(merge_count) * 3.5
	## Holes (disabled cells) are an intentional complexity lever vs filling with shapes.
	score += float(hole_count) * 2.0
	score += float(maxi(goal_edges - 1, 0)) * 0.6
	if config.multi_goal_mode:
		score += 4.0
	if min_moves >= 0:
		score += float(min_moves) * 0.45

	## Full solid boards (no holes) stay easier than carved boards of the same size.
	if hole_count == 0 and block_count > 0:
		score *= 0.85

	var tier := 1
	if score >= 18.5:
		tier = 2
	if score >= 28.0:
		tier = 3
	if score >= 40.0:
		tier = 4
	if score >= 54.0:
		tier = 5

	return {
		"score": snappedf(score, 0.01),
		"tier": tier,
		"colors": colors,
		"walls": wall_count,
		"merges": merge_count,
		"blocks": block_count,
		"area": int(area),
		"min_moves": min_moves,
	}


static func _unique_colors(config: LevelConfig) -> int:
	var seen := {}
	for i in config.block_colors.size():
		var kind := (
			int(config.block_kinds[i]) if i < config.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if kind == int(Block.BlockKind.WALL):
			continue
		seen[int(config.block_colors[i])] = true
	return seen.size()


static func _cell_count(config: LevelConfig, index: int) -> int:
	if index < config.block_cell_patterns.size() and config.block_cell_patterns[index] is Array:
		return (config.block_cell_patterns[index] as Array).size()
	var shape_id := (
		str(config.block_shapes[index]) if index < config.block_shapes.size() else BlockShapes.SINGLE
	)
	return BlockShapes.get_cells(shape_id).size()
