extends RefCounted
class_name FaVector

## HUD + map icons: Font Awesome 4.7 webfont via draw_string.
## Map award stars stay custom polygons.

const LOCK_STEEL := Color(0.46, 0.50, 0.56, 1.0)

const FA_FONT: Font = preload("res://assets/fonts/FontAwesome.otf")

const FA_CHARS := {
	"arrow-left": "\uf060",
	"arrow-right": "\uf061",
	"refresh": "\uf021",
	"undo": "\uf0e2",
	"bullseye": "\uf140",
	"play": "\uf04b",
	"floppy-disk": "\uf0c7",
	"save": "\uf0c7",
	"xmark": "\uf00d",
	"gear": "\uf013",
	"angles-right": "\uf101",
	"chevron-right": "\uf054",
	"chevron-down": "\uf078",
	"lock": "\uf023",
	"check": "\uf00c",
	"star": "\uf005",
	"heart": "\uf004",
	"pencil": "\uf040",
	"plus": "\uf067",
	"trash": "\uf1f8",
	"bars": "\uf0c9",
}


static func draw_lock(item: CanvasItem, center: Vector2, height: float, fill: Color = LOCK_STEEL) -> void:
	_draw_fa_char(item, "lock", center, height, fill, 2.0, 1.0)


static func draw_check(item: CanvasItem, center: Vector2, height: float, fill: Color = Color(0.95, 0.78, 0.2, 1.0)) -> void:
	_draw_fa_char(item, "check", center, height, fill, 2.0, 1.0)


static func draw_star(
	item: CanvasItem,
	center: Vector2,
	height: float,
	fill: Color = Color(0.95, 0.78, 0.2, 1.0),
	black_w: float = 0.0,
	white_w: float = 0.0
) -> void:
	_draw_fa_char(item, "star", center, height, fill, black_w, white_w)


static func award_star_points(center: Vector2, radius: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 5:
		var outer_a := -PI * 0.5 + float(i) * TAU / 5.0
		pts.append(center + Vector2(cos(outer_a), sin(outer_a)) * radius)
		var inner_a := outer_a + TAU / 10.0
		pts.append(center + Vector2(cos(inner_a), sin(inner_a)) * radius * 0.42)
	return pts


static func draw_award_star(
	item: CanvasItem,
	center: Vector2,
	radius: float,
	black_w: float = 2.0,
	white_w: float = 1.0
) -> void:
	## Map camera-zoom path: hairline rims (looks sharp when zoomed ~2.35×).
	var pts := award_star_points(center, radius)
	item.draw_colored_polygon(pts, Color(0.95, 0.78, 0.2, 1.0))
	item.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.15, 0.12, 0.08, 0.85), black_w, true)
	item.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.9), white_w, true)


static func draw_award_star_hud(item: CanvasItem, center: Vector2, radius: float) -> void:
	## Same star as the map, but rims are filled offsets so 1:1 UI pixels stay sharp.
	var gold := award_star_points(center, radius)
	var black_out := Geometry2D.offset_polygon(gold, maxf(radius * 0.18, 2.4))
	var white_out := Geometry2D.offset_polygon(gold, maxf(radius * 0.09, 1.2))
	if not black_out.is_empty():
		item.draw_colored_polygon(black_out[0], Color(0.15, 0.12, 0.08, 0.9))
	if not white_out.is_empty():
		item.draw_colored_polygon(white_out[0], Color(1, 1, 1, 0.95))
	item.draw_colored_polygon(gold, Color(0.95, 0.78, 0.2, 1.0))


static func draw_named(item: CanvasItem, name: String, center: Vector2, height: float, fill: Color) -> void:
	if name == "lock" or name == "check":
		_draw_fa_char(item, name, center, height, fill, 2.0, 1.0)
		return
	_draw_fa_char(item, name, center, height, fill)


static func _draw_fa_char(
	item: CanvasItem,
	name: String,
	center: Vector2,
	height: float,
	fill: Color,
	black_w: float = 0.0,
	white_w: float = 0.0
) -> void:
	if not FA_CHARS.has(name):
		push_warning("FaVector: unknown icon '%s'" % name)
		return
	var ch: String = FA_CHARS[name]
	var fs := maxi(12, int(round(height)))
	var sz := FA_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var pos := Vector2(center.x - sz.x * 0.5, center.y - sz.y * 0.5 + FA_FONT.get_ascent(fs))
	if black_w > 0.0:
		item.draw_string_outline(
			FA_FONT, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			maxi(1, int(round(black_w + white_w))),
			Color(0.15, 0.12, 0.08, 0.9)
		)
	if white_w > 0.0:
		item.draw_string_outline(
			FA_FONT, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			maxi(1, int(round(white_w))),
			Color(1, 1, 1, 0.95)
		)
	item.draw_string(FA_FONT, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)
