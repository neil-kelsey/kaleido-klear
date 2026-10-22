extends Node2D

## Daily puzzles: three cards (Easy / Medium / Hard) for the UTC day, plus streaks.
## Same nebula + star-chart language as dimension level select.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"
const STAR_CHART_PATH := "res://assets/backgrounds/level_star_chart.png"
const LevelDetailsModalScript := preload("res://scritps/ui/LevelDetailsModal.gd")
const STRIP_WORLD := Rect2(-420, -180, 840, 2800)

const CARD_SPACING := 250.0
const CARD_FIRST_SCREEN_Y := 640.0
const LEVEL_DIAMOND_SIZE := 130.0
const DIAMOND_X := -160.0
const TEXT_X := -70.0
const TEXT_MAX_W := 340.0
const CARD_HIT := Rect2(-240, -90, 520, 180)
const DAY_CHECK_INTERVAL := 1.0
const TITLE_POLE_SCREEN_Y := 248.0
const TITLE_FONT_SIZE := 53
const SECONDARY_TITLE_FONT_SIZE := 44
const MAP_DRAW_ZOOM := 2.35

const LOCKED_GREY := Color(0.78, 0.80, 0.84, 1.0)
const GOLD_TITLE := Color(1.0, 0.90, 0.62, 0.88)
const MAP_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")

@onready var camera: Camera2D = $Camera2D
@onready var back_button: CircleBackButton = %BackButton
@onready var title_badge: DiamondTitleBadge = %TitleBadge
@onready var date_label: Label = %DateLabel
@onready var empty_label: Label = %EmptyLabel
@onready var nebula_bg: TextureRect = %NebulaBg
@onready var details_modal: LevelDetailsModalScript = %LevelDetailsModal

var _levels: Array[LevelConfig] = []
var _slots: PackedStringArray = []
var _day_key := ""
var _day_check_accum := 0.0
var _streak_label: Label
var _level_positions: Array[Vector2] = []
var _theme_color: Color = LevelCatalog.PRIMARY_BLUE
var _star_chart_tex: Texture2D
var _map_font: Font
var _chart_sprite: Sprite2D
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0
var _last_vp_size := Vector2.ZERO
var _hover_index := -1
var _navigating := false
const HOLD_DELAY := 0.5
const DRAG_CANCEL_PX := 16.0
var _hold_timer: Timer
var _hold_index := -1
var _hold_from := Vector2.ZERO
var _hold_fired := false
var _press_on_diamond := false


func _ready() -> void:
	_map_font = MAP_FONT
	_theme_color = LevelCatalog.PRIMARY_BLUE
	if back_button != null:
		back_button.accent_color = _theme_color
	_load_day()
	_star_chart_tex = load(STAR_CHART_PATH) as Texture2D
	if _star_chart_tex == null:
		push_warning("Missing baked level star chart at %s" % STAR_CHART_PATH)

	_nebula_mat = NebulaEffect.apply_backdrop(nebula_bg)
	set_process(true)
	_ensure_chart_sprite()
	camera.make_current()
	if title_badge != null:
		title_badge.z_index = 40
	if back_button != null:
		back_button.z_index = 50
	back_button.pressed.connect(_on_back_pressed)
	_ensure_hold_timer()
	if details_modal != null:
		details_modal.play_pressed.connect(_on_details_play_pressed)
	_apply_secondary_title_style(date_label)
	_apply_secondary_title_style(empty_label)
	_ensure_streak_label()
	_apply_translations()
	var viewport := get_viewport()
	if viewport and not viewport.size_changed.is_connected(_on_viewport_resized):
		viewport.size_changed.connect(_on_viewport_resized)
	await _await_valid_viewport()
	_rebuild_map()
	_sync_title_to_chart_pole()
	_sync_secondary_titles()
	GameSession.fade_scene_wipe_out(0.32)


func _load_day() -> void:
	_day_key = DailyCatalog.today_key()
	_levels.clear()
	_slots.clear()
	var picks := DailyCatalog.get_daily_set(_day_key)
	for slot in DailyCatalog.SLOTS:
		if picks.has(slot):
			_levels.append(picks[slot])
			_slots.append(slot)


func _ensure_streak_label() -> void:
	if _streak_label != null:
		return
	_streak_label = Label.new()
	_streak_label.name = "StreakLabel"
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_streak_label.offset_left = -400.0
	_streak_label.offset_right = 400.0
	date_label.get_parent().add_child(_streak_label)
	_streak_label.add_theme_font_override("font", MAP_FONT)
	_streak_label.add_theme_font_size_override("font_size", 36)
	_streak_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 0.82))


