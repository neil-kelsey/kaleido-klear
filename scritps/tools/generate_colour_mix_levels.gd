extends SceneTree

## Build the Tutorial Colour Mix chapter (section 10, sort 160–200).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_colour_mix_levels.gd

const SECTION_TUTORIAL := 10
const _GROUP_COLOUR_MIX := "UI_GROUP_COLOUR_MIX"
const MIN_CELLS := 3
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Colour Mix generate / verify ===")
	var exit_code := 0

	if not _assert_merge_once(lines):
		_finish(lines, 1)
		return

	for spec in _level_specs():
		var level: LevelConfig = spec.level
		lines.append("")
		lines.append("--- %s ---" % level.level_id)

		var cell_err := _min_cell_error(level)
		if not cell_err.is_empty():
			lines.append("ERROR: %s" % cell_err)
			exit_code = 1
			continue

		var result: Dictionary = LevelSolverScript.solve(level)
		var rating: Dictionary = LevelDifficultyScript.rate(
			level, int(result.get("min_moves", -1))
		)
		lines.append(
			"solvable=%s min_moves=%s states=%s"
			% [
				result.get("solvable", false),
				result.get("min_moves", -1),
				result.get("states_explored", 0),
			]
		)
		if not bool(result.get("solvable", false)):
			lines.append("ERROR: Level is not solvable — not saving.")
			exit_code = 1
			continue

		if spec.has("trap"):
			var trap: Dictionary = _verify_trap(level, spec.trap)
			lines.append("trap unsolvable=%s (%s)" % [trap.get("ok", false), trap.get("reason", "")])
			if not bool(trap.get("ok", false)):
				lines.append("ERROR: Fail-state trap did not brick the puzzle.")
				exit_code = 1
				continue

		level.verified_solvable = true
		level.min_moves = int(result.min_moves)
		level.difficulty_score = float(rating.score)
		level.difficulty_tier = int(rating.tier)

		var save_err := _save_project_level(level)
		if save_err != OK:
			lines.append("ERROR: Failed to save level, error=%s" % save_err)
			exit_code = 1
			continue
		lines.append("Saved res://resources/levels/%s.tres" % level.level_id)

	_finish(lines, exit_code)


func _assert_merge_once(lines: PackedStringArray) -> bool:
	var ok := true
	var expect := {
		"R+Y": [Block.TileColor.RED, Block.TileColor.YELLOW, Block.TileColor.ORANGE],
		"Y+B": [Block.TileColor.YELLOW, Block.TileColor.BLUE, Block.TileColor.GREEN],
		"R+B": [Block.TileColor.RED, Block.TileColor.BLUE, Block.TileColor.PURPLE],
	}
	for key in expect:
		var a: Block.TileColor = expect[key][0]
		var b: Block.TileColor = expect[key][1]
		var want: int = expect[key][2]
		var got := Block.get_merged_color(a, b)
		var got_rev := Block.get_merged_color(b, a)
		if got != want or got_rev != want:
			lines.append("FAIL mix %s: got %s / %s want %s" % [key, got, got_rev, want])
			ok = false
		else:
			lines.append("ok mix %s -> %s" % [key, want])

	var forbidden: Array = [
		[Block.TileColor.ORANGE, Block.TileColor.BLUE],
		[Block.TileColor.ORANGE, Block.TileColor.RED],
		[Block.TileColor.ORANGE, Block.TileColor.YELLOW],
		[Block.TileColor.GREEN, Block.TileColor.RED],
		[Block.TileColor.GREEN, Block.TileColor.YELLOW],
		[Block.TileColor.GREEN, Block.TileColor.BLUE],
		[Block.TileColor.PURPLE, Block.TileColor.YELLOW],
		[Block.TileColor.PURPLE, Block.TileColor.RED],
		[Block.TileColor.PURPLE, Block.TileColor.BLUE],
		[Block.TileColor.RED, Block.TileColor.RED],
		[Block.TileColor.ORANGE, Block.TileColor.GREEN],
		[Block.TileColor.ORANGE, Block.TileColor.PURPLE],
		[Block.TileColor.GREEN, Block.TileColor.PURPLE],
	]
	for pair in forbidden:
		var got_bad := Block.get_merged_color(pair[0], pair[1])
		if got_bad != -1:
			lines.append("FAIL re-mix %s+%s -> %s" % [pair[0], pair[1], got_bad])
			ok = false
	if ok:
		lines.append("ok merge-once: secondaries cannot mix")
	if not _assert_sim_rejects_remerge(lines):
		ok = false
	return ok


