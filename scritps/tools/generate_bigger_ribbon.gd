extends SceneTree

## Adds the long, thin Bigger Boards tutorial closer (section 8, sort 260).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_bigger_ribbon.gd

const SECTION_TUTORIAL := 8
const _GROUP_BIGGER := "UI_GROUP_BIGGER_BOARDS"
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Bigger Boards ribbon generate / verify ===")
	var exit_code := 0
	var saved := false

	# Prefer a slightly harder split, but accept the natural peel if needed.
	var variants: Array = [
		{"id": "top2_bottom2", "top": 2, "bottom": 2},
		{"id": "top3_bottom1", "top": 3, "bottom": 1},
		{"id": "top1_bottom3", "top": 1, "bottom": 3},
	]
	var candidates: Array = []
	for variant in variants:
		var level := _build_ribbon(int(variant.top), int(variant.bottom))
		lines.append("")
		lines.append("--- %s (%s) ---" % [level.level_id, variant.id])
		lines.append(
			"section=%d size=%dx%d sort=%d group=%s goals T%d/B%d"
			% [
				level.section_index,
				level.columns,
				level.rows,
				level.sort_index,
				level.group_title_key,
				int(variant.top),
				int(variant.bottom),
			]
		)
		var rules: Dictionary = LevelGenRulesScript.validate(level)
		lines.append(
			"rules ok=%s occupied=%s disabled=%s empty=%s"
			% [
				rules.get("ok", false),
				rules.get("occupied", 0),
				rules.get("disabled", 0),
				rules.get("empty", 0),
			]
		)
		for err in rules.get("errors", []):
			lines.append("RULE ERROR: %s" % err)
		for warn in rules.get("warnings", []):
			lines.append("RULE WARN: %s" % warn)
		if not bool(rules.get("ok", false)):
			exit_code = 1
			continue
		var result: Dictionary = LevelSolverScript.solve(level)
		var rating: Dictionary = LevelDifficultyScript.rate(level, int(result.get("min_moves", -1)))
		lines.append(
			"solvable=%s min_moves=%s states=%s"
			% [
				result.get("solvable", false),
				result.get("min_moves", -1),
				result.get("states_explored", 0),
			]
		)
		lines.append(
			"difficulty score=%s tier=%s colors=%s blocks=%s"
			% [rating.score, rating.tier, rating.colors, rating.blocks]
		)
		if not bool(result.get("solvable", false)):
			lines.append("unsolvable at this split")
			continue
		var moves := int(result.min_moves)
		candidates.append({
			"level": level,
			"result": result,
			"rating": rating,
			"moves": moves,
			"variant": str(variant.id),
		})

	var chosen: Dictionary = {}
	for cand in candidates:
		var moves: int = int(cand.moves)
		if moves >= 12 and moves <= 18:
			if chosen.is_empty() or abs(moves - 15) < abs(int(chosen.moves) - 15):
				chosen = cand
	if chosen.is_empty():
		for cand in candidates:
			var moves2: int = int(cand.moves)
			if moves2 >= 10 and moves2 <= 20:
				if chosen.is_empty() or moves2 > int(chosen.moves):
					chosen = cand
	if chosen.is_empty():
		lines.append("")
		lines.append("ERROR: No solvable ribbon variant in the tutorial move window.")
		exit_code = 1
		_finish(lines, exit_code)
		return

	var level: LevelConfig = chosen.level
	var result: Dictionary = chosen.result
	var rating: Dictionary = chosen.rating
	var moves: int = int(chosen.moves)
	lines.append("")
	lines.append("Chosen variant %s with %d moves" % [chosen.variant, moves])

	level.verified_solvable = true
	level.min_moves = moves
	level.difficulty_score = float(rating.score)
	# Heuristic rates a 16-block 5x16 board as Very Hard; keep Medium like the rest of this tutorial chapter.
	level.difficulty_tier = 2

	var save_err := _save_project_level(level)
	if save_err != OK:
		lines.append("ERROR: Failed to save level, error=%s" % save_err)
		exit_code = 1
		_finish(lines, exit_code)
		return
	lines.append("Saved res://resources/levels/%s.tres" % level.level_id)
	_finish(lines, exit_code)


