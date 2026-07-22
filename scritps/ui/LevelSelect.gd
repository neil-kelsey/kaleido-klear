extends Control

const MAIN_MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const GAME_SCENE := "res://scenes/main.tscn"

@onready var title_label: Label = %TitleLabel
@onready var sections_container: VBoxContainer = %SectionsContainer
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_apply_translations()
	UiTheme.style_menu_title(title_label)
	UiTheme.style_menu_button(back_button)
	back_button.icon = load("res://assets/icons/back_icon.svg")
	_build_sections()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		_build_sections()


func _apply_translations() -> void:
	title_label.text = tr("UI_LEVEL_SELECT_TITLE")
	back_button.text = "  " + tr("UI_BACK")


func _build_sections() -> void:
	for child in sections_container.get_children():
		child.free()

	for section_index in LevelCatalog.SECTIONS.size():
		var section: Dictionary = LevelCatalog.SECTIONS[section_index]
		var section_title := Label.new()
		section_title.text = tr(section["title_key"])
		UiTheme.style_menu_section_title(section_title)
		sections_container.add_child(section_title)

		var section_levels := LevelCatalog.get_section_levels(section_index)
		for level in section_levels:
			var button := Button.new()
			button.custom_minimum_size = Vector2(0, UiTheme.MIN_MENU_BUTTON_HEIGHT)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			UiTheme.style_menu_button(button)
			var level_label := LevelCatalog.get_level_label(level)
			var unlocked := GameSession.is_level_unlocked(level)
			if unlocked:
				button.icon = load("res://assets/icons/play_icon.svg")
				var stars := GameSession.get_level_stars(level.level_id)
				var stars_text := _stars_text(stars)
				button.text = "  %s  %s" % [level_label, stars_text]
				button.pressed.connect(_on_level_pressed.bind(level))
			else:
				button.disabled = true
				button.text = "  %s  —  %s" % [level_label, tr("UI_LOCKED")]
			sections_container.add_child(button)

		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 12)
		sections_container.add_child(spacer)


func _stars_text(stars: int) -> String:
	if stars <= 0:
		return ""
	var filled := "★".repeat(stars)
	var empty := "☆".repeat(3 - stars)
	return filled + empty


func _on_level_pressed(level: LevelConfig) -> void:
	GameSession.set_level(level)
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
