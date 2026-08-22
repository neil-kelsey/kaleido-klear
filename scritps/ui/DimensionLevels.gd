extends Node2D

## Per-dimension level map over a nebula + gold star-chart overlay.

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.png"
## Must match StarChartBaker.LEVEL_STRIP_WORLD.
const STRIP_WORLD := Rect2(-420, -180, 840, 2800)

const COLUMNS := 5
const COL_SPACING := 132.0
const ROW_SPACING := 128.0
const LEVEL_DIAMOND_SIZE := 114.0
## Campaign nodes read larger on a phone; Tutorial keeps the compact size.
const LEVEL_DIAMOND_SIZE_PAGED := 122.0
const GROUP_GAP_COMPACT := 168.0
## Minimum world gap between a chapter's last row and the next title.
const GROUP_GAP_PEEK_MIN := 56.0
## How much of the next chapter's first diamond shows below the peek title.
const PEEK_DIAMOND_SLICE := 0.32
## Fraction of viewport width reserved as empty space on each side of the diamond grid.
const SIDE_MARGIN_RATIO := 0.18
## Campaign uses more of the width so 5-wide diamonds read as tap targets.
const SIDE_MARGIN_RATIO_PAGED := 0.15
## Screen Y of the title centre (and the chart vanishing pole). Push this down
## to add space above the badge; the star chart tracks the same point.
const TITLE_POLE_SCREEN_Y := 248.0
## Screen pixels from the title-badge centre down to the first chapter header.
const BELOW_BADGE_PX := 176.0
const BOTTOM_PAD_PX := 168.0
const GROUP_HEADER_FONT_SIZE := 44
## World gap from section title centre down to level-diamond centres.
const HEADER_CLEARANCE := 118.0
const TITLE_FONT_SIZE := 53
## On-screen stroke match for DimensionMap.INTRO_ZOOM_END (map path markers).
const MAP_DRAW_ZOOM := 2.35
## Page-snap only above this count. Tutorial (25) must stay compact free-scroll.
## Twinkle Drift (150) is above; keep this above 25 and at/under 150.
const PAGE_LEVEL_THRESHOLD := 48

const PAGE_SNAP_DURATION := 0.42
const SNAP_VELOCITY := 220.0
const SNAP_DISTANCE_RATIO := 0.22
const FREE_SCROLL_STEP := 120.0

const LOCKED_GREY := Color(0.78, 0.80, 0.84, 1.0)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")

@onready var camera: Camera2D = $Camera2D
@onready var back_button: CircleBackButton = %BackButton
@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var hint_label: Label = %HintLabel
@onready var empty_label: Label = %EmptyLabel
@onready var nebula_bg: TextureRect = %NebulaBg

var _dimension_index: int = 0
var _levels: Array[LevelConfig] = []
var _level_positions: Array[Vector2] = []
var _group_headers: Array = []
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
var _chart_sprite: Sprite2D
var _white_fade: ColorRect
var _exit_tween: Tween
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0
var _glyph_overlay: Control
var _page_dots: Control
var _overlay_cam_y := INF
var _overlay_cam_z := 0.0


func _ready() -> void:
	_map_font = MAP_FONT
	_dimension_index = clampi(GameSession.current_dimension_index, 0, LevelCatalog.get_dimension_count() - 1)
	_theme_color = LevelCatalog.get_dimension_color(_dimension_index)
	if back_button != null:
		back_button.accent_color = _theme_color
	_levels = LevelCatalog.get_section_levels(_dimension_index)
	_paging_enabled = _should_enable_paging()
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s — run bake_level_star_chart.gd" % STAR_CHART_PATH)

	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_ensure_chart_sprite()

	camera.make_current()
	_ensure_white_fade()
	_ensure_glyph_overlay()
	_ensure_page_dots()
	GameSession.fade_scene_wipe_out(0.32)
	back_button.pressed.connect(_on_back_pressed)
	_apply_translations()
	hint_label.visible = false
	UiTheme.style_menu_hint(empty_label)
	empty_label.visible = _levels.is_empty()
	empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))

	get_viewport().size_changed.connect(_on_viewport_resized)
	## Layout must exist before the first draw — an await here left positions empty and crashed.
	_rebuild_map()
	_go_to_page(0, false)
	await get_tree().process_frame
	## Re-measure once the viewport size is final (esp. mobile / windowed).
	_rebuild_map()
	_go_to_page(0, false)
	_sync_title_to_chart_pole()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		queue_redraw()
		_invalidate_glyph_overlay()


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)
	_sync_glyph_overlay_to_camera()


func _apply_translations() -> void:
	title_badge.title = LevelCatalog.get_dimension_title(_dimension_index)
	title_badge.fill_color = _theme_color
	title_badge.font_size = TITLE_FONT_SIZE
	title_badge.show_rim = false
	empty_label.text = tr("UI_DIMENSION_EMPTY")


