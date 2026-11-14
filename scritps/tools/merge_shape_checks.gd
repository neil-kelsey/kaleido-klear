extends SceneTree

## Merged shapes keep every cell of both pieces, and draw that way, whichever
## piece you swipe. Run:
##   godot --headless --path . -s res://scritps/tools/merge_shape_checks.gd
##
## Squirrel (Hedgerow Treasures): swiping the yellow 7 down into the blue S
## wraps the two around an empty square. The outline tracer kept one edge per
## corner, so with that cell order it lost the outline and drew only a 1x1 green
## square in the gap. Swiping the blue right gave a different cell order and
## looked right, though it painted the gap as filled. The game logic was fine;
## only the drawing broke.

const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")
const SQUIRREL := "res://resources/levels/custom_level_1793400034.tres"

## Squirrel's yellow and blue, local offsets, around the gap at (1, 1).
const YELLOW := [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(2, 2)]
const BLUE := [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)]
const GAP := Vector2i(1, 1)

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
	else:
		_fails += 1
		printerr("FAIL ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_outline_geometry()
	await _check_squirrel()
	await _check_all_orientations()
	print("merge_shape_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


# --- geometry -----------------------------------------------------------------

func _cells_dict(cells: Array) -> Dictionary:
	var d := {}
	for c in cells:
		d[c] = true
	return d


func _region_area(polys: Array) -> float:
	var a := 0.0
	for p in polys:
		var poly: PackedVector2Array = p
		var s := 0.0
		for i in poly.size():
			var j := (i + 1) % poly.size()
			s += poly[i].x * poly[j].y - poly[j].x * poly[i].y
		a += absf(s) * 0.5
	return a


func _covers(polys: Array, point: Vector2) -> bool:
	for p in polys:
		if Geometry2D.is_point_in_polygon(point, p):
			return true
	return false


## Every filled cell is drawn, no empty cell is, and the result is the same
## for any cell order.
func _check_shape_draws(block: Block, cells: Array, label: String) -> void:
	var cs := float(block._cell_size)
	var half := cs / 2.0
	var margin := block._cell_edge_margin()
	var radius := block._merge_corner_radius()
	var orders := [cells.duplicate(), cells.duplicate()]
	orders[1].reverse()
	var shuffled := cells.duplicate()
	seed(hash(label))
	shuffled.shuffle()
	orders.append(shuffled)
	var first_area := -1.0
	for order in orders:
		var d := _cells_dict(order)
		var loops: Array = block._boundary_loops(d)
		var all_closed := true
		var signed := 0.0
		for loop in loops:
			all_closed = all_closed and Vector2i(loop[-1]["to_v"]) == Vector2i(loop[0]["from_v"])
			signed += block._loop_signed_area(loop)
		_check(all_closed and is_equal_approx(signed, float(cells.size())), "%s: outline loops closed and cover %d cells" % [label, cells.size()])
		block._region_cache.clear()
		var tint: Array = block._shape_region_polygons(d, half, cs, 0.0, 0.0)
		_check(is_equal_approx(_region_area(tint) / (cs * cs), float(cells.size())), "%s: tint area = %d cells (got %.2f)" % [label, cells.size(), _region_area(tint) / (cs * cs)])
		var body: Array = block._shape_region_polygons(d, half, cs, margin, radius)
		var area := _region_area(body)
		if first_area < 0.0:
			first_area = area
		_check(absf(area - first_area) < 1.0, "%s: drawing does not depend on cell order" % label)
		_check(area > float(cells.size()) * cs * cs * 0.4, "%s: body is not collapsed (%.0f px)" % [label, area])
		var min_c := Vector2i(999, 999)
		var max_c := Vector2i(-999, -999)
		for c in cells:
			min_c = Vector2i(mini(min_c.x, c.x), mini(min_c.y, c.y))
			max_c = Vector2i(maxi(max_c.x, c.x), maxi(max_c.y, c.y))
		for y in range(min_c.y - 1, max_c.y + 2):
			for x in range(min_c.x - 1, max_c.x + 2):
				var centre := Vector2(x * cs, y * cs)
				var filled := d.has(Vector2i(x, y))
				_check(_covers(body, centre) == filled, "%s: cell %d,%d drawn=%s" % [label, x, y, filled])


func _check_outline_geometry() -> void:
	var block: Block = load("res://scenes/block.tscn").instantiate() if ResourceLoader.exists("res://scenes/block.tscn") else Block.new()
	block.block_kind = Block.BlockKind.MERGE
	block.setup(96)
	var squirrel_union: Array = []
	for c in YELLOW:
		squirrel_union.append(c)
	for c in BLUE:
		squirrel_union.append(c)
	_check_shape_draws(block, squirrel_union, "squirrel green (gap at a corner pinch)")
	var ring: Array = []
	for y in 3:
		for x in 3:
			if Vector2i(x, y) != Vector2i(1, 1):
				ring.append(Vector2i(x, y))
	_check_shape_draws(block, ring, "ring around a closed gap")
	var big_ring: Array = []
	for y in 4:
		for x in 5:
			if not (y in [1, 2] and x in [1, 2, 3]):
				big_ring.append(Vector2i(x, y))
	_check_shape_draws(block, big_ring, "ring around a 3x2 gap")
	var two_gaps: Array = []
	for y in 3:
		for x in 5:
			if not (y == 1 and x in [1, 3]):
				two_gaps.append(Vector2i(x, y))
	_check_shape_draws(block, two_gaps, "two closed gaps")
	_check_shape_draws(block, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)], "plain S (no gap)")
	_check_shape_draws(block, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2), Vector2i(0, 2)], "U with diagonal pinch")
	block.free()


