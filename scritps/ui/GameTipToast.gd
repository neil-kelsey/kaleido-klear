extends Control
class_name GameTipToast

## Short in-game tip. Looks like HintTooltip: dark rounded bubble, white
## Quicksand, optional caret toward an anchor. Auto-dismisses; tap the bubble
## to close early. The rest of the screen stays playable.

const FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const FONT_SIZE := 34
const PAD_X := 28.0
const PAD_Y := 20.0
const RADIUS := 16.0
const CARET := 12.0
const GAP := 12.0
const MARGIN := 24.0
const MAX_WIDTH_RATIO := 0.86
const BG := Color(0.05, 0.05, 0.07, 0.96)
const FADE_IN := 0.22
const HOLD_SEC := 5.5
const FADE_OUT := 0.4

var _text := ""
var _anchor: Control
var _bubble_rect := Rect2()
var _caret_tip := Vector2.ZERO
var _caret_base_y := 0.0
var _caret_down := false
var _tween: Tween
var _paint: Control
var _label: Label
var _hit: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 30
	visible = false
	modulate.a = 0.0
	_paint = _Paint.new()
	_paint.tip = self
	_paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_paint)
	_hit = Control.new()
	_hit.mouse_filter = Control.MOUSE_FILTER_STOP
	_hit.gui_input.connect(_on_hit_gui_input)
	add_child(_hit)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)


func present(text: String, anchor: Control = null) -> void:
	_text = text.strip_edges()
	_anchor = anchor
	if _text.is_empty():
		hide_tip()
		return
	_label.text = _text
	_layout_bubble()
	_label.visible = true
	_paint.queue_redraw()
	visible = true
	modulate.a = 0.0
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(HOLD_SEC)
	_tween.set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(hide_tip)


func hide_tip() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	_label.visible = false
	visible = false
	modulate.a = 0.0
	_anchor = null
	if _paint != null:
		_paint.queue_redraw()


func _on_hit_gui_input(event: InputEvent) -> void:
	var tap := false
	if event is InputEventScreenTouch:
		tap = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		tap = mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed
	if tap:
		accept_event()
		hide_tip()


func _process(_delta: float) -> void:
	if not visible or not _label.visible:
		return
	if _anchor != null and is_instance_valid(_anchor) and not _anchor.is_visible_in_tree():
		hide_tip()
		return
	_layout_bubble()
	_paint.queue_redraw()


func _layout_bubble() -> void:
	var vp := get_viewport_rect().size
	if vp.x < 2.0 or vp.y < 2.0:
		return
	var max_text_w := maxf(vp.x * MAX_WIDTH_RATIO - PAD_X * 2.0, 200.0)
	var text_size := FONT.get_multiline_string_size(
		_text, HORIZONTAL_ALIGNMENT_CENTER, max_text_w, FONT_SIZE
	)
	var bubble_size := Vector2(text_size.x + PAD_X * 2.0, text_size.y + PAD_Y * 2.0)
	var anchor_rect := Rect2(Vector2(vp.x * 0.5, 160.0), Vector2.ZERO)
	if _anchor != null and is_instance_valid(_anchor):
		anchor_rect = _anchor.get_global_rect()
	var mid_x := anchor_rect.position.x + anchor_rect.size.x * 0.5
	var x := clampf(mid_x - bubble_size.x * 0.5, MARGIN, maxf(MARGIN, vp.x - bubble_size.x - MARGIN))
	## Prefer just below the lives row, caret pointing up at the hearts.
	var y := anchor_rect.end.y + GAP + CARET
	_caret_down = false
	if y + bubble_size.y > vp.y - MARGIN:
		_caret_down = true
		y = anchor_rect.position.y - GAP - CARET - bubble_size.y
		if y < MARGIN:
			y = clampf(y, MARGIN, maxf(MARGIN, vp.y - bubble_size.y - MARGIN))
	_bubble_rect = Rect2(Vector2(x, y), bubble_size)
	var caret_x := clampf(
		mid_x,
		_bubble_rect.position.x + RADIUS + CARET,
		_bubble_rect.end.x - RADIUS - CARET
	)
	if _caret_down:
		_caret_base_y = _bubble_rect.end.y
		_caret_tip = Vector2(caret_x, _bubble_rect.end.y + CARET)
	else:
		_caret_base_y = _bubble_rect.position.y
		_caret_tip = Vector2(caret_x, _bubble_rect.position.y - CARET)
	_label.position = _bubble_rect.position
	_label.size = _bubble_rect.size
	_hit.position = _bubble_rect.position
	_hit.size = _bubble_rect.size


func _on_paint_draw() -> void:
	if not _label.visible:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(int(RADIUS))
	_paint.draw_style_box(sb, _bubble_rect)
	var half := CARET
	var pts := PackedVector2Array([
		Vector2(_caret_tip.x - half, _caret_base_y),
		Vector2(_caret_tip.x + half, _caret_base_y),
		_caret_tip,
	])
	_paint.draw_colored_polygon(pts, BG)


class _Paint extends Control:
	var tip: GameTipToast

	func _draw() -> void:
		if tip != null:
			tip._on_paint_draw()
