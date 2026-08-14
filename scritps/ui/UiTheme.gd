extends RefCounted
class_name UiTheme

const _BRAND_RAINBOW := preload("res://scritps/ui/BrandRainbow.gd")

const BG := Color(1.0, 1.0, 1.0, 1.0)
const PANEL := Color(0.14, 0.14, 0.18, 1.0)
const TEXT := Color(0.12, 0.13, 0.16, 1.0)
const TEXT_ON_DARK := Color(0.95, 0.95, 0.97, 1.0)
const TEXT_MUTED := Color(0.42, 0.44, 0.48, 1.0)
const ACCENT := Color(0.25, 0.45, 0.95, 1.0)
const PLAY := Color(0.9, 0.28, 0.32, 1.0)
const PLAY_HOVER := Color(0.95, 0.38, 0.42, 1.0)
const PLAY_PRESSED := Color(0.75, 0.2, 0.24, 1.0)
const BUTTON := Color(0.18, 0.2, 0.26, 1.0)
const BUTTON_HOVER := Color(0.22, 0.24, 0.32, 1.0)
const BUTTON_PRESSED := Color(0.14, 0.16, 0.22, 1.0)
const HOLE_TINT := Color(0, 0, 0, 0.1)
const PLAYFIELD_TILE := Color(0.16, 0.16, 0.2, 1.0)
const PLAYFIELD_TILE_BORDER := Color(0.12, 0.12, 0.15, 1.0)

## Brand CTA palette — single source of truth for primary / secondary buttons.
## Keep in sync with MenuActionButton (home hero CTAs use these same tokens).
## PRIMARY stays the accent for secondary borders / text; PRIMARY_FILL is the
## deep-space fallback under the nebula shader (and flat primary buttons).
const PRIMARY := Color(0.0, 0.28, 0.66, 1.0) ## #0047A8
const PRIMARY_HOVER := Color(0.04, 0.34, 0.74, 1.0)
const PRIMARY_PRESSED := Color(0.0, 0.22, 0.56, 1.0)
const PRIMARY_FILL := Color(0.08, 0.05, 0.22, 1.0) ## deep nebula navy
const PRIMARY_FILL_HOVER := Color(0.12, 0.07, 0.30, 1.0)
const PRIMARY_FILL_PRESSED := Color(0.05, 0.03, 0.16, 1.0)
const SECONDARY_BG := Color(1.0, 1.0, 1.0, 1.0)
const SECONDARY_BG_HOVER := Color(0.96, 0.97, 1.0, 1.0)
const SECONDARY_BG_PRESSED := Color(0.9, 0.92, 0.96, 1.0)
const BUTTON_CORNER_RADIUS := 40
const BUTTON_BORDER_WIDTH := 3
## Shared circular HUD / nav button sizes — change here to update everywhere.
const CIRCLE_BUTTON_SIZE := 96
const CIRCLE_BUTTON_EMPHASIS_SIZE := 120
const CIRCLE_BUTTON_EDGE_INSET := 52
const CIRCLE_BUTTON_CLUSTER_GAP := 16
const BUTTON_FONT := preload("res://assets/fonts/Quicksand-Medium.ttf")
const BUTTON_LETTER_SPACING := 3
const BUTTON_WORD_SPACING := 10

enum ButtonRole { PRIMARY, SECONDARY, DANGER }
enum ButtonScale { STANDARD, HUD, COMPACT }

## Floor sizes so phone / small preview windows stay readable.
const MIN_MENU_FONT_SIZE := 56
const MIN_MENU_TITLE_FONT_SIZE := 64
const MIN_MENU_HINT_FONT_SIZE := 36
const MIN_MENU_BUTTON_HEIGHT := 108
const MENU_BUTTON_FONT_SIZE := 40
const MENU_BUTTON_ICON_SIZE := 44
const HUD_BUTTON_HEIGHT := 72
const HUD_BUTTON_FONT_SIZE := 28
const COMPACT_BUTTON_HEIGHT := 48
const COMPACT_BUTTON_FONT_SIZE := 18
const COMPACT_BUTTON_RADIUS := 22


