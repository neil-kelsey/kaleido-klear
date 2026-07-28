extends Node2D

## Per-dimension level map: hub diamond at top, levels in a 5-column grid below.

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.jpg"
## Must match StarChartBaker.LEVEL_STRIP_WORLD.
const STRIP_WORLD := Rect2(-420, -180, 840, 2520)

const COLUMNS := 5
const COL_SPACING := 100.0
const ROW_SPACING := 100.0
const HUB_GAP := 160.0

const ZOOM_MIN := 0.85
const ZOOM_MAX := 4.5
const WHEEL_ZOOM_STEP := 0.12
const PINCH_ZOOM_SENSITIVITY := 1.0
const INTRO_ZOOM_START := 1.15
const INTRO_ZOOM_END := 1.85
const INTRO_ZOOM_DURATION := 0.95

const HUB_DIAMOND_SIZE := 84.0
const LEVEL_DIAMOND_SIZE := 52.0
const LINE_WIDTH := 2.2
const DASH_LEN := 12.0
const GAP_LEN := 9.0
const FOCUS_TOP_MARGIN_PX := 96.0

const CHART_BG := Color(0.97, 0.97, 0.985, 1.0)
const STAR_COLOR := Color(0.18, 0.28, 0.48, 0.85)
const LOCKED_GREY := Color(0.62, 0.64, 0.68, 1.0)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const LOCK_ICON := preload("res://assets/icons/lock_icon.svg")

const PAN_FRICTION := 7.5
const PAN_STOP_SPEED := 12.0
const PAN_MAX_SPEED := 4200.0

@onready var camera: Camera2D = $Camera2D
@onready var back_button: Button = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var empty_label: Label = %EmptyLabel

var _dimension_index: int = 0
var _levels: Array[LevelConfig] = []
var _level_positions: Array[Vector2] = []
var _hub_pos := Vector2.ZERO
var _theme_color: Color = LevelCatalog.PRIMARY_BLUE
var _star_chart_tex: Texture2D
var _map_font: Font
var _intro_tween: Tween
var _intro_playing := false
var _panning := false
var _pan_pointer_id := -1
var _pan_velocity := Vector2.ZERO
var _pinch_active := false
var _pinch_touches: Dictionary = {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_last_midpoint := Vector2.ZERO
var _navigating := false


func _ready() -> void:
	_map_font = MAP_FONT
	_dimension_index = clampi(GameSession.current_dimension_index, 0, LevelCatalog.get_dimension_count() - 1)
	_theme_color = LevelCatalog.get_dimension_color(_dimension_index)
	_levels = LevelCatalog.get_section_levels(_dimension_index)
	_level_positions = LevelCatalog.build_level_grid_positions(
		_levels.size(), COLUMNS, COL_SPACING, ROW_SPACING, HUB_GAP
	)
	_hub_pos = Vector2.ZERO
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s — run bake_level_star_chart.gd" % STAR_CHART_PATH)

	camera.make_current()
	back_button.pressed.connect(_on_back_pressed)
	UiTheme.style_nav_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	_apply_translations()
	UiTheme.style_menu_hint(hint_label)
	hint_label.add_theme_color_override("font_color", Color(0.25, 0.35, 0.55, 0.85))
	UiTheme.style_menu_hint(empty_label)
	empty_label.visible = _levels.is_empty()
	title_label.add_theme_color_override("font_color", Color(0.12, 0.16, 0.28, 0.92))
	title_label.add_theme_font_size_override("font_size", 36)

	get_viewport().size_changed.connect(_clamp_camera_to_strip)
	queue_redraw()
	await get_tree().process_frame
	_clamp_camera_to_strip()
	_play_intro()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		queue_redraw()


func _apply_translations() -> void:
	back_button.text = "  " + tr("UI_BACK")
	title_label.text = LevelCatalog.get_dimension_title(_dimension_index)
	hint_label.text = tr("UI_LEVEL_MAP_HINT")
	empty_label.text = tr("UI_DIMENSION_EMPTY")


func _play_intro() -> void:
	_intro_playing = true
	camera.zoom = Vector2(INTRO_ZOOM_START, INTRO_ZOOM_START)
	camera.position = _camera_pos_to_frame_hub()
	_clamp_camera_to_strip()
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(_set_intro_zoom, INTRO_ZOOM_START, INTRO_ZOOM_END, INTRO_ZOOM_DURATION)
	_intro_tween.tween_callback(func(): _intro_playing = false)


func _set_intro_zoom(z: float) -> void:
	camera.zoom = Vector2(z, z)
	camera.position = _camera_pos_to_frame_hub()
	_clamp_camera_to_strip()


func _camera_pos_to_frame_hub() -> Vector2:
	## Pin the hub near the top of the viewport so the level grid opens below.
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	var desired_screen_y := FOCUS_TOP_MARGIN_PX
	var cam := Vector2.ZERO
	cam.x = _hub_pos.x
	cam.y = _hub_pos.y - (desired_screen_y - vp.y * 0.5) / z
	return cam


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _world_mouse() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())


