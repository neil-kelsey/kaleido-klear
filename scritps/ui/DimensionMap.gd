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
const PINCH_ZOOM_SENSITIVITY := 1.0
const INTRO_ZOOM_START := 1.35
const INTRO_ZOOM_END := 3.6
const INTRO_ZOOM_DURATION := 1.15

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
const FOCUS_DURATION := 0.45

@onready var camera: Camera2D = $Camera2D
@onready var back_button: Button = %BackButton
@onready var hint_label: Label = %HintLabel

var _positions: Array[Vector2] = []
var _star_chart_tex: Texture2D
var _map_font: Font
var _intro_tween: Tween
var _focus_tween: Tween
var _intro_playing := false
var _panning := false
var _pan_pointer_id := -1
var _pan_velocity := Vector2.ZERO
var _selected_index: int = 0
var _pinch_active := false
var _pinch_touches: Dictionary = {} # index -> screen position
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_last_midpoint := Vector2.ZERO


func _ready() -> void:
	_map_font = MAP_FONT
	_positions = LevelCatalog.build_dimension_positions(300.0)
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked star chart at %s — run bake_star_chart.gd" % STAR_CHART_PATH)
	if not LevelCatalog.is_dimension_unlocked(GameSession.current_dimension_index):
		GameSession.set_current_dimension(_focus_dimension_index())
	_selected_index = _focus_dimension_index()
	camera.make_current()
	back_button.pressed.connect(_on_back_pressed)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	back_button.text = "  " + tr("UI_BACK")
	hint_label.text = tr("UI_DIMENSION_MAP_HINT")
	UiTheme.style_menu_hint(hint_label)
	hint_label.add_theme_color_override("font_color", Color(0.25, 0.35, 0.55, 0.85))
	get_viewport().size_changed.connect(_clamp_camera_to_strip)
	queue_redraw()
	await get_tree().process_frame
	_clamp_camera_to_strip()
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
	_clamp_camera_to_strip()
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
	_clamp_camera_to_strip()


func _world_mouse() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _min_zoom_to_cover_strip() -> float:
	## Zoom out no further than the star chart filling the viewport.
	var vp := get_viewport_rect().size
	if STRIP_WORLD.size.x <= 0.0 or STRIP_WORLD.size.y <= 0.0:
		return ZOOM_MIN
	return maxf(vp.x / STRIP_WORLD.size.x, vp.y / STRIP_WORLD.size.y)


func _clamp_camera_to_strip() -> void:
	## Keep the view inside STRIP_WORLD so the plain fill outside never shows.
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
	## Chart only — camera clamps keep the view on this strip.
	if _star_chart_tex != null:
		draw_texture_rect(_star_chart_tex, STRIP_WORLD, false)
	else:
		draw_rect(STRIP_WORLD, CHART_BG, true)

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
		var is_progress := i == progress
		var is_selected := i == _selected_index
		_draw_diamond(pos, DIAMOND_SIZE, theme, is_progress, is_selected, unlocked)
		_draw_dimension_label(pos, i, theme, is_progress, is_selected, unlocked)
		if is_progress:
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


func _draw_diamond(
	center: Vector2,
	size: float,
	theme: Color,
	is_progress: bool,
	is_selected: bool,
	unlocked: bool
) -> void:
	var pts := _diamond_points(center, size)
	var outline := pts + PackedVector2Array([pts[0]])
	if is_selected:
		_draw_selection_glow(center, size, LevelCatalog.PRIMARY_BLUE if is_progress else theme)
	if is_progress:
		_draw_current_glow(center, size)
		draw_colored_polygon(pts, LevelCatalog.PRIMARY_BLUE)
		draw_polyline(outline, Color(1, 1, 1, 0.95), 3.0, true)
	elif unlocked:
		draw_polyline(outline, theme, 4.0, true)
	else:
		draw_polyline(outline, theme.lightened(0.25), 3.0, true)
	if is_selected and not is_progress:
		## Clear selection ring so locked/unlocked picks read as focused.
		draw_polyline(outline, Color(1, 1, 1, 0.95), 5.0, true)
		draw_polyline(outline, theme if unlocked else theme.lightened(0.15), 2.5, true)
	var hub_r := 3.5
	draw_circle(center, hub_r + 1.6, Color(1, 1, 1, 1))
	draw_circle(center, hub_r, STAR_COLOR)
	if not unlocked:
		## Sit on the diamond's top-right corner (not centered over the hub).
		_draw_lock_icon(center + Vector2(size * 0.28, -size * 0.28))