static func menu_font_size(desired: int, minimum: int = MIN_MENU_FONT_SIZE) -> int:
	return maxi(desired, minimum)


static func apply_label_font(label: Label, desired: int, minimum: int = MIN_MENU_FONT_SIZE) -> void:
	label.add_theme_font_size_override("font_size", menu_font_size(desired, minimum))


static func button_typeface() -> Font:
	var font := FontVariation.new()
	font.base_font = BUTTON_FONT
	font.spacing_glyph = BUTTON_LETTER_SPACING
	font.spacing_space = BUTTON_WORD_SPACING
	return font


static func circle_stylebox(color: Color, radius: float = 999.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	return style


static func rounded_stylebox(color: Color, radius: int = 20) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


static func brand_button_stylebox(
	role: ButtonRole,
	state: StringName,
	scale: ButtonScale = ButtonScale.STANDARD
) -> StyleBoxFlat:
	var radius := COMPACT_BUTTON_RADIUS if scale == ButtonScale.COMPACT else BUTTON_CORNER_RADIUS
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(radius)
	match role:
		ButtonRole.PRIMARY:
			match state:
				&"hover", &"focus":
					style.bg_color = PRIMARY_FILL_HOVER
				&"pressed":
					style.bg_color = PRIMARY_FILL_PRESSED
				_:
					style.bg_color = PRIMARY_FILL
			style.set_border_width_all(0)
			style.shadow_color = Color(0.45, 0.2, 0.75, 0.28)
			style.shadow_size = 8 if scale == ButtonScale.STANDARD else 5
			style.shadow_offset = Vector2(0, 2)
		ButtonRole.DANGER:
			match state:
				&"hover", &"focus":
					style.bg_color = PLAY_HOVER
				&"pressed":
					style.bg_color = PLAY_PRESSED
				_:
					style.bg_color = PLAY
			style.set_border_width_all(0)
		_:
			match state:
				&"hover", &"focus":
					style.bg_color = SECONDARY_BG_HOVER
				&"pressed":
					style.bg_color = SECONDARY_BG_PRESSED
				_:
					style.bg_color = SECONDARY_BG
			style.border_color = PRIMARY
			style.set_border_width_all(BUTTON_BORDER_WIDTH)
	var pad_h := 16 if scale == ButtonScale.COMPACT else 28
	var pad_v := 10 if scale == ButtonScale.COMPACT else (16 if scale == ButtonScale.HUD else 22)
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	if role == ButtonRole.SECONDARY and state != &"pressed":
		style.shadow_color = Color(0, 0, 0, 0.12)
		style.shadow_size = 4 if scale != ButtonScale.STANDARD else 6
		style.shadow_offset = Vector2(0, 2 if scale != ButtonScale.STANDARD else 3)
	return style


## Single entry point for branded buttons. Prefer the role wrappers below.
static func style_button(
	button: Button,
	role: ButtonRole,
	scale: ButtonScale = ButtonScale.STANDARD,
	left_align: bool = false
) -> void:
	button.add_theme_stylebox_override("normal", brand_button_stylebox(role, &"normal", scale))
	button.add_theme_stylebox_override("hover", brand_button_stylebox(role, &"hover", scale))
	button.add_theme_stylebox_override("pressed", brand_button_stylebox(role, &"pressed", scale))
	button.add_theme_stylebox_override("focus", brand_button_stylebox(role, &"focus", scale))
	button.add_theme_stylebox_override("disabled", brand_button_stylebox(role, &"pressed", scale))

	var font_color := Color.WHITE
	if role == ButtonRole.SECONDARY:
		font_color = PRIMARY
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_color_override("font_disabled_color", Color(font_color, 0.45))

	button.add_theme_font_override("font", button_typeface())
	var font_size := MENU_BUTTON_FONT_SIZE
	var min_height := MIN_MENU_BUTTON_HEIGHT
	var icon_size := MENU_BUTTON_ICON_SIZE
	match scale:
		ButtonScale.HUD:
			font_size = HUD_BUTTON_FONT_SIZE
			min_height = HUD_BUTTON_HEIGHT
			icon_size = 28
		ButtonScale.COMPACT:
			font_size = COMPACT_BUTTON_FONT_SIZE
			min_height = COMPACT_BUTTON_HEIGHT
			icon_size = 22
		_:
			pass
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(min_height))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT if left_align else HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("h_separation", 16)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func style_primary_button(
	button: Button,
	scale: ButtonScale = ButtonScale.STANDARD
) -> void:
	style_button(button, ButtonRole.PRIMARY, scale)