func _assert_sim_rejects_remerge(lines: PackedStringArray) -> bool:
	## Orange (secondary) + blue (primary) must bounce, not mix, in PuzzleSim.
	var level := _make_level(
		"merge_once_probe",
		"probe",
		0,
		{
			"left": false,
			"top": false,
			"right": true,
			"bottom": false,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Orange", Block.TileColor.ORANGE, _line3_h(0, 2)),
			_piece("Blue", Block.TileColor.BLUE, _line3_h(0, 4)),
		]
	)
	var sim := PuzzleSim.new()
	var state = sim.load_config(level)
	var applied: Dictionary = sim.apply_move(state, 1, Vector2i.UP)
	var outcome := int(applied.get("outcome", PuzzleSim.Outcome.NONE))
	if outcome == PuzzleSim.Outcome.MERGE:
		lines.append("FAIL PuzzleSim allowed orange+blue re-merge")
		return false
	lines.append("ok PuzzleSim rejects orange+blue re-merge (outcome=%s)" % outcome)
	return true


func _level_specs() -> Array:
	return [
		{"level": _level_orange_intro()},
		{"level": _level_purple_pair()},
		{"level": _level_green_pair()},
		{"level": _level_two_mixes()},
		{
			"level": _level_deadlock(),
			## Swipe both top T’s down: orange and green mix into the same
			## band and block each other's left/right goals.
			"trap": [
				{"block_index": 0, "direction": Vector2i.DOWN},
				{"color": Block.TileColor.YELLOW, "direction": Vector2i.DOWN},
			],
		},
	]


func _level_orange_intro() -> LevelConfig:
	## Two vertical line_3s. Mix, then swipe the orange into the right goal.
	return _make_level(
		"test_5x5_colour_mix_1",
		"Colour Mix 1 — Orange",
		160,
		{
			"left": false,
			"top": false,
			"right": true,
			"bottom": false,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red Bar", Block.TileColor.RED, _line3_v(1, 1), BlockShapes.LINE_3),
			_piece("Yellow Bar", Block.TileColor.YELLOW, _line3_v(3, 1), BlockShapes.LINE_3),
		]
	)


func _level_purple_pair() -> LevelConfig:
	## Two L trominoes. Mix, then swipe the purple into the top goal.
	return _make_level(
		"test_5x5_colour_mix_2",
		"Colour Mix 2 — Purple",
		170,
		{
			"left": false,
			"top": true,
			"right": false,
			"bottom": false,
			"top_color": Block.TileColor.PURPLE,
		},
		[
			_piece("Red L", Block.TileColor.RED, _l_se(1, 1), BlockShapes.L_SHAPE),
			_piece("Blue L", Block.TileColor.BLUE, _l_se(1, 3), BlockShapes.L_SHAPE),
		]
	)


func _level_green_pair() -> LevelConfig:
	## Yellow line_3 + blue L → green, then swipe left. Third mix colour,
	## still a 2-move obvious board — no wrong-mix bait.
	return _make_level(
		"test_5x5_colour_mix_3",
		"Colour Mix 3 — Green",
		180,
		{
			"left": true,
			"top": false,
			"right": false,
			"bottom": false,
			"left_color": Block.TileColor.GREEN,
		},
		[
			_piece("Yellow Bar", Block.TileColor.YELLOW, _line3_h(0, 0), BlockShapes.LINE_3),
			_piece("Blue L", Block.TileColor.BLUE, _l_se(2, 2), BlockShapes.L_SHAPE),
		]
	)


