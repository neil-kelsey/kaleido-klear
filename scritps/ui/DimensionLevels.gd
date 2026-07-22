extends Control

## Simple per-dimension level list (placeholder UI for later polish).

const DIMENSION_MAP_SCENE := "res://scenes/ui/dimension_map.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

@onready var title_label: Label = %TitleLabel
@onready var levels_container: VBoxContainer = %LevelsContainer
@onready var empty_label: Label = %EmptyLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	var dim := GameSession.current_dimension_index
	title_label.text = LevelCatalog.get_dimension_title(dim)
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	back_button.text = "  " + tr("UI_BACK")
	empty_label.text = tr("UI_DIMENSION_EMPTY")
	UiTheme.style_menu_hint(empty_label)
	_build_levels(dim)


func _build_levels(dim: int) -> void:
	for child in levels_container.get_children():
		child.queue_free()
	var levels := LevelCatalog.get_section_levels(dim)
	empty_label.visible = levels.is_empty()
	for level in levels:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, UiTheme.MIN_MENU_BUTTON_HEIGHT)
		var stars := GameSession.get_level_stars(level.level_id)
		var star_text := ""
		for s in 3:
			star_text += "★" if s < stars else "☆"
		var unlocked := GameSession.is_level_unlocked(level)
		if unlocked:
			button.text = "  %s   %s" % [LevelCatalog.get_level_label(level), star_text]
			button.icon = load("res://assets/icons/play_icon.svg")
			button.pressed.connect(_on_level_pressed.bind(level))
		else:
			button.text = "  %s  — %s" % [LevelCatalog.get_level_label(level), tr("UI_LOCKED")]
			button.disabled = true
		UiTheme.style_menu_button(button)
		levels_container.add_child(button)


func _on_level_pressed(level: LevelConfig) -> void:
	GameSession.set_level(level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(DIMENSION_MAP_SCENE)
