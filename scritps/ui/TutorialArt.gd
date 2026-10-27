extends RefCounted
class_name TutorialArt

## Shared drawing helpers for the tutorial icons. Blocks match Block.gd's look
## (translucent cell tint + rounded body + shine) so diagrams read as the real game.

const PLATE_FILL := Color(0.09, 0.06, 0.17, 0.92)
const PLATE_EDGE := Color(0.82, 0.68, 0.28, 0.7)
const ARROW_GOLD := Color(0.82, 0.68, 0.28)
const CHEVRON_WHITE := Color(1, 1, 1, 0.85)
const MUTED := Color(1, 1, 1, 0.8)
const WARN := Color(0.95, 0.35, 0.35)


static func plate(ci: CanvasItem, rect: Rect2) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PLATE_FILL
	sb.border_color = PLATE_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	ci.draw_style_box(sb, rect)


## A game block. `merge` draws the glossy mergeable look; otherwise the flat standard block.
static func block(ci: CanvasItem, at: Vector2, cell: float, tile: int, merge: bool = true) -> void:
	var col := Block.get_color(tile as Block.TileColor)
	var rect := Rect2(at, Vector2(cell, cell))
	var tint := col
	tint.a = Block.MERGE_TINT_ALPHA if merge else Block.CELL_TINT_ALPHA
	ci.draw_rect(rect, tint)
	var margin := maxf(3.0, cell * Block.CELL_EDGE_MARGIN_RATIO)
	var body := rect.grow(-margin)
	var rad := maxf(Block.MERGE_CORNER_RADIUS_MIN, cell * Block.MERGE_CORNER_RADIUS_RATIO)
	rad = minf(rad, maxf(2.0, margin - 1.5))
	Block._draw_rounded_rect_filled(ci, body, col, rad)
	if merge:
		Block._draw_merge_shine_on_polygon(ci, Block._rounded_rect_points(body, rad), col, 600.0)


static func wall(ci: CanvasItem, at: Vector2, cell: float) -> void:
	var rect := Rect2(at, Vector2(cell, cell))
	ci.draw_rect(rect, Block.WALL_TINT)
	var margin := maxf(3.0, cell * Block.CELL_EDGE_MARGIN_RATIO)
	ci.draw_rect(rect.grow(-margin), Block.WALL_FILL)


static func glyph(ci: CanvasItem, text: String, center: Vector2, font_size: int, col: Color) -> void:
	var f: Font = UiTheme.BUTTON_FONT
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(
		f,
		Vector2(center.x - w * 0.5, center.y + f.get_ascent(font_size) * 0.5 - font_size * 0.06),
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col
	)


static func arrow(ci: CanvasItem, from: Vector2, to: Vector2, col: Color, width: float = 14.0, head: float = 30.0) -> void:
	var d := (to - from).normalized()
	var n := Vector2(-d.y, d.x)
	var base := to - d * head
	ci.draw_line(from, base + d * 2.0, col, width, true)
	ci.draw_colored_polygon(PackedVector2Array([to, base + n * head * 0.62, base - n * head * 0.62]), col)


static func chevrons(ci: CanvasItem, center: Vector2, dir: Vector2, count: int, col: Color, size: float = 14.0, gap: float = 18.0) -> void:
	var n := Vector2(-dir.y, dir.x)
	for i in count:
		var c := center + dir * (float(i) - (count - 1) * 0.5) * gap
		ci.draw_polyline(
			PackedVector2Array([c - dir * size * 0.5 + n * size, c + dir * size * 0.5, c - dir * size * 0.5 - n * size]),
			col, 6.0, true
		)


## Striped goal bar like GoalBorder's, drawn on `rect` (long side picks the orientation).
static func goal_bar(ci: CanvasItem, rect: Rect2, tile: int) -> void:
	var col := Block.get_color(tile as Block.TileColor)
	ci.draw_rect(rect, col)
	var vertical := rect.size.y >= rect.size.x
	var length := rect.size.y if vertical else rect.size.x
	var k := 0.0
	while k < length:
		var seg := minf(13.5, length - k)
		var r := Rect2(rect.position.x, rect.position.y + k, rect.size.x, seg) if vertical else Rect2(rect.position.x + k, rect.position.y, seg, rect.size.y)
		ci.draw_rect(r, col.lightened(0.25))
		k += 27.0


static func cross(ci: CanvasItem, center: Vector2, radius: float, col: Color, width: float = 9.0) -> void:
	ci.draw_line(center + Vector2(-radius, -radius), center + Vector2(radius, radius), col, width, true)
	ci.draw_line(center + Vector2(-radius, radius), center + Vector2(radius, -radius), col, width, true)