func _level_two_mixes() -> LevelConfig:
	## T + L on top (orange, right) and two L trominoes below (purple, top).
	return _make_level(
		"test_5x5_colour_mix_4",
		"Colour Mix 4 — Two Mixes",
		190,
		{
			"left": false,
			"top": true,
			"right": true,
			"bottom": false,
			"top_color": Block.TileColor.PURPLE,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red T", Block.TileColor.RED, _t_south(0, 0), "t_shape"),
			_piece("Yellow L", Block.TileColor.YELLOW, _l_sw(5, 0), BlockShapes.L_SHAPE),
			_piece("Blue L", Block.TileColor.BLUE, _l_ne(0, 4), BlockShapes.L_SHAPE),
			_piece("Red L", Block.TileColor.RED, _l_se(3, 4), BlockShapes.L_SHAPE),
		],
		{"columns": 6, "rows": 6}
	)


func _level_deadlock() -> LevelConfig:
	## Two T pairs on a 6×6. Mix each pair on its own row, then send orange
	## right and green left. Swiping both top T’s down parks two mixed pieces
	## in the same band — orange cannot reach the right goal, green cannot
	## reach the left (Dimension 2’s in-line deadlock, 3+ cell pieces).
	return _make_level(
		"test_5x5_colour_mix_5",
		"Colour Mix 5 — Challenge",
		200,
		{
			"left": true,
			"top": false,
			"right": true,
			"bottom": false,
			"left_color": Block.TileColor.GREEN,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red Top T", Block.TileColor.RED, _t_south(0, 1), "t_shape"),
			_piece("Yellow Top T", Block.TileColor.YELLOW, _t_south(3, 1), "t_shape"),
			_piece("Yellow Low T", Block.TileColor.YELLOW, _t_south(0, 4), "t_shape"),
			_piece("Blue Low T", Block.TileColor.BLUE, _t_south(3, 4), "t_shape"),
		],
		{"columns": 6, "rows": 6}
	)


func _line3_h(x: int, y: int) -> Array[Vector2i]:
	return [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 2, y)]


func _line3_v(x: int, y: int) -> Array[Vector2i]:
	return [Vector2i(x, y), Vector2i(x, y + 1), Vector2i(x, y + 2)]


func _l_se(x: int, y: int) -> Array[Vector2i]:
	## #
	## ##
	return [Vector2i(x, y), Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]


func _l_ne(x: int, y: int) -> Array[Vector2i]:
	## ##
	##  #
	return [Vector2i(x, y), Vector2i(x + 1, y), Vector2i(x + 1, y + 1)]


func _l_sw(x: int, y: int) -> Array[Vector2i]:
	##  #
	## ##
	return [Vector2i(x, y), Vector2i(x - 1, y + 1), Vector2i(x, y + 1)]


func _t_south(x: int, y: int) -> Array[Vector2i]:
	## ###
	##  #
	return [
		Vector2i(x, y),
		Vector2i(x + 1, y),
		Vector2i(x + 2, y),
		Vector2i(x + 1, y + 1),
	]


func _piece(
	piece_name: String,
	color: Block.TileColor,
	cells: Array[Vector2i],
	shape: String = BlockShapes.L_SHAPE
) -> Dictionary:
	return {
		"name": piece_name,
		"color": color,
		"cells": cells,
		"shape": shape,
		"kind": Block.BlockKind.MERGE,
	}


