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
	_check_paradiddle()
	_check_board_agrees()
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
	var phase := GoalPhase.new()
	phase.color = color as Block.TileColor
	phase.count = 1
	var phases: Array[GoalPhase] = [phase]
	level.goal_left_phases = phases
	level.goal_left_enabled = true


func _add(level: LevelConfig, pos: Vector2i, color: int, kind: int, cells: Array) -> void:
	level.block_positions.append(pos)
	level.block_colors.append(color as Block.TileColor)
	level.block_kinds.append(kind as Block.BlockKind)
	level.block_shapes.append("single")
	var pattern: Array[Vector2i] = []
	for cell in cells:
		pattern.append(cell)
	level.block_cell_patterns.append(pattern)
