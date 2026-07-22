extends RefCounted
class_name StarChartBaker

## One-shot baker for the dimension-map sky chart.
## Renders the circular planisphere into a vertical strip covering the linear path.

## Large enough that Dimension 10 (≈ y -2700) sits well inside the circle.
const CHART_RADIUS := 3400.0
const GUIDE_RING_COUNT := 12
const GUIDE_SPOKE_COUNT := 28
const STAR_COUNT := 1100
const CONSTELLATION_COUNT := 28
const CONSTELLATION_MIN_STARS := 5
const CONSTELLATION_MAX_STARS := 9
const LINK_MIN_DIST := 45.0
const LINK_MAX_DIST := 195.0

const CHART_BG := Color(0.97, 0.97, 0.985, 1.0)
const GUIDE_COLOR := Color(0.55, 0.62, 0.78, 0.28)
const GUIDE_OUTER := Color(0.25, 0.35, 0.55, 0.45)
const STAR_COLOR := Color(0.18, 0.28, 0.48, 0.85)
const CONSTELLATION_COLOR := Color(0.22, 0.32, 0.55, 0.4)

## World-space crop covering the linear dimension path (1px = 1 world unit).
## Keep in sync with DimensionMap.STRIP_WORLD.
const STRIP_WORLD := Rect2(-560, -3600, 1120, 4300)
const OUTPUT_PATH := "res://assets/backgrounds/dimension_star_chart.jpg"


static func bake_and_save(path: String = OUTPUT_PATH) -> Error:
	var image := bake_strip_image()
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	return image.save_jpg(abs_path, 0.92)


static func bake_strip_image() -> Image:
	var w := int(STRIP_WORLD.size.x)
	var h := int(STRIP_WORLD.size.y)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(CHART_BG)

	var stars: Array[Vector2] = []
	var radii: Array[float] = []
	var links: Array[Vector2i] = []
	_build_star_field(stars, radii)
	_build_constellations(stars, links)

	_draw_guides_on_image(img)
	_draw_links_on_image(img, stars, links)
	_draw_stars_on_image(img, stars, radii)
	return img


static func strip_world_rect() -> Rect2:
	return STRIP_WORLD


static func _world_to_pixel(world: Vector2) -> Vector2:
	return world - STRIP_WORLD.position


static func _hash01(i: int, salt: int) -> float:
	var x := sin(float(i * 12.9898 + salt * 78.233)) * 43758.5453
	return x - floorf(x)


static func _build_star_field(stars: Array[Vector2], radii: Array[float]) -> void:
	stars.clear()
	radii.clear()
	for i in STAR_COUNT:
		var a := _hash01(i, 1) * TAU
		var r := lerpf(90.0, CHART_RADIUS * 0.96, pow(_hash01(i, 2), 0.72))
		stars.append(Vector2(cos(a), sin(a)) * r)
		radii.append(lerpf(1.0, 3.2, pow(_hash01(i, 3), 2.1)))


static func _build_constellations(stars: Array[Vector2], links: Array[Vector2i]) -> void:
	links.clear()
	var used: Dictionary = {}
	var built := 0
	var seed_cursor := 0
	while built < CONSTELLATION_COUNT and seed_cursor < STAR_COUNT * 3:
		var seed_i := int(_hash01(seed_cursor, 7) * float(STAR_COUNT)) % STAR_COUNT
		seed_cursor += 1
		if used.has(seed_i):
			continue
		var target := CONSTELLATION_MIN_STARS + int(
			_hash01(seed_i, 11) * float(CONSTELLATION_MAX_STARS - CONSTELLATION_MIN_STARS + 1)
		)
		target = clampi(target, CONSTELLATION_MIN_STARS, CONSTELLATION_MAX_STARS)
		var members: Array[int] = [seed_i]
		var edges: Array[Vector2i] = []
		var degree: Dictionary = {seed_i: 0}
		used[seed_i] = true

		while members.size() < target:
			var pick := _find_extension(stars, members, used, edges, links)
			if pick.x < 0:
				break
			members.append(pick.y)
			used[pick.y] = true
			edges.append(_edge(pick.x, pick.y))
			degree[pick.x] = int(degree.get(pick.x, 0)) + 1
			degree[pick.y] = int(degree.get(pick.y, 0)) + 1

		if members.size() < CONSTELLATION_MIN_STARS:
			for m in members:
				used.erase(m)
			continue

		var extra_budget := 1 + int(_hash01(seed_i, 13) * 3.0)
		for attempt in 18:
			if extra_budget <= 0:
				break
			var a_i: int = members[int(_hash01(seed_i + attempt, 17) * float(members.size())) % members.size()]
			var b_i: int = members[int(_hash01(seed_i + attempt, 19) * float(members.size())) % members.size()]
			if a_i == b_i:
				continue
			var d := stars[a_i].distance_to(stars[b_i])
			if d < LINK_MIN_DIST or d > LINK_MAX_DIST * 1.05:
				continue
			var e := _edge(a_i, b_i)
			if e in edges:
				continue
			if _link_crosses_any(stars, e, edges) or _link_crosses_any(stars, e, links):
				continue
			var deg_a := int(degree.get(a_i, 0))
			var deg_b := int(degree.get(b_i, 0))
			if deg_a < 1 and deg_b < 1:
				continue
			edges.append(e)
			degree[a_i] = deg_a + 1
			degree[b_i] = deg_b + 1
			extra_budget -= 1

		for e in edges:
			links.append(e)
		built += 1


