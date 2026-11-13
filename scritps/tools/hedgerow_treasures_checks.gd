extends SceneTree

## Checks the 50 Hedgerow Treasures levels (Ion Meadows, section 3, after Meadow Charms):
## - every level is in LevelRegistry, in the right section/group, tiers as listed in EXPECTED_TIERS, nothing above Medium so all can feed the daily pool;
## - piece rules (>= 3 cells, connected, no overlap, walls are WALL pieces);
## - nothing can leave on the first swipe;
## - the recorded winning line wins in PuzzleSim AND on the real Board scene
##   (normal _commit_move, animations included) with all 3 lives, and the two
##   agree on every piece after every move.
## Run:
##   godot --headless --path . -s res://scritps/tools/hedgerow_treasures_checks.gd

const Gen := preload("res://scritps/tools/generate_hedgerow_treasures_levels.gd")
const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")

var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _fail(msg: String) -> void:
	_fails += 1
	printerr("FAIL ", msg)


func _key(cells: Array) -> String:
	var a: Array = []
	for c in cells:
		a.append("%d,%d" % [c.x, c.y])
	a.sort()
	return ";".join(a)


func _board_sig(board) -> Array:
	var out: Array = []
	for bi in board.placed_blocks.size():
		if not is_instance_valid(board.placed_blocks[bi]):
			continue
		var b: Block = board.placed_blocks[bi]
		if b.visible:
			out.append("%d|%d|%s" % [b.block_kind, b.tile_color, _key(b.get_occupied_cells())])
	out.sort()
	return out


func _sim_sig(st) -> Array:
	var out: Array = []
	for b in st.blocks:
		out.append("%d|%d|%s" % [b.kind, b.color, _key(b.occupied())])
	out.sort()
	return out


const EXPECTED_TIERS := {1: 8, 2: 42, 3: 0, 4: 0}


func _run() -> void:
	var data: Dictionary = Gen.load_data()
	var tiers := {1: 0, 2: 0, 3: 0, 4: 0}
	var ids := {}
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	for spec in data.levels:
		var path := "res://resources/levels/%s.tres" % spec.level_id
		var label := "%s %s" % [spec.level_id, spec.name]
		if ids.has(spec.level_id):
			_fail("%s duplicate id" % label)
		ids[spec.level_id] = true
		if not LevelRegistry.LEVEL_PATHS.has(path):
			_fail("%s not in LevelRegistry" % label)
		var level := load(path) as LevelConfig
		if level == null:
			_fail("%s does not load" % label)
			continue
		if level.section_index != 3 or level.group_title_key != "UI_GROUP_HEDGEROW_TREASURES":
			_fail("%s wrong section/group" % label)
		if level.difficulty_tier != int(spec.tier):
			_fail("%s tier %d != %d" % [label, level.difficulty_tier, int(spec.tier)])
		tiers[level.difficulty_tier] = int(tiers.get(level.difficulty_tier, 0)) + 1
		var rules: Dictionary = LevelGenRulesScript.validate(level)
		for e in rules.errors:
			## Handmade silhouettes leave open space on purpose (docs/level-design.md).
			if not str(e).contains("empty playable"):
				_fail("%s rule: %s" % [label, e])
		var sim = PuzzleSimScript.new()
		var st = sim.load_config(level)
		for act in sim.legal_actions(st):
			var r: Dictionary = sim.apply_move(st, act.block_index, act.direction)
			if int(r.outcome) == PuzzleSimScript.Outcome.SCORE:
				_fail("%s a piece can leave on the first swipe" % label)
				break
		var steps: Array = Gen.solution(spec)
		var sim_err: String = Gen.replay_sim(level, steps)
		if sim_err != "":
			_fail("%s sim: %s" % [label, sim_err])
			continue
		## Real Board replay.
		board.load_level(level)
		await process_frame
		var ok := _board_sig(board) == _sim_sig(st)
		var n := 0
		for s in steps:
			n += 1
			var want := _key(st.blocks[int(s[0])].occupied())
			var target: Block = null
			for bi in board.placed_blocks.size():
				if not is_instance_valid(board.placed_blocks[bi]):
					continue
				var cand: Block = board.placed_blocks[bi]
				if cand.visible and _key(cand.get_occupied_cells()) == want:
					target = cand
			if target == null:
				ok = false
				_fail("%s board: no piece for step %d" % [label, n])
				break
			st = sim.apply_move(st, int(s[0]), s[1] as Vector2i).state
			# Mirror Board._begin_pointer: the dragged piece's cells are unregistered before commit.
			board._unregister_block_cells(target)
			board._commit_move(target, target.grid_pos, s[1] as Vector2i, 1500.0)
			var guard := 0
			while (board.is_busy or guard < 2) and guard < 900:
				await process_frame
				guard += 1
			for i in 20:
				await process_frame
			if _board_sig(board) != _sim_sig(st) or board.get_lives() != 3:
				ok = false
				_fail("%s board differs from sim after step %d (lives %d)" % [label, n, board.get_lives()])
				break
		var left := 0
		for bi in board.placed_blocks.size():
			if not is_instance_valid(board.placed_blocks[bi]):
				continue
			var lb: Block = board.placed_blocks[bi]
			if lb.visible and not Block.is_wall_kind(lb.block_kind):
				left += 1
		if ok and left != 0:
			ok = false
			_fail("%s board ends with %d pieces" % [label, left])
		print("%s %s tier=%d moves=%d sim=WIN board=%s lives=%d" % [
			"PASS" if ok else "FAIL", label, level.difficulty_tier, steps.size(),
			"WIN" if ok else "NO", board.get_lives()])
	## Placement: Ion Meadows lists Meadow Charms first, then this whole subsection in one block.
	var order: Array[String] = []
	var catalog = root.get_node("LevelCatalog")
	for lv in catalog.get_section_levels(3):
		var k := (lv as LevelConfig).group_title_key.strip_edges()
		if order.is_empty() or order[-1] != k:
			order.append(k)
	if order != ["UI_GROUP_MEADOW_CHARMS", "UI_GROUP_HEDGEROW_TREASURES"]:
		_fail("Ion Meadows chapter order is %s" % [order])
	else:
		print("Ion Meadows chapters: %s" % [order])
	for t in [1, 2, 3, 4]:
		if int(tiers[t]) != int(EXPECTED_TIERS[t]):
			_fail("tier %d has %d levels" % [t, int(tiers[t])])
	print("hedgerow_treasures_checks: %d levels, tiers %s, %d failures" % [ids.size(), tiers, _fails])
	board.queue_free()
	quit(1 if _fails > 0 else 0)
