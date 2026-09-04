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
const INTRO_ZOOM_START := 1.15
const INTRO_ZOOM_END := 2.35
const INTRO_ZOOM_DURATION := 1.15

const DIAMOND_SIZE := 108.0
const PATH_DIAMOND_SIZE := 48.0
const PATH_MARKER_HIT := 36.0
const TITLE_FONT_FOCUSED := 18
## Focused diamond sits slightly below centre so its title fits and a neighbour marker shows above and below.
const FRAME_Y_BIAS := 52.0
const LINE_WIDTH := 1.8
const DASH_LEN := 14.0
const GAP_LEN := 10.0

const CHART_BG := Color(0.97, 0.97, 0.985, 1.0)
const STAR_COLOR := Color(0.18, 0.28, 0.48, 0.85)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")

## Pan coast: higher friction = snappier stop; stop speed is world-units/sec.
const PAN_FRICTION := 7.5
const PAN_STOP_SPEED := 12.0
const PAN_MAX_SPEED := 4200.0
const FOCUS_DURATION := 0.45
const DIVE_DURATION := 1.05
const DIVE_ZOOM_MULT := 5.5
const DIVE_WHITE_HOLD := 0.14
## Ignore a second click that arrives in the same press (mouse + emulated touch).
const CLICK_DEBOUNCE_MS := 120

const NEBULA_BRIGHT_SELECTED := 1.0
const NEBULA_BRIGHT_WASHED := 1.22
const NEBULA_WASH_OUT := 0.82
const NEBULA_WASHED_MODULATE := Color(1.0, 1.0, 1.02, 0.68)
const WASHED_RIM := Color(0.82, 0.84, 0.88, 0.38)

@onready var camera: Camera2D = $Camera2D
@onready var back_button: CircleBackButton = %BackButton

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
var _intro_focus_index: int = 0
var _navigating := false
var _nebula_effects: Array[NebulaEffect] = []
var _chart_sprite: Sprite2D
var _map_order: Array[int] = []
var _dive_tween: Tween
var _dive_progress := 0.0
var _dive_index := -1
var _white_fade: ColorRect
var _path_hint: Label
var _last_select_msec := 0


func _ready() -> void:
	_map_font = MAP_FONT
	_map_order = LevelCatalog.get_dimension_map_order()
	_positions = LevelCatalog.build_dimension_positions(168.0)
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked star chart at %s — run bake_star_chart.gd" % STAR_CHART_PATH)
	## Title-screen entry always frames furthest main-path progress, not the last
	## diamond visited (Tutorial is a side branch and must not steal CURRENT).
	if not GameSession.pending_map_zoom_out:
		GameSession.set_current_dimension(_focus_dimension_index())
	elif not LevelCatalog.is_dimension_unlocked(GameSession.current_dimension_index):
		GameSession.set_current_dimension(_focus_dimension_index())
	_selected_index = _focus_dimension_index() if not GameSession.pending_map_zoom_out else clampi(
		GameSession.current_dimension_index, 0, maxi(_positions.size() - 1, 0)
	)
	_ensure_chart_sprite()
	_ensure_nebula_effects()
	_sync_nebulas()
	_ensure_path_hint()
	_ensure_white_fade()
	camera.make_current()
	back_button.pressed.connect(_on_back_pressed)
	get_viewport().size_changed.connect(_clamp_camera_to_strip)
	queue_redraw()
	var zoom_out := GameSession.pending_map_zoom_out
	if zoom_out:
		## Cover the first frame so the map doesn't flash before the reverse dive.
		if _white_fade != null:
			_white_fade.color = Color(1, 1, 1, 1)
		GameSession.set_scene_wipe(Color(1, 1, 1, 1))
		var idx := clampi(GameSession.current_dimension_index, 0, maxi(_positions.size() - 1, 0))
		_selected_index = idx
		var z_close := INTRO_ZOOM_END * DIVE_ZOOM_MULT
		camera.zoom = Vector2(z_close, z_close)
		if idx < _positions.size():
			camera.position = _positions[idx]
	await get_tree().process_frame
	if GameSession.consume_map_zoom_out():
		_play_exit_zoom_out()
	else:
		_clamp_camera_to_strip()
		_play_intro()