func _on_viewport_resized() -> void:
	var keep := _page_index
	_rebuild_map()
	_go_to_page(keep, false)


func _rebuild_map() -> void:
	_paging_enabled = _should_enable_paging()
	_apply_page_zoom()
	_group_gap = _group_gap_for_paging() if _paging_enabled else GROUP_GAP_COMPACT
	var layout: Dictionary = LevelCatalog.build_grouped_level_layout(
		_levels,
		COLUMNS,
		_col_spacing(),
		_row_spacing(),
		_hub_gap_for_title(),
		_group_gap,
		HEADER_CLEARANCE
	)
	_level_positions.assign(layout.positions)
	_group_headers = layout.headers
	_rebuild_page_targets()
	_clamp_camera_to_pages()
	_apply_translations()
	_sync_chart_sprite()
	_sync_title_to_chart_pole()
	queue_redraw()
	_invalidate_glyph_overlay()


func _content_width() -> float:
	return _col_spacing() * float(COLUMNS - 1) + _diamond_size()


func _diamond_size() -> float:
	return LEVEL_DIAMOND_SIZE_PAGED if _paging_enabled else LEVEL_DIAMOND_SIZE


func _col_spacing() -> float:
	return COL_SPACING


func _side_margin_ratio() -> float:
	return SIDE_MARGIN_RATIO_PAGED if _paging_enabled else SIDE_MARGIN_RATIO


func _apply_page_zoom() -> void:
	var vp := get_viewport_rect().size
	if vp.x <= 1.0:
		return
	var usable := clampf(1.0 - 2.0 * _side_margin_ratio(), 0.35, 0.9)
	var target_visible_w := _content_width() / usable
	var z := vp.x / maxf(target_visible_w, 1.0)
	camera.zoom = Vector2(z, z)
	camera.position.x = 0.0


func _should_enable_paging() -> bool:
	## Tutorial stays compact free-scroll even if the global count threshold changes.
	if LevelCatalog.is_tutorial_dimension(_dimension_index):
		return false
	if _levels.size() > PAGE_LEVEL_THRESHOLD:
		return true
	## A full 30-level chapter is one page even before the dimension hits 48.
	return _largest_group_size() >= 30


func _largest_group_size() -> int:
	var counts: Dictionary = {}
	var largest := 0
	for level in _levels:
		if level == null:
			continue
		var key := level.group_title_key.strip_edges()
		if key.is_empty():
			key = "_"
		var n := int(counts.get(key, 0)) + 1
		counts[key] = n
		largest = maxi(largest, n)
	return largest


func _row_spacing() -> float:
	## Campaign: same world gap on both axes so diamonds don't kiss vertically.
	return COL_SPACING if _paging_enabled else ROW_SPACING


func _group_gap_for_paging() -> float:
	## Keep the current 30 framed like page 1. Place the next chapter title plus
	## a slice of its first diamond row at the bottom of the viewport.
	var z := maxf(camera.zoom.x, 0.001)
	var vp := get_viewport_rect().size
	var world_at_bottom := (vp.y - _title_pole_screen_y()) / z
	var rows := ceili(float(maxi(_largest_group_size(), 1)) / float(COLUMNS))
	## After a full last row, layout has already advanced one row_spacing.
	var next_row_after_section := _hub_gap_for_title() + float(rows) * _row_spacing()
	var peek_cut_from_center := _diamond_size() * (PEEK_DIAMOND_SLICE - 0.5)
	var desired_next_diamonds := world_at_bottom - peek_cut_from_center
	return maxf(desired_next_diamonds - next_row_after_section, GROUP_GAP_PEEK_MIN)


func _camera_y_to_place_world_at_screen_y(world_y: float, screen_y: float) -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	return world_y - (screen_y - vp.y * 0.5) / z


func _chart_pole_camera_y() -> float:
	return _camera_y_to_place_world_at_screen_y(0.0, _title_pole_screen_y())


func _title_pole_screen_y() -> float:
	return TITLE_POLE_SCREEN_Y


func _hub_gap_for_title() -> float:
	## World Y of the first diamond row: enough screen space under the title badge.
	var z := maxf(camera.zoom.x, 0.001)
	var metrics := DiamondTitleBadge.measure(
		LevelCatalog.get_dimension_title(_dimension_index),
		TITLE_FONT_SIZE
	)
	return (metrics.size.y * 0.5 + BELOW_BADGE_PX) / z + HEADER_CLEARANCE


func _page1_header_screen_y() -> float:
	var metrics := DiamondTitleBadge.measure(
		LevelCatalog.get_dimension_title(_dimension_index),
		TITLE_FONT_SIZE
	)
	return _title_pole_screen_y() + BELOW_BADGE_PX + metrics.size.y * 0.5


