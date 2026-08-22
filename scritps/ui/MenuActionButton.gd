extends Button
class_name MenuActionButton

## Shared CTA. PRIMARY / DESTRUCTIVE use one baked nebula texture; SECONDARY is cream + rainbow.

enum Kind { PRIMARY, SECONDARY, DESTRUCTIVE }
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
## Extra air above compact CTAs when they follow copy (not another CTA).
const COMPACT_TOP_GAP := 28

@export var kind: Kind = Kind.PRIMARY
@export var label_text: String = "START GAME":
	set(value):
		label_text = value
		if is_node_ready():
			_apply_label()
@export var icon_style: IconStyle = IconStyle.CHEVRON
@export var show_trailing_icon: bool = true
## Modal CTAs: landing look at a size that fits a card.
@export var compact: bool = false

var _face: Panel
var _label: Label
var _icon: Control
var _nebula: TextureRect
var _nebula_mat: ShaderMaterial
var _rainbow_border: ColorRect
var _press_tween: Tween
var _fx_time: float = 0.0
var _hovering := false
var _top_gap: Control


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
	_ensure_top_gap()
	_layout()
	set_process(true)


func _exit_tree() -> void:
	if _top_gap != null and is_instance_valid(_top_gap):
		_top_gap.queue_free()
		_top_gap = null


func _ensure_top_gap() -> void:
	## Keep modal body copy from sitting on the first CTA; skip between stacked CTAs.
	if not compact:
		return
	var parent := get_parent()
	if parent == null or parent is HBoxContainer:
		return
	var idx := get_index()
	if idx > 0:
		var prev := parent.get_child(idx - 1)
		if prev is MenuActionButton or prev == _top_gap:
			return
		if prev.get_meta("ui_section_subtitle", false):
			return
	if _top_gap != null and is_instance_valid(_top_gap):
		return
	_top_gap = Control.new()
	_top_gap.name = "MenuActionTopGap"
	_top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_gap.custom_minimum_size = Vector2(0, COMPACT_TOP_GAP)
	## Never absorb leftover VBox space — that stretches chart modals tall.
	_top_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_gap.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_top_gap)
	parent.move_child(_top_gap, get_index())


func _uses_nebula() -> bool:
	return kind == Kind.PRIMARY or kind == Kind.DESTRUCTIVE


func _min_height() -> int:
	if compact:
		return 128 if _uses_nebula() else 112
	return PRIMARY_MIN_HEIGHT if _uses_nebula() else CTA_MIN_HEIGHT


func _font_size() -> int:
	if compact:
		return 40 if _uses_nebula() else 36
	return PRIMARY_FONT_SIZE if _uses_nebula() else CTA_FONT_SIZE


func _icon_size() -> int:
	if compact:
		return 36
	return PRIMARY_ICON_SIZE if _uses_nebula() else CTA_ICON_SIZE


func _pad_h() -> int:
	if compact:
		return 28
	return PRIMARY_PAD_H if _uses_nebula() else CTA_PAD_H


func _pad_v() -> int:
	if compact:
		return 22
	return PRIMARY_PAD_V if _uses_nebula() else CTA_PAD_V


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


func apply_kind(new_kind: Kind) -> void:
	if kind == new_kind and is_node_ready() and _face != null:
		return
	kind = new_kind
	if not is_node_ready():
		return
	custom_minimum_size.y = maxf(custom_minimum_size.y, float(_min_height()))
	_build()
	_apply_label()
	_refresh_face_color()
	_layout()


func _clear_button_chrome() -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, empty)


func _theme_role() -> UiTheme.ButtonRole:
	match kind:
		Kind.DESTRUCTIVE:
			return UiTheme.ButtonRole.DANGER
		Kind.PRIMARY:
			return UiTheme.ButtonRole.PRIMARY
		_:
			return UiTheme.ButtonRole.SECONDARY