func _min_zoom_to_cover_strip() -> float:
	var vp := get_viewport_rect().size
	if STRIP_WORLD.size.x <= 0.0 or STRIP_WORLD.size.y <= 0.0:
		return ZOOM_MIN
	return maxf(vp.x / STRIP_WORLD.size.x, vp.y / STRIP_WORLD.size.y)


func _clamp_camera_to_strip() -> void:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	var cover := _min_zoom_to_cover_strip()
	if z < cover:
		z = cover
		camera.zoom = Vector2(z, z)
	var half := vp / (2.0 * z)
	var b := STRIP_WORLD
	var min_pos := b.position + half
	var max_pos := b.end - half
	var pos := camera.position
	if min_pos.x > max_pos.x:
		pos.x = b.get_center().x
	else:
		pos.x = clampf(pos.x, min_pos.x, max_pos.x)
	if min_pos.y > max_pos.y:
		pos.y = b.get_center().y
	else:
		pos.y = clampf(pos.y, min_pos.y, max_pos.y)
	camera.position = pos


func _process(delta: float) -> void:
	if _intro_playing or _panning:
		return
	if _pan_velocity.length_squared() < PAN_STOP_SPEED * PAN_STOP_SPEED:
		_pan_velocity = Vector2.ZERO
		set_process(false)
		return
	var intended := camera.position + _pan_velocity * delta
	camera.position = intended
	_clamp_camera_to_strip()
	if absf(camera.position.x - intended.x) > 0.01:
		_pan_velocity.x = 0.0
	if absf(camera.position.y - intended.y) > 0.01:
		_pan_velocity.y = 0.0
	_pan_velocity *= exp(-PAN_FRICTION * delta)


func _apply_pan_delta(screen_delta: Vector2, record_velocity: bool = true) -> void:
	var world_delta := -screen_delta / camera.zoom.x
	camera.position += world_delta
	_clamp_camera_to_strip()
	if not record_velocity:
		_pan_velocity = Vector2.ZERO
		return
	var dt := maxf(get_process_delta_time(), 0.0001)
	var sample := (world_delta / dt).limit_length(PAN_MAX_SPEED)
	_pan_velocity = _pan_velocity.lerp(sample, 0.55)
	set_process(true)


func _draw() -> void:
	if _star_chart_tex != null:
		draw_texture_rect(_star_chart_tex, STRIP_WORLD, false)
	else:
		draw_rect(STRIP_WORLD, CHART_BG, true)

	_draw_map_lines()
	_draw_hub_diamond()
	for i in _levels.size():
		_draw_level_diamond(i)


func _draw_map_lines() -> void:
	if _level_positions.is_empty():
		return
	## Vertical links down each column (no spokes from the dimension hub).
	for i in _level_positions.size():
		var below := i + COLUMNS
		if below >= _level_positions.size():
			continue
		var from_c: Vector2 = _level_positions[i]
		var to_c: Vector2 = _level_positions[below]
		var unlocked := GameSession.is_level_unlocked(_levels[below])
		var from_p := _diamond_edge_point(from_c, to_c, LEVEL_DIAMOND_SIZE)
		var to_p := _diamond_edge_point(to_c, from_c, LEVEL_DIAMOND_SIZE)
		if unlocked:
			draw_line(from_p, to_p, _theme_color.lightened(0.08), LINE_WIDTH, true)
		else:
			_draw_dashed_line(from_p, to_p, LOCKED_GREY, LINE_WIDTH)


func _draw_hub_diamond() -> void:
	var pts := _diamond_points(_hub_pos, HUB_DIAMOND_SIZE)
	var outline := pts + PackedVector2Array([pts[0]])
	_draw_selection_glow(_hub_pos, HUB_DIAMOND_SIZE, _theme_color)
	draw_colored_polygon(pts, _theme_color)
	draw_polyline(outline, Color(1, 1, 1, 0.95), 3.0, true)
	draw_circle(_hub_pos, 5.0, Color(1, 1, 1, 1))
	draw_circle(_hub_pos, 3.4, STAR_COLOR)
	if LevelCatalog.is_dimension_complete(_dimension_index):
		_draw_star_badge(_hub_pos + Vector2(HUB_DIAMOND_SIZE * 0.42, -HUB_DIAMOND_SIZE * 0.12), 10.0)


