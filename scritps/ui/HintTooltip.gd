extends CanvasLayer
class_name HintTooltip

## Reusable hover / long-press hint. Matches Material-style icon-button help:
## desktop hover shows the bubble; touch long-press shows it without firing the click.

const FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const FONT_SIZE := 28
const PAD_X := 22.0
const PAD_Y := 14.0
const RADIUS := 16.0
const CARET := 12.0
const GAP := 10.0
const MARGIN := 16.0
const HOVER_DELAY := 0.35
const HOLD_DELAY := 0.5
const DRAG_CANCEL_PX := 14.0
const BG := Color(0.05, 0.05, 0.07, 0.96)

static var _instance: HintTooltip

var _host: Control
var _text := ""
var _bubble_rect := Rect2()
var _caret_tip := Vector2.ZERO
var _caret_base_y := 0.0
var _caret_down := true
var _from_hold := false
var _press_from := Vector2.ZERO
var _holding := false

var _paint: Control
var _label: Label
var _catcher: Control
var _hover_timer: Timer
var _hold_timer: Timer
var _hosts: Dictionary = {} ## instance_id -> { "enter": Callable, ... }


static func bind(host: Control, text: String) -> void:
	if host == null:
		return
	_ensure()._bind_host(host, text)


static func unbind(host: Control) -> void:
	if host == null or _instance == null or not is_instance_valid(_instance):
		return
	_instance._unbind_host(host)


static func _ensure() -> HintTooltip:
	if _instance != null and is_instance_valid(_instance):
		return _instance
	_instance = HintTooltip.new()
	_instance.layer = 128
	_instance.name = "HintTooltip"
	Engine.get_main_loop().root.add_child(_instance)
	return _instance


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_catcher = Control.new()
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	var paint := _Paint.new()
	paint.tip = self
	paint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	paint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paint = paint
	add_child(_paint)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)
	_hover_timer = _make_timer(HOVER_DELAY, _on_hover_timeout)
	_hold_timer = _make_timer(HOLD_DELAY, _on_hold_timeout)
	hide_hint()


func _make_timer(wait: float, cb: Callable) -> Timer:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = wait
	t.timeout.connect(cb)
	add_child(t)
	return t


func _bind_host(host: Control, text: String) -> void:
	_unbind_host(host)
	host.tooltip_text = ""
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	var enter := _on_mouse_entered.bind(host)
	var exit := _on_mouse_exited.bind(host)
	var input := _on_host_gui_input.bind(host)
	var gone := _on_host_exiting.bind(host)
	host.set_meta("hint_tooltip_text", trimmed)
	host.mouse_entered.connect(enter)
	host.mouse_exited.connect(exit)
	host.gui_input.connect(input)
	host.tree_exiting.connect(gone)
	_hosts[host.get_instance_id()] = {
		"host": host,
		"enter": enter,
		"exit": exit,
		"input": input,
		"gone": gone,
	}


func _unbind_host(host: Control) -> void:
	var id := host.get_instance_id()
	if not _hosts.has(id):
		if host.has_meta("hint_tooltip_text"):
			host.remove_meta("hint_tooltip_text")
		return
	var rec: Dictionary = _hosts[id]
	if host.mouse_entered.is_connected(rec.enter):
		host.mouse_entered.disconnect(rec.enter)
	if host.mouse_exited.is_connected(rec.exit):
		host.mouse_exited.disconnect(rec.exit)
	if host.gui_input.is_connected(rec.input):
		host.gui_input.disconnect(rec.input)
	if host.tree_exiting.is_connected(rec.gone):
		host.tree_exiting.disconnect(rec.gone)
	if host.has_meta("hint_tooltip_text"):
		host.remove_meta("hint_tooltip_text")
	_hosts.erase(id)
	if _host == host:
		hide_hint()


func _on_host_exiting(host: Control) -> void:
	_unbind_host(host)


func _on_mouse_entered(host: Control) -> void:
	if _from_hold:
		return
	_host = host
	_text = str(host.get_meta("hint_tooltip_text", ""))
	_hover_timer.start()
	_hold_timer.stop()


func _on_mouse_exited(host: Control) -> void:
	if _from_hold:
		return
	_hover_timer.stop()
	if _host == host and not _holding:
		hide_hint()


