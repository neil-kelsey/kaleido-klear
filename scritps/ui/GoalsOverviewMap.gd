extends Control
class_name GoalsOverviewMap

## Read-only goals map (creator-style board + edge strips) with phase status.

const EDGE_KEYS := ["left", "top", "right", "bottom"]
const MAP_SIZE := 168.0
const STRIP_THICKNESS := 16.0
const STRIP_GAP := 6.0
const BADGE_SIZE := 30.0

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
var _map_label: Label


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_layout()
	refresh()


func set_overview(goals_by_edge: Dictionary) -> void:
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
	if _map_label != null:
		_map_label.text = tr("UI_CREATOR_GOAL_MAP")


func apply_translations() -> void:
	refresh()


func _build_layout() -> void:
	_root = VBoxContainer.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	_left_strips = HBoxContainer.new()
	_left_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_left_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_left_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	_map_label = Label.new()
	_map_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_map_label.text = tr("UI_CREATOR_GOAL_MAP")
	_map_label.add_theme_color_override("font_color", UiTheme.TEXT_MUTED)
	_map_label.add_theme_font_size_override("font_size", 18)
	_map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_panel.add_child(_map_label)

	_right_strips = HBoxContainer.new()
	_right_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_right_strips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_right_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(_right_strips)

	var bottom_strips_wrap := CenterContainer.new()
	bottom_strips_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bottom_strips_wrap)
	_bottom_strips = VBoxContainer.new()
	_bottom_strips.add_theme_constant_override("separation", int(STRIP_GAP))
	_bottom_strips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_strips_wrap.add_child(_bottom_strips)


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

	if status == "current":
		var glow := ColorRect.new()
		glow.color = Color(1, 1, 1, 0.22)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		strip.add_child(glow)

	var badge := Panel.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(BADGE_SIZE, BADGE_SIZE)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = fill.darkened(0.18) if status != "completed" else Color(0.35, 0.38, 0.42, 0.9)
	badge_style.border_color = Color(1, 1, 1, 0.95) if status == "current" else Color(1, 1, 1, 0.7)
	badge_style.set_border_width_all(2 if status == "current" else 1)
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
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
	badge_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_label.text = _badge_text(goal, status)
	badge.add_child(badge_label)

	return strip


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
