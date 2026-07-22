extends Node2D
class_name Board

signal level_cleared(remaining_lives: int)
signal life_lost(remaining_lives: int)
signal game_over
signal goal_state_changed(goal_edge: int, state: Dictionary)
signal undo_available_changed(available: bool)
signal undo_applied(remaining_lives: int)

enum PlacementResult { OK, OUT_OF_BOUNDS, BLOCKED_BY_BLOCK }

const BlockScene := preload("res://scenes/block.tscn")
const GOAL_GRID_GAP := 14
## Extra inset so the playfield never sits flush against screen edges / HUD.
const PLAYFIELD_MARGIN := 56
const PLAYFIELD_MARGIN_BOTTOM := 96

enum GoalEdge { LEFT, TOP, RIGHT, BOTTOM }

@export var level_config: LevelConfig
@export var starting_lives: int = 3

var cell_size: int = 64
var grid_origin := Vector2.ZERO
var grid_columns: int = 8
var grid_rows: int = 8

var cell_occupant: Dictionary = {}
var _disabled_cells: Dictionary = {}
var placed_blocks: Array[Block] = []
var lives: int = 3
var is_busy := false
var game_ended := false

var selected_block: Block = null
var drag_start := Vector2.ZERO
var drag_anchor_start := Vector2i.ZERO
var drag_anchor_world := Vector2.ZERO
var drag_locked_axis := Vector2i.ZERO
var last_pointer_pos := Vector2.ZERO
var is_dragging := false
var active_pointer_id: int = -1
var drag_samples: Array[Dictionary] = []
var _multi_goal_states: Array[MultiGoalEdgeState] = []
var _undo_snapshot: Dictionary = {}

const DRAG_THRESHOLD := 20.0
const MAX_DRAG_PULL_RATIO := 0.5
const ELASTIC_SPRING_STRENGTH := 2.6
const MIN_ANIM_SPEED := 180.0
const MAX_ANIM_SPEED := 2800.0
const MIN_ANIM_DURATION := 0.05
const MAX_ANIM_DURATION := 0.5
const MIN_RELEASE_SPEED := 200.0
const MERGE_BLEND_DURATION := 0.32
const MERGE_IMPACT_NUDGE_RATIO := 0.12
const MERGE_IMPACT_NUDGE_IN := 0.07
const MERGE_IMPACT_NUDGE_SETTLE := 0.18

@onready var blocks_container: Node2D = $Blocks
@onready var playfield_background: ColorRect = $PlayfieldBackground
@onready var playfield_tiles: Node2D = $PlayfieldTiles

var swipe_hints: SwipeHintOverlay = null


func _ready() -> void:
	if level_config == null:
		level_config = load("res://resources/levels/demo_level.tres") as LevelConfig
	lives = starting_lives
	await get_tree().process_frame
	_rebuild_board()
	set_process(false)


func load_level(config: LevelConfig) -> void:
	level_config = config
	lives = starting_lives
	game_ended = false
	is_busy = false
	_rebuild_board()


func get_lives() -> int:
	return lives


func can_undo_move() -> bool:
	return not _undo_snapshot.is_empty() and not is_busy


func undo_last_move() -> bool:
	if not can_undo_move():
		return false

	var snapshot := _undo_snapshot.duplicate(true)
	_undo_snapshot.clear()
	_restore_snapshot(snapshot)
	_notify_undo_available()
	return true


func _rebuild_board() -> void:
	grid_columns = level_config.columns
	grid_rows = level_config.rows

	for child in blocks_container.get_children():
		if child is SwipeHintOverlay:
			continue
		child.free()
	for child in playfield_tiles.get_children():
		child.free()

	cell_occupant.clear()
	_disabled_cells.clear()
	for cell in level_config.disabled_cells:
		if cell is Vector2i:
			_disabled_cells[cell] = true
	placed_blocks.clear()
	_undo_snapshot.clear()
	_clear_merge_previews()
	_init_goal_states()
	_layout_grid()
	_rebuild_playfield_tiles()
	_spawn_blocks()
	_ensure_swipe_hints()
	_emit_all_goal_states()
	_notify_undo_available()


func _uses_multi_goals() -> bool:
	return level_config != null and level_config.multi_goal_mode


func _init_goal_states() -> void:
	_multi_goal_states.clear()
	if not _uses_multi_goals():
		return
	_multi_goal_states.append(MultiGoalEdgeState.new(level_config.goal_left_phases))
	_multi_goal_states.append(MultiGoalEdgeState.new(level_config.goal_top_phases))
	_multi_goal_states.append(MultiGoalEdgeState.new(level_config.goal_right_phases))
	_multi_goal_states.append(MultiGoalEdgeState.new(level_config.goal_bottom_phases))


func get_goal_display_state(goal_edge: int) -> Dictionary:
	if _uses_multi_goals() and goal_edge >= 0 and goal_edge < _multi_goal_states.size():
		return _multi_goal_states[goal_edge].get_display_state()
	return {
		"active": _is_goal_edge_enabled(goal_edge),
		"base_color": Block.get_color(_goal_color_for_edge(goal_edge)),
		"next_color": Color.TRANSPARENT,
		"progress": 0,
		"target": 1,
		"has_next_preview": false,
	}


func _emit_all_goal_states() -> void:
	for goal_edge in [GoalEdge.LEFT, GoalEdge.TOP, GoalEdge.RIGHT, GoalEdge.BOTTOM]:
		goal_state_changed.emit(goal_edge, get_goal_display_state(goal_edge))


func _notify_undo_available() -> void:
	undo_available_changed.emit(can_undo_move())


func _finish_busy() -> void:
	is_busy = false
	_notify_undo_available()


