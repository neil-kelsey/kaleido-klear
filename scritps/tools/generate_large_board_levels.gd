extends SceneTree

## Bigger Boards tutorial levels 3-5 (section 10, sort 230/240/250).
## Frozen layouts + colours + goal phases found by a randomised playthrough
## search and verified with LevelSolver. Every piece is a MERGE block so the
## first useful move is a mix, never a score. Levels 1-2 are left untouched.
## Set KK_REPORT=1 to also count dead-end first moves (slow).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_large_board_levels.gd

const SECTION_TUTORIAL := 10
const _GROUP_BIGGER := "UI_GROUP_BIGGER_BOARDS"
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")
const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")


func _initialize() -> void:
	var exit_code := 0
	for spec in _specs():
		var level := _build(spec)
		print("--- %s ---" % level.level_id)
		var rules: Dictionary = LevelGenRulesScript.validate(level)
		print("rules ok=%s occupied=%s empty=%s" % [rules.get("ok"), rules.get("occupied"), rules.get("empty")])
		var blocking := 0
		for err in rules.get("errors", []):
			## Handmade silhouettes may leave empty space (docs/level-design.md).
			if bool(spec.get("allow_empty", false)) and str(err).contains("empty playable"):
				print("RULE NOTE (allowed, handmade silhouette): ", err)
				continue
			blocking += 1
			print("RULE ERROR: ", err)
		for warn in rules.get("warnings", []):
			print("RULE WARN: ", warn)
		if blocking > 0:
			exit_code = 1
			continue
		var result: Dictionary = LevelSolverScript.solve(level)
		print("solvable=%s min_moves=%s states=%s" % [result.get("solvable"), result.get("min_moves"), result.get("states_explored")])
		if not bool(result.get("solvable", false)):
			print("ERROR: not solvable")
			exit_code = 1
			continue
		var rating: Dictionary = LevelDifficultyScript.rate(level, int(result.min_moves))
		if OS.get_environment("KK_REPORT") == "1":
			_report_first_moves(level)
		level.verified_solvable = true
		level.min_moves = int(result.min_moves)
		level.difficulty_score = float(rating.score)
		level.difficulty_tier = int(rating.tier)
		var path := "res://resources/levels/%s.tres" % level.level_id
		var err := ResourceSaver.save(level, path)
		print("saved %s err=%d" % [path, err])
		if err != OK:
			exit_code = 1
	_rewrite_registry()
	quit(exit_code)


func _report_first_moves(level: LevelConfig) -> void:
	var sim = PuzzleSimScript.new()
	var start = sim.load_config(level)
	var scores := 0
	var accepted := 0
	var dead := 0
	for act in sim.legal_actions(start):
		var r: Dictionary = sim.apply_move(start, act.block_index, act.direction)
		if not r.ok:
			continue
		var oc: int = r.outcome
		if oc == 2:
			scores += 1
		if oc == 1 or oc == 2 or oc == 3:
			accepted += 1
			if not LevelSolverScript.solve_state(sim, r.state, 20000).solvable:
				dead += 1
	print("first-move scores=%d accepted=%d dead-end accepted=%d" % [scores, accepted, dead])


func _phase(color: Block.TileColor, count: int = 1) -> GoalPhase:
	var phase := GoalPhase.new()
	phase.color = color
	phase.count = count
	return phase


func _build(spec: Dictionary) -> LevelConfig:
	var rows: PackedStringArray = spec.rows
	var cells_by_id: Dictionary = {}
	for y in rows.size():
		for x in rows[y].length():
			var ch := rows[y].substr(x, 1)
			if ch == ".":
				continue
			if not cells_by_id.has(ch):
				cells_by_id[ch] = [] as Array[Vector2i]
			(cells_by_id[ch] as Array).append(Vector2i(x, y))
	var ids: Array = cells_by_id.keys()
	ids.sort()
	var level := LevelConfig.new()
	level.level_id = spec.id
	level.display_name = spec.name
	level.level_name_key = ""
	level.section_index = SECTION_TUTORIAL
	level.sort_index = spec.sort
	level.group_title_key = _GROUP_BIGGER
	level.columns = rows[0].length()
	level.rows = rows.size()
	level.disabled_cells = []
	var en: Dictionary = spec.enabled
	level.goal_left_enabled = en.left
	level.goal_top_enabled = en.top
	level.goal_right_enabled = en.right
	level.goal_bottom_enabled = en.bottom
	level.multi_goal_mode = true
	var ph: Dictionary = spec.phases
	level.goal_left_phases = ph.left as Array[GoalPhase]
	level.goal_top_phases = ph.top as Array[GoalPhase]
	level.goal_right_phases = ph.right as Array[GoalPhase]
	level.goal_bottom_phases = ph.bottom as Array[GoalPhase]
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
		level.block_colors.append(spec.colors[id])
		level.block_shapes.append(BlockShapes.SINGLE)
		level.block_kinds.append(int(Block.BlockKind.MERGE))
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append("Piece %s" % id)
	return level


