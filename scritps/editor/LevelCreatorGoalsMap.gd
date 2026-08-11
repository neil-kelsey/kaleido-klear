extends Control
class_name LevelCreatorGoalsMap

## Map-centric goal editor: board preview in the centre, Add goal on each edge,
## stacked coloured strips with count / ∞ badges (first phase closest to the board).

signal goals_changed
signal add_goal_requested(edge_key: String)
signal edit_goal_requested(edge_key: String, index: int)

const EDGE_KEYS := ["left", "top", "right", "bottom"]
const MAP_SIZE := 148.0
const STRIP_THICKNESS := 14.0
const STRIP_GAP := 5.0
const BADGE_SIZE := 26.0
const ADD_BTN_MIN := Vector2(118, 44)

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
var _add_buttons: Dictionary = {}


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_layout()
	refresh()


func set_edge_goals(edge_key: String, goals: Array) -> void:
	if not _goals.has(edge_key):
		return
	_goals[edge_key] = goals.duplicate(true)
	refresh()


func get_edge_goals(edge_key: String) -> Array:
	if not _goals.has(edge_key):
		return []
	return (_goals[edge_key] as Array).duplicate(true)


func set_all_goals(goals_by_edge: Dictionary) -> void:
	for edge_key in EDGE_KEYS:
		_goals[edge_key] = goals_by_edge.get(edge_key, []).duplicate(true)
	refresh()


func refresh() -> void:
	if _top_strips == null:
		return
	_rebuild_edge_strips("top", _top_strips)
	_rebuild_edge_strips("bottom", _bottom_strips)
	_rebuild_edge_strips("left", _left_strips)
	_rebuild_edge_strips("right", _right_strips)
	_update_map_size()


func _build_layout() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 10)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_root)

	var top_add_wrap := CenterContainer.new()
	_root.add_child(top_add_wrap)
	top_add_wrap.add_child(_make_add_button("top"))

	var top_strips_wrap := CenterContainer.new()
	_root.add_child(top_strips_wrap)
	_top_strips = VBoxContainer.new()
	_top_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	top_strips_wrap.add_child(_top_strips)

	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 10)
	_root.add_child(mid)

	mid.add_child(_make_add_button("left"))

	_left_strips = HBoxContainer.new()
	_left_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_left_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(_left_strips)

	_map_panel = Panel.new()
	_map_panel.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	_map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var map_style := StyleBoxFlat.new()
	map_style.bg_color = Color(0.12, 0.13, 0.16, 1)
	map_style.border_color = Color(0.35, 0.38, 0.45, 1)
	map_style.set_border_width_all(2)
	map_style.set_corner_radius_all(12)
	_map_panel.add_theme_stylebox_override("panel", map_style)
	mid.add_child(_map_panel)

	var map_label := Label.new()
	map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map_label.text = tr("UI_CREATOR_GOAL_MAP")
	map_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	map_label.add_theme_font_size_override("font_size", 16)
	map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(map_label)

	_right_strips = HBoxContainer.new()
	_right_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_right_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mid.add_child(_right_strips)

	mid.add_child(_make_add_button("right"))

	var bottom_strips_wrap := CenterContainer.new()
	_root.add_child(bottom_strips_wrap)
	_bottom_strips = VBoxContainer.new()
	_bottom_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	bottom_strips_wrap.add_child(_bottom_strips)

	var bottom_add_wrap := CenterContainer.new()
	_root.add_child(bottom_add_wrap)
	bottom_add_wrap.add_child(_make_add_button("bottom"))


func _make_add_button(edge_key: String) -> Control:
	var button := Button.new()
	button.text = tr("UI_CREATOR_ADD_GOAL")
	button.custom_minimum_size = ADD_BTN_MIN
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func() -> void:
		add_goal_requested.emit(edge_key)
	)
	UiTheme.style_secondary_button(button, UiTheme.ButtonScale.COMPACT)
	_add_buttons[edge_key] = button

	## Side buttons sit in a tall mid-row; wrap so they keep the same pill height.
	if edge_key == "left" or edge_key == "right":
		var wrap := CenterContainer.new()
		wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrap.add_child(button)
		return wrap
	return button


