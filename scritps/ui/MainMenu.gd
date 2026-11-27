extends Control

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const DAILY_PUZZLES_SCENE := "res://scenes/ui/daily_puzzles.tscn"

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
@onready var exit_confirm_modal: Control = %ExitConfirmModal
@onready var star_map: Control = %StarMap

## Same baked planisphere the Dimensions screen draws (DimensionMap / StarChartBaker),
## with its radial centre (world 0,0) pinned behind the K logo.
const STAR_MAP_SCALE_PER_412PX := 0.85
const STAR_MAP_OPACITY := 0.9
const DIMENSION_MAP_SCRIPT := preload("res://scritps/ui/DimensionMap.gd")
const STREAK_CLUSTER_SCRIPT := preload("res://scritps/ui/DailyStreakCluster.gd")
var _star_map_tex: Texture2D

var _streak_cluster: Control


func _ready() -> void:
	_apply_translations()
	_build_streak_cluster()
	GameSession.maybe_open_daily_from_reminder()
	_star_map_tex = load(DIMENSION_MAP_SCRIPT.STAR_CHART_PATH) as Texture2D
	star_map.draw.connect(_draw_star_map)
	brand_icon.item_rect_changed.connect(star_map.queue_redraw)
	get_viewport().size_changed.connect(_on_viewport_resized)
	await get_tree().process_frame
	_on_viewport_resized()


func _draw_star_map() -> void:
	if _star_map_tex == null:
		return
	var strip: Rect2 = DIMENSION_MAP_SCRIPT.STRIP_WORLD
	var tex_size := _star_map_tex.get_size()
	var s := star_map.size.x / 412.0 * STAR_MAP_SCALE_PER_412PX
	## Chart pixel of the planisphere's radial centre (world origin).
	var hub_px := (Vector2.ZERO - strip.position) * (tex_size / strip.size)
	var centre := brand_icon.get_global_rect().get_center() - star_map.get_global_rect().position
	var draw_size := strip.size * s
	var origin := centre - hub_px * (draw_size / tex_size)
	star_map.draw_texture_rect(_star_map_tex, Rect2(origin, draw_size), false, Color(1, 1, 1, STAR_MAP_OPACITY))
	## The baked strip stops a little below its hub; feather that edge into the page colour.
	var bottom := origin.y + draw_size.y
	if bottom < star_map.size.y:
		var fade := 140.0 * s
		var bg: Color = DIMENSION_MAP_SCRIPT.CHART_BG
		var clear := Color(bg.r, bg.g, bg.b, 0.0)
		star_map.draw_polygon(
			PackedVector2Array([Vector2(0, bottom - fade), Vector2(star_map.size.x, bottom - fade), Vector2(star_map.size.x, bottom + 1), Vector2(0, bottom + 1)]),
			PackedColorArray([clear, clear, bg, bg])
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()


func handle_back() -> void:
	if exit_confirm_modal != null and exit_confirm_modal.visible:
		exit_confirm_modal.hide_modal()
		return
	if exit_confirm_modal != null:
		exit_confirm_modal.show_modal()


## Streak details live in the Daily Puzzle button's trailing slot (replaces the chevron).
## Today not done: flame + greyed-out streak count.
## Done with 2 hearts or fewer remaining (1–2 stars): tick + green count.
## Perfect (3 stars, all hearts remaining): star + green count.
func _build_streak_cluster() -> void:
	if level_select_button == null:
		return
	_streak_cluster = STREAK_CLUSTER_SCRIPT.new()
	_streak_cluster.apply_from_session()
	level_select_button.set_custom_trailing(_streak_cluster)


func _on_viewport_resized() -> void:
	_apply_side_margins()
	_fit_brand_titles()
	star_map.queue_redraw.call_deferred()


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
	if play_button == null or level_select_button == null or settings_button == null:
		return
	play_button.set_label(tr("UI_LEVEL_SELECT"))
	level_select_button.set_label(tr("UI_DAILY_PUZZLES"))
	settings_button.set_label(tr("UI_SETTINGS"))


func _on_play_button_pressed() -> void:
	GameSession.set_return_scene(DIMENSION_MAP_SCENE)
	get_tree().change_scene_to_file(DIMENSION_MAP_SCENE)


func _on_level_select_button_pressed() -> void:
	get_tree().change_scene_to_file(DAILY_PUZZLES_SCENE)


func _on_settings_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/settings.tscn")


func _on_exit_confirmed() -> void:
	get_tree().quit()


func _on_exit_cancelled() -> void:
	pass
