extends Control
class_name TutorialIcon

## Small drawn diagram for a tutorial step (blocks, goal bars, arrows). Rows are
## data-driven: a step lists icons as { "kind", "a", "b", "r", "height" } and
## TutorialWalkthrough builds one of these per entry.
##
##   merge   block + block -> blended block (a, b -> r)        [Colour Mix]
##   nomerge mixed blocks do not blend again (a, b)             [Colour Mix]
##   mismatch block cannot enter a goal of another colour (a, r)
##   swipe   block swiped toward a matching goal bar (a)
##   goals   board with four coloured goal bars
##   lives   three hearts, one lost
##   chevrons goal bar + chevrons showing the next goal colour (a -> b)
##   goal_list sequence of upcoming goal colours (a, b, r)
##   walls   wall blocks the straight path, detour around it
##   bigger  small board growing into a large one

var kind: String = "merge"
var a: int = Block.TileColor.RED
var b: int = Block.TileColor.YELLOW
var r: int = Block.TileColor.ORANGE
var plated: bool = true


static func make(spec: Dictionary) -> TutorialIcon:
	var icon := TutorialIcon.new()
	icon.kind = str(spec.get("kind", "merge"))
	icon.a = int(spec.get("a", Block.TileColor.RED))
	icon.b = int(spec.get("b", Block.TileColor.YELLOW))
	icon.r = int(spec.get("r", Block.TileColor.ORANGE))
	icon.plated = bool(spec.get("plate", true))
	icon.custom_minimum_size = Vector2(float(spec.get("width", 0.0)), float(spec.get("height", 120.0)))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if float(spec.get("width", 0.0)) <= 0.0:
		icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return icon


func _draw() -> void:
	if plated:
		TutorialArt.plate(self, Rect2(Vector2.ZERO, size))
	var c := size * 0.5
	match kind:
		"merge":
			_draw_merge(c)
		"nomerge":
			_draw_nomerge(c)
		"mismatch":
			_draw_mismatch(c)
		"swipe":
			_draw_swipe(c)
		"goals":
			_draw_goals(c)
		"lives":
			_draw_lives(c)
		"chevrons":
			_draw_chevrons(c)
		"goal_list":
			_draw_goal_list(c)
		"walls":
			_draw_walls(c)
		"bigger":
			_draw_bigger(c)


func _cell() -> float:
	return minf(size.y - 28.0, 92.0)


## [A] >> [B] => [R]
func _draw_merge(c: Vector2) -> void:
	var cs := _cell()
	var y0 := c.y - cs * 0.5
	var total := cs * 3.0 + 70.0 + 96.0
	var x := c.x - total * 0.5
	TutorialArt.block(self, Vector2(x, y0), cs, a)
	TutorialArt.chevrons(self, Vector2(x + cs + 35.0, c.y), Vector2.RIGHT, 2, TutorialArt.CHEVRON_WHITE, 14.0, 18.0)
	x += cs + 70.0
	TutorialArt.block(self, Vector2(x, y0), cs, b)
	var ax := x + cs + 14.0
	TutorialArt.arrow(self, Vector2(ax, c.y), Vector2(ax + 68.0, c.y), TutorialArt.ARROW_GOLD)
	TutorialArt.block(self, Vector2(x + cs + 96.0, y0), cs, r)


## [A] >> [B] =x=> (ghost): the blend does not happen again.
func _draw_nomerge(c: Vector2) -> void:
	var cs := _cell()
	var y0 := c.y - cs * 0.5
	var total := cs * 3.0 + 70.0 + 96.0
	var x := c.x - total * 0.5
	TutorialArt.block(self, Vector2(x, y0), cs, a)
	TutorialArt.chevrons(self, Vector2(x + cs + 35.0, c.y), Vector2.RIGHT, 2, TutorialArt.CHEVRON_WHITE, 14.0, 18.0)
	x += cs + 70.0
	TutorialArt.block(self, Vector2(x, y0), cs, b)
	var ax := x + cs + 14.0
	var dim_gold := TutorialArt.ARROW_GOLD
	dim_gold.a = 0.45
	TutorialArt.arrow(self, Vector2(ax, c.y), Vector2(ax + 68.0, c.y), dim_gold)
	## Empty ghost cell where a blended block would have appeared.
	var gx := x + cs + 96.0
	var ghost := Rect2(Vector2(gx, y0), Vector2(cs, cs)).grow(-maxf(3.0, cs * Block.CELL_EDGE_MARGIN_RATIO))
	var step := 12.0
	var edge := Color(1, 1, 1, 0.35)
	var k := 0.0
	while k < ghost.size.x:
		var seg := minf(6.0, ghost.size.x - k)
		draw_line(ghost.position + Vector2(k, 0), ghost.position + Vector2(k + seg, 0), edge, 3.0)
		draw_line(ghost.position + Vector2(k, ghost.size.y), ghost.position + Vector2(k + seg, ghost.size.y), edge, 3.0)
		draw_line(ghost.position + Vector2(0, k), ghost.position + Vector2(0, k + seg), edge, 3.0)
		draw_line(ghost.position + Vector2(ghost.size.x, k), ghost.position + Vector2(ghost.size.x, k + seg), edge, 3.0)
		k += step
	TutorialArt.cross(self, Vector2(ax + 34.0, c.y), 18.0, TutorialArt.WARN)


