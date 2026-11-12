extends SceneTree

## Meadow Charms: 40 picture levels in Ion Meadows (section 3), 39 Medium / 1 Hard (pitched at the medium/hard boundary)
## (Easy, Medium, Hard, Very Hard). Layouts, colours, goals and one recorded
## winning line live in meadow_charms_levels.json. They came from a
## solver-guided search over hand-drawn silhouettes (animals, plants, vehicles and everyday
## objects, none reused from earlier subsections). This script turns them into level resources and refuses any level
## whose recorded line does not win in PuzzleSim with all 3 lives.
## Run:
##   godot --headless --path . -s res://scritps/tools/generate_tidepool_glyphs_levels.gd

const DATA_PATH := "res://scritps/tools/meadow_charms_levels.json"
const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const DIRS := {"UP": Vector2i.UP, "DOWN": Vector2i.DOWN, "LEFT": Vector2i.LEFT, "RIGHT": Vector2i.RIGHT}


static func load_data() -> Dictionary:
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


static func build_level(spec: Dictionary, data: Dictionary) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = str(spec.level_id)
	level.display_name = str(spec.name)
	level.locale_display_names = {"en": str(spec.name), "fr": str(spec.fr), "pirate": str(spec.name)}
	level.section_index = int(data.section_index)
	level.sort_index = int(spec.sort_index)
	level.group_title_key = str(data.group_title_key)
	level.columns = int(spec.columns)
	level.rows = int(spec.rows)
	level.multi_goal_mode = true
	var edges: Array = [[], [], [], []]
	for e in 4:
		var phases: Array[GoalPhase] = []
		for ph in spec.phases[e]:
			var gp := GoalPhase.new()
			gp.color = int(ph[0]) as Block.TileColor
			gp.count = int(ph[1])
			phases.append(gp)
		edges[e] = phases
	level.goal_left_phases = edges[0]
	level.goal_top_phases = edges[1]
	level.goal_right_phases = edges[2]
	level.goal_bottom_phases = edges[3]
	level.goal_left_enabled = not edges[0].is_empty()
	level.goal_top_enabled = not edges[1].is_empty()
	level.goal_right_enabled = not edges[2].is_empty()
	level.goal_bottom_enabled = not edges[3].is_empty()
	var n := 0
	for p in spec.pieces:
		var cells: Array[Vector2i] = []
		for c in p.cells:
			cells.append(Vector2i(int(c[0]), int(c[1])))
		var anchor := cells[0]
		for c in cells:
			anchor.x = mini(anchor.x, c.x)
			anchor.y = mini(anchor.y, c.y)
		var offsets: Array[Vector2i] = []
		for c in cells:
			offsets.append(c - anchor)
		n += 1
		level.block_positions.append(anchor)
		level.block_colors.append(int(p.color) as Block.TileColor)
		level.block_kinds.append(int(p.kind) as Block.BlockKind)
		level.block_shapes.append("single")
		level.block_cell_patterns.append(offsets)
		level.block_shape_names.append("Shape %d" % n)
	return level


static func solution(spec: Dictionary) -> Array:
	var out: Array = []
	for s in spec.solution:
		out.append([int(s[0]), DIRS[str(s[1])]])
	return out


## Replays the recorded line in PuzzleSim. Returns "" when it wins with 3 lives.
static func replay_sim(level: LevelConfig, steps: Array) -> String:
	var sim = PuzzleSimScript.new()
	var state = sim.load_config(level)
	var n := 0
	for s in steps:
		n += 1
		var r: Dictionary = sim.apply_move(state, int(s[0]), s[1] as Vector2i)
		var o := int(r.outcome)
		if not bool(r.ok) or not (o == PuzzleSimScript.Outcome.SCORE or o == PuzzleSimScript.Outcome.MERGE):
			return "step %d not accepted (outcome %d)" % [n, o]
		state = r.state
	if not state.is_won():
		return "line ends with %d pieces left" % state.clearable_count()
	if state.lives != 3:
		return "lost a life"
	return ""


func _initialize() -> void:
	var data := load_data()
	var failed := 0
	var paths: Array[String] = []
	for spec in data.levels:
		var level := build_level(spec, data)
		var steps := solution(spec)
		var err := replay_sim(level, steps)
		if err != "":
			failed += 1
			printerr("FAIL %s %s: %s" % [spec.level_id, spec.name, err])
			continue
		var clearable := 0
		for k in level.block_kinds:
			if int(k) != int(Block.BlockKind.WALL):
				clearable += 1
		level.verified_solvable = true
		## Every accepted move removes exactly one piece (a mix joins two, an exit
		## removes one), so every win takes exactly `clearable` moves.
		level.min_moves = clearable
		level.difficulty_tier = int(spec.tier)
		level.difficulty_score = float(LevelDifficultyScript.rate(level, clearable).score)
		var path := "res://resources/levels/%s.tres" % level.level_id
		var save_err := ResourceSaver.save(level, path)
		if save_err != OK:
			failed += 1
			printerr("FAIL save %s err=%d" % [path, save_err])
			continue
		paths.append(path)
		print("OK %s tier=%d %s moves=%d" % [spec.level_id, int(spec.tier), spec.name, steps.size()])
	_add_to_registry(paths)
	print("meadow charms generate: %d saved, %d failed" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _add_to_registry(paths: Array[String]) -> void:
	var reg_path := "res://scritps/LevelRegistry.gd"
	var text := FileAccess.get_file_as_string(reg_path)
	var start := text.find("const LEVEL_PATHS: PackedStringArray = [")
	var end := text.find("]", start)
	var body := text.substr(start, end - start)
	var existing: Array[String] = []
	for line in body.split("\n"):
		var t := line.strip_edges().trim_suffix(",")
		if t.begins_with("\"res://"):
			existing.append(t.trim_prefix("\"").trim_suffix("\""))
	for p in paths:
		if not existing.has(p):
			existing.append(p)
	existing.sort()
	var lines: PackedStringArray = []
	for p in existing:
		lines.append("\t\"%s\"" % p)
	var new_body := "const LEVEL_PATHS: PackedStringArray = [\n" + ",\n".join(lines) + "\n"
	var f := FileAccess.open(reg_path, FileAccess.WRITE)
	f.store_string(text.substr(0, start) + new_body + text.substr(end))
	f.close()
