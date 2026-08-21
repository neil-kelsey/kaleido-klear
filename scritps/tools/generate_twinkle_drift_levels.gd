extends SceneTree

## Build Dimension 1 (Twinkle Drift): 5 chapters × 30 solver-verified levels.
## Reverse-fills polyominoes from goal edges so every accepted board is
## constructively solvable, then confirms with LevelSolver.
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_twinkle_drift_levels.gd
## Optional: TWINKLE_LIMIT=N generates N levels per chapter (debug).

const SECTION_DIM1 := 0
const MIN_CELLS := 3
const ATTEMPTS_PER_LEVEL := 80
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")

const _GROUP_PEBBLE := "UI_GROUP_PEBBLE_ORBITS"
const _GROUP_MOONLACE := "UI_GROUP_MOONLACE_WALLS"
const _GROUP_SOLAR := "UI_GROUP_SOLAR_STACK"
const _GROUP_PAINT := "UI_GROUP_PAINT_NOVA"
const _GROUP_RIFT := "UI_GROUP_RIFT_GEOMETRY"

const DIRS: Array[Vector2i] = [
	Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN
]
const EDGE_LEFT := 0
const EDGE_TOP := 1
const EDGE_RIGHT := 2
const EDGE_BOTTOM := 3

const C_RED := 0
const C_GREEN := 1
const C_BLUE := 2
const C_YELLOW := 3
const C_PURPLE := 4
const C_ORANGE := 5


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Twinkle Drift generate / verify ===")
	var exit_code := 0

	if not _assert_merge_once(lines):
		_finish(lines, 1)
		return

	_clear_previous_twinkle()
	var seen: Dictionary = {}
	var limit := int(OS.get_environment("TWINKLE_LIMIT"))
	var only_chapter := int(OS.get_environment("TWINKLE_CHAPTER"))
	var skip_existing := int(OS.get_environment("TWINKLE_SKIP_EXISTING")) == 1
	var per_chapter := 30 if limit <= 0 else mini(limit, 30)
	var saved_count := 0
	var expected := 0

	for chapter in _chapters():
		if only_chapter > 0 and int(chapter.chapter) != only_chapter:
			continue
		expected += per_chapter
		for index in per_chapter:
			var spec: Dictionary = _slot_spec(chapter, index)
			lines.append("")
			lines.append("--- %s ---" % spec.level_id)
			if skip_existing and ResourceLoader.exists("res://resources/levels/%s.tres" % spec.level_id):
				saved_count += 1
				lines.append("skip existing")
				continue
			var built: Dictionary = _build_verified(spec, seen)
			if not bool(built.get("ok", false)):
				lines.append("ERROR: %s" % built.get("reason", "failed"))
				exit_code = 1
				continue
			var level: LevelConfig = built.level
			var save_err := _save_project_level(level)
			if save_err != OK:
				lines.append("ERROR: save failed %s" % save_err)
				exit_code = 1
				continue
			saved_count += 1
			lines.append(
				"ok size=%dx%d pieces=%d moves=%d score=%s tier=%d bait=%s attempts=%d"
				% [
					level.columns,
					level.rows,
					level.block_positions.size(),
					level.min_moves,
					level.difficulty_score,
					level.difficulty_tier,
					built.get("bait", false),
					built.get("attempts", 0),
				]
			)

	var rewrite := _rewrite_registry_fallback("")
	if rewrite != OK:
		lines.append("ERROR: registry rewrite %s" % rewrite)
		exit_code = 1

	exit_code = maxi(exit_code, _audit(lines, expected))
	lines.append("")
	lines.append("Saved %d Twinkle Drift levels." % saved_count)
	_finish(lines, exit_code)


func _chapters() -> Array:
	return [
		{
			"chapter": 1,
			"group": _GROUP_PEBBLE,
			"prefix": "twinkle_pebbles",
			"title": "Pebble Orbits",
			"sort0": 100,
		},
		{
			"chapter": 2,
			"group": _GROUP_MOONLACE,
			"prefix": "twinkle_moonlace",
			"title": "Moonlace Walls",
			"sort0": 200,
		},
		{
			"chapter": 3,
			"group": _GROUP_SOLAR,
			"prefix": "twinkle_solar",
			"title": "Solar Stack",
			"sort0": 300,
		},
		{
			"chapter": 4,
			"group": _GROUP_PAINT,
			"prefix": "twinkle_paint",
			"title": "Paint Nova",
			"sort0": 400,
		},
		{
			"chapter": 5,
			"group": _GROUP_RIFT,
			"prefix": "twinkle_rift",
			"title": "Rift Geometry",
			"sort0": 500,
		},
	]


func _slot_spec(chapter: Dictionary, index: int) -> Dictionary:
	var n := index + 1
	var spec := {
		"chapter": int(chapter.chapter),
		"index": index,
		"level_id": "%s_%02d" % [chapter.prefix, n],
		"display_name": "%s %02d" % [chapter.title, n],
		"group": chapter.group,
		"sort_index": int(chapter.sort0) + index,
		"want_bait": false,
		"allow_holes": false,
		"columns": 8,
		"rows": 8,
	}
	match int(chapter.chapter):
		1:
			spec.columns = 8
			spec.rows = 8
			spec.color_count = 2 if index < 8 else (3 if index < 20 else 4)
			spec.want_bait = index in [6, 11, 16, 21, 24, 26, 27, 28, 29] or index == 4
			spec.allow_holes = true
		2:
			spec.allow_holes = true
			spec.want_bait = index >= 24 or index in [8, 14, 19]
			if index >= 25:
				spec.columns = 10
				spec.rows = 10
			elif index >= 20:
				spec.columns = 10
				spec.rows = 8
			else:
				spec.columns = 8
				spec.rows = 8
			spec.color_count = 2 if index < 10 else 3
			spec.wall_count = 1 if index < 12 else (2 if index < 22 else 2)
			spec.shifting = index >= 10
		3:
			spec.allow_holes = false
			spec.want_bait = index >= 22 or index in [9, 15]
			spec.columns = 8 if index < 16 else 10
			spec.rows = spec.columns
			spec.stack_edge = EDGE_TOP if index % 5 != 4 else (EDGE_LEFT if index % 2 == 0 else EDGE_RIGHT)
			spec.phase_count = 2 if index < 10 else 3
			spec.overflow = index in [7, 13, 18, 23, 28]
			spec.quota_one = index >= 8
		4:
			spec.allow_holes = true
			spec.want_bait = index >= 6
			spec.columns = 8 if index < 18 else 10
			spec.rows = spec.columns
			spec.palette = index % 3
			spec.wall_count = 1 if index >= 22 else 0
		5:
			spec.allow_holes = true
			spec.want_bait = index >= 20 or index in [7, 13]
			if index >= 22:
				spec.columns = 12
				spec.rows = 12
			else:
				spec.columns = 10
				spec.rows = 10
			spec.silhouette = index % 6
			if index >= 22:
				## 12×12 closers: keep edge-open silhouettes (frame / plus / islands).
				spec.silhouette = index % 3
			spec.combo_wall = index >= 12 and index < 22
			spec.combo_stack = false
			spec.combo_merge = index >= 18 and index < 22
	return spec


