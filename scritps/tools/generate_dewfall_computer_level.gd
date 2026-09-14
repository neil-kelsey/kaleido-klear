extends SceneTree

## Dewfall Nebula — Computer generated 01 (pinwheel core).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_dewfall_computer_level.gd

const SECTION_DEWFALL := 1
const GROUP_KEY := "UI_GROUP_COMPUTER_GENERATED"
const LEVEL_ID := "dewfall_computer_generated_01"
const SORT_INDEX := 310
const MIN_CELLS := 3
const SOLVE_STATES := 600000

const LevelConfigScript := preload("res://scritps/LevelConfig.gd")
const GoalPhaseScript := preload("res://scritps/GoalPhase.gd")
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")

const C_RED := Block.TileColor.RED
const C_BLUE := Block.TileColor.BLUE
const C_YELLOW := Block.TileColor.YELLOW
const C_GREEN := Block.TileColor.GREEN
const C_PURPLE := Block.TileColor.PURPLE
const C_ORANGE := Block.TileColor.ORANGE


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Dewfall computer-generated pinwheel ===")
	var chosen: LevelConfig = null
	var chosen_result: Dictionary = {}
	var chosen_label := ""

	for spec in _candidates():
		var level: LevelConfig = spec.level
		lines.append("")
		lines.append("--- %s ---" % spec.label)
		_print_board(level, lines)
		var cell_err := _min_cell_error(level)
		if not cell_err.is_empty():
			lines.append("ERROR: %s" % cell_err)
			continue
		var result: Dictionary = LevelSolverScript.solve(level, SOLVE_STATES)
		lines.append(
			"solvable=%s min_moves=%s states=%s"
			% [
				result.get("solvable", false),
				result.get("min_moves", -1),
				result.get("states_explored", 0),
			]
		)
		if not bool(result.get("solvable", false)):
			continue
		var moves := int(result.get("min_moves", -1))
		var mix: Dictionary = _path_mix(level, result.get("path", []))
		lines.append(
			"path mix merge=%s score=%s slide=%s"
			% [mix.merge, mix.score, mix.slide]
		)
		if moves < 8:
			lines.append("skip: too short for a dig-out mix puzzle")
			continue
		chosen = level
		chosen_result = result
		chosen_label = str(spec.label)
		break

	if chosen == null:
		lines.append("")
		lines.append("ERROR: no candidate solved")
		_finish(lines, 1)
		return

	var rating: Dictionary = LevelDifficultyScript.rate(
		chosen, int(chosen_result.get("min_moves", -1))
	)
	chosen.verified_solvable = true
	chosen.min_moves = int(chosen_result.min_moves)
	chosen.difficulty_score = float(rating.score)
	chosen.difficulty_tier = int(rating.tier)
	lines.append("")
	lines.append(
		"Using %s  min_moves=%s  tier=%s  score=%s"
		% [chosen_label, chosen.min_moves, chosen.difficulty_tier, chosen.difficulty_score]
	)

	var save_err := _save_project_level(chosen)
	if save_err != OK:
		lines.append("ERROR: Failed to save level, error=%s" % save_err)
		_finish(lines, 1)
		return
	lines.append("Saved res://resources/levels/%s.tres" % chosen.level_id)
	_finish(lines, 0)


func _candidates() -> Array:
	return [
		{
			"label": "bullseye-20 + top P2-G-O / bottom P / right B2",
			"level": _make_level(_board_bullseye_20(), _goals_bullseye_top_stack()),
		}
	]