func _on_host_gui_input(event: InputEvent, host: Control) -> void:
	var pressed := false
	var released := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		if _holding and _press_from.distance_to(event.position) > DRAG_CANCEL_PX:
			_cancel_hold()
		return
	else:
		return
	if pressed:
		_host = host
		_text = str(host.get_meta("hint_tooltip_text", ""))
		_holding = true
		_from_hold = false
		_press_from = pos
		_hold_timer.start()
	elif released:
		_end_hold(host, event)


func _end_hold(host: Control, event: InputEvent) -> void:
	_hold_timer.stop()
	_holding = false
	if _from_hold:
		## Swallow the release so a long-press hint does not also activate the button.
		host.accept_event()
		get_viewport().set_input_as_handled()
		hide_hint()


func _cancel_hold() -> void:
	_hold_timer.stop()
	_holding = false
	if _from_hold:
		hide_hint()


func _on_hover_timeout() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	_from_hold = false
	_show_for_host(_host)


func _on_hold_timeout() -> void:
	if _host == null or not is_instance_valid(_host) or not _holding:
		return
	_from_hold = true
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_show_for_host(_host)
	if Haptics:
		Haptics.light()


func _on_catcher_input(event: InputEvent) -> void:
	if not _from_hold:
		return
	var up := false
	if event is InputEventScreenTouch:
		up = not (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		up = mouse.button_index == MOUSE_BUTTON_LEFT and not mouse.pressed
	if up:
		get_viewport().set_input_as_handled()
		hide_hint()


func _show_for_host(host: Control) -> void:
	_host = host
	_text = str(host.get_meta("hint_tooltip_text", ""))
	if _text.is_empty():
		hide_hint()
		return
	_label.text = _text
	_label.reset_size()
	_layout_bubble()
	_label.visible = true
	_paint.queue_redraw()
	visible = true


func hide_hint() -> void:
	_hover_timer.stop()
	_hold_timer.stop()
	_from_hold = false
	_holding = false
	_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.visible = false
	_paint.queue_redraw()
	_host = null


func _process(_delta: float) -> void:
	if _label.visible and _host != null and is_instance_valid(_host):
		if not _host.is_visible_in_tree():
			hide_hint()
			return
		_layout_bubble()
		_paint.queue_redraw()


func _layout_bubble() -> void:
	if _host == null or not is_instance_valid(_host):
		return
	var vp := get_viewport().get_visible_rect().size
	var text_size := FONT.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var bubble_size := Vector2(text_size.x + PAD_X * 2.0, text_size.y + PAD_Y * 2.0)
	var host_rect := _host.get_global_rect()
	var anchor := Vector2(host_rect.position.x + host_rect.size.x * 0.5, host_rect.position.y)
	var x := clampf(anchor.x - bubble_size.x * 0.5, MARGIN, maxf(MARGIN, vp.x - bubble_size.x - MARGIN))
	var y := anchor.y - GAP - CARET - bubble_size.y
	_caret_down = true
	if y < MARGIN:
		_caret_down = false
		y = host_rect.position.y + host_rect.size.y + GAP + CARET
		if y + bubble_size.y > vp.y - MARGIN:
			y = clampf(y, MARGIN, maxf(MARGIN, vp.y - bubble_size.y - MARGIN))
	_bubble_rect = Rect2(Vector2(x, y), bubble_size)
	var caret_x := clampf(anchor.x, _bubble_rect.position.x + RADIUS + CARET, _bubble_rect.end.x - RADIUS - CARET)
	if _caret_down:
		_caret_base_y = _bubble_rect.end.y
		_caret_tip = Vector2(caret_x, _bubble_rect.end.y + CARET)
	else:
		_caret_base_y = _bubble_rect.position.y
		_caret_tip = Vector2(caret_x, _bubble_rect.position.y - CARET)
	_label.position = _bubble_rect.position
	_label.size = _bubble_rect.size


func _on_paint_draw() -> void:
	if not _label.visible:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(int(RADIUS))
	_paint.draw_style_box(sb, _bubble_rect)
	var half := CARET
	var pts: PackedVector2Array
	if _caret_down:
		pts = PackedVector2Array([
			Vector2(_caret_tip.x - half, _caret_base_y),
			Vector2(_caret_tip.x + half, _caret_base_y),
			_caret_tip,
		])
	else:
		pts = PackedVector2Array([
			Vector2(_caret_tip.x - half, _caret_base_y),
			Vector2(_caret_tip.x + half, _caret_base_y),
			_caret_tip,
		])
	_paint.draw_colored_polygon(pts, BG)


class _Paint extends Control:
	var tip: HintTooltip

	func _draw() -> void:
		if tip != null:
			tip._on_paint_draw()