# --- real Board ---------------------------------------------------------------

func _key(cells: Array) -> String:
	var a := []
	for c in cells:
		a.append("%d,%d" % [c.x, c.y])
	a.sort()
	return ";".join(a)


func _wait_board(board) -> void:
	var guard := 0
	while (board.is_busy or guard < 3) and guard < 600:
		await process_frame
		guard += 1


## Merge on the real Board and in PuzzleSim. Returns the merged cells or [].
func _merge_on_board(cfg: LevelConfig, mover_pos: Vector2i, dir: Vector2i, label: String) -> Array:
	var board = load("res://scenes/board.tscn").instantiate()
	root.add_child(board)
	await process_frame
	board.load_level(cfg)
	await process_frame
	var before: int = board.placed_blocks.size()
	var mover = null
	for b in board.placed_blocks:
		if b.grid_pos == mover_pos:
			mover = b
	if mover == null:
		_check(false, "%s: mover found" % label)
		board.queue_free()
		return []
	var lives: int = board.get_lives()
	board._unregister_block_cells(mover)
	board._commit_move(mover, mover.grid_pos, dir, 1500.0)
	await _wait_board(board)
	var merged = null
	var live := 0
	for b in board.placed_blocks:
		if is_instance_valid(b) and b.visible:
			live += 1
			if b.tile_color == Block.TileColor.GREEN:
				merged = b
	_check(live == before - 1 and merged != null, "%s: Board merged into one green piece" % label)
	_check(board.get_lives() == lives, "%s: merge costs no life" % label)
	var cells: Array = merged.get_occupied_cells() if merged != null else []
	if merged != null:
		var registered := true
		for c in cells:
			registered = registered and board.cell_occupant.get(c) == merged
		_check(registered, "%s: every merged cell is registered on the Board" % label)
		_check_shape_draws(merged, merged.shape_cells, label + " (drawn)")

	var sim = PuzzleSimScript.new()
	var st = sim.load_config(cfg)
	var idx := -1
	for i in st.blocks.size():
		if st.blocks[i].pos == mover_pos:
			idx = i
	var r: Dictionary = sim.apply_move(st, idx, dir)
	var sim_green := ""
	for sb in r.state.blocks:
		if int(sb.color) == Block.TileColor.GREEN:
			sim_green = _key(sb.occupied())
	_check(int(r.outcome) == PuzzleSimScript.Outcome.MERGE and sim_green == _key(cells), "%s: PuzzleSim agrees with the Board" % label)
	board.queue_free()
	await process_frame
	return cells