## Red corners, blue ring, two yellow L's in the dead centre. No red touches
## yellow, so orange only exists after a blue is merged or slid out of the way.
func _board_bullseye_20() -> Dictionary:
	return {
		"name": "bullseye-20",
		"pieces": [
			_l("Red NW", C_RED, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]),
			_l("Blue N-W", C_BLUE, [Vector2i(2, 0), Vector2i(1, 1), Vector2i(2, 1)]),
			_l("Blue N-E", C_BLUE, [Vector2i(3, 0), Vector2i(3, 1), Vector2i(4, 1)]),
			_l("Red NE", C_RED, [Vector2i(4, 0), Vector2i(5, 0), Vector2i(5, 1)]),
			_l("Blue W", C_BLUE, [Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3)]),
			_l("Yellow W", C_YELLOW, [Vector2i(2, 2), Vector2i(1, 3), Vector2i(2, 3)]),
			_l("Yellow E", C_YELLOW, [Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3)]),
			_l("Blue E", C_BLUE, [Vector2i(5, 2), Vector2i(4, 3), Vector2i(5, 3)]),
			_l("Red SW", C_RED, [Vector2i(0, 4), Vector2i(0, 5), Vector2i(1, 5)]),
			_l("Blue S-W", C_BLUE, [Vector2i(1, 4), Vector2i(2, 4), Vector2i(2, 5)]),
			_l("Blue S-E", C_BLUE, [Vector2i(3, 4), Vector2i(4, 4), Vector2i(3, 5)]),
			_l("Red SE", C_RED, [Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]),
		],
	}


func _goals_bullseye_top_stack() -> Dictionary:
	## Mix sequence on the top so left/right pieces stay as ice bumpers.
	## Two purples teach the cheap mix, then green (ring + core), then orange
	## after a blue has been moved. Last purple dumps down; leftover blues right.
	return {
		"left": false,
		"top": true,
		"right": true,
		"bottom": true,
		"top_color": C_PURPLE,
		"right_color": C_BLUE,
		"bottom_color": C_PURPLE,
		"multi": true,
		"top_phases": [
			_phase(C_PURPLE, 2),
			_phase(C_GREEN, 1),
			_phase(C_ORANGE, 1),
		],
		"right_phases": [
			_phase(C_BLUE, 2),
		],
		"bottom_phases": [
			_phase(C_PURPLE, 1),
		],
	}


func _l(piece_name: String, color: Block.TileColor, cells: Array) -> Dictionary:
	var typed: Array[Vector2i] = []
	for cell in cells:
		typed.append(cell as Vector2i)
	return {
		"name": piece_name,
		"color": color,
		"cells": typed,
		"shape": BlockShapes.L_SHAPE,
		"kind": Block.BlockKind.MERGE,
	}


func _phase(color: Block.TileColor, count: int) -> GoalPhase:
	var phase: GoalPhase = GoalPhaseScript.new()
	phase.color = color
	phase.count = count
	phase.unlimited = false
	return phase


func _make_level(board: Dictionary, goals: Dictionary) -> LevelConfig:
	var level: LevelConfig = LevelConfigScript.new()
	level.level_id = LEVEL_ID
	level.display_name = "Yellow core"
	level.level_name_key = ""
	level.section_index = SECTION_DEWFALL
	level.sort_index = SORT_INDEX
	level.group_title_key = GROUP_KEY
	level.columns = 6
	level.rows = 6
	level.disabled_cells = []
	level.multi_goal_mode = bool(goals.get("multi", true))

	level.goal_left_enabled = bool(goals.get("left", false))
	level.goal_top_enabled = bool(goals.get("top", false))
	level.goal_right_enabled = bool(goals.get("right", false))
	level.goal_bottom_enabled = bool(goals.get("bottom", false))
	level.goal_left_color = goals.get("left_color", C_PURPLE) as Block.TileColor
	level.goal_top_color = goals.get("top_color", C_GREEN) as Block.TileColor
	level.goal_right_color = goals.get("right_color", C_ORANGE) as Block.TileColor
	level.goal_bottom_color = goals.get("bottom_color", C_YELLOW) as Block.TileColor
	level.goal_left_phases = _as_phases(goals.get("left_phases", []))
	level.goal_top_phases = _as_phases(goals.get("top_phases", []))
	level.goal_right_phases = _as_phases(goals.get("right_phases", []))
	level.goal_bottom_phases = _as_phases(goals.get("bottom_phases", []))

	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []

	for piece in board.pieces:
		var cells: Array[Vector2i] = piece.cells
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cells)
		level.block_positions.append(packed.anchor)
		level.block_colors.append(piece.color as Block.TileColor)
		level.block_shapes.append(str(piece.get("shape", BlockShapes.L_SHAPE)))
		level.block_kinds.append(piece.kind as Block.BlockKind)
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append(str(piece.name))
	return level


