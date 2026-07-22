extends Node2D

const GAME_SCENE := "res://scenes/main.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/ui/dimension_map.tscn"
const LEVEL_CREATOR_SCENE := "res://scenes/editor/level_creator.tscn"

const ZOOM_MIN := 0.55
const ZOOM_MAX := 2.75
const WHEEL_ZOOM_STEP := 0.12
const PINCH_ZOOM_SENSITIVITY := 1.0
const INTRO_ZOOM_START := 0.78
const INTRO_ZOOM_DURATION := 0.9

@onready var board: Board = $Board
@onready var camera: Camera2D = $Camera2D
@onready var back_button: Button = %BackButton
@onready var undo_button: Button = %UndoButton
@onready var restart_button: Button = %RestartButton
@onready var lives_label: Label = $UI/LivesLabel
@onready var goal_border_left: GoalBorder = $UI/GoalBorderLeft
@onready var goal_border_top: GoalBorder = $UI/GoalBorderTop
@onready var goal_border_right: GoalBorder = $UI/GoalBorderRight
@onready var goal_border_bottom: GoalBorder = $UI/GoalBorderBottom
@onready var level_complete_modal: Control = $UI/LevelCompleteModal
@onready var game_over_modal: Control = $UI/GameOverModal

var _current_level: LevelConfig = null
var _section_backdrop: SectionBackdrop = null
var _zoom: float = 1.0
var _pinch_active := false
var _pinch_touches: Dictionary = {} # index -> screen position
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_last_midpoint := Vector2.ZERO
var _pan_active := false
var _pan_pointer_id: int = -1
var _pan_last_screen := Vector2.ZERO
## Pointers claimed for tile swipes — never pan while these are held.
var _tile_pointer_ids: Dictionary = {}
var _intro_playing := false
var _intro_tween: Tween = null


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	camera.position = viewport_size * 0.5
	camera.make_current()
	_apply_zoom(1.0, camera.position)
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_ensure_section_backdrop()

	var selected_level := GameSession.consume_level()
	if selected_level != null:
		board.load_level(selected_level)

	_current_level = board.level_config
	_apply_section_theme()
	_apply_goal_borders(_current_level)
	board.goal_state_changed.connect(_on_goal_state_changed)
	board.level_cleared.connect(_on_level_cleared)
	board.life_lost.connect(_on_life_lost)
	board.game_over.connect(_on_game_over)
	board.undo_available_changed.connect(_on_undo_available_changed)
	board.undo_applied.connect(_on_undo_applied)
	level_complete_modal.next_level_pressed.connect(_on_next_level_pressed)
	level_complete_modal.remove_ads_pressed.connect(_on_remove_ads_pressed)
	level_complete_modal.share_pressed.connect(_on_share_pressed)
	game_over_modal.replay_level_pressed.connect(_on_replay_level_pressed)
	game_over_modal.level_select_pressed.connect(_on_game_over_level_select_pressed)
	UiTheme.style_hud_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	back_button.text = "  " + tr("UI_BACK")
	UiTheme.style_hud_button(undo_button)
	undo_button.icon = load("res://assets/icons/undo_icon.svg")
	undo_button.tooltip_text = tr("UI_UNDO_MOVE")
	UiTheme.style_hud_button(restart_button)
	restart_button.icon = load("res://assets/icons/refresh_icon.svg")
	restart_button.tooltip_text = tr("UI_RESTART_LEVEL")
	_update_lives_label(board.get_lives())
	lives_label.add_theme_color_override("font_color", UiTheme.TEXT)
	_update_undo_button()
	_play_level_intro()


func _on_viewport_size_changed() -> void:
	_kill_intro_tween()
	board.relayout_for_viewport()
	var viewport_size := get_viewport_rect().size
	camera.position = viewport_size * 0.5
	_apply_zoom(1.0, camera.position)
	_pan_active = false
	_pinch_active = false
	_pinch_touches.clear()
	_tile_pointer_ids.clear()
	_apply_goal_borders(_current_level)
	if _section_backdrop != null:
		_section_backdrop.relayout()
	if _intro_playing:
		_finish_level_intro()


