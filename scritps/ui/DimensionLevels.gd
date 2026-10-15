extends Node2D

## Per-dimension level map over a nebula + gold star-chart overlay.

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.png"
const LevelDetailsModalScript := preload("res://scritps/ui/LevelDetailsModal.gd")
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
## A campaign chapter is 6 rows. Split a chapter only when it is taller than the
## viewport; a few extra levels that still fit stay on the same page.

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
@onready var details_modal: LevelDetailsModalScript = %LevelDetailsModal

var _dimension_index: int = 0
var _levels: Array[LevelConfig] = []
var _level_positions: Array[Vector2] = []
var _group_headers: Array = []
var _theme_color: Color = LevelCatalog.PRIMARY_BLUE
var _star_chart_tex: Texture2D
var _map_font: Font
var _panning := false
var _pan_pointer_id := -1
var _edge_back := EdgeBack.new()
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
var _page_dots: Control
var _dots_drawn_index := -1
var _hover_index := -1
var _last_vp_size := Vector2.ZERO
var _fps_label: Label
var _fps_accum := 0.0
var _fps_frames := 0
var _ready_msec := 0
var _resize_rebuilds := 0
var _first_draw_logged := false
const HOLD_DELAY := 0.5
const DRAG_CANCEL_PX := 16.0
var _hold_timer: Timer
var _hold_index := -1
var _hold_from := Vector2.ZERO
var _hold_fired := false
var _press_on_diamond := false
## Snapshot at rebuild so _draw never walks the catalog (find_level_context
## recopies and sorts every section on each call).
var _level_unlocked: Array[bool] = []
var _level_stars: PackedInt32Array = PackedInt32Array()
var _level_perfect: Array[bool] = []


func _ready() -> void:
	_ready_msec = Time.get_ticks_msec()
	_map_font = MAP_FONT
	_dimension_index = clampi(GameSession.current_dimension_index, 0, LevelCatalog.get_dimension_count() - 1)
	_theme_color = LevelCatalog.get_dimension_color(_dimension_index)
	if back_button != null:
		back_button.accent_color = _theme_color
	_levels = LevelCatalog.get_section_levels(_dimension_index)
	_paging_enabled = _should_enable_paging()
	print(
		"[DimensionLevels] start dim=%s levels=%s paging=%s" % [
			_dimension_index, _levels.size(), _paging_enabled
		]
	)
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s — run bake_level_star_chart.gd" % STAR_CHART_PATH)

	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	print("[DimensionLevels] backdrop +%sms" % _elapsed_ms())
	set_process(true)
	_ensure_chart_sprite()

	camera.make_current()
	_ensure_white_fade()
	_ensure_page_dots()
	_ensure_fps_overlay()
	if title_badge != null:
		title_badge.z_index = 40
	if back_button != null:
		back_button.z_index = 50
	back_button.pressed.connect(_on_back_pressed)
	_ensure_hold_timer()
	if details_modal != null:
		details_modal.play_pressed.connect(_on_details_play_pressed)
	_apply_translations()
	hint_label.visible = false
	UiTheme.style_menu_hint(empty_label)
	empty_label.visible = _levels.is_empty()
	empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.88))

	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)
	## Linux/XWayland can report a 0x0 viewport on the first frames. Laying out
	## against that parks the camera in empty space (near-black sky). Wait, then
	## never rebuild from a degenerate size so a later 0-size event cannot wipe
	## a good layout. On Android the size is already valid — a long wait is a
	## black screen.
	var waited := await _await_valid_viewport()
	print("[DimensionLevels] viewport ready after %s frames +%sms size=%s" % [
		waited, _elapsed_ms(), get_viewport_rect().size
	])
	_rebuild_map()
	_restore_level_focus(GameSession.consume_dimension_level_focus(_dimension_index))
	_sync_title_to_chart_pole()
	GameSession.fade_scene_wipe_out(0.32)
	print("[DimensionLevels] first layout +%sms" % _elapsed_ms())


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		var viewport := get_viewport()
		if viewport and viewport.size_changed.is_connected(_on_viewport_resized):
			viewport.size_changed.disconnect(_on_viewport_resized)
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		return
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		queue_redraw()


