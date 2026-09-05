extends Control
class_name TutorialWalkthrough

## Spotlight coach marks for the first level of each Tutorial chapter.

signal finished

const DIM := Color(0, 0, 0, 0.62)
const GOLD := Color(0.82, 0.68, 0.28, 0.95)
const HOLE_PAD := 10.0
const CARD_MARGIN := 20.0
const CARD_GAP := 20.0
const CARD_MAX_WIDTH := 820.0
const CARD_PAD_X := 56.0
const CARD_PAD_Y := 48.0
const TITLE_FONT_SIZE := 58
const BODY_FONT_SIZE := 40
const BODY_LINE_SPACING := 14

const SCRIPTS := {
	"UI_GROUP_BASIC_TRAINING": {
		"id": "UI_GROUP_BASIC_TRAINING",
		"title_key": "UI_GROUP_BASIC_TRAINING",
		"steps": [
			{"text_key": "UI_TUTORIAL_BASIC_SWIPE", "spotlight": "board"},
			{"text_key": "UI_TUTORIAL_BASIC_GOALS", "spotlight": "goal_edges"},
			{"text_key": "UI_TUTORIAL_BASIC_LIVES", "spotlight": "lives"},
		],
	},
	"UI_GROUP_COLOUR_MIX": {
		"id": "UI_GROUP_COLOUR_MIX",
		"title_key": "UI_GROUP_COLOUR_MIX",
		"steps": [
			{"text_key": "UI_TUTORIAL_COLOUR_MIX_BLEND", "spotlight": "board"},
			{"text_key": "UI_TUTORIAL_COLOUR_MIX_GOALS", "spotlight": "goal_edges"},
			{"text_key": "UI_TUTORIAL_COLOUR_MIX_ONCE", "spotlight": "board"},
		],
	},
	"UI_GROUP_SHIFTING_GOALS": {
		"id": "UI_GROUP_SHIFTING_GOALS",
		"title_key": "UI_GROUP_SHIFTING_GOALS",
		"steps": [
			{"text_key": "UI_TUTORIAL_SHIFTING_CHEVRONS", "spotlight": "goal_edges"},
			{"text_key": "UI_TUTORIAL_SHIFTING_MAP", "spotlight": "goals_button"},
		],
	},
	"UI_GROUP_WALLS": {
		"id": "UI_GROUP_WALLS",
		"title_key": "UI_GROUP_WALLS",
		"steps": [
			{"text_key": "UI_TUTORIAL_WALLS", "spotlight": "board"},
		],
	},
	"UI_GROUP_BIGGER_BOARDS": {
		"id": "UI_GROUP_BIGGER_BOARDS",
		"title_key": "UI_GROUP_BIGGER_BOARDS",
		"steps": [
			{"text_key": "UI_TUTORIAL_BIGGER_BOARDS", "spotlight": "board"},
		],
	},
}

var _script: Dictionary = {}
var _step_index: int = 0
var _host: Node = null

var _dim_top: ColorRect
var _dim_left: ColorRect
var _dim_right: ColorRect
var _dim_bottom: ColorRect
var _hole_catcher: ColorRect
var _ring: Panel
var _card: PanelContainer
var _title: Label
var _body: Label
var _next_button: MenuActionButton


static func script_for_group(level: LevelConfig) -> Dictionary:
	if level == null or GameSession.playtest_mode:
		return {}
	if not _is_tutorial_level(level):
		return {}
	var group := level.group_title_key.strip_edges()
	if not SCRIPTS.has(group):
		return {}
	return (SCRIPTS[group] as Dictionary).duplicate(true)


static func script_for(level: LevelConfig, replay: bool = false) -> Dictionary:
	var script := script_for_group(level)
	if script.is_empty():
		return {}
	if replay:
		return script
	if not LevelCatalog.is_first_level_of_group(level):
		return {}
	if GameSession.has_seen_tutorial(str(script.get("id", ""))):
		return {}
	return script


