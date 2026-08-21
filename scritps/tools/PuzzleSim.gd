extends RefCounted
class_name PuzzleSim

## Pure puzzle rules for headless solving — mirrors Board slide / score / merge
## without scenes, tweens, or input. Walls never move; win = no non-wall blocks left.

enum Placement { OK, OUT_OF_BOUNDS, BLOCKED }
enum Outcome { NONE, SLIDE, SCORE, MERGE, FAIL }

const DIRS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]


class SimBlock:
	var id: int = 0
	var pos: Vector2i = Vector2i.ZERO
	var color: int = 0
	var kind: int = 0
	var cells: Array[Vector2i] = [Vector2i.ZERO]

	func duplicate_block() -> SimBlock:
		var copy := SimBlock.new()
		copy.id = id
		copy.pos = pos
		copy.color = color
		copy.kind = kind
		copy.cells = cells.duplicate()
		return copy

	func occupied(anchor: Vector2i = pos) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for offset in cells:
			out.append(anchor + offset)
		return out


class SimState:
	var blocks: Array = [] ## Array[SimBlock]
	var lives: int = 3
	var next_id: int = 1
	## Multi-goal edge progress: phase index + scored count per edge (L,T,R,B).
	var edge_phase: Array[int] = [0, 0, 0, 0]
	var edge_scored: Array[int] = [0, 0, 0, 0]

	func duplicate_state() -> SimState:
		var copy := SimState.new()
		copy.lives = lives
		copy.next_id = next_id
		copy.edge_phase = edge_phase.duplicate()
		copy.edge_scored = edge_scored.duplicate()
		for block in blocks:
			copy.blocks.append((block as SimBlock).duplicate_block())
		return copy

	func fingerprint() -> String:
		var parts: PackedStringArray = [
			"L%d" % lives,
			"P%s" % ",".join(PackedStringArray([
				"%d:%d" % [edge_phase[0], edge_scored[0]],
				"%d:%d" % [edge_phase[1], edge_scored[1]],
				"%d:%d" % [edge_phase[2], edge_scored[2]],
				"%d:%d" % [edge_phase[3], edge_scored[3]],
			])),
		]
		var sortable: Array[String] = []
		for raw in blocks:
			var b: SimBlock = raw
			var cell_bits: PackedStringArray = []
			for c in b.cells:
				cell_bits.append("%d,%d" % [c.x, c.y])
			sortable.append(
				"%d:%d,%d:k%d:c%d:[%s]"
				% [b.kind, b.pos.x, b.pos.y, b.kind, b.color, ",".join(cell_bits)]
			)
		sortable.sort()
		parts.append_array(sortable)
		return "|".join(parts)

	func clearable_count() -> int:
		var n := 0
		for raw in blocks:
			if not Block.is_wall_kind((raw as SimBlock).kind):
				n += 1
		return n

	func is_won() -> bool:
		return clearable_count() == 0

	func is_lost() -> bool:
		return lives <= 0 and not is_won()


var columns: int = 5
var rows: int = 5
var disabled: Dictionary = {} ## Vector2i -> true
var goal_enabled: Array[bool] = [true, true, true, false]
var goal_colors: Array[int] = [0, 2, 1, 3]
var multi_goal_mode: bool = false
## Array[Array[Dictionary]] — each edge: [{color, count, unlimited}, ...]
var goal_phases: Array = [[], [], [], []]