func _push_undo_snapshot() -> void:
	_undo_snapshot = _capture_snapshot()
	_notify_undo_available()


func _capture_snapshot() -> Dictionary:
	var blocks_data: Array = []
	for block in placed_blocks:
		blocks_data.append({
			"grid_pos": block.grid_pos,
			"shape_cells": block.shape_cells.duplicate(),
			"tile_color": block.tile_color,
			"block_kind": block.block_kind,
			"shape_id": block.shape_id,
		})

	var goals_data: Array = []
	if _uses_multi_goals():
		for state in _multi_goal_states:
			goals_data.append({
				"phase_index": state.phase_index,
				"scored_in_phase": state.scored_in_phase,
			})

	return {
		"lives": lives,
		"blocks": blocks_data,
		"multi_goal_states": goals_data,
	}


func _restore_snapshot(snapshot: Dictionary) -> void:
	_reset_pointer()
	_clear_merge_previews()

	for block in placed_blocks.duplicate():
		_remove_block(block)
		block.queue_free()

	lives = snapshot["lives"]
	game_ended = false

	for data in snapshot["blocks"]:
		_spawn_block_from_snapshot(data)

	if _uses_multi_goals() and snapshot.has("multi_goal_states"):
		var goals_data: Array = snapshot["multi_goal_states"]
		for i in _multi_goal_states.size():
			if i >= goals_data.size():
				break
			var goal_data: Dictionary = goals_data[i]
			_multi_goal_states[i].phase_index = goal_data["phase_index"]
			_multi_goal_states[i].scored_in_phase = goal_data["scored_in_phase"]

	_emit_all_goal_states()
	undo_applied.emit(lives)


func _spawn_block_from_snapshot(data: Dictionary) -> void:
	var block: Block = BlockScene.instantiate()
	block.configure(
		data["tile_color"],
		data["shape_id"],
		data["grid_pos"],
		data["block_kind"]
	)
	block.set_shape_cells(data["shape_cells"])
	block.position = _anchor_to_world(data["grid_pos"])
	blocks_container.add_child(block)
	block.setup(cell_size)
	_register_block_cells(block)
	placed_blocks.append(block)


func _goal_edge_active(goal_edge: int) -> bool:
	if not _is_goal_edge_enabled(goal_edge):
		return false
	if _uses_multi_goals():
		if goal_edge < 0 or goal_edge >= _multi_goal_states.size():
			return false
		return not _multi_goal_states[goal_edge].is_finished()
	return true


func _is_goal_edge_enabled(goal_edge: int) -> bool:
	if level_config == null:
		return false
	match goal_edge:
		GoalEdge.LEFT:
			return level_config.goal_left_enabled
		GoalEdge.TOP:
			return level_config.goal_top_enabled
		GoalEdge.RIGHT:
			return level_config.goal_right_enabled
		GoalEdge.BOTTOM:
			return level_config.goal_bottom_enabled
		_:
			return false


func _record_goal_score(goal_edge: int) -> void:
	if not _uses_multi_goals():
		return
	if goal_edge < 0 or goal_edge >= _multi_goal_states.size():
		return
	_multi_goal_states[goal_edge].record_score()
	goal_state_changed.emit(goal_edge, get_goal_display_state(goal_edge))


func _layout_grid() -> void:
	var viewport_size := get_viewport_rect().size
	var play_left := GoalBorder.BAR_WIDTH + GOAL_GRID_GAP + PLAYFIELD_MARGIN
	var play_top := GoalBorder.BAR_WIDTH + GOAL_GRID_GAP + PLAYFIELD_MARGIN
	var play_right := viewport_size.x - GoalBorder.BAR_WIDTH - GOAL_GRID_GAP - PLAYFIELD_MARGIN
	var play_bottom := viewport_size.y - GOAL_GRID_GAP - PLAYFIELD_MARGIN_BOTTOM
	if _is_goal_edge_enabled(GoalEdge.BOTTOM):
		play_bottom -= GoalBorder.BAR_WIDTH

	var available := Vector2(play_right - play_left, play_bottom - play_top)
	available.x = maxf(available.x, 1.0)
	available.y = maxf(available.y, 1.0)
	cell_size = maxi(
		8,
		mini(
			int(available.x / grid_columns),
			int(available.y / grid_rows)
		)
	)

	var grid_pixel_size := Vector2(grid_columns * cell_size, grid_rows * cell_size)
	grid_origin = Vector2(
		play_left + (available.x - grid_pixel_size.x) / 2.0,
		play_top + (available.y - grid_pixel_size.y) / 2.0
	)

	playfield_background.position = grid_origin
	playfield_background.size = grid_pixel_size
	playfield_background.color = UiTheme.PANEL
	playfield_background.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rebuild_playfield_tiles() -> void:
	for y in grid_rows:
		for x in grid_columns:
			var cell := Vector2i(x, y)
			var origin := grid_origin + Vector2(cell) * cell_size
			if _is_cell_disabled(cell):
				var hole := ColorRect.new()
				hole.color = UiTheme.HOLE_TINT
				hole.position = origin
				hole.size = Vector2(cell_size, cell_size)
				hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
				playfield_tiles.add_child(hole)
				continue
			var border := ColorRect.new()
			border.color = UiTheme.PLAYFIELD_TILE_BORDER
			border.position = origin
			border.size = Vector2(cell_size, cell_size)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			playfield_tiles.add_child(border)
			var fill := ColorRect.new()
			fill.color = UiTheme.PLAYFIELD_TILE
			fill.position = origin + Vector2.ONE
			fill.size = Vector2(cell_size - 2, cell_size - 2)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			playfield_tiles.add_child(fill)