static func _is_tutorial_level(level: LevelConfig) -> bool:
	if LevelCatalog.is_tutorial_dimension(level.section_index):
		return true
	var context := LevelCatalog.find_level_context(level.level_id)
	return not context.is_empty() and LevelCatalog.is_tutorial_dimension(int(context.section_index))


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout_step)
	gui_input.connect(_on_overlay_gui_input)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and visible:
		_apply_step_copy()


func begin(script: Dictionary, host: Node) -> void:
	_script = script
	_host = host
	_step_index = 0
	visible = true
	_apply_step_copy()
	_layout_step()
	call_deferred("_layout_step")


func relayout() -> void:
	_layout_step()


func dismiss() -> void:
	_complete()


func _complete() -> void:
	var id := str(_script.get("id", ""))
	if not id.is_empty():
		GameSession.mark_tutorial_seen(id)
	visible = false
	_script = {}
	_host = null
	finished.emit()


func _build() -> void:
	_dim_top = _make_dim()
	_dim_left = _make_dim()
	_dim_right = _make_dim()
	_dim_bottom = _make_dim()
	_hole_catcher = ColorRect.new()
	_hole_catcher.color = Color(0, 0, 0, 0)
	_hole_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hole_catcher)

	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.draw_center = false
	ring_style.border_color = GOLD
	ring_style.set_border_width_all(4)
	ring_style.set_corner_radius_all(18)
	_ring.add_theme_stylebox_override("panel", ring_style)
	add_child(_ring)

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.97, 0.97, 0.985, 1.0)
	card_style.set_corner_radius_all(28)
	card_style.content_margin_left = CARD_PAD_X
	card_style.content_margin_top = CARD_PAD_Y
	card_style.content_margin_right = CARD_PAD_X
	card_style.content_margin_bottom = CARD_PAD_Y
	card_style.border_color = Color(0.82, 0.68, 0.28, 0.7)
	card_style.set_border_width_all(3)
	card_style.shadow_color = Color(0, 0, 0, 0.32)
	card_style.shadow_size = 14
	card_style.shadow_offset = Vector2(0, 6)
	_card.add_theme_stylebox_override("panel", card_style)
	## Extra content height must grow upward so the bottom gap stays put.
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	_card.add_child(vbox)

	_title = Label.new()
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_chart_modal_copy(_title)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	vbox.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_chart_modal_copy(null, _body)
	_body.add_theme_font_size_override("font_size", BODY_FONT_SIZE)
	_body.add_theme_constant_override("line_spacing", BODY_LINE_SPACING)
	vbox.add_child(_body)

	_next_button = MenuActionButton.new()
	_next_button.kind = MenuActionButton.Kind.PRIMARY
	_next_button.compact = true
	_next_button.show_trailing_icon = false
	_next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next_button.custom_minimum_size = Vector2(0, 128)
	_next_button.pressed.connect(_on_next_pressed)
	vbox.add_child(_next_button)


func _make_dim() -> ColorRect:
	var dim := ColorRect.new()
	dim.color = DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	return dim


func _on_overlay_gui_input(event: InputEvent) -> void:
	## Touch is emulated from mouse in this project, so ScreenTouch is enough.
	if event is InputEventScreenTouch and event.pressed:
		_on_next_pressed()
		accept_event()


func _on_next_pressed() -> void:
	var steps: Array = _script.get("steps", [])
	if _step_index + 1 >= steps.size():
		_complete()
		return
	_step_index += 1
	_apply_step_copy()
	_layout_step()


func _apply_step_copy() -> void:
	var steps: Array = _script.get("steps", [])
	if _step_index < 0 or _step_index >= steps.size():
		return
	var step: Dictionary = steps[_step_index]
	_title.text = tr(str(_script.get("title_key", "")))
	_body.text = tr(str(step.get("text_key", "")))
	var last := _step_index >= steps.size() - 1
	_next_button.set_label(tr("UI_TUTORIAL_GOT_IT" if last else "UI_TUTORIAL_NEXT"))