func _build_verified(spec: Dictionary, seen: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	var base_seed := int(spec.level_id.hash()) & 0x7fffffff
	var last_reason := ""
	var reasons: Dictionary = {}
	var attempts := ATTEMPTS_PER_LEVEL
	if int(spec.chapter) >= 3:
		attempts = 140
	if int(spec.chapter) == 5:
		attempts = 90
	for attempt in attempts:
		rng.seed = base_seed + attempt * 7919 + int(spec.index) * 13
		var raw: Dictionary = _build_attempt(spec, rng)
		if not bool(raw.get("ok", false)):
			last_reason = str(raw.get("reason", "build"))
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		var level: LevelConfig = raw.level
		var rules: Dictionary = LevelGenRulesScript.validate(level)
		if not bool(rules.get("ok", false)):
			last_reason = "rules"
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		var cell_err := _min_cell_error(level)
		if not cell_err.is_empty():
			last_reason = cell_err
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		if not _dense_enough(level, spec):
			last_reason = "sparse"
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		var fp := _fingerprint(level)
		if seen.has(fp) or _near_duplicate(level, seen):
			last_reason = "dup"
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		if not _opening_progress(level):
			last_reason = "no-open"
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		var max_states := 120000
		if level.columns >= 10:
			max_states = 220000
		if level.columns >= 12:
			max_states = 320000
		var result: Dictionary = LevelSolverScript.solve(level, max_states)
		if not bool(result.get("solvable", false)):
			last_reason = "unsolvable:%s" % result.get("states_explored", 0)
			reasons[last_reason] = int(reasons.get(last_reason, 0)) + 1
			continue
		if spec.want_bait and not bool(raw.get("bait", false)):
			var discovered: Dictionary = _discover_bait(level)
			raw.bait = bool(discovered.get("traps", false))
		var rating: Dictionary = LevelDifficultyScript.rate(
			level, int(result.get("min_moves", -1))
		)
		_apply_rating(level, rating, spec)
		level.verified_solvable = true
		level.min_moves = int(result.min_moves)
		seen[fp] = true
		seen["near:" + _near_key(level)] = true
		return {
			"ok": true,
			"level": level,
			"bait": raw.get("bait", false),
			"attempts": attempt + 1,
		}
	return {
		"ok": false,
		"reason": "no unique solvable board after %d attempts (%s)" % [attempts, reasons],
	}


func _build_attempt(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	match int(spec.chapter):
		1:
			if spec.want_bait and rng.randf() < 0.45:
				var baited: Dictionary = _build_bait_pack(spec, rng, false, false, "")
				if bool(baited.get("ok", false)):
					return baited
			return _build_pebble(spec, rng)
		2:
			if spec.want_bait and rng.randf() < 0.45:
				var wall_bait: Dictionary = _build_bait_pack(
					spec, rng, true, bool(spec.get("shifting", false)), "wall"
				)
				if bool(wall_bait.get("ok", false)):
					return wall_bait
			return _build_moonlace(spec, rng)
		3:
			if spec.want_bait and rng.randf() < 0.55:
				var solar_bait: Dictionary = _build_solar_bait(spec, rng)
				if bool(solar_bait.get("ok", false)):
					return solar_bait
			return _build_solar(spec, rng)
		4:
			return _build_paint(spec, rng)
		5:
			return _build_rift(spec, rng)
		_:
			return {"ok": false}


func _build_pebble(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var n_colors: int = int(spec.color_count)
	var palette: Array = _pick_palette(n_colors, rng)
	var edges: Array = [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT]
	if n_colors >= 3:
		edges.append(EDGE_BOTTOM)
	_shuffle(edges, rng)
	var edge_colors: Dictionary = {}
	for i in edges.size():
		edge_colors[edges[i]] = palette[i % palette.size()]
	var filled: Dictionary = _reverse_fill(
		cols, rows, {}, [], edges, edge_colors, rng, bool(spec.allow_holes)
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false, "reason": "fill"}
	var goals := _unlimited_goals(edge_colors, edges)
	if n_colors >= 3 and (rng.randf() < 0.35 or spec.want_bait):
		goals = _counted_goals_from_pieces(filled.pieces, edge_colors, edges)
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), filled.pieces, goals
	)
	return {"ok": true, "level": level, "bait": false}


func _build_moonlace(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var disabled: Dictionary = _moonlace_holes(cols, rows, spec.index, rng)
	var walls: Array = _make_walls(cols, rows, disabled, int(spec.get("wall_count", 1)), rng)
	var n_colors: int = int(spec.color_count)
	var palette: Array = _pick_palette(n_colors, rng)
	var edges: Array = [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM]
	_shuffle(edges, rng)
	edges = edges.slice(0, maxi(3, n_colors))
	var edge_colors: Dictionary = {}
	for i in edges.size():
		edge_colors[edges[i]] = palette[i % palette.size()]
	var filled: Dictionary = _reverse_fill(
		cols, rows, disabled, walls, edges, edge_colors, rng, false
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false}
	var pieces: Array = walls + filled.pieces
	var goals: Dictionary
	if bool(spec.get("shifting", false)):
		goals = _counted_goals_from_pieces(filled.pieces, edge_colors, edges)
	else:
		goals = _unlimited_goals(edge_colors, edges)
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), pieces, goals
	)
	return {"ok": true, "level": level, "bait": false}


func _build_solar(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var stack: int = int(spec.stack_edge)
	var n_phases: int = int(spec.phase_count)
	var palette: Array = _pick_palette(maxi(n_phases, 2), rng)
	var edges: Array = [stack]
	var dummy_color: Dictionary = {stack: palette[0]}
	var filled: Dictionary = _reverse_fill(
		cols, rows, {}, [], edges, dummy_color, rng, false
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false}
	var pieces: Array = filled.pieces
	if pieces.size() < 6:
		return {"ok": false, "reason": "few-pieces"}
	var peeled: Dictionary = _color_by_peel(
		pieces, filled.get("disabled", []), stack, cols, rows, palette, n_phases
	)
	if not bool(peeled.get("ok", false)):
		return {"ok": false, "reason": "peel"}
	var counts: Dictionary = _count_colors(pieces)
	var phases: Array[GoalPhase] = []
	for col in peeled.order:
		var n: int = int(counts.get(col, 0))
		if n <= 0:
			continue
		phases.append(_phase(col as Block.TileColor, n))
	if phases.is_empty():
		return {"ok": false, "reason": "no-phases"}
	var multi := phases.size() >= 2
	if not multi:
		phases = [_phase(int(peeled.order[0]) as Block.TileColor, 1, true)]
	var enabled := {0: false, 1: false, 2: false, 3: false}
	enabled[stack] = true
	var colors := {0: C_RED, 1: C_BLUE, 2: C_GREEN, 3: C_YELLOW}
	colors[stack] = int(peeled.order[0])
	var phase_map := {
		0: [] as Array[GoalPhase],
		1: [] as Array[GoalPhase],
		2: [] as Array[GoalPhase],
		3: [] as Array[GoalPhase],
	}
	phase_map[stack] = phases
	if bool(spec.get("overflow", false)) and multi:
		## Optional shortcut, never required: unlimited first-colour overflow.
		var overflow: int = _other_edge(stack, rng)
		enabled[overflow] = true
		colors[overflow] = int(peeled.order[0])
		phase_map[overflow] = [_phase(int(peeled.order[0]) as Block.TileColor, 1, true)]
	var goals := {
		"enabled": enabled,
		"colors": colors,
		"multi": multi,
		"phases": phase_map,
	}
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), pieces, goals
	)
	return {"ok": true, "level": level, "bait": false}


