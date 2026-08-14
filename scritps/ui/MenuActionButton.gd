extends Button
class_name MenuActionButton

## Home hero CTA. Primary fill is ONE baked nebula texture (no tiled procedural UV).

enum Kind { PRIMARY, SECONDARY }
enum IconStyle { CHEVRON, GEAR }

const BRAND_RAINBOW := preload("res://scritps/ui/BrandRainbow.gd")

const PRESS_SCALE := 0.97
const CTA_FONT_SIZE := 40
const CTA_ICON_SIZE := 54
const CTA_MIN_HEIGHT := 140
const CTA_PAD_H := 36
const CTA_PAD_V := 34
const PRIMARY_FONT_SIZE := 56
const PRIMARY_ICON_SIZE := 72
const PRIMARY_MIN_HEIGHT := 260
const PRIMARY_PAD_H := 44
const PRIMARY_PAD_V := 52

@export var kind: Kind = Kind.PRIMARY
@export var label_text: String = "START GAME"
@export var icon_style: IconStyle = IconStyle.CHEVRON

var _face: Panel
var _label: Label
var _icon: Control
var _nebula: TextureRect
var _nebula_mat: ShaderMaterial
var _rainbow_border: ColorRect
var _press_tween: Tween
var _fx_time: float = 0.0
var _hovering := false


func _ready() -> void:
	flat = false
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""
	clip_contents = false
	_clear_button_chrome()
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(_min_height()))
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
	set_process(true)


func _min_height() -> int:
	return PRIMARY_MIN_HEIGHT if kind == Kind.PRIMARY else CTA_MIN_HEIGHT


func _font_size() -> int:
	return PRIMARY_FONT_SIZE if kind == Kind.PRIMARY else CTA_FONT_SIZE


func _icon_size() -> int:
	return PRIMARY_ICON_SIZE if kind == Kind.PRIMARY else CTA_ICON_SIZE


func _pad_h() -> int:
	return PRIMARY_PAD_H if kind == Kind.PRIMARY else CTA_PAD_H


func _pad_v() -> int:
	return PRIMARY_PAD_V if kind == Kind.PRIMARY else CTA_PAD_V


func _process(delta: float) -> void:
	_fx_time += delta
	BRAND_RAINBOW.tick(delta)
	if _rainbow_border != null:
		UiTheme.sync_rainbow_border(_rainbow_border, size)
	if _nebula_mat == null:
		return
	_nebula_mat.set_shader_parameter("time_sec", _fx_time)
	## Whole-button breathe only — nothing spatial that can read as a seam.
	var pulse := 0.97 + 0.03 * sin(_fx_time * 0.55)
	var brightness := pulse
	if button_pressed:
		brightness *= 0.82
	elif _hovering:
		brightness *= 1.06
	_nebula_mat.set_shader_parameter("brightness", brightness)


func set_label(text_value: String) -> void:
	label_text = text_value
	_apply_label()


func _clear_button_chrome() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)