func _viewport_is_ready() -> bool:
	if not is_inside_tree() or camera == null:
		return false
	var vp := get_viewport_rect().size
	return vp.x > 1.0 and vp.y > 1.0


func _await_valid_viewport() -> int:
	var frames := 0
	var max_frames := 4 if OS.has_feature("mobile") else 60
	while not _viewport_is_ready() and frames < max_frames:
		await get_tree().process_frame
		frames += 1
	return frames


func _elapsed_ms() -> int:
	return Time.get_ticks_msec() - _ready_msec


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)
	_sync_page_dots_to_camera()
	_update_fps_overlay(delta)
	## Diamonds are culled to the camera view. Pan/snap must redraw or newly
	## visible rows stay blank (tappable, but never painted) — especially on
	## phone, where hover never triggers a redraw.
	if _panning or (_snap_tween != null and _snap_tween.is_running()):
		queue_redraw()


func _apply_translations() -> void:
	title_badge.title = LevelCatalog.get_dimension_title(_dimension_index)
	title_badge.fill_color = _theme_color
	title_badge.font_size = TITLE_FONT_SIZE
	title_badge.show_rim = false
	empty_label.text = tr("UI_DIMENSION_EMPTY")


func _on_viewport_resized() -> void:
	if not _viewport_is_ready():
		return
	var vp := get_viewport_rect().size
	## The Linux Game/DEBUG window can spam size_changed with the same size.
	## Rebuilding the map every time freezes paging at a couple of frames/sec.
	if vp.distance_to(_last_vp_size) < 1.0:
		return
	_resize_rebuilds += 1
	print("[DimensionLevels] resize #%s %s -> %s +%sms" % [
		_resize_rebuilds, _last_vp_size, vp, _elapsed_ms()
	])
	_last_vp_size = vp
	var keep := _page_index
	_rebuild_map()
	_go_to_page(keep, false)


func _rebuild_map() -> void:
	if not _viewport_is_ready():
		return
	_last_vp_size = get_viewport_rect().size
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
	_cache_level_progress()
	print("[DimensionLevels] rebuild +%sms levels=%s" % [_elapsed_ms(), _levels.size()])
	queue_redraw()


func _cache_level_progress() -> void:
	## Sequential campaign unlock. Never call has_project_level per diamond —
	## that reloaded every level .tres (200+) for each of the 150 nodes.
	var n := _levels.size()
	_level_unlocked.resize(n)
	_level_stars.resize(n)
	_level_perfect.resize(n)
	var dim_unlocked := LevelCatalog.is_dimension_unlocked(_dimension_index)
	var draft_ids: Dictionary = CustomLevelStore.user_draft_ids()
	for i in n:
		var level: LevelConfig = _levels[i]
		var stars := 0
		var perfect := false
		if level != null:
			stars = GameSession.get_level_stars(level.level_id)
			perfect = GameSession.is_perfect_clear(level.level_id)
		_level_stars[i] = stars
		_level_perfect[i] = perfect
		if GameSession.develop_mode:
			_level_unlocked[i] = level != null
			continue
		if level != null and draft_ids.has(level.level_id):
			_level_unlocked[i] = true
			continue
		if not dim_unlocked or level == null:
			_level_unlocked[i] = false
			continue
		_level_unlocked[i] = true if i <= 0 else _level_stars[i - 1] > 0


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
		var diamond_screen := header_screen + HEADER_CLEARANCE * maxf(camera.zoom.x, 0.001)
		if not _level_positions.is_empty():
			diamond_screen = _screen_y_for_world_at_camera(
				_level_positions[0].y, _chart_pole_camera_y()
			)
		var i := 0
		var group_i := 0
		while i < _levels.size():
			var key := ""
			if _levels[i] != null:
				key = _levels[i].group_title_key.strip_edges()
			var start := i
			while i < _levels.size():
				var next_key := ""
				if _levels[i] != null:
					next_key = _levels[i].group_title_key.strip_edges()
				if next_key != key:
					break
				i += 1
			if group_i > 0 and group_i < _group_headers.size():
				var header_y: float = _group_headers[group_i].position.y
				_page_ys.append(_camera_y_to_place_world_at_screen_y(header_y, header_screen))
			var extra := 1
			var count := i - start
			var page_size := _chapter_page_size()
			while extra * page_size < count and start + extra * page_size < _level_positions.size():
				var pos: Vector2 = _level_positions[start + extra * page_size]
				_page_ys.append(_camera_y_to_place_world_at_screen_y(pos.y, diamond_screen))
				extra += 1
			group_i += 1
	if _page_ys.is_empty():
		_page_ys.append(0.0)
	_page_index = clampi(_page_index, 0, _page_ys.size() - 1)