func _finish(lines: PackedStringArray, exit_code: int) -> void:
	lines.append("")
	lines.append("Done (Bigger Boards ribbon, Tutorial section %d)." % SECTION_TUTORIAL)
	for line in lines:
		print(line)
	quit(exit_code)


func _phase(color: Block.TileColor, count: int = 1) -> GoalPhase:
	var phase := GoalPhase.new()
	phase.color = color
	phase.count = count
	return phase


func _from_ascii(
	level_id: String,
	display_name: String,
	sort_index: int,
	rows: PackedStringArray,
	colors: Dictionary,
	opts: Dictionary = {}
) -> LevelConfig:
	var height := rows.size()
	var width := rows[0].length()
	var cells_by_id: Dictionary = {}
	for y in height:
		for x in width:
			var ch := rows[y].substr(x, 1)
			if not cells_by_id.has(ch):
				cells_by_id[ch] = [] as Array[Vector2i]
			(cells_by_id[ch] as Array).append(Vector2i(x, y))
	var ids: Array = cells_by_id.keys()
	ids.sort()

	var kinds: Dictionary = opts.get("kinds", {})
	var names: Dictionary = opts.get("names", {})
	var enabled: Dictionary = opts.get("enabled", {})
	var phases: Dictionary = opts.get("phases", {})
	var edge_colors: Dictionary = opts.get("edge_colors", {})

	var level := LevelConfig.new()
	level.level_id = level_id
	level.display_name = display_name
	level.level_name_key = ""
	level.section_index = SECTION_TUTORIAL
	level.sort_index = sort_index
	level.group_title_key = _GROUP_BIGGER
	level.columns = width
	level.rows = height
	level.disabled_cells = []
	level.goal_left_enabled = bool(enabled.get("left", true))
	level.goal_top_enabled = bool(enabled.get("top", true))
	level.goal_right_enabled = bool(enabled.get("right", true))
	level.goal_bottom_enabled = bool(enabled.get("bottom", true))
	level.goal_left_color = edge_colors.get("left", Block.TileColor.RED) as Block.TileColor
	level.goal_top_color = edge_colors.get("top", Block.TileColor.GREEN) as Block.TileColor
	level.goal_right_color = edge_colors.get("right", Block.TileColor.BLUE) as Block.TileColor
	level.goal_bottom_color = edge_colors.get("bottom", Block.TileColor.GREEN) as Block.TileColor
	level.multi_goal_mode = true
	level.goal_left_phases = phases.get("left", []) as Array[GoalPhase]
	level.goal_top_phases = phases.get("top", []) as Array[GoalPhase]
	level.goal_right_phases = phases.get("right", []) as Array[GoalPhase]
	level.goal_bottom_phases = phases.get("bottom", []) as Array[GoalPhase]
	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []
	for id in ids:
		var cell_list: Array[Vector2i] = []
		for cell in cells_by_id[id]:
			cell_list.append(cell as Vector2i)
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cell_list)
		level.block_positions.append(packed.anchor)
		level.block_colors.append(colors[id])
		level.block_shapes.append(BlockShapes.SINGLE)
		level.block_kinds.append(int(kinds.get(id, Block.BlockKind.STANDARD)))
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append(str(names.get(id, "Piece %s" % id)))
	return level


