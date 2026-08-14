extends Node

const SETTINGS_PATH := "user://settings.cfg"
const DEV_SETTINGS_PATH := "user://dev_settings.cfg"
## Dedicated progress file — survives app restarts on phone (JSON is reliable on Android).
const PROGRESS_PATH := "user://progress.json"

## Supported app locales (code must match Language: header in locales/*.po).
const AVAILABLE_LOCALES: Array[Dictionary] = [
	{"code": "en", "name_key": "UI_LANGUAGE_ENGLISH"},
	{"code": "fr", "name_key": "UI_LANGUAGE_FRENCH"},
	{"code": "pirate", "name_key": "UI_LANGUAGE_PIRATE"},
]

signal locale_changed(locale_code: String)

var selected_level: LevelConfig = null
var level_stars: Dictionary = {}
var level_perfect: Dictionary = {}
var develop_mode: bool = false
var playtest_mode: bool = false
var playtest_level_draft: LevelConfig = null
var playtest_passed: bool = false
## Last / current dimension on the star map (section index).
var current_dimension_index: int = 0
## When true, DimensionMap plays a zoom-out from the current diamond (back from levels).
var pending_map_zoom_out: bool = false
var locale: String = "en"
## Scene to return to from gameplay (dimensions map, daily list, etc.).
var return_scene_path: String = "res://scenes/ui/dimension_map.tscn"
## Optional ordered playlist (daily puzzles). Empty = campaign catalog order.
var active_level_playlist: Array[LevelConfig] = []


func _ready() -> void:
	_load_settings()
	_load_progress()
	## Defer so scene @onready nodes exist before TRANSLATION_CHANGED fires.
	call_deferred("_boot_locale")


func _notification(what: int) -> void:
	## Flush progress if Android sends the app to background / closes it.
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_WM_CLOSE_REQUEST
	):
		_save_progress()


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
	var next := clampi(section_index, 0, LevelCatalog.get_dimension_count() - 1)
	if next == current_dimension_index:
		return
	current_dimension_index = next
	_save_progress()


func consume_map_zoom_out() -> bool:
	var pending := pending_map_zoom_out
	pending_map_zoom_out = false
	return pending


func change_scene(path: String) -> void:
	## Prefer this over node.get_tree() during input — autoload stays in the tree
	## even after the current scene starts tearing down.
	if path.strip_edges().is_empty():
		return
	var tree := get_tree()
	if tree == null:
		push_warning("GameSession.change_scene: SceneTree missing for %s" % path)
		return
	tree.change_scene_to_file(path)


func set_return_scene(path: String) -> void:
	if path.strip_edges().is_empty():
		return_scene_path = "res://scenes/ui/dimension_map.tscn"
	else:
		return_scene_path = path


func get_return_scene() -> String:
	if return_scene_path.strip_edges().is_empty():
		return "res://scenes/ui/dimension_map.tscn"
	return return_scene_path


func set_level_playlist(levels: Array[LevelConfig]) -> void:
	active_level_playlist = levels.duplicate()


func clear_level_playlist() -> void:
	active_level_playlist.clear()


func is_last_in_playlist(level: LevelConfig) -> bool:
	if level == null or active_level_playlist.is_empty():
		return false
	return active_level_playlist[active_level_playlist.size() - 1].level_id == level.level_id


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


func record_level_stars(level: LevelConfig, stars: int, perfect: bool = false) -> void:
	if level == null:
		return
	var id := level.level_id
	var previous: int = int(level_stars.get(id, 0))
	var next := maxi(previous, clampi(stars, 0, 3))
	var already_perfect := is_perfect_clear(id)
	var next_perfect := already_perfect or perfect
	if next == previous and previous > 0 and next_perfect == already_perfect:
		return
	level_stars[id] = next
	level_perfect[id] = next_perfect
	## Write immediately so a phone close after clear still keeps the stars.
	_save_progress()


func get_level_stars(level_id: String) -> int:
	return int(level_stars.get(level_id, 0))


func reset_progress() -> void:
	## Clears stars / unlocks. Keeps language and develop-mode prefs.
	level_stars.clear()
	level_perfect.clear()
	current_dimension_index = 0
	selected_level = null
	clear_level_playlist()
	_save_progress()


func is_level_unlocked(level: LevelConfig) -> bool:
	if develop_mode:
		return level != null
	if level == null:
		return false
	if CustomLevelStore.has_level(level.level_id):
		return true
	var context: Dictionary = LevelCatalog.find_level_context(level.level_id)
	if context.is_empty():
		return false
	var section_index: int = int(context.section_index)
	if not LevelCatalog.is_dimension_unlocked(section_index):
		return false
	var section_levels := LevelCatalog.get_section_levels(section_index)
	var level_index: int = int(context.level_index)
	if level_index <= 0:
		return true
	if level_index >= section_levels.size():
		return false
	return get_level_stars(section_levels[level_index - 1].level_id) > 0


func is_level_completed(level_id: String) -> bool:
	return get_level_stars(level_id) > 0


func is_perfect_clear(level_id: String) -> bool:
	## Perfect = cleared without losing a life and without using undo.
	if level_perfect.has(level_id):
		return bool(level_perfect[level_id])
	## Legacy saves: 3 remaining lives was stored as 3 stars.
	return get_level_stars(level_id) >= 3


func get_next_level(current: LevelConfig) -> LevelConfig:
	if current != null and not active_level_playlist.is_empty():
		for i in active_level_playlist.size():
			if active_level_playlist[i].level_id == current.level_id:
				if i + 1 < active_level_playlist.size():
					return active_level_playlist[i + 1]
				return null
		return null
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
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save settings.cfg: %s" % error_string(err))


func _load_progress() -> void:
	level_stars.clear()
	level_perfect.clear()
	current_dimension_index = 0
	if FileAccess.file_exists(PROGRESS_PATH):
		var file := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				_apply_progress_dict(parsed as Dictionary)
				return
	## Migrate older builds that stored stars inside settings.cfg.
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var stored: Variant = config.get_value("progress", "level_stars", {})
		if typeof(stored) == TYPE_DICTIONARY and not (stored as Dictionary).is_empty():
			_apply_progress_dict({
				"level_stars": stored,
				"current_dimension_index": int(config.get_value("progress", "current_dimension_index", 0)),
			})
			_save_progress()


func _apply_progress_dict(data: Dictionary) -> void:
	var stars_raw: Variant = data.get("level_stars", {})
	if typeof(stars_raw) == TYPE_DICTIONARY:
		for key in (stars_raw as Dictionary).keys():
			level_stars[str(key)] = clampi(int(stars_raw[key]), 0, 3)
	var perfect_raw: Variant = data.get("level_perfect", {})
	if typeof(perfect_raw) == TYPE_DICTIONARY:
		for key in (perfect_raw as Dictionary).keys():
			level_perfect[str(key)] = bool(perfect_raw[key])
	current_dimension_index = maxi(0, int(data.get("current_dimension_index", 0)))


func _save_progress() -> void:
	var payload := {
		"level_stars": level_stars.duplicate(),
		"level_perfect": level_perfect.duplicate(),
		"current_dimension_index": current_dimension_index,
	}
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open progress.json for write: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()