func _screen_y_for_world_at_camera(world_y: float, cam_y: float) -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	return (world_y - cam_y) * z + vp.y * 0.5


func _clamp_camera_to_pages() -> void:
	camera.position.x = 0.0
	if _page_ys.is_empty():
		return
	var min_y := _page_ys[0]
	var max_y := _page_ys[_page_ys.size() - 1] if _paging_enabled else _max_camera_y()
	camera.position.y = clampf(camera.position.y, min_y, max_y)


func _restore_level_focus(level_id: String) -> void:
	var index := _index_of_level(level_id)
	if index < 0:
		_go_to_page(0, false)
		return
	if _paging_enabled:
		_go_to_page(_page_index_for_level_index(index), false)
		return
	_frame_level_group(index)


func _index_of_level(level_id: String) -> int:
	if level_id.is_empty():
		return -1
	for i in _levels.size():
		if _levels[i] != null and _levels[i].level_id == level_id:
			return i
	return -1


func _page_index_for_level_index(level_index: int) -> int:
	## Same page breaks as _rebuild_page_targets: one page per chapter, plus
	## another page only when a chapter is taller than the screen.
	if not _paging_enabled or level_index < 0:
		return 0
	var page := 0
	var i := 0
	var group_i := 0
	var page_size := _chapter_page_size()
	while i < _levels.size():
		var key := ""
		if _levels[i] != null:
			key = _levels[i].group_title_key.strip_edges()
		var start := i
		while i < _levels.size():
			var next_key := ""
			if _levels[i] != null:
				next_key = _levels[i].group_title_key.strip_edges()
			if next_key != key:
				break
			i += 1
		if group_i > 0:
			page += 1
		var count := i - start
		var extra_pages := 0
		while (extra_pages + 1) * page_size < count:
			extra_pages += 1
		if level_index < i:
			var within := level_index - start
			return page + mini(int(within / float(page_size)), extra_pages)
		page += extra_pages
		group_i += 1
	return 0


