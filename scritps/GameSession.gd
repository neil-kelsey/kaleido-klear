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

const Reminders := preload("res://scritps/StreakReminder.gd")

signal locale_changed(locale_code: String)

var selected_level: LevelConfig = null
var level_stars: Dictionary = {}
var level_perfect: Dictionary = {}
var level_best_moves: Dictionary = {}
var level_best_time_ms: Dictionary = {}
var develop_mode: bool = false
var playtest_mode: bool = false
## Play launched from the level audit page. Back and Next return there.
var audit_play: bool = false
var playtest_level_draft: LevelConfig = null
var playtest_passed: bool = false
## Creator dirty-check snapshot so Back still warns after returning from playtest.
var playtest_baseline_signature: String = ""
## Level opened from the audit. Empty when the creator started as a new level.
var creator_loaded_level_id: String = ""
## Where creator Back returns. Empty means the settings screen.
var creator_return_scene: String = ""
var creator_edit_level: LevelConfig = null
## Last / current dimension on the star map (section index).
var current_dimension_index: int = 0
## When true, DimensionMap plays a zoom-out from the current diamond (back from levels).
var pending_map_zoom_out: bool = false
var locale: String = "en"
var sfx_enabled: bool = true
var daily_reminders: bool = true
var reminder_hour: int = 12
var reminder_minute: int = 0
var _reminder_permission_asked: bool = false
var _reminder_test_pending: bool = false
## Scene to return to from gameplay (dimensions map, daily list, etc.).
var return_scene_path: String = "res://scenes/ui/dimension_map.tscn"
## Dimension level map should reopen on the subsection of this level.
var dimension_return_index: int = -1
var dimension_return_level_id: String = ""
## Optional ordered playlist (daily puzzles). Empty = campaign catalog order.
var active_level_playlist: Array[LevelConfig] = []
## Daily puzzle: "YYYY-MM-DD" -> {"daily": stars}. Legacy days may still have easy/medium/hard keys.
var daily_completed: Dictionary = {}
var daily_streak_current: int = 0
var daily_streak_best: int = 0
var daily_streak_last_date: String = ""
## Set while a daily is being played (cleared when any other level starts).
var active_daily_slot: String = ""
var active_daily_date: String = ""
var active_daily_level_id: String = ""
## Tutorial coach marks already shown (group id -> true).
var seen_tutorials: Dictionary = {}
## One-time in-game tip after the first heart loss (persists in progress.json).
var heart_tip_seen: bool = false
const DAILY_PUZZLES_SCENE := "res://scenes/ui/daily_puzzles.tscn"
var _scene_wipe: ColorRect
var _scene_wipe_tween: Tween


func _ready() -> void:
	_load_settings()
	_load_progress()
	_connect_reminder_signal()
	## Defer so scene @onready nodes exist before TRANSLATION_CHANGED fires.
	call_deferred("_boot_locale")
	call_deferred("_refresh_reminder")


func _notification(what: int) -> void:
	## Flush progress if Android sends the app to background / closes it.
	if (
		what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_WM_CLOSE_REQUEST
	):
		_save_progress()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_refresh_reminder()
		maybe_open_daily_from_reminder()


func _boot_locale() -> void:
	_apply_locale(locale, false)


func set_level(level: LevelConfig) -> void:
	selected_level = level
	playtest_mode = false
	audit_play = false
	## Leaving the daily for any other level drops the daily context and playlist.
	if level == null or level.level_id != active_daily_level_id:
		_clear_daily_context()
	if level != null:
		var context: Dictionary = LevelCatalog.find_level_context(level.level_id)
		if not context.is_empty():
			current_dimension_index = int(context.section_index)


## Tutorial used to live at section 10, after two empty stubs (8–9). Map those
## saves onto the current Tutorial index; anything else is clamped.
func _migrate_dimension_index(index: int) -> int:
	var count := LevelCatalog.get_dimension_count()
	if index == 10:
		var tutorial := LevelCatalog.get_tutorial_section_index()
		if tutorial >= 0:
			return tutorial
	return clampi(index, 0, maxi(count - 1, 0))