func _process(delta: float) -> void:
	_fx_time += delta
	## Cheap UTC-midnight check: rebuild when the day key rolls over.
	_day_check_accum += delta
	if _day_check_accum >= DAY_CHECK_INTERVAL:
		_day_check_accum = 0.0
		if DailyCatalog.today_key() != _day_key:
			_load_day()
			_apply_translations()
			_rebuild_map()
	if _nebula_mat != null and nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)


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


func _await_valid_viewport() -> void:
	var frames := 0
	var max_frames := 4 if OS.has_feature("mobile") else 60
	while not _viewport_is_ready() and frames < max_frames:
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
	date_label.text = DailyCatalog.format_date_key(_day_key)
	empty_label.text = tr("UI_DAILY_EMPTY")
	if _streak_label != null:
		_streak_label.text = tr("UI_DAILY_STREAK") % [
			GameSession.get_display_streak(_day_key), GameSession.daily_streak_best
		]
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
	if _streak_label != null:
		_streak_label.offset_top = top + 66.0
		_streak_label.offset_bottom = top + 116.0
	if empty_label != null:
		empty_label.visible = empty
		var empty_y := top + 150.0
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
		return
	var z := maxf(camera.zoom.x, 0.001)
	var start_y := (CARD_FIRST_SCREEN_Y - _title_pole_screen_y()) / z
	for i in _levels.size():
		_level_positions.append(Vector2(0.0, start_y + float(i) * CARD_SPACING))
	camera.position = Vector2(0, _camera_y_for_pole())
	_sync_chart_sprite()
	queue_redraw()


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


func _draw() -> void:
	_draw_award_stars_on(self)


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


func _draw_award_stars_on(item: CanvasItem) -> void:
	var z := maxf(camera.zoom.x, 0.001)
	var world_px := 1.0 / z
	var dsize := LEVEL_DIAMOND_SIZE
	var rim_w := 1.8 * MAP_DRAW_ZOOM * world_px
	var count := mini(_levels.size(), _level_positions.size())
	for i in count:
		var row: Vector2 = _level_positions[i]
		var center := row + Vector2(DIAMOND_X, 0.0)
		var level: LevelConfig = _levels[i]
		var slot: String = _slots[i]
		var tint := LevelDifficulty.banner_color(DailyCatalog.slot_tier(slot))
		var pts := _diamond_points(center, dsize)
		var outline := pts + PackedVector2Array([pts[0]])
		var stars := GameSession.get_daily_stars(slot, _day_key)
		var completed := stars > 0
		var hovered := i == _hover_index
		if hovered:
			NebulaEffect.draw_selection_glow(item, center, dsize, tint)
		if completed:
			item.draw_colored_polygon(pts, tint.lightened(0.20 if hovered else 0.05))
			if stars >= 3:
				FaVector.draw_star(item, center, dsize * 0.40, Color(0.95, 0.78, 0.2, 1.0),
					2.0 * MAP_DRAW_ZOOM * world_px, 1.0 * MAP_DRAW_ZOOM * world_px)
			else:
				FaVector.draw_check(item, center, dsize * 0.30, Color(1, 1, 1, 0.95))
		else:
			var wash := tint
			wash.a = 0.30 if hovered else 0.16
			item.draw_colored_polygon(pts, wash)
			item.draw_polyline(outline, tint.lightened(0.18) if hovered else tint, rim_w * (1.8 if hovered else 1.4), true)
			FaVector.draw_named(item, "play", center + Vector2(dsize * 0.03, 0), dsize * 0.28, tint.lightened(0.25))
		var text_x := row.x + TEXT_X
		_draw_text(item, tr(DailyCatalog.slot_label_key(slot)).to_upper(), Vector2(text_x, row.y - 34.0 * world_px * 1.6), 40.0, tint.lightened(0.15), world_px)
		_draw_text(item, LevelCatalog.get_level_label(level), Vector2(text_x, row.y + 14.0 * world_px * 1.6), 32.0, Color(1, 1, 1, 0.88), world_px)
		var star_r := 15.0 * world_px * 1.6
		for s_i in 3:
			var sc := Vector2(text_x + star_r + float(s_i) * star_r * 2.6, row.y + 58.0 * world_px * 1.6)
			if s_i < stars:
				FaVector.draw_award_star(item, sc, star_r, 1.6 * world_px * 1.6, 0.8 * world_px * 1.6)
			else:
				var sp := FaVector.award_star_points(sc, star_r)
				item.draw_polyline(sp + PackedVector2Array([sp[0]]), Color(1, 1, 1, 0.35), 1.4 * world_px * 1.6, true)