func _spawn_blocks() -> void:
	var count := level_config.block_positions.size()
	for i in count:
		var grid_pos: Vector2i = level_config.block_positions[i]
		var color: Block.TileColor = level_config.block_colors[i]
		var shape_id := BlockShapes.SINGLE
		if i < level_config.block_shapes.size():
			shape_id = level_config.block_shapes[i]
		var kind := Block.BlockKind.STANDARD
		if i < level_config.block_kinds.size():
			kind = level_config.block_kinds[i]
		if _has_custom_pattern(i):
			var pattern: Array[Vector2i] = _pattern_cells_for_index(i)
			_add_block_with_cells(grid_pos, color, pattern, kind)
		else:
			_add_block(grid_pos, color, shape_id, kind)


func _has_custom_pattern(index: int) -> bool:
	return (
		index < level_config.block_cell_patterns.size()
		and level_config.block_cell_patterns[index] is Array
		and level_config.block_cell_patterns[index].size() > 0
	)


func _pattern_cells_for_index(index: int) -> Array[Vector2i]:
	var pattern: Array[Vector2i] = []
	var raw: Array = level_config.block_cell_patterns[index]
	for offset in raw:
		if offset is Vector2i:
			pattern.append(offset)
	return pattern


func _add_block_with_cells(
	grid_pos: Vector2i,
	color: Block.TileColor,
	shape_cells: Array[Vector2i],
	kind: Block.BlockKind = Block.BlockKind.STANDARD
) -> void:
	if not _can_place_shape(shape_cells, grid_pos):
		push_warning("Cannot place custom block at %s." % grid_pos)
		return

	var block: Block = BlockScene.instantiate()
	block.configure(color, BlockShapes.SINGLE, grid_pos, kind)
	block.set_shape_cells(shape_cells)
	block.position = _anchor_to_world(grid_pos)
	blocks_container.add_child(block)
	block.setup(cell_size)
	_register_block_cells(block)
	placed_blocks.append(block)


func _add_block(
	grid_pos: Vector2i,
	color: Block.TileColor,
	shape_id: String,
	kind: Block.BlockKind = Block.BlockKind.STANDARD
) -> void:
	var shape_cells := BlockShapes.get_cells(shape_id)
	if not _can_place_shape(shape_cells, grid_pos):
		push_warning("Cannot place %s block at %s." % [shape_id, grid_pos])
		return

	var block: Block = BlockScene.instantiate()
	block.configure(color, shape_id, grid_pos, kind)
	block.position = _anchor_to_world(grid_pos)
	blocks_container.add_child(block)
	block.setup(cell_size)
	_register_block_cells(block)
	placed_blocks.append(block)


func _register_block_cells(block: Block) -> void:
	for cell in block.get_occupied_cells():
		cell_occupant[cell] = block


func _unregister_block_cells(block: Block) -> void:
	for cell in block.get_occupied_cells():
		if cell_occupant.get(cell) == block:
			cell_occupant.erase(cell)


func _can_place_shape(shape_cells: Array[Vector2i], anchor: Vector2i, ignore_block: Block = null) -> bool:
	for offset in shape_cells:
		var cell := anchor + offset
		if not _is_in_bounds(cell):
			return false
		if _is_cell_disabled(cell):
			return false
		if cell_occupant.has(cell) and cell_occupant[cell] != ignore_block:
			return false
	return true


func _placement_result(block: Block, anchor: Vector2i) -> PlacementResult:
	var saw_oob := false
	for offset in block.shape_cells:
		var cell := anchor + offset
		if _is_cell_disabled(cell):
			return PlacementResult.BLOCKED_BY_BLOCK
		if not _is_in_bounds(cell):
			saw_oob = true
		elif cell_occupant.has(cell) and cell_occupant[cell] != block:
			return PlacementResult.BLOCKED_BY_BLOCK

	if saw_oob:
		return PlacementResult.OUT_OF_BOUNDS
	return PlacementResult.OK


func _is_cell_disabled(cell: Vector2i) -> bool:
	return _disabled_cells.has(cell)


func _anchor_to_world(anchor: Vector2i) -> Vector2:
	return grid_origin + Vector2(anchor) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)


func _shape_offset_extents(block: Block) -> Dictionary:
	var min_offset := Vector2i(block.shape_cells[0])
	var max_offset := Vector2i(block.shape_cells[0])
	for offset in block.shape_cells:
		min_offset.x = mini(min_offset.x, offset.x)
		min_offset.y = mini(min_offset.y, offset.y)
		max_offset.x = maxi(max_offset.x, offset.x)
		max_offset.y = maxi(max_offset.y, offset.y)
	return {"min": min_offset, "max": max_offset}


func _goal_contact_world(block: Block, edge_anchor: Vector2i, goal_edge: int) -> Vector2:
	return _screen_edge_contact_world(block, edge_anchor, _direction_for_goal_edge(goal_edge))


func _direction_for_goal_edge(goal_edge: int) -> Vector2i:
	match goal_edge:
		GoalEdge.LEFT:
			return Vector2i.LEFT
		GoalEdge.TOP:
			return Vector2i.UP
		GoalEdge.RIGHT:
			return Vector2i.RIGHT
		GoalEdge.BOTTOM:
			return Vector2i.DOWN
	return Vector2i.ZERO