func _sync_title_to_chart_pole() -> void:
	if title_badge == null:
		return
	var pole_y := _title_pole_screen_y()
	var metrics := DiamondTitleBadge.measure(title_badge.title, title_badge.font_size)
	var w: float = metrics.size.x
	var h: float = metrics.size.y
	title_badge.custom_minimum_size = metrics.size
	title_badge.offset_left = -w * 0.5
	title_badge.offset_right = w * 0.5
	title_badge.offset_top = pole_y - h * 0.5
	title_badge.offset_bottom = pole_y + h * 0.5


func _content_bottom_y() -> float:
	var bottom := 0.0
	for pos in _level_positions:
		bottom = maxf(bottom, pos.y + _diamond_size() * 0.5)
	for header in _group_headers:
		bottom = maxf(bottom, float(header.position.y) + 24.0)
	return bottom


func _first_content_y() -> float:
	if not _group_headers.is_empty():
		return float(_group_headers[0].position.y)
	if not _level_positions.is_empty():
		return _level_positions[0].y
	return 0.0


func _max_camera_y() -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	var min_y := _chart_pole_camera_y()
	var bottom_margin_world := BOTTOM_PAD_PX / z
	var framed_bottom := _content_bottom_y() + bottom_margin_world - vp.y * 0.5 / z
	return maxf(min_y, framed_bottom)


func _rebuild_page_targets() -> void:
	_page_ys.clear()
	_page_ys.append(_chart_pole_camera_y())
	if _paging_enabled:
		var header_screen := _page1_header_screen_y()
		for i in range(1, _group_headers.size()):
			var header_y: float = _group_headers[i].position.y
			_page_ys.append(_camera_y_to_place_world_at_screen_y(header_y, header_screen))
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
		if _page_dots != null:
			_page_dots.queue_redraw()
		return
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(camera, "position", target, PAGE_SNAP_DURATION)
	_snap_tween.finished.connect(func() -> void:
		if _page_dots != null:
			_page_dots.queue_redraw()
	)


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


func _ensure_glyph_overlay() -> void:
	## Parent to the HUD canvas so the camera never scales these pixels.
	if _glyph_overlay != null and is_instance_valid(_glyph_overlay):
		return
	var hud := get_node_or_null("UI/Root") as Control
	if hud == null:
		return
	_glyph_overlay = _AwardStarOverlay.new()
	_glyph_overlay.host = self
	_glyph_overlay.name = "AwardStarOverlay"
	_glyph_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph_overlay.z_index = 20
	hud.add_child(_glyph_overlay)


func _ensure_page_dots() -> void:
	if _page_dots != null and is_instance_valid(_page_dots):
		return
	var hud := get_node_or_null("UI/Root") as Control
	if hud == null:
		return
	_page_dots = _PageDots.new()
	_page_dots.host = self
	_page_dots.name = "PageDots"
	_page_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_dots.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_page_dots.offset_top = -56.0
	_page_dots.offset_bottom = -16.0
	_page_dots.z_index = 25
	hud.add_child(_page_dots)


func _page_dot_count() -> int:
	if not _paging_enabled:
		return 0
	return _page_ys.size()


func _page_dot_index() -> int:
	if not _paging_enabled or _page_ys.size() < 2:
		return _page_index
	if _panning or _snap_tween != null:
		return _nearest_page_index(camera.position.y)
	return _page_index


func _world_pos_to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func _invalidate_glyph_overlay() -> void:
	_overlay_cam_y = INF
	if _glyph_overlay != null:
		_glyph_overlay.queue_redraw()
	if _page_dots != null:
		_page_dots.queue_redraw()


func _sync_glyph_overlay_to_camera() -> void:
	if _glyph_overlay == null or camera == null:
		return
	var y := camera.position.y
	var z := camera.zoom.x
	if is_equal_approx(y, _overlay_cam_y) and is_equal_approx(z, _overlay_cam_z):
		return
	_overlay_cam_y = y
	_overlay_cam_z = z
	_glyph_overlay.queue_redraw()
	if _page_dots != null:
		_page_dots.queue_redraw()