## [A] >> |goal of colour R| with a cross: wrong colour does not fit.
func _draw_mismatch(c: Vector2) -> void:
	var cs := _cell()
	var y0 := c.y - cs * 0.5
	var total := cs + 150.0 + 28.0
	var x := c.x - total * 0.5
	TutorialArt.block(self, Vector2(x, y0), cs, a, false)
	TutorialArt.chevrons(self, Vector2(x + cs + 50.0, c.y), Vector2.RIGHT, 3, TutorialArt.CHEVRON_WHITE, 16.0, 26.0)
	var bar := Rect2(x + cs + 130.0, 14.0, 28.0, size.y - 28.0)
	TutorialArt.goal_bar(self, bar, r)
	TutorialArt.cross(self, Vector2(bar.position.x - 40.0, c.y), 18.0, TutorialArt.WARN)


func _draw_swipe(c: Vector2) -> void:
	var cs := minf(size.y - 40.0, 112.0)
	var y0 := c.y - cs * 0.5
	TutorialArt.block(self, Vector2(40.0, y0), cs, a, false)
	TutorialArt.chevrons(self, Vector2(size.x * 0.45, c.y), Vector2.RIGHT, 3, Color(0.86, 0.88, 0.94, 0.95), 20.0, 30.0)
	var bar := Rect2(size.x - 38.0, 14.0, 16.0, size.y - 28.0)
	TutorialArt.goal_bar(self, bar, a)
	var col := Block.get_color(a as Block.TileColor)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = col.darkened(0.3)
	bsb.border_color = col
	bsb.set_border_width_all(2)
	bsb.set_corner_radius_all(22)
	draw_style_box(bsb, Rect2(bar.position.x - 112.0, c.y - 22.0, 92.0, 44.0))
	TutorialArt.glyph(self, "0/3", Vector2(bar.position.x - 66.0, c.y), 28, Color.WHITE)


func _draw_goals(c: Vector2) -> void:
	var bs := minf(size.y - 56.0, 190.0)
	var o := c - Vector2(bs, bs) * 0.5
	draw_rect(Rect2(o, Vector2(bs, bs)), Color(0.16, 0.10, 0.28, 0.9))
	draw_rect(Rect2(o, Vector2(bs, bs)), TutorialArt.PLATE_EDGE, false, 2.0)
	var t := 14.0
	TutorialArt.goal_bar(self, Rect2(o.x - t - 4.0, o.y, t, bs), Block.TileColor.BLUE)
	TutorialArt.goal_bar(self, Rect2(o.x + bs + 4.0, o.y, t, bs), Block.TileColor.YELLOW)
	TutorialArt.goal_bar(self, Rect2(o.x, o.y - t - 4.0, bs, t), Block.TileColor.RED)
	TutorialArt.goal_bar(self, Rect2(o.x, o.y + bs + 4.0, bs, t), Block.TileColor.GREEN)
	var q := bs * 0.35
	var pad := bs * 0.11
	var far := bs - pad - q
	TutorialArt.block(self, o + Vector2(pad, pad), q, Block.TileColor.RED, false)
	TutorialArt.block(self, o + Vector2(far, pad), q, Block.TileColor.YELLOW, false)
	TutorialArt.block(self, o + Vector2(pad, far), q, Block.TileColor.BLUE, false)
	TutorialArt.block(self, o + Vector2(far, far), q, Block.TileColor.GREEN, false)
	TutorialArt.chevrons(self, o + Vector2(pad + q * 0.5, -2.0), Vector2.UP, 1, Color(1, 1, 1, 0.9), 9.0, 10.0)


func _draw_lives(c: Vector2) -> void:
	var hs := minf(size.y - 28.0, 64.0)
	var gap := 22.0
	var total := hs * 3.0 + gap * 2.0
	var x := c.x - total * 0.5 + hs * 0.5
	for i in 3:
		var col := LivesHearts.HEART_RED if i < 2 else LivesHearts.HEART_GREY
		FaVector.draw_named(self, "heart", Vector2(x + i * (hs + gap), c.y), hs, col)


