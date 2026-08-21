extends SceneTree

## Tutorial Bigger Boards levels 2–5 (section 10, sort 220–250).
## Level 1 (test_bigger_bait_1, sort 210) is kept as-is and only verified.
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_bigger_board_levels.gd

const SECTION_TUTORIAL := 10
const _GROUP_BIGGER := "UI_GROUP_BIGGER_BOARDS"
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Bigger Boards generate / verify ===")
	var exit_code := 0

	exit_code = maxi(exit_code, _verify_kept_bait_1(lines))

	for spec in _level_specs():
		var level: LevelConfig = spec.level
		lines.append("")
		lines.append("--- %s ---" % level.level_id)
		lines.append(
			"section=%d size=%dx%d sort=%d"
			% [level.section_index, level.columns, level.rows, level.sort_index]
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
		lines.append(
			"difficulty score=%s tier=%s colors=%s blocks=%s"
			% [rating.score, rating.tier, rating.colors, rating.blocks]
		)
		if not bool(result.get("solvable", false)):
			lines.append("ERROR: Level is not solvable — not saving.")
			exit_code = 1
			continue

		if spec.has("bait"):
			var bait: Dictionary = spec.bait
			var trap: Dictionary = LevelSolverScript.bait_traps(
				level,
				int(bait.block_index),
				bait.direction as Vector2i
			)
			lines.append(
				"bait trap=%s (%s)"
				% [trap.get("traps", false), trap.get("reason", "")]
			)
			if not bool(trap.get("ok", false)) or not bool(trap.get("traps", false)):
				lines.append("ERROR: Bait does not trap the player — not saving.")
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
	lines.append("Done (Bigger Boards, Tutorial section %d)." % SECTION_TUTORIAL)
	for line in lines:
		print(line)
	quit(exit_code)


func _verify_kept_bait_1(lines: PackedStringArray) -> int:
	lines.append("")
	lines.append("--- test_bigger_bait_1 (kept, verify only) ---")
	var level: LevelConfig = load("res://resources/levels/test_bigger_bait_1.tres")
	if level == null:
		lines.append("ERROR: missing kept bait 1")
		return 1
	var result: Dictionary = LevelSolverScript.solve(level)
	lines.append(
		"solvable=%s min_moves=%s states=%s"
		% [
			result.get("solvable", false),
			result.get("min_moves", -1),
			result.get("states_explored", 0),
		]
	)
	var trap: Dictionary = LevelSolverScript.bait_traps(level, 0, Vector2i.LEFT)
	lines.append("bait trap=%s (%s)" % [trap.get("traps", false), trap.get("reason", "")])
	if (
		not bool(result.get("solvable", false))
		or not bool(trap.get("ok", false))
		or not bool(trap.get("traps", false))
	):
		lines.append("ERROR: kept bait 1 is no longer a valid bait puzzle")
		return 1
	if level.sort_index != 210 or level.group_title_key != _GROUP_BIGGER:
		lines.append(
			"WARN: kept bait 1 sort/group is %s / %s (expected 210 / %s)"
			% [level.sort_index, level.group_title_key, _GROUP_BIGGER]
		)
	return 0


func _level_specs() -> Array:
	return [
		## Top-green cap looks free; it must wait for the left edge's last phase.
		_spec_bait(_build_top_cap(), 0, Vector2i.UP),
		## L-wall forces a detour; shifting top R→G→B. Right-blue is a callback bait.
		_spec_bait(_build_wall_path(), 0, Vector2i.RIGHT),
		## Mix red+yellow once. Dumping the red mixer into the left red goal bricks it.
		_spec_bait(_build_mix_finale(), 0, Vector2i.LEFT),
		## Mix red+blue once to purple. Dumping the bottom-flush blue mixer bricks it.
		_spec_bait(_build_gauntlet(), 0, Vector2i.DOWN),
	]


func _spec_bait(level: LevelConfig, bait_block: int, bait_dir: Vector2i) -> Dictionary:
	return {
		"level": level,
		"bait": {"block_index": bait_block, "direction": bait_dir},
	}


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
	level.goal_bottom_color = edge_colors.get("bottom", Block.TileColor.RED) as Block.TileColor
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


func _build_top_cap() -> LevelConfig:
	## 8×8 shelves. The 8-cell green cap is flush with the top (and left).
	## Top wants green ×1, so it looks free — but that green must wait for the
	## left edge's last phase. Inland green takes the top after the cap leaves.
	return _from_ascii(
		"test_bigger_top_cap",
		"Bigger 2 — Top Cap",
		220,
		PackedStringArray([
			"00011111",
			"00044331",
			"20044331",
			"22224333",
			"24444355",
			"22888555",
			"68887775",
			"66688755",
		]),
		{
			"0": Block.TileColor.GREEN,
			"1": Block.TileColor.RED,
			"2": Block.TileColor.BLUE,
			"3": Block.TileColor.GREEN,
			"4": Block.TileColor.RED,
			"5": Block.TileColor.BLUE,
			"6": Block.TileColor.RED,
			"7": Block.TileColor.BLUE,
			"8": Block.TileColor.RED,
		},
		{
			"enabled": {"left": true, "top": true, "right": true, "bottom": false},
			"edge_colors": {
				"left": Block.TileColor.RED,
				"top": Block.TileColor.GREEN,
				"right": Block.TileColor.BLUE,
				"bottom": Block.TileColor.RED,
			},
			"phases": {
				"left": [
					_phase(Block.TileColor.RED),
					_phase(Block.TileColor.BLUE),
					_phase(Block.TileColor.GREEN),
				] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.GREEN)] as Array[GoalPhase],
				"right": [
					_phase(Block.TileColor.BLUE, 2),
					_phase(Block.TileColor.RED, 3),
				] as Array[GoalPhase],
				"bottom": [] as Array[GoalPhase],
			},
			"names": {
				"0": "Green Cap",
				"1": "Red Rim",
				"2": "Blue Bend",
				"3": "Green Twin",
				"4": "Red Mid",
				"5": "Blue Wing",
				"6": "Red Hook",
				"7": "Blue Nub",
				"8": "Red Shelf",
			},
		}
	)


