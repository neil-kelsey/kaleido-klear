extends RefCounted
class_name UiTheme

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

## Floor sizes so phone / small preview windows stay readable.
const MIN_MENU_FONT_SIZE := 56
const MIN_MENU_TITLE_FONT_SIZE := 64
const MIN_MENU_HINT_FONT_SIZE := 36
const MIN_MENU_BUTTON_HEIGHT := 108
const MENU_BUTTON_FONT_SIZE := 64
const MENU_BUTTON_ICON_SIZE := 44


static func menu_font_size(desired: int, minimum: int = MIN_MENU_FONT_SIZE) -> int:
	return maxi(desired, minimum)


static func apply_label_font(label: Label, desired: int, minimum: int = MIN_MENU_FONT_SIZE) -> void:
	label.add_theme_font_size_override("font_size", menu_font_size(desired, minimum))


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


static func style_menu_button(button: Button) -> void:
	_style_text_button(
		button,
		menu_font_size(MENU_BUTTON_FONT_SIZE),
		MIN_MENU_BUTTON_HEIGHT,
		MENU_BUTTON_ICON_SIZE,
		20
	)


static func style_hud_button(button: Button) -> void:
	## In-game chrome — readable on phone, smaller than full menu rows.
	_style_text_button(button, menu_font_size(32, 28), 72, 28, 14)


static func _style_text_button(
	button: Button,
	font_size: int,
	min_height: int,
	icon_size: int,
	corner_radius: int
) -> void:
	button.add_theme_stylebox_override("normal", rounded_stylebox(BUTTON, corner_radius))
	button.add_theme_stylebox_override("hover", rounded_stylebox(BUTTON_HOVER, corner_radius))
	button.add_theme_stylebox_override("pressed", rounded_stylebox(BUTTON_PRESSED, corner_radius))
	button.add_theme_stylebox_override("focus", rounded_stylebox(BUTTON_HOVER, corner_radius))
	button.add_theme_color_override("font_color", TEXT_ON_DARK)
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, float(min_height))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("h_separation", 16)


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
	option.add_theme_stylebox_override("hover", focus_style)
	option.add_theme_stylebox_override("pressed", normal_style)
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


static func style_play_button(button: Button) -> void:
	var size := 200
	button.custom_minimum_size = Vector2(size, size)
	button.add_theme_stylebox_override("normal", circle_stylebox(PLAY))
	button.add_theme_stylebox_override("hover", circle_stylebox(PLAY_HOVER))
	button.add_theme_stylebox_override("pressed", circle_stylebox(PLAY_PRESSED))
	button.add_theme_stylebox_override("focus", circle_stylebox(PLAY_HOVER))
	button.icon = load("res://assets/icons/play_icon.svg")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 80)


static func style_close_button(button: Button) -> void:
	var size := 44
	button.custom_minimum_size = Vector2(size, size)
	button.text = ""
	button.icon = load("res://assets/icons/close_icon.svg")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_stylebox_override("normal", circle_stylebox(BUTTON))
	button.add_theme_stylebox_override("hover", circle_stylebox(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", circle_stylebox(BUTTON_PRESSED))
	button.add_theme_stylebox_override("focus", circle_stylebox(BUTTON_HOVER))
