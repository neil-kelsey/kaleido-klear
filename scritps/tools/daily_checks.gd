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

	# --- date key ---
	var key: String = DC.today_key()
	_check(key == Time.get_date_string_from_unix_time(Time.get_unix_time_from_system()), "today_key is UTC date")
	_check(DC.date_key_for_unix(0) == "1970-01-01", "unix 0 -> 1970-01-01")
	_check(DC.date_key_for_unix(86399) == "1970-01-01" and DC.date_key_for_unix(86400) == "1970-01-02", "UTC midnight boundary")
	_check(DC.shift_date_key("2026-03-01", -1) == "2026-02-28", "shift back across month")
	_check(DC.shift_date_key("2026-12-31", 1) == "2027-01-01", "shift forward across year")
	_check(DC.shift_date_key("2028-03-01", -1) == "2028-02-29", "leap day")

	# --- deterministic selection (synthetic pools) ---
	var pools := {1: [], 2: [], 3: [], 4: []}
	for i in 7:
		(pools[1] as Array).append(_make("e%d" % i, 1))
		(pools[2] as Array).append(_make("m%d" % i, 2))
		(pools[3] as Array).append(_make("h%d" % i, 3))
	var a: Dictionary = DC.select_from([], pools, "2026-10-22")
	var b: Dictionary = DC.select_from([], pools, "2026-10-22")
	_check(a.size() == 3, "three slots filled")
	_check(a.easy == b.easy and a.medium == b.medium and a.hard == b.hard, "same day -> same picks")
	_check(str(a.easy.level_id).begins_with("e") and str(a.medium.level_id).begins_with("m") and str(a.hard.level_id).begins_with("h"), "slots map to tiers 1/2/3")
	var differs := false
	for d in range(1, 10):
		var other: Dictionary = DC.select_from([], pools, DC.shift_date_key("2026-10-22", d))
		if other.easy != a.easy:
			differs = true
	_check(differs, "rotation changes across days")
	_check(DC.stable_hash("2026-10-22") == DC.stable_hash("2026-10-22") and DC.stable_hash("a") == 3826002220, "FNV-1a stable")
	var no_hard := {1: pools[1], 2: pools[2], 3: [], 4: [_make("vh", 4)]}
	_check(DC.select_from([], no_hard, "2026-10-22").hard.level_id == "vh", "hard falls back to tier 4")
	var dated := [_make("dated_med", 2, "2026-10-22"), _make("dated_other_day", 1, "2026-10-23")]
	var c: Dictionary = DC.select_from(dated, pools, "2026-10-22")
	_check(c.medium.level_id == "dated_med" and c.easy == a.easy, "hand-dated wins its slot only")
	_check(DC.slot_for_tier(DC.effective_tier(_make("z", 0))) == "hard", "tier 0 -> extreme -> hard slot")

	# --- real catalogue ---
	var real: Dictionary = DC.get_daily_set(key)
	_check(real.size() == 3, "real catalogue gives 3 dailies today (%s)" % key)
	var ok_tiers := true
	for slot in real.keys():
		var lv: Resource = real[slot]
		var ctx: Dictionary = lc.find_level_context(lv.level_id)
		if not ctx.is_empty() and lc.is_tutorial_dimension(int(ctx.section_index)):
			ok_tiers = false
		print("  today ", slot, " -> ", lv.level_id, " tier ", lv.difficulty_tier)
	_check(ok_tiers, "no tutorial levels")
	_check(DC.get_daily_set(key).easy == real.easy, "cached repeat is stable")
	print("  pool sizes: t1=%d t2=%d t3=%d t4=%d" % [DC.get_pool(1).size(), DC.get_pool(2).size(), DC.get_pool(3).size(), DC.get_pool(4).size()])

	# --- streaks + double counting ---
	gs.daily_completed = {}
	gs.daily_streak_current = 0
	gs.daily_streak_best = 0
	gs.daily_streak_last_date = ""
	_check(gs.record_daily_completion("easy", 2, "2026-10-01"), "first clear records")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_best == 1, "first clear -> streak 1")
	_check(not gs.record_daily_completion("easy", 2, "2026-10-01"), "same slot same stars: no change")
	_check(not gs.record_daily_completion("easy", 1, "2026-10-01"), "worse stars: no change")
	gs.record_daily_completion("medium", 3, "2026-10-01")
	gs.record_daily_completion("easy", 3, "2026-10-01")
	_check(gs.daily_streak_current == 1, "same day other slots: streak stays 1")
	_check(gs.get_daily_stars("easy", "2026-10-01") == 3 and gs.get_daily_stars("medium", "2026-10-01") == 3 and gs.get_daily_stars("hard", "2026-10-01") == 0, "best per slot kept")
	gs.record_daily_completion("hard", 1, "2026-10-02")
	_check(gs.daily_streak_current == 2 and gs.daily_streak_best == 2, "next day -> 2")
	_check(gs.get_display_streak("2026-10-03") == 2, "display holds through following day")
	_check(gs.get_display_streak("2026-10-04") == 0, "display 0 after missed day")
	gs.record_daily_completion("easy", 1, "2026-10-04")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_best == 2, "gap -> restart at 1, best kept")
	gs.record_daily_completion("easy", 1, "2026-10-03")
	_check(gs.daily_streak_current == 1 and gs.daily_streak_last_date == "2026-10-04", "older day doesn't rewind streak")
	_check(not gs.record_daily_completion("bogus", 3, "2026-10-04") and not gs.record_daily_completion("easy", 0, "2026-10-05"), "bad slot / 0 stars ignored")
	_check(gs.daily_streak_last_date == "2026-10-04", "0-star call didn't move streak")

	# --- daily play context / playlist ---
	var lvl: Resource = real.easy
	gs.begin_daily_play(lvl, "easy", key)
	_check(gs.is_daily_play(lvl) and gs.get_next_level(lvl) == null, "daily playlist has no next level")
	_check(gs.get_return_scene() == gs.DAILY_PUZZLES_SCENE, "returns to daily screen")
	gs.restart_level(lvl)
	_check(gs.is_daily_play(lvl), "restart keeps daily context")
	gs.set_level(real.medium if real.medium != lvl else real.hard)
	_check(not gs.is_daily_play(lvl) and gs.active_level_playlist.is_empty(), "starting another level clears daily context")

	# restore progress
	if backup.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.PROGRESS_PATH))
	else:
		var f := FileAccess.open(gs.PROGRESS_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	print("daily_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true
