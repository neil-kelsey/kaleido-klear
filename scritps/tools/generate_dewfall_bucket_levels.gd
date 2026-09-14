extends SceneTree

## Dewfall Nebula — Computer generated 02–11 (wall-bucket wells).
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_dewfall_bucket_levels.gd

const SECTION_DEWFALL := 1
const GROUP_KEY := "UI_GROUP_COMPUTER_GENERATED"
const SOLVE_STATES := 800000

const LevelConfigScript := preload("res://scritps/LevelConfig.gd")
const GoalPhaseScript := preload("res://scritps/GoalPhase.gd")
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")

const C_RED := Block.TileColor.RED
const C_GREEN := Block.TileColor.GREEN
const C_BLUE := Block.TileColor.BLUE
const C_YELLOW := Block.TileColor.YELLOW
const C_PURPLE := Block.TileColor.PURPLE
const C_ORANGE := Block.TileColor.ORANGE
const KIND_STD := Block.BlockKind.STANDARD
const KIND_MERGE := Block.BlockKind.MERGE
const KIND_WALL := Block.BlockKind.WALL

const LETTERS := {
	"R": C_RED,
	"G": C_GREEN,
	"B": C_BLUE,
	"Y": C_YELLOW,
	"P": C_PURPLE,
	"O": C_ORANGE,
}


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Dewfall computer-generated buckets ===")
	var exit_code := 0
	for spec in _specs():
		lines.append("")
		lines.append("--- %s (%s) ---" % [spec.level_id, spec.display_name])
		var built: Dictionary = _make_level(spec)
		if not bool(built.get("ok", false)):
			lines.append("ERROR: %s" % built.get("reason", "build failed"))
			exit_code = 1
			continue
		var level: LevelConfig = built.level
		_print_board(level, lines)
		var result: Dictionary = LevelSolverScript.solve(level, SOLVE_STATES)
		lines.append(
			"solvable=%s min_moves=%s states=%s baits=%s"
			% [
				result.get("solvable", false),
				result.get("min_moves", -1),
				result.get("states_explored", 0),
				built.get("baits", 0),
			]
		)
		if not bool(result.get("solvable", false)):
			lines.append("ERROR: not solvable")
			exit_code = 1
			continue
		var rating: Dictionary = LevelDifficultyScript.rate(
			level, int(result.get("min_moves", -1))
		)
		level.verified_solvable = true
		level.min_moves = int(result.min_moves)
		level.difficulty_score = float(rating.score)
		level.difficulty_tier = int(rating.tier)
		var save_err := _save_project_level(level)
		if save_err != OK:
			lines.append("ERROR: save failed %s" % save_err)
			exit_code = 1
			continue
		lines.append(
			"Saved  min_moves=%s  tier=%s  score=%s"
			% [level.min_moves, level.difficulty_tier, level.difficulty_score]
		)
	_finish(lines, exit_code)