func _ensure_path_hint() -> void:
	if _path_hint != null and is_instance_valid(_path_hint):
		_sync_path_hint()
		return
	var root := get_node_or_null("UI/Root") as Control
	if root == null:
		return
	_path_hint = Label.new()
	_path_hint.name = "PathHint"
	_path_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_path_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_path_hint.offset_left = -120.0
	_path_hint.offset_right = 120.0
	_path_hint.offset_top = -92.0
	_path_hint.offset_bottom = -58.0
	_path_hint.add_theme_font_override("font", MAP_FONT)
	_path_hint.add_theme_font_size_override("font_size", 18)
	_path_hint.add_theme_color_override("font_color", Color(0.22, 0.28, 0.42, 0.45))
	root.add_child(_path_hint)
	_sync_path_hint()


func _sync_path_hint() -> void:
	if _path_hint == null:
		return
	var slot := _map_order.find(_selected_index)
	var total := _map_order.size()
	if slot < 0 or total <= 0:
		_path_hint.text = ""
		return
	_path_hint.text = "%d / %d" % [slot + 1, total]


func _ensure_white_fade() -> void:
	if _white_fade != null and is_instance_valid(_white_fade):
		return
	var root := get_node_or_null("UI/Root") as Control
	if root == null:
		return
	_white_fade = ColorRect.new()
	_white_fade.name = "WhiteFade"
	_white_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white_fade.color = Color(1, 1, 1, 0)
	root.add_child(_white_fade)

func _ensure_chart_sprite() -> void:
	## Chart sits behind nebula fills so diamond centres can use the CTA nebula look.
	if _chart_sprite != null and is_instance_valid(_chart_sprite):
		return
	_chart_sprite = Sprite2D.new()
	_chart_sprite.z_index = -10
	_chart_sprite.centered = true
	_chart_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_chart_sprite.position = STRIP_WORLD.get_center()
	if _star_chart_tex != null:
		_chart_sprite.texture = _star_chart_tex
		var tex_size := _star_chart_tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_chart_sprite.scale = Vector2(
				STRIP_WORLD.size.x / tex_size.x,
				STRIP_WORLD.size.y / tex_size.y
			)
	add_child(_chart_sprite)


func _ensure_nebula_effects() -> void:
	while _nebula_effects.size() < _positions.size():
		_nebula_effects.append(NebulaEffect.attach_diamond(self))
	while _nebula_effects.size() > _positions.size():
		var extra: NebulaEffect = _nebula_effects.pop_back()
		extra.queue_free()


func _sync_nebulas() -> void:
	_ensure_nebula_effects()
	_sync_back_accent()
	for i in _nebula_effects.size():
		var fx := _nebula_effects[i]
		if i >= _positions.size():
			fx.visible = false
			continue
		var selected := i == _selected_index
		var unlocked := LevelCatalog.is_dimension_unlocked(i)
		fx.visible = true
		var dsize := DIAMOND_SIZE if selected else PATH_DIAMOND_SIZE
		if selected and unlocked:
			fx.configure_diamond(
				_positions[i],
				dsize,
				NEBULA_BRIGHT_SELECTED,
				true,
				Color.WHITE
			)
		else:
			fx.configure_diamond(
				_positions[i],
				dsize,
				NEBULA_BRIGHT_WASHED,
				false,
				NEBULA_WASHED_MODULATE,
				NEBULA_WASH_OUT
			)


func _sync_back_accent() -> void:
	if back_button == null:
		return
	var idx := clampi(_selected_index, 0, LevelCatalog.get_dimension_count() - 1)
	back_button.accent_color = LevelCatalog.get_dimension_color(idx)


func _play_intro() -> void:
	_intro_playing = true
	_intro_focus_index = _focus_dimension_index()
	camera.zoom = Vector2(INTRO_ZOOM_START, INTRO_ZOOM_START)
	camera.position = _camera_pos_to_frame_dimension(_intro_focus_index)
	_clamp_camera_to_strip()
	if _intro_tween:
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(_set_intro_zoom, INTRO_ZOOM_START, INTRO_ZOOM_END, INTRO_ZOOM_DURATION)
	_intro_tween.tween_callback(func(): _intro_playing = false)


func _interrupt_intro() -> void:
	## Entry zoom is cosmetic — don't eat taps while it finishes.
	if not _intro_playing or _navigating:
		return
	_intro_playing = false
	if _intro_tween:
		_intro_tween.kill()
		_intro_tween = null