func _build_ribbon(green_top: int, green_bottom: int) -> LevelConfig:
	## Tall thin 5×16 ribbon. Reds stay on the left and exit left; blues stay
	## on the right and exit right; greens peel off the short ends. Fully filled,
	## no walls or holes.
	return _from_ascii(
		"test_bigger_ribbon",
		"Bigger 6 — Ribbon",
		260,
		PackedStringArray([
			"00011",
			"00011",
			"22011",
			"22333",
			"24433",
			"64455",
			"66555",
			"66777",
			"88777",
			"88899",
			"A8899",
			"AAABB",
			"CCCBB",
			"CCCDD",
			"EEEDD",
			"EEFFF",
		]),
		{
			"0": Block.TileColor.GREEN,
			"1": Block.TileColor.BLUE,
			"2": Block.TileColor.RED,
			"3": Block.TileColor.GREEN,
			"4": Block.TileColor.RED,
			"5": Block.TileColor.BLUE,
			"6": Block.TileColor.RED,
			"7": Block.TileColor.BLUE,
			"8": Block.TileColor.GREEN,
			"9": Block.TileColor.BLUE,
			"A": Block.TileColor.RED,
			"B": Block.TileColor.BLUE,
			"C": Block.TileColor.RED,
			"D": Block.TileColor.BLUE,
			"E": Block.TileColor.RED,
			"F": Block.TileColor.GREEN,
		},
		{
			"phases": {
				"left": [_phase(Block.TileColor.RED, 6)] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.GREEN, green_top)] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.BLUE, 6)] as Array[GoalPhase],
				"bottom": [_phase(Block.TileColor.GREEN, green_bottom)] as Array[GoalPhase],
			},
			"names": {
				"0": "Green Cap",
				"1": "Blue Crown",
				"2": "Red Shoulder",
				"3": "Green Shelf",
				"4": "Red Step",
				"5": "Blue Step",
				"6": "Red Bend",
				"7": "Blue Bend",
				"8": "Green Mid",
				"9": "Blue Mid",
				"A": "Red Mid",
				"B": "Blue Drop",
				"C": "Red Base",
				"D": "Blue Base",
				"E": "Red Foot",
				"F": "Green Foot",
			},
		}
	)


func _save_project_level(level: LevelConfig) -> Error:
	var path := "res://resources/levels/%s.tres" % level.level_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/levels/"))
	var err := ResourceSaver.save(level, path)
	if err != OK:
		return err
	# Do not call rewrite_project_manifest(): a full disk scan would pull stray
	# custom_level_*.tres drafts into LevelRegistry. Insert only this path.
	return _insert_registry_path(path)


func _insert_registry_path(new_path: String) -> Error:
	var file := FileAccess.open("res://scritps/LevelRegistry.gd", FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var text := file.get_as_text()
	file.close()
	var quoted := "\t\"%s\"," % new_path
	if text.find(quoted) != -1:
		return OK
	var needle := "const LEVEL_PATHS: PackedStringArray = [\n"
	var idx := text.find(needle)
	if idx == -1:
		return ERR_FILE_CORRUPT
	var start := idx + needle.length()
	var end := text.find("]", start)
	if end == -1:
		return ERR_FILE_CORRUPT
	var block := text.substr(start, end - start)
	var lines: PackedStringArray = []
	for raw in block.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		lines.append(line)
	lines.append(quoted.strip_edges())
	# quoted already has a leading tab when we re-join; normalize to tab-indented sorted lines.
	var items: Array[String] = []
	for line in lines:
		var s := line.strip_edges()
		if s.ends_with(","):
			s = s.substr(0, s.length() - 1)
		if s.begins_with("\"") and s.ends_with("\""):
			items.append(s.substr(1, s.length() - 2))
	items.sort()
	var rebuilt := ""
	for item in items:
		rebuilt += "\t\"%s\",\n" % item
	var out := text.substr(0, start) + rebuilt + text.substr(end)
	var out_file := FileAccess.open("res://scritps/LevelRegistry.gd", FileAccess.WRITE)
	if out_file == null:
		return FileAccess.get_open_error()
	out_file.store_string(out)
	out_file.close()
	return OK