func _build_solar_bait(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	## Flush matching colour on the stack edge is phase 2; taking it first bricks the stack.
	var cols: int = spec.columns
	var rows: int = spec.rows
	var stack: int = int(spec.get("stack_edge", EDGE_TOP))
	var palette: Array = _pick_palette(3, rng)
	var a: int = palette[0]
	var c: int = palette[1]
	var bait_edge: int = _other_edge(stack, rng)
	return _build_bait_core(spec, rng, cols, rows, {}, [], bait_edge, stack, a, c, true)


func _build_paint(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var pal: int = int(spec.palette)
	var pair: Array = _mix_pair(pal)
	var primary_a: int = pair[0]
	var primary_b: int = pair[1]
	var mix: int = pair[2]
	var mix_edge: int = [EDGE_RIGHT, EDGE_TOP, EDGE_LEFT][spec.index % 3]
	var bait_edge: int = _other_edge(mix_edge, rng)
	## Keep bait on an adjacent edge so a mixer can sit in the corner.
	if bait_edge == _opposite_edge(mix_edge):
		bait_edge = _perp_edge(mix_edge, rng)
	var disabled: Dictionary = {}
	var walls: Array = []
	if int(spec.get("wall_count", 0)) > 0:
		walls = _make_walls(cols, rows, disabled, 1, rng)
	var mixers: Array = _place_mix_pair(
		cols, rows, disabled, walls, primary_a, primary_b, mix_edge, bait_edge, rng
	)
	if mixers.is_empty():
		return {"ok": false}
	var fill_edges: Array = []
	var edge_colors: Dictionary = {}
	for edge in [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM]:
		if edge == mix_edge:
			continue
		fill_edges.append(edge)
	edge_colors[fill_edges[0]] = primary_b
	if fill_edges.size() >= 2:
		edge_colors[fill_edges[1]] = primary_a
	if fill_edges.size() >= 3:
		edge_colors[fill_edges[2]] = primary_b if spec.index % 2 == 0 else primary_a
	var pre: Array = walls + mixers
	var filled: Dictionary = _reverse_fill(
		cols, rows, disabled, pre, fill_edges, edge_colors, rng, false
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false}
	var extra: Array = []
	for p in filled.pieces:
		p.kind = int(Block.BlockKind.STANDARD)
		extra.append(p)
	var has_std_a := false
	var has_std_b := false
	for p in extra:
		if int(p.color) == primary_a:
			has_std_a = true
		if int(p.color) == primary_b:
			has_std_b = true
	if not has_std_a or not has_std_b:
		for p in extra:
			if not has_std_a:
				p.color = primary_a
				has_std_a = true
			elif not has_std_b and int(p.color) != primary_a:
				p.color = primary_b
				has_std_b = true
	if not has_std_a or not has_std_b:
		return {"ok": false}
	var pieces: Array = walls + mixers + extra
	var enabled := {0: false, 1: false, 2: false, 3: false}
	enabled[mix_edge] = true
	enabled[bait_edge] = true
	var b_edge: int = fill_edges[0]
	if b_edge == bait_edge:
		b_edge = fill_edges[1] if fill_edges.size() >= 2 else _other_edge(bait_edge, rng)
	enabled[b_edge] = true
	var colors := {0: C_RED, 1: C_BLUE, 2: C_GREEN, 3: C_YELLOW}
	colors[mix_edge] = mix
	colors[bait_edge] = primary_a
	colors[b_edge] = primary_b
	var std_counts := _count_colors(extra)
	var a_count: int = int(std_counts.get(primary_a, 0))
	var b_count: int = int(std_counts.get(primary_b, 0))
	var phase_map := {
		0: [] as Array[GoalPhase],
		1: [] as Array[GoalPhase],
		2: [] as Array[GoalPhase],
		3: [] as Array[GoalPhase],
	}
	var use_multi: bool = bool(spec.want_bait) or int(spec.index) >= 4
	if use_multi:
		phase_map[mix_edge] = [_phase(mix as Block.TileColor, 1)] as Array[GoalPhase]
		phase_map[bait_edge] = [_phase(primary_a as Block.TileColor, maxi(a_count, 1))] as Array[GoalPhase]
		phase_map[b_edge] = [_phase(primary_b as Block.TileColor, maxi(b_count, 1))] as Array[GoalPhase]
	var goals := {
		"enabled": enabled,
		"colors": colors,
		"multi": use_multi,
		"phases": phase_map,
	}
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), pieces, goals
	)
	return {"ok": true, "level": level, "bait": bool(spec.want_bait)}


func _build_rift(spec: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var disabled: Dictionary = _silhouette(cols, rows, int(spec.silhouette), rng)
	## Disc/ring used to need carved apertures; corner-cut and frame
	## silhouettes already touch the edges.
	var walls: Array = []
	if bool(spec.get("combo_wall", false)):
		walls = _make_walls(cols, rows, disabled, 1, rng)
	if spec.want_bait and cols < 12:
		var pack: Dictionary = _build_bait_core(
			spec, rng, cols, rows, disabled, walls, EDGE_LEFT, EDGE_TOP, C_RED, C_BLUE, true
		)
		if bool(pack.get("ok", false)):
			return pack
	var palette: Array = _pick_palette(3 if spec.index < 18 else 4, rng)
	var edges: Array = [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM]
	var edge_colors: Dictionary = {}
	for i in edges.size():
		edge_colors[edges[i]] = palette[i % palette.size()]
	var mixers: Array = []
	if bool(spec.get("combo_merge", false)) and spec.index >= 18:
		var pair: Array = _mix_pair(spec.index % 3)
		mixers = _place_mix_pair(
			cols, rows, disabled, walls, pair[0], pair[1], EDGE_RIGHT, EDGE_LEFT, rng
		)
		if not mixers.is_empty():
			edge_colors[EDGE_RIGHT] = pair[2]
			edge_colors[EDGE_LEFT] = pair[0]
			edge_colors[EDGE_TOP] = pair[1]
	var pre: Array = walls + mixers
	var filled: Dictionary = _reverse_fill(
		cols, rows, disabled, pre, edges, edge_colors, rng, false
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false}
	var pieces: Array = walls + mixers + filled.pieces
	var goals: Dictionary
	if mixers.is_empty() or spec.columns >= 12:
		goals = _unlimited_goals(edge_colors, edges)
	else:
		goals = _counted_goals_from_pieces(filled.pieces, edge_colors, edges)
		var mix_col: int = int(edge_colors[EDGE_RIGHT])
		var phases: Dictionary = goals.phases
		phases[EDGE_RIGHT] = [_phase(mix_col as Block.TileColor, 1)] as Array[GoalPhase]
		goals.phases = phases
		goals.multi = true
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), pieces, goals
	)
	return {"ok": true, "level": level, "bait": false}


func _build_bait_pack(
	spec: Dictionary,
	rng: RandomNumberGenerator,
	allow_holes: bool,
	shifting: bool,
	_mode: String
) -> Dictionary:
	var cols: int = spec.columns
	var rows: int = spec.rows
	var disabled: Dictionary = {}
	var walls: Array = []
	if int(spec.chapter) == 2:
		disabled = _moonlace_holes(cols, rows, spec.index, rng)
		walls = _make_walls(cols, rows, disabled, int(spec.get("wall_count", 1)), rng)
	var palette: Array = _pick_palette(3, rng)
	return _build_bait_core(
		spec, rng, cols, rows, disabled, walls, EDGE_LEFT, EDGE_TOP, palette[0], palette[1], allow_holes
	)


func _build_bait_core(
	spec: Dictionary,
	rng: RandomNumberGenerator,
	cols: int,
	rows: int,
	disabled: Dictionary,
	walls: Array,
	bait_edge: int,
	stack_edge: int,
	phase_a: int,
	bait_color: int,
	allow_holes: bool
) -> Dictionary:
	var occupied: Dictionary = disabled.duplicate()
	for w in walls:
		for cell in w.cells:
			occupied[cell] = true
	var corner := _corner_cell(cols, rows, bait_edge, stack_edge)
	if occupied.has(corner):
		return {"ok": false}
	var empty: Dictionary = _empty_map(cols, rows, occupied)
	var bait_size := rng.randi_range(3, 5)
	var bait_cells: Array[Vector2i] = _grow_polyomino(corner, bait_size, empty, rng)
	if bait_cells.size() < 3:
		return {"ok": false}
	if _is_full_span_bar(bait_cells, cols, rows):
		return {"ok": false}
	if not _can_exit(bait_cells, _edge_dir(bait_edge), occupied, disabled, cols, rows):
		return {"ok": false}
	var bait_piece := {
		"cells": bait_cells,
		"color": bait_color,
		"kind": int(Block.BlockKind.STANDARD),
		"name": "Bait",
	}
	for cell in bait_cells:
		occupied[cell] = true
	var fill_colors: Dictionary = {}
	var fill_edges: Array = []
	for edge in [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM]:
		if edge == bait_edge:
			continue
		if edge == stack_edge:
			fill_colors[edge] = phase_a
			fill_edges.append(edge)
		else:
			var third: int = _third_color(phase_a, bait_color)
			fill_colors[edge] = third
			fill_edges.append(edge)
	var pre: Array = walls + [bait_piece]
	var filled: Dictionary = _reverse_fill(
		cols, rows, disabled, pre, fill_edges, fill_colors, rng, allow_holes
	)
	if not bool(filled.get("ok", false)):
		return {"ok": false}
	for p in filled.pieces:
		if int(p.color) == bait_color:
			return {"ok": false}
	var pieces: Array = walls + [bait_piece] + filled.pieces
	var a_count := 0
	var other_counts: Dictionary = {}
	for p in filled.pieces:
		if int(p.color) == phase_a:
			a_count += 1
		else:
			other_counts[int(p.color)] = int(other_counts.get(int(p.color), 0)) + 1
	if a_count < 1:
		return {"ok": false}
	var enabled := {0: false, 1: false, 2: false, 3: false}
	enabled[bait_edge] = true
	enabled[stack_edge] = true
	var colors := {0: C_RED, 1: C_BLUE, 2: C_GREEN, 3: C_YELLOW}
	colors[bait_edge] = bait_color
	colors[stack_edge] = phase_a
	var phase_map := {
		0: [] as Array[GoalPhase],
		1: [] as Array[GoalPhase],
		2: [] as Array[GoalPhase],
		3: [] as Array[GoalPhase],
	}
	phase_map[bait_edge] = [_phase(bait_color as Block.TileColor, 1)] as Array[GoalPhase]
	var stack_phases: Array[GoalPhase] = [
		_phase(phase_a as Block.TileColor, a_count),
		_phase(bait_color as Block.TileColor, 1),
	]
	phase_map[stack_edge] = stack_phases
	for edge in fill_edges:
		if edge == stack_edge:
			continue
		var col: int = int(fill_colors[edge])
		var n: int = int(other_counts.get(col, 0))
		if n <= 0:
			continue
		enabled[edge] = true
		colors[edge] = col
		phase_map[edge] = [_phase(col as Block.TileColor, n)] as Array[GoalPhase]
	var goals := {
		"enabled": enabled,
		"colors": colors,
		"multi": true,
		"phases": phase_map,
	}
	var level := _assemble(
		spec, cols, rows, filled.get("disabled", []), pieces, goals
	)
	if not _opening_progress(level):
		return {"ok": false}
	return {"ok": true, "level": level, "bait": true}


