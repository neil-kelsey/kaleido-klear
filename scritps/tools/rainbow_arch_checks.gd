extends SceneTree

## Rainbow Arch (Comet Shallows) keeps a solid red 2×3 bar.
## The old top-left notch made an L. It is not required for the unique
## five-down clear. Run:
##   godot --headless --path . -s res://scritps/tools/rainbow_arch_checks.gd

const LEVEL_PATH := "res://resources/levels/custom_level_1792900028.tres"
const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")

const RECT: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2),
]
const EXPECT_POS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(2, 1), Vector2i(4, 2), Vector2i(6, 3), Vector2i(8, 4),
]
const EXPECT_COLORS: Array[int] = [
	Block.TileColor.BLUE,
	Block.TileColor.GREEN,
	Block.TileColor.YELLOW,
	Block.TileColor.ORANGE,
	Block.TileColor.RED,
]
const EXPECT_GOAL: Array[int] = [
	Block.TileColor.RED,
	Block.TileColor.ORANGE,
	Block.TileColor.YELLOW,
	Block.TileColor.GREEN,
	Block.TileColor.BLUE,
]

const MAX_SOLUTIONS := 16
const MAX_VISITS := 20000

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
	var level := load(LEVEL_PATH) as LevelConfig
	_check(level != null and level.display_name == "Rainbow Arch", "loaded Rainbow Arch")
	if level == null:
		quit(1)
		return true

	_check(level.level_id == "custom_level_1792900028", "level id unchanged")
	_check(level.columns == 10 and level.rows == 7, "board stays 10×7")
	_check(level.section_index == 2, "stays in Comet Shallows section")
	_check(level.group_title_key == "UI_GROUP_COMET_SHALLOWS", "group unchanged")
	_check(level.sort_index == 5, "sort index unchanged")
	_check(level.difficulty_tier == 1 and level.min_moves == 5, "still an easy 5-move level")
	_check(
		level.goal_bottom_enabled
		and not level.goal_left_enabled
		and not level.goal_top_enabled
		and not level.goal_right_enabled,
		"only the bottom edge is open"
	)
	_check(level.multi_goal_mode, "bottom goal is a sequence")
	_check(level.block_positions.size() == 5, "five pieces")

	var staircase_ok := true
	for i in EXPECT_POS.size():
		if level.block_positions[i] != EXPECT_POS[i]:
			staircase_ok = false
		if int(level.block_colors[i]) != EXPECT_COLORS[i]:
			staircase_ok = false
		if int(level.block_kinds[i]) != int(Block.BlockKind.STANDARD):
			staircase_ok = false
		if not _same_cells(level.block_cell_patterns[i], RECT):
			staircase_ok = false
	_check(staircase_ok, "blue/green/yellow/orange/red are identical 2×3 bars on the staircase")

	var goal_ok := level.goal_bottom_phases.size() == EXPECT_GOAL.size()
	if goal_ok:
		for i in EXPECT_GOAL.size():
			var phase: GoalPhase = level.goal_bottom_phases[i]
			if phase == null or int(phase.color) != EXPECT_GOAL[i] or phase.count != 1:
				goal_ok = false
	_check(goal_ok, "bottom asks for red, orange, yellow, green, blue")

	var layout_error := _layout_error(level)
	_check(layout_error.is_empty(), "solid bars sit in bounds without overlap (%s)" % layout_error)

	var solid := _enumerate(level)
	_report("solid", solid)
	_check(not bool(solid.truncated), "solid search finished")
	_check(solid.solutions.size() == 1, "solid red has one solution (got %d)" % solid.solutions.size())
	if solid.solutions.size() >= 1:
		var first: Dictionary = solid.solutions[0]
		_check(str(first.letters) == "DDDDD", "solid solution is DDDDD (got %s)" % str(first.letters))
		_check(
			_colors_equal(first.colors, EXPECT_GOAL),
			"solid clears red, orange, yellow, green, blue (got %s)" % str(first.colors)
		)

	var opening := _accepted_from(level)
	_check(
		opening.size() == 1 and str(opening[0].letters) == "D" and int(opening[0].color) == Block.TileColor.RED,
		"only opening move is down on red (got %s)" % _format_moves(opening)
	)

	var notched := _notched_copy(level)
	var notch_layout := _layout_error(notched)
	_check(notch_layout.is_empty(), "historical notch still a legal layout (%s)" % notch_layout)
	var notch_cells: Array = notched.block_cell_patterns[4]
	_check(
		notch_cells.size() == 5 and not _pattern_has(notch_cells, Vector2i.ZERO),
		"notch copy is the old L (missing the top-left cell)"
	)
	var notched_result := _enumerate(notched)
	_report("notch", notched_result)
	_check(not bool(notched_result.truncated), "notch search finished")
	_check(
		notched_result.solutions.size() == 1,
		"notch was not load-bearing (got %d solutions)" % notched_result.solutions.size()
	)
	if solid.solutions.size() == 1 and notched_result.solutions.size() == 1:
		var a: Dictionary = solid.solutions[0]
		var b: Dictionary = notched_result.solutions[0]
		_check(
			str(a.letters) == str(b.letters) and _colors_equal(a.colors, b.colors),
			"solid and notched share the same clear"
		)

	var solved: Dictionary = LevelSolverScript.solve(level)
	var solver_letters := ""
	for step in solved.path:
		solver_letters += _letter(step.direction)
	_check(bool(solved.solvable) and int(solved.min_moves) == 5, "LevelSolver min moves is 5")
	_check(solver_letters == "DDDDD", "LevelSolver path is DDDDD (got %s)" % solver_letters)

	print("rainbow_arch_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true


func _enumerate(config: LevelConfig) -> Dictionary:
	var sim = PuzzleSimScript.new()
	var start = sim.load_config(config)
	var solutions: Array = []
	var guard: Dictionary = {}
	var path: Array = []
	var stats := {"states": 0, "truncated": false}
	_dfs(sim, start, guard, path, solutions, stats)
	return {
		"solutions": solutions,
		"states": int(stats.states),
		"truncated": bool(stats.truncated),
	}


func _dfs(sim, state, guard: Dictionary, path: Array, solutions: Array, stats: Dictionary) -> void:
	if bool(stats.truncated):
		return
	if state.is_won():
		solutions.append(_snapshot(path))
		if solutions.size() >= MAX_SOLUTIONS:
			stats.truncated = true
		return
	var key: String = state.fingerprint()
	if guard.has(key):
		return
	stats.states = int(stats.states) + 1
	if int(stats.states) > MAX_VISITS:
		stats.truncated = true
		return
	guard[key] = true
	for action in sim.legal_actions(state):
		var idx: int = int(action.block_index)
		var dir: Vector2i = action.direction
		var moving = state.blocks[idx]
		var color: int = int(moving.color)
		var result: Dictionary = sim.apply_move(state, idx, dir)
		if not bool(result.get("ok", false)):
			continue
		var outcome: int = int(result.get("outcome", 0))
		if outcome == PuzzleSimScript.Outcome.NONE or outcome == PuzzleSimScript.Outcome.FAIL:
			continue
		path.append({"dir": dir, "color": color, "outcome": outcome})
		_dfs(sim, result.state, guard, path, solutions, stats)
		path.pop_back()
		if bool(stats.truncated):
			break
	guard.erase(key)


func _accepted_from(config: LevelConfig) -> Array:
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(config)
	var moves: Array = []
	for action in sim.legal_actions(state):
		var idx: int = int(action.block_index)
		var dir: Vector2i = action.direction
		var moving = state.blocks[idx]
		var result: Dictionary = sim.apply_move(state, idx, dir)
		if not bool(result.get("ok", false)):
			continue
		var outcome: int = int(result.get("outcome", 0))
		if outcome == PuzzleSimScript.Outcome.NONE or outcome == PuzzleSimScript.Outcome.FAIL:
			continue
		moves.append({
			"letters": _letter(dir),
			"color": int(moving.color),
			"outcome": outcome,
		})
	return moves


func _notched_copy(level: LevelConfig) -> LevelConfig:
	var copy := level.duplicate(true) as LevelConfig
	copy.block_cell_patterns = level.block_cell_patterns.duplicate()
	var trimmed: Array[Vector2i] = []
	for cell in level.block_cell_patterns[4]:
		var offset := cell as Vector2i
		if offset != Vector2i.ZERO:
			trimmed.append(offset)
	copy.block_cell_patterns[4] = trimmed
	return copy


func _layout_error(level: LevelConfig) -> String:
	var occupied: Dictionary = {}
	for i in level.block_positions.size():
		var anchor: Vector2i = level.block_positions[i]
		var pattern: Array = level.block_cell_patterns[i]
		for cell in pattern:
			var world: Vector2i = anchor + (cell as Vector2i)
			if world.x < 0 or world.y < 0 or world.x >= level.columns or world.y >= level.rows:
				return "out of bounds %s" % world
			if occupied.has(world):
				return "overlap at %s" % world
			occupied[world] = i
	return ""


func _same_cells(pattern: Array, expect: Array) -> bool:
	if pattern.size() != expect.size():
		return false
	var seen: Dictionary = {}
	for cell in pattern:
		seen[cell] = true
	for cell in expect:
		if not seen.has(cell):
			return false
	return true


func _pattern_has(pattern: Array, needle: Vector2i) -> bool:
	for cell in pattern:
		if (cell as Vector2i) == needle:
			return true
	return false


func _colors_equal(got: Array, expect: Array) -> bool:
	if got.size() != expect.size():
		return false
	for i in got.size():
		if int(got[i]) != int(expect[i]):
			return false
	return true


func _snapshot(path: Array) -> Dictionary:
	var letters := ""
	var colors: Array[int] = []
	for step in path:
		letters += _letter(step.dir)
		colors.append(int(step.color))
	return {"letters": letters, "colors": colors}


func _letter(dir: Vector2i) -> String:
	if dir == Vector2i.DOWN:
		return "D"
	if dir == Vector2i.UP:
		return "U"
	if dir == Vector2i.LEFT:
		return "L"
	if dir == Vector2i.RIGHT:
		return "R"
	return "?"


func _format_moves(moves: Array) -> String:
	var bits: PackedStringArray = []
	for move in moves:
		bits.append("%s:%d" % [str(move.letters), int(move.color)])
	return ",".join(bits)


func _report(label: String, result: Dictionary) -> void:
	var rendered: PackedStringArray = []
	for solution in result.solutions:
		rendered.append(str(solution.letters))
	print(
		"%s: states=%d solutions=%d truncated=%s [%s]"
		% [label, int(result.states), result.solutions.size(), str(result.truncated), ", ".join(rendered)]
	)
