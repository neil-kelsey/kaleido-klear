extends CheckButton
class_name SettingsToggle

## iOS-style switch used on the Settings page. Emits the usual `toggled` signal.

const TRACK_ON := Color(0.0, 0.28, 0.66, 1.0) ## UiTheme.PRIMARY #0047A8
const TRACK_OFF := Color(0.28, 0.30, 0.38, 0.88)
const KNOB := Color(0.98, 0.98, 1.0, 1.0)
const KNOB_SHADOW := Color(0.0, 0.0, 0.0, 0.28)
const TWEEN_SEC := 0.16
## Was 104x58 with a 44px track and 36px knob — too short and flat.
const SWITCH_SIZE := Vector2(128, 72)
const TRACK_HEIGHT_RATIO := 0.84
const TRACK_HEIGHT_MAX := 58.0
const KNOB_INSET := 5.0

var _knob := 0.0
var _tween: Tween


func _ready() -> void:
	toggle_mode = true
	text = ""
	clip_contents = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = SWITCH_SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hide_default_chrome()
	_knob = 1.0 if button_pressed else 0.0
	if not toggled.is_connected(_on_self_toggled):
		toggled.connect(_on_self_toggled)
	set_process(true)
	queue_redraw()


func _hide_default_chrome() -> void:
	var empty := StyleBoxEmpty.new()
	for name in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(name, empty)
	var blank := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	for name in [
		"checked", "unchecked", "checked_disabled", "unchecked_disabled",
		"checked_mirrored", "unchecked_mirrored"
	]:
		add_theme_icon_override(name, blank)
	add_theme_constant_override("h_separation", 0)
	add_theme_constant_override("icon_max_width", 0)


func sync_pressed(on: bool) -> void:
	set_pressed_no_signal(on)
	if _tween != null and _tween.is_running():
		_tween.kill()
	_knob = 1.0 if on else 0.0
	queue_redraw()


func _on_self_toggled(on: bool) -> void:
	var target := 1.0 if on else 0.0
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_knob, _knob, target, TWEEN_SEC)


func _set_knob(value: float) -> void:
	_knob = value
	queue_redraw()


func _process(_delta: float) -> void:
	if _tween != null and _tween.is_running():
		return
	var target := 1.0 if button_pressed else 0.0
	if absf(_knob - target) > 0.001:
		_knob = target
		queue_redraw()


func _draw() -> void:
	var track_h := minf(size.y * TRACK_HEIGHT_RATIO, TRACK_HEIGHT_MAX)
	var track_w := size.x
	var y := (size.y - track_h) * 0.5
	var radius := track_h * 0.5
	var off := TRACK_OFF
	var on := TRACK_ON
	var fill := off.lerp(on, _knob)
	var track := Rect2(0.0, y, track_w, track_h)
	_draw_round_rect(track, radius, fill)
	## Soft inner highlight along the top of the track.
	var sheen := Color(1, 1, 1, 0.10 + 0.06 * _knob)
	_draw_round_rect(Rect2(2.0, y + 1.5, track_w - 4.0, track_h * 0.38), radius * 0.7, sheen)
	var inset := KNOB_INSET
	var knob_d := track_h - inset * 2.0
	var knob_r := knob_d * 0.5
	var min_x := inset + knob_r
	var max_x := track_w - inset - knob_r
	var cx := lerpf(min_x, max_x, _knob)
	var cy := y + radius
	draw_circle(Vector2(cx, cy + 1.4), knob_r, KNOB_SHADOW)
	draw_circle(Vector2(cx, cy), knob_r, KNOB)


func _draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(round(radius)))
	style.anti_aliasing = true
	style.draw(get_canvas_item(), rect)
