extends Button
class_name MenuActionButton

## Primary (blue + shine) or secondary (white + soft shadow) menu CTA.
## Styled to match the design reference: moderate radius, medium type, >> / gear.

enum Kind { PRIMARY, SECONDARY }
enum IconStyle { CHEVRON, GEAR }

const FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const SHINE_SHADER := preload("res://assets/shaders/button_shine.gdshader")
const CHEVRON_ICON := preload("res://assets/icons/chevron_double.svg")

## Royal blue from design (~#0047A8), slightly darker than the reference mid-tone.
const PRIMARY_BLUE := Color(0.0, 0.28, 0.66, 1.0)
const PRIMARY_BLUE_HOVER := Color(0.04, 0.34, 0.74, 1.0)
const PRIMARY_BLUE_PRESSED := Color(0.0, 0.22, 0.56, 1.0)
const SECONDARY_BG := Color(1, 1, 1, 1)
const SECONDARY_BORDER_WIDTH := 3
const CORNER_RADIUS := 18
const PRESS_SCALE := 0.97
const SHINE_CYCLE_SEC := 2.8
const CTA_FONT_SIZE := 40
const CTA_ICON_SIZE := 54
const CTA_MIN_HEIGHT := 140
const CTA_PAD_H := 36
const CTA_PAD_V := 34

@export var kind: Kind = Kind.PRIMARY
@export var label_text: String = "START GAME"
@export var icon_style: IconStyle = IconStyle.CHEVRON

var _face: Panel
var _label: Label
var _icon: Control
var _shine: ColorRect
var _shine_mat: ShaderMaterial
var _press_tween: Tween
var _shine_phase: float = 0.0
var _hovering := false


func _ready() -> void:
	flat = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	clip_contents = false
	_clear_button_chrome()
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(CTA_MIN_HEIGHT))
	_build()
	_apply_label()
	_refresh_face_color()
	resized.connect(_layout)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_set_pressed_visual.bind(true))
	button_up.connect(_set_pressed_visual.bind(false))
	await get_tree().process_frame
	_layout()
	if kind == Kind.PRIMARY:
		set_process(true)


func _process(delta: float) -> void:
	if _shine_mat == null:
		return
	_shine_phase = fposmod(_shine_phase + delta / SHINE_CYCLE_SEC, 1.0)
	_shine_mat.set_shader_parameter("phase", _shine_phase)


func set_label(text_value: String) -> void:
	label_text = text_value
	_apply_label()


func _clear_button_chrome() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)


func _cta_font() -> Font:
	## Quicksand Medium — rounded geometric, softer than Montserrat.
	var font := FontVariation.new()
	font.base_font = FONT
	font.spacing_glyph = 2
	font.spacing_space = 8
	return font


func _face_style(bg: Color, with_shadow: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(CORNER_RADIUS)
	if kind == Kind.SECONDARY:
		style.border_color = PRIMARY_BLUE
		style.set_border_width_all(SECONDARY_BORDER_WIDTH)
	else:
		style.set_border_width_all(0)
	if with_shadow:
		style.shadow_color = Color(0, 0, 0, 0.12)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 3)
	return style


func _build() -> void:
	for child in get_children():
		child.queue_free()

	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_face)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", CTA_PAD_H)
	margin.add_theme_constant_override("margin_right", CTA_PAD_H)
	margin.add_theme_constant_override("margin_top", CTA_PAD_V)
	margin.add_theme_constant_override("margin_bottom", CTA_PAD_V)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var text_color := Color.WHITE if kind == Kind.PRIMARY else PRIMARY_BLUE
	var face_color := PRIMARY_BLUE if kind == Kind.PRIMARY else SECONDARY_BG

	_label = Label.new()
	_label.add_theme_font_override("font", _cta_font())
	_label.add_theme_font_size_override("font_size", CTA_FONT_SIZE)
	_label.add_theme_color_override("font_color", text_color)
	if kind == Kind.PRIMARY:
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.28))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.add_theme_constant_override("shadow_outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)

	var icon_px := float(CTA_ICON_SIZE)
	match icon_style:
		IconStyle.GEAR:
			var gear := _GearIcon.new()
			gear.set_icon_color(text_color)
			gear.set_hole_color(face_color)
			_icon = gear
		_:
			var chevron := TextureRect.new()
			chevron.texture = CHEVRON_ICON
			chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			chevron.modulate = text_color
			_icon = chevron
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	_icon.size = Vector2(icon_px, icon_px)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	if kind == Kind.PRIMARY:
		_shine = ColorRect.new()
		_shine.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shine_mat = ShaderMaterial.new()
		_shine_mat.shader = SHINE_SHADER
		_shine_mat.set_shader_parameter("band_width", 0.28)
		_shine_mat.set_shader_parameter("strength", 0.22)
		_shine.material = _shine_mat
		_shine.color = Color(1, 1, 1, 1)
		_face.add_child(_shine)
		margin.move_to_front()


func _apply_label() -> void:
	if _label:
		_label.text = label_text.to_upper()


func _layout() -> void:
	pivot_offset = size * 0.5
	if _face:
		_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _base_color() -> Color:
	if kind == Kind.PRIMARY:
		if button_pressed:
			return PRIMARY_BLUE_PRESSED
		if _hovering:
			return PRIMARY_BLUE_HOVER
		return PRIMARY_BLUE
	return SECONDARY_BG


func _refresh_face_color() -> void:
	if _face == null:
		return
	var shadow := not button_pressed
	var bg := _base_color()
	_face.add_theme_stylebox_override("panel", _face_style(bg, shadow))
	if _icon is _GearIcon:
		(_icon as _GearIcon).set_hole_color(bg)


func _on_hover(hovering: bool) -> void:
	_hovering = hovering
	if not button_pressed:
		_refresh_face_color()


func _set_pressed_visual(down: bool) -> void:
	_refresh_face_color()
	if _press_tween:
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var target := Vector2(PRESS_SCALE, PRESS_SCALE) if down else Vector2.ONE
	_press_tween.tween_property(self, "scale", target, 0.08 if down else 0.12)


class _GearIcon extends Control:
	var icon_color: Color = Color.WHITE
	var hole_color: Color = Color.WHITE

	func set_icon_color(color: Color) -> void:
		icon_color = color
		queue_redraw()

	func set_hole_color(color: Color) -> void:
		hole_color = color
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var outer := minf(size.x, size.y) * 0.46
		var valley := outer * 0.68
		var hole := outer * 0.30
		var teeth := 8
		var pts := PackedVector2Array()
		for i in teeth:
			var base := (-PI * 0.5) + (TAU * float(i) / float(teeth))
			var half_tooth := PI / float(teeth) * 0.35
			var half_gap := PI / float(teeth) * 0.65
			pts.append(c + Vector2(cos(base - half_gap), sin(base - half_gap)) * valley)
			pts.append(c + Vector2(cos(base - half_tooth), sin(base - half_tooth)) * outer)
			pts.append(c + Vector2(cos(base + half_tooth), sin(base + half_tooth)) * outer)
			pts.append(c + Vector2(cos(base + half_gap), sin(base + half_gap)) * valley)
		draw_colored_polygon(pts, icon_color)
		draw_circle(c, hole, hole_color)