func _specs() -> Array:
	return [
		## Same 4-well comb as Dewfall 10, new colours. First R is on two
		## columns; only one continues G then R.
		_deal_spec(2, "Bucket baits", 320, 9, 12, 4, [
			"0R", "0G", "1R", "1R", "2O", "2O", "0O", "3G", "0G", "2G",
			"3P", "2P", "3P", "1B", "1Y", "0B", "0Y", "2B", "1O", "1P",
			"1G", "3B", "3Y", "3R", "2Y", "2R", "0P", "0B", "1B", "1Y",
			"3O", "3G", "2G", "2P", "0R", "0O", "1P", "2B", "3R", "3Y",
		]),
		## Same walls; some bars are two cells tall (still one score).
		_deal_spec(3, "Tall tiles", 330, 9, 12, 4, [
			"0R", "0G2", "1R", "1R", "2O2", "3O", "0B2", "3G", "1G2", "2P",
			"3P2", "0Y", "1B", "1Y", "2B", "3Y", "0P", "1O", "2Y", "3R",
		]),
		_deal_spec(4, "Two wells", 340, 5, 7, 2, [
			"0R", "0G", "1R", "0B", "1G", "1B", "0Y", "1Y", "0P", "1P",
		]),
		_deal_spec(5, "Three wells", 350, 7, 8, 3, [
			"0B", "0Y", "1B", "1B", "2R", "0R", "2R", "1Y", "0G", "2G",
			"1G", "1R", "2Y", "0B", "0Y",
		]),
		_deal_spec(6, "Short buckets", 360, 9, 8, 4, [
			"0O", "0G", "1O", "1O", "2G", "3G", "0P", "2P", "2R", "3P",
			"3R", "1G", "1B", "0B", "0Y", "2B", "3Y",
		]),
		_merge_spec(),
		_deal_spec(8, "Deep wells", 380, 9, 18, 4, [
			"0R", "0G", "1R", "1R", "2O", "2O", "0O", "3G", "0G", "2G",
			"3P", "2P", "3P", "1B", "1Y", "0B", "0Y", "2B", "1O", "1P",
			"1G", "3B", "3Y", "3R", "2Y", "2R", "0P", "0B", "1B", "1Y",
			"3O", "3G", "2G", "2P", "0R", "0O", "1P", "2B", "3R", "3Y",
			"0R", "1R", "2O", "3G", "0G", "1B", "2B", "3Y", "0Y", "1P",
			"2P", "3O", "0B", "1Y", "2R", "3B", "0O", "1O", "2Y", "3P",
		]),
		_deal_spec(9, "The spire", 390, 9, 20, 4, [
			"0Y", "0R", "1Y", "1Y", "2B", "3B", "3B", "0G", "2G", "3G",
			"1R", "1P", "2P", "0P", "0B", "0O", "1B", "1O", "2R", "2O",
			"3R", "3O", "3P", "3Y", "3G", "3B", "3R", "3O", "3P", "3Y",
			"3G", "3B",
		]),
		_mixed_spec(),
		_deal_spec(11, "Five wells", 410, 11, 12, 5, [
			"0P", "0O", "1P", "1P", "2O", "3O", "4O", "0G", "2G", "1G",
			"3G", "4G", "2B", "3B", "4B", "0B", "0Y", "1B", "1Y", "2Y",
			"3Y", "4Y", "0R", "1R", "2R", "3R", "4R",
		]),
	]


func _deal_spec(
	index: int,
	display_name: String,
	sort_index: int,
	cols: int,
	rows: int,
	lane_count: int,
	deal: Array
) -> Dictionary:
	var lanes: Array = []
	for i in lane_count:
		lanes.append(1 + i * 2)
	return {
		"level_id": "dewfall_computer_generated_%02d" % index,
		"display_name": display_name,
		"sort_index": sort_index,
		"columns": cols,
		"rows": rows,
		"lanes": lanes,
		"deal": deal,
		"merge": false,
	}


func _merge_spec() -> Dictionary:
	return {
		"level_id": "dewfall_computer_generated_07",
		"display_name": "Merge bluff",
		"sort_index": 370,
		"columns": 9,
		"rows": 12,
		"lanes": [1, 3, 5, 7],
		"stacks": ["RBYOG", "PGYBR", "RBOGY", "GOBYRP"],
		"kinds": ["MMSSS", "SSSSS", "MMSSS", "SSSSSS"],
		"merge": true,
		"phases": [
			[C_PURPLE, 2],
			[C_GREEN, 1],
			[C_YELLOW, 2],
			[C_ORANGE, 1],
			[C_GREEN, 1],
			[C_PURPLE, 1],
			[C_ORANGE, 1],
			[C_GREEN, 1],
			[C_YELLOW, 1],
			[C_GREEN, 1],
			[C_ORANGE, 1],
			[C_BLUE, 1],
			[C_YELLOW, 1],
			[C_RED, 1],
			[C_PURPLE, 1],
			[C_BLUE, 1],
			[C_RED, 1],
		],
	}


func _mixed_spec() -> Dictionary:
	return {
		"level_id": "dewfall_computer_generated_10",
		"display_name": "Mixed wells",
		"sort_index": 400,
		"columns": 7,
		"rows": 12,
		"lanes": [1, 3, 5],
		"stacks": ["R,B,G2,Y,O", "P,G,Y2,B,R", "R,B,O2,G,Y"],
		"kinds": ["MMSSS", "SSSSS", "MMSSS"],
		"merge": true,
		"phases": [
			[C_PURPLE, 2],
			[C_GREEN, 1],
			[C_YELLOW, 1],
			[C_GREEN, 1],
			[C_YELLOW, 1],
			[C_ORANGE, 1],
			[C_PURPLE, 1],
			[C_ORANGE, 1],
			[C_GREEN, 1],
			[C_YELLOW, 1],
			[C_BLUE, 1],
			[C_RED, 1],
		],
	}