func _face_style(bg: Color, with_shadow: bool) -> StyleBoxFlat:
	var role := _theme_role()
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
	row.add_theme_constant_override("separation", 32 if _uses_nebula() else 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var text_color := Color.WHITE if _uses_nebula() else UiTheme.PRIMARY

	_label = Label.new()
	_label.add_theme_font_override("font", UiTheme.button_typeface())
	_label.add_theme_font_size_override("font_size", _font_size())
	_label.add_theme_color_override("font_color", text_color)
	if _uses_nebula():
		_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
		_label.add_theme_constant_override("shadow_offset_x", 1)
		_label.add_theme_constant_override("shadow_offset_y", 1)
		_label.add_theme_constant_override("shadow_outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_label)

	if show_trailing_icon:
		var icon_px := float(_icon_size())
		var fa := FaIconView.new()
		fa.icon_name = "gear" if icon_style == IconStyle.GEAR else "angles-right"
		fa.icon_color = text_color
		_icon = fa
		_icon.custom_minimum_size = Vector2(icon_px, icon_px)
		_icon.size = Vector2(icon_px, icon_px)
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(_icon)

	if _uses_nebula():
		## No StyleBoxFlat on nebula fills (known mid-seam bug). One baked texture only.
		_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_nebula = TextureRect.new()
		_nebula.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_nebula_mat = NebulaEffect.apply_to_control(_nebula, float(UiTheme.BUTTON_CORNER_RADIUS))
		if kind == Kind.DESTRUCTIVE:
			_nebula_mat.set_shader_parameter(
				"tint_rgb",
				Vector3(UiTheme.DANGER_TINT.r, UiTheme.DANGER_TINT.g, UiTheme.DANGER_TINT.b)
			)
			_nebula_mat.set_shader_parameter("tint_amount", 0.88)
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
	if is_node_ready():
		_fit_wrapped_height()


func _layout() -> void:
	pivot_offset = size * 0.5
	if _face:
		_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sync_fx_rect()
	_fit_wrapped_height()


func _fit_wrapped_height() -> void:
	## Grow the button when wrapped copy needs a second line, never clip text.
	if _label == null or size.x < 200.0:
		## Wait until the button has a real laid-out width — wrapping at ~48px
		## inflates height and can lock chart modals to a huge stale size.
		return
	var text_w := size.x - float(_pad_h() * 2)
	if show_trailing_icon and _icon != null:
		var gap := 32.0 if _uses_nebula() else 24.0
		text_w -= float(_icon_size()) + gap
	text_w = maxf(text_w, 120.0)
	_label.custom_minimum_size.x = text_w
	var text_h := _label.get_minimum_size().y
	var needed := float(_pad_v() * 2) + text_h
	## CTAs should wrap to at most a couple of lines, not a tall column.
	var max_needed := float(_min_height()) + float(_font_size()) * 2.2
	needed = minf(needed, max_needed)
	var next_h := maxf(float(_min_height()), needed)
	if absf(custom_minimum_size.y - next_h) < 0.5:
		return
	custom_minimum_size.y = next_h
	_shrink_ancestor_chart_panel()


func _shrink_ancestor_chart_panel() -> void:
	## Only shrink-wrap centered modal cards — never collapse fill layouts (Settings).
	var node: Node = get_parent()
	while node != null:
		if node is ChartModalPanel:
			var panel := node as ChartModalPanel
			if panel.shrink_wrap:
				panel.shrink_to_content()
			return
		node = node.get_parent()


func _sync_fx_rect() -> void:
	var rect := size
	if rect.x < 2.0 or rect.y < 2.0:
		return
	if _nebula_mat != null:
		_nebula_mat.set_shader_parameter("rect_size", rect)
	if _rainbow_border != null:
		UiTheme.sync_rainbow_border(_rainbow_border, rect)


func _base_color() -> Color:
	if kind == Kind.DESTRUCTIVE:
		if button_pressed:
			return UiTheme.DANGER_FILL_PRESSED
		if _hovering:
			return UiTheme.DANGER_FILL_HOVER
		return UiTheme.DANGER_FILL
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
	if _uses_nebula():
		_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		var shadow := not button_pressed
		_face.add_theme_stylebox_override("panel", _face_style(_base_color(), shadow))
	if _icon is FaIconView:
		(_icon as FaIconView).icon_color = Color.WHITE if _uses_nebula() else UiTheme.PRIMARY


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
