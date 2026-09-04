extends Node2D

## Daily puzzles map — same nebula + star-chart language as dimension level select.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.png"
const STRIP_WORLD := Rect2(-420, -180, 840, 2800)

const COLUMNS := 5
const COL_SPACING := 132.0
const ROW_SPACING := 128.0
const LEVEL_DIAMOND_SIZE := 114.0
const TITLE_POLE_SCREEN_Y := 248.0
const TITLE_FONT_SIZE := 53
const SECONDARY_TITLE_FONT_SIZE := 44
const MAP_DRAW_ZOOM := 2.35
const HEADER_CLEARANCE := 118.0

const LOCKED_GREY := Color(0.78, 0.80, 0.84, 1.0)
const GOLD_TITLE := Color(1.0, 0.90, 0.62, 0.88)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")

@onready var camera: Camera2D = $Camera2D
@onready var back_button: CircleBackButton = %BackButton
@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var date_label: Label = %DateLabel
@onready var empty_label: Label = %EmptyLabel
@onready var nebula_bg: TextureRect = %NebulaBg

var _levels: Array[LevelConfig] = []
var _level_positions: Array[Vector2] = []
var _theme_color: Color = LevelCatalog.PRIMARY_BLUE
var _star_chart_tex: Texture2D
var _map_font: Font
var _chart_sprite: Sprite2D
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0
var _glyph_overlay: Control
var _overlay_cam_y := INF
var _overlay_cam_z := 0.0
var _last_vp_size := Vector2.ZERO
var _hover_index := -1
var _navigating := false


func _ready() -> void:
	_map_font = MAP_FONT
	_theme_color = LevelCatalog.PRIMARY_BLUE
	if back_button != null:
		back_button.accent_color = _theme_color
	_levels = DailyCatalog.get_todays_levels()
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s" % STAR_CHART_PATH)

	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_ensure_chart_sprite()
	camera.make_current()
	_ensure_glyph_overlay()
	back_button.pressed.connect(_on_back_pressed)
	_apply_secondary_title_style(date_label)
	_apply_secondary_title_style(empty_label)
	_apply_translations()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)
	await _await_valid_viewport()
	_rebuild_map()
	_sync_title_to_chart_pole()
	_sync_secondary_titles()
	GameSession.fade_scene_wipe_out(0.32)


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null and nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)
	_sync_glyph_overlay_to_camera()


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
		_invalidate_glyph_overlay()


func _viewport_is_ready() -> bool:
	if not is_inside_tree() or camera == null:
		return false
	var vp := get_viewport_rect().size
	return vp.x > 1.0 and vp.y > 1.0


func _await_valid_viewport() -> void:
	var frames := 0
	while not _viewport_is_ready() and frames < 60:
		await get_tree().process_frame
		frames += 1


func _apply_secondary_title_style(label: Label) -> void:
	label.add_theme_font_override("font", MAP_FONT)
	label.add_theme_font_size_override("font_size", SECONDARY_TITLE_FONT_SIZE)
	label.add_theme_color_override("font_color", GOLD_TITLE)


func _apply_translations() -> void:
	title_badge.title = tr("UI_DAILY_PUZZLES")
	title_badge.fill_color = _theme_color
	title_badge.font_size = TITLE_FONT_SIZE
	title_badge.show_rim = false
	date_label.text = DailyCatalog.format_today_date()
	empty_label.text = tr("UI_DAILY_EMPTY")
	_sync_title_to_chart_pole()
	_sync_secondary_titles()


func _on_viewport_resized() -> void:
	if not _viewport_is_ready():
		return
	var vp := get_viewport_rect().size
	if vp.distance_to(_last_vp_size) < 1.0:
		return
	_last_vp_size = vp
	_rebuild_map()
	_sync_title_to_chart_pole()
	_sync_secondary_titles()


func _title_pole_screen_y() -> float:
	return TITLE_POLE_SCREEN_Y


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


func _sync_secondary_titles() -> void:
	## Same vertical band as dimension group headers under the title badge.
	var top := _title_pole_screen_y() + 96.0
	if date_label != null:
		date_label.offset_top = top
		date_label.offset_bottom = top + 56.0
	var empty := _levels.is_empty()
	if empty_label != null:
		empty_label.visible = empty
		## Sit where the first group title would — under the date.
		var empty_y := top + 72.0
		empty_label.offset_top = empty_y
		empty_label.offset_bottom = empty_y + 56.0
	if date_label != null:
		date_label.visible = true


