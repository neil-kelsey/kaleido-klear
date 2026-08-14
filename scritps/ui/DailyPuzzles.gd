extends Control

## Daily puzzle list — same layout language as dimension level select.

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

@onready var title_label: Label = %TitleLabel
@onready var date_label: Label = %DateLabel
@onready var levels_container: VBoxContainer = %LevelsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var back_button: Button = %BackButton

var _todays_levels: Array[LevelConfig] = []


func _ready() -> void:
	_todays_levels = DailyCatalog.get_todays_levels()
	_apply_translations()
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_hint(date_label)
	date_label.add_theme_color_override("font_color", Color(0.25, 0.35, 0.55, 0.9))
	UiTheme.style_nav_button(back_button)
	UiTheme.style_menu_hint(empty_label)
	_build_levels()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		_build_levels()


func _apply_translations() -> void:
	title_label.text = tr("UI_DAILY_PUZZLES")
	date_label.text = DailyCatalog.format_today_date()
	back_button.text = "  " + tr("UI_BACK")
	empty_label.text = tr("UI_DAILY_EMPTY")


func _build_levels() -> void:
	for child in levels_container.get_children():
		child.queue_free()
	empty_label.visible = _todays_levels.is_empty()
	for i in _todays_levels.size():
		var level: LevelConfig = _todays_levels[i]
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, UiTheme.MIN_MENU_BUTTON_HEIGHT)
		var label := level.display_name.strip_edges()
		if label.is_empty():
			label = tr("UI_DAILY_PUZZLE") % (i + 1)
		var stars := GameSession.get_level_stars(level.level_id)
		var star_text := ""
		for s in 3:
			star_text += "★" if s < stars else "☆"
		var unlocked := DailyCatalog.is_level_unlocked(_todays_levels, level)
		if unlocked:
			button.text = "  %s   %s" % [label, star_text]
			button.icon = null
			UiTheme.style_nav_button(button)
			button.pressed.connect(_on_level_pressed.bind(level))
		else:
			button.text = "  %s  —  %s" % [label, tr("UI_LOCKED")]
			button.disabled = true
			UiTheme.style_nav_button(button)
		levels_container.add_child(button)


func _on_level_pressed(level: LevelConfig) -> void:
	GameSession.set_level_playlist(_todays_levels)
	GameSession.set_return_scene("res://scenes/ui/daily_puzzles.tscn")
	GameSession.set_level(level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func handle_back() -> void:
	_on_back_button_pressed()