func _face_style(bg: Color, with_shadow: bool) -> StyleBoxFlat:
	var role := (
		UiTheme.ButtonRole.PRIMARY if kind == Kind.PRIMARY else UiTheme.ButtonRole.SECONDARY
	)
	var state := &"normal"
	if button_pressed:
		state = &"pressed"
	elif _hovering:
		state = &"hover"
	var style := UiTheme.brand_button_stylebox(role, state)
	style.bg_color = bg
	style.anti_aliasing = false
	if kind == Kind.SECONDARY:
		## Rainbow stroke is drawn by BrandRainbow overlay — no solid blue border.
		style.set_border_width_all(0)
	if with_shadow and kind == Kind.SECONDARY and not button_pressed:
		style.shadow_color = Color(0, 0, 0, 0.12)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0, 3)
	elif not with_shadow:
		style.shadow_size = 0
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
	margin.add_theme_constant_override("margin_left", _pad_h())
	margin.add_theme_constant_override("margin_right", _pad_h())
	margin.add_theme_constant_override("margin_top", _pad_v())
	margin.add_theme_constant_override("margin_bottom", _pad_v())
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24 if kind != Kind.PRIMARY else 32)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var text_color := Color.WHITE if kind == Kind.PRIMARY else UiTheme.PRIMARY
	var face_color := UiTheme.PRIMARY_FILL if kind == Kind.PRIMARY else UiTheme.SECONDARY_BG

	_label = Label.new()
	_label.add_theme_font_override("font", UiTheme.button_typeface())
	_label.add_theme_font_size_override("font_size", _font_size())
	_label.add_theme_color_override("font_color", text_color)
	if kind == Kind.PRIMARY:
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.add_theme_constant_override("shadow_outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)

	var icon_px := float(_icon_size())
	match icon_style:
		IconStyle.GEAR:
			var gear := _GearIcon.new()
			gear.set_icon_color(text_color)
			gear.set_hole_color(face_color)
			_icon = gear
		_:
			var chevron := _FaIconView.new()
			chevron.icon_name = "angles-right"
			chevron.icon_color = text_color
			_icon = chevron
	_icon.custom_minimum_size = Vector2(icon_px, icon_px)
	_icon.size = Vector2(icon_px, icon_px)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	if kind == Kind.PRIMARY:
		## No StyleBoxFlat on primary (known mid-seam bug). One baked texture only.
		_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_nebula = TextureRect.new()
		_nebula.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nebula_mat = NebulaEffect.apply_to_control(_nebula, float(UiTheme.BUTTON_CORNER_RADIUS))
		_face.add_child(_nebula)
		_face.move_child(_nebula, 0)
		margin.move_to_front()
	else:
		## Shared BrandRainbow stroke (same palette/phase as Klear title).
		_rainbow_border = UiTheme.attach_rainbow_border(
			_face,
			float(UiTheme.BUTTON_CORNER_RADIUS),
			float(UiTheme.BUTTON_BORDER_WIDTH)
		)
		margin.move_to_front()


func _apply_label() -> void:
	if _label:
		_label.text = label_text.to_upper()


func _layout() -> void:
	pivot_offset = size * 0.5
	if _face:
		_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_fx_rect()


func _sync_fx_rect() -> void:
	var rect := size
	if rect.x < 2.0 or rect.y < 2.0:
		return
	if _nebula_mat != null:
		_nebula_mat.set_shader_parameter("rect_size", rect)
	if _rainbow_border != null:
		UiTheme.sync_rainbow_border(_rainbow_border, rect)


func _base_color() -> Color:
	if kind == Kind.PRIMARY:
		if button_pressed:
			return UiTheme.PRIMARY_FILL_PRESSED
		if _hovering:
			return UiTheme.PRIMARY_FILL_HOVER
		return UiTheme.PRIMARY_FILL
	return UiTheme.SECONDARY_BG


func _refresh_face_color() -> void:
	if _face == null:
		return
	if kind == Kind.PRIMARY:
		_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		var shadow := not button_pressed
		_face.add_theme_stylebox_override("panel", _face_style(_base_color(), shadow))
	if _icon is _GearIcon:
		(_icon as _GearIcon).set_hole_color(
			UiTheme.PRIMARY_FILL if kind == Kind.PRIMARY else _base_color()
		)
	elif _icon is _FaIconView:
		(_icon as _FaIconView).icon_color = (
			Color.WHITE if kind == Kind.PRIMARY else UiTheme.PRIMARY
		)


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


class _FaIconView extends Control:
	var icon_name: String = "angles-right"
	var icon_color: Color = Color.WHITE:
		set(value):
			icon_color = value
			queue_redraw()

	func _draw() -> void:
		var h := minf(size.x, size.y)
		FaVector.draw_named(self, icon_name, size * 0.5, h, icon_color)