func _build_wall_path() -> LevelConfig:
	## 8×8 with a 3-cell L wall. Shifting top R→G→B, bottom G×2 then R×2.
	## The right-flush blue looks like a free exit (right wants blue ×1) but
	## must wait for the top's last phase — a bait callback, not the main lesson.
	return _from_ascii(
		"test_bigger_wall_path",
		"Bigger 3 — Wall Path",
		230,
		PackedStringArray([
			"88222200",
			"8WW42210",
			"8W444210",
			"74443210",
			"75433210",
			"75333210",
			"75533310",
			"77551111",
		]),
		{
			"0": Block.TileColor.BLUE,
			"1": Block.TileColor.RED,
			"2": Block.TileColor.GREEN,
			"3": Block.TileColor.BLUE,
			"4": Block.TileColor.RED,
			"5": Block.TileColor.GREEN,
			"7": Block.TileColor.GREEN,
			"8": Block.TileColor.RED,
			"W": Block.TileColor.RED,
		},
		{
			"enabled": {"left": false, "top": true, "right": true, "bottom": true},
			"edge_colors": {
				"left": Block.TileColor.BLUE,
				"top": Block.TileColor.RED,
				"right": Block.TileColor.BLUE,
				"bottom": Block.TileColor.GREEN,
			},
			"phases": {
				"left": [] as Array[GoalPhase],
				"top": [
					_phase(Block.TileColor.RED),
					_phase(Block.TileColor.GREEN),
					_phase(Block.TileColor.BLUE),
				] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.BLUE)] as Array[GoalPhase],
				"bottom": [
					_phase(Block.TileColor.GREEN, 2),
					_phase(Block.TileColor.RED, 2),
				] as Array[GoalPhase],
			},
			"kinds": {"W": Block.BlockKind.WALL},
			"names": {
				"0": "Blue Side",
				"1": "Red Base",
				"2": "Green Top",
				"3": "Blue Spine",
				"4": "Red Elbow",
				"5": "Green Floor",
				"7": "Green Bend",
				"8": "Red Cap",
				"W": "Wall L",
			},
		}
	)


