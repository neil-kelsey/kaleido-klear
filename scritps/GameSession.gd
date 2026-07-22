extends Node

const DEV_SETTINGS_PATH := "user://dev_settings.cfg"

var selected_level: LevelConfig = null
var level_stars: Dictionary = {}
var develop_mode: bool = false
var playtest_mode: bool = false
var playtest_level_draft: LevelConfig = null
var playtest_passed: bool = false
## Last / current dimension on the star map (section index).
var current_dimension_index: int = 0


func _ready() -> void:
	_load_develop_mode()


func set_level(level: LevelConfig) -> void:
	selected_level = level
	playtest_mode = false
	if level != null:
		var context: Dictionary = LevelCatalog.find_level_context(level.level_id)
		if not context.is_empty():
			current_dimension_index = int(context.section_index)


func set_current_dimension(section_index: int) -> void:
	current_dimension_index = clampi(section_index, 0, LevelCatalog.get_dimension_count() - 1)


func restart_level(level: LevelConfig) -> void:
	if level == null:
		return
	if playtest_mode:
		selected_level = level.duplicate(true) as LevelConfig
	else:
		set_level(level)


func start_playtest(level: LevelConfig) -> void:
	playtest_mode = true
	playtest_passed = false
	playtest_level_draft = level.duplicate(true) as LevelConfig
	selected_level = level.duplicate(true) as LevelConfig


func mark_playtest_passed() -> void:
	playtest_passed = true


func end_playtest() -> void:
	playtest_mode = false
	selected_level = null


func consume_playtest_draft() -> LevelConfig:
	var draft := playtest_level_draft
	playtest_level_draft = null
	return draft


func consume_playtest_passed() -> bool:
	var passed := playtest_passed
	playtest_passed = false
	return passed


func consume_level() -> LevelConfig:
	var level := selected_level
	selected_level = null
	return level


func record_level_stars(level: LevelConfig, stars: int) -> void:
	if level == null:
		return
	var previous: int = level_stars.get(level.level_id, 0)
	level_stars[level.level_id] = maxi(previous, stars)


func get_level_stars(level_id: String) -> int:
	return level_stars.get(level_id, 0)


func is_level_unlocked(level: LevelConfig) -> bool:
	if develop_mode:
		return level != null
	if level == null:
		return false
	if CustomLevelStore.has_level(level.level_id):
		return true
	var all_levels := LevelCatalog.get_all_levels()
	for i in all_levels.size():
		if all_levels[i].level_id == level.level_id:
			if i == 0:
				return true
			return get_level_stars(all_levels[i - 1].level_id) > 0
	return false


func get_next_level(current: LevelConfig) -> LevelConfig:
	return LevelCatalog.get_next_level(current)


func has_next_level(current: LevelConfig) -> bool:
	return get_next_level(current) != null


func set_develop_mode(enabled: bool) -> void:
	develop_mode = enabled
	_save_develop_mode()


func _load_develop_mode() -> void:
	var config := ConfigFile.new()
	if config.load(DEV_SETTINGS_PATH) != OK:
		return
	develop_mode = config.get_value("dev", "develop_mode", false)


func _save_develop_mode() -> void:
	var config := ConfigFile.new()
	config.set_value("dev", "develop_mode", develop_mode)
	config.save(DEV_SETTINGS_PATH)