func _screen_edge_contact_world(block: Block, edge_anchor: Vector2i, direction: Vector2i) -> Vector2:
	var edge_world := _anchor_to_world(edge_anchor)
	var half: float = cell_size / 2.0
	var extents := _shape_offset_extents(block)
	var min_offset: Vector2i = extents["min"]
	var max_offset: Vector2i = extents["max"]
	var viewport_size := get_viewport_rect().size

	if direction == Vector2i.LEFT:
		var shape_left: float = edge_world.x + min_offset.x * cell_size - half
		return edge_world + Vector2(-shape_left, 0.0)
	if direction == Vector2i.RIGHT:
		var shape_right: float = edge_world.x + max_offset.x * cell_size + half
		return edge_world + Vector2(viewport_size.x - shape_right, 0.0)
	if direction == Vector2i.UP:
		var shape_top: float = edge_world.y + min_offset.y * cell_size - half
		return edge_world + Vector2(0.0, -shape_top)
	if direction == Vector2i.DOWN:
		var shape_bottom: float = edge_world.y + max_offset.y * cell_size + half
		return edge_world + Vector2(0.0, viewport_size.y - shape_bottom)

	return edge_world


func _world_to_grid(world_pos: Vector2) -> Vector2i:
	var local := to_local(world_pos) - grid_origin
	return Vector2i(floori(local.x / cell_size), floori(local.y / cell_size))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var canvas_transform := get_viewport().get_canvas_transform()
	return canvas_transform.affine_inverse() * screen_pos


func _is_in_bounds(grid_pos: Vector2i) -> bool:
	return (
		grid_pos.x >= 0
		and grid_pos.x < grid_columns
		and grid_pos.y >= 0
		and grid_pos.y < grid_rows
	)


func _goal_color_for_edge(goal_edge: int) -> Block.TileColor:
	if _uses_multi_goals() and goal_edge >= 0 and goal_edge < _multi_goal_states.size():
		var color: int = _multi_goal_states[goal_edge].current_color()
		if color != -1:
			return color as Block.TileColor
	match goal_edge:
		GoalEdge.LEFT:
			return level_config.goal_left_color
		GoalEdge.TOP:
			return level_config.goal_top_color
		GoalEdge.RIGHT:
			return level_config.goal_right_color
		GoalEdge.BOTTOM:
			return level_config.goal_bottom_color
	return Block.TileColor.RED


func _blocking_block_at(block: Block, anchor: Vector2i) -> Block:
	for offset in block.shape_cells:
		var cell := anchor + offset
		if cell_occupant.has(cell):
			var occupant: Block = cell_occupant[cell]
			if occupant != block:
				return occupant
	return null


func _clear_merge_previews() -> void:
	_clear_swipe_hints()
	for block in placed_blocks:
		block.clear_merge_preview()
		block.set_drag_focus(false)


func _clear_swipe_hints() -> void:
	if swipe_hints != null and is_instance_valid(swipe_hints):
		swipe_hints.clear_hints()


func _ensure_swipe_hints() -> void:
	# Must stay inside Blocks at z_index 0 as the first child so hints draw:
	# - after PlayfieldTiles (opaque ColorRects)
	# - before tile Blocks (same z_index, earlier in tree = underneath)
	# Do NOT use negative z_index: that pulls drawing behind PlayfieldTiles.
	if swipe_hints != null and is_instance_valid(swipe_hints):
		if swipe_hints.get_parent() != blocks_container:
			if swipe_hints.get_parent() != null:
				swipe_hints.get_parent().remove_child(swipe_hints)
			blocks_container.add_child(swipe_hints)
		blocks_container.move_child(swipe_hints, 0)
		swipe_hints.z_index = 0
		swipe_hints.z_as_relative = true
		return

	var existing := get_node_or_null("SwipeHints")
	if existing is SwipeHintOverlay:
		swipe_hints = existing
	else:
		swipe_hints = SwipeHintOverlay.new()
		swipe_hints.name = "SwipeHints"

	if swipe_hints.get_parent() != null:
		swipe_hints.get_parent().remove_child(swipe_hints)
	blocks_container.add_child(swipe_hints)
	blocks_container.move_child(swipe_hints, 0)
	swipe_hints.z_index = 0
	swipe_hints.z_as_relative = true


func _show_swipe_hints(block: Block) -> void:
	_ensure_swipe_hints()
	if swipe_hints == null or block == null:
		return
	swipe_hints.show_hints(_build_swipe_hint_corridors(block), float(cell_size))


func _build_swipe_hint_corridors(block: Block) -> Array[Dictionary]:
	var corridors: Array[Dictionary] = []
	var directions := [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]
	for direction in directions:
		var corridor := _swipe_hint_corridor_for_direction(block, direction)
		if not corridor.is_empty():
			corridors.append(corridor)
	return corridors


func _swipe_hint_corridor_for_direction(block: Block, direction: Vector2i) -> Dictionary:
	var slide := _compute_slide(block, block.grid_pos, direction)
	var steps := absi(slide.target.x - block.grid_pos.x) + absi(slide.target.y - block.grid_pos.y)
	if steps <= 0:
		return {}

	var extents := _shape_offset_extents(block)
	var min_offset: Vector2i = extents["min"]
	var max_offset: Vector2i = extents["max"]
	var half := cell_size / 2.0
	var dir := Vector2(direction)
	var origin := Vector2.ZERO
	var length := float(steps) * float(cell_size)
	var cross_cells := 1

	# Corridor starts at the leading face of the pressed block and runs through
	# empty cells until the last reachable cell (stopping before any blocker/goal/edge).
	if direction == Vector2i.RIGHT:
		cross_cells = max_offset.y - min_offset.y + 1
		origin = _anchor_to_world(block.grid_pos) + Vector2(
			max_offset.x * cell_size + half,
			(min_offset.y + max_offset.y) * cell_size * 0.5
		)
	elif direction == Vector2i.LEFT:
		cross_cells = max_offset.y - min_offset.y + 1
		origin = _anchor_to_world(block.grid_pos) + Vector2(
			min_offset.x * cell_size - half,
			(min_offset.y + max_offset.y) * cell_size * 0.5
		)
	elif direction == Vector2i.DOWN:
		cross_cells = max_offset.x - min_offset.x + 1
		origin = _anchor_to_world(block.grid_pos) + Vector2(
			(min_offset.x + max_offset.x) * cell_size * 0.5,
			max_offset.y * cell_size + half
		)
	elif direction == Vector2i.UP:
		cross_cells = max_offset.x - min_offset.x + 1
		origin = _anchor_to_world(block.grid_pos) + Vector2(
			(min_offset.x + max_offset.x) * cell_size * 0.5,
			min_offset.y * cell_size - half
		)
	else:
		return {}

	return {
		"direction": dir,
		"origin": origin,
		"length": length,
		"cross_cells": cross_cells,
	}