func _build_mix_finale() -> LevelConfig:
	## Two 3×2 MERGE blocks (red + yellow) sit on top of a 2×2 wall.
	## Mix once to orange for the right goal. Left wants red ×1 — that slot
	## belongs to the standard red, not the mixer. Scoring the mixer left bricks it.
	return _from_ascii(
		"test_bigger_mix_finale",
		"Bigger 4 — Mix Finale",
		240,
		PackedStringArray([
			"00011122",
			"00011122",
			"WW334422",
			"WW334455",
			"66334455",
			"66777555",
			"66777888",
			"66777888",
		]),
		{
			"0": Block.TileColor.RED,
			"1": Block.TileColor.YELLOW,
			"2": Block.TileColor.GREEN,
			"3": Block.TileColor.BLUE,
			"4": Block.TileColor.GREEN,
			"5": Block.TileColor.BLUE,
			"6": Block.TileColor.RED,
			"7": Block.TileColor.GREEN,
			"8": Block.TileColor.BLUE,
			"W": Block.TileColor.RED,
		},
		{
			"enabled": {"left": true, "top": true, "right": true, "bottom": true},
			"edge_colors": {
				"left": Block.TileColor.RED,
				"top": Block.TileColor.GREEN,
				"right": Block.TileColor.ORANGE,
				"bottom": Block.TileColor.GREEN,
			},
			"phases": {
				"left": [_phase(Block.TileColor.RED)] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.GREEN, 2)] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.ORANGE)] as Array[GoalPhase],
				"bottom": [
					_phase(Block.TileColor.GREEN),
					_phase(Block.TileColor.BLUE, 3),
				] as Array[GoalPhase],
			},
			"kinds": {
				"0": Block.BlockKind.MERGE,
				"1": Block.BlockKind.MERGE,
				"W": Block.BlockKind.WALL,
			},
			"names": {
				"0": "Red Mixer",
				"1": "Yellow Mixer",
				"2": "Green Cap",
				"3": "Blue Mid",
				"4": "Green Step",
				"5": "Blue Wing",
				"6": "Red Body",
				"7": "Green Floor",
				"8": "Blue Corner",
				"W": "Wall Square",
			},
		}
	)


func _build_gauntlet() -> LevelConfig:
	## Chapter closer: wall + shifting top R→G→Y + MERGE-once (red+blue=purple).
	## The 7-cell blue mixer is flush with the bottom while bottom wants blue ×1 —
	## that's the bait. Mix it with the red mixer instead; purple exits right.
	## The 2×2 wall blocks a left escape, so the mix has to go around. A standard
	## blue slab takes the bottom-blue quota. MERGE-once only; no second mix.
	return _from_ascii(
		"test_bigger_gauntlet",
		"Bigger 5 — Gauntlet",
		250,
		PackedStringArray([
			"66666588",
			"66677558",
			"77775558",
			"77345442",
			"WW344422",
			"WW331122",
			"00011122",
			"00001222",
		]),
		{
			"0": Block.TileColor.BLUE,
			"1": Block.TileColor.RED,
			"2": Block.TileColor.BLUE,
			"3": Block.TileColor.RED,
			"4": Block.TileColor.RED,
			"5": Block.TileColor.YELLOW,
			"6": Block.TileColor.GREEN,
			"7": Block.TileColor.RED,
			"8": Block.TileColor.GREEN,
			"W": Block.TileColor.RED,
		},
		{
			"enabled": {"left": true, "top": true, "right": true, "bottom": true},
			"edge_colors": {
				"left": Block.TileColor.GREEN,
				"top": Block.TileColor.RED,
				"right": Block.TileColor.PURPLE,
				"bottom": Block.TileColor.BLUE,
			},
			"phases": {
				"left": [_phase(Block.TileColor.GREEN)] as Array[GoalPhase],
				"top": [
					_phase(Block.TileColor.RED),
					_phase(Block.TileColor.GREEN),
					_phase(Block.TileColor.YELLOW),
				] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.PURPLE)] as Array[GoalPhase],
				"bottom": [
					_phase(Block.TileColor.BLUE),
					_phase(Block.TileColor.RED, 2),
				] as Array[GoalPhase],
			},
			"kinds": {
				"0": Block.BlockKind.MERGE,
				"1": Block.BlockKind.MERGE,
				"W": Block.BlockKind.WALL,
			},
			"names": {
				"0": "Blue Mixer",
				"1": "Red Mixer",
				"2": "Blue Slab",
				"3": "Red Stem",
				"4": "Red Shelf",
				"5": "Yellow Bend",
				"6": "Green Rim",
				"7": "Red Crown",
				"8": "Green Hook",
				"W": "Wall Square",
			},
		}
	)


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
