extends Node2D

## Dimension progression map over a baked planisphere strip background.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const DIMENSION_LEVELS_SCENE := "res://scenes/ui/dimension_levels.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/dimension_star_chart.jpg"
## Must match StarChartBaker.STRIP_WORLD (bake crop alignment).
const STRIP_WORLD := Rect2(-560, -3600, 1120, 4300)

const ZOOM_MIN := 0.75
const ZOOM_MAX := 5.5
const WHEEL_ZOOM_STEP := 0.15
const INTRO_ZOOM_START := 2.4
const INTRO_ZOOM_END := 3.6
const INTRO_ZOOM_DURATION := 0.9

const DIAMOND_SIZE := 72.0
const LINE_WIDTH := 2.5
const DASH_LEN := 14.0
const GAP_LEN := 10.0

const CHART_BG := Color(0.97, 0.97, 0.985, 1.0)
const STAR_COLOR := Color(0.18, 0.28, 0.48, 0.85)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const LOCK_ICON := preload("res://assets/icons/lock_icon.svg")

## Pan coast: higher friction = snappier stop; stop speed is world-units/sec.
const PAN_FRICTION := 7.5
const PAN_STOP_SPEED := 12.0
const PAN_MAX_SPEED := 4200.0

@onready var camera: Camera2D = $Camera2D
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %HintLabel

var _positions: Array[Vector2] = []
var _star_chart_tex: Texture2D
var _map_font: Font
var _intro_tween: Tween
var _intro_playing := false
var _panning := false
var _pan_velocity := Vector2.ZERO


func _ready() -> void:
	_map_font = MAP_FONT
	_positions = LevelCatalog.build_dimension_positions(300.0)
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked star chart at %s — run bake_star_chart.gd" % STAR_CHART_PATH)
	if not LevelCatalog.is_dimension_unlocked(GameSession.current_dimension_index):
		GameSession.set_current_dimension(_focus_dimension_index())
	camera.make_current()
	back_button.pressed.connect(_on_back_pressed)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	back_button.text = "  " + tr("UI_BACK")
	hint_label.text = tr("UI_DIMENSION_MAP_HINT")
	UiTheme.style_menu_hint(hint_label)
	hint_label.add_theme_color_override("font_color", Color(0.25, 0.35, 0.55, 0.85))
	queue_redraw()
	await get_tree().process_frame
	_play_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		back_button.text = "  " + tr("UI_BACK")
		hint_label.text = tr("UI_DIMENSION_MAP_HINT")
		queue_redraw()


func _play_intro() -> void:
	_intro_playing = true
	var focus_i := _focus_dimension_index()
	var focus := _positions[focus_i] if not _positions.is_empty() else Vector2.ZERO
	camera.position = focus
	camera.zoom = Vector2(INTRO_ZOOM_START, INTRO_ZOOM_START)
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(_set_intro_zoom, INTRO_ZOOM_START, INTRO_ZOOM_END, INTRO_ZOOM_DURATION)
	_intro_tween.tween_callback(func(): _intro_playing = false)


func _focus_dimension_index() -> int:
	var preferred := clampi(GameSession.current_dimension_index, 0, maxi(_positions.size() - 1, 0))
	if LevelCatalog.is_dimension_unlocked(preferred):
		return preferred
	for i in range(_positions.size() - 1, -1, -1):
		if LevelCatalog.is_dimension_unlocked(i):
			return i
	return 0


func _set_intro_zoom(z: float) -> void:
	camera.zoom = Vector2(z, z)


func _world_mouse() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_mouse_position()


func _process(delta: float) -> void:
	if _intro_playing or _panning:
		return
	if _pan_velocity.length_squared() < PAN_STOP_SPEED * PAN_STOP_SPEED:
		_pan_velocity = Vector2.ZERO
		set_process(false)
		return
	camera.position += _pan_velocity * delta
	_pan_velocity *= exp(-PAN_FRICTION * delta)