func _frame_level_group(level_index: int) -> void:
	var key := ""
	if level_index >= 0 and level_index < _levels.size() and _levels[level_index] != null:
		key = _levels[level_index].group_title_key.strip_edges()
	if key.is_empty():
		_go_to_page(0, false)
		return
	for header in _group_headers:
		if str(header.get("title_key", "")) != key:
			continue
		var header_y := float(header.position.y)
		camera.position = Vector2(
			0.0,
			_camera_y_to_place_world_at_screen_y(header_y, _page1_header_screen_y())
		)
		_clamp_camera_to_pages()
		_sync_page_dots_to_camera()
		queue_redraw()
		return
	_go_to_page(0, false)


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
		_sync_page_dots_to_camera()
		queue_redraw()
		return
	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_snap_tween.tween_property(camera, "position", target, PAGE_SNAP_DURATION)
	_snap_tween.finished.connect(func() -> void:
		_snap_tween = null
		_sync_page_dots_to_camera()
		queue_redraw()
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


func _chapter_page_size() -> int:
	## How many diamonds fit under the chapter title before the next title peeks
	## in. Dewfall's first subsection is a few levels past a 30-pack and still
	## fits, so it stays one page and a swipe lands on the next subsection.
	var z := maxf(camera.zoom.x, 0.001)
	var vp := get_viewport_rect().size
	var first_screen := _page1_header_screen_y() + HEADER_CLEARANCE * z
	var bottom_screen := vp.y - _diamond_size() * PEEK_DIAMOND_SLICE * z
	var row_screen := _row_spacing() * z
	var rows := 1
	if row_screen > 1.0:
		rows = maxi(int(floor((bottom_screen - first_screen) / row_screen)) + 1, 1)
	return rows * COLUMNS


func _neighbor_page_span(index: int, direction: int) -> float:
	if _page_ys.size() < 2:
		return 1.0
	var neighbor := clampi(index + direction, 0, _page_ys.size() - 1)
	if neighbor == index:
		return 1.0
	return maxf(absf(_page_ys[neighbor] - _page_ys[index]), 1.0)


func _resolve_snap_page() -> int:
	if _page_ys.is_empty():
		return 0
	var idx := _page_index
	var drag := camera.position.y - _pan_start_cam_y
	## Positive cam Y = looking further down the strip = next section.
	## Measure the swipe against the next page, not the first gap in the list.
	var dir := 1 if drag >= 0.0 else -1
	if absf(_pan_velocity_y) >= SNAP_VELOCITY:
		dir = 1 if _pan_velocity_y > 0.0 else -1
		idx += dir
	elif absf(drag) >= _neighbor_page_span(idx, dir) * SNAP_DISTANCE_RATIO:
		idx += dir
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
	queue_redraw()


func _nudge_scroll(world_dy: float) -> void:
	camera.position.y += world_dy
	camera.position.x = 0.0
	_clamp_camera_to_pages()
	queue_redraw()


func _ensure_fps_overlay() -> void:
	if not OS.has_feature("editor"):
		return
	if _fps_label != null and is_instance_valid(_fps_label):
		return
	var hud := get_node_or_null("UI/Root") as Control
	if hud == null:
		return
	_fps_label = Label.new()
	_fps_label.name = "PerfLabel"
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -280.0
	_fps_label.offset_top = 16.0
	_fps_label.offset_right = -16.0
	_fps_label.offset_bottom = 64.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 18)
	_fps_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.35, 0.95))
	_fps_label.text = "…"
	hud.add_child(_fps_label)


func _update_fps_overlay(delta: float) -> void:
	if _fps_label == null:
		return
	_fps_accum += delta
	_fps_frames += 1
	if _fps_accum < 0.4:
		return
	var avg_ms := (_fps_accum / float(_fps_frames)) * 1000.0
	var fps := 0.0 if avg_ms <= 0.0 else 1000.0 / avg_ms
	_fps_label.text = "%.0f ms  %.0f fps  rz %s" % [avg_ms, fps, _resize_rebuilds]
	_fps_accum = 0.0
	_fps_frames = 0


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


func _sync_page_dots_to_camera() -> void:
	if _page_dots == null:
		return
	var idx := _page_dot_index()
	if idx == _dots_drawn_index:
		return
	_dots_drawn_index = idx
	_page_dots.queue_redraw()


func _camera_view_rect(pad: float) -> Rect2:
	var z := maxf(camera.zoom.x, 0.001)
	var vp := get_viewport_rect().size
	var size := vp / z
	var origin := camera.position - size * 0.5
	return Rect2(origin, size).grow(pad)


