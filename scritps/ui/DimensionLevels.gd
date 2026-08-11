extends Node2D

## Per-dimension level map: hub at chart centre, levels below.
## Section page-snap only kicks in when a dimension has many levels.

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.jpg"
## Must match StarChartBaker.LEVEL_STRIP_WORLD (hub at 0,0 = radial centre).
const STRIP_WORLD := Rect2(-420, -180, 840, 2800)

const COLUMNS := 5
const COL_SPACING := 118.0
const ROW_SPACING := 122.0
const HUB_GAP := 280.0
const HUB_DIAMOND_SIZE := 114.0
const LEVEL_DIAMOND_SIZE := 114.0
const GROUP_GAP_COMPACT := 128.0
## Hub sits slightly below world origin so it centres on the baked radial point.
const HUB_RADIAL_OFFSET_Y := 22.0
## Fraction of viewport width reserved as empty space on each side of the diamond grid.
const SIDE_MARGIN_RATIO := 0.18
## Screen Y for hub centre — clears the centered title above.
const FOCUS_TOP_MARGIN_PX := 210.0
const SECTION_TOP_MARGIN_PX := 148.0
const BOTTOM_PAD_PX := 168.0
const GROUP_HEADER_FONT_SIZE := 44
## World gap from section title centre down to level-diamond centres.
const HEADER_CLEARANCE := 96.0
const TITLE_FONT_SIZE := 64
## Page-snap only when a dimension has more levels than this.
const PAGE_LEVEL_THRESHOLD := 24

const PAGE_SNAP_DURATION := 0.42
const SNAP_VELOCITY := 220.0
const SNAP_DISTANCE_RATIO := 0.22
const FREE_SCROLL_STEP := 120.0

const CHART_BG := Color(0.97, 0.97, 0.985, 1.0)
const STAR_COLOR := Color(0.18, 0.28, 0.48, 0.85)
const LOCKED_GREY := Color(0.62, 0.64, 0.68, 1.0)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const LOCK_ICON := preload("res://assets/icons/lock_icon.svg")

@onready var camera: Camera2D = $Camera2D
@onready var back_button: CircleBackButton = %BackButton
@onready var title_label: Label = %TitleLabel
@onready var hint_label: Label = %HintLabel
@onready var empty_label: Label = %EmptyLabel

var _dimension_index: int = 0
var _levels: Array[LevelConfig] = []
var _level_positions: Array[Vector2] = []
var _group_headers: Array = []
var _hub_pos := Vector2.ZERO
var _theme_color: Color = LevelCatalog.PRIMARY_BLUE
var _star_chart_tex: Texture2D
var _map_font: Font
var _panning := false
var _pan_pointer_id := -1
var _pan_velocity_y := 0.0
var _pan_start_cam_y := 0.0
var _navigating := false
var _page_ys: Array[float] = []
var _page_index := 0
var _snap_tween: Tween
var _group_gap := GROUP_GAP_COMPACT
var _paging_enabled := false
var _hub_nebula: NebulaDiamondFill
var _chart_sprite: Sprite2D


