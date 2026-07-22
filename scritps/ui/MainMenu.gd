extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const STANDARD_LEVEL := preload("res://resources/levels/demo_level.tres")

## Klear size relative to the fitted Kaleido size (logo proportion).
const KLEAR_TO_KALEIDO_RATIO := 0.68
## Brand mark size relative to content width (same column as the buttons).
const ICON_WIDTH_RATIO := 0.52
## Shared page column inset — logo, titles, and buttons all share this edge.
const MENU_SIDE_MARGIN_RATIO := 0.15

@onready var margin: MarginContainer = $Margin
@onready var hero_title: BrandTitleLine = %HeroTitle
@onready var subtitle_title: BrandTitleLine = %SubtitleTitle
@onready var brand_icon: TextureRect = %BrandIcon
@onready var play_button: MenuActionButton = %PlayButton
@onready var level_select_button: MenuActionButton = %LevelSelectButton
@onready var settings_button: MenuActionButton = %SettingsButton


func _ready() -> void:
	_apply_translations()
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	_on_viewport_resized()


func _on_viewport_resized() -> void:
	_apply_side_margins()
	_fit_brand_titles()


func _apply_side_margins() -> void:
	if margin == null:
		return
	var side := int(round(get_viewport_rect().size.x * MENU_SIDE_MARGIN_RATIO))
	side = maxi(side, 56)
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)


func _fit_brand_titles() -> void:
	if hero_title == null or subtitle_title == null:
		return
	## Fit to the shared content column (same width the buttons use).
	var side_margin := float(margin.get_theme_constant("margin_left")) if margin else 0.0
	var usable_width := maxf(get_viewport_rect().size.x - side_margin * 2.0, 120.0)
	hero_title.fit_to_width(usable_width)
	subtitle_title.match_scale(hero_title.font_size, KLEAR_TO_KALEIDO_RATIO)
	if brand_icon != null:
		var icon_size := clampf(usable_width * ICON_WIDTH_RATIO, 160.0, 360.0)
		brand_icon.custom_minimum_size = Vector2(icon_size, icon_size)


func _apply_translations() -> void:
	play_button.set_label(tr("UI_START_GAME"))
	level_select_button.set_label(tr("UI_LEVEL_SELECT"))
	settings_button.set_label(tr("UI_SETTINGS"))


func _on_play_button_pressed() -> void:
	GameSession.set_level(STANDARD_LEVEL)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_level_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/dimension_map.tscn")


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")