func _layout_step() -> void:
	if not visible:
		return
	var vp := size
	if vp.x <= 1.0 or vp.y <= 1.0:
		return
	var hole := _spotlight_rect().grow(HOLE_PAD)
	hole = hole.intersection(Rect2(Vector2.ZERO, vp).grow(-8.0))
	if hole.size.x < 8.0 or hole.size.y < 8.0:
		hole = Rect2()

	_fit_rect(_dim_top, Rect2(0, 0, vp.x, hole.position.y if hole.size.y > 0.0 else vp.y))
	if hole.size.y <= 0.0:
		_fit_rect(_dim_left, Rect2())
		_fit_rect(_dim_right, Rect2())
		_fit_rect(_dim_bottom, Rect2())
		_fit_rect(_hole_catcher, Rect2())
		_ring.visible = false
	else:
		_fit_rect(_dim_left, Rect2(0, hole.position.y, hole.position.x, hole.size.y))
		_fit_rect(
			_dim_right,
			Rect2(hole.end.x, hole.position.y, vp.x - hole.end.x, hole.size.y)
		)
		_fit_rect(_dim_bottom, Rect2(0, hole.end.y, vp.x, vp.y - hole.end.y))
		_fit_rect(_hole_catcher, hole)
		_ring.visible = true
		_fit_rect(_ring, hole)

	_place_card(hole, vp)


func _place_card(hole: Rect2, vp: Vector2) -> void:
	var insets := UiTheme.viewport_safe_insets(get_viewport())
	var max_w := minf(CARD_MAX_WIDTH, vp.x - CARD_MARGIN * 2.0)
	var side := maxf((vp.x - max_w) * 0.5, CARD_MARGIN)
	var bottom_pad := maxf(side, insets.w)
	var top_pad := maxf(side, insets.y)
	var inner_w := maxf(max_w - CARD_PAD_X * 2.0, 1.0)
	_title.custom_minimum_size.x = inner_w
	_body.custom_minimum_size.x = inner_w
	_card.custom_minimum_size.x = max_w
	_card.reset_size()
	var h := _card.get_combined_minimum_size().y
	h = maxf(h, _card.size.y)

	## Default: sit on the bottom inset (same gap as the sides). Grow-up anchors
	## keep that edge if the NEXT button later adds height.
	var top := vp.y - bottom_pad - h
	if hole.size.y > 0.0:
		var below := hole.end.y + CARD_GAP
		if below + h <= vp.y - bottom_pad:
			top = below
		else:
			var above := hole.position.y - CARD_GAP - h
			if above >= top_pad:
				top = above
	if top + h > vp.y - bottom_pad:
		top = vp.y - bottom_pad - h
	top = minf(top, vp.y - bottom_pad - h)

	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -max_w * 0.5
	_card.offset_right = max_w * 0.5
	_card.offset_bottom = -(vp.y - (top + h))
	_card.offset_top = _card.offset_bottom - h
	_card.size = Vector2(max_w, h)


func _spotlight_rect() -> Rect2:
	var steps: Array = _script.get("steps", [])
	if _step_index < 0 or _step_index >= steps.size() or _host == null:
		return Rect2()
	if not _host.has_method("get_tutorial_spotlight_rect"):
		return Rect2()
	var id := str(steps[_step_index].get("spotlight", ""))
	var rect: Variant = _host.call("get_tutorial_spotlight_rect", id)
	if typeof(rect) == TYPE_RECT2:
		return rect
	return Rect2()


func _fit_rect(node: Control, rect: Rect2) -> void:
	node.visible = rect.size.x > 0.5 and rect.size.y > 0.5
	if not node.visible:
		return
	node.position = rect.position
	node.size = rect.size