## Goal bar of colour A, chevrons in colour B (what comes next), then bar B.
func _draw_chevrons(c: Vector2) -> void:
	var bh := size.y - 36.0
	var total := 28.0 + 190.0 + 28.0
	var x := c.x - total * 0.5
	TutorialArt.goal_bar(self, Rect2(x, c.y - bh * 0.5, 28.0, bh), a)
	var next_col := Block.get_color(b as Block.TileColor)
	TutorialArt.chevrons(self, Vector2(x + 28.0 + 95.0, c.y), Vector2.RIGHT, 4, next_col.lightened(0.15), 16.0, 30.0)
	var bar2 := Rect2(x + 28.0 + 190.0, c.y - bh * 0.5, 28.0, bh)
	var ghost_col := next_col
	ghost_col.a = 0.45
	draw_rect(bar2, ghost_col)


func _draw_goal_list(c: Vector2) -> void:
	var cols := [a, b, r]
	var chip := minf(size.y - 40.0, 52.0)
	var gap := 54.0
	var total := chip * 3.0 + gap * 2.0
	var x := c.x - total * 0.5
	for i in 3:
		var rect := Rect2(x + i * (chip + gap), c.y - chip * 0.5, chip, chip)
		var col := Block.get_color(int(cols[i]) as Block.TileColor)
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(12)
		draw_style_box(sb, rect)
		if i < 2:
			TutorialArt.chevrons(self, Vector2(rect.end.x + gap * 0.5, c.y), Vector2.RIGHT, 1, TutorialArt.MUTED, 12.0, 0.0)


func _draw_walls(c: Vector2) -> void:
	var cs := minf((size.y - 24.0) / 3.0, 74.0)
	var gx := c.x - cs * 2.0
	var gy := c.y - cs * 1.5
	TutorialArt.wall(self, Vector2(gx + cs, gy), cs)
	TutorialArt.wall(self, Vector2(gx + cs, gy + cs), cs)
	TutorialArt.block(self, Vector2(gx, gy + cs), cs, Block.TileColor.RED, false)
	var cc := Vector2(gx + cs * 0.5, gy + cs * 1.5)
	TutorialArt.chevrons(self, Vector2(gx + cs, gy + cs * 1.5), Vector2.RIGHT, 1, TutorialArt.WARN, 13.0)
	var pts := PackedVector2Array([
		cc + Vector2(0, cs * 0.5), Vector2(cc.x, gy + cs * 2.5),
		Vector2(gx + cs * 2.5, gy + cs * 2.5), Vector2(gx + cs * 2.5, gy + cs * 1.62),
	])
	draw_polyline(pts, Color(1, 1, 1, 0.9), 7.0, true)
	var tip := Vector2(gx + cs * 2.5, gy + cs * 1.45)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-17, 26), tip + Vector2(17, 26)]), Color(1, 1, 1, 0.9))
	TutorialArt.goal_bar(self, Rect2(gx + cs * 3.0 + 12.0, gy, 14.0, cs * 3.0), Block.TileColor.RED)


## 3x3 board -> arrow -> 6x6 board of mixed blocks.
func _draw_bigger(c: Vector2) -> void:
	var small := 3
	var big := 6
	var sc := 34.0
	var bc := minf((size.y - 24.0) / float(big), 34.0)
	var sw := small * sc
	var bw := big * bc
	var gap := 64.0
	var total := sw + gap + bw
	var x := c.x - total * 0.5
	var palette := [Block.TileColor.RED, Block.TileColor.BLUE, Block.TileColor.YELLOW, Block.TileColor.GREEN, Block.TileColor.PURPLE, Block.TileColor.ORANGE]
	_mini_board(Vector2(x, c.y - sw * 0.5), small, sc, palette, 0)
	TutorialArt.arrow(self, Vector2(x + sw + 12.0, c.y), Vector2(x + sw + gap - 12.0, c.y), TutorialArt.ARROW_GOLD, 10.0, 24.0)
	_mini_board(Vector2(x + sw + gap, c.y - bw * 0.5), big, bc, palette, 2)


func _mini_board(origin: Vector2, n: int, cs: float, palette: Array, seed_offset: int) -> void:
	var span := n * cs
	draw_rect(Rect2(origin, Vector2(span, span)), Color(0.16, 0.10, 0.28, 0.9))
	for gy in n:
		for gx in n:
			if (gx * 3 + gy * 5 + seed_offset) % 4 == 0:
				continue
			var tile: int = palette[(gx * 2 + gy * 3 + seed_offset) % palette.size()]
			TutorialArt.block(self, origin + Vector2(gx, gy) * cs, cs, tile, false)
	draw_rect(Rect2(origin, Vector2(span, span)), TutorialArt.PLATE_EDGE, false, 2.0)