func _show_merge_previews(source: Block) -> void:
	if source == null or source.block_kind != Block.BlockKind.MERGE:
		return

	for block in placed_blocks:
		if block != source:
			block.clear_merge_preview()

	source.set_drag_selected(true)

	var merge_targets: Dictionary = {}
	for target in _get_reachable_merge_targets(source):
		var merged_color := Block.get_merged_color(source.tile_color, target.tile_color)
		if merged_color != -1:
			target.set_merge_target_preview(merged_color)
			merge_targets[target] = true

	for block in placed_blocks:
		if block == source:
			continue
		if block.block_kind != Block.BlockKind.MERGE:
			continue
		if merge_targets.has(block):
			continue
		block.set_merge_non_target_muted()


func _get_reachable_merge_targets(source: Block) -> Array[Block]:
	var targets: Array[Block] = []
	var seen := {}
	var directions := [
		Vector2i.LEFT,
		Vector2i.RIGHT,
		Vector2i.UP,
		Vector2i.DOWN,
	]

	for direction in directions:
		var slide := _compute_slide(source, source.grid_pos, direction)
		if slide.next_result != PlacementResult.BLOCKED_BY_BLOCK:
			continue

		var blocker := _blocking_block_at(source, slide.next_anchor)
		if blocker == null or blocker.block_kind != Block.BlockKind.MERGE:
			continue
		if not Block.can_merge_blocks(source, blocker):
			continue
		if seen.has(blocker):
			continue

		seen[blocker] = true
		targets.append(blocker)

	return targets


func _union_cells(a: Array[Vector2i], b: Array[Vector2i]) -> Array[Vector2i]:
	var seen := {}
	var result: Array[Vector2i] = []
	for cell in a + b:
		if not seen.has(cell):
			seen[cell] = true
			result.append(cell)
	return result


func _cells_anchor(cells: Array[Vector2i]) -> Vector2i:
	var anchor := cells[0]
	for cell in cells:
		anchor.x = mini(anchor.x, cell.x)
		anchor.y = mini(anchor.y, cell.y)
	return anchor


func _cells_to_offsets(cells: Array[Vector2i], anchor: Vector2i) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for cell in cells:
		offsets.append(cell - anchor)
	return offsets


func _goal_for_direction(direction: Vector2i) -> int:
	if direction == Vector2i.LEFT:
		return GoalEdge.LEFT
	if direction == Vector2i.UP:
		return GoalEdge.TOP
	if direction == Vector2i.RIGHT:
		return GoalEdge.RIGHT
	if direction == Vector2i.DOWN:
		return GoalEdge.BOTTOM
	return -1


func _would_exit_goal_edge(block: Block, anchor: Vector2i, goal_edge: int) -> bool:
	for offset in block.shape_cells:
		var cell := anchor + offset
		match goal_edge:
			GoalEdge.LEFT:
				if cell.x < 0:
					return true
			GoalEdge.TOP:
				if cell.y < 0:
					return true
			GoalEdge.RIGHT:
				if cell.x >= grid_columns:
					return true
			GoalEdge.BOTTOM:
				if cell.y >= grid_rows:
					return true
	return false


func _process(_delta: float) -> void:
	if not is_dragging or selected_block == null:
		return

	var pointer_pos := last_pointer_pos
	if active_pointer_id == 0:
		pointer_pos = _screen_to_world(get_viewport().get_mouse_position())

	_update_drag_follow(pointer_pos)


func handle_input_event(event: InputEvent) -> void:
	if is_busy or game_ended:
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		var pointer_pos := _screen_to_world(event.position)
		if event.pressed:
			_begin_pointer(0, pointer_pos)
		elif active_pointer_id == 0:
			_end_pointer(pointer_pos)
		return

	if event is InputEventScreenTouch:
		var pointer_pos := _screen_to_world(event.position)
		if event.pressed:
			_begin_pointer(event.index, pointer_pos)
		elif active_pointer_id == event.index:
			_end_pointer(pointer_pos)
		return

	if not is_dragging or selected_block == null:
		return

	if event is InputEventMouseMotion and active_pointer_id == 0:
		last_pointer_pos = _screen_to_world(event.position)
	elif event is InputEventScreenDrag and event.index == active_pointer_id:
		last_pointer_pos = _screen_to_world(event.position)