func _update_map_size() -> void:
	var side := MAP_SIZE
	_map_panel.custom_minimum_size = Vector2(side, side)


func _rebuild_edge_strips(edge_key: String, host: Container) -> void:
	for child in host.get_children():
		child.queue_free()
	var goals: Array = _goals[edge_key]
	if goals.is_empty():
		return

	var horizontal_strip := edge_key == "top" or edge_key == "bottom"
	## First phase sits closest to the board.
	match edge_key:
		"top", "left":
			for i in range(goals.size() - 1, -1, -1):
				host.add_child(_make_strip(edge_key, i, goals[i], horizontal_strip))
		"bottom", "right":
			for i in goals.size():
				host.add_child(_make_strip(edge_key, i, goals[i], horizontal_strip))


func _make_strip(edge_key: String, index: int, goal: Dictionary, horizontal_strip: bool) -> Button:
	var fill: Color = Block.get_color(goal["color"] as Block.TileColor)
	var strip := Button.new()
	strip.focus_mode = Control.FOCUS_NONE
	strip.tooltip_text = tr("UI_CREATOR_GOAL_TAP_EDIT")
	strip.clip_contents = false
	if horizontal_strip:
		strip.custom_minimum_size = Vector2(MAP_SIZE, maxf(STRIP_THICKNESS, BADGE_SIZE))
	else:
		strip.custom_minimum_size = Vector2(maxf(STRIP_THICKNESS, BADGE_SIZE), MAP_SIZE)

	var bar := ColorRect.new()
	bar.color = fill
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if horizontal_strip:
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.5
		bar.anchor_bottom = 0.5
		bar.offset_top = -STRIP_THICKNESS * 0.5
		bar.offset_bottom = STRIP_THICKNESS * 0.5
	else:
		bar.anchor_top = 0.0
		bar.anchor_bottom = 1.0
		bar.anchor_left = 0.5
		bar.anchor_right = 0.5
		bar.offset_left = -STRIP_THICKNESS * 0.5
		bar.offset_right = STRIP_THICKNESS * 0.5
	strip.add_child(bar)

	var empty := StyleBoxEmpty.new()
	strip.add_theme_stylebox_override("normal", empty)
	strip.add_theme_stylebox_override("hover", empty)
	strip.add_theme_stylebox_override("pressed", empty)
	strip.add_theme_stylebox_override("focus", empty)
	strip.pressed.connect(_on_strip_pressed.bind(edge_key, index))

	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = fill.darkened(0.22)
	badge_style.border_color = Color(1, 1, 1, 0.9)
	badge_style.set_border_width_all(1)
	badge_style.set_corner_radius_all(int(BADGE_SIZE * 0.5))
	badge.add_theme_stylebox_override("panel", badge_style)
	badge.set_anchors_preset(Control.PRESET_CENTER)
	badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	badge.offset_left = -BADGE_SIZE * 0.5
	badge.offset_top = -BADGE_SIZE * 0.5
	badge.offset_right = BADGE_SIZE * 0.5
	badge.offset_bottom = BADGE_SIZE * 0.5
	strip.add_child(badge)

	var badge_label := Label.new()
	badge_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 13)
	badge_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bool(goal.get("unlimited", false)):
		badge_label.text = "∞"
	else:
		badge_label.text = str(int(goal.get("count", 1)))
	badge.add_child(badge_label)

	return strip


func _on_strip_pressed(edge_key: String, index: int) -> void:
	var goals: Array = _goals[edge_key]
	if index < 0 or index >= goals.size():
		return
	edit_goal_requested.emit(edge_key, index)


func apply_translations() -> void:
	for edge_key in _add_buttons.keys():
		var button: Button = _add_buttons[edge_key]
		button.text = tr("UI_CREATOR_ADD_GOAL")
	if _map_panel != null and _map_panel.get_child_count() > 0:
		var map_label := _map_panel.get_child(0) as Label
		if map_label != null:
			map_label.text = tr("UI_CREATOR_GOAL_MAP")