func _as_phases(raw: Variant) -> Array[GoalPhase]:
	var out: Array[GoalPhase] = []
	if raw == null:
		return out
	for item in raw:
		if item is GoalPhase:
			out.append(item)
	return out


func _min_cell_error(level: LevelConfig) -> String:
	var occupied: Dictionary = {}
	for i in level.block_positions.size():
		var kind := (
			int(level.block_kinds[i]) if i < level.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if Block.is_wall_kind(kind as Block.BlockKind):
			continue
		var cells: Array = LevelGenRulesScript.absolute_cells(level, i)
		if cells.size() < MIN_CELLS:
			return "block %d has %d cells" % [i, cells.size()]
		for cell in cells:
			if occupied.has(cell):
				return "overlap at %s" % cell
			occupied[cell] = true
	if occupied.size() != 36:
		return "expected 36 filled cells, got %d" % occupied.size()
	return ""


func _path_mix(level: LevelConfig, path: Array) -> Dictionary:
	var mix := {"merge": 0, "score": 0, "slide": 0, "other": 0}
	if path.is_empty():
		return mix
	var sim := PuzzleSim.new()
	var state = sim.load_config(level)
	for step in path:
		var applied: Dictionary = sim.apply_move(
			state,
			int(step.get("block_index", -1)),
			step.get("direction", Vector2i.ZERO) as Vector2i
		)
		if not bool(applied.get("ok", false)):
			mix.other += 1
			continue
		var outcome := int(applied.get("outcome", PuzzleSim.Outcome.NONE))
		match outcome:
			PuzzleSim.Outcome.MERGE:
				mix.merge += 1
			PuzzleSim.Outcome.SCORE:
				mix.score += 1
			PuzzleSim.Outcome.SLIDE:
				mix.slide += 1
			_:
				mix.other += 1
		state = applied.state
	return mix


func _print_board(level: LevelConfig, lines: PackedStringArray) -> void:
	var letters := {
		int(C_RED): "R",
		int(C_BLUE): "B",
		int(C_YELLOW): "Y",
		int(C_GREEN): "G",
		int(C_PURPLE): "P",
		int(C_ORANGE): "O",
	}
	var grid: Array = []
	for _y in level.rows:
		var row: PackedStringArray = []
		for _x in level.columns:
			row.append(".")
		grid.append(row)
	for i in level.block_positions.size():
		var ch: String = letters.get(int(level.block_colors[i]), "?")
		for cell in LevelGenRulesScript.absolute_cells(level, i):
			if cell.y >= 0 and cell.y < level.rows and cell.x >= 0 and cell.x < level.columns:
				grid[cell.y][cell.x] = ch
	for row in grid:
		lines.append("  " + " ".join(row))


func _save_project_level(level: LevelConfig) -> Error:
	var path := "res://resources/levels/%s.tres" % level.level_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/levels/"))
	var err := ResourceSaver.save(level, path)
	if err != OK:
		return err
	var store: Node = Engine.get_main_loop().root.get_node_or_null("CustomLevelStore")
	if store != null and store.has_method("rewrite_project_manifest"):
		return store.call("rewrite_project_manifest") as Error
	return _rewrite_registry_fallback(path)


func _rewrite_registry_fallback(new_path: String) -> Error:
	var paths: Array[String] = []
	var dir := DirAccess.open("res://resources/levels/")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				paths.append("res://resources/levels/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if not paths.has(new_path):
		paths.append(new_path)
	paths.sort()
	var lines: PackedStringArray = [
		"extends Object",
		"class_name LevelRegistry",
		"",
		"## Auto-updated when the level creator saves into the project.",
		"## Do not hand-edit unless you know why — CustomLevelStore.rewrite_project_manifest() owns this file.",
		"const LEVEL_PATHS: PackedStringArray = [",
	]
	for p in paths:
		lines.append("\t\"%s\"," % p)
	lines.append("]")
	lines.append("")
	var file := FileAccess.open("res://scritps/LevelRegistry.gd", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	return OK


func _finish(lines: PackedStringArray, code: int) -> void:
	for line in lines:
		print(line)
	quit(code)