func _begin_pointer(pointer_id: int, pointer_pos: Vector2) -> void:
	if is_dragging or is_busy:
		return

	var grid := _world_to_grid(pointer_pos)
	if not cell_occupant.has(grid):
		_clear_merge_previews()
		return

	active_pointer_id = pointer_id
	selected_block = cell_occupant[grid]
	if Block.is_wall_kind(selected_block.block_kind):
		_clear_merge_previews()
		return
	_show_merge_previews(selected_block)
	selected_block.set_drag_focus(true)
	_show_swipe_hints(selected_block)
	is_dragging = true
	drag_start = pointer_pos
	last_pointer_pos = pointer_pos
	drag_anchor_start = selected_block.grid_pos
	drag_anchor_world = _anchor_to_world(drag_anchor_start)
	drag_locked_axis = Vector2i.ZERO
	selected_block.position = drag_anchor_world
	drag_samples.clear()
	_track_pointer_sample(pointer_pos)
	_unregister_block_cells(selected_block)
	selected_block.z_index = 10
	set_process(true)
	get_viewport().set_input_as_handled()


func _update_drag_follow(pointer_pos: Vector2) -> void:
	last_pointer_pos = pointer_pos
	_track_pointer_sample(pointer_pos)

	var drag_delta := pointer_pos - drag_start
	if drag_locked_axis == Vector2i.ZERO and drag_delta.length() >= DRAG_THRESHOLD:
		drag_locked_axis = _snap_direction(drag_delta)

	if drag_locked_axis == Vector2i.ZERO:
		selected_block.position = drag_anchor_world
		return

	var axis := Vector2(drag_locked_axis)
	var max_pull := cell_size * MAX_DRAG_PULL_RATIO
	var raw_pull: float = drag_delta.dot(axis)
	var pull := _elastic_pull(raw_pull, max_pull)
	selected_block.position = drag_anchor_world + axis * pull


func _elastic_pull(raw_pull: float, max_pull: float) -> float:
	if max_pull <= 0.0:
		return 0.0

	var direction_sign: float = signf(raw_pull)
	if direction_sign == 0.0:
		return 0.0

	# Mouse travel is unbounded; output saturates toward max_pull like a spring.
	# Easy to pull at first, increasingly stiff as the block nears full extension.
	var stretch_ratio: float = abs(raw_pull) / max_pull
	var eased: float = 1.0 - exp(-ELASTIC_SPRING_STRENGTH * stretch_ratio)
	return direction_sign * eased * max_pull


func _end_pointer(pointer_pos: Vector2) -> void:
	if not is_dragging or selected_block == null:
		return

	set_process(false)
	_update_drag_follow(pointer_pos)

	var total_drag := pointer_pos - drag_start
	var release_velocity := _get_release_velocity()
	var release_speed := release_velocity.length()

	if drag_locked_axis == Vector2i.ZERO or total_drag.length() < DRAG_THRESHOLD:
		_snap_block_back(selected_block, drag_anchor_start, maxf(release_speed, MIN_ANIM_SPEED))
		_reset_pointer()
		return

	if release_speed < MIN_RELEASE_SPEED:
		_snap_block_back(selected_block, drag_anchor_start, MIN_ANIM_SPEED)
		_reset_pointer()
		return

	var axis_vec := Vector2(drag_locked_axis)
	if release_velocity.dot(axis_vec) < MIN_RELEASE_SPEED * 0.5:
		_snap_block_back(selected_block, drag_anchor_start, release_speed)
		_reset_pointer()
		return

	var move_dir := drag_locked_axis

	_commit_move(selected_block, drag_anchor_start, move_dir, release_speed)
	_reset_pointer()
	get_viewport().set_input_as_handled()


func _track_pointer_sample(pointer_pos: Vector2) -> void:
	drag_samples.append({"pos": pointer_pos, "time": Time.get_ticks_msec()})
	while drag_samples.size() > 10:
		drag_samples.pop_front()


func _get_release_velocity() -> Vector2:
	if drag_samples.size() < 2:
		return Vector2.ZERO

	var newest: Dictionary = drag_samples[-1]
	var previous: Dictionary = drag_samples[-2]
	var elapsed_ms: int = newest.time - previous.time
	if elapsed_ms <= 0:
		return Vector2.ZERO

	var elapsed_sec := elapsed_ms / 1000.0
	return (newest.pos - previous.pos) / elapsed_sec


func _get_release_speed() -> float:
	return _get_release_velocity().length()


func _move_duration(speed: float, distance: float) -> float:
	var clamped_speed := clampf(speed, MIN_ANIM_SPEED, MAX_ANIM_SPEED)
	var duration := distance / clamped_speed
	return clampf(duration, MIN_ANIM_DURATION, MAX_ANIM_DURATION)


func _snap_block_back(block: Block, anchor: Vector2i, speed: float) -> void:
	var target_world := _anchor_to_world(anchor)
	var distance := block.position.distance_to(target_world)
	if distance < 1.0:
		block.position = target_world
		block.grid_pos = anchor
		_register_block_cells(block)
		block.z_index = 0
		return

	is_busy = true
	var tween := create_tween()
	tween.tween_property(
		block,
		"position",
		target_world,
		_move_duration(speed, distance)
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		block.grid_pos = anchor
		_register_block_cells(block)
		block.z_index = 0
		is_busy = false
	)


