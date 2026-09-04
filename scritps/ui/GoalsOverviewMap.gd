extends Control
class_name GoalsOverviewMap

## Read-only goals map (creator-style board + edge strips) with phase status.

const EDGE_KEYS := ["left", "top", "right", "bottom"]
const MAP_SIZE := 280.0
const STRIP_THICKNESS := 22.0
const STRIP_GAP := 14.0
const BADGE_W := 92.0
const BADGE_H := 44.0
const VIEW_PAD := 20.0
const ZOOM_MAX := 2.4
const WHEEL_ZOOM_STEP := 0.12
const PINCH_ZOOM_SENSITIVITY := 1.0

## goals_by_edge[edge] = Array of {
##   color: TileColor, unlimited: bool, count: int,
##   status: "completed"|"current"|"upcoming", scored: int
## }
var _goals: Dictionary = {
	"left": [],
	"top": [],
	"right": [],
	"bottom": [],
}

var _root: VBoxContainer
var _map_panel: Panel
var _top_strips: VBoxContainer
var _bottom_strips: VBoxContainer
var _left_strips: HBoxContainer
var _right_strips: HBoxContainer
var _left_slot: HBoxContainer
var _right_slot: HBoxContainer
var _map_label: Label
var _zoom := 1.0
var _fit_zoom := 1.0
var _pan := Vector2.ZERO
var _pinch_active := false
var _pinch_touches: Dictionary = {}
var _pinch_start_distance := 0.0
var _pinch_start_zoom := 1.0
var _pinch_last_midpoint := Vector2.ZERO


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_on_resized)
	_build_layout()
	refresh()


func set_overview(goals_by_edge: Dictionary) -> void:
	for edge_key in EDGE_KEYS:
		_goals[edge_key] = goals_by_edge.get(edge_key, []).duplicate(true)
	refresh()
	call_deferred("_fit_to_view")


func refresh() -> void:
	if _top_strips == null:
		return
	_rebuild_edge_strips("top", _top_strips)
	_rebuild_edge_strips("bottom", _bottom_strips)
	_rebuild_edge_strips("left", _left_strips)
	_rebuild_edge_strips("right", _right_strips)
	_sync_side_slots()
	if _map_label != null:
		_map_label.text = tr("UI_CREATOR_GOAL_MAP")
	call_deferred("_keep_view_valid")


func apply_translations() -> void:
	refresh()


func _build_layout() -> void:
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 10)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var top_strips_wrap := CenterContainer.new()
	top_strips_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_strips_wrap)
	_top_strips = VBoxContainer.new()
	_top_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_top_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_strips_wrap.add_child(_top_strips)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(mid)

	_left_slot = HBoxContainer.new()
	_left_slot.alignment = BoxContainer.ALIGNMENT_END
	_left_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_left_slot)
	_left_strips = HBoxContainer.new()
	_left_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_left_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_slot.add_child(_left_strips)

	_map_panel = Panel.new()
	_map_panel.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.92, 0.93, 0.96, 0.92)
	map_style.border_color = Color(0.55, 0.58, 0.65, 1)
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(12)
	_map_panel.add_theme_stylebox_override("panel", map_style)
	mid.add_child(_map_panel)

	_map_label = Label.new()
	_map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_label.text = tr("UI_CREATOR_GOAL_MAP")
	_map_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	_map_label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	_map_label.add_theme_font_size_override("font_size", 28)
	_map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(_map_label)

	_right_slot = HBoxContainer.new()
	_right_slot.alignment = BoxContainer.ALIGNMENT_BEGIN
	_right_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_right_slot)
	_right_strips = HBoxContainer.new()
	_right_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_right_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_slot.add_child(_right_strips)

	var bottom_strips_wrap := CenterContainer.new()
	bottom_strips_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom_strips_wrap)
	_bottom_strips = VBoxContainer.new()
	_bottom_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_bottom_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_strips_wrap.add_child(_bottom_strips)