func _ensure_section_backdrop() -> void:
	if _section_backdrop != null and is_instance_valid(_section_backdrop):
		return
	_section_backdrop = SectionBackdrop.new()
	_section_backdrop.name = "SectionBackdrop"
	add_child(_section_backdrop)
	move_child(_section_backdrop, 0)


func _apply_section_theme() -> void:
	_ensure_section_backdrop()
	var section_index := _resolve_section_index(_current_level)
	_section_backdrop.apply_section(section_index)


func _resolve_section_index(level: LevelConfig) -> int:
	if level == null:
		return 0
	var context := LevelCatalog.find_level_context(level.level_id)
	if not context.is_empty():
		return int(context.section_index)
	return clampi(level.section_index, 0, maxi(LevelCatalog.SECTIONS.size() - 1, 0))


func _play_level_intro() -> void:
	_kill_intro_tween()
	_intro_playing = true
	_set_play_controls_enabled(false)
	_pan_active = false
	_pinch_active = false
	_pinch_touches.clear()
	_tile_pointer_ids.clear()

	var center := get_viewport_rect().size * 0.5
	camera.position = center
	_apply_zoom(INTRO_ZOOM_START, center)

	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(_set_intro_zoom, INTRO_ZOOM_START, 1.0, INTRO_ZOOM_DURATION)
	_intro_tween.tween_callback(_finish_level_intro)


func _set_intro_zoom(zoom_value: float) -> void:
	_apply_zoom(zoom_value, get_viewport_rect().size * 0.5)


func _finish_level_intro() -> void:
	_kill_intro_tween()
	_intro_playing = false
	_apply_zoom(1.0, get_viewport_rect().size * 0.5)
	_set_play_controls_enabled(true)
	_update_undo_button()


func _kill_intro_tween() -> void:
	if _intro_tween != null and is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_tween = null


func _set_play_controls_enabled(enabled: bool) -> void:
	back_button.disabled = not enabled
	restart_button.disabled = not enabled
	if enabled:
		_update_undo_button()
	else:
		undo_button.disabled = true

func _apply_goal_borders(config: LevelConfig) -> void:
	if config.multi_goal_mode:
		_refresh_goal_border(Board.GoalEdge.LEFT, goal_border_left)
		_refresh_goal_border(Board.GoalEdge.TOP, goal_border_top)
		_refresh_goal_border(Board.GoalEdge.RIGHT, goal_border_right)
		_refresh_goal_border(Board.GoalEdge.BOTTOM, goal_border_bottom)
	else:
		var left_state := board.get_goal_display_state(Board.GoalEdge.LEFT)
		left_state["base_color"] = Block.get_color(config.goal_left_color)
		goal_border_left.apply_state(left_state)

		var top_state := board.get_goal_display_state(Board.GoalEdge.TOP)
		top_state["base_color"] = Block.get_color(config.goal_top_color)
		goal_border_top.apply_state(top_state)

		var right_state := board.get_goal_display_state(Board.GoalEdge.RIGHT)
		right_state["base_color"] = Block.get_color(config.goal_right_color)
		goal_border_right.apply_state(right_state)

		var bottom_state := board.get_goal_display_state(Board.GoalEdge.BOTTOM)
		bottom_state["base_color"] = Block.get_color(config.goal_bottom_color)
		goal_border_bottom.apply_state(bottom_state)


func _refresh_goal_border(goal_edge: int, border: GoalBorder) -> void:
	border.apply_state(board.get_goal_display_state(goal_edge))


func _on_goal_state_changed(goal_edge: int, state: Dictionary) -> void:
	match goal_edge:
		Board.GoalEdge.LEFT:
			goal_border_left.apply_state(state)
		Board.GoalEdge.TOP:
			goal_border_top.apply_state(state)
		Board.GoalEdge.RIGHT:
			goal_border_right.apply_state(state)
		Board.GoalEdge.BOTTOM:
			goal_border_bottom.apply_state(state)


func _input(event: InputEvent) -> void:
	if _intro_playing:
		return
	if _is_modal_open():
		return
	if event.is_action_pressed("ui_cancel"):
		_go_back()
		return

	# Never pan the map while a tile swipe is in progress.
	if board.is_dragging:
		_end_pan()

	if _handle_camera_input(event):
		return

	# Android synthesizes mouse events for finger 0. If those reach the board
	# first, cells unregister and the following touch is treated as empty-space
	# pan. Route play input through ScreenTouch/ScreenDrag only.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return
	if event is InputEventMouseMotion:
		return

	board.handle_input_event(event)