func _draw_level_diamond(index: int) -> void:
	var level: LevelConfig = _levels[index]
	var pos: Vector2 = _level_positions[index]
	var unlocked := GameSession.is_level_unlocked(level)
	var stars := GameSession.get_level_stars(level.level_id)
	var perfect := GameSession.is_perfect_clear(level.level_id)
	var pts := _diamond_points(pos, LEVEL_DIAMOND_SIZE)
	var outline := pts + PackedVector2Array([pts[0]])

	if unlocked and stars > 0:
		draw_colored_polygon(pts, _theme_color.lightened(0.08))
		draw_polyline(outline, Color(1, 1, 1, 0.9), 2.5, true)
	elif unlocked:
		draw_polyline(outline, _theme_color, 3.5, true)
	else:
		draw_polyline(outline, LOCKED_GREY, 3.0, true)

	var number := str(index + 1)
	var font_size := 18 if index < 99 else 15
	var text_size := _map_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_col := Color(1, 1, 1, 0.95) if unlocked and stars > 0 else (
		_theme_color if unlocked else LOCKED_GREY
	)
	var text_pos := Vector2(
		pos.x - text_size.x * 0.5,
		pos.y + (_map_font.get_ascent(font_size) - _map_font.get_descent(font_size)) * 0.5
	)
	draw_string(_map_font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

	if not unlocked:
		_draw_lock_icon(pos + Vector2(LEVEL_DIAMOND_SIZE * 0.3, -LEVEL_DIAMOND_SIZE * 0.3), 18.0)
	elif perfect:
		_draw_star_badge(pos + Vector2(LEVEL_DIAMOND_SIZE * 0.4, -LEVEL_DIAMOND_SIZE * 0.08), 7.5)


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


func _diamond_edge_point(center: Vector2, toward: Vector2, size: float) -> Vector2:
	var dir := toward - center
	if dir.length_squared() < 0.0001:
		return center
	dir = dir.normalized()
	var half := size * 0.5 + LINE_WIDTH * 0.5 + 1.0
	var t := half / (absf(dir.x) + absf(dir.y))
	return center + dir * t


func _draw_selection_glow(center: Vector2, size: float, accent: Color) -> void:
	var outer := _diamond_points(center, size * 1.45)
	draw_colored_polygon(outer, Color(accent.r, accent.g, accent.b, 0.12))
	var mid := _diamond_points(center, size * 1.2)
	draw_polyline(mid + PackedVector2Array([mid[0]]), Color(accent.r, accent.g, accent.b, 0.45), 3.5, true)


func _draw_lock_icon(center: Vector2, icon_size: float) -> void:
	var rect := Rect2(center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))
	draw_texture_rect(LOCK_ICON, rect, false)