func _draw_selection_glow(center: Vector2, size: float, accent: Color) -> void:
	var outer := _diamond_points(center, size * 1.55)
	draw_colored_polygon(outer, Color(accent.r, accent.g, accent.b, 0.12))
	var mid := _diamond_points(center, size * 1.28)
	draw_polyline(mid + PackedVector2Array([mid[0]]), Color(accent.r, accent.g, accent.b, 0.55), 4.5, true)


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


func _draw_dimension_label(
	center: Vector2,
	index: int,
	theme: Color,
	is_progress: bool,
	is_selected: bool,
	unlocked: bool
) -> void:
	var title := LevelCatalog.get_dimension_title(index)
	var font := _map_font
	var font_size := 20
	var text_size := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := center + Vector2(-text_size.x * 0.5, -DIAMOND_SIZE * 0.5 - 16.0)
	var col: Color
	if is_selected or is_progress:
		col = LevelCatalog.PRIMARY_BLUE if is_progress else theme
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
			_zoom_at_screen_point(mb.position, camera.zoom.x + WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_screen_point(mb.position, camera.zoom.x - WHEEL_ZOOM_STEP)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_velocity = Vector2.ZERO
				var hit := _hit_dimension(_world_mouse())
				if hit >= 0:
					get_viewport().set_input_as_handled()
					_on_dimension_clicked(hit)
				else:
					_begin_pan(-1)
			else:
				_end_pan()
	elif event is InputEventMouseMotion and _panning and not _pinch_active:
		var motion := event as InputEventMouseMotion
		_apply_pan_delta(motion.relative)
		var viewport := get_viewport()
		if viewport:
			viewport.set_input_as_handled()
	elif event is InputEventScreenTouch:
		if _handle_pinch_touch(event as InputEventScreenTouch):
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _handle_pinch_drag(event as InputEventScreenDrag):
			get_viewport().set_input_as_handled()


func _handle_pinch_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_pinch_touches[event.index] = event.position
		_pan_velocity = Vector2.ZERO
		if _pinch_touches.size() >= 2:
			_end_pan()
			_begin_pinch()
			return true
		var hit := _hit_dimension(_screen_to_world(event.position))
		if hit >= 0:
			_on_dimension_clicked(hit)
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
	if _focus_tween:
		_focus_tween.kill()
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


func _set_zoom(z: float) -> void:
	_zoom_at_screen_point(get_viewport_rect().size * 0.5, z)


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
	## First tap: select + center. Second tap on an unlocked dim: open levels.
	if index == _selected_index:
		if LevelCatalog.is_dimension_unlocked(index):
			GameSession.set_current_dimension(index)
			get_tree().change_scene_to_file(DIMENSION_LEVELS_SCENE)
		else:
			_center_on_dimension(index)
		return
	_selected_index = index
	queue_redraw()
	_center_on_dimension(index)


func _center_on_dimension(index: int) -> void:
	if index < 0 or index >= _positions.size():
		return
	_pan_velocity = Vector2.ZERO
	set_process(false)
	var target: Vector2 = _positions[index]
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_set_camera_position_clamped, camera.position, target, FOCUS_DURATION)


func _set_camera_position_clamped(pos: Vector2) -> void:
	camera.position = pos
	_clamp_camera_to_strip()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
