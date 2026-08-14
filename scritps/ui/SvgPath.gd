extends RefCounted
class_name SvgPath

## Tessellate an SVG path `d` into closed vector contours (Font Awesome glyphs).
## Godot imports .svg as bitmaps; drawing these polygons stays crisp at any scale.


static func contours(d: String, curve_steps: int = 12) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var cur := PackedVector2Array()
	var i := 0
	var chars := d.strip_edges()
	var n := chars.length()
	var pos := Vector2.ZERO
	var start := Vector2.ZERO
	var last_cubic := Vector2.ZERO
	var last_quad := Vector2.ZERO
	var cmd := ""
	while i < n:
		var ch := chars[i]
		if _is_command(ch):
			cmd = ch
			i += 1
			continue
		if ch == " " or ch == "," or ch == "\n" or ch == "\t":
			i += 1
			continue
		match cmd:
			"M", "m":
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var mv: Vector2 = p["v"]
				pos = mv if cmd == "M" else pos + mv
				if not cur.is_empty():
					out.append(cur)
				cur = PackedVector2Array()
				cur.append(pos)
				start = pos
				cmd = "L" if cmd == "M" else "l"
			"L", "l":
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var lv: Vector2 = p["v"]
				pos = lv if cmd == "L" else pos + lv
				cur.append(pos)
			"H", "h":
				var r := _read_num(chars, i)
				i = int(r["i"])
				var hx := float(r["v"])
				pos.x = hx if cmd == "H" else pos.x + hx
				cur.append(pos)
			"V", "v":
				var r := _read_num(chars, i)
				i = int(r["i"])
				var vy := float(r["v"])
				pos.y = vy if cmd == "V" else pos.y + vy
				cur.append(pos)
			"C", "c":
				var c1 := _read_vec(chars, i)
				i = int(c1["i"])
				var c2 := _read_vec(chars, i)
				i = int(c2["i"])
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var c1v: Vector2 = c1["v"]
				var c2v: Vector2 = c2["v"]
				var pv: Vector2 = p["v"]
				var p1: Vector2 = c1v if cmd == "C" else pos + c1v
				var p2: Vector2 = c2v if cmd == "C" else pos + c2v
				var p3: Vector2 = pv if cmd == "C" else pos + pv
				_append_cubic(cur, pos, p1, p2, p3, curve_steps)
				last_cubic = p2
				pos = p3
			"S", "s":
				var c2 := _read_vec(chars, i)
				i = int(c2["i"])
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var c2v: Vector2 = c2["v"]
				var pv: Vector2 = p["v"]
				var p1: Vector2 = pos * 2.0 - last_cubic
				var p2: Vector2 = c2v if cmd == "S" else pos + c2v
				var p3: Vector2 = pv if cmd == "S" else pos + pv
				_append_cubic(cur, pos, p1, p2, p3, curve_steps)
				last_cubic = p2
				pos = p3
			"Q", "q":
				var c1 := _read_vec(chars, i)
				i = int(c1["i"])
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var c1v: Vector2 = c1["v"]
				var pv: Vector2 = p["v"]
				var ctrl: Vector2 = c1v if cmd == "Q" else pos + c1v
				var dest: Vector2 = pv if cmd == "Q" else pos + pv
				_append_quadratic(cur, pos, ctrl, dest, curve_steps)
				last_quad = ctrl
				pos = dest
			"T", "t":
				var p := _read_vec(chars, i)
				i = int(p["i"])
				var pv: Vector2 = p["v"]
				var ctrl: Vector2 = pos * 2.0 - last_quad
				var dest: Vector2 = pv if cmd == "T" else pos + pv
				_append_quadratic(cur, pos, ctrl, dest, curve_steps)
				last_quad = ctrl
				pos = dest
			"Z", "z":
				if cur.size() >= 2:
					cur.append(start)
				out.append(cur)
				cur = PackedVector2Array()
				pos = start
			_:
				i += 1
	if cur.size() >= 2:
		out.append(cur)
	return out


static func draw_icon(
	item: CanvasItem,
	d: String,
	view: Vector2,
	center: Vector2,
	height: float,
	fill: Color,
	double_rim: bool = false
) -> void:
	var raw := contours(d)
	if raw.is_empty() or view.y <= 0.0:
		return
	var s := height / view.y
	var scaled: Array[PackedVector2Array] = []
	for contour in raw:
		var pts := PackedVector2Array()
		for p in contour:
			pts.append(center + (p - view * 0.5) * s)
		scaled.append(pts)
	var pieces: Array = []
	if scaled.size() >= 2:
		pieces = Geometry2D.clip_polygons(scaled[1], scaled[0])
		if pieces.is_empty():
			pieces = Geometry2D.clip_polygons(scaled[0], scaled[1])
	if pieces.is_empty():
		pieces = [scaled[scaled.size() - 1]]
	var black := Color(0.15, 0.12, 0.08, 0.9)
	var white := Color(1, 1, 1, 0.95)
	for poly_v in pieces:
		var poly: PackedVector2Array = poly_v
		if poly.size() < 3:
			continue
		item.draw_colored_polygon(poly, fill)
		var closed := poly
		if closed[0] != closed[closed.size() - 1]:
			closed = closed + PackedVector2Array([closed[0]])
		if double_rim:
			item.draw_polyline(closed, black, 2.0, true)
			item.draw_polyline(closed, white, 1.0, true)
		else:
			item.draw_polyline(closed, fill, 1.0, true)


static func _is_command(ch: String) -> bool:
	return ch in "MmLlHhVvCcSsQqTtAaZz"


static func _read_num(s: String, i: int) -> Dictionary:
	while i < s.length() and (s[i] == " " or s[i] == "," or s[i] == "\n"):
		i += 1
	var start := i
	if i < s.length() and (s[i] == "-" or s[i] == "+"):
		i += 1
	while i < s.length() and (s[i] >= "0" and s[i] <= "9" or s[i] == "."):
		i += 1
	if i < s.length() and (s[i] == "e" or s[i] == "E"):
		i += 1
		if i < s.length() and (s[i] == "-" or s[i] == "+"):
			i += 1
		while i < s.length() and s[i] >= "0" and s[i] <= "9":
			i += 1
	return {"v": float(s.substr(start, i - start)), "i": i}


static func _read_vec(s: String, i: int) -> Dictionary:
	var x := _read_num(s, i)
	var y := _read_num(s, int(x["i"]))
	return {"v": Vector2(float(x["v"]), float(y["v"])), "i": int(y["i"])}


static func _append_cubic(
	cur: PackedVector2Array,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	steps: int
) -> void:
	for k in range(1, steps + 1):
		var t := float(k) / float(steps)
		var u := 1.0 - t
		cur.append(
			p0 * (u * u * u)
			+ p1 * (3.0 * u * u * t)
			+ p2 * (3.0 * u * t * t)
			+ p3 * (t * t * t)
		)


static func _append_quadratic(
	cur: PackedVector2Array,
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	steps: int
) -> void:
	for k in range(1, steps + 1):
		var t := float(k) / float(steps)
		var u := 1.0 - t
		cur.append(p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t))