func _reverse_fill(
	cols: int,
	rows: int,
	holes: Dictionary,
	pre_pieces: Array,
	edges: Array,
	edge_colors: Dictionary,
	rng: RandomNumberGenerator,
	allow_holes: bool
) -> Dictionary:
	if edges.is_empty():
		return {"ok": false}
	var occupied: Dictionary = holes.duplicate()
	for pre in pre_pieces:
		for cell in pre.cells:
			occupied[cell] = true
	var leftover_holes: Dictionary = holes.duplicate()
	var playable := 0
	for y in rows:
		for x in cols:
			if not occupied.has(Vector2i(x, y)):
				playable += 1
	if playable < 6:
		return {"ok": false}
	var pieces: Array = []
	var stuck := 0
	while true:
		var empty: Dictionary = _empty_map(cols, rows, occupied)
		var empty_n := empty.size()
		if empty_n == 0:
			break
		if empty_n < 3:
			if not _resolve_leftovers(pieces, empty, leftover_holes, occupied, cols, rows, allow_holes):
				return {"ok": false}
			break
		var placed := false
		var progress := 1.0 - float(empty_n) / float(maxi(playable, 1))
		if stuck >= 2:
			progress = 1.0
		var try_edges: Array = edges.duplicate()
		_shuffle(try_edges, rng)
		for _try in 50:
			var edge: int = try_edges[_try % try_edges.size()]
			var dir: Vector2i = _edge_dir(edge)
			var depth: Dictionary = _depth_from_edge(empty, cols, rows, edge)
			if depth.is_empty():
				continue
			var start: Vector2i = _pick_start(depth, progress, rng)
			if start.x < 0:
				continue
			var min_sz := 3
			var max_sz := mini(8, empty_n)
			if edges.size() == 1:
				max_sz = mini(6, empty_n)
			if leftover_holes.size() >= 10:
				max_sz = mini(5, max_sz)
			var target := 3 if stuck >= 2 else _target_size(progress, empty_n, min_sz, max_sz, rng)
			var cells: Array[Vector2i] = _grow_polyomino(start, target, empty, rng)
			if cells.size() < 3:
				continue
			if _is_full_span_bar(cells, cols, rows):
				continue
			if not _can_exit(cells, dir, occupied, leftover_holes, cols, rows):
				continue
			var color: int = int(edge_colors[edge])
			pieces.append({
				"cells": cells,
				"color": color,
				"kind": int(Block.BlockKind.STANDARD),
				"name": "Piece %d" % pieces.size(),
			})
			for cell in cells:
				occupied[cell] = true
			placed = true
			break
		if not placed:
			stuck += 1
			if stuck >= 10:
				if not _resolve_leftovers(pieces, empty, leftover_holes, occupied, cols, rows, allow_holes):
					return {"ok": false}
				break
		else:
			stuck = 0
	if pieces.is_empty():
		return {"ok": false}
	var out_disabled: Array[Vector2i] = []
	for cell in leftover_holes.keys():
		out_disabled.append(cell as Vector2i)
	return {"ok": true, "pieces": pieces, "disabled": out_disabled}


func _assemble(
	spec: Dictionary,
	cols: int,
	rows: int,
	extra_disabled: Array,
	pieces: Array,
	goals: Dictionary
) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = spec.level_id
	level.display_name = spec.display_name
	level.level_name_key = ""
	level.section_index = SECTION_DIM1
	level.sort_index = int(spec.sort_index)
	level.group_title_key = str(spec.group)
	level.columns = cols
	level.rows = rows
	var disabled_cells: Array[Vector2i] = []
	var seen_d: Dictionary = {}
	for cell in extra_disabled:
		var v := cell as Vector2i
		if seen_d.has(v):
			continue
		seen_d[v] = true
		disabled_cells.append(v)
	## Silhouette / moonlace holes live in spec via extra_disabled plus any
	## cells never covered. Rebuild from a coverage map so holes the packer
	## started with survive even if they weren't leftover-tagged.
	if spec.has("_holes"):
		for cell in spec._holes:
			var hv := cell as Vector2i
			if seen_d.has(hv):
				continue
			seen_d[hv] = true
			disabled_cells.append(hv)
	level.disabled_cells = disabled_cells
	var enabled: Dictionary = goals.enabled
	level.goal_left_enabled = bool(enabled.get(0, false))
	level.goal_top_enabled = bool(enabled.get(1, false))
	level.goal_right_enabled = bool(enabled.get(2, false))
	level.goal_bottom_enabled = bool(enabled.get(3, false))
	var colors: Dictionary = goals.colors
	level.goal_left_color = colors.get(0, C_RED) as Block.TileColor
	level.goal_top_color = colors.get(1, C_BLUE) as Block.TileColor
	level.goal_right_color = colors.get(2, C_GREEN) as Block.TileColor
	level.goal_bottom_color = colors.get(3, C_YELLOW) as Block.TileColor
	level.multi_goal_mode = bool(goals.get("multi", false))
	var phases: Dictionary = goals.get("phases", {})
	level.goal_left_phases = _as_phases(phases.get(0, []))
	level.goal_top_phases = _as_phases(phases.get(1, []))
	level.goal_right_phases = _as_phases(phases.get(2, []))
	level.goal_bottom_phases = _as_phases(phases.get(3, []))
	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []
	var covered: Dictionary = {}
	for piece in pieces:
		var cells: Array[Vector2i] = []
		for cell in piece.cells:
			cells.append(cell as Vector2i)
			covered[cell] = true
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cells)
		level.block_positions.append(packed.anchor)
		level.block_colors.append(int(piece.color) as Block.TileColor)
		level.block_shapes.append(BlockShapes.SINGLE)
		level.block_kinds.append(int(piece.get("kind", Block.BlockKind.STANDARD)) as Block.BlockKind)
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append(str(piece.get("name", "Piece")))
	## Interior leftovers become holes. Rim leftovers stay empty so LevelGenRules
	## rejects the board instead of blocking the only exit with a rim hole.
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if covered.has(cell) or seen_d.has(cell):
				continue
			if x == 0 or y == 0 or x == cols - 1 or y == rows - 1:
				continue
			seen_d[cell] = true
			disabled_cells.append(cell)
	level.disabled_cells = disabled_cells
	return level


func _unlimited_goals(edge_colors: Dictionary, edges: Array) -> Dictionary:
	var enabled := {0: false, 1: false, 2: false, 3: false}
	var colors := {0: C_RED, 1: C_BLUE, 2: C_GREEN, 3: C_YELLOW}
	for edge in edges:
		enabled[int(edge)] = true
		colors[int(edge)] = int(edge_colors[edge])
	return {
		"enabled": enabled,
		"colors": colors,
		"multi": false,
		"phases": {
			0: [] as Array[GoalPhase],
			1: [] as Array[GoalPhase],
			2: [] as Array[GoalPhase],
			3: [] as Array[GoalPhase],
		},
	}


func _counted_goals_from_pieces(pieces: Array, edge_colors: Dictionary, edges: Array) -> Dictionary:
	var counts: Dictionary = _count_colors(pieces)
	var enabled := {0: false, 1: false, 2: false, 3: false}
	var colors := {0: C_RED, 1: C_BLUE, 2: C_GREEN, 3: C_YELLOW}
	var phase_map := {
		0: [] as Array[GoalPhase],
		1: [] as Array[GoalPhase],
		2: [] as Array[GoalPhase],
		3: [] as Array[GoalPhase],
	}
	var assigned: Dictionary = {}
	for edge in edges:
		var e: int = int(edge)
		var col: int = int(edge_colors[edge])
		enabled[e] = true
		colors[e] = col
		if assigned.has(col):
			## Second edge of the same colour: unlimited overflow / later phase.
			phase_map[e] = [_phase(col as Block.TileColor, 1, true)] as Array[GoalPhase]
			continue
		var n: int = int(counts.get(col, 1))
		phase_map[e] = [_phase(col as Block.TileColor, maxi(n, 1))] as Array[GoalPhase]
		assigned[col] = true
	return {
		"enabled": enabled,
		"colors": colors,
		"multi": true,
		"phases": phase_map,
	}