func _apply_pan_delta(screen_delta: Vector2) -> void:
	var world_delta := -screen_delta / camera.zoom.x
	camera.position += world_delta
	var dt := maxf(get_process_delta_time(), 0.0001)
	var sample := (world_delta / dt).limit_length(PAN_MAX_SPEED)
	_pan_velocity = _pan_velocity.lerp(sample, 0.55)
	set_process(true)


func _draw() -> void:
	## Soft fill outside the strip so pan/zoom never shows void.
	var extent := 4000.0
	draw_rect(Rect2(-extent, -extent, extent * 2.0, extent * 2.0), CHART_BG, true)
	if _star_chart_tex != null:
		draw_texture_rect(_star_chart_tex, STRIP_WORLD, false)

	for i in _positions.size():
		var parent_i := LevelCatalog.get_dimension_parent(i)
		if parent_i < 0:
			continue
		var from_c: Vector2 = _positions[parent_i]
		var to_c: Vector2 = _positions[i]
		var from_p := _diamond_edge_point(from_c, to_c)
		var to_p := _diamond_edge_point(to_c, from_c)
		var col := LevelCatalog.get_dimension_color(i)
		if LevelCatalog.is_dimension_unlocked(i):
			draw_line(from_p, to_p, col, LINE_WIDTH, true)
		else:
			_draw_dashed_line(from_p, to_p, col.lightened(0.15), LINE_WIDTH)

	var progress := _furthest_unlocked_dimension()
	for i in _positions.size():
		var pos: Vector2 = _positions[i]
		var theme := LevelCatalog.get_dimension_color(i)
		var unlocked := LevelCatalog.is_dimension_unlocked(i)
		var is_current := i == progress
		_draw_diamond(pos, DIAMOND_SIZE, theme, is_current, unlocked)
		_draw_dimension_label(pos, i, theme, is_current, unlocked)
		if is_current:
			_draw_current_badge(pos)


func _furthest_unlocked_dimension() -> int:
	var best := 0
	for i in _positions.size():
		if LevelCatalog.is_dimension_unlocked(i):
			best = i
	return best


func _diamond_edge_point(center: Vector2, toward: Vector2) -> Vector2:
	var dir := toward - center
	if dir.length_squared() < 0.0001:
		return center
	dir = dir.normalized()
	var half := DIAMOND_SIZE * 0.5 + LINE_WIDTH * 0.5 + 1.0
	var t := half / (absf(dir.x) + absf(dir.y))
	return center + dir * t


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


func _draw_diamond(center: Vector2, size: float, theme: Color, is_current: bool, unlocked: bool) -> void:
	var pts := _diamond_points(center, size)
	var outline := pts + PackedVector2Array([pts[0]])
	if is_current:
		_draw_current_glow(center, size)
		draw_colored_polygon(pts, LevelCatalog.PRIMARY_BLUE)
		draw_polyline(outline, Color(1, 1, 1, 0.95), 3.0, true)
	elif unlocked:
		draw_polyline(outline, theme, 4.0, true)
	else:
		draw_polyline(outline, theme.lightened(0.25), 3.0, true)
	var hub_r := 3.5
	draw_circle(center, hub_r + 1.6, Color(1, 1, 1, 1))
	draw_circle(center, hub_r, STAR_COLOR)
	if not unlocked:
		## Sit on the diamond's top-right corner (not centered over the hub).
		_draw_lock_icon(center + Vector2(size * 0.28, -size * 0.28))


func _draw_current_glow(center: Vector2, size: float) -> void:
	## Static bloom — no per-frame redraw. Soft outer haze + bright rim.
	var blue := LevelCatalog.PRIMARY_BLUE
	var outer := _diamond_points(center, size * 1.7)
	draw_colored_polygon(outer, Color(blue.r, blue.g, blue.b, 0.08))
	var mid := _diamond_points(center, size * 1.35)
	draw_colored_polygon(mid, Color(blue.r, blue.g, blue.b, 0.16))
	draw_polyline(mid + PackedVector2Array([mid[0]]), Color(0.45, 0.72, 1.0, 0.35), 5.0, true)
	var rim := _diamond_points(center, size * 1.08)
	draw_polyline(rim + PackedVector2Array([rim[0]]), Color(1, 1, 1, 0.45), 2.5, true)