func set_current_dimension(section_index: int) -> void:
	var next := _migrate_dimension_index(section_index)
	if next == current_dimension_index:
		return
	current_dimension_index = next
	_save_progress()


func consume_map_zoom_out() -> bool:
	var pending := pending_map_zoom_out
	pending_map_zoom_out = false
	return pending


func _ensure_scene_wipe() -> void:
	if _scene_wipe != null and is_instance_valid(_scene_wipe):
		return
	var layer := CanvasLayer.new()
	layer.name = "SceneWipeLayer"
	layer.layer = 128
	add_child(layer)
	_scene_wipe = ColorRect.new()
	_scene_wipe.name = "SceneWipe"
	_scene_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_wipe.color = Color(0, 0, 0, 0)
	layer.add_child(_scene_wipe)


func set_scene_wipe(color: Color) -> void:
	_ensure_scene_wipe()
	if _scene_wipe_tween != null and is_instance_valid(_scene_wipe_tween):
		_scene_wipe_tween.kill()
		_scene_wipe_tween = null
	_scene_wipe.color = color


func sync_scene_wipe(color: Color) -> void:
	_ensure_scene_wipe()
	_scene_wipe.color = color


func fade_scene_wipe_to(target: Color, duration: float, on_done: Callable = Callable()) -> void:
	_ensure_scene_wipe()
	if _scene_wipe_tween != null and is_instance_valid(_scene_wipe_tween):
		_scene_wipe_tween.kill()
	_scene_wipe_tween = create_tween()
	_scene_wipe_tween.tween_property(_scene_wipe, "color", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	if on_done.is_valid():
		_scene_wipe_tween.tween_callback(on_done)


func fade_scene_wipe_out(duration: float = 0.28) -> void:
	_ensure_scene_wipe()
	if _scene_wipe.color.a < 0.01:
		return
	var clear := _scene_wipe.color
	clear.a = 0.0
	fade_scene_wipe_to(clear, duration)


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


func focus_dimension_level(level: LevelConfig) -> void:
	if level == null or get_return_scene() != "res://scenes/ui/dimension_levels.tscn":
		return
	dimension_return_index = current_dimension_index
	dimension_return_level_id = level.level_id


func consume_dimension_level_focus(dimension_index: int) -> String:
	if dimension_return_index != dimension_index or dimension_return_level_id.is_empty():
		return ""
	var level_id := dimension_return_level_id
	dimension_return_index = -1
	dimension_return_level_id = ""
	return level_id


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
	var keep_audit := audit_play
	if playtest_mode:
		selected_level = level.duplicate(true) as LevelConfig
	else:
		set_level(level)
		audit_play = keep_audit


func begin_daily_play(level: LevelConfig, slot: String, date_key: String) -> void:
	if level == null:
		return
	set_level(level)
	var single: Array[LevelConfig] = [level]
	## A one-level playlist: "next" can never walk into the campaign.
	set_level_playlist(single)
	set_return_scene(DAILY_PUZZLES_SCENE)
	active_daily_slot = slot
	active_daily_date = date_key
	active_daily_level_id = level.level_id


func is_daily_play(level: LevelConfig) -> bool:
	return (
		level != null
		and not playtest_mode
		and not audit_play
		and not active_daily_slot.is_empty()
		and level.level_id == active_daily_level_id
	)


func _clear_daily_context() -> void:
	if active_daily_level_id.is_empty():
		return
	active_daily_slot = ""
	active_daily_date = ""
	active_daily_level_id = ""
	clear_level_playlist()


## The single entry point for a daily win. Idempotent per UTC day: stars keep the
## best, and the streak moves at most once per day. Returns true if anything changed.
func record_daily_completion(slot: String, stars: int, date_key: String = "") -> bool:
	var key := slot if not slot.is_empty() else DailyCatalog.SLOT_DAILY
	## Old easy/medium/hard writes still count, stored under the single daily key.
	if key != DailyCatalog.SLOT_DAILY and not DailyCatalog.LEGACY_SLOTS.has(key):
		return false
	var day := date_key if not date_key.is_empty() else DailyCatalog.today_key()
	var clamped := clampi(stars, 0, 3)
	if clamped <= 0:
		return false
	var changed := false
	var entry: Dictionary = daily_completed.get(day, {})
	var previous := get_daily_stars(DailyCatalog.SLOT_DAILY, day)
	if clamped > previous:
		entry[DailyCatalog.SLOT_DAILY] = clamped
		daily_completed[day] = entry
		changed = true
	if apply_daily_streak(day):
		changed = true
	if changed:
		_save_progress()
		_maybe_ask_reminder_permission()
		_refresh_reminder()
	return changed


## Streak transition for a clear on `day`. Same day: no-op. Next day: +1. Gap: restart at 1.
func apply_daily_streak(day: String) -> bool:
	if day == daily_streak_last_date:
		return false
	if not daily_streak_last_date.is_empty() and day < daily_streak_last_date:
		return false
	if daily_streak_last_date == DailyCatalog.shift_date_key(day, -1):
		daily_streak_current += 1
	else:
		daily_streak_current = 1
	daily_streak_last_date = day
	daily_streak_best = maxi(daily_streak_best, daily_streak_current)
	return true


func get_daily_stars(slot: String = "", date_key: String = "") -> int:
	var day := date_key if not date_key.is_empty() else DailyCatalog.today_key()
	var entry: Dictionary = daily_completed.get(day, {})
	## New saves use "daily". If a legacy day has easy/medium/hard stars, take the best
	## so an already-cleared day stays cleared and the streak does not reset.
	if slot.is_empty() or slot == DailyCatalog.SLOT_DAILY:
		var best := int(entry.get(DailyCatalog.SLOT_DAILY, 0))
		for legacy in DailyCatalog.LEGACY_SLOTS:
			best = maxi(best, int(entry.get(legacy, 0)))
		return best
	return int(entry.get(slot, 0))


## Shown streak: 0 once a whole UTC day has been missed.
func get_display_streak(today: String = "") -> int:
	var day := today if not today.is_empty() else DailyCatalog.today_key()
	if daily_streak_last_date == day or daily_streak_last_date == DailyCatalog.shift_date_key(day, -1):
		return daily_streak_current
	return 0


## Any recorded stars (including legacy easy/medium/hard) count as done for that day.
func is_daily_done(date_key: String = "") -> bool:
	return get_daily_stars(DailyCatalog.SLOT_DAILY, date_key) > 0


## Perfect daily = the top 3-star rating (cleared with all lives remaining).
## Matches the Daily Puzzles diamond, which draws a gold star at 3 stars.
func is_daily_perfect(date_key: String = "") -> bool:
	return get_daily_stars(DailyCatalog.SLOT_DAILY, date_key) >= 3


func begin_audit_play(level: LevelConfig) -> void:
	if level == null:
		return
	clear_level_playlist()
	set_return_scene("res://scenes/ui/level_audit.tscn")
	set_level(level)
	audit_play = true


func end_audit_play() -> void:
	audit_play = false


func begin_creator_edit(level: LevelConfig, return_scene: String) -> void:
	if level == null:
		return
	creator_edit_level = level.duplicate(true) as LevelConfig
	creator_loaded_level_id = level.level_id
	creator_return_scene = return_scene


func begin_fresh_creator() -> void:
	creator_edit_level = null
	creator_loaded_level_id = ""
	creator_return_scene = ""


func consume_creator_edit_level() -> LevelConfig:
	var level := creator_edit_level
	creator_edit_level = null
	return level


func finish_creator_session() -> String:
	var path := creator_return_scene
	creator_edit_level = null
	creator_loaded_level_id = ""
	creator_return_scene = ""
	return path


func start_playtest(level: LevelConfig, baseline_signature: String = "") -> void:
	playtest_mode = true
	playtest_passed = false
	playtest_level_draft = level.duplicate(true) as LevelConfig
	playtest_baseline_signature = baseline_signature
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


func consume_playtest_baseline() -> String:
	var signature := playtest_baseline_signature
	playtest_baseline_signature = ""
	return signature


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


func record_level_stats(level_id: String, moves: int, time_ms: int) -> void:
	if level_id.strip_edges().is_empty():
		return
	var changed := false
	if moves > 0:
		var previous_moves := int(level_best_moves.get(level_id, 0))
		if previous_moves <= 0 or moves < previous_moves:
			level_best_moves[level_id] = moves
			changed = true
	if time_ms > 0:
		var previous_time := int(level_best_time_ms.get(level_id, 0))
		if previous_time <= 0 or time_ms < previous_time:
			level_best_time_ms[level_id] = time_ms
			changed = true
	if changed:
		_save_progress()


func get_level_best_moves(level_id: String) -> int:
	return int(level_best_moves.get(level_id, 0))


func get_level_best_time_ms(level_id: String) -> int:
	return int(level_best_time_ms.get(level_id, 0))


func format_play_time(time_ms: int) -> String:
	var total_sec := maxi(time_ms, 0) / 1000
	var minutes := total_sec / 60
	var seconds := total_sec % 60
	return "%d:%02d" % [minutes, seconds]


func reset_progress() -> void:
	## Clears stars / unlocks. Keeps tutorials, language, and develop-mode prefs.
	level_stars.clear()
	level_perfect.clear()
	level_best_moves.clear()
	level_best_time_ms.clear()
	daily_completed.clear()
	daily_streak_current = 0
	daily_streak_best = 0
	daily_streak_last_date = ""
	current_dimension_index = 0
	selected_level = null
	clear_level_playlist()
	_save_progress()
	_refresh_reminder()


func reset_tutorials() -> void:
	## Replay coach walkthroughs. Keeps stars and unlocks.
	seen_tutorials.clear()
	_save_progress()


func has_seen_tutorial(tutorial_id: String) -> bool:
	return bool(seen_tutorials.get(tutorial_id, false))


func has_seen_heart_tip() -> bool:
	return heart_tip_seen


func mark_heart_tip_seen() -> void:
	if heart_tip_seen:
		return
	heart_tip_seen = true
	_save_progress()


func mark_tutorial_seen(tutorial_id: String) -> void:
	if tutorial_id.strip_edges().is_empty():
		return
	if bool(seen_tutorials.get(tutorial_id, false)):
		return
	seen_tutorials[tutorial_id] = true
	_save_progress()


func is_level_unlocked(level: LevelConfig) -> bool:
	if develop_mode:
		return level != null
	if level == null:
		return false
	## Device drafts only. has_project_level is true for every official .tres, and
	## used to reload the whole library on each call — that is not an unlock gate.
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
	if level_index < 0 or level_index >= section_levels.size():
		return false
	## Already-earned stars stay reachable after a reshuffle.
	if get_level_stars(level.level_id) > 0:
		return true
	if level_index <= 0:
		return true
	## Sequential unlock along the new order.
	if get_level_stars(section_levels[level_index - 1].level_id) > 0:
		return true
	## Migration: if the player already has stars later in this dimension,
	## open every earlier level so they can keep playing the new order.
	var furthest := -1
	for i in section_levels.size():
		if get_level_stars(section_levels[i].level_id) > 0:
			furthest = i
	return furthest >= 0 and level_index <= furthest


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


func set_sfx_enabled(enabled: bool) -> void:
	sfx_enabled = enabled
	_save_settings()


func set_daily_reminders(enabled: bool) -> void:
	daily_reminders = enabled
	_save_settings()
	## Turning the toggle on is the player's ask, so the dialog may show again.
	if enabled and Reminders.available() and not Reminders.has_permission():
		Reminders.request_permission()
	_refresh_reminder()


func set_reminder_time(hour: int, minute: int) -> void:
	reminder_hour = Reminders.clamp_hour(hour)
	reminder_minute = Reminders.snap_minute(minute)
	_save_settings()
	_refresh_reminder()


func test_daily_reminder() -> void:
	if not Reminders.allows_test(OS.is_debug_build(), develop_mode):
		return
	if not Reminders.available() or Reminders.has_permission():
		Reminders.schedule_test()
		return
	_reminder_test_pending = true
	Reminders.request_permission()


## A notification tap opens Daily after the splash has left. During the splash
## the flag stays set so the menu can consume it.
func maybe_open_daily_from_reminder() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var current := tree.current_scene
	if current == null:
		return
	var path := str(current.scene_file_path)
	if path.ends_with("veil_splash.tscn"):
		return
	if not Reminders.consume_open_daily():
		return
	if path == DAILY_PUZZLES_SCENE:
		return
	change_scene(DAILY_PUZZLES_SCENE)



func _gated_develop_mode(stored: bool) -> bool:
	## Release / non-debug builds ignore a stale true in user://settings.cfg.
	return stored and OS.is_debug_build()


func set_develop_mode(enabled: bool) -> void:
	## Release builds can never turn this on, even if settings.cfg says so.
	develop_mode = enabled and OS.is_debug_build()
	_save_settings()
	## Developer mode is what decides whether device drafts are part of the
	## level list. Rebuild that list once here, not on every map visit.
	if CustomLevelStore != null and CustomLevelStore.has_method("invalidate_user_levels"):
		CustomLevelStore.invalidate_user_levels()
	if LevelCatalog != null and LevelCatalog.has_method("refresh_runtime_levels"):
		LevelCatalog.refresh_runtime_levels()


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
	if persist:
		_refresh_reminder()


func _normalize_locale(locale_code: String) -> String:
	for entry in AVAILABLE_LOCALES:
		if str(entry.code) == locale_code:
			return locale_code
	return "en"


func _load_settings() -> void:
	var config := ConfigFile.new()
	## Prefer unified settings; fall back to legacy develop-mode file.
	if config.load(SETTINGS_PATH) == OK:
		develop_mode = _gated_develop_mode(bool(config.get_value("dev", "develop_mode", false)))
		locale = _normalize_locale(str(config.get_value("i18n", "locale", "en")))
		sfx_enabled = bool(config.get_value("audio", "sfx_enabled", true))
		_load_reminder_settings(config)
		return
	if config.load(DEV_SETTINGS_PATH) == OK:
		develop_mode = _gated_develop_mode(bool(config.get_value("dev", "develop_mode", false)))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("dev", "develop_mode", develop_mode if OS.is_debug_build() else false)
	config.set_value("i18n", "locale", locale)
	config.set_value("audio", "sfx_enabled", sfx_enabled)
	config.set_value("notifications", "daily_reminders", daily_reminders)
	config.set_value("notifications", "reminder_hour", reminder_hour)
	config.set_value("notifications", "reminder_minute", reminder_minute)
	config.set_value("notifications", "permission_asked", _reminder_permission_asked)
	var err := config.save(SETTINGS_PATH)
	if err != OK:
		push_warning("Failed to save settings.cfg: %s" % error_string(err))


func _load_progress() -> void:
	level_stars.clear()
	level_perfect.clear()
	level_best_moves.clear()
	level_best_time_ms.clear()
	daily_completed.clear()
	daily_streak_current = 0
	daily_streak_best = 0
	daily_streak_last_date = ""
	current_dimension_index = 0
	seen_tutorials.clear()
	heart_tip_seen = false
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
	var moves_raw: Variant = data.get("level_best_moves", {})
	if typeof(moves_raw) == TYPE_DICTIONARY:
		for key in (moves_raw as Dictionary).keys():
			level_best_moves[str(key)] = maxi(int(moves_raw[key]), 0)
	var time_raw: Variant = data.get("level_best_time_ms", {})
	if typeof(time_raw) == TYPE_DICTIONARY:
		for key in (time_raw as Dictionary).keys():
			level_best_time_ms[str(key)] = maxi(int(time_raw[key]), 0)
	var daily_raw: Variant = data.get("daily_completed", {})
	if typeof(daily_raw) == TYPE_DICTIONARY:
		for day in (daily_raw as Dictionary).keys():
			var slots_raw: Variant = daily_raw[day]
			if typeof(slots_raw) != TYPE_DICTIONARY:
				continue
			var entry := {}
			for slot in (slots_raw as Dictionary).keys():
				entry[str(slot)] = clampi(int(slots_raw[slot]), 0, 3)
			daily_completed[str(day)] = entry
	daily_streak_current = maxi(0, int(data.get("daily_streak_current", 0)))
	daily_streak_best = maxi(daily_streak_current, int(data.get("daily_streak_best", 0)))
	daily_streak_last_date = str(data.get("daily_streak_last_date", ""))
	current_dimension_index = _migrate_dimension_index(int(data.get("current_dimension_index", 0)))
	var tutorials_raw: Variant = data.get("seen_tutorials", {})
	seen_tutorials.clear()
	if typeof(tutorials_raw) == TYPE_DICTIONARY:
		for key in (tutorials_raw as Dictionary).keys():
			if bool(tutorials_raw[key]):
				seen_tutorials[str(key)] = true
	heart_tip_seen = bool(data.get("heart_tip_seen", false))


func _save_progress() -> void:
	var payload := {
		"level_stars": level_stars.duplicate(),
		"level_perfect": level_perfect.duplicate(),
		"level_best_moves": level_best_moves.duplicate(),
		"level_best_time_ms": level_best_time_ms.duplicate(),
		"current_dimension_index": current_dimension_index,
		"seen_tutorials": seen_tutorials.duplicate(),
		"heart_tip_seen": heart_tip_seen,
		"daily_completed": daily_completed.duplicate(true),
		"daily_streak_current": daily_streak_current,
		"daily_streak_best": daily_streak_best,
		"daily_streak_last_date": daily_streak_last_date,
	}
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open progress.json for write: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(payload))
	file.flush()
	file.close()