static func style_secondary_button(
	button: Button,
	scale: ButtonScale = ButtonScale.STANDARD,
	left_align: bool = false
) -> void:
	style_button(button, ButtonRole.SECONDARY, scale, left_align)


static func style_danger_button(
	button: Button,
	scale: ButtonScale = ButtonScale.STANDARD
) -> void:
	style_button(button, ButtonRole.DANGER, scale)


## Nav / list rows that need an icon on the left (Back, level rows).
static func style_nav_button(
	button: Button,
	scale: ButtonScale = ButtonScale.STANDARD
) -> void:
	style_secondary_button(button, scale, true)


static func style_menu_button(button: Button) -> void:
	## Legacy alias — prefer style_nav_button / style_secondary_button.
	style_nav_button(button)


static func style_danger_menu_button(button: Button) -> void:
	## Legacy alias — prefer style_danger_button.
	style_danger_button(button)


static func style_hud_button(button: Button) -> void:
	## In-game chrome — compact secondary.
	style_secondary_button(button, ButtonScale.HUD, true)


static func style_menu_title(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT)
	apply_label_font(label, 72, MIN_MENU_TITLE_FONT_SIZE)


static func style_menu_hint(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT_MUTED)
	apply_label_font(label, 36, MIN_MENU_HINT_FONT_SIZE)


static func style_menu_section_title(label: Label) -> void:
	label.add_theme_color_override("font_color", TEXT)
	apply_label_font(label, 48, MIN_MENU_FONT_SIZE)


static func style_settings_row_label(label: Label) -> void:
	## Settings panel sits on a dark surface — use light text.
	label.add_theme_color_override("font_color", TEXT_ON_DARK)
	apply_label_font(label, 56, MIN_MENU_FONT_SIZE)


static func settings_option_field_stylebox(focused: bool = false) -> StyleBoxFlat:
	var style := text_field_stylebox(focused)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 24
	style.content_margin_top = 18
	style.content_margin_right = 48
	style.content_margin_bottom = 18
	return style


static func style_settings_option_field(option: OptionButton) -> void:
	## Match settings row type scale so the language picker isn't tiny on phone.
	var font_size := menu_font_size(48, 44)
	var min_height := maxi(MIN_MENU_BUTTON_HEIGHT - 12, 96)
	_apply_option_field_theme(
		option,
		settings_option_field_stylebox(false),
		settings_option_field_stylebox(true),
		min_height,
		font_size
	)
	option.custom_minimum_size = Vector2(maxi(int(option.custom_minimum_size.x), 360), min_height)
	option.add_theme_constant_override("arrow_margin", 20)
	option.fit_to_longest_item = true
	var popup := option.get_popup()
	popup.add_theme_font_size_override("font_size", font_size)
	popup.add_theme_constant_override("item_start_padding", 20)
	popup.add_theme_constant_override("item_end_padding", 20)
	popup.add_theme_constant_override("v_separation", 12)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.12, 0.13, 0.17, 1.0)
	panel.corner_radius_top_left = 16
	panel.corner_radius_top_right = 16
	panel.corner_radius_bottom_left = 16
	panel.corner_radius_bottom_right = 16
	panel.content_margin_left = 12
	panel.content_margin_top = 12
	panel.content_margin_right = 12
	panel.content_margin_bottom = 12
	popup.add_theme_stylebox_override("panel", panel)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.22, 0.24, 0.32, 1.0)
	hover.corner_radius_top_left = 12
	hover.corner_radius_top_right = 12
	hover.corner_radius_bottom_left = 12
	hover.corner_radius_bottom_right = 12
	popup.add_theme_stylebox_override("hover", hover)
	popup.add_theme_color_override("font_color", TEXT_ON_DARK)
	popup.add_theme_color_override("font_hover_color", TEXT_ON_DARK)
	popup.add_theme_color_override("font_separator_color", TEXT_ON_DARK)