func _draw_lock_icon(center: Vector2) -> void:
	var icon_size := 26.0
	var rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(LOCK_ICON, rect, false)


func _draw_current_badge(diamond_center: Vector2) -> void:
	var label := tr("UI_CURRENT").to_upper()
	var font := _map_font
	## Badge size stays as before (font 10 + padding); type is smaller and centered.
	var layout_size := 10
	var text_layout := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, layout_size)
	var pad_x := 7.0
	var pad_y := 2.5
	var badge_size := Vector2(text_layout.x + pad_x * 2.0, text_layout.y + pad_y * 2.0)
	var font_size := 7
	var badge_pos := diamond_center + Vector2(-badge_size.x * 0.5, DIAMOND_SIZE * 0.5 + 12.0)
	var radius := badge_size.y * 0.5
	var col := LevelCatalog.PRIMARY_BLUE
	## Pill: flat middle + round end caps (full rect would leave square corners).
	if badge_size.x > radius * 2.0:
		draw_rect(Rect2(badge_pos.x + radius, badge_pos.y, badge_size.x - radius * 2.0, badge_size.y), col, true)
	draw_circle(badge_pos + Vector2(radius, radius), radius, col)
	draw_circle(badge_pos + Vector2(badge_size.x - radius, radius), radius, col)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_pos := Vector2(
		badge_pos.x + (badge_size.x - text_size.x) * 0.5,
		badge_pos.y + (badge_size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	)
	draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_dimension_label(center: Vector2, index: int, theme: Color, is_current: bool, unlocked: bool) -> void:
	var title := LevelCatalog.get_dimension_title(index)
	var font := _map_font
	var font_size := 20
	var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := center + Vector2(-text_size.x * 0.5, -DIAMOND_SIZE * 0.5 - 16.0)
	var col: Color
	if is_current:
		col = LevelCatalog.PRIMARY_BLUE
	elif unlocked:
		col = theme
	else:
		col = theme.lightened(0.2)
	draw_string(font, origin, title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


func _draw_dashed_line(from_p: Vector2, to_p: Vector2, color: Color, width: float) -> void:
	var delta := to_p - from_p
	var length := delta.length()
	if length < 1.0:
		return
	var dir := delta / length
	var drawn := 0.0
	var draw_on := true
	while drawn < length:
		var seg := DASH_LEN if draw_on else GAP_LEN
		var a := from_p + dir * drawn
		var b := from_p + dir * minf(drawn + seg, length)
		if draw_on:
			draw_line(a, b, color, width, true)
		drawn += seg
		draw_on = not draw_on


func _unhandled_input(event: InputEvent) -> void:
	if _intro_playing:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_set_zoom(camera.zoom.x + WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_set_zoom(camera.zoom.x - WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_velocity = Vector2.ZERO
				var hit := _hit_dimension(_world_mouse())
				if hit >= 0:
					get_viewport().set_input_as_handled()
					_on_dimension_clicked(hit)
				else:
					_panning = true
			else:
				_panning = false
	elif event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		_apply_pan_delta(motion.relative)
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_pan_velocity = Vector2.ZERO
			var hit := _hit_dimension(_world_mouse())
			if hit >= 0:
				get_viewport().set_input_as_handled()
				_on_dimension_clicked(hit)
			else:
				_panning = true
		else:
			_panning = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_panning = true
		_apply_pan_delta(drag.relative)
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()


func _set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(z, z)


func _hit_dimension(world_pos: Vector2) -> int:
	var best := -1
	var best_d := DIAMOND_SIZE
	for i in _positions.size():
		var local := world_pos - _positions[i]
		var manhattan := absf(local.x) + absf(local.y)
		if manhattan <= DIAMOND_SIZE * 0.55 and manhattan < best_d:
			best_d = manhattan
			best = i
	return best


func _on_dimension_clicked(index: int) -> void:
	if not LevelCatalog.is_dimension_unlocked(index):
		return
	GameSession.set_current_dimension(index)
	get_tree().change_scene_to_file(DIMENSION_LEVELS_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