func _rebuild_map() -> void:
	if not _viewport_is_ready():
		return
	_level_positions.clear()
	if _levels.is_empty():
		camera.position = Vector2(0, _camera_y_for_pole())
		_sync_chart_sprite()
		queue_redraw()
		_invalidate_glyph_overlay()
		return
	var start_y := HEADER_CLEARANCE
	var cols := mini(COLUMNS, _levels.size())
	for i in _levels.size():
		var col := i % cols
		var row := int(i / cols)
		var x := (float(col) - float(cols - 1) * 0.5) * COL_SPACING
		var y := start_y + float(row) * ROW_SPACING
		_level_positions.append(Vector2(x, y))
	camera.position = Vector2(0, _camera_y_for_pole())
	_sync_chart_sprite()
	queue_redraw()
	_invalidate_glyph_overlay()


func _camera_y_for_pole() -> float:
	var vp := get_viewport_rect().size
	var z := maxf(camera.zoom.x, 0.001)
	return 0.0 - (_title_pole_screen_y() - vp.y * 0.5) / z


func _ensure_chart_sprite() -> void:
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


func _ensure_glyph_overlay() -> void:
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
	## Sit behind the title badge so diamonds tuck under it.
	_glyph_overlay.z_index = 0
	hud.add_child(_glyph_overlay)
	hud.move_child(_glyph_overlay, 0)
	if title_badge != null:
		title_badge.z_index = 40
	if back_button != null:
		back_button.z_index = 50


func _world_pos_to_screen(world: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform() * world


func _invalidate_glyph_overlay() -> void:
	_overlay_cam_y = INF
	if _glyph_overlay != null:
		_glyph_overlay.queue_redraw()


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
	_set_hover_index(_hoverable_index_at(_screen_to_world(get_viewport().get_mouse_position())))


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _draw_award_stars_on(item: CanvasItem) -> void:
	var z := maxf(camera.zoom.x, 0.001)
	var dsize := LEVEL_DIAMOND_SIZE * z
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
		var unlocked := DailyCatalog.is_level_unlocked(_levels, level)
		var stars := GameSession.get_level_stars(level.level_id)
		var completed := unlocked and stars > 0
		var hovered := unlocked and i == _hover_index
		if hovered:
			NebulaEffect.draw_selection_glow(item, center, dsize, _theme_color)
		if completed:
			var fill := _theme_color.lightened(0.20 if hovered else 0.08)
			item.draw_colored_polygon(pts, fill)
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
			if hovered:
				var wash := _theme_color.lightened(0.12)
				wash.a = 0.55
				item.draw_colored_polygon(pts, wash)
			var rim := _theme_color.lightened(0.18) if hovered else _theme_color
			item.draw_polyline(outline, rim, rim_w * (1.8 if hovered else 1.4), true)
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


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


func _gui_blocks_hover() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var ctrl := viewport.gui_get_hovered_control()
	return ctrl != null and ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _hoverable_index_at(world: Vector2) -> int:
	if _gui_blocks_hover():
		return -1
	var hit := _hit_level(world)
	if hit < 0 or hit >= _levels.size():
		return -1
	var level: LevelConfig = _levels[hit]
	if level == null or not DailyCatalog.is_level_unlocked(_levels, level):
		return -1
	return hit


func _set_hover_index(index: int) -> void:
	if _hover_index == index:
		return
	_hover_index = index
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if index >= 0 else Input.CURSOR_ARROW
	)
	if _glyph_overlay != null:
		_glyph_overlay.queue_redraw()


func _hit_level(world: Vector2) -> int:
	var half := LEVEL_DIAMOND_SIZE * 0.55
	for i in _level_positions.size():
		if world.distance_to(_level_positions[i]) <= half:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover_index(_hoverable_index_at(_screen_to_world(get_viewport().get_mouse_position())))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var hit := _hit_level(_screen_to_world(get_viewport().get_mouse_position()))
			if hit >= 0:
				_on_level_clicked(hit)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_set_hover_index(-1)
		if touch.pressed:
			var hit := _hit_level(_screen_to_world(touch.position))
			if hit >= 0:
				_on_level_clicked(hit)
				get_viewport().set_input_as_handled()


func _on_level_clicked(index: int) -> void:
	if _navigating or index < 0 or index >= _levels.size():
		return
	var level: LevelConfig = _levels[index]
	if not DailyCatalog.is_level_unlocked(_levels, level):
		return
	_navigating = true
	GameSession.set_level_playlist(_levels)
	GameSession.set_return_scene("res://scenes/ui/daily_puzzles.tscn")
	GameSession.set_level(level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func handle_back() -> void:
	_on_back_pressed()


class _AwardStarOverlay extends Control:
	var host: Node = null

	func _draw() -> void:
		if host != null and host.has_method("_draw_award_stars_on"):
			host._draw_award_stars_on(self)