static func text_field_stylebox(focused: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.13, 1.0)
	style.border_color = Color(0.48, 0.5, 0.56, 1.0) if focused else Color(0.34, 0.36, 0.42, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	return style


static func _apply_row_field_margins(style: StyleBoxFlat, arrow_room: int = 0) -> void:
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12 + arrow_room
	style.content_margin_bottom = 8


static func row_text_field_stylebox(focused: bool = false) -> StyleBoxFlat:
	var style := text_field_stylebox(focused)
	_apply_row_field_margins(style)
	return style


static func row_option_field_stylebox(focused: bool = false) -> StyleBoxFlat:
	var style := text_field_stylebox(focused)
	_apply_row_field_margins(style, 18)
	return style


static func style_text_field(field: LineEdit) -> void:
	field.custom_minimum_size = Vector2(0, 48)
	field.add_theme_stylebox_override("normal", text_field_stylebox(false))
	field.add_theme_stylebox_override("focus", text_field_stylebox(true))
	field.add_theme_color_override("font_color", TEXT_ON_DARK)
	field.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	field.add_theme_font_size_override("font_size", 18)
	field.caret_blink = true


static func style_row_text_field(field: LineEdit) -> void:
	field.custom_minimum_size = Vector2(0, 40)
	field.add_theme_stylebox_override("normal", row_text_field_stylebox(false))
	field.add_theme_stylebox_override("focus", row_text_field_stylebox(true))
	field.add_theme_color_override("font_color", TEXT_ON_DARK)
	field.add_theme_color_override("font_placeholder_color", TEXT_MUTED)
	field.add_theme_font_size_override("font_size", 16)
	field.caret_blink = true


static func _apply_option_field_theme(
	option: OptionButton,
	normal_style: StyleBoxFlat,
	focus_style: StyleBoxFlat,
	min_height: int = 48,
	font_size: int = 18
) -> void:
	option.custom_minimum_size = Vector2(0, min_height)
	option.add_theme_stylebox_override("normal", normal_style)
	option.add_theme_stylebox_override("pressed", normal_style)
	option.add_theme_stylebox_override("hover", focus_style)
	option.add_theme_stylebox_override("focus", focus_style)
	option.add_theme_color_override("font_color", TEXT_ON_DARK)
	option.add_theme_font_size_override("font_size", font_size)
	option.add_theme_constant_override("arrow_margin", 12)
	option.add_theme_constant_override("align_to_largest_stylebox", 0)


static func style_option_field(option: OptionButton) -> void:
	var normal := text_field_stylebox(false)
	normal.content_margin_right = 28
	var focus := text_field_stylebox(true)
	focus.content_margin_right = 28
	_apply_option_field_theme(option, normal, focus)


static func style_row_option_field(option: OptionButton) -> void:
	_apply_option_field_theme(
		option,
		row_option_field_stylebox(false),
		row_option_field_stylebox(true),
		40,
		16
	)


static func style_close_button(button: Button) -> void:
	## Compact circular primary control for modal dismiss.
	var size := 44
	button.custom_minimum_size = Vector2(size, size)
	button.text = ""
	button.icon = null
	button.add_theme_stylebox_override("normal", circle_stylebox(PRIMARY_FILL))
	button.add_theme_stylebox_override("hover", circle_stylebox(PRIMARY_FILL_HOVER))
	button.add_theme_stylebox_override("pressed", circle_stylebox(PRIMARY_FILL_PRESSED))
	button.add_theme_stylebox_override("focus", circle_stylebox(PRIMARY_FILL_HOVER))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_attach_fa_glyph(button, "xmark", Color.WHITE, 20.0)


static func _attach_fa_glyph(button: Button, icon_name: String, color: Color, px: float) -> void:
	var glyph := button.get_node_or_null("FaGlyph") as FaIconView
	if glyph == null:
		glyph = FaIconView.new()
		glyph.name = "FaGlyph"
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(glyph)
	glyph.icon_name = icon_name
	glyph.icon_color = color
	glyph.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	glyph.custom_minimum_size = Vector2(px, px)
	glyph.size = Vector2(px, px)
	glyph.offset_left = -px * 0.5
	glyph.offset_right = px * 0.5
	glyph.offset_top = -px * 0.5
	glyph.offset_bottom = px * 0.5


static func style_circle_back_button(button: Button, size: int = -1, accent: Color = PRIMARY) -> void:
	var resolved := size if size > 0 else CIRCLE_BUTTON_SIZE
	style_circle_icon_button(button, resolved, accent)
	if button is CircleIconButton:
		(button as CircleIconButton).fa_icon = "arrow-left"
	elif button.has_method("set") and button.get("fa_icon") != null:
		button.set("fa_icon", "arrow-left")


static func style_circle_icon_button(button: Button, size: int = -1, accent: Color = PRIMARY) -> void:
	## Thumb-friendly circular icon control (glyph drawn as vectors in _draw).
	var resolved := size if size > 0 else CIRCLE_BUTTON_SIZE
	button.custom_minimum_size = Vector2(resolved, resolved)
	button.size = Vector2(resolved, resolved)
	button.text = ""
	button.icon = null
	button.expand_icon = false
	button.add_theme_constant_override("h_separation", 0)
	var border_w := maxi(5, int(round(float(resolved) * 0.05)))
	var hover_accent := accent.lightened(0.12)
	var press_accent := accent.darkened(0.12)
	var normal := circle_stylebox(SECONDARY_BG)
	normal.border_color = accent
	normal.set_border_width_all(border_w)
	var hover := circle_stylebox(SECONDARY_BG_HOVER)
	hover.border_color = hover_accent
	hover.set_border_width_all(border_w)
	var pressed := circle_stylebox(SECONDARY_BG_PRESSED)
	pressed.border_color = press_accent
	pressed.set_border_width_all(border_w)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", pressed)
	button.add_theme_color_override("icon_normal_color", accent)
	button.add_theme_color_override("icon_hover_color", hover_accent)
	button.add_theme_color_override("icon_pressed_color", press_accent)
	button.add_theme_color_override("icon_disabled_color", Color(accent, 0.45))
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Attach a scrolling BrandRainbow border to a Control that owns its own face
## (e.g. MenuActionButton). Returns the overlay for resize-sync.
static func attach_rainbow_border(
	host: Control,
	corner_radius_px: float = float(BUTTON_CORNER_RADIUS),
	border_width_px: float = float(BUTTON_BORDER_WIDTH)
) -> ColorRect:
	var existing := host.get_node_or_null("RainbowBorder")
	if existing != null:
		existing.queue_free()
	var border := ColorRect.new()
	border.name = "RainbowBorder"
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border.color = Color(1, 1, 1, 1)
	var mat := _BRAND_RAINBOW.make_border_material(corner_radius_px, border_width_px)
	border.material = mat
	border.set_meta("brand_rainbow_mat", mat)
	host.add_child(border)
	return border


static func sync_rainbow_border(border: ColorRect, rect_size: Vector2) -> void:
	if border == null:
		return
	var mat: ShaderMaterial = border.get_meta("brand_rainbow_mat", null) as ShaderMaterial
	if mat == null and border.material is ShaderMaterial:
		mat = border.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("rect_size", rect_size)
	_BRAND_RAINBOW.sync_material(mat)