func _make_level(spec: Dictionary) -> Dictionary:
	var cols: int = int(spec.columns)
	var rows: int = int(spec.rows)
	var lanes: Array = spec.lanes
	var pieces: Array = [_comb_wall(cols, rows, lanes)]
	var lane_items: Array = []
	for _i in lanes.size():
		lane_items.append([])
	var phases: Array[GoalPhase] = []
	var bait_n := 0
	if spec.has("deal"):
		var built: Dictionary = _items_from_deal(spec.deal, lanes.size())
		if not bool(built.get("ok", false)):
			return {"ok": false, "reason": built.get("reason", "bad deal")}
		lane_items = built.items
		for phase in built.phases:
			phases.append(phase)
		bait_n = int(built.baits)
	else:
		var stacks: Array = spec.get("stacks", [])
		if stacks.size() != lanes.size():
			return {"ok": false, "reason": "lane/stack mismatch"}
		var kinds: Array = spec.get("kinds", [])
		for i in lanes.size():
			lane_items[i] = _parse_stack(str(stacks[i]), str(kinds[i]) if i < kinds.size() else "")
		if spec.has("phases"):
			for pair in spec.phases:
				phases.append(_phase(pair[0] as Block.TileColor, int(pair[1])))
		bait_n = _count_opening_baits(stacks)
	if phases.is_empty():
		return {"ok": false, "reason": "no phases"}
	for i in lanes.size():
		var packed: Dictionary = _place_stack(int(lanes[i]), rows, lane_items[i])
		if not bool(packed.get("ok", false)):
			return {"ok": false, "reason": packed.get("reason", "stack overflow")}
		for piece in packed.pieces:
			pieces.append(piece)
	var level: LevelConfig = LevelConfigScript.new()
	level.level_id = str(spec.level_id)
	level.display_name = str(spec.display_name)
	level.level_name_key = ""
	level.section_index = SECTION_DEWFALL
	level.sort_index = int(spec.sort_index)
	level.group_title_key = GROUP_KEY
	level.columns = cols
	level.rows = rows
	level.disabled_cells = []
	level.multi_goal_mode = true
	level.goal_left_enabled = false
	level.goal_top_enabled = true
	level.goal_right_enabled = false
	level.goal_bottom_enabled = false
	level.goal_left_color = C_PURPLE
	level.goal_top_color = phases[0].color
	level.goal_right_color = C_ORANGE
	level.goal_bottom_color = C_YELLOW
	level.goal_left_phases = []
	level.goal_top_phases = phases
	level.goal_right_phases = []
	level.goal_bottom_phases = []
	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []
	var occupied: Dictionary = {}
	for piece in pieces:
		var cells: Array[Vector2i] = []
		for cell in piece.cells:
			var v := cell as Vector2i
			if occupied.has(v):
				return {"ok": false, "reason": "overlap at %s" % v}
			occupied[v] = true
			cells.append(v)
		var packed_cells: Dictionary = LevelGenRulesScript.pack_cells(cells)
		level.block_positions.append(packed_cells.anchor)
		level.block_colors.append(piece.color as Block.TileColor)
		level.block_shapes.append(str(piece.get("shape", BlockShapes.SINGLE)))
		level.block_kinds.append(piece.kind as Block.BlockKind)
		level.block_cell_patterns.append(packed_cells.offsets)
		level.block_shape_names.append(str(piece.name))
	var bait_out := bait_n
	return {"ok": true, "level": level, "baits": bait_out}


func _items_from_deal(deal: Array, lane_count: int) -> Dictionary:
	var items: Array = []
	for _i in lane_count:
		items.append([])
	var seq: Array[int] = []
	var baits := 0
	for token in deal:
		var parsed: Dictionary = _parse_deal_token(str(token), lane_count)
		if not bool(parsed.get("ok", false)):
			return {"ok": false, "reason": parsed.get("reason", "bad token")}
		var lane: int = int(parsed.lane)
		items[lane].append({"c": parsed.c, "h": parsed.h, "k": KIND_STD})
		seq.append(int(parsed.c))
	var replay: Array = []
	for i in lane_count:
		replay.append((items[i] as Array).duplicate())
	for token in deal:
		var parsed: Dictionary = _parse_deal_token(str(token), lane_count)
		var need: int = int(parsed.c)
		var match_n := 0
		for i in lane_count:
			var stack: Array = replay[i]
			if stack.is_empty():
				continue
			if int(stack[0].c) == need:
				match_n += 1
		if match_n >= 2:
			baits += 1
		(replay[int(parsed.lane)] as Array).pop_front()
	var phases: Array[GoalPhase] = []
	for c in seq:
		if phases.is_empty() or int(phases[phases.size() - 1].color) != c:
			phases.append(_phase(c as Block.TileColor, 1))
		else:
			phases[phases.size() - 1].count += 1
	return {"ok": true, "items": items, "phases": phases, "baits": baits}