func _draw_text(item: CanvasItem, text: String, left_mid: Vector2, screen_px: float, color: Color, world_px: float) -> void:
	var font_size := maxi(10, int(round(screen_px * world_px)))
	var width := _map_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while width > TEXT_MAX_W and font_size > 10:
		font_size -= 1
		width = _map_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pos := Vector2(left_mid.x, left_mid.y + (_map_font.get_ascent(font_size) - _map_font.get_descent(font_size)) * 0.5)
	item.draw_string(_map_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


func _desktop_pointer() -> bool:
	return not OS.has_feature("mobile")


func _gui_blocks_hover() -> bool:
	var viewport := get_viewport()
	if viewport == null:
		return false
	var ctrl := viewport.gui_get_hovered_control()
	return ctrl != null and ctrl.mouse_filter != Control.MOUSE_FILTER_IGNORE


func _hoverable_index_at(world: Vector2) -> int:
	if not _desktop_pointer() or _gui_blocks_hover():
		return -1
	var hit := _hit_level(world)
	if hit < 0 or hit >= _levels.size():
		return -1
	return hit


func _set_hover_index(index: int) -> void:
	if _hover_index == index:
		return
	_hover_index = index
	Input.set_default_cursor_shape(
		Input.CURSOR_POINTING_HAND if index >= 0 else Input.CURSOR_ARROW
	)
	queue_redraw()


func _hit_level(world: Vector2) -> int:
	for i in _level_positions.size():
		var hit_rect := CARD_HIT
		hit_rect.position += _level_positions[i]
		if hit_rect.has_point(world):
			return i
	return -1


func _input(event: InputEvent) -> void:
	if not _desktop_pointer():
		return
	if event is InputEventMouseMotion:
		_set_hover_index(_hoverable_index_at(_screen_to_world(get_viewport().get_mouse_position())))


func _unhandled_input(event: InputEvent) -> void:
	if details_modal != null and details_modal.visible:
		return
	if OS.has_feature("mobile") and (
		event is InputEventMouseButton or event is InputEventMouseMotion
	):
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_pointer_down(_screen_to_world(mb.position), mb.position)
		else:
			_pointer_up()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		if _press_on_diamond:
			var motion := event as InputEventMouseMotion
			_pointer_drag(motion.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		_set_hover_index(-1)
		if touch.pressed:
			_pointer_down(_screen_to_world(touch.position), touch.position)
		else:
			_pointer_up()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _press_on_diamond:
			_pointer_drag((event as InputEventScreenDrag).position)
			get_viewport().set_input_as_handled()


func _on_level_clicked(index: int) -> void:
	if _navigating or index < 0 or index >= _levels.size():
		return
	_launch_level(_levels[index])


func _launch_level(level: LevelConfig) -> void:
	if _navigating or level == null:
		return
	var index := _levels.find(level)
	if index < 0:
		return
	_navigating = true
	GameSession.begin_daily_play(level, _slots[index], _day_key)
	get_tree().change_scene_to_file(GAME_SCENE)


func _ensure_hold_timer() -> void:
	if _hold_timer != null:
		return
	_hold_timer = Timer.new()
	_hold_timer.one_shot = true
	_hold_timer.wait_time = HOLD_DELAY
	_hold_timer.timeout.connect(_on_hold_timeout)
	add_child(_hold_timer)


func _pointer_down(world_pos: Vector2, screen_pos: Vector2) -> void:
	_hold_fired = false
	var hit := _hit_level(world_pos)
	var level: LevelConfig = _levels[hit] if hit >= 0 and hit < _levels.size() else null
	_press_on_diamond = level != null
	if not _press_on_diamond:
		_hold_index = -1
		return
	_hold_index = hit
	_hold_from = screen_pos
	if _hold_timer != null:
		_hold_timer.start()


func _pointer_drag(screen_pos: Vector2) -> void:
	if not _press_on_diamond:
		return
	if screen_pos.distance_to(_hold_from) >= DRAG_CANCEL_PX:
		if _hold_timer != null:
			_hold_timer.stop()
		_press_on_diamond = false
		_hold_index = -1


func _pointer_up() -> void:
	if _hold_timer != null:
		_hold_timer.stop()
	if _press_on_diamond and not _hold_fired and _hold_index >= 0:
		_on_level_clicked(_hold_index)
	_press_on_diamond = false
	_hold_index = -1
	_hold_fired = false


func _on_hold_timeout() -> void:
	if not _press_on_diamond or _hold_index < 0:
		return
	_hold_fired = true
	Haptics.light()
	if details_modal != null and _hold_index < _levels.size():
		details_modal.show_level(_levels[_hold_index])


func _on_details_play_pressed(level: LevelConfig) -> void:
	_launch_level(level)


func _on_back_pressed() -> void:
	if details_modal != null and details_modal.visible:
		details_modal.hide_modal()
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func handle_back() -> void:
	_on_back_pressed()