func _handle_camera_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_screen_point(event.position, _zoom * (1.0 + WHEEL_ZOOM_STEP))
			return true
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_screen_point(event.position, _zoom * (1.0 - WHEEL_ZOOM_STEP))
			return true

	if event is InputEventScreenTouch:
		if _handle_pinch_touch(event):
			return true
		if event.pressed:
			return _claim_pointer_on_press(event.index, event.position)
		return _release_pointer(event.index)

	if event is InputEventScreenDrag:
		if board.is_dragging or _tile_pointer_ids.has(event.index):
			_end_pan()
			return false
		if _handle_pinch_drag(event):
			return true
		if _pan_active and _pan_pointer_id == event.index:
			_update_pan(event.position)
			return true

	return false


func _claim_pointer_on_press(pointer_id: int, screen_pos: Vector2) -> bool:
	if _pinch_active or _pinch_touches.size() >= 2:
		return true

	# Already swiping a tile, or pressing on a playable block → tile owns this pointer.
	if board.is_dragging or board.is_swipable_at_screen(screen_pos):
		_tile_pointer_ids[pointer_id] = true
		_end_pan()
		return false

	# Empty / wall / background → map pan only.
	_tile_pointer_ids.erase(pointer_id)
	_pan_active = true
	_pan_pointer_id = pointer_id
	_pan_last_screen = screen_pos
	return true


func _release_pointer(pointer_id: int) -> bool:
	_tile_pointer_ids.erase(pointer_id)
	if _pan_active and _pan_pointer_id == pointer_id:
		_end_pan()
		return true
	return false


func _update_pan(screen_pos: Vector2) -> void:
	if board.is_dragging:
		_end_pan()
		return
	var delta := screen_pos - _pan_last_screen
	_pan_last_screen = screen_pos
	if delta.length_squared() <= 0.01:
		return
	camera.position -= delta / _zoom
	_clamp_camera()


func _end_pan() -> void:
	_pan_active = false
	_pan_pointer_id = -1


func _handle_pinch_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_pinch_touches[event.index] = event.position
		if _pinch_touches.size() >= 2:
			board.cancel_active_pointer()
			_tile_pointer_ids.clear()
			_end_pan()
			_begin_pinch()
			return true
		return false

	_pinch_touches.erase(event.index)
	if _pinch_touches.size() < 2:
		_pinch_active = false
	return false


func _handle_pinch_drag(event: InputEventScreenDrag) -> bool:
	if not _pinch_touches.has(event.index):
		return false
	_pinch_touches[event.index] = event.position
	if _pinch_touches.size() < 2:
		return false
	if not _pinch_active:
		board.cancel_active_pointer()
		_tile_pointer_ids.clear()
		_end_pan()
		_begin_pinch()
	_update_pinch()
	return true
func _begin_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2:
		return
	_pinch_active = true
	_pinch_start_distance = points[0].distance_to(points[1])
	_pinch_start_zoom = _zoom
	_pinch_last_midpoint = (points[0] + points[1]) * 0.5


func _update_pinch() -> void:
	var points := _pinch_points()
	if points.size() < 2 or _pinch_start_distance <= 0.001:
		return
	var midpoint := (points[0] + points[1]) * 0.5
	var distance := points[0].distance_to(points[1])
	var target_zoom := _pinch_start_zoom * (distance / _pinch_start_distance) * PINCH_ZOOM_SENSITIVITY
	_zoom_at_screen_point(midpoint, target_zoom)

	# Two-finger pan: move camera opposite to midpoint movement.
	var mid_delta := midpoint - _pinch_last_midpoint
	if mid_delta.length_squared() > 0.01:
		camera.position -= mid_delta / _zoom
		_clamp_camera()
	_pinch_last_midpoint = midpoint


func _pinch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in _pinch_touches.keys():
		points.append(_pinch_touches[key])
		if points.size() >= 2:
			break
	return points