func _grow_polyomino(
	start: Vector2i,
	target: int,
	available: Dictionary,
	rng: RandomNumberGenerator
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var used: Dictionary = {start: true}
	var want := clampi(target, 3, 10)
	while cells.size() < want:
		var compact: Array[Vector2i] = []
		var loose: Array[Vector2i] = []
		for cell in cells:
			for dir in DIRS:
				var n: Vector2i = cell + dir
				if not available.has(n) or used.has(n):
					continue
				var adj := 0
				for d2 in DIRS:
					if used.has(n + d2):
						adj += 1
				if adj >= 2:
					compact.append(n)
				else:
					loose.append(n)
		var pool: Array[Vector2i] = compact if (not compact.is_empty() and rng.randf() < 0.72) else loose
		if pool.is_empty():
			pool = compact if not compact.is_empty() else loose
		if pool.is_empty():
			break
		var pick: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		cells.append(pick)
		used[pick] = true
	return cells


func _can_exit(
	cells: Array[Vector2i],
	dir: Vector2i,
	occupied: Dictionary,
	disabled: Dictionary,
	cols: int,
	rows: int
) -> bool:
	var current: Array[Vector2i] = []
	var own: Dictionary = {}
	for cell in cells:
		current.append(cell)
		own[cell] = true
	for _step in cols + rows + 2:
		var blocked := false
		var oob := false
		var next_cells: Array[Vector2i] = []
		for cell in current:
			var n: Vector2i = cell + dir
			next_cells.append(n)
			if disabled.has(n) or (occupied.has(n) and not own.has(n)):
				blocked = true
			elif n.x < 0 or n.y < 0 or n.x >= cols or n.y >= rows:
				oob = true
		if blocked:
			return false
		if oob:
			return _would_exit_edge(next_cells, dir, cols, rows)
		own.clear()
		current = next_cells
		for cell in current:
			own[cell] = true
	return false


func _would_exit_edge(next_cells: Array[Vector2i], dir: Vector2i, cols: int, rows: int) -> bool:
	for cell in next_cells:
		if dir == Vector2i.LEFT and cell.x < 0:
			return true
		if dir == Vector2i.UP and cell.y < 0:
			return true
		if dir == Vector2i.RIGHT and cell.x >= cols:
			return true
		if dir == Vector2i.DOWN and cell.y >= rows:
			return true
	return false


func _depth_from_edge(empty: Dictionary, cols: int, rows: int, edge: int) -> Dictionary:
	var depth: Dictionary = {}
	var q: Array[Vector2i] = []
	for cell in empty.keys():
		var c: Vector2i = cell
		if _on_edge(c, cols, rows, edge):
			depth[c] = 0
			q.append(c)
	var i := 0
	while i < q.size():
		var cur: Vector2i = q[i]
		i += 1
		var d: int = int(depth[cur])
		for dir in DIRS:
			var n: Vector2i = cur + dir
			if not empty.has(n) or depth.has(n):
				continue
			depth[n] = d + 1
			q.append(n)
	return depth


func _pick_start(depth: Dictionary, progress: float, rng: RandomNumberGenerator) -> Vector2i:
	var keys: Array = depth.keys()
	if keys.is_empty():
		return Vector2i(-1, -1)
	var best: Array[Vector2i] = []
	if progress < 0.45:
		var max_d := 0
		for cell in keys:
			max_d = maxi(max_d, int(depth[cell]))
		var floor_d: int = maxi(int(float(max_d) * 0.45), 1 if max_d > 1 else 0)
		for cell in keys:
			if int(depth[cell]) >= floor_d:
				best.append(cell as Vector2i)
	else:
		var cap := 2 if progress < 0.75 else 1
		for cell in keys:
			if int(depth[cell]) <= cap:
				best.append(cell as Vector2i)
	if best.is_empty():
		return keys[rng.randi_range(0, keys.size() - 1)] as Vector2i
	return best[rng.randi_range(0, best.size() - 1)]


func _target_size(progress: float, empty_n: int, min_sz: int, max_sz: int, rng: RandomNumberGenerator) -> int:
	if empty_n <= 8 and empty_n >= 3:
		return empty_n
	var lo := min_sz
	var hi := max_sz
	if progress < 0.4:
		lo = mini(5, max_sz)
		hi = max_sz
	elif progress < 0.75:
		lo = 4
		hi = mini(6, max_sz)
	else:
		lo = 3
		hi = mini(5, max_sz)
	if hi < lo:
		hi = lo
	return rng.randi_range(lo, hi)


func _on_edge(cell: Vector2i, cols: int, rows: int, edge: int) -> bool:
	match edge:
		EDGE_LEFT:
			return cell.x == 0
		EDGE_TOP:
			return cell.y == 0
		EDGE_RIGHT:
			return cell.x == cols - 1
		_:
			return cell.y == rows - 1


func _edge_dir(edge: int) -> Vector2i:
	match edge:
		EDGE_LEFT:
			return Vector2i.LEFT
		EDGE_TOP:
			return Vector2i.UP
		EDGE_RIGHT:
			return Vector2i.RIGHT
		_:
			return Vector2i.DOWN


func _resolve_leftovers(
	pieces: Array,
	empty: Dictionary,
	leftover_holes: Dictionary,
	occupied: Dictionary,
	cols: int,
	rows: int,
	allow_holes: bool
) -> bool:
	var rim: Dictionary = {}
	var interior: Dictionary = {}
	for cell in empty.keys():
		var c: Vector2i = cell
		if c.x == 0 or c.y == 0 or c.x == cols - 1 or c.y == rows - 1:
			rim[c] = true
		else:
			interior[c] = true
	if not rim.is_empty():
		if not _absorb_leftovers(pieces, rim, cols, rows):
			return false
		for cell in rim.keys():
			occupied[cell] = true
	if interior.is_empty():
		return true
	if allow_holes:
		for cell in interior.keys():
			leftover_holes[cell] = true
			occupied[cell] = true
		return true
	if _absorb_leftovers(pieces, interior, cols, rows):
		for cell in interior.keys():
			occupied[cell] = true
		return true
	return false


func _empty_map(cols: int, rows: int, occupied: Dictionary) -> Dictionary:
	var empty := {}
	for y in rows:
		for x in cols:
			var cell := Vector2i(x, y)
			if not occupied.has(cell):
				empty[cell] = true
	return empty


func _is_full_span_bar(cells: Array[Vector2i], cols: int, rows: int) -> bool:
	if cells.size() < 3:
		return false
	var min_x := cells[0].x
	var max_x := cells[0].x
	var min_y := cells[0].y
	var max_y := cells[0].y
	for cell in cells:
		min_x = mini(min_x, cell.x)
		max_x = maxi(max_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_y = maxi(max_y, cell.y)
	var w := max_x - min_x + 1
	var h := max_y - min_y + 1
	if h == 1 and w == cells.size() and w == cols:
		return true
	if w == 1 and h == cells.size() and h == rows:
		return true
	return false


func _absorb_leftovers(pieces: Array, empty: Dictionary, cols: int, rows: int) -> bool:
	if pieces.is_empty():
		return false
	for cell in empty.keys():
		var c: Vector2i = cell
		var absorbed := false
		for i in range(pieces.size() - 1, -1, -1):
			var piece: Dictionary = pieces[i]
			if int(piece.get("kind", 0)) == int(Block.BlockKind.WALL):
				continue
			for existing in piece.cells:
				if abs(existing.x - c.x) + abs(existing.y - c.y) != 1:
					continue
				var grown: Array[Vector2i] = []
				for old in piece.cells:
					grown.append(old as Vector2i)
				grown.append(c)
				if _is_full_span_bar(grown, cols, rows):
					continue
				piece.cells = grown
				pieces[i] = piece
				absorbed = true
				break
			if absorbed:
				break
		if not absorbed:
			return false
	return true


func _silhouette(cols: int, rows: int, kind: int, rng: RandomNumberGenerator) -> Dictionary:
	var disabled := {}
	match kind % 6:
		0:
			## Square frame — playable rim, hollow centre.
			var t := 2 if cols >= 10 else 1
			for y in rows:
				for x in cols:
					if x >= t and x < cols - t and y >= t and y < rows - t:
						disabled[Vector2i(x, y)] = true
		1:
			## Plus-sign corridors that meet every edge.
			var arm := 1 if cols <= 10 else 2
			var mx := int(cols / 2)
			var my := int(rows / 2)
			for y in rows:
				for x in cols:
					if abs(x - mx) > arm and abs(y - my) > arm:
						disabled[Vector2i(x, y)] = true
		2:
			## Two islands with a gap you cannot cross. Leave top/bottom
			## edge cells open so each island still has three exits.
			var gap0 := int(cols / 2) - 1
			var gap1 := gap0 + (1 if rng.randf() < 0.55 else 2)
			for y2 in range(1, rows - 1):
				for x2 in range(gap0, mini(gap1 + 1, cols)):
					disabled[Vector2i(x2, y2)] = true
		3:
			## Diagonal rift, 1–2 cells thick.
			var width := 1 if cols <= 10 else 2
			if rng.randf() < 0.5:
				for y in rows:
					for x in cols:
						if absi(x - y) <= width:
							disabled[Vector2i(x, y)] = true
			else:
				for y in rows:
					for x in cols:
						if absi(x - (rows - 1 - y)) <= width:
							disabled[Vector2i(x, y)] = true
		4:
			## Rounded corners only — a disc-like silhouette that still
			## keeps every edge playable.
			var cut := 2 if cols <= 10 else 3
			for y in rows:
				for x in cols:
					var corner := (
						(x < cut and y < cut)
						or (x >= cols - cut and y < cut)
						or (x < cut and y >= rows - cut)
						or (x >= cols - cut and y >= rows - cut)
					)
					if corner:
						disabled[Vector2i(x, y)] = true
		_:
			## Thick square frame (ring analogue) with a large inner hole.
			var t := 3 if cols >= 12 else 2
			for y in rows:
				for x in cols:
					if x >= t and x < cols - t and y >= t and y < rows - t:
						disabled[Vector2i(x, y)] = true
	return disabled


func _moonlace_holes(cols: int, rows: int, index: int, rng: RandomNumberGenerator) -> Dictionary:
	var disabled := {}
	if index < 6:
		## Small interior hole / room.
		var hx := rng.randi_range(2, cols - 4)
		var hy := rng.randi_range(2, rows - 4)
		for y in range(hy, mini(hy + 2, rows - 1)):
			for x in range(hx, mini(hx + 2, cols - 1)):
				disabled[Vector2i(x, y)] = true
		return disabled
	if index < 16:
		## Corridor that does not span the full board.
		var vertical := rng.randf() < 0.5
		if vertical:
			var x := rng.randi_range(2, cols - 3)
			var y0 := rng.randi_range(1, 2)
			var y1 := rng.randi_range(rows - 4, rows - 3)
			for y in range(y0, y1 + 1):
				disabled[Vector2i(x, y)] = true
		else:
			var y := rng.randi_range(2, rows - 3)
			var x0 := rng.randi_range(1, 2)
			var x1 := rng.randi_range(cols - 4, cols - 3)
			for x in range(x0, x1 + 1):
				disabled[Vector2i(x, y)] = true
		return disabled
	## Split rooms with a gap you cannot cross, plus a detour.
	var x := int(cols / 2)
	for y in range(1, rows - 1):
		if y == int(rows / 2) and index % 2 == 0:
			continue
		disabled[Vector2i(x, y)] = true
	return disabled


func _make_walls(
	cols: int,
	rows: int,
	disabled: Dictionary,
	count: int,
	rng: RandomNumberGenerator
) -> Array:
	var walls: Array = []
	var occupied: Dictionary = disabled.duplicate()
	for _i in count:
		var empty: Dictionary = _empty_map(cols, rows, occupied)
		if empty.size() < 8:
			break
		var candidates: Array[Vector2i] = []
		for cell in empty.keys():
			var c: Vector2i = cell
			if c.x == 0 or c.y == 0 or c.x == cols - 1 or c.y == rows - 1:
				continue
			candidates.append(c)
		if candidates.is_empty():
			break
		var start: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		var cells: Array[Vector2i] = _grow_polyomino(start, rng.randi_range(3, 5), empty, rng)
		if cells.size() < 3:
			continue
		var wall := {
			"cells": cells,
			"color": C_RED,
			"kind": int(Block.BlockKind.WALL),
			"name": "Wall %d" % walls.size(),
		}
		walls.append(wall)
		for cell in cells:
			occupied[cell] = true
	return walls


func _place_mix_pair(
	cols: int,
	rows: int,
	disabled: Dictionary,
	walls: Array,
	color_a: int,
	color_b: int,
	mix_edge: int,
	bait_edge: int,
	rng: RandomNumberGenerator
) -> Array:
	var occupied: Dictionary = disabled.duplicate()
	for w in walls:
		for cell in w.cells:
			occupied[cell] = true
	var mix_dir: Vector2i = _edge_dir(mix_edge)
	var bait_dir: Vector2i = _edge_dir(bait_edge)
	var tangent := Vector2i(-mix_dir.y, mix_dir.x)
	var candidates: Array = []
	## Side-by-side 3-bars on the mix edge: merge along the rim, then score out.
	for y in rows:
		for x in cols:
			var origin := Vector2i(x, y)
			if not _on_edge(origin, cols, rows, mix_edge):
				continue
			var a_cells: Array[Vector2i] = _edge_bar(origin, tangent, 3, cols, rows)
			if a_cells.is_empty():
				continue
			var b_origin: Vector2i = origin + tangent * 3
			var b_cells: Array[Vector2i] = _edge_bar(b_origin, tangent, 3, cols, rows)
			if b_cells.is_empty():
				continue
			var blocked := false
			for cell in a_cells + b_cells:
				if occupied.has(cell):
					blocked = true
					break
			if blocked:
				continue
			var union_cells: Array[Vector2i] = []
			for cell in a_cells + b_cells:
				union_cells.append(cell)
			if not _can_exit(union_cells, mix_dir, occupied, disabled, cols, rows):
				continue
			var a_on_bait := false
			for cell in a_cells:
				if _on_edge(cell, cols, rows, bait_edge):
					a_on_bait = true
			if a_on_bait and not _can_exit(a_cells, bait_dir, occupied, disabled, cols, rows):
				continue
			candidates.append({"a": a_cells, "b": b_cells, "bait": a_on_bait})
	if candidates.is_empty():
		return []
	var baited: Array = []
	for c in candidates:
		if bool(c.bait):
			baited.append(c)
	var pool: Array = baited if not baited.is_empty() else candidates
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return [
		{
			"cells": pick.a,
			"color": color_a,
			"kind": int(Block.BlockKind.MERGE),
			"name": "Mixer A",
		},
		{
			"cells": pick.b,
			"color": color_b,
			"kind": int(Block.BlockKind.MERGE),
			"name": "Mixer B",
		},
	]


func _edge_bar(
	origin: Vector2i,
	tangent: Vector2i,
	length: int,
	cols: int,
	rows: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in length:
		var cell: Vector2i = origin + tangent * i
		if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
			return [] as Array[Vector2i]
		cells.append(cell)
	return cells


func _pick_palette(n: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = [C_RED, C_BLUE, C_GREEN, C_YELLOW]
	_shuffle(pool, rng)
	var out: Array = []
	for i in clampi(n, 2, 4):
		out.append(pool[i])
	return out


func _mix_pair(kind: int) -> Array:
	match kind % 3:
		0:
			return [C_RED, C_YELLOW, C_ORANGE]
		1:
			return [C_YELLOW, C_BLUE, C_GREEN]
		_:
			return [C_RED, C_BLUE, C_PURPLE]


func _third_color(a: int, b: int) -> int:
	for c in [C_RED, C_BLUE, C_GREEN, C_YELLOW]:
		if c != a and c != b:
			return c
	return C_GREEN


func _other_edge(edge: int, rng: RandomNumberGenerator) -> int:
	var opts: Array = []
	for e in [EDGE_LEFT, EDGE_TOP, EDGE_RIGHT, EDGE_BOTTOM]:
		if e != edge:
			opts.append(e)
	return int(opts[rng.randi_range(0, opts.size() - 1)])


func _corner_cell(cols: int, rows: int, edge_a: int, edge_b: int) -> Vector2i:
	var x := 0
	var y := 0
	if edge_a == EDGE_RIGHT or edge_b == EDGE_RIGHT:
		x = cols - 1
	if edge_a == EDGE_BOTTOM or edge_b == EDGE_BOTTOM:
		y = rows - 1
	if edge_a == EDGE_LEFT or edge_b == EDGE_LEFT:
		x = 0
	if edge_a == EDGE_TOP or edge_b == EDGE_TOP:
		y = 0
	return Vector2i(x, y)


func _color_by_peel(
	pieces: Array,
	disabled_arr: Array,
	edge: int,
	cols: int,
	rows: int,
	palette: Array,
	n_phases: int
) -> Dictionary:
	var holes: Dictionary = {}
	for cell in disabled_arr:
		holes[cell] = true
	var remaining: Array = []
	for i in pieces.size():
		if int(pieces[i].get("kind", 0)) == int(Block.BlockKind.WALL):
			continue
		remaining.append(i)
	var layers: Array = []
	var dir: Vector2i = _edge_dir(edge)
	while not remaining.is_empty():
		var occupied: Dictionary = holes.duplicate()
		for i in remaining:
			for cell in pieces[i].cells:
				occupied[cell] = true
		var layer: Array = []
		for i in remaining:
			var cells: Array[Vector2i] = []
			for cell in pieces[i].cells:
				cells.append(cell as Vector2i)
			if _can_exit(cells, dir, occupied, holes, cols, rows):
				layer.append(i)
		if layer.is_empty():
			return {"ok": false}
		layers.append(layer)
		var nxt: Array = []
		for i in remaining:
			if not layer.has(i):
				nxt.append(i)
		remaining = nxt
	var order: Array = []
	var phases := clampi(n_phases, 1, mini(palette.size(), layers.size()))
	if layers.size() == 1:
		var only: int = palette[0]
		for i in layers[0]:
			pieces[i].color = only
		return {"ok": true, "order": [only]}
	## Band peel layers into 2–3 goal phases so rim pieces leave first.
	var cuts: Array[int] = [0]
	if phases == 2:
		cuts.append(1)
		cuts.append(layers.size())
	else:
		cuts.append(1)
		cuts.append(mini(2, layers.size()))
		cuts.append(layers.size())
	for band in range(cuts.size() - 1):
		var col: int = palette[band % palette.size()]
		if not order.has(col):
			order.append(col)
		for li in range(cuts[band], cuts[band + 1]):
			if li >= layers.size():
				break
			for i in layers[li]:
				pieces[i].color = col
	return {"ok": order.size() >= 1, "order": order}


func _as_phases(raw) -> Array[GoalPhase]:
	var out: Array[GoalPhase] = []
	if raw == null:
		return out
	for item in raw:
		if item is GoalPhase:
			out.append(item)
	return out


func _opposite_edge(edge: int) -> int:
	match edge:
		EDGE_LEFT:
			return EDGE_RIGHT
		EDGE_RIGHT:
			return EDGE_LEFT
		EDGE_TOP:
			return EDGE_BOTTOM
		_:
			return EDGE_TOP


func _perp_edge(edge: int, rng: RandomNumberGenerator) -> int:
	if edge == EDGE_LEFT or edge == EDGE_RIGHT:
		return EDGE_TOP if rng.randf() < 0.5 else EDGE_BOTTOM
	return EDGE_LEFT if rng.randf() < 0.5 else EDGE_RIGHT


func _open_edge_apertures(disabled: Dictionary, cols: int, rows: int) -> void:
	var mx := int(cols / 2)
	var my := int(rows / 2)
	for i in maxi(int(mini(cols, rows) / 2), 3):
		disabled.erase(Vector2i(mx, i))
		disabled.erase(Vector2i(mx - 1, i))
		disabled.erase(Vector2i(mx, rows - 1 - i))
		disabled.erase(Vector2i(mx - 1, rows - 1 - i))
		disabled.erase(Vector2i(i, my))
		disabled.erase(Vector2i(i, my - 1))
		disabled.erase(Vector2i(cols - 1 - i, my))
		disabled.erase(Vector2i(cols - 1 - i, my - 1))


func _color_scorable_first(
	pieces: Array,
	disabled_arr: Array,
	edge: int,
	cols: int,
	rows: int,
	palette: Array
) -> bool:
	var holes: Dictionary = {}
	for cell in disabled_arr:
		holes[cell] = true
	var occupied: Dictionary = holes.duplicate()
	for piece in pieces:
		for cell in piece.cells:
			occupied[cell] = true
	var scorable: Dictionary = {}
	var dir: Vector2i = _edge_dir(edge)
	for i in pieces.size():
		var own: Dictionary = {}
		var cells: Array[Vector2i] = []
		for cell in pieces[i].cells:
			own[cell] = true
			cells.append(cell as Vector2i)
		var occ: Dictionary = occupied.duplicate()
		if _can_exit(cells, dir, occ, holes, cols, rows):
			scorable[i] = true
	if scorable.is_empty():
		return false
	var inland_color: int = palette[1] if palette.size() > 1 else palette[0]
	for i in pieces.size():
		pieces[i].color = palette[0] if scorable.has(i) else inland_color
	return scorable.size() < pieces.size() or palette.size() == 1


func _opening_progress(level: LevelConfig) -> bool:
	var sim := PuzzleSim.new()
	var state = sim.load_config(level)
	for action in sim.legal_actions(state):
		var applied: Dictionary = sim.apply_move(
			state,
			int(action.block_index),
			action.direction as Vector2i
		)
		if not bool(applied.get("ok", false)):
			continue
		var outcome: int = int(applied.get("outcome", 0))
		if outcome == PuzzleSim.Outcome.SCORE or outcome == PuzzleSim.Outcome.MERGE:
			return true
	return false


func _dist_to_edge(cell: Vector2i, edge: int, cols: int, rows: int) -> int:
	match edge:
		EDGE_LEFT:
			return cell.x
		EDGE_TOP:
			return cell.y
		EDGE_RIGHT:
			return cols - 1 - cell.x
		_:
			return rows - 1 - cell.y


func _count_colors(pieces: Array) -> Dictionary:
	var counts := {}
	for p in pieces:
		if int(p.get("kind", 0)) == int(Block.BlockKind.WALL):
			continue
		var c: int = int(p.color)
		counts[c] = int(counts.get(c, 0)) + 1
	return counts


func _phase(color: Block.TileColor, count: int = 1, unlimited: bool = false) -> GoalPhase:
	var phase := GoalPhase.new()
	phase.color = color
	phase.count = count
	phase.unlimited = unlimited
	return phase


func _find_piece_index(level: LevelConfig, kind: int, color: int) -> int:
	for i in level.block_kinds.size():
		if int(level.block_kinds[i]) == kind and int(level.block_colors[i]) == color:
			return i
	return -1


func _discover_bait(level: LevelConfig) -> Dictionary:
	var sim := PuzzleSim.new()
	var start = sim.load_config(level)
	for action in sim.legal_actions(start):
		var applied: Dictionary = sim.apply_move(
			start,
			int(action.block_index),
			action.direction as Vector2i
		)
		if not bool(applied.get("ok", false)):
			continue
		if int(applied.get("outcome", 0)) != PuzzleSim.Outcome.SCORE:
			continue
		var trap: Dictionary = LevelSolverScript.bait_traps(
			level, int(action.block_index), action.direction as Vector2i
		)
		if bool(trap.get("ok", false)) and bool(trap.get("traps", false)):
			return trap
	return {"traps": false}


func _dense_enough(level: LevelConfig, spec: Dictionary) -> bool:
	var area := maxi(level.columns * level.rows, 1)
	var holes := level.disabled_cells.size()
	var piece_cells := 0
	var clearable := 0
	for i in level.block_positions.size():
		var kind := (
			int(level.block_kinds[i]) if i < level.block_kinds.size() else 0
		)
		var n: int = (
			(level.block_cell_patterns[i] as Array).size()
			if i < level.block_cell_patterns.size()
			else 0
		)
		piece_cells += n
		if kind != 2:
			clearable += 1
	if clearable < 6:
		return false
	var filled := float(piece_cells) / float(area)
	if int(spec.chapter) == 1:
		return filled >= 0.78 and holes <= 8
	if int(spec.chapter) == 2:
		return filled >= 0.52
	if int(spec.chapter) == 5:
		return filled >= 0.28 and clearable >= 7
	return filled >= 0.45


func _min_cell_error(level: LevelConfig) -> String:
	for i in level.block_positions.size():
		var kind := (
			int(level.block_kinds[i]) if i < level.block_kinds.size() else int(Block.BlockKind.STANDARD)
		)
		if Block.is_wall_kind(kind as Block.BlockKind):
			continue
		var cells: Array = LevelGenRulesScript.absolute_cells(level, i)
		if cells.size() < MIN_CELLS:
			return "tiny piece"
		var shape_id := str(level.block_shapes[i]) if i < level.block_shapes.size() else ""
		if shape_id == BlockShapes.LINE_2:
			return "line_2"
	return ""


func _fingerprint(level: LevelConfig) -> String:
	var bits: PackedStringArray = [
		"%dx%d" % [level.columns, level.rows],
		"g%s" % _goal_sig(level),
	]
	var holes: PackedStringArray = []
	for cell in level.disabled_cells:
		holes.append("%d,%d" % [cell.x, cell.y])
	holes.sort()
	bits.append("h:" + ",".join(holes))
	var pieces: PackedStringArray = []
	for i in level.block_positions.size():
		var cells: Array = LevelGenRulesScript.absolute_cells(level, i)
		var coords: PackedStringArray = []
		for cell in cells:
			coords.append("%d,%d" % [cell.x, cell.y])
		coords.sort()
		var kind := int(level.block_kinds[i]) if i < level.block_kinds.size() else 0
		var color := int(level.block_colors[i]) if i < level.block_colors.size() else 0
		pieces.append("%d:%d:%s" % [kind, color, ";".join(coords)])
	pieces.sort()
	bits.append("p:" + "|".join(pieces))
	return " ".join(bits)


func _near_key(level: LevelConfig) -> String:
	var shapes: PackedStringArray = []
	for i in level.block_positions.size():
		var cells: Array = LevelGenRulesScript.absolute_cells(level, i)
		var canon := _canonical_shape(cells)
		var kind := int(level.block_kinds[i]) if i < level.block_kinds.size() else 0
		var color := int(level.block_colors[i]) if i < level.block_colors.size() else 0
		shapes.append("%d:%d:%s" % [kind, color, canon])
	shapes.sort()
	var holes: PackedStringArray = []
	for cell in level.disabled_cells:
		holes.append("%d,%d" % [cell.x, cell.y])
	holes.sort()
	return "%dx%d|%s|%s|%s" % [
		level.columns, level.rows, _goal_sig(level), ",".join(holes), "|".join(shapes)
	]


func _near_duplicate(level: LevelConfig, seen: Dictionary) -> bool:
	return seen.has("near:" + _near_key(level))


func _canonical_shape(cells: Array) -> String:
	var min_x := 99
	var min_y := 99
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	var parts: PackedStringArray = []
	for cell in cells:
		parts.append("%d,%d" % [cell.x - min_x, cell.y - min_y])
	parts.sort()
	return ";".join(parts)


func _goal_sig(level: LevelConfig) -> String:
	return "%s%s%s%s:%d%d%d%d:%s" % [
		int(level.goal_left_color),
		int(level.goal_top_color),
		int(level.goal_right_color),
		int(level.goal_bottom_color),
		int(level.goal_left_enabled),
		int(level.goal_top_enabled),
		int(level.goal_right_enabled),
		int(level.goal_bottom_enabled),
		int(level.multi_goal_mode),
	]


func _apply_rating(level: LevelConfig, rating: Dictionary, spec: Dictionary) -> void:
	var index: int = int(spec.index)
	var chapter: int = int(spec.chapter)
	var score := float(rating.score) + float(index) * 0.18 + float(chapter - 1) * 0.4
	var tier := int(rating.tier)
	match chapter:
		1:
			tier = 1 if index < 16 else 2
			tier = clampi(maxi(tier, 1), 1, 2)
		2:
			tier = 2
		3:
			tier = 2 if index < 12 else 3
			tier = clampi(tier, 2, 3)
		4:
			tier = 2 if index < 10 else 3
			tier = clampi(tier, 2, 3)
		5:
			tier = 3
	level.difficulty_score = snappedf(score, 0.01)
	level.difficulty_tier = tier


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _assert_merge_once(lines: PackedStringArray) -> bool:
	var ok := true
	if Block.get_merged_color(C_RED, C_YELLOW) != C_ORANGE:
		lines.append("FAIL mix R+Y")
		ok = false
	if Block.get_merged_color(C_YELLOW, C_BLUE) != C_GREEN:
		lines.append("FAIL mix Y+B")
		ok = false
	if Block.get_merged_color(C_RED, C_BLUE) != C_PURPLE:
		lines.append("FAIL mix R+B")
		ok = false
	if Block.get_merged_color(C_ORANGE, C_BLUE) != -1:
		lines.append("FAIL re-mix orange+blue")
		ok = false
	if ok:
		lines.append("ok merge-once RYB")
	return ok


func _clear_previous_twinkle() -> void:
	if int(OS.get_environment("TWINKLE_SKIP_EXISTING")) == 1:
		return
	var only_chapter := int(OS.get_environment("TWINKLE_CHAPTER"))
	var prefixes: Array[String] = [
		"twinkle_pebbles_",
		"twinkle_moonlace_",
		"twinkle_solar_",
		"twinkle_paint_",
		"twinkle_rift_",
	]
	var dir := DirAccess.open("res://resources/levels/")
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.begins_with("twinkle_") and name.ends_with(".tres"):
			var wipe := only_chapter <= 0
			if not wipe and only_chapter >= 1 and only_chapter <= prefixes.size():
				wipe = name.begins_with(prefixes[only_chapter - 1])
			if wipe:
				dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()


func _audit(lines: PackedStringArray, expected_dim0: int) -> int:
	lines.append("")
	lines.append("=== audit ===")
	var by_section: Dictionary = {}
	var by_group: Dictionary = {}
	var unverified := 0
	var tiny := 0
	var dim0 := 0
	var tutorial := 0
	var dir := DirAccess.open("res://resources/levels/")
	if dir == null:
		lines.append("ERROR: cannot open levels dir")
		return 1
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var level: LevelConfig = load("res://resources/levels/%s" % fname)
			if level == null:
				fname = dir.get_next()
				continue
			if str(level.daily_date).strip_edges() != "" or level.section_index == 100:
				fname = dir.get_next()
				continue
			by_section[level.section_index] = int(by_section.get(level.section_index, 0)) + 1
			if level.section_index == 0:
				dim0 += 1
				var g := level.group_title_key
				by_group[g] = int(by_group.get(g, 0)) + 1
				if not level.verified_solvable:
					unverified += 1
				if not _min_cell_error(level).is_empty():
					tiny += 1
			if level.section_index == 10:
				tutorial += 1
		fname = dir.get_next()
	dir.list_dir_end()
	lines.append("section 0: %d (want %d)" % [dim0, expected_dim0])
	for g in [
		_GROUP_PEBBLE, _GROUP_MOONLACE, _GROUP_SOLAR, _GROUP_PAINT, _GROUP_RIFT
	]:
		lines.append("  %s: %d" % [g, int(by_group.get(g, 0))])
	lines.append("tutorial: %d" % tutorial)
	lines.append("unverified dim1: %d tiny: %d" % [unverified, tiny])
	for s in by_section.keys():
		if int(s) != 0 and int(s) != 10:
			lines.append("WARN leftover section %s count=%s" % [s, by_section[s]])
	var code := 0
	if unverified > 0 or tiny > 0:
		code = 1
	var all_thirty := true
	for g in [
		_GROUP_PEBBLE, _GROUP_MOONLACE, _GROUP_SOLAR, _GROUP_PAINT, _GROUP_RIFT
	]:
		if int(by_group.get(g, 0)) != 30:
			all_thirty = false
	if all_thirty:
		if dim0 != 150:
			code = 1
	elif dim0 != expected_dim0:
		code = 1
	if tutorial != 25:
		lines.append("WARN tutorial count is %d (expected 25)" % tutorial)
	return code


func _save_project_level(level: LevelConfig) -> Error:
	var path := "res://resources/levels/%s.tres" % level.level_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/levels/"))
	return ResourceSaver.save(level, path)


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
	if not new_path.is_empty() and not paths.has(new_path):
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