func _load_reminder_settings(config: ConfigFile) -> void:
	daily_reminders = bool(config.get_value("notifications", "daily_reminders", true))
	reminder_hour = Reminders.clamp_hour(int(config.get_value("notifications", "reminder_hour", 12)))
	reminder_minute = Reminders.snap_minute(int(config.get_value("notifications", "reminder_minute", 0)))
	_reminder_permission_asked = bool(config.get_value("notifications", "permission_asked", false))


func _connect_reminder_signal() -> void:
	if not Reminders.available():
		return
	var plugin := Reminders.singleton()
	if plugin == null or not plugin.has_signal("permission_result"):
		return
	if not plugin.permission_result.is_connected(_on_reminder_permission):
		plugin.permission_result.connect(_on_reminder_permission)


func _on_reminder_permission(granted: bool) -> void:
	_reminder_permission_asked = true
	_save_settings()
	if _reminder_test_pending:
		_reminder_test_pending = false
		if granted:
			Reminders.schedule_test()
	_refresh_reminder()


func _maybe_ask_reminder_permission() -> void:
	var present := Reminders.available()
	var granted := present and Reminders.has_permission()
	var streak := get_display_streak()
	if present and granted and daily_reminders and streak > 0 and not _reminder_permission_asked:
		_reminder_permission_asked = true
		_save_settings()
		return
	if not Reminders.should_request_permission(
		daily_reminders,
		streak,
		_reminder_permission_asked,
		present,
		granted
	):
		return
	_reminder_permission_asked = true
	_save_settings()
	Reminders.request_permission()


func _refresh_reminder() -> void:
	Reminders.sync(
		int(Time.get_unix_time_from_system()),
		Reminders.local_bias_minutes(),
		daily_completed,
		daily_reminders,
		reminder_hour,
		reminder_minute,
		daily_streak_last_date,
		daily_streak_current
	)