func _commit_move(block: Block, start_pos: Vector2i, direction: Vector2i, speed: float) -> void:
	_clear_merge_previews()
	var slide := _compute_slide(block, start_pos, direction)
	var target: Vector2i = slide.target
	var next_result: PlacementResult = slide.next_result
	var goal_edge: int = slide.goal_edge
	var next_anchor: Vector2i = slide.next_anchor
	var from_visual := block.position

	if (
		goal_edge != -1
		and next_result == PlacementResult.OUT_OF_BOUNDS
		and _would_exit_goal_edge(block, next_anchor, goal_edge)
		and _goal_edge_active(goal_edge)
	):
		var goal_color: Block.TileColor = _goal_color_for_edge(goal_edge)
		if block.tile_color == goal_color:
			_score_block_animated(block, target, direction, speed, from_visual)
		else:
			_wrong_goal_bounce_animated(
				block, start_pos, target, direction, speed, from_visual
			)
		return

	if next_result == PlacementResult.OUT_OF_BOUNDS and target != start_pos:
		_screen_edge_bounce_animated(block, start_pos, target, direction, speed, from_visual)
		return

	if target == start_pos:
		if next_result == PlacementResult.BLOCKED_BY_BLOCK:
			if _try_merge_collision(block, start_pos, next_anchor, direction, speed, from_visual):
				return
			_push_undo_snapshot()
			Sfx.play_bump()
			_snap_block_back(block, start_pos, speed)
			_lose_life()
		else:
			_snap_block_back(block, start_pos, speed)
		return

	if next_result == PlacementResult.BLOCKED_BY_BLOCK:
		if _try_merge_collision(block, target, next_anchor, direction, speed, from_visual):
			return
		_bounce_block_animated(block, start_pos, target, speed, from_visual)
		return

	_move_block_animated(block, start_pos, target, speed, from_visual)


func _try_merge_collision(
	moving: Block,
	moving_anchor: Vector2i,
	next_anchor: Vector2i,
	direction: Vector2i,
	speed: float,
	from_visual: Vector2
) -> bool:
	var blocker := _blocking_block_at(moving, next_anchor)
	if blocker == null or not Block.can_merge_blocks(moving, blocker):
		return false
	_merge_blocks_animated(moving, blocker, moving_anchor, direction, speed, from_visual)
	return true


func _merge_impact_offset(direction: Vector2i) -> Vector2:
	if direction == Vector2i.ZERO:
		return Vector2.ZERO
	return Vector2(direction.x, direction.y) * float(cell_size) * MERGE_IMPACT_NUDGE_RATIO