func _check_squirrel() -> void:
	var cfg: LevelConfig = load(SQUIRREL)
	var expected := []
	for c in YELLOW:
		expected.append(c + Vector2i(5, 3))
	for c in BLUE:
		expected.append(c + Vector2i(5, 3))
	var down: Array = await _merge_on_board(cfg, Vector2i(6, 3), Vector2i.DOWN, "Squirrel yellow down")
	var right: Array = await _merge_on_board(cfg, Vector2i(5, 4), Vector2i.RIGHT, "Squirrel blue right")
	_check(_key(down) == _key(expected), "Squirrel yellow down keeps all 11 cells")
	_check(_key(right) == _key(expected), "Squirrel blue right keeps all 11 cells")
	_check(_key(down) == _key(right), "Squirrel merge is the same both ways")


func _transform(cell: Vector2i, rot: int, mirror: bool) -> Vector2i:
	var c := Vector2i(-cell.x, cell.y) if mirror else cell
	for _i in rot:
		c = Vector2i(-c.y, c.x)
	return c


func _transform_dir(dir: Vector2i, rot: int, mirror: bool) -> Vector2i:
	return _transform(dir, rot, mirror)


## The Squirrel pair in all 8 orientations, each merged all 4 ways it can be
## (mover down/left into the other, other up/right back).
func _check_all_orientations() -> void:
	var moves := [
		["yellow", Vector2i.DOWN],
		["yellow", Vector2i.LEFT],
		["blue", Vector2i.RIGHT],
		["blue", Vector2i.UP],
	]
	for mirror in [false, true]:
		for rot in 4:
			var ys: Array = []
			var bs: Array = []
			for c in YELLOW:
				ys.append(_transform(c, rot, mirror))
			for c in BLUE:
				bs.append(_transform(c, rot, mirror))
			var all_cells := ys + bs
			var lo := Vector2i(999, 999)
			for c in all_cells:
				lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
			var shift := Vector2i(3, 3) - lo
			var expected: Array = []
			for c in all_cells:
				expected.append(c + shift)
			for m in moves:
				var cfg := LevelConfig.new()
				cfg.columns = 10
				cfg.rows = 10
				cfg.multi_goal_mode = true
				cfg.goal_left_enabled = false
				cfg.goal_top_enabled = false
				cfg.goal_right_enabled = false
				cfg.goal_bottom_enabled = false
				var mover_pos := Vector2i.ZERO
				for piece in [["yellow", ys, Block.TileColor.YELLOW], ["blue", bs, Block.TileColor.BLUE]]:
					var cells: Array = piece[1]
					var a := Vector2i(999, 999)
					for c in cells:
						a = Vector2i(mini(a.x, c.x), mini(a.y, c.y))
					var pattern: Array[Vector2i] = []
					for c in cells:
						pattern.append(c - a)
					cfg.block_positions.append(a + shift)
					cfg.block_colors.append(piece[2])
					cfg.block_kinds.append(Block.BlockKind.MERGE)
					cfg.block_shapes.append("single")
					cfg.block_cell_patterns.append(pattern)
					if piece[0] == m[0]:
						mover_pos = a + shift
				var dir := _transform_dir(m[1], rot, mirror)
				var label := "rot %d%s %s %s" % [rot * 90, " mirrored" if mirror else "", m[0], dir]
				var got: Array = await _merge_on_board(cfg, mover_pos, dir, label)
				_check(_key(got) == _key(expected), "%s: merged shape is the union of both pieces" % label)
