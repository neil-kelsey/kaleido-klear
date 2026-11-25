extends SceneTree

## Headless checks for Daily Puzzles. Run:
##   godot --headless --path . -s res://scritps/tools/daily_checks.gd
## Restores user://progress.json afterwards.

var _fails := 0
var _passes := 0
var DC: Variant


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _make(id: String, tier: int, date: String = "") -> Resource:
	var l: Resource = load("res://scritps/LevelConfig.gd").new()
	l.level_id = id
	l.difficulty_tier = tier
	l.daily_date = date
	return l


func _process(_delta: float) -> bool:
	var gs: Node = root.get_node("GameSession")
	var lc: Node = root.get_node("LevelCatalog")
	## Loaded at runtime: -s scripts compile before autoload names exist.
	DC = load("res://scritps/DailyCatalog.gd")
	var backup := ""
	if FileAccess.file_exists(gs.PROGRESS_PATH):
		backup = FileAccess.get_file_as_string(gs.PROGRESS_PATH)
	var settings_backup := ""
	if FileAccess.file_exists(gs.SETTINGS_PATH):
		settings_backup = FileAccess.get_file_as_string(gs.SETTINGS_PATH)

	# --- date key ---
	var key: String = DC.today_key()
	_check(key == Time.get_date_string_from_unix_time(Time.get_unix_time_from_system()), "today_key is UTC date")
	_check(DC.date_key_for_unix(0) == "1970-01-01", "unix 0 -> 1970-01-01")
	_check(DC.date_key_for_unix(86399) == "1970-01-01" and DC.date_key_for_unix(86400) == "1970-01-02", "UTC midnight boundary")
	_check(DC.shift_date_key("2026-03-01", -1) == "2026-02-28", "shift back across month")
	_check(DC.shift_date_key("2026-12-31", 1) == "2027-01-01", "shift forward across year")
	_check(DC.shift_date_key("2028-03-01", -1) == "2028-02-29", "leap day")

	# --- deterministic selection (synthetic Easy+Medium pool) ---
	var pools := {1: [], 2: [], 3: [], 4: []}
	for i in 7:
		(pools[1] as Array).append(_make("e%d" % i, 1))
		(pools[2] as Array).append(_make("m%d" % i, 2))
		(pools[3] as Array).append(_make("h%d" % i, 3))
		(pools[4] as Array).append(_make("v%d" % i, 4))
	var a: Dictionary = DC.select_from([], pools, "2026-10-22")
	var b: Dictionary = DC.select_from([], pools, "2026-10-22")
	_check(a.size() == 1 and a.has(DC.SLOT_DAILY), "one pick per date")
	_check(a[DC.SLOT_DAILY] == b[DC.SLOT_DAILY], "same day -> same pick")
	var pick_id: String = str(a[DC.SLOT_DAILY].level_id)
	_check(pick_id.begins_with("e") or pick_id.begins_with("m"), "pick is Easy or Medium")
	_check(not pick_id.begins_with("h") and not pick_id.begins_with("v"), "Hard is never chosen")
	var differs := false
	for d in range(1, 10):
		var other: Dictionary = DC.select_from([], pools, DC.shift_date_key("2026-10-22", d))
		if other[DC.SLOT_DAILY] != a[DC.SLOT_DAILY]:
			differs = true
	_check(differs, "rotation changes across days")
	_check(DC.stable_hash("2026-10-22") == DC.stable_hash("2026-10-22") and DC.stable_hash("a") == 3826002220, "FNV-1a stable")
	var only_hard := {1: [], 2: [], 3: pools[3], 4: pools[4]}
	_check(DC.select_from([], only_hard, "2026-10-22").is_empty(), "no pick when the Easy+Medium pool is empty")
	var dated := [_make("dated_hard", 3, "2026-10-22"), _make("dated_med", 2, "2026-10-22"), _make("dated_other_day", 1, "2026-10-23")]
	var c: Dictionary = DC.select_from(dated, pools, "2026-10-22")
	_check(c[DC.SLOT_DAILY].level_id == "dated_med", "hand-dated Easy/Medium wins; dated Hard is ignored")
	# Combined pool contains only tier 1-2
	var em_pool: Array = DC.easy_medium_pool(pools)
	var only_em := true
	for lv in em_pool:
		var tier: int = int(lv.difficulty_tier)
		if tier != 1 and tier != 2:
			only_em = false
	_check(only_em and em_pool.size() == 14, "easy_medium_pool is only tier 1-2")

	# --- real catalogue (LevelRegistry path, same as an exported APK) ---
	lc.reload_levels_as_exported()
	DC.invalidate_cache()
	var real: Dictionary = DC.get_daily_set(key)
	_check(real.size() == 1 and real.has(DC.SLOT_DAILY), "real catalogue gives 1 daily today (%s)" % key)
	var today_lv: Resource = real[DC.SLOT_DAILY]
	var today_tier: int = int(today_lv.difficulty_tier)
	var ctx: Dictionary = lc.find_level_context(today_lv.level_id)
	_check(today_tier == 1 or today_tier == 2, "today's pick is Easy or Medium (tier %d)" % today_tier)
	_check(ctx.is_empty() or not lc.is_tutorial_dimension(int(ctx.section_index)), "today's pick is not a tutorial level")
	print("  today daily -> ", today_lv.level_id, " tier ", today_tier)
	_check(DC.get_daily_set(key)[DC.SLOT_DAILY] == real[DC.SLOT_DAILY], "cached repeat is stable")
	_check(DC.get_daily_level(key) == today_lv, "get_daily_level matches the set")
	print("  pool sizes: t1=%d t2=%d t3=%d t4=%d" % [DC.get_pool(1).size(), DC.get_pool(2).size(), DC.get_pool(3).size(), DC.get_pool(4).size()])
	var em: int = int(DC.get_pool(1).size()) + int(DC.get_pool(2).size())
	_check(em >= 365, "SHIPPED Easy+Medium daily pool is >= 365 (got %d, counted from LevelRegistry)" % em)
	_check(em == 369, "SHIPPED Easy+Medium daily pool is 369 (got %d)" % em)
	# Scan a year of dates: never Hard
	var hard_pick := false
	for d in range(0, 400):
		var day: String = DC.shift_date_key("2026-01-01", d)
		var sel: Dictionary = DC.get_daily_set(day)
		if sel.is_empty():
			hard_pick = true
			break
		var lv2: Resource = sel[DC.SLOT_DAILY]
		if int(lv2.difficulty_tier) >= 3:
			hard_pick = true
			break
	_check(not hard_pick, "400 consecutive dates never pick Hard or above")

	# --- streaks + migration from per-tier records ---
	gs.daily_completed = {}
	gs.daily_streak_current = 0
	gs.daily_streak_best = 0
	gs.daily_streak_last_date = ""
	_check(gs.record_daily_completion("daily", 2, "2026-10-01"), "first clear records")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_best == 1, "first clear -> streak 1")
	_check(not gs.record_daily_completion("daily", 2, "2026-10-01"), "same day same stars: no change")
	_check(not gs.record_daily_completion("daily", 1, "2026-10-01"), "worse stars: no change")
	_check(gs.record_daily_completion("daily", 3, "2026-10-01"), "better stars update")
	_check(gs.daily_streak_current == 1, "same day better stars: streak stays 1")
	_check(gs.get_daily_stars("daily", "2026-10-01") == 3, "best daily stars kept")
	gs.record_daily_completion("daily", 1, "2026-10-02")
	_check(gs.daily_streak_current == 2 and gs.daily_streak_best == 2, "next day -> 2")
	_check(gs.get_display_streak("2026-10-03") == 2, "display holds through following day")
	_check(gs.get_display_streak("2026-10-04") == 0, "display 0 after missed day")
	gs.record_daily_completion("daily", 1, "2026-10-04")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_best == 2, "gap -> restart at 1, best kept")
	gs.record_daily_completion("daily", 1, "2026-10-03")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_last_date == "2026-10-04", "older day doesn't rewind streak")
	_check(not gs.record_daily_completion("bogus", 3, "2026-10-04") and not gs.record_daily_completion("daily", 0, "2026-10-05"), "bad slot / 0 stars ignored")
	_check(gs.daily_streak_last_date == "2026-10-04", "0-star call didn't move streak")
	# Legacy per-tier day: any slot stars count, streak is not reset
	gs.daily_completed["2026-11-20"] = {"easy": 2, "medium": 3, "hard": 1}
	_check(gs.get_daily_stars("daily", "2026-11-20") == 3, "legacy easy/medium/hard migrate to the best star count")
	gs.daily_streak_current = 5
	gs.daily_streak_best = 5
	gs.daily_streak_last_date = "2026-11-20"
	_check(gs.get_display_streak("2026-11-21") == 5, "legacy completed day keeps the existing streak")
	_check(not gs.record_daily_completion("daily", 2, "2026-11-20"), "legacy day already cleared: no streak rewrite")
	_check(gs.daily_streak_current == 5 and gs.daily_streak_last_date == "2026-11-20", "streak is unchanged after reading a legacy day")

	# --- main-menu badge state (todo / done / perfect) ---
	gs.daily_completed = {}
	gs.daily_streak_current = 4
	gs.daily_streak_best = 4
	gs.daily_streak_last_date = "2026-11-24"
	_check(not gs.is_daily_done("2026-11-25") and not gs.is_daily_perfect("2026-11-25"), "today not done -> not perfect")
	_check(gs.get_display_streak("2026-11-25") == 4, "at-risk streak still shows 4")
	gs.daily_completed["2026-11-25"] = {"daily": 1}
	gs.daily_streak_last_date = "2026-11-25"
	_check(gs.is_daily_done("2026-11-25") and not gs.is_daily_perfect("2026-11-25"), "1 star -> done, not perfect")
	gs.daily_completed["2026-11-25"] = {"daily": 2}
	_check(gs.is_daily_done("2026-11-25") and not gs.is_daily_perfect("2026-11-25"), "2 stars -> done, not perfect")
	gs.daily_completed["2026-11-25"] = {"daily": 3}
	_check(gs.is_daily_done("2026-11-25") and gs.is_daily_perfect("2026-11-25"), "3 stars -> perfect")
	gs.daily_completed["2026-11-26"] = {"easy": 2, "medium": 3, "hard": 1}
	_check(gs.is_daily_done("2026-11-26") and gs.is_daily_perfect("2026-11-26"), "legacy best of 3 is perfect")
	gs.daily_completed["2026-11-27"] = {"easy": 1, "hard": 2}
	_check(gs.is_daily_done("2026-11-27") and not gs.is_daily_perfect("2026-11-27"), "legacy best of 2 is done, not perfect")
	_check(not gs.is_daily_done("2026-11-28") and not gs.is_daily_perfect("2026-11-28"), "missing day is not done")
	_check(gs.get_display_streak("2026-11-29") == 0, "display 0 with no recent streak")

	# --- daily play context / playlist ---
	var lvl: Resource = today_lv
	gs.begin_daily_play(lvl, DC.SLOT_DAILY, key)
	_check(gs.is_daily_play(lvl) and gs.get_next_level(lvl) == null, "daily playlist has no next level")
	_check(gs.get_return_scene() == gs.DAILY_PUZZLES_SCENE, "returns to daily screen")
	gs.restart_level(lvl)
	_check(gs.is_daily_play(lvl), "restart keeps daily context")
	var other: Resource = DC.get_pool(1)[0] if DC.get_pool(1)[0].level_id != lvl.level_id else DC.get_pool(2)[0]
	gs.set_level(other)
	_check(not gs.is_daily_play(lvl) and gs.active_level_playlist.is_empty(), "starting another level clears daily context")

	# --- streak reminder rules (UTC dates, local clock) ---
	var R = load("res://scritps/StreakReminder.gd")
	var open := {"2026-10-21": {"daily": 2}}
	var cleared_day := {"2026-10-22": {"daily": 2}}
	var morning: int = int(Time.get_unix_time_from_datetime_string("2026-10-22T08:00:00"))
	_check(R.date_from_unix(morning) == "2026-10-22", "morning fixture is 2026-10-22 UTC")
	var noon: int = int(R.next_local_noon_unix(morning, 0))
	_check(R.date_from_unix(noon) == "2026-10-22" and Time.get_datetime_dict_from_unix_time(noon).hour == 12, "UTC noon is 12:00 on the same date")
	var afternoon: int = noon + 3600
	var tomorrow_noon: int = noon + 86400
	_check(R.day_counts(open, "2026-10-21") and not R.day_counts(open, "2026-10-22"), "day_counts uses the daily slot")
	_check(R.day_counts({"2026-10-21": {"easy": 0, "medium": 3}}, "2026-10-21"), "legacy medium stars count")
	_check(not R.day_counts({"2026-10-21": {"daily": 0, "hard": 0}}, "2026-10-21"), "zero stars do not count")
	_check(R.current_streak("2026-10-22", open) == 1, "open today keeps yesterday's run")
	_check(R.scheduled_fire_unix(morning, 0, open, true) == noon, "morning with an open UTC day schedules local noon")
	_check(R.scheduled_fire_unix(afternoon, 0, open, true) == 0, "after local noon an open UTC day has no later noon that keeps the streak")
	_check(R.scheduled_fire_unix(morning, 0, cleared_day, true) == tomorrow_noon, "clearing today moves the reminder to the next open noon")
	_check(R.scheduled_fire_unix(morning, 0, {}, true) == 0, "a zero streak schedules nothing")
	_check(R.scheduled_fire_unix(morning, 0, open, false) == 0, "reminders off schedule nothing")
	## 2026-10-22 01:00 UTC = 10:00 JST (bias +540).
	var ten_jst: int = int(Time.get_unix_time_from_datetime_string("2026-10-22T01:00:00"))
	_check(R.date_from_unix(ten_jst) == "2026-10-22", "JST morning fixture date")
	var jst_noon: int = int(R.next_local_clock_unix(ten_jst, 540, 12, 0))
	_check(R.scheduled_fire_unix(ten_jst, 540, open, true) == jst_noon, "Tokyo morning schedules 12:00 JST")
	var fifteen: int = int(R.next_local_clock_unix(morning, 0, 15, 0))
	_check(R.scheduled_fire_unix(morning, 0, open, true, 15, 0) == fifteen, "an open morning schedules 15:00 the same UTC day")
	# Stored streak fields match GameSession.get_display_streak
	_check(R.display_streak("2026-10-22", open, "2026-10-21", 4) == 4, "stored streak is used when last_date is yesterday")
	_check(R.display_streak("2026-10-22", open, "2026-10-19", 4) == 0, "stored streak dies after a missed UTC day")
	_check(R.scheduled_fire_unix(morning, 0, open, true, 12, 0, "2026-10-19", 4) == 0, "dead stored streak schedules nothing")
	_check(R.notification_body_template("2026-10-22").find("%d") >= 0, "reminder copy keeps a streak placeholder")
	TranslationServer.set_locale("en")
	_check(R.notification_title() == "Daily puzzle", "english reminder title")
	TranslationServer.set_locale("pirate")
	_check(tr("UI_DAILY_REMINDERS") == "Noon hail", "pirate reminders label")
	_check(R.notification_title() == "Daily voyage", "pirate reminder title uses voyage")
	TranslationServer.set_locale("fr")
	_check(tr("UI_REMINDER_TIME_LABEL") == "Heure du rappel", "french reminder time label")
	TranslationServer.set_locale("en")
	_check(R.should_request_permission(true, 1, false, false, false) == false, "desktop does not ask")
	_check(R.should_request_permission(true, 1, false, true, false), "a new streak asks once")
	_check(not R.should_request_permission(true, 1, true, true, false), "a later clear does not nag")
	_check(not R.should_request_permission(true, 0, false, true, false), "no streak does not ask")
	_check(not R.should_request_permission(false, 2, false, true, false), "reminders off does not ask")
	_check(not R.should_request_permission(true, 2, false, true, true), "granted permission is not asked")
	_check(not R.available(), "this build has no android reminder plugin")
	var settings_scene := FileAccess.get_file_as_string("res://scenes/ui/settings.tscn")
	_check(settings_scene.contains("ReminderTimeButton"), "reminder time is a row")
	_check(settings_scene.contains("TimePicker.gd"), "reminder time opens the picker")
	_check(settings_scene.contains("ReminderToggle"), "daily reminders use a toggle")
	var saved_hour: int = gs.reminder_hour
	var saved_minute: int = gs.reminder_minute
	var saved_enabled: bool = gs.daily_reminders
	gs.set_reminder_time(18, 22)
	_check(gs.reminder_hour == 18 and gs.reminder_minute == 15, "reminder_minute snaps to a quarter hour")
	var saved_settings := ConfigFile.new()
	_check(saved_settings.load(gs.SETTINGS_PATH) == OK, "settings.cfg saved after set_reminder_time")
	_check(int(saved_settings.get_value("notifications", "reminder_hour", -1)) == 18, "reminder_hour is stored")
	_check(int(saved_settings.get_value("notifications", "reminder_minute", -1)) == 15, "reminder_minute is stored")
	gs.reset_progress()
	_check(gs.reminder_hour == 18 and gs.reminder_minute == 15, "reset progress keeps the reminder clock")
	gs.set_reminder_time(saved_hour, saved_minute)
	gs.set_daily_reminders(saved_enabled)
	for locale_path in ["res://locales/en.po", "res://locales/fr.po", "res://locales/pirate.po"]:
		var catalog := FileAccess.get_file_as_string(locale_path)
		_check(catalog.contains("msgid \"UI_REMINDER_TITLE\""), "%s has the reminder title" % locale_path)
		_check(catalog.contains("msgid \"UI_REMINDER_TIME_LABEL\""), "%s has the reminder time" % locale_path)

	# restore progress + settings
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.PROGRESS_PATH))
	else:
		var f := FileAccess.open(gs.PROGRESS_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	if settings_backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.SETTINGS_PATH))
	else:
		var sf := FileAccess.open(gs.SETTINGS_PATH, FileAccess.WRITE)
		sf.store_string(settings_backup)
		sf.close()
	print("daily_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true