static func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


static func _find_extension(
	stars: Array[Vector2],
	members: Array[int],
	used: Dictionary,
	edges: Array[Vector2i],
	all_links: Array[Vector2i]
) -> Vector2i:
	var prefer_branch := members.size() >= 3 and _hash01(members.size() + members[0], 29) > 0.5
	var attach_from: Array[int] = []
	if prefer_branch:
		for k in mini(3, members.size()):
			var idx := int(_hash01(members[0] + k * 17 + members.size(), 37) * float(members.size())) % members.size()
			var m: int = members[idx]
			if m not in attach_from:
				attach_from.append(m)
	else:
		attach_from.append(members[members.size() - 1])
		if members.size() >= 2 and _hash01(members.size(), 41) > 0.6:
			attach_from.append(members[members.size() - 2])

	var best_from := -1
	var best_to := -1
	var best_score := INF
	for from_i in attach_from:
		for step in 56:
			var j := (from_i * 13 + step * 17 + members.size() * 3) % STAR_COUNT
			if used.has(j):
				continue
			var d := stars[from_i].distance_to(stars[j])
			if d < LINK_MIN_DIST or d > LINK_MAX_DIST:
				continue
			var candidate := _edge(from_i, j)
			if _link_crosses_any(stars, candidate, edges):
				continue
			if _link_crosses_any(stars, candidate, all_links):
				continue
			var score := d + _hash01(j, 43) * 12.0
			if score < best_score:
				best_score = score
				best_from = from_i
				best_to = j
	return Vector2i(best_from, best_to)


static func _link_crosses_any(stars: Array[Vector2], link: Vector2i, others: Array[Vector2i]) -> bool:
	var a := stars[link.x]
	var b := stars[link.y]
	for other in others:
		if link.x == other.x or link.x == other.y or link.y == other.x or link.y == other.y:
			continue
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, stars[other.x], stars[other.y])
		if hit != null:
			return true
	return false


static func _blend_pixel(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var dst := img.get_pixel(x, y)
	var a := color.a
	img.set_pixel(x, y, Color(
		dst.r * (1.0 - a) + color.r * a,
		dst.g * (1.0 - a) + color.g * a,
		dst.b * (1.0 - a) + color.b * a,
		1.0
	))


static func _fill_circle_px(img: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var r := int(ceil(radius))
	var r2 := radius * radius
	var x0 := int(floor(cx))
	var y0 := int(floor(cy))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if float(dx * dx + dy * dy) <= r2:
				_blend_pixel(img, x0 + dx, y0 + dy, color)


static func _draw_line_px(img: Image, from_px: Vector2, to_px: Vector2, color: Color, width: float) -> void:
	var steps := maxi(1, int(from_px.distance_to(to_px)))
	var half_w := maxf(width * 0.5, 0.65)
	for i in steps + 1:
		var t := float(i) / float(steps)
		var p := from_px.lerp(to_px, t)
		_fill_circle_px(img, p.x, p.y, half_w, color)


static func _draw_guides_on_image(img: Image) -> void:
	for ring in range(1, GUIDE_RING_COUNT + 1):
		var r := CHART_RADIUS * (float(ring) / float(GUIDE_RING_COUNT))
		_draw_arc_world(img, Vector2.ZERO, r, GUIDE_COLOR, 1.25)
	_draw_arc_world(img, Vector2.ZERO, CHART_RADIUS, GUIDE_OUTER, 2.0)
	for spoke in GUIDE_SPOKE_COUNT:
		var ang := TAU * float(spoke) / float(GUIDE_SPOKE_COUNT)
		var inner := Vector2(cos(ang), sin(ang)) * 70.0
		var outer := Vector2(cos(ang), sin(ang)) * CHART_RADIUS
		_draw_line_px(img, _world_to_pixel(inner), _world_to_pixel(outer), GUIDE_COLOR, 1.0)


static func _draw_arc_world(
	img: Image,
	center: Vector2,
	radius: float,
	color: Color,
	width: float
) -> void:
	var steps := 180
	var prev := _world_to_pixel(center + Vector2(radius, 0))
	for i in range(1, steps + 1):
		var ang := TAU * float(i) / float(steps)
		var p := _world_to_pixel(center + Vector2(cos(ang), sin(ang)) * radius)
		_draw_line_px(img, prev, p, color, width)
		prev = p


static func _draw_links_on_image(img: Image, stars: Array[Vector2], links: Array[Vector2i]) -> void:
	for link in links:
		_draw_line_px(
			img,
			_world_to_pixel(stars[link.x]),
			_world_to_pixel(stars[link.y]),
			CONSTELLATION_COLOR,
			1.15
		)


static func _draw_stars_on_image(img: Image, stars: Array[Vector2], radii: Array[float]) -> void:
	for i in stars.size():
		var p := _world_to_pixel(stars[i])
		_fill_circle_px(img, p.x, p.y, radii[i], STAR_COLOR)
