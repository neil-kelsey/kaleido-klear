extends SceneTree

## Exit collision: a shape may leave only when every cell can translate off the
## board without landing on another piece. Run:
##   godot --headless --path . -s res://scritps/tools/collision_checks.gd
##
## The same pass-through made these other Comet Shallows frames unsolvable
## until their pockets are opened: Horseshoe Fold, Serpent Bend, Onion Fold,
## Right Parade, Matryoshka, Deep Peel, Mirror Parade.

const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _process(_delta: float) -> bool:
	_check_clear_exit()
	_check_bump_does_not_pass()
	_check_merge()
	_check_concave_pocket()
	_check_other_axes()
	_check_wall_blocks_exit()
	_check_unused_cells_do_not_block()
	_check_exit_certification()
	_check_paradiddle()
	_check_board_agrees()
	_check_needle_spire()
	_check_unused_cells_do_not_score()
	print("collision_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true


func _check_clear_exit() -> void:
	var level := _board(5, 3)
	_goal_left(level, Block.TileColor.RED)
	_add(level, Vector2i(2, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	var result: Dictionary = sim.apply_move(state, 0, Vector2i.LEFT)
	_check(int(result.outcome) == PuzzleSimScript.Outcome.SCORE, "clear piece still exits")
	_check(result.state.is_won(), "clear exit clears the board")


func _check_bump_does_not_pass() -> void:
	var level := _board(4, 3)
	_goal_left(level, Block.TileColor.RED)
	_add(level, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	_add(level, Vector2i(1, 1), Block.TileColor.BLUE, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	var result: Dictionary = sim.apply_move(state, 0, Vector2i.RIGHT)
	_check(int(result.outcome) == PuzzleSimScript.Outcome.FAIL, "standard piece bumps instead of passing")
	_check(result.state.blocks[0].pos == Vector2i(0, 1), "bumped piece stays put")


func _check_merge() -> void:
	var level := _board(4, 3)
	_goal_left(level, Block.TileColor.RED)
	_add(level, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.MERGE, [Vector2i.ZERO])
	_add(level, Vector2i(1, 1), Block.TileColor.YELLOW, Block.BlockKind.MERGE, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	var result: Dictionary = sim.apply_move(state, 0, Vector2i.RIGHT)
	_check(int(result.outcome) == PuzzleSimScript.Outcome.MERGE, "adjacent primaries still merge")
	_check(result.state.clearable_count() == 1, "merge leaves one piece")
	if result.state.blocks.size() == 1:
		_check(
			int(result.state.blocks[0].color) == Block.TileColor.ORANGE,
			"red plus yellow merges to orange"
		)
	else:
		_check(false, "red plus yellow merges to orange")


func _check_concave_pocket() -> void:
	## Gap between the right arm and the interior piece, so the first step off
	## the left edge used to be treated as a clean exit.
	var frame := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(4, 2),
	]
	var level := _board(6, 4)
	_goal_left(level, Block.TileColor.RED)
	_add(level, Vector2i(0, 0), Block.TileColor.RED, Block.BlockKind.STANDARD, frame)
	_add(level, Vector2i(2, 1), Block.TileColor.BLUE, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var blocked: Dictionary = sim.apply_move(sim.load_config(level), 0, Vector2i.LEFT)
	_check(int(blocked.outcome) == PuzzleSimScript.Outcome.FAIL, "frame does not exit through its pocket")
	_check(blocked.state.blocks.size() == 2, "pocket piece is still on the board")

	var open := _board(6, 4)
	_goal_left(open, Block.TileColor.RED)
	_add(open, Vector2i(0, 0), Block.TileColor.RED, Block.BlockKind.STANDARD, frame)
	var cleared: Dictionary = sim.apply_move(sim.load_config(open), 0, Vector2i.LEFT)
	_check(int(cleared.outcome) == PuzzleSimScript.Outcome.SCORE, "empty frame can still leave")


func _check_other_axes() -> void:
	# Right: far arm is on the left, pocket sits in the gap, exit is right.
	_assert_pocket_blocks(Vector2i.RIGHT, Vector2i(1, 0), [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(4, 2),
	], Vector2i(2, 1), "right")
	# Down: far bar is the top, pocket is one row below it, bottom is the exit edge.
	_assert_pocket_blocks(Vector2i.DOWN, Vector2i(0, 0), [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(4, 2),
	], Vector2i(2, 2), "down")
	# Up: far bar is the bottom, pocket is one row above it, top is the exit edge.
	_assert_pocket_blocks(Vector2i.UP, Vector2i(0, 0), [
		Vector2i(0, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	], Vector2i(2, 0), "up")


func _assert_pocket_blocks(
	direction: Vector2i,
	anchor: Vector2i,
	frame: Array,
	pocket: Vector2i,
	label: String
) -> void:
	var level := _board(6, 3)
	_goal_on(level, direction, Block.TileColor.RED)
	_add(level, anchor, Block.TileColor.RED, Block.BlockKind.STANDARD, frame)
	_add(level, pocket, Block.TileColor.BLUE, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var blocked: Dictionary = sim.apply_move(sim.load_config(level), 0, direction)
	_check(int(blocked.outcome) != PuzzleSimScript.Outcome.SCORE, "%s frame does not exit through its pocket" % label)
	var open := _board(6, 3)
	_goal_on(open, direction, Block.TileColor.RED)
	_add(open, anchor, Block.TileColor.RED, Block.BlockKind.STANDARD, frame)
	var cleared: Dictionary = sim.apply_move(sim.load_config(open), 0, direction)
	_check(int(cleared.outcome) == PuzzleSimScript.Outcome.SCORE, "empty %s frame can still leave" % label)


func _check_wall_blocks_exit() -> void:
	## A WALL piece is the only static blocker.
	var level := _board(6, 3)
	_goal_on(level, Vector2i.LEFT, Block.TileColor.RED)
	# Cells (0,1) and (3,1). First step left puts (0,1) off the board; the next step hits the wall.
	_add(level, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i(0, 0), Vector2i(3, 0)])
	_add(level, Vector2i(1, 1), Block.TileColor.RED, Block.BlockKind.WALL, [Vector2i.ZERO])
	var sim = PuzzleSimScript.new()
	var result: Dictionary = sim.apply_move(sim.load_config(level), 0, Vector2i.LEFT)
	_check(int(result.outcome) == PuzzleSimScript.Outcome.FAIL, "a wall piece on the rest of the exit path blocks the leave")
	var open := _board(6, 3)
	_goal_on(open, Vector2i.LEFT, Block.TileColor.RED)
	_add(open, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i(0, 0), Vector2i(3, 0)])
	var cleared: Dictionary = sim.apply_move(sim.load_config(open), 0, Vector2i.LEFT)
	_check(int(cleared.outcome) == PuzzleSimScript.Outcome.SCORE, "the same split piece leaves when the wall is gone")


func _check_unused_cells_do_not_block() -> void:
	## Unused board cells (disabled_cells) are scenery only. Same moves as the
	## wall test, but with an unused cell where the wall was: nothing blocks.
	var level := _board(6, 3)
	_goal_on(level, Vector2i.LEFT, Block.TileColor.RED)
	level.disabled_cells = [Vector2i(1, 1)] as Array[Vector2i]
	_add(level, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i(0, 0), Vector2i(3, 0)])
	var sim = PuzzleSimScript.new()
	var exited: Dictionary = sim.apply_move(sim.load_config(level), 0, Vector2i.LEFT)
	_check(int(exited.outcome) == PuzzleSimScript.Outcome.SCORE, "an unused cell does not block a full-shape exit")
	# Plain slide across an unused cell, stopping against a real piece beyond it.
	var slide := _board(6, 3)
	slide.disabled_cells = [Vector2i(2, 1)] as Array[Vector2i]
	_add(slide, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.MERGE, [Vector2i.ZERO])
	_add(slide, Vector2i(5, 1), Block.TileColor.BLUE, Block.BlockKind.MERGE, [Vector2i.ZERO])
	var moved: Dictionary = sim.apply_move(sim.load_config(slide), 0, Vector2i.RIGHT)
	_check(
		int(moved.outcome) == PuzzleSimScript.Outcome.MERGE
		and moved.state.blocks[0].occupied() == [Vector2i(4, 1), Vector2i(5, 1)],
		"a piece slides across an unused cell and merges at the real piece"
	)
	# Stops on an unused cell when the real piece is right after it.
	var stop := _board(6, 3)
	stop.disabled_cells = [Vector2i(3, 1)] as Array[Vector2i]
	_add(stop, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.MERGE, [Vector2i.ZERO])
	_add(stop, Vector2i(4, 1), Block.TileColor.BLUE, Block.BlockKind.MERGE, [Vector2i.ZERO])
	var parked: Dictionary = sim.apply_move(sim.load_config(stop), 0, Vector2i.RIGHT)
	_check(
		int(parked.outcome) == PuzzleSimScript.Outcome.MERGE
		and Vector2i(3, 1) in parked.state.blocks[0].occupied(),
		"a merged piece can occupy an unused cell"
	)
	# Real pieces in a pocket still block, even with unused cells around.
	var pocket := _board(6, 3)
	_goal_on(pocket, Vector2i.LEFT, Block.TileColor.RED)
	pocket.disabled_cells = [Vector2i(1, 1)] as Array[Vector2i]
	_add(pocket, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i(0, 0), Vector2i(3, 0)])
	_add(pocket, Vector2i(2, 1), Block.TileColor.BLUE, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var stuck: Dictionary = sim.apply_move(sim.load_config(pocket), 0, Vector2i.LEFT)
	_check(int(stuck.outcome) == PuzzleSimScript.Outcome.FAIL, "a real piece in the path still blocks next to unused cells")
	# Board parity.
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	board.load_level(level)
	var b0 = board.placed_blocks[0]
	var r0: Dictionary = board._compute_slide(b0, b0.grid_pos, Vector2i.LEFT)
	_check(int(r0.get("next_result", -1)) == 1 and not bool(r0.get("exit_blocked", true)), "Board: unused cell does not block the exit")
	var walled := _board(6, 3)
	_goal_on(walled, Vector2i.LEFT, Block.TileColor.RED)
	_add(walled, Vector2i(0, 1), Block.TileColor.RED, Block.BlockKind.STANDARD, [Vector2i(0, 0), Vector2i(3, 0)])
	_add(walled, Vector2i(1, 1), Block.TileColor.RED, Block.BlockKind.WALL, [Vector2i.ZERO])
	board.load_level(walled)
	var b1 = board.placed_blocks[0]
	var r1: Dictionary = board._compute_slide(b1, b1.grid_pos, Vector2i.LEFT)
	_check(int(r1.get("next_result", -1)) != 1, "Board: a wall piece blocks the same exit")
	board.load_level(slide)
	var b2 = board.placed_blocks[0]
	var r2: Dictionary = board._compute_slide(b2, b2.grid_pos, Vector2i.RIGHT)
	_check(r2.get("target") == Vector2i(4, 1), "Board: slide crosses the unused cell to the real piece")
	board.queue_free()
	_check(
		PuzzleSimScript.shape_can_fully_exit([Vector2i(0, 1), Vector2i(3, 1)], Vector2i.LEFT, {}, 6, 3),
		"certifier ignores unused cells (they are never in the blocked set)"
	)


func _check_exit_certification() -> void:
	var frame: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(4, 2),
	]
	var pocket := {Vector2i(2, 1): true}
	_check(
		not PuzzleSimScript.shape_can_fully_exit(frame, Vector2i.LEFT, pocket, 6, 4),
		"certifier rejects a left exit through a pocket"
	)
	_check(
		PuzzleSimScript.shape_can_fully_exit(frame, Vector2i.LEFT, {}, 6, 4),
		"certifier allows the same frame when the pocket is empty"
	)
	var bar: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	_check(
		PuzzleSimScript.shape_can_fully_exit(bar, Vector2i.DOWN, {}, 3, 3),
		"certifier allows a straight bar off its edge"
	)
	var gen = load("res://scritps/tools/generate_twinkle_drift_levels.gd").new()
	_check(
		not gen._can_exit(frame, Vector2i.LEFT, pocket, {}, 6, 4),
		"Twinkle peel check rejects a pass-through exit"
	)
	_check(
		gen._can_exit(bar, Vector2i.DOWN, {}, {}, 3, 3),
		"Twinkle peel check still allows a straight exit"
	)


func _check_paradiddle() -> void:
	var level: LevelConfig = load("res://resources/levels/custom_level_1792900030.tres")
	var solved: Dictionary = LevelSolverScript.solve(level, 20000)
	_check(bool(solved.solvable) and int(solved.min_moves) == 4, "Paradiddle is a 4-move clear")
	var letters := _play_letters(level, [
		[0, Vector2i.LEFT],
		[0, Vector2i.RIGHT],
		[1, Vector2i.LEFT],
		[0, Vector2i.LEFT],
	])
	_check(letters == "LRLL", "Paradiddle still accepts LRLL (%s)" % letters)

	var wrapped := level.duplicate(true) as LevelConfig
	var red: Array[Vector2i] = []
	for cell in level.block_cell_patterns[0]:
		red.append(cell)
	red.append(Vector2i(10, 1))
	red.append(Vector2i(10, 2))
	red.append(Vector2i(10, 3))
	var orange: Array[Vector2i] = []
	for cell in level.block_cell_patterns[1]:
		orange.append(cell)
	orange.append(Vector2i(0, 2))
	orange.append(Vector2i(0, 3))
	wrapped.block_cell_patterns = level.block_cell_patterns.duplicate()
	wrapped.block_cell_patterns[0] = red
	wrapped.block_cell_patterns[1] = orange
	var sim = PuzzleSimScript.new()
	var old: Dictionary = sim.apply_move(sim.load_config(wrapped), 0, Vector2i.LEFT)
	_check(int(old.outcome) != PuzzleSimScript.Outcome.SCORE, "restored wrap cannot fly out to the left")
	var old_solved: Dictionary = LevelSolverScript.solve(wrapped, 5000)
	_check(not bool(old_solved.solvable), "old wrapped Paradiddle has no solution once exits cannot pass through")


func _check_board_agrees() -> void:
	var frame := [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(0, 1), Vector2i(4, 1),
		Vector2i(0, 2), Vector2i(4, 2),
	]
	var level := _board(6, 4)
	_goal_left(level, Block.TileColor.RED)
	_add(level, Vector2i(0, 0), Block.TileColor.RED, Block.BlockKind.STANDARD, frame)
	_add(level, Vector2i(2, 1), Block.TileColor.BLUE, Block.BlockKind.STANDARD, [Vector2i.ZERO])
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	board.load_level(level)
	var mover = board.placed_blocks[0]
	var slide: Dictionary = board._compute_slide(mover, mover.grid_pos, Vector2i.LEFT)
	_check(bool(slide.get("exit_blocked", false)), "Board slide blocks the wrapped exit")
	_check(int(slide.get("next_result", -1)) != 1, "Board does not treat the wrapped exit as off-board")
	var sim = PuzzleSimScript.new()
	var sim_move: Dictionary = sim.apply_move(sim.load_config(level), 0, Vector2i.LEFT)
	_check(int(sim_move.outcome) == PuzzleSimScript.Outcome.FAIL, "solver matches the Board on the wrapped exit")

	var paradiddle: LevelConfig = load("res://resources/levels/custom_level_1792900030.tres")
	board.load_level(paradiddle)
	var red = board.placed_blocks[0]
	var opened: Dictionary = board._compute_slide(red, red.grid_pos, Vector2i.LEFT)
	_check(
		not bool(opened.get("exit_blocked", true)) and int(opened.get("next_result", -1)) == 1,
		"Board lets the repaired Paradiddle red piece leave left"
	)
	board.queue_free()


## Needle Spire: the user's move. Blue (0,9) + yellow (3,9) merge into a green
## that wraps the unused cell at (3,10). Unused cells are not obstacles, so the
## green leaves right into the green goal. The rows 7-8 green square does too.
func _check_needle_spire() -> void:
	var level: LevelConfig = load("res://resources/levels/custom_level_1792900016.tres")
	var sim = PuzzleSimScript.new()
	var start = sim.load_config(level)
	var wrap: Dictionary = sim.apply_move(start, 11, Vector2i.LEFT)
	_check(int(wrap.outcome) == PuzzleSimScript.Outcome.MERGE, "Needle Spire lower yellow merges into the blue")
	var green_i: int = wrap.state.blocks.size() - 1
	_check(int(wrap.state.blocks[green_i].color) == Block.TileColor.GREEN, "Needle Spire lower merge is green")
	var out_wrap: Dictionary = sim.apply_move(wrap.state, green_i, Vector2i.RIGHT)
	_check(int(out_wrap.outcome) == PuzzleSimScript.Outcome.SCORE, "Needle Spire lower green crosses the unused cell into the right goal")
	var square: Dictionary = sim.apply_move(start, 8, Vector2i.RIGHT)
	_check(int(square.outcome) == PuzzleSimScript.Outcome.MERGE, "Needle Spire rows 7-8 yellow merges into the blue")
	var out: Dictionary = sim.apply_move(square.state, square.state.blocks.size() - 1, Vector2i.RIGHT)
	_check(int(out.outcome) == PuzzleSimScript.Outcome.SCORE, "rows 7-8 green square exits right into the green goal")
	var path_ok := _replay_wins(level, NEEDLE_SPIRE_SOLUTION)
	_check(path_ok, "Needle Spire recorded 16-move solution replays to a win with 3 lives")

	var shaped := _board(5, 14)
	shaped.disabled_cells = level.disabled_cells.duplicate()
	_goal_on(shaped, Vector2i.RIGHT, Block.TileColor.GREEN)
	_add(shaped, Vector2i(0, 9), Block.TileColor.GREEN, Block.BlockKind.MERGE, [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(4, 1),
	])
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	board.load_level(shaped)
	var g = board.placed_blocks[0]
	var r: Dictionary = board._compute_slide(g, g.grid_pos, Vector2i.RIGHT)
	_check(int(r.get("next_result", -1)) == 1 and not bool(r.get("exit_blocked", true)), "Board lets the Needle Spire lower green leave right")
	board.queue_free()


func _check_unused_cells_do_not_score() -> void:
	## Unused cells are scenery: the same board scores the same with or without them.
	var level: LevelConfig = load("res://resources/levels/custom_level_1792900016.tres")
	var bare := level.duplicate(true) as LevelConfig
	bare.disabled_cells = [] as Array[Vector2i]
	var a: Dictionary = LevelDifficulty.rate(level, 16)
	var b: Dictionary = LevelDifficulty.rate(bare, 16)
	_check(
		is_equal_approx(float(a.score), float(b.score)) and int(a.tier) == int(b.tier),
		"difficulty score ignores unused cells (%s vs %s)" % [a.score, b.score]
	)


## [block_index, direction] in the order the simulator indexes pieces at each step.
const NEEDLE_SPIRE_SOLUTION := [
	[15, Vector2i.DOWN], [14, Vector2i.UP], [13, Vector2i.LEFT], [1, Vector2i.LEFT],
	[2, Vector2i.LEFT], [1, Vector2i.LEFT], [7, Vector2i.DOWN], [7, Vector2i.UP],
	[7, Vector2i.RIGHT], [0, Vector2i.RIGHT], [0, Vector2i.UP], [1, Vector2i.RIGHT],
	[3, Vector2i.RIGHT], [0, Vector2i.RIGHT], [0, Vector2i.UP], [0, Vector2i.UP],
]


func _replay_wins(level: LevelConfig, steps: Array) -> bool:
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	for step in steps:
		var result: Dictionary = sim.apply_move(state, int(step[0]), step[1] as Vector2i)
		var o := int(result.outcome)
		if not bool(result.ok) or o == PuzzleSimScript.Outcome.FAIL or o == PuzzleSimScript.Outcome.NONE:
			return false
		state = result.state
	return state.is_won() and state.lives == 3


func _play_letters(level: LevelConfig, steps: Array) -> String:
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	var letters := ""
	for step in steps:
		var idx: int = step[0]
		var dir: Vector2i = step[1]
		var result: Dictionary = sim.apply_move(state, idx, dir)
		if int(result.outcome) != PuzzleSimScript.Outcome.SCORE:
			return letters + "?"
		letters += _letter(dir)
		state = result.state
	if not state.is_won():
		return letters + "!"
	return letters


func _letter(dir: Vector2i) -> String:
	if dir == Vector2i.LEFT:
		return "L"
	if dir == Vector2i.RIGHT:
		return "R"
	if dir == Vector2i.UP:
		return "U"
	if dir == Vector2i.DOWN:
		return "D"
	return "?"


func _board(columns: int, rows: int) -> LevelConfig:
	var level := LevelConfig.new()
	level.columns = columns
	level.rows = rows
	level.multi_goal_mode = true
	level.goal_left_enabled = false
	level.goal_top_enabled = false
	level.goal_right_enabled = false
	level.goal_bottom_enabled = false
	return level


func _goal_left(level: LevelConfig, color: int) -> void:
	_goal_on(level, Vector2i.LEFT, color)


func _goal_on(level: LevelConfig, direction: Vector2i, color: int) -> void:
	var phase := GoalPhase.new()
	phase.color = color as Block.TileColor
	phase.count = 1
	var phases: Array[GoalPhase] = [phase]
	if direction == Vector2i.LEFT:
		level.goal_left_phases = phases
		level.goal_left_enabled = true
	elif direction == Vector2i.RIGHT:
		level.goal_right_phases = phases
		level.goal_right_enabled = true
	elif direction == Vector2i.UP:
		level.goal_top_phases = phases
		level.goal_top_enabled = true
	else:
		level.goal_bottom_phases = phases
		level.goal_bottom_enabled = true


func _add(level: LevelConfig, pos: Vector2i, color: int, kind: int, cells: Array) -> void:
	level.block_positions.append(pos)
	level.block_colors.append(color as Block.TileColor)
	level.block_kinds.append(kind as Block.BlockKind)
	level.block_shapes.append("single")
	var pattern: Array[Vector2i] = []
	for cell in cells:
		pattern.append(cell)
	level.block_cell_patterns.append(pattern)