func _ready() -> void:
	_map_font = MAP_FONT
	_dimension_index = clampi(GameSession.current_dimension_index, 0, LevelCatalog.get_dimension_count() - 1)
	_theme_color = LevelCatalog.get_dimension_color(_dimension_index)
	_levels = LevelCatalog.get_section_levels(_dimension_index)
	_hub_pos = Vector2(0.0, HUB_RADIAL_OFFSET_Y)
	_paging_enabled = _levels.size() > PAGE_LEVEL_THRESHOLD
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s — run bake_level_star_chart.gd" % STAR_CHART_PATH)

	_ensure_chart_sprite()
	_hub_nebula = NebulaDiamondFill.new()
	add_child(_hub_nebula)
	_hub_nebula.configure(_hub_pos, HUB_DIAMOND_SIZE)

	camera.make_current()
	back_button.pressed.connect(_on_back_pressed)
	_apply_translations()
	hint_label.visible = false
	UiTheme.style_menu_hint(empty_label)
	empty_label.visible = _levels.is_empty()
	UiTheme.style_menu_section_title(title_label)
	title_label.add_theme_color_override("font_color", Color(0.12, 0.16, 0.28, 0.92))
	UiTheme.apply_label_font(title_label, TITLE_FONT_SIZE, 48)

	get_viewport().size_changed.connect(_on_viewport_resized)
	## Layout must exist before the first draw — an await here left positions empty and crashed.
	_rebuild_map()
	_go_to_page(0, false)
	await get_tree().process_frame
	## Re-measure once the viewport size is final (esp. mobile / windowed).
	_rebuild_map()
	_go_to_page(0, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		queue_redraw()


func _apply_translations() -> void:
	title_label.text = LevelCatalog.get_dimension_title(_dimension_index)
	empty_label.text = tr("UI_DIMENSION_EMPTY")


func _on_viewport_resized() -> void:
	var keep := _page_index
	_rebuild_map()
	_go_to_page(keep, false)


func _rebuild_map() -> void:
	_paging_enabled = _levels.size() > PAGE_LEVEL_THRESHOLD
	_apply_page_zoom()
	_group_gap = _group_gap_for_paging() if _paging_enabled else GROUP_GAP_COMPACT
	var layout: Dictionary = LevelCatalog.build_grouped_level_layout(
		_levels,
		COLUMNS,
		COL_SPACING,
		ROW_SPACING,
		HUB_GAP + HUB_RADIAL_OFFSET_Y,
		_group_gap,
		HEADER_CLEARANCE
	)
	_level_positions.assign(layout.positions)
	_group_headers = layout.headers
	_rebuild_page_targets()
	_clamp_camera_to_pages()
	_apply_translations()
	_sync_chart_sprite()
	queue_redraw()


func _content_width() -> float:
	return COL_SPACING * float(COLUMNS - 1) + LEVEL_DIAMOND_SIZE


func _apply_page_zoom() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0:
		return
	var usable := clampf(1.0 - 2.0 * SIDE_MARGIN_RATIO, 0.35, 0.9)
	var target_visible_w := _content_width() / usable
	var z := vp.x / maxf(target_visible_w, 1.0)
	camera.zoom = Vector2(z, z)
	camera.position.x = 0.0


func _group_gap_for_paging() -> float:
	var page_h := get_viewport_rect().size.y / maxf(camera.zoom.x, 0.001)
	## Keep sections roughly one viewport apart so snaps feel like full-page jumps.
	var section_body := ROW_SPACING + LEVEL_DIAMOND_SIZE * 0.35 + 48.0
	return maxf(page_h - section_body, 240.0)


func _camera_y_to_frame_world_y(world_y: float, top_margin_px: float) -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	return world_y - (top_margin_px - vp.y * 0.5) / z


func _content_bottom_y() -> float:
	var bottom := _hub_pos.y + HUB_DIAMOND_SIZE * 0.5
	for pos in _level_positions:
		bottom = maxf(bottom, pos.y + LEVEL_DIAMOND_SIZE * 0.5)
	for header in _group_headers:
		bottom = maxf(bottom, float(header.position.y) + 24.0)
	return bottom


func _max_camera_y() -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	var min_y := _camera_y_to_frame_world_y(_hub_pos.y, FOCUS_TOP_MARGIN_PX)
	## Keep the last content above the footer hint.
	var bottom_margin_world := BOTTOM_PAD_PX / z
	var framed_bottom := _content_bottom_y() + bottom_margin_world - vp.y * 0.5 / z
	return maxf(min_y, framed_bottom)


func _rebuild_page_targets() -> void:
	_page_ys.clear()
	_page_ys.append(_camera_y_to_frame_world_y(_hub_pos.y, FOCUS_TOP_MARGIN_PX))
	if _paging_enabled:
		for i in range(1, _group_headers.size()):
			var header_y: float = _group_headers[i].position.y
			_page_ys.append(_camera_y_to_frame_world_y(header_y, SECTION_TOP_MARGIN_PX))
	if _page_ys.is_empty():
		_page_ys.append(0.0)
	_page_index = clampi(_page_index, 0, _page_ys.size() - 1)


func _clamp_camera_to_pages() -> void:
	camera.position.x = 0.0
	if _page_ys.is_empty():
		return
	var min_y := _page_ys[0]
	var max_y := _page_ys[_page_ys.size() - 1] if _paging_enabled else _max_camera_y()
	camera.position.y = clampf(camera.position.y, min_y, max_y)


func _go_to_page(index: int, animate: bool) -> void:
	if _page_ys.is_empty():
		return
	_page_index = clampi(index, 0, _page_ys.size() - 1)
	var target := Vector2(0.0, _page_ys[_page_index])
	if _snap_tween:
		_snap_tween.kill()
		_snap_tween = null
	if not animate:
		camera.position = target
		_clamp_camera_to_pages()
		return
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(camera, "position", target, PAGE_SNAP_DURATION)


func _nearest_page_index(cam_y: float) -> int:
	var best := 0
	var best_d := INF
	for i in _page_ys.size():
		var d := absf(cam_y - _page_ys[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _resolve_snap_page() -> int:
	if _page_ys.is_empty():
		return 0
	var idx := _page_index
	var page_span := 1.0
	if _page_ys.size() >= 2:
		page_span = absf(_page_ys[1] - _page_ys[0])
	var drag := camera.position.y - _pan_start_cam_y
	## Positive cam Y = looking further down the strip = next section.
	if absf(_pan_velocity_y) >= SNAP_VELOCITY:
		idx += 1 if _pan_velocity_y > 0.0 else -1
	elif absf(drag) >= page_span * SNAP_DISTANCE_RATIO:
		idx += 1 if drag > 0.0 else -1
	else:
		idx = _nearest_page_index(camera.position.y)
	return clampi(idx, 0, _page_ys.size() - 1)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _world_mouse() -> Vector2:
	return _screen_to_world(get_viewport().get_mouse_position())


func _apply_pan_delta(screen_delta: Vector2) -> void:
	## Vertical only — ignore horizontal drag.
	var world_dy := -screen_delta.y / maxf(camera.zoom.x, 0.001)
	camera.position.y += world_dy
	camera.position.x = 0.0
	_clamp_camera_to_pages()
	var dt := maxf(get_process_delta_time(), 0.0001)
	_pan_velocity_y = lerpf(_pan_velocity_y, world_dy / dt, 0.55)


func _nudge_scroll(world_dy: float) -> void:
	camera.position.y += world_dy
	camera.position.x = 0.0
	_clamp_camera_to_pages()


func _ensure_chart_sprite() -> void:
	## Chart sits behind nebula fills (z -10) so diamonds can layer correctly.
	if _chart_sprite != null and is_instance_valid(_chart_sprite):
		_sync_chart_sprite()
		return
	_chart_sprite = Sprite2D.new()
	_chart_sprite.z_index = -10
	_chart_sprite.centered = true
	_chart_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_chart_sprite)
	_sync_chart_sprite()


func _sync_chart_sprite() -> void:
	if _chart_sprite == null:
		return
	var chart_rect := _chart_draw_rect()
	_chart_sprite.position = chart_rect.get_center()
	if _star_chart_tex != null:
		_chart_sprite.texture = _star_chart_tex
		var tex_size := _star_chart_tex.get_size()
		if tex_size.x > 0.0 and tex_size.y > 0.0:
			_chart_sprite.scale = Vector2(
				chart_rect.size.x / tex_size.x,
				chart_rect.size.y / tex_size.y
			)
		_chart_sprite.modulate = Color.WHITE
	else:
		_chart_sprite.texture = null


func _chart_draw_rect() -> Rect2:
	## Expand past the baked strip so zoomed-out side margins still show chart, not bare white.
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	var visible_half_w := vp.x / (2.0 * z) + 80.0
	var half_w := maxf(STRIP_WORLD.size.x * 0.5, visible_half_w)
	return Rect2(-half_w, STRIP_WORLD.position.y, half_w * 2.0, STRIP_WORLD.size.y)


func _draw() -> void:
	## Background chart is a Sprite2D behind nebula; draw map chrome here.
	if _star_chart_tex == null:
		draw_rect(_chart_draw_rect(), CHART_BG, true)
	_draw_hub_diamond()
	_draw_group_headers()
	var count := mini(_levels.size(), _level_positions.size())
	for i in count:
		_draw_level_diamond(i)


func _draw_group_headers() -> void:
	## Left edge of the leftmost level diamond in the grid.
	var grid_left := -(float(COLUMNS - 1) * 0.5) * COL_SPACING - LEVEL_DIAMOND_SIZE * 0.5
	for header in _group_headers:
		var key := str(header.get("title_key", ""))
		if key.is_empty():
			continue
		var text := tr(key)
		var pos: Vector2 = header.position
		var text_pos := Vector2(
			grid_left,
			pos.y + (_map_font.get_ascent(GROUP_HEADER_FONT_SIZE) - _map_font.get_descent(GROUP_HEADER_FONT_SIZE)) * 0.5
		)
		draw_string(
			_map_font,
			text_pos,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			GROUP_HEADER_FONT_SIZE,
			Color(0.22, 0.28, 0.42, 0.88)
		)


func _draw_hub_diamond() -> void:
	var pts := _diamond_points(_hub_pos, HUB_DIAMOND_SIZE)
	var outline := pts + PackedVector2Array([pts[0]])
	## Theme-coloured outer glow; nebula child supplies the centre fill.
	_draw_selection_glow(_hub_pos, HUB_DIAMOND_SIZE, _theme_color)
	if _hub_nebula != null:
		_hub_nebula.configure(_hub_pos, HUB_DIAMOND_SIZE)
	draw_polyline(outline, Color(1, 1, 1, 0.95), 3.0, true)
	draw_polyline(outline, Color(_theme_color.r, _theme_color.g, _theme_color.b, 0.85), 1.6, true)
	if LevelCatalog.is_dimension_complete(_dimension_index):
		_draw_star_badge(_hub_pos, HUB_DIAMOND_SIZE * 0.22)
	else:
		draw_circle(_hub_pos, 5.0, Color(1, 1, 1, 1))
		draw_circle(_hub_pos, 3.4, STAR_COLOR)


func _draw_level_diamond(index: int) -> void:
	var level: LevelConfig = _levels[index]
	var pos: Vector2 = _level_positions[index]
	var unlocked := GameSession.is_level_unlocked(level)
	var stars := GameSession.get_level_stars(level.level_id)
	var completed := unlocked and stars > 0
	var pts := _diamond_points(pos, LEVEL_DIAMOND_SIZE)
	var outline := pts + PackedVector2Array([pts[0]])

	if completed:
		draw_colored_polygon(pts, _theme_color.lightened(0.08))
		draw_polyline(outline, Color(1, 1, 1, 0.9), 2.8, true)
		_draw_star_badge(pos, LEVEL_DIAMOND_SIZE * 0.28)
	elif unlocked:
		draw_polyline(outline, _theme_color, 3.8, true)
	else:
		draw_polyline(outline, LOCKED_GREY, 3.2, true)

	var number := str(index + 1)
	var font_size := 32 if index < 99 else 26
	var text_size := _map_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var text_col := Color(1, 1, 1, 0.98) if completed else (
		_theme_color if unlocked else LOCKED_GREY
	)
	var text_pos := Vector2(
		pos.x - text_size.x * 0.5,
		pos.y + (_map_font.get_ascent(font_size) - _map_font.get_descent(font_size)) * 0.5
	)
	draw_string(_map_font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

	if not unlocked:
		_draw_lock_icon(pos + Vector2(LEVEL_DIAMOND_SIZE * 0.28, -LEVEL_DIAMOND_SIZE * 0.28), 22.0)


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if _paging_enabled:
				_go_to_page(_page_index - 1, true)
			else:
				_nudge_scroll(-FREE_SCROLL_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if _paging_enabled:
				_go_to_page(_page_index + 1, true)
			else:
				_nudge_scroll(FREE_SCROLL_STEP)
			_mark_input_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pan_velocity_y = 0.0
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
	elif event is InputEventMouseMotion and _panning:
		var motion := event as InputEventMouseMotion
		_apply_pan_delta(motion.relative)
		_mark_input_handled()
	elif event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_drag(event as InputEventScreenDrag)


func _mark_input_handled() -> void:
	var viewport := get_viewport()
	if viewport:
		viewport.set_input_as_handled()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_pan_velocity_y = 0.0
		var world := _screen_to_world(event.position)
		var hit := _hit_level(world)
		if hit >= 0:
			_on_level_clicked(hit)
			_mark_input_handled()
			return
		if _hit_hub(world):
			_on_back_pressed()
			_mark_input_handled()
			return
		_begin_pan(event.index)
		_mark_input_handled()
		return

	if _pan_pointer_id == event.index:
		_end_pan()
		_mark_input_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _panning and _pan_pointer_id != event.index:
		return
	if not _panning:
		_begin_pan(event.index)
	_apply_pan_delta(event.relative)
	_mark_input_handled()


func _begin_pan(pointer_id: int) -> void:
	if _snap_tween:
		_snap_tween.kill()
		_snap_tween = null
	_panning = true
	_pan_pointer_id = pointer_id
	_pan_velocity_y = 0.0
	_pan_start_cam_y = camera.position.y


func _end_pan() -> void:
	if not _panning:
		return
	_panning = false
	_pan_pointer_id = -1
	if _paging_enabled:
		_go_to_page(_resolve_snap_page(), true)
	else:
		_clamp_camera_to_pages()
	_pan_velocity_y = 0.0


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
