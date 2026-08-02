extends SceneTree

## Diagnose shifting_4 solvability and print a concrete move path.
## Godot --headless --path <project> -s res://scritps/tools/diagnose_shifting_4.gd

const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")


func _initialize() -> void:
	var level: LevelConfig = load("res://resources/levels/test_5x5_shifting_4.tres")
	print("=== diagnose %s ===" % level.level_id)
	_print_phases(level)
	_print_blocks(level)

	var result: Dictionary = LevelSolverScript.solve(level)
	print(
		"solver: solvable=%s min_moves=%s states=%s"
		% [result.get("solvable"), result.get("min_moves"), result.get("states_explored")]
	)

	if not bool(result.get("solvable", false)):
		print("NOT SOLVABLE according to headless solver")
		quit(1)
		return

	var path: Array = result.path
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	print("--- replaying path ---")
	var step := 0
	for action in path:
		step += 1
		var bi: int = int(action.block_index)
		var dir: Vector2i = action.direction as Vector2i
		var block = state.blocks[bi]
		var before := "block#%d color=%d pos=%s cells=%s" % [
			bi, block.color, block.pos, block.cells
		]
		var applied: Dictionary = sim.apply_move(state, bi, dir)
		state = applied.state
		print(
			"step %d: %s dir=%s outcome=%s lives=%d blocks_left=%d ok=%s"
			% [
				step,
				before,
				_dir_name(dir),
				_outcome_name(int(applied.outcome)),
				state.lives,
				state.clearable_count(),
				applied.ok,
			]
		)
		print(
			"  phases L=%d/%d T=%d/%d R=%d/%d B=%d/%d"
			% [
				state.edge_phase[0], state.edge_scored[0],
				state.edge_phase[1], state.edge_scored[1],
				state.edge_phase[2], state.edge_scored[2],
				state.edge_phase[3], state.edge_scored[3],
			]
		)
		if not bool(applied.ok) or int(applied.outcome) == 4:
			print("  WARNING: path used a non-clean move")

	print("final won=%s lost=%s blocks=%d lives=%d" % [
		state.is_won(), state.is_lost(), state.clearable_count(), state.lives
	])
	quit(0 if state.is_won() else 2)


func _print_phases(level: LevelConfig) -> void:
	print("multi_goal=%s" % level.multi_goal_mode)
	_print_edge("left", level.goal_left_phases)
	_print_edge("top", level.goal_top_phases)
	_print_edge("right", level.goal_right_phases)
	_print_edge("bottom", level.goal_bottom_phases)


func _print_edge(name: String, phases: Array[GoalPhase]) -> void:
	var bits: PackedStringArray = []
	for phase in phases:
		bits.append("%s×%d" % [_color_name(int(phase.color)), phase.count])
	print("  %s: %s" % [name, " → ".join(bits)])


func _print_blocks(level: LevelConfig) -> void:
	for i in level.block_positions.size():
		var cells: Array = []
		var anchor: Vector2i = level.block_positions[i]
		for offset in level.block_cell_patterns[i]:
			cells.append(anchor + offset)
		print(
			"  block %d %s color=%s cells=%s"
			% [i, level.block_shape_names[i], _color_name(int(level.block_colors[i])), cells]
		)


func _dir_name(dir: Vector2i) -> String:
	if dir == Vector2i.LEFT:
		return "LEFT"
	if dir == Vector2i.RIGHT:
		return "RIGHT"
	if dir == Vector2i.UP:
		return "UP"
	if dir == Vector2i.DOWN:
		return "DOWN"
	return str(dir)


func _outcome_name(outcome: int) -> String:
	match outcome:
		0:
			return "NONE"
		1:
			return "SLIDE"
		2:
			return "SCORE"
		3:
			return "MERGE"
		4:
			return "FAIL"
		_:
			return str(outcome)


func _color_name(color: int) -> String:
	match color:
		0:
			return "RED"
		1:
			return "GREEN"
		2:
			return "BLUE"
		_:
			return str(color)