func load_config(config: LevelConfig) -> SimState:
	columns = config.columns
	rows = config.rows
	disabled.clear()
	for cell in config.disabled_cells:
		disabled[cell] = true
	goal_enabled = [
		config.goal_left_enabled,
		config.goal_top_enabled,
		config.goal_right_enabled,
		config.goal_bottom_enabled,
	]
	goal_colors = [
		int(config.goal_left_color),
		int(config.goal_top_color),
		int(config.goal_right_color),
		int(config.goal_bottom_color),
	]
	multi_goal_mode = config.multi_goal_mode
	goal_phases = [
		_pack_phases(config.goal_left_phases),
		_pack_phases(config.goal_top_phases),
		_pack_phases(config.goal_right_phases),
		_pack_phases(config.goal_bottom_phases),
	]
	var state := SimState.new()
	var count := config.block_positions.size()
	for i in count:
		var block := SimBlock.new()
		block.id = state.next_id
		state.next_id += 1
		block.pos = config.block_positions[i]
		block.color = int(config.block_colors[i]) if i < config.block_colors.size() else 0
		block.kind = (
			int(config.block_kinds[i]) if i < config.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if i < config.block_cell_patterns.size() and config.block_cell_patterns[i] is Array:
			var pattern: Array = config.block_cell_patterns[i]
			block.cells.clear()
			for cell in pattern:
				block.cells.append(cell as Vector2i)
		else:
			var shape_id := (
				str(config.block_shapes[i]) if i < config.block_shapes.size() else BlockShapes.SINGLE
			)
			block.cells = BlockShapes.get_cells(shape_id)
		if block.cells.is_empty():
			block.cells = [Vector2i.ZERO]
		state.blocks.append(block)
	return state


func _pack_phases(phases: Array[GoalPhase]) -> Array:
	var out: Array = []
	for phase in phases:
		if phase == null:
			continue
		out.append({
			"color": int(phase.color),
			"count": int(phase.count),
			"unlimited": bool(phase.unlimited),
		})
	return out


func _edge_active(state: SimState, goal_edge: int) -> bool:
	if goal_edge < 0 or goal_edge > 3:
		return false
	if not goal_enabled[goal_edge]:
		return false
	if not multi_goal_mode:
		return true
	var phases: Array = goal_phases[goal_edge]
	return state.edge_phase[goal_edge] < phases.size()


func _edge_color(state: SimState, goal_edge: int) -> int:
	if not multi_goal_mode:
		return goal_colors[goal_edge]
	var phases: Array = goal_phases[goal_edge]
	var idx: int = state.edge_phase[goal_edge]
	if idx < 0 or idx >= phases.size():
		return -1
	return int(phases[idx].color)


func _record_edge_score(state: SimState, goal_edge: int) -> void:
	if not multi_goal_mode:
		return
	var phases: Array = goal_phases[goal_edge]
	var idx: int = state.edge_phase[goal_edge]
	if idx < 0 or idx >= phases.size():
		return
	var phase: Dictionary = phases[idx]
	if bool(phase.unlimited):
		return
	state.edge_scored[goal_edge] += 1
	if state.edge_scored[goal_edge] >= int(phase.count):
		state.edge_phase[goal_edge] += 1
		state.edge_scored[goal_edge] = 0


func apply_move(state: SimState, block_index: int, direction: Vector2i) -> Dictionary:
	## Returns { ok, outcome, state } — never mutates input.
	## Bounce rules match Board: failed exits / bumps animate out and return to the
	## start cell. They must NOT leave the block at the bounce edge (that bug let the
	## solver "solve" levels that are impossible in-game).
	var next := state.duplicate_state()
	if block_index < 0 or block_index >= next.blocks.size():
		return {"ok": false, "outcome": Outcome.NONE, "state": next}
	var moving: SimBlock = next.blocks[block_index]
	if Block.is_wall_kind(moving.kind):
		return {"ok": false, "outcome": Outcome.NONE, "state": next}

	var start_pos := moving.pos
	var slide := _compute_slide(next, moving, start_pos, direction)
	var target: Vector2i = slide.target
	var next_anchor: Vector2i = slide.next_anchor
	var next_result: Placement = slide.next_result
	var goal_edge: int = slide.goal_edge

	if (
		goal_edge != -1
		and next_result == Placement.OUT_OF_BOUNDS
		and _would_exit_goal(moving, next_anchor, goal_edge)
		and _edge_active(next, goal_edge)
	):
		if moving.color == _edge_color(next, goal_edge):
			next.blocks.remove_at(block_index)
			_record_edge_score(next, goal_edge)
			return {"ok": true, "outcome": Outcome.SCORE, "state": next}
		## Wrong-colour goal: bounce home + lose a life.
		next.lives -= 1
		moving.pos = start_pos
		return {"ok": next.lives > 0, "outcome": Outcome.FAIL, "state": next}

	if next_result == Placement.OUT_OF_BOUNDS and target != start_pos:
		## Inactive / non-goal screen edge: Board returns home with no life loss —
		## no puzzle-state change, so the solver ignores it.
		return {"ok": false, "outcome": Outcome.NONE, "state": next}

	if target == start_pos:
		if next_result == Placement.BLOCKED:
			var blocker_i := _blocking_index(next, moving, next_anchor)
			if blocker_i >= 0 and _can_merge(moving, next.blocks[blocker_i] as SimBlock):
				_merge_into(next, block_index, blocker_i)
				return {"ok": true, "outcome": Outcome.MERGE, "state": next}
			next.lives -= 1
			moving.pos = start_pos
			return {"ok": next.lives > 0, "outcome": Outcome.FAIL, "state": next}
		return {"ok": false, "outcome": Outcome.NONE, "state": next}

	if next_result == Placement.BLOCKED:
		var blocker_j := _blocking_index(next, moving, next_anchor)
		if blocker_j >= 0 and _can_merge(moving, next.blocks[blocker_j] as SimBlock):
			moving.pos = target
			_merge_into(next, block_index, blocker_j)
			return {"ok": true, "outcome": Outcome.MERGE, "state": next}
		## Collision bounce: return home + lose a life (do not stay at edge).
		next.lives -= 1
		moving.pos = start_pos
		return {"ok": next.lives > 0, "outcome": Outcome.FAIL, "state": next}

	moving.pos = target
	return {"ok": true, "outcome": Outcome.SLIDE, "state": next}


func legal_actions(state: SimState) -> Array[Dictionary]:
	var actions: Array[Dictionary] = []
	for i in state.blocks.size():
		var block: SimBlock = state.blocks[i]
		if Block.is_wall_kind(block.kind):
			continue
		for dir in DIRS:
			actions.append({"block_index": i, "direction": dir})
	return actions


func _compute_slide(state: SimState, block: SimBlock, start: Vector2i, direction: Vector2i) -> Dictionary:
	var target := start
	var next_anchor := target + direction
	while _placement(state, block, next_anchor) == Placement.OK:
		target = next_anchor
		next_anchor = target + direction
	return {
		"target": target,
		"next_anchor": next_anchor,
		"next_result": _placement(state, block, next_anchor),
		"goal_edge": _goal_for_direction(direction),
	}


func _placement(state: SimState, block: SimBlock, anchor: Vector2i) -> Placement:
	var saw_oob := false
	for offset in block.cells:
		var cell := anchor + offset
		if disabled.has(cell):
			return Placement.BLOCKED
		if not _in_bounds(cell):
			saw_oob = true
		else:
			var owner := _occupant(state, cell)
			if owner != null and owner != block:
				return Placement.BLOCKED
	if saw_oob:
		return Placement.OUT_OF_BOUNDS
	return Placement.OK


func _occupant(state: SimState, cell: Vector2i) -> SimBlock:
	for raw in state.blocks:
		var block: SimBlock = raw
		for occupied in block.occupied():
			if occupied == cell:
				return block
	return null


func _blocking_index(state: SimState, moving: SimBlock, next_anchor: Vector2i) -> int:
	for offset in moving.cells:
		var cell := next_anchor + offset
		if not _in_bounds(cell) or disabled.has(cell):
			continue
		for i in state.blocks.size():
			var other: SimBlock = state.blocks[i]
			if other == moving:
				continue
			for occupied in other.occupied():
				if occupied == cell:
					return i
	return -1


func _can_merge(a: SimBlock, b: SimBlock) -> bool:
	if Block.is_wall_kind(a.kind) or Block.is_wall_kind(b.kind):
		return false
	if a.kind != int(Block.BlockKind.MERGE) or b.kind != int(Block.BlockKind.MERGE):
		return false
	if (
		not Block.is_primary_merge_color(a.color as Block.TileColor)
		or not Block.is_primary_merge_color(b.color as Block.TileColor)
	):
		return false
	return Block.get_merged_color(a.color as Block.TileColor, b.color as Block.TileColor) != -1


func _merge_into(state: SimState, moving_i: int, blocker_i: int) -> void:
	var moving: SimBlock = state.blocks[moving_i]
	var blocker: SimBlock = state.blocks[blocker_i]
	var union_cells: Array[Vector2i] = []
	var seen := {}
	for cell in moving.occupied() + blocker.occupied():
		if seen.has(cell):
			continue
		seen[cell] = true
		union_cells.append(cell)
	var anchor := union_cells[0]
	for cell in union_cells:
		anchor.x = mini(anchor.x, cell.x)
		anchor.y = mini(anchor.y, cell.y)
	var offsets: Array[Vector2i] = []
	for cell in union_cells:
		offsets.append(cell - anchor)
	var merged := SimBlock.new()
	merged.id = state.next_id
	state.next_id += 1
	merged.pos = anchor
	merged.cells = offsets
	merged.kind = int(Block.BlockKind.MERGE)
	merged.color = Block.get_merged_color(
		moving.color as Block.TileColor,
		blocker.color as Block.TileColor
	)
	## Remove higher index first.
	var hi := maxi(moving_i, blocker_i)
	var lo := mini(moving_i, blocker_i)
	state.blocks.remove_at(hi)
	state.blocks.remove_at(lo)
	state.blocks.append(merged)


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _goal_for_direction(direction: Vector2i) -> int:
	if direction == Vector2i.LEFT:
		return 0
	if direction == Vector2i.UP:
		return 1
	if direction == Vector2i.RIGHT:
		return 2
	if direction == Vector2i.DOWN:
		return 3
	return -1


func _would_exit_goal(block: SimBlock, anchor: Vector2i, goal_edge: int) -> bool:
	for offset in block.cells:
		var cell := anchor + offset
		match goal_edge:
			0:
				if cell.x < 0:
					return true
			1:
				if cell.y < 0:
					return true
			2:
				if cell.x >= columns:
					return true
			3:
				if cell.y >= rows:
					return true
	return false