func _parse_deal_token(token: String, lane_count: int) -> Dictionary:
	if token.length() < 2:
		return {"ok": false, "reason": "short token %s" % token}
	var lane := int(token.substr(0, 1))
	if lane < 0 or lane >= lane_count:
		return {"ok": false, "reason": "lane %s" % token}
	var letter := token.substr(1, 1).to_upper()
	if not LETTERS.has(letter):
		return {"ok": false, "reason": "colour %s" % token}
	var height := 1
	if token.length() > 2:
		height = maxi(int(token.substr(2)), 1)
	return {
		"ok": true,
		"lane": lane,
		"c": LETTERS[letter],
		"h": height,
	}


func _parse_stack(token: String, kinds: String) -> Array:
	var items: Array = []
	if token.contains(","):
		for part in token.split(","):
			items.append(_parse_item(str(part).strip_edges()))
	else:
		for i in token.length():
			items.append(_parse_item(token.substr(i, 1)))
	for i in items.size():
		if i < kinds.length() and kinds.substr(i, 1) == "M":
			items[i].k = KIND_MERGE
	return items


func _parse_item(part: String) -> Dictionary:
	if part.is_empty():
		return {"c": C_RED, "h": 1, "k": KIND_STD}
	var letter := part.substr(0, 1).to_upper()
	var color: Block.TileColor = LETTERS.get(letter, C_RED) as Block.TileColor
	var height := 1
	if part.length() > 1:
		height = maxi(int(part.substr(1)), 1)
	return {"c": color, "h": height, "k": KIND_STD}


func _place_stack(lane_x: int, rows: int, items: Array) -> Dictionary:
	var total := 0
	for it in items:
		total += int(it.h)
	var y := rows - 1 - total
	if y < 0:
		return {"ok": false, "reason": "stack taller than well"}
	var pieces: Array = []
	for i in items.size():
		var h: int = int(items[i].h)
		var cells: Array[Vector2i] = []
		for n in h:
			cells.append(Vector2i(lane_x, y + n))
		pieces.append({
			"name": "L%s %s" % [lane_x, i],
			"color": items[i].c,
			"kind": items[i].k,
			"cells": cells,
			"shape": BlockShapes.SINGLE if h == 1 else BlockShapes.LINE_2,
		})
		y += h
	return {"ok": true, "pieces": pieces}


func _comb_wall(cols: int, rows: int, lanes: Array) -> Dictionary:
	var lane_set: Dictionary = {}
	for x in lanes:
		lane_set[int(x)] = true
	var cells: Array[Vector2i] = []
	for x in cols:
		if lane_set.has(x):
			cells.append(Vector2i(x, rows - 1))
			continue
		for y in rows:
			cells.append(Vector2i(x, y))
	return {
		"name": "Well walls",
		"color": C_RED,
		"kind": KIND_WALL,
		"cells": cells,
		"shape": BlockShapes.SINGLE,
	}


func _phase(color: Block.TileColor, count: int) -> GoalPhase:
	var phase: GoalPhase = GoalPhaseScript.new()
	phase.color = color
	phase.count = count
	phase.unlimited = false
	return phase


func _count_opening_baits(stacks: Array) -> int:
	var tops: Dictionary = {}
	for token in stacks:
		var items: Array = _parse_stack(str(token), "")
		if items.is_empty():
			continue
		var c: int = int(items[0].c)
		tops[c] = int(tops.get(c, 0)) + 1
	var n := 0
	for c in tops:
		if int(tops[c]) >= 2:
			n += int(tops[c])
	return n


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
		var kind := (
			int(level.block_kinds[i]) if i < level.block_kinds.size() else 0
		)
		var ch := "#"
		if kind != int(KIND_WALL):
			ch = str(letters.get(int(level.block_colors[i]), "?"))
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
