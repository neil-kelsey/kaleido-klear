extends SceneTree

## Build the Tutorial Colour Mix chapter (section 10, sort 51–55).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_colour_mix_levels.gd

const SECTION_TUTORIAL := 10
const _GROUP_COLOUR_MIX := "UI_GROUP_COLOUR_MIX"
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Colour Mix generate / verify ===")
	var exit_code := 0

	if not _assert_merge_once(lines):
		_finish(lines, 1)
		return

	for level in _levels():
		lines.append("")
		lines.append("--- %s ---" % level.level_id)
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

	lines.append("")
	lines.append("=== Dimension 2 merge demos (merge-once) ===")
	for path in [
		"res://resources/levels/merge_demo.tres",
		"res://resources/levels/merge_demo_2.tres",
		"res://resources/levels/merge_demo_level.tres",
		"res://resources/levels/merge_demo_level_2.tres",
	]:
		var demo: LevelConfig = load(path)
		if demo == null:
			lines.append("MISSING %s" % path)
			exit_code = 1
			continue
		var demo_result: Dictionary = LevelSolverScript.solve(demo)
		lines.append(
			"%s solvable=%s min_moves=%s states=%s"
			% [
				demo.level_id,
				demo_result.get("solvable", false),
				demo_result.get("min_moves", -1),
				demo_result.get("states_explored", 0),
			]
		)
		if not bool(demo_result.get("solvable", false)):
			lines.append("WARN: %s is unsolvable under merge-once." % demo.level_id)

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
			_piece("Orange", Block.TileColor.ORANGE, Vector2i(1, 2), BlockShapes.SINGLE),
			_piece("Blue", Block.TileColor.BLUE, Vector2i(3, 2), BlockShapes.SINGLE),
		]
	)
	var sim := PuzzleSim.new()
	var state = sim.load_config(level)
	var applied: Dictionary = sim.apply_move(state, 1, Vector2i.LEFT)
	var outcome := int(applied.get("outcome", PuzzleSim.Outcome.NONE))
	if outcome == PuzzleSim.Outcome.MERGE:
		lines.append("FAIL PuzzleSim allowed orange+blue re-merge")
		return false
	lines.append("ok PuzzleSim rejects orange+blue re-merge (outcome=%s)" % outcome)
	return true


func _levels() -> Array[LevelConfig]:
	return [
		_level_orange_intro(),
		_level_purple_pair(),
		_level_green_trap(),
		_level_two_mixes_open(),
		_level_two_mixes_stacked(),
	]


func _level_orange_intro() -> LevelConfig:
	## Red + yellow on one row; mix then swipe the orange into the right goal.
	return _make_level(
		"test_5x5_colour_mix_1",
		"Colour Mix 1 — Orange",
		51,
		{
			"left": false,
			"top": false,
			"right": true,
			"bottom": false,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red Drop", Block.TileColor.RED, Vector2i(1, 2), BlockShapes.SINGLE),
			_piece("Yellow Drop", Block.TileColor.YELLOW, Vector2i(3, 2), BlockShapes.SINGLE),
		]
	)


func _level_purple_pair() -> LevelConfig:
	## Same idea, vertical: red + blue → purple, exit top.
	return _make_level(
		"test_5x5_colour_mix_2",
		"Colour Mix 2 — Purple",
		52,
		{
			"left": false,
			"top": true,
			"right": false,
			"bottom": false,
			"top_color": Block.TileColor.PURPLE,
		},
		[
			_piece("Red Drop", Block.TileColor.RED, Vector2i(2, 1), BlockShapes.SINGLE),
			_piece("Blue Drop", Block.TileColor.BLUE, Vector2i(2, 3), BlockShapes.SINGLE),
		]
	)


func _level_green_trap() -> LevelConfig:
	## Yellow + blue → green (left). Extra red on the blue column is a wrong-mix bait;
	## after the correct mix it still scores on the red bottom goal.
	return _make_level(
		"test_5x5_colour_mix_3",
		"Colour Mix 3 — Green Trap",
		53,
		{
			"left": true,
			"top": false,
			"right": false,
			"bottom": true,
			"left_color": Block.TileColor.GREEN,
			"bottom_color": Block.TileColor.RED,
		},
		[
			_piece("Yellow Drop", Block.TileColor.YELLOW, Vector2i(1, 1), BlockShapes.SINGLE),
			_piece("Blue Drop", Block.TileColor.BLUE, Vector2i(3, 1), BlockShapes.SINGLE),
			_piece("Red Bait", Block.TileColor.RED, Vector2i(3, 3), BlockShapes.SINGLE),
		]
	)


func _level_two_mixes_open() -> LevelConfig:
	## Two independent first-generation mixes: orange exits right, purple exits top.
	return _make_level(
		"test_5x5_colour_mix_4",
		"Colour Mix 4 — Two Mixes",
		54,
		{
			"left": false,
			"top": true,
			"right": true,
			"bottom": false,
			"top_color": Block.TileColor.PURPLE,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red High", Block.TileColor.RED, Vector2i(0, 1), BlockShapes.SINGLE),
			_piece("Yellow High", Block.TileColor.YELLOW, Vector2i(2, 1), BlockShapes.SINGLE),
			_piece("Blue Low", Block.TileColor.BLUE, Vector2i(1, 4), BlockShapes.SINGLE),
			_piece("Red Low", Block.TileColor.RED, Vector2i(3, 4), BlockShapes.SINGLE),
		]
	)


func _level_two_mixes_stacked() -> LevelConfig:
	## Two first-generation mixes stacked on the same columns. Orange (right) must
	## be cleared before purple can reach the top goal — a second mix is never required.
	return _make_level(
		"test_5x5_colour_mix_5",
		"Colour Mix 5 — Challenge",
		55,
		{
			"left": false,
			"top": true,
			"right": true,
			"bottom": false,
			"top_color": Block.TileColor.PURPLE,
			"right_color": Block.TileColor.ORANGE,
		},
		[
			_piece("Red Top", Block.TileColor.RED, Vector2i(1, 1), BlockShapes.SINGLE),
			_piece("Yellow Top", Block.TileColor.YELLOW, Vector2i(3, 1), BlockShapes.SINGLE),
			_piece("Red Low", Block.TileColor.RED, Vector2i(1, 3), BlockShapes.SINGLE),
			_piece("Blue Low", Block.TileColor.BLUE, Vector2i(3, 3), BlockShapes.SINGLE),
		]
	)


func _piece(
	piece_name: String,
	color: Block.TileColor,
	pos: Vector2i,
	shape: String,
	kind: Block.BlockKind = Block.BlockKind.MERGE
) -> Dictionary:
	return {
		"name": piece_name,
		"color": color,
		"pos": pos,
		"shape": shape,
		"kind": kind,
	}


func _make_level(
	level_id: String,
	display_name: String,
	sort_index: int,
	goals: Dictionary,
	pieces: Array
) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = level_id
	level.display_name = display_name
	level.level_name_key = ""
	level.section_index = SECTION_TUTORIAL
	level.sort_index = sort_index
	level.group_title_key = _GROUP_COLOUR_MIX
	level.columns = 5
	level.rows = 5
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
		level.block_positions.append(piece.pos as Vector2i)
		level.block_colors.append(piece.color as Block.TileColor)
		level.block_shapes.append(str(piece.shape))
		level.block_kinds.append(piece.kind as Block.BlockKind)
		level.block_cell_patterns.append(BlockShapes.get_cells(str(piece.shape)))
		level.block_shape_names.append(str(piece.name))
	return level


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