func _draw_award_stars_on(item: CanvasItem) -> void:
	## World space — the camera pans these for free. A HUD overlay had to
	## rebuild every diamond on every swipe frame, and each diamond called
	## GameSession.is_level_unlocked (catalog copy + sort per section).
	var dsize := _diamond_size()
	var z := maxf(camera.zoom.x, 0.001)
	var world_px := 1.0 / z
	var rim_w := 1.8 * MAP_DRAW_ZOOM * world_px
	## Extra row of padding so the next chapter is already painted as it peeks in.
	var view := _camera_view_rect(dsize + _row_spacing())
	var count := mini(_levels.size(), _level_positions.size())
	var drawn := 0
	for i in count:
		var center: Vector2 = _level_positions[i]
		if not view.has_point(center):
			continue
		drawn += 1
		var pts := _diamond_points(center, dsize)
		var outline := pts + PackedVector2Array([pts[0]])
		var unlocked := i < _level_unlocked.size() and _level_unlocked[i]
		var stars := _level_stars[i] if i < _level_stars.size() else 0
		var completed := unlocked and stars > 0
		var hovered := unlocked and i == _hover_index
		if hovered:
			NebulaEffect.draw_selection_glow(item, center, dsize, _theme_color)
		if completed:
			var fill := _theme_color.lightened(0.20 if hovered else 0.08)
			item.draw_colored_polygon(pts, fill)
			if i < _level_perfect.size() and _level_perfect[i]:
				FaVector.draw_star(
					item,
					center,
					dsize * 0.42,
					Color(0.95, 0.78, 0.2, 1.0),
					2.0 * MAP_DRAW_ZOOM * world_px,
					1.0 * MAP_DRAW_ZOOM * world_px
				)
			else:
				FaVector.draw_check(item, center, dsize * 0.30)
		elif unlocked:
			if hovered:
				var wash := _theme_color.lightened(0.12)
				wash.a = 0.55
				item.draw_colored_polygon(pts, wash)
			var rim := _theme_color.lightened(0.18) if hovered else _theme_color
			item.draw_polyline(outline, rim, rim_w * (1.8 if hovered else 1.4), true)
			var number := str(i + 1)
			var font_px := 32.0 if i < 99 else 26.0
			var font_size := maxi(10, int(round(font_px * world_px)))
			var text_size := _map_font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos := Vector2(
				center.x - text_size.x * 0.5,
				center.y + (_map_font.get_ascent(font_size) - _map_font.get_descent(font_size)) * 0.5
			)
			item.draw_string(_map_font, text_pos, number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_color)
		else:
			item.draw_polyline(outline, LOCKED_GREY, rim_w * 1.2, true)
			FaVector.draw_lock(item, center, dsize * 0.34)
	if not _first_draw_logged:
		_first_draw_logged = true
		print("[DimensionLevels] first diamonds draw +%sms visible=%s / %s" % [
			_elapsed_ms(), drawn, count
		])


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
	_draw_award_stars_on(self)


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


func _input(event: InputEvent) -> void:
	if not _desktop_pointer():
		return
	if event is InputEventMouseMotion and not _panning:
		_update_hover_from_screen((event as InputEventMouseMotion).position)


func _unhandled_input(event: InputEvent) -> void:
	if details_modal != null and details_modal.visible:
		return
	if OS.has_feature("mobile") and (
		event is InputEventMouseButton or event is InputEventMouseMotion
	):
		## Touch already arrives as ScreenTouch/ScreenDrag. The emulated mouse
		## copy would double-pan and re-run hover hit-tests on every swipe.
		return
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
				_pointer_down(_world_mouse(), mb.position, -1)
			else:
				_pointer_up(-1)
			_mark_input_handled()
	elif event is InputEventMouseMotion:
		if _panning or _press_on_diamond:
			var motion := event as InputEventMouseMotion
			_pointer_drag(motion.position, motion.relative, -1)
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
	_set_hover_index(-1)
	if event.pressed:
		_pointer_down(_screen_to_world(event.position), event.position, event.index)
		_mark_input_handled()
		return
	_pointer_up(event.index)
	_mark_input_handled()


func _handle_drag(event: InputEventScreenDrag) -> void:
	_pointer_drag(event.position, event.relative, event.index)
	_mark_input_handled()


func _begin_pan(pointer_id: int) -> void:
	_set_hover_index(-1)
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
		queue_redraw()
	_pan_velocity_y = 0.0
	if _desktop_pointer():
		_set_hover_index(_hoverable_index_at(_world_mouse()))


func _desktop_pointer() -> bool:
	return not OS.has_feature("mobile")