func _play_exit_zoom_out() -> void:
	## Reverse of the enter dive: start inside the diamond, fade from white, zoom out.
	_intro_playing = true
	_navigating = true
	var index := clampi(GameSession.current_dimension_index, 0, maxi(_positions.size() - 1, 0))
	_selected_index = index
	_sync_nebulas()
	_sync_path_hint()
	queue_redraw()

	var z_close := INTRO_ZOOM_END * DIVE_ZOOM_MULT
	var z_open := INTRO_ZOOM_END
	var target: Vector2 = _positions[index]
	camera.zoom = Vector2(z_close, z_close)
	camera.position = target
	if _white_fade != null:
		_white_fade.color = Color(1, 1, 1, 1)
	GameSession.set_scene_wipe(Color(1, 1, 1, 1))

	if _intro_tween:
		_intro_tween.kill()
	if _dive_tween:
		_dive_tween.kill()
	_dive_tween = create_tween()
	_dive_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_dive_tween.tween_method(
		func(t: float) -> void: _update_zoom_out(t, z_close, z_open, index, target),
		0.0,
		1.0,
		DIVE_DURATION
	)
	_dive_tween.tween_callback(func() -> void:
		_intro_playing = false
		_navigating = false
		_dive_progress = 0.0
		if _white_fade != null:
			_white_fade.color = Color(1, 1, 1, 0)
		GameSession.set_scene_wipe(Color(1, 1, 1, 0))
		camera.zoom = Vector2(z_open, z_open)
		camera.position = _camera_pos_to_frame_dimension(index)
		_clamp_camera_to_strip()
	)


func _update_zoom_out(t: float, z_close: float, z_open: float, index: int, target: Vector2) -> void:
	## Ease-out already from tween; square-root so the first frames peel away from white.
	var ease_t := sqrt(t)
	_dive_progress = 1.0 - t
	var z := lerpf(z_close, z_open, ease_t)
	camera.zoom = Vector2(z, z)
	var framed := _camera_pos_to_frame_dimension(index)
	## Start centred on the diamond; stay centred while zooming out to map scale.
	camera.position = target.lerp(framed, ease_t)
	if _white_fade != null:
		var fade := 1.0 - smoothstep(0.0, 0.45, t)
		_white_fade.color = Color(1, 1, 1, fade)
		GameSession.sync_scene_wipe(Color(1, 1, 1, fade))



func _focus_dimension_index() -> int:
	## CURRENT = furthest unlocked main-path dimension. Side branches never win.
	return _furthest_unlocked_dimension()


func _set_intro_zoom(z: float) -> void:
	camera.zoom = Vector2(z, z)
	## Re-frame while zooming so the diamond stays centred.
	camera.position = _camera_pos_to_frame_dimension(_intro_focus_index)
	_clamp_camera_to_strip()


func _camera_pos_to_frame_dimension(index: int) -> Vector2:
	## Centre the diamond, with a slight downward bias so the title above
	## the neighbour above still fits on screen.
	if index < 0 or index >= _positions.size():
		return Vector2.ZERO
	return _positions[index] + Vector2(0.0, FRAME_Y_BIAS)


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
	## Background chart is a Sprite2D behind nebula fills.
	if _star_chart_tex == null:
		draw_rect(STRIP_WORLD, CHART_BG, true)
	## Connect consecutive diamonds on the vertical path (bottom → top).
	for slot in range(1, _map_order.size()):
		var from_i: int = _map_order[slot - 1]
		var to_i: int = _map_order[slot]
		var from_c: Vector2 = _positions[from_i]
		var to_c: Vector2 = _positions[to_i]
		var from_p := _path_edge_point(from_c, to_c, from_i)
		var to_p := _path_edge_point(to_c, from_c, to_i)
		var col := LevelCatalog.get_dimension_color(to_i)
		if LevelCatalog.is_dimension_unlocked(to_i):
			draw_line(from_p, to_p, col, LINE_WIDTH, true)
		else:
			_draw_dashed_line(from_p, to_p, col.lightened(0.15), LINE_WIDTH)

	var progress := _furthest_unlocked_dimension()
	_sync_nebulas()
	for i in _positions.size():
		var pos: Vector2 = _positions[i]
		var theme := LevelCatalog.get_dimension_color(i)
		var unlocked := LevelCatalog.is_dimension_unlocked(i)
		var is_progress := i == progress
		var is_selected := i == _selected_index
		if is_selected:
			_draw_diamond(pos, DIAMOND_SIZE, theme, is_progress, true, unlocked)
			_draw_dimension_label(pos, i, theme)
			if LevelCatalog.is_dimension_complete(i):
				if LevelCatalog.is_dimension_perfect(i):
					FaVector.draw_award_star(self, pos, DIAMOND_SIZE * 0.18)
				else:
					FaVector.draw_check(self, pos, DIAMOND_SIZE * 0.30)
			if is_progress:
				_draw_current_badge(pos, DIAMOND_SIZE, theme)
		else:
			_draw_path_diamond(pos, i, theme, unlocked)