func _draw_award_stars_on(item: CanvasItem) -> void:
	## Same draw calls as the dimension map, in screen pixels (no camera resampling).
	var z := maxf(camera.zoom.x, 0.001)
	var dsize := _diamond_size() * z
	var rim_w := 1.8 * MAP_DRAW_ZOOM
	var vp := get_viewport_rect().size
	var pad := dsize
	var count := mini(_levels.size(), _level_positions.size())
	for i in count:
		var center := _world_pos_to_screen(_level_positions[i])
		if center.x < -pad or center.x > vp.x + pad or center.y < -pad or center.y > vp.y + pad:
			continue
		var level: LevelConfig = _levels[i]
		var pts := _diamond_points(center, dsize)
		var outline := pts + PackedVector2Array([pts[0]])
		var unlocked := GameSession.is_level_unlocked(level)
		var stars := GameSession.get_level_stars(level.level_id)
		var completed := unlocked and stars > 0
		if completed:
			item.draw_colored_polygon(pts, _theme_color.lightened(0.08))
			if GameSession.is_perfect_clear(level.level_id):
				FaVector.draw_star(
					item,
					center,
					dsize * 0.42,
					Color(0.95, 0.78, 0.2, 1.0),
					2.0 * MAP_DRAW_ZOOM,
					1.0 * MAP_DRAW_ZOOM
				)
			else:
				FaVector.draw_check(item, center, dsize * 0.30)
		elif unlocked:
			item.draw_polyline(outline, _theme_color, rim_w * 1.4, true)
			var number := str(i + 1)
			var font_size := 32 if i < 99 else 26
			var text_size := _map_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos := Vector2(
				center.x - text_size.x * 0.5,
				center.y + (_map_font.get_ascent(font_size) - _map_font.get_descent(font_size)) * 0.5
			)
			item.draw_string(_map_font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_color)
		else:
			item.draw_polyline(outline, LOCKED_GREY, rim_w * 1.2, true)
			FaVector.draw_lock(item, center, dsize * 0.34)


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
	if _star_chart_tex == null:
		_chart_sprite.texture = null
		return
	_chart_sprite.texture = _star_chart_tex
	var tex_size := _star_chart_tex.get_size()
	if tex_size.x <= 0.0 or STRIP_WORLD.size.x <= 0.0:
		return
	## Uniform scale so the bake covers the screen, including above the title pole.
	var base := STRIP_WORLD.size.x / tex_size.x
	var z := maxf(camera.zoom.x, 0.001)
	var vp := get_viewport_rect().size
	var pole_up := maxf(-STRIP_WORLD.position.y, 1.0)
	var pole_down := maxf(STRIP_WORLD.end.y, 1.0)
	var pole_side := maxf(STRIP_WORLD.size.x * 0.5, 1.0)
	var need_up := (_title_pole_screen_y() + 8.0) / z
	var need_down := (vp.y - _title_pole_screen_y() + 8.0) / z
	var need_side := (vp.x * 0.5 + 8.0) / z
	var cover := maxf(need_side / pole_side, maxf(need_up / pole_up, need_down / pole_down))
	var s := base * cover
	_chart_sprite.scale = Vector2(s, s)
	var pole_px := Vector2(-STRIP_WORLD.position.x, -STRIP_WORLD.position.y) * (tex_size.x / STRIP_WORLD.size.x)
	_chart_sprite.position = -(pole_px - tex_size * 0.5) * s
	_chart_sprite.modulate = Color(1.0, 0.88, 0.50, 0.32)


func _draw() -> void:
	_draw_group_headers()


func _draw_group_headers() -> void:
	## Left edge of the leftmost level diamond in the grid.
	var grid_left := -(float(COLUMNS - 1) * 0.5) * _col_spacing() - _diamond_size() * 0.5
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
			Color(1.0, 0.90, 0.62, 0.88)
		)


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


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


func _hit_level(world_pos: Vector2) -> int:
	var best := -1
	var best_d := _diamond_size()
	for i in _level_positions.size():
		var local := world_pos - _level_positions[i]
		var manhattan := absf(local.x) + absf(local.y)
		if manhattan <= _diamond_size() * 0.55 and manhattan < best_d:
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


func _on_back_pressed() -> void:
	if _navigating:
		return
	_navigating = true
	GameSession.pending_map_zoom_out = true
	GameSession.fade_scene_wipe_to(
		Color(1, 1, 1, 1),
		0.22,
		func() -> void:
			GameSession.change_scene(DIMENSION_MAP_SCENE)
	)


func handle_back() -> void:
	_on_back_pressed()


class _AwardStarOverlay extends Control:
	var host: Node

	func _draw() -> void:
		if host != null and host.has_method("_draw_award_stars_on"):
			host._draw_award_stars_on(self)


class _PageDots extends Control:
	var host: Node

	func _draw() -> void:
		if host == null or not host.has_method("_page_dot_count"):
			return
		var n := int(host.call("_page_dot_count"))
		if n < 2:
			return
		var radius := 7.0
		var gap := 22.0
		var total := float(n - 1) * gap
		var start_x := size.x * 0.5 - total * 0.5
		var y := size.y * 0.5
		var current := int(host.call("_page_dot_index"))
		for i in n:
			var colour := Color(1, 1, 1, 0.96) if i == current else Color(0.22, 0.22, 0.26, 0.92)
			draw_circle(Vector2(start_x + float(i) * gap, y), radius, colour)