func _gui_blocks_hover() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var ctrl := viewport.gui_get_hovered_control()
	return ctrl != null and ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _hoverable_index_at(world_pos: Vector2) -> int:
	if not _desktop_pointer() or _panning or _gui_blocks_hover():
		return -1
	var hit := _hit_level(world_pos)
	if hit < 0 or hit >= _levels.size():
		return -1
	if hit >= _level_unlocked.size() or not _level_unlocked[hit]:
		return -1
	return hit


func _update_hover_from_screen(_screen: Vector2) -> void:
	_set_hover_index(_hoverable_index_at(_world_mouse()))


func _set_hover_index(index: int) -> void:
	if _hover_index == index:
		return
	_hover_index = index
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if index >= 0 else Input.CURSOR_ARROW
	)
	queue_redraw()


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
	if index >= _level_unlocked.size() or not _level_unlocked[index]:
		return
	_launch_level(level)


func _launch_level(level: LevelConfig) -> void:
	if _navigating or level == null:
		return
	_navigating = true
	GameSession.clear_level_playlist()
	GameSession.set_return_scene("res://scenes/ui/dimension_levels.tscn")
	GameSession.set_level(level)
	GameSession.focus_dimension_level(level)
	GameSession.change_scene(GAME_SCENE)


func _ensure_hold_timer() -> void:
	if _hold_timer != null:
		return
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_DELAY
	_hold_timer.timeout.connect(_on_hold_timeout)
	add_child(_hold_timer)


func _pointer_down(world_pos: Vector2, screen_pos: Vector2, pointer_id: int) -> void:
	_pan_velocity_y = 0.0
	_hold_fired = false
	var hit := _hit_level(world_pos)
	var unlocked := hit >= 0 and hit < _level_unlocked.size() and _level_unlocked[hit]
	_press_on_diamond = unlocked
	if _press_on_diamond:
		_hold_index = hit
		_hold_from = screen_pos
		if _hold_timer != null:
			_hold_timer.start()
		return
	_hold_index = -1
	if _edge_back.try_begin(pointer_id, screen_pos, get_viewport_rect().size.x):
		return
	_begin_pan(pointer_id)


func _pointer_drag(screen_pos: Vector2, relative: Vector2, pointer_id: int) -> void:
	if _edge_back.watching(pointer_id):
		if _edge_back.drag(pointer_id, screen_pos):
			_begin_pan(pointer_id)
		return
	if _press_on_diamond and not _panning:
		if screen_pos.distance_to(_hold_from) >= DRAG_CANCEL_PX:
			if _hold_timer != null:
				_hold_timer.stop()
			_press_on_diamond = false
			_hold_index = -1
			_begin_pan(pointer_id)
	if _panning:
		_apply_pan_delta(relative)


func _pointer_up(pointer_id: int) -> void:
	if _hold_timer != null:
		_hold_timer.stop()
	if _edge_back.owns(pointer_id):
		var go_back := _edge_back.release(pointer_id)
		if go_back:
			BackRouter.request_back()
			_press_on_diamond = false
			_hold_index = -1
			_hold_fired = false
			return
	if _panning and (_pan_pointer_id == pointer_id or pointer_id < 0):
		_end_pan()
	elif _press_on_diamond and not _hold_fired and _hold_index >= 0:
		_on_level_clicked(_hold_index)
	_press_on_diamond = false
	_hold_index = -1
	_hold_fired = false


func _on_hold_timeout() -> void:
	if not _press_on_diamond or _hold_index < 0 or _panning:
		return
	_hold_fired = true
	Haptics.light()
	_show_level_details(_hold_index)


func _show_level_details(index: int) -> void:
	if details_modal == null or index < 0 or index >= _levels.size():
		return
	if index >= _level_unlocked.size() or not _level_unlocked[index]:
		return
	details_modal.show_level(_levels[index])


func _on_details_play_pressed(level: LevelConfig) -> void:
	_launch_level(level)


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
	if details_modal != null and details_modal.visible:
		details_modal.hide_modal()
		return
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