func _furthest_unlocked_dimension() -> int:
	## Highest unlocked dimension on the main path (excludes Tutorial / side branches).
	var best := 0
	for i in _positions.size():
		if LevelCatalog.is_dimension_side_branch(i):
			continue
		if LevelCatalog.is_dimension_unlocked(i):
			best = i
	return best


func _path_marker_radius(index: int) -> float:
	if index == _selected_index:
		return DIAMOND_SIZE * 0.5
	return PATH_DIAMOND_SIZE * 0.5


func _path_edge_point(center: Vector2, toward: Vector2, index: int) -> Vector2:
	return _diamond_edge_point(center, toward, _path_marker_radius(index) * 2.0)


func _diamond_edge_point(center: Vector2, toward: Vector2, size: float) -> Vector2:
	var dir := toward - center
	if dir.length_squared() < 0.0001:
		return center
	dir = dir.normalized()
	var half := size * 0.5 + LINE_WIDTH * 0.5 + 1.0
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
	_is_progress: bool,
	is_selected: bool,
	unlocked: bool
) -> void:
	if is_selected:
		NebulaEffect.draw_selection_glow(self, center, size, theme)

	var pts := _diamond_points(center, size)
	var rim := Color(1, 1, 1, 0.45) if unlocked else WASHED_RIM
	draw_polyline(pts + PackedVector2Array([pts[0]]), rim, 1.5, true)

	if not unlocked:
		FaVector.draw_lock(self, center, size * 0.34)


func _draw_path_diamond(center: Vector2, index: int, theme: Color, unlocked: bool) -> void:
	var size := PATH_DIAMOND_SIZE
	var pts := _diamond_points(center, size)
	var outline := pts + PackedVector2Array([pts[0]])
	var rim := Color(theme.r, theme.g, theme.b, 0.92 if unlocked else 0.75)
	draw_polyline(outline, rim, 1.8 if unlocked else 1.6, true)
	if not unlocked:
		FaVector.draw_lock(self, center, size * 0.34)
	elif LevelCatalog.is_dimension_perfect(index):
		FaVector.draw_award_star(self, center, size * 0.18)
	elif LevelCatalog.is_dimension_complete(index):
		FaVector.draw_check(self, center, size * 0.30)


func _draw_current_badge(diamond_center: Vector2, diamond_size: float, theme: Color) -> void:
	var label := tr("UI_CURRENT").to_upper()
	var font := _map_font
	## Badge size stays as before (font 10 + padding); type is smaller and centered.
	var layout_size := 10
	var text_layout := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, layout_size)
	var pad_x := 7.0
	var pad_y := 2.5
	var badge_size := Vector2(text_layout.x + pad_x * 2.0, text_layout.y + pad_y * 2.0)
	var font_size := 7
	var badge_pos := diamond_center + Vector2(-badge_size.x * 0.5, diamond_size * 0.5 + 12.0)
	var radius := badge_size.y * 0.5
	var col := theme
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