func _zoom_at_screen_point(screen_point: Vector2, target_zoom: float) -> void:
	var old_zoom := _zoom
	var new_zoom := clampf(target_zoom, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(old_zoom, new_zoom):
		return

	# Keep the world point under the cursor/pinch stable while zooming.
	var canvas := get_viewport().get_canvas_transform()
	var world_before: Vector2 = canvas.affine_inverse() * screen_point
	_apply_zoom(new_zoom, camera.position)
	canvas = get_viewport().get_canvas_transform()
	var world_after: Vector2 = canvas.affine_inverse() * screen_point
	camera.position += world_before - world_after
	_clamp_camera()


func _apply_zoom(zoom_value: float, keep_position: Vector2) -> void:
	_zoom = clampf(zoom_value, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(_zoom, _zoom)
	camera.position = keep_position


func _clamp_camera() -> void:
	# Soft clamp: keep camera near the design viewport so UI gutters stay usable.
	var viewport_size := get_viewport_rect().size
	var margin := viewport_size * 0.35
	camera.position.x = clampf(camera.position.x, -margin.x, viewport_size.x + margin.x)
	camera.position.y = clampf(camera.position.y, -margin.y, viewport_size.y + margin.y)


func _is_modal_open() -> bool:
	return level_complete_modal.visible or game_over_modal.visible


func _go_to_level_select() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _go_to_level_creator() -> void:
	GameSession.end_playtest()
	get_tree().change_scene_to_file(LEVEL_CREATOR_SCENE)


func _go_back() -> void:
	if GameSession.playtest_mode:
		_go_to_level_creator()
	else:
		_go_to_level_select()


func _on_back_button_pressed() -> void:
	_go_back()


func _on_restart_button_pressed() -> void:
	_restart_level()


func _on_undo_button_pressed() -> void:
	if board.undo_last_move():
		_update_undo_button()


func _on_undo_available_changed(_available: bool) -> void:
	_update_undo_button()


func _on_undo_applied(remaining_lives: int) -> void:
	_update_lives_label(remaining_lives)
	if game_over_modal.visible:
		game_over_modal.hide()
	_update_undo_button()


func _update_undo_button() -> void:
	undo_button.disabled = (
		_intro_playing
		or not board.can_undo_move()
		or _is_modal_open()
	)

func _restart_level() -> void:
	if _current_level == null:
		return
	GameSession.restart_level(_current_level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_level_cleared(remaining_lives: int) -> void:
	if GameSession.playtest_mode:
		GameSession.mark_playtest_passed()
		level_complete_modal.show_playtest_success()
		return
	var stars := clampi(remaining_lives, 1, 3)
	GameSession.record_level_stars(_current_level, stars)
	var section_complete := LevelCatalog.is_last_level_in_section(_current_level)
	var has_next_section := LevelCatalog.has_next_section(_current_level)
	level_complete_modal.show_result(stars, section_complete, has_next_section)


func _on_life_lost(remaining_lives: int) -> void:
	_update_lives_label(remaining_lives)


func _on_game_over() -> void:
	Sfx.play_fail()
	game_over_modal.show_modal()


func _on_replay_level_pressed() -> void:
	_restart_level()


func _on_game_over_level_select_pressed() -> void:
	_go_back()


func _on_next_level_pressed() -> void:
	if GameSession.playtest_mode:
		_go_to_level_creator()
		return
	var next_level := GameSession.get_next_level(_current_level)
	if next_level != null:
		GameSession.set_level(next_level)
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	if LevelCatalog.has_next_section(_current_level):
		var first_level := LevelCatalog.get_first_level_of_next_section(_current_level)
		GameSession.set_level(first_level)
		get_tree().change_scene_to_file(GAME_SCENE)
		return
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func _on_remove_ads_pressed() -> void:
	# Placeholder until ad integration is added.
	print("Remove ads tapped")


func _on_share_pressed() -> void:
	var stars := GameSession.get_level_stars(_current_level.level_id)
	var share_text := tr("UI_SHARE_MESSAGE") % [tr(_current_level.level_name_key), stars]
	DisplayServer.clipboard_set(share_text)
	print(share_text)


func _update_lives_label(remaining_lives: int) -> void:
	lives_label.text = tr("UI_LIVES") % remaining_lives