func _sync_side_slots() -> void:
	if _left_slot == null or _right_slot == null:
		return
	## Keep the board centred even when one side has more phases than the other.
	var col_w := maxf(
		_left_strips.get_combined_minimum_size().x,
		_right_strips.get_combined_minimum_size().x
	)
	_left_slot.custom_minimum_size.x = col_w
	_right_slot.custom_minimum_size.x = col_w


func _rebuild_edge_strips(edge_key: String, host: Container) -> void:
	for child in host.get_children():
		host.remove_child(child)
		child.queue_free()
	var goals: Array = _goals[edge_key]
	if goals.is_empty():
		return

	var horizontal_strip := edge_key == "top" or edge_key == "bottom"
	## First phase sits closest to the board.
	match edge_key:
		"top", "left":
			for i in range(goals.size() - 1, -1, -1):
				host.add_child(_make_strip(goals[i], horizontal_strip))
		"bottom", "right":
			for i in goals.size():
				host.add_child(_make_strip(goals[i], horizontal_strip))


func _make_strip(goal: Dictionary, horizontal_strip: bool) -> Control:
	var status := str(goal.get("status", "upcoming"))
	var fill: Color = Block.get_color(goal["color"] as Block.TileColor)
	if status == "completed":
		fill = fill.darkened(0.35)
		fill.a = 0.45
	elif status == "current":
		fill = fill.lightened(0.06)

	var strip := Control.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.clip_contents = false
	if horizontal_strip:
		strip.custom_minimum_size = Vector2(MAP_SIZE, maxf(STRIP_THICKNESS, BADGE_H))
	else:
		strip.custom_minimum_size = Vector2(maxf(STRIP_THICKNESS, BADGE_W), MAP_SIZE)

	var bar := ColorRect.new()
	bar.color = fill
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_strip_bar(bar, horizontal_strip)
	strip.add_child(bar)

	if status == "current":
		var glow := ColorRect.new()
		glow.color = Color(1, 1, 1, 0.18)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layout_strip_bar(glow, horizontal_strip)
		strip.add_child(glow)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.clip_text = false
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	badge.add_theme_font_size_override("font_size", UiTheme.HUD_BUTTON_FONT_SIZE)
	badge.text = _badge_text(goal, status)
	var pill_fill := fill
	pill_fill.a = 1.0
	if status == "completed":
		pill_fill = Color(0.32, 0.34, 0.38, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = pill_fill
	style.set_corner_radius_all(20)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	badge.add_theme_stylebox_override("normal", style)
	badge.add_theme_color_override("font_color", UiTheme.contrast_on(pill_fill))
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.offset_left = -BADGE_W * 0.5
	badge.offset_right = BADGE_W * 0.5
	badge.offset_top = -BADGE_H * 0.5
	badge.offset_bottom = BADGE_H * 0.5
	strip.add_child(badge)

	return strip


func _layout_strip_bar(bar: Control, horizontal_strip: bool) -> void:
	bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if horizontal_strip:
		bar.set_anchor(SIDE_TOP, 0.5, true)
		bar.set_anchor(SIDE_BOTTOM, 0.5, true)
		bar.offset_left = 0.0
		bar.offset_right = 0.0
		bar.offset_top = -STRIP_THICKNESS * 0.5
		bar.offset_bottom = STRIP_THICKNESS * 0.5
	else:
		bar.set_anchor(SIDE_LEFT, 0.5, true)
		bar.set_anchor(SIDE_RIGHT, 0.5, true)
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bar.offset_left = -STRIP_THICKNESS * 0.5
		bar.offset_right = STRIP_THICKNESS * 0.5


func _badge_text(goal: Dictionary, status: String) -> String:
	if status == "completed":
		return "✓"
	if bool(goal.get("unlimited", false)):
		if status == "current":
			var scored := int(goal.get("scored", 0))
			return "∞" if scored <= 0 else str(scored)
		return "∞"
	var count := int(goal.get("count", 1))
	if status == "current":
		var scored_cur := int(goal.get("scored", 0))
		return "%d/%d" % [scored_cur, count]
	return str(count)


func fit_in_view() -> void:
	_fit_to_view()


func _on_resized() -> void:
	_recompute_fit_zoom()
	_zoom = clampf(_zoom, _fit_zoom, ZOOM_MAX)
	_apply_view()


func _keep_view_valid() -> void:
	_recompute_fit_zoom()
	_zoom = clampf(_zoom, _fit_zoom, ZOOM_MAX)
	_apply_view()


func _fit_to_view() -> void:
	_recompute_fit_zoom()
	_zoom = _fit_zoom
	_pan = Vector2.ZERO
	_apply_view()


func _recompute_fit_zoom() -> void:
	if _root == null or size.x < 8.0 or size.y < 8.0:
		return
	_root.reset_size()
	var natural := _root.get_combined_minimum_size()
	if natural.x < 1.0 or natural.y < 1.0:
		return
	_root.size = natural
	var avail := size - Vector2(VIEW_PAD, VIEW_PAD) * 2.0
	if avail.x < 1.0 or avail.y < 1.0:
		return
	_fit_zoom = minf(avail.x / natural.x, avail.y / natural.y)
	_fit_zoom = clampf(_fit_zoom, 0.22, 1.0)


func _apply_view() -> void:
	if _root == null:
		return
	_root.scale = Vector2(_zoom, _zoom)
	var scaled := _root.size * _zoom
	_clamp_pan(scaled)
	_root.position = (size - scaled) * 0.5 + _pan


func _clamp_pan(scaled: Vector2) -> void:
	var slack := (scaled - size) * 0.5
	if slack.x <= 0.0:
		_pan.x = 0.0
	else:
		_pan.x = clampf(_pan.x, -slack.x, slack.x)
	if slack.y <= 0.0:
		_pan.y = 0.0
	else:
		_pan.y = clampf(_pan.y, -slack.y, slack.y)


func _zoom_at_local(local_point: Vector2, new_zoom: float) -> void:
	var old_zoom := maxf(_zoom, 0.001)
	var focus := (local_point - _root.position) / old_zoom
	_zoom = clampf(new_zoom, _fit_zoom, ZOOM_MAX)
	var scaled := _root.size * _zoom
	var centered := (size - scaled) * 0.5
	_pan = local_point - focus * _zoom - centered
	_apply_view()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_local(mb.position, _zoom * (1.0 + WHEEL_ZOOM_STEP))
			accept_event()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_local(mb.position, _zoom * (1.0 - WHEEL_ZOOM_STEP))
			accept_event()
			return
	if event is InputEventMagnifyGesture:
		var mag := event as InputEventMagnifyGesture
		_zoom_at_local(mag.position, _zoom * mag.factor)
		accept_event()
		return
	if event is InputEventScreenTouch:
		if _handle_pinch_touch(event as InputEventScreenTouch):
			accept_event()
		return
	if event is InputEventScreenDrag:
		if _handle_pinch_drag(event as InputEventScreenDrag):
			accept_event()


func _handle_pinch_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_pinch_touches[event.index] = event.position
		if _pinch_touches.size() >= 2:
			_begin_pinch()
			return true
		return false
	var pinching := _pinch_active or _pinch_touches.size() >= 2
	_pinch_touches.erase(event.index)
	if _pinch_touches.size() < 2:
		_pinch_active = false
	return pinching


func _handle_pinch_drag(event: InputEventScreenDrag) -> bool:
	if not _pinch_touches.has(event.index):
		return false
	_pinch_touches[event.index] = event.position
	if _pinch_touches.size() < 2:
		return false
	if not _pinch_active:
		_begin_pinch()
	_update_pinch()
	return true


func _pinch_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for key in _pinch_touches.keys():
		points.append(_pinch_touches[key])
		if points.size() >= 2:
			break
	return points


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
	_zoom_at_local(midpoint, target_zoom)
	var mid_delta := midpoint - _pinch_last_midpoint
	if mid_delta.length_squared() > 0.01:
		_pan += mid_delta
		_apply_view()
	_pinch_last_midpoint = midpoint