func _draw_dimension_label(center: Vector2, index: int, theme: Color) -> void:
	var title := LevelCatalog.get_dimension_title(index)
	var metrics := DiamondTitleBadge.measure(title, TITLE_FONT_FOCUSED)
	var badge_c := center + Vector2(0.0, -DIAMOND_SIZE * 0.5 - 10.0 - metrics.h * 0.5)
	DiamondTitleBadge.draw_on(self, badge_c, title, theme, TITLE_FONT_FOCUSED, false, true)


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
	if _navigating or _dive_progress > 0.0:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_interrupt_intro()
			_zoom_at_screen_point(mb.position, camera.zoom.x + WHEEL_ZOOM_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_interrupt_intro()
			_zoom_at_screen_point(mb.position, camera.zoom.x - WHEEL_ZOOM_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_velocity = Vector2.ZERO
				var hit := _hit_dimension(_world_mouse())
				if hit >= 0:
					_mark_input_handled()
					_on_dimension_clicked(hit)
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
	_interrupt_intro()
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
	_interrupt_intro()
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
	var best_d := INF
	for i in _positions.size():
		var local := world_pos - _positions[i]
		if i == _selected_index:
			var manhattan := absf(local.x) + absf(local.y)
			if manhattan <= DIAMOND_SIZE * 0.55 and manhattan < best_d:
				best_d = manhattan
				best = i
		else:
			var d := local.length()
			if d <= PATH_MARKER_HIT and d < best_d:
				best_d = d
				best = i
	return best


func _on_dimension_clicked(index: int) -> void:
	## First tap focuses a different dimension (centres it, shows the name).
	## Second tap on that focused diamond dives in — even while it is still sliding.
	if _navigating or _dive_progress > 0.0:
		return
	_interrupt_intro()
	if index == _selected_index:
		if _is_duplicate_click():
			return
		if LevelCatalog.is_dimension_unlocked(index) and _can_enter_focused(index):
			_play_enter_dive(index)
			return
		_center_on_dimension(index)
		return
	_selected_index = index
	_last_select_msec = Time.get_ticks_msec()
	_sync_nebulas()
	_sync_path_hint()
	queue_redraw()
	_center_on_dimension(index)


func _is_duplicate_click() -> bool:
	return Time.get_ticks_msec() - _last_select_msec < CLICK_DEBOUNCE_MS


func _can_enter_focused(index: int) -> bool:
	## Don't wait for the centre animation to finish — a second tap means enter.
	if _focus_tween != null and _focus_tween.is_running():
		return true
	return _is_dimension_centered(index)


func _is_dimension_centered(index: int) -> bool:
	if index < 0 or index >= _positions.size():
		return false
	return camera.position.distance_to(_camera_pos_to_frame_dimension(index)) <= 18.0


func _world_to_screen(world_pos: Vector2, cam_pos: Vector2, zoom: float) -> Vector2:
	var vp := get_viewport_rect().size
	return (world_pos - cam_pos) * zoom + vp * 0.5


func _play_enter_dive(index: int) -> void:
	_navigating = true
	_dive_index = index
	GameSession.set_current_dimension(index)
	_pan_velocity = Vector2.ZERO
	set_process(false)
	if _focus_tween:
		_focus_tween.kill()
	if _dive_tween:
		_dive_tween.kill()
	_intro_playing = false
	if _intro_tween:
		_intro_tween.kill()

	_dive_progress = 0.0
	if _white_fade != null:
		_white_fade.color = Color(0, 0, 0, 0)

	var z0 := camera.zoom.x
	var z1 := z0 * DIVE_ZOOM_MULT
	var p0 := camera.position
	var target := _positions[index]
	## Keep diving into the diamond's current screen position, then pull it to centre.
	var start_focus := _world_to_screen(target, p0, z0)

	_dive_tween = create_tween()
	_dive_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	_dive_tween.tween_method(
		func(t: float) -> void: _update_dive(t, z0, z1, target, start_focus),
		0.0,
		1.0,
		DIVE_DURATION
	)
	## Brief full-black hold so the dark level map doesn't pop in harshly.
	_dive_tween.tween_callback(func() -> void:
		if _white_fade != null:
			_white_fade.color = Color(0, 0, 0, 1)
	)
	_dive_tween.tween_interval(DIVE_WHITE_HOLD)
	_dive_tween.tween_callback(_finish_enter_dive)


func _update_dive(
	t: float,
	z0: float,
	z1: float,
	target_world: Vector2,
	start_focus_screen: Vector2
) -> void:
	## Ease-in already from tween; square again so late frames feel like a rush.
	var rush := t * t
	_dive_progress = t
	var vp := get_viewport_rect().size
	var z := lerpf(z0, z1, rush)
	## Focal screen point: diamond stays under the zoom while sliding toward centre.
	var focus_screen := start_focus_screen.lerp(vp * 0.5, rush)
	camera.zoom = Vector2(z, z)
	## Camera so target_world projects exactly onto focus_screen.
	camera.position = target_world - (focus_screen - vp * 0.5) / maxf(z, 0.001)

	if _white_fade != null:
		var fade := smoothstep(0.58, 0.98, t)
		_white_fade.color = Color(0, 0, 0, fade)


func _finish_enter_dive() -> void:
	_dive_progress = 1.0
	if _white_fade != null:
		_white_fade.color = Color(0, 0, 0, 1)
	GameSession.set_scene_wipe(Color(0, 0, 0, 1))
	GameSession.change_scene(DIMENSION_LEVELS_SCENE)


func _center_on_dimension(index: int) -> void:
	if index < 0 or index >= _positions.size():
		return
	_pan_velocity = Vector2.ZERO
	set_process(false)
	var target := _camera_pos_to_frame_dimension(index)
	if _focus_tween:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_tween.tween_method(_set_camera_position_clamped, camera.position, target, FOCUS_DURATION)


func _set_camera_position_clamped(pos: Vector2) -> void:
	camera.position = pos
	_clamp_camera_to_strip()


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	GameSession.change_scene(MAIN_MENU_SCENE)


func handle_back() -> void:
	_on_back_pressed()
