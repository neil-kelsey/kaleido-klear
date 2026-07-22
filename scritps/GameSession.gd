extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEV_SETTINGS_PATH := "user://dev_settings.cfg"

## Supported app locales (code must match Language: header in locales/*.po).
const AVAILABLE_LOCALES: Array[Dictionary] = [
	{"code": "en", "name_key": "UI_LANGUAGE_ENGLISH"},
	{"code": "fr", "name_key": "UI_LANGUAGE_FRENCH"},
	{"code": "pirate", "name_key": "UI_LANGUAGE_PIRATE"},
]

signal locale_changed(locale_code: String)

var selected_level: LevelConfig = null
var level_stars: Dictionary = {}
var develop_mode: bool = false
var playtest_mode: bool = false
var playtest_level_draft: LevelConfig = null
var playtest_passed: bool = false
## Last / current dimension on the star map (section index).
var current_dimension_index: int = 0
var locale: String = "en"


func _ready() -> void:
	_load_settings()
	## Defer so scene @onready nodes exist before TRANSLATION_CHANGED fires.
	call_deferred("_boot_locale")


func _boot_locale() -> void:
	_apply_locale(locale, false)


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
	_save_settings()


func set_locale(locale_code: String) -> void:
	var code := _normalize_locale(locale_code)
	if code == locale and TranslationServer.get_locale() == code:
		return
	_apply_locale(code, true)


func get_locale_display_name(locale_code: String) -> String:
	for entry in AVAILABLE_LOCALES:
		if str(entry.code) == locale_code:
			return tr(str(entry.name_key))
	return locale_code


func _apply_locale(locale_code: String, persist: bool) -> void:
	locale = _normalize_locale(locale_code)
	TranslationServer.set_locale(locale)
	if persist:
		_save_settings()
	locale_changed.emit(locale)


func _normalize_locale(locale_code: String) -> String:
	for entry in AVAILABLE_LOCALES:
		if str(entry.code) == locale_code:
			return locale_code
	return "en"


func _load_settings() -> void:
	var config := ConfigFile.new()
	## Prefer unified settings; fall back to legacy develop-mode file.
	if config.load(SETTINGS_PATH) == OK:
		develop_mode = bool(config.get_value("dev", "develop_mode", false))
		locale = _normalize_locale(str(config.get_value("i18n", "locale", "en")))
		return
	if config.load(DEV_SETTINGS_PATH) == OK:
		develop_mode = bool(config.get_value("dev", "develop_mode", false))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("dev", "develop_mode", develop_mode)
	config.set_value("i18n", "locale", locale)
	config.save(SETTINGS_PATH)