func _merge_blocks_animated(
	moving: Block,
	stationary: Block,
	moving_anchor: Vector2i,
	impact_direction: Vector2i,
	speed: float,
	from_visual: Vector2
) -> void:
	_push_undo_snapshot()
	Sfx.play_swoosh()
	is_busy = true
	moving.position = from_visual

	var merged_cells := _union_cells(
		moving.get_occupied_cells(moving_anchor),
		stationary.get_occupied_cells()
	)
	var new_anchor := _cells_anchor(merged_cells)
	var new_offsets := _cells_to_offsets(merged_cells, new_anchor)
	var new_color: Block.TileColor = Block.get_merged_color(
		moving.tile_color,
		stationary.tile_color
	) as Block.TileColor
	var merged_fill := Block.get_color(new_color)
	var contact_world := _anchor_to_world(moving_anchor)
	var merge_world := _anchor_to_world(new_anchor)
	var slide_distance := from_visual.distance_to(contact_world)
	var slide_duration := _move_duration(speed, slide_distance)

	var tween := create_tween()
	tween.tween_property(
		moving,
		"position",
		contact_world,
		slide_duration
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		moving.grid_pos = moving_anchor
		moving.position = contact_world
		_unregister_block_cells(stationary)
		_unregister_block_cells(moving)
		stationary.clear_merge_preview()

		var stationary_cells := _cells_to_offsets(stationary.get_occupied_cells(), new_anchor)
		var moving_cells := _cells_to_offsets(
			moving.get_occupied_cells(moving_anchor),
			new_anchor
		)
		var stationary_fill := Block.get_color(stationary.tile_color)
		var moving_fill := Block.get_color(moving.tile_color)

		stationary.grid_pos = new_anchor
		stationary.position = merge_world
		stationary.set_shape_cells(new_offsets)
		moving.visible = false

		stationary.start_merge_blend_animation(
			stationary_fill,
			moving_fill,
			merged_fill,
			stationary_cells,
			moving_cells
		)

		var impact_offset := _merge_impact_offset(impact_direction)
		var blend_tween := create_tween()
		blend_tween.tween_method(
			stationary.set_merge_blend_progress,
			0.0,
			1.0,
			MERGE_BLEND_DURATION
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		if impact_offset != Vector2.ZERO:
			stationary.set_merge_impact_offset(Vector2.ZERO)
			var nudge_tween := create_tween()
			nudge_tween.tween_method(
				stationary.set_merge_impact_offset,
				Vector2.ZERO,
				impact_offset,
				MERGE_IMPACT_NUDGE_IN
			).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			nudge_tween.tween_method(
				stationary.set_merge_impact_offset,
				impact_offset,
				Vector2.ZERO,
				MERGE_IMPACT_NUDGE_SETTLE
			).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		blend_tween.chain().tween_callback(func():
			_remove_block(moving)
			moving.queue_free()
			stationary.finish_merge_blend_animation()
			stationary.tile_color = new_color
			_register_block_cells(stationary)
			_finish_busy()
		)
	)


func _compute_slide(block: Block, start_pos: Vector2i, direction: Vector2i) -> Dictionary:
	var target := start_pos
	var next_anchor := target + direction

	while _placement_result(block, next_anchor) == PlacementResult.OK:
		target = next_anchor
		next_anchor = target + direction

	return {
		"target": target,
		"next_anchor": next_anchor,
		"next_result": _placement_result(block, next_anchor),
		"goal_edge": _goal_for_direction(direction),
	}


func _move_block_animated(
	block: Block,
	from_pos: Vector2i,
	to_pos: Vector2i,
	speed: float,
	from_visual: Vector2
) -> void:
	_push_undo_snapshot()
	Sfx.play_swoosh()
	is_busy = true
	block.position = from_visual
	var target_world := _anchor_to_world(to_pos)
	var distance := from_visual.distance_to(target_world)

	var tween := create_tween()
	tween.tween_property(
		block,
		"position",
		target_world,
		_move_duration(speed, distance)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		block.grid_pos = to_pos
		_register_block_cells(block)
		block.z_index = 0
		_finish_busy()
	)


func cancel_active_pointer() -> void:
	if not is_dragging or selected_block == null:
		return
	var block := selected_block
	var anchor := drag_anchor_start
	_reset_pointer()
	if block != null and is_instance_valid(block):
		block.position = _anchor_to_world(anchor)
		block.grid_pos = anchor
		_register_block_cells(block)
		block.z_index = 0


func relayout_for_viewport() -> void:
	if level_config == null:
		return
	_layout_grid()
	for child in playfield_tiles.get_children():
		child.free()
	_rebuild_playfield_tiles()
	for block in placed_blocks:
		if not is_instance_valid(block):
			continue
		block.setup(cell_size)
		block.position = _anchor_to_world(block.grid_pos)
		block.queue_redraw()


func is_swipable_at_screen(screen_pos: Vector2) -> bool:
	if is_busy or game_ended:
		return false
	# While a swipe is already active, keep treating input as tile-owned
	# (cells are unregistered mid-drag, so occupancy alone would look empty).
	if is_dragging:
		return true
	var grid := _world_to_grid(_screen_to_world(screen_pos))
	if not cell_occupant.has(grid):
		return false
	return not Block.is_wall_kind(cell_occupant[grid].block_kind)


func _reset_pointer() -> void:
	_clear_merge_previews()
	is_dragging = false
	selected_block = null
	active_pointer_id = -1
	drag_locked_axis = Vector2i.ZERO
	drag_samples.clear()
	set_process(false)


func _snap_direction(drag_vector: Vector2) -> Vector2i:
	if drag_vector.length() < 0.001:
		return Vector2i.ZERO
	if abs(drag_vector.x) > abs(drag_vector.y):
		return Vector2i(int(sign(drag_vector.x)), 0)
	return Vector2i(0, int(sign(drag_vector.y)))


func _score_block_animated(
	block: Block,
	edge_pos: Vector2i,
	direction: Vector2i,
	speed: float,
	from_visual: Vector2
) -> void:
	_push_undo_snapshot()
	Sfx.play_swoosh()
	is_busy = true
	_remove_block(block)
	block.position = from_visual
	block.grid_pos = edge_pos

	var goal_edge := _goal_for_direction(direction)
	_record_goal_score(goal_edge)
	var goal_world := _goal_contact_world(block, edge_pos, goal_edge)
	var exit_world := goal_world + Vector2(direction) * cell_size * 2.0
	var total_distance := from_visual.distance_to(exit_world)

	var tween := create_tween()
	tween.tween_property(
		block,
		"position",
		exit_world,
		_move_duration(speed, total_distance)
	).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(func():
		block.queue_free()
		block.z_index = 0
		_finish_busy()
		_check_win()
	)


func _wrong_goal_bounce_animated(
	block: Block,
	start_pos: Vector2i,
	edge_pos: Vector2i,
	direction: Vector2i,
	speed: float,
	from_visual: Vector2
) -> void:
	_push_undo_snapshot()
	Sfx.play_bump()
	_screen_edge_bounce_animated(block, start_pos, edge_pos, direction, speed, from_visual, true)


func _screen_edge_bounce_animated(
	block: Block,
	start_pos: Vector2i,
	edge_pos: Vector2i,
	direction: Vector2i,
	speed: float,
	from_visual: Vector2,
	lose_life_on_finish: bool = false
) -> void:
	is_busy = true
	block.position = from_visual
	block.grid_pos = edge_pos

	var edge_world := _screen_edge_contact_world(block, edge_pos, direction)
	var start_world := _anchor_to_world(start_pos)
	var to_edge_distance := from_visual.distance_to(edge_world)
	var back_distance := edge_world.distance_to(start_world)

	var tween := create_tween()
	tween.tween_property(
		block,
		"position",
		edge_world,
		_move_duration(speed, to_edge_distance)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		block,
		"position",
		start_world,
		_move_duration(speed, back_distance)
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		block.grid_pos = start_pos
		_register_block_cells(block)
		block.z_index = 0
		_finish_busy()
		if lose_life_on_finish:
			_lose_life()
	)


func _bounce_block_animated(
	block: Block,
	start_pos: Vector2i,
	edge_pos: Vector2i,
	speed: float,
	from_visual: Vector2
) -> void:
	_push_undo_snapshot()
	Sfx.play_bump()
	is_busy = true
	block.position = from_visual
	block.grid_pos = edge_pos

	var edge_world := _anchor_to_world(edge_pos)
	var start_world := _anchor_to_world(start_pos)
	var to_edge_distance := from_visual.distance_to(edge_world)
	var back_distance := edge_world.distance_to(start_world)

	var tween := create_tween()
	tween.tween_property(
		block,
		"position",
		edge_world,
		_move_duration(speed, to_edge_distance)
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		block,
		"position",
		start_world,
		_move_duration(speed, back_distance)
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		block.grid_pos = start_pos
		_register_block_cells(block)
		block.z_index = 0
		_finish_busy()
		_lose_life()
	)


func _remove_block(block: Block) -> void:
	_unregister_block_cells(block)
	placed_blocks.erase(block)


func _lose_life() -> void:
	lives -= 1
	life_lost.emit(lives)
	if lives <= 0:
		game_ended = true
		game_over.emit()


func _check_win() -> void:
	if placed_blocks.is_empty():
		game_ended = true
		level_cleared.emit(lives)