func _draw_star_badge(center: Vector2, radius: float) -> void:
	var pts := PackedVector2Array()
	for i in 5:
		var outer_a := -PI * 0.5 + float(i) * TAU / 5.0
		pts.append(center + Vector2(cos(outer_a), sin(outer_a)) * radius)
		var inner_a := outer_a + TAU / 10.0
		pts.append(center + Vector2(cos(inner_a), sin(inner_a)) * radius * 0.42)
	draw_colored_polygon(pts, Color(0.95, 0.78, 0.2, 1.0))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.75), 1.2, true)


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
			_zoom_at_screen_point(mb.position, camera.zoom.x + WHEEL_ZOOM_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_screen_point(mb.position, camera.zoom.x - WHEEL_ZOOM_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_velocity = Vector2.ZERO
				var hit := _hit_level(_world_mouse())
				if hit >= 0:
					_mark_input_handled()
					_on_level_clicked(hit)
				elif _hit_hub(_world_mouse()):
					_mark_input_handled()
					_on_back_pressed()
				else:
					_begin_pan(-1)
			else:
				_end_pan()
	elif event is InputEventMouseMotion and _panning and not _pinch_active:
		var motion := event as InputEventMouseMotion
		_apply_pan_delta(motion.relative)
		_mark_input_handled()
	elif event is InputEventScreenTouch:
		if _handle_pinch_touch(event as InputEventScreenTouch):
			_mark_input_handled()
	elif event is InputEventScreenDrag:
		if _handle_pinch_drag(event as InputEventScreenDrag):
			_mark_input_handled()


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()


func _handle_pinch_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_pinch_touches[event.index] = event.position
		_pan_velocity = Vector2.ZERO
		if _pinch_touches.size() >= 2:
			_end_pan()
			_begin_pinch()
			return true
		var world := _screen_to_world(event.position)
		var hit := _hit_level(world)
		if hit >= 0:
			_on_level_clicked(hit)
			return true
		if _hit_hub(world):
			_on_back_pressed()
			return true
		_begin_pan(event.index)
		return true

	_pinch_touches.erase(event.index)
	if _pinch_touches.size() < 2:
		_pinch_active = false
	if _pan_pointer_id == event.index:
		_end_pan()
	return false


func _handle_pinch_drag(event: InputEventScreenDrag) -> bool:
	if _pinch_touches.has(event.index):
		_pinch_touches[event.index] = event.position
	if _pinch_touches.size() >= 2:
		if not _pinch_active:
			_end_pan()
			_begin_pinch()
		_update_pinch()
		return true
	if _pinch_touches.has(event.index) or _panning:
		if not _panning:
			_begin_pan(event.index)
		_apply_pan_delta(event.relative)
		return true
	return false


func _begin_pan(pointer_id: int) -> void:
	_panning = true
	_pan_pointer_id = pointer_id
	_pan_velocity = Vector2.ZERO
	set_process(false)


func _end_pan() -> void:
	_panning = false
	_pan_pointer_id = -1


func _begin_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2:
		return
	_pinch_active = true
	_pan_velocity = Vector2.ZERO
	set_process(false)
	_pinch_start_distance = points[0].distance_to(points[1])
	_pinch_start_zoom = camera.zoom.x
	_pinch_last_midpoint = (points[0] + points[1]) * 0.5


func _update_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2 or _pinch_start_distance <= 0.001:
		return
	var midpoint := (points[0] + points[1]) * 0.5
	var distance := points[0].distance_to(points[1])
	var target_zoom := _pinch_start_zoom * (distance / _pinch_start_distance) * PINCH_ZOOM_SENSITIVITY
	_zoom_at_screen_point(midpoint, target_zoom)
	var mid_delta := midpoint - _pinch_last_midpoint
	if mid_delta.length_squared() > 0.01:
		_apply_pan_delta(mid_delta, false)
	_pinch_last_midpoint = midpoint


func _pinch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in _pinch_touches.keys():
		points.append(_pinch_touches[key])
		if points.size() >= 2:
			break
	return points


func _zoom_at_screen_point(screen_point: Vector2, target_zoom: float) -> void:
	var old_zoom := camera.zoom.x
	var new_zoom := clampf(target_zoom, maxf(ZOOM_MIN, _min_zoom_to_cover_strip()), ZOOM_MAX)
	if is_equal_approx(old_zoom, new_zoom):
		_clamp_camera_to_strip()
		return
	var world_before := _screen_to_world(screen_point)
	camera.zoom = Vector2(new_zoom, new_zoom)
	var world_after := _screen_to_world(screen_point)
	camera.position += world_before - world_after
	_clamp_camera_to_strip()


func _hit_hub(world_pos: Vector2) -> bool:
	var local := world_pos - _hub_pos
	return absf(local.x) + absf(local.y) <= HUB_DIAMOND_SIZE * 0.55


func _hit_level(world_pos: Vector2) -> int:
	var best := -1
	var best_d := LEVEL_DIAMOND_SIZE
	for i in _level_positions.size():
		var local := world_pos - _level_positions[i]
		var manhattan := absf(local.x) + absf(local.y)
		if manhattan <= LEVEL_DIAMOND_SIZE * 0.55 and manhattan < best_d:
			best_d = manhattan
			best = i
	return best


func _on_level_clicked(index: int) -> void:
	if _navigating:
		return
	if index < 0 or index >= _levels.size():
		return
	var level: LevelConfig = _levels[index]
	if not GameSession.is_level_unlocked(level):
		return
	_navigating = true
	GameSession.clear_level_playlist()
	GameSession.set_return_scene("res://scenes/ui/dimension_levels.tscn")
	GameSession.set_level(level)
	GameSession.change_scene(GAME_SCENE)


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	GameSession.change_scene(DIMENSION_MAP_SCENE)


func handle_back() -> void:
	_on_back_pressed()