func _rewrite_registry() -> void:
	var paths: Array[String] = []
	var dir := DirAccess.open("res://resources/levels/")
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			paths.append("res://resources/levels/" + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
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
	file.store_string("\n".join(lines))
	file.close()


func _specs() -> Array:
	return [
		{
			"id": "test_bigger_pinwheel",
			"name": "Bigger 3 — Pinwheel",
			"sort": 230,
			"rows": PackedStringArray([
				"AAABBBDDDD",
				"ACCBBBDFFD",
				"ACCCBBFFFD",
				"AACCCBFFEE",
				"KKKKMMFEEE",
				"KKKLMMEEEE",
				"KKLLHIIIGG",
				"JLLLHHIIIG",
				"JLLJHHHIIG",
				"JJJJHHHGGG",
			]),
			"colors": {"A": Block.TileColor.BLUE, "B": Block.TileColor.RED, "C": Block.TileColor.BLUE, "D": Block.TileColor.RED, "E": Block.TileColor.BLUE, "F": Block.TileColor.BLUE, "G": Block.TileColor.RED, "H": Block.TileColor.RED, "I": Block.TileColor.YELLOW, "J": Block.TileColor.YELLOW, "K": Block.TileColor.RED, "L": Block.TileColor.BLUE, "M": Block.TileColor.RED},
			"enabled": {"left": true, "top": true, "right": true, "bottom": false},
			"phases": {
				"left": [_phase(Block.TileColor.PURPLE, 2), _phase(Block.TileColor.YELLOW, 1), _phase(Block.TileColor.ORANGE, 1)] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.PURPLE, 2)] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.PURPLE, 1)] as Array[GoalPhase],
				"bottom": [] as Array[GoalPhase],
			},
			# solver min_moves at design time: 13
		},
		{
			"id": "test_bigger_gem",
			"name": "Bigger 5 — Gem",
			"sort": 250,
			"allow_empty": true,
			"rows": PackedStringArray([
				"....AB....",
				"...AABB...",
				"..CADEBB..",
				".CCDDEEFF.",
				"CCDDGGEEFF",
				"HHIIGGJJKK",
				".HHIIJJKK.",
				"..HLIJMM..",
				"...LLMM...",
				"....LM....",
			]),
			"colors": {"A": Block.TileColor.RED, "B": Block.TileColor.YELLOW, "C": Block.TileColor.YELLOW, "D": Block.TileColor.YELLOW, "E": Block.TileColor.BLUE, "F": Block.TileColor.YELLOW, "G": Block.TileColor.YELLOW, "H": Block.TileColor.YELLOW, "I": Block.TileColor.BLUE, "J": Block.TileColor.RED, "K": Block.TileColor.BLUE, "L": Block.TileColor.YELLOW, "M": Block.TileColor.RED},
			"enabled": {"left": true, "top": true, "right": true, "bottom": true},
			"phases": {
				"left": [_phase(Block.TileColor.GREEN, 1), _phase(Block.TileColor.YELLOW, 2)] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.ORANGE, 1), _phase(Block.TileColor.YELLOW, 1)] as Array[GoalPhase],
				"right": [_phase(Block.TileColor.GREEN, 1)] as Array[GoalPhase],
				"bottom": [_phase(Block.TileColor.ORANGE, 1), _phase(Block.TileColor.PURPLE, 1)] as Array[GoalPhase],
			},
			# solver min_moves at design time: 13
		},
		{
			"id": "test_bigger_spiral",
			"name": "Bigger 4 — Spiral",
			"sort": 240,
			"rows": PackedStringArray([
				"AAABBBBBCC",
				"AAABBBBBCC",
				"GGGHHHHICC",
				"GGGHHHHICC",
				"GGKKKKIICC",
				"GGKKKKIIDD",
				"FFKJJJIIDD",
				"FFKJJJJJDD",
				"FFFEEEEEDD",
				"FFFEEEEEDD",
			]),
			"colors": {"A": Block.TileColor.YELLOW, "B": Block.TileColor.RED, "C": Block.TileColor.RED, "D": Block.TileColor.RED, "E": Block.TileColor.RED, "F": Block.TileColor.RED, "G": Block.TileColor.RED, "H": Block.TileColor.BLUE, "I": Block.TileColor.YELLOW, "J": Block.TileColor.BLUE, "K": Block.TileColor.YELLOW},
			"enabled": {"left": false, "top": true, "right": false, "bottom": false},
			"phases": {
				"left": [] as Array[GoalPhase],
				"top": [_phase(Block.TileColor.PURPLE, 1), _phase(Block.TileColor.RED, 1), _phase(Block.TileColor.ORANGE, 3), _phase(Block.TileColor.PURPLE, 1)] as Array[GoalPhase],
				"right": [] as Array[GoalPhase],
				"bottom": [] as Array[GoalPhase],
			},
			# solver min_moves at design time: 11
		},
	]