func _make_level(
	level_id: String,
	display_name: String,
	sort_index: int,
	goals: Dictionary,
	pieces: Array,
	opts: Dictionary = {}
) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = level_id
	level.display_name = display_name
	level.level_name_key = ""
	level.section_index = SECTION_TUTORIAL
	level.sort_index = sort_index
	level.group_title_key = _GROUP_COLOUR_MIX
	level.columns = int(opts.get("columns", 5))
	level.rows = int(opts.get("rows", 5))
	level.disabled_cells = []
	level.multi_goal_mode = false

	level.goal_left_enabled = bool(goals.get("left", false))
	level.goal_top_enabled = bool(goals.get("top", false))
	level.goal_right_enabled = bool(goals.get("right", false))
	level.goal_bottom_enabled = bool(goals.get("bottom", false))
	level.goal_left_color = goals.get("left_color", Block.TileColor.RED) as Block.TileColor
	level.goal_top_color = goals.get("top_color", Block.TileColor.BLUE) as Block.TileColor
	level.goal_right_color = goals.get("right_color", Block.TileColor.GREEN) as Block.TileColor
	level.goal_bottom_color = goals.get("bottom_color", Block.TileColor.YELLOW) as Block.TileColor

	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []

	for piece in pieces:
		var cells: Array[Vector2i] = []
		for cell in piece.cells:
			cells.append(cell as Vector2i)
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cells)
		level.block_positions.append(packed.anchor)
		level.block_colors.append(piece.color as Block.TileColor)
		level.block_shapes.append(str(piece.get("shape", BlockShapes.L_SHAPE)))
		level.block_kinds.append(piece.kind as Block.BlockKind)
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append(str(piece.name))
	return level


func _min_cell_error(level: LevelConfig) -> String:
	for i in level.block_positions.size():
		var kind := (
			int(level.block_kinds[i]) if i < level.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if Block.is_wall_kind(kind as Block.BlockKind):
			continue
		var cells: Array = LevelGenRulesScript.absolute_cells(level, i)
		if cells.size() < MIN_CELLS:
			return "block %d (%s) has %d cells; Colour Mix minimum is %d" % [
				i,
				level.block_shape_names[i] if i < level.block_shape_names.size() else "?",
				cells.size(),
				MIN_CELLS,
			]
		var shape_id := str(level.block_shapes[i]) if i < level.block_shapes.size() else ""
		if shape_id == BlockShapes.SINGLE or shape_id == BlockShapes.LINE_2:
			return "block %d uses %s — Colour Mix forbids 1-cell and 2-cell shapes" % [i, shape_id]
	return ""


func _verify_trap(level: LevelConfig, moves: Array) -> Dictionary:
	var sim := PuzzleSim.new()
	var state = sim.load_config(level)
	for move in moves:
		var block_index := _trap_block_index(state, move)
		if block_index < 0:
			return {"ok": false, "reason": "trap block not found"}
		var applied: Dictionary = sim.apply_move(
			state,
			block_index,
			move.direction as Vector2i
		)
		if not bool(applied.get("ok", false)):
			return {"ok": false, "reason": "trap move not legal"}
		if int(applied.get("outcome", PuzzleSim.Outcome.NONE)) != PuzzleSim.Outcome.MERGE:
			return {"ok": false, "reason": "trap move did not merge"}
		state = applied.state
	var result: Dictionary = LevelSolverScript.solve_state(sim, state)
	if bool(result.get("solvable", false)):
		return {"ok": false, "reason": "trap still solvable"}
	return {"ok": true, "reason": "wrong line deadlocks; %s" % _state_cells(state)}


func _state_cells(state) -> String:
	var parts: PackedStringArray = []
	for block in state.blocks:
		var cells: PackedStringArray = []
		for cell in block.occupied():
			cells.append("%s,%s" % [cell.x, cell.y])
		parts.append("c%s[%s]" % [block.color, " ".join(cells)])
	return " ".join(parts)


func _trap_block_index(state, move: Dictionary) -> int:
	if move.has("block_index"):
		return int(move.block_index)
	if move.has("color"):
		var want := int(move.color)
		for i in state.blocks.size():
			if int(state.blocks[i].color) == want:
				return i
	return -1


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
