extends RefCounted

## When to ring the daily-puzzle streak reminder, and the Android plugin bridge.
## Streak days stay UTC, matching DailyCatalog.today_key(). The clock time is
## the next local reminder time (default 12:00). Desktop builds have no
## singleton, so every call that would touch Android is a no-op.
##
## Time.get_time_zone_from_system().bias is minutes east of UTC (Tokyo +540,
## US Pacific daylight −420). Local time is UTC plus that bias. A daylight-saving
## change between now and the chosen time can move the alarm by about an hour.

const PLUGIN := "StreakReminder"
const BODY_KEYS: Array[String] = [
	"UI_REMINDER_BODY_1",
	"UI_REMINDER_BODY_2",
	"UI_REMINDER_BODY_3",
	"UI_REMINDER_BODY_4",
]
const STAR_SLOTS: Array[String] = ["daily", "easy", "medium", "hard"]


static func local_bias_minutes() -> int:
	var zone: Dictionary = Time.get_time_zone_from_system()
	return int(zone.get("bias", 0))


static func clamp_hour(hour: int) -> int:
	var wrapped := hour % 24
	if wrapped < 0:
		wrapped += 24
	return wrapped


## Nearest quarter hour. The picker only offers 00, 15, 30, and 45.
static func snap_minute(minute: int) -> int:
	var steps: Array[int] = [0, 15, 30, 45]
	var best := 0
	var best_distance := 99
	var value := clampi(minute, 0, 59)
	for step in steps:
		var distance := absi(value - step)
		if distance < best_distance:
			best_distance = distance
			best = step
	return best


## 24-hour clock, same digits in every language.
static func format_clock(hour: int, minute: int) -> String:
	return "%02d:%02d" % [clamp_hour(hour), snap_minute(minute)]


## The next local clock time, strictly after now. `bias_minutes` is minutes east of UTC.
static func next_local_clock_unix(now_unix: int, bias_minutes: int, hour: int, minute: int) -> int:
	var shifted := now_unix + bias_minutes * 60
	var clock := Time.get_datetime_dict_from_unix_time(shifted)
	var seconds_into_day := int(clock.hour) * 3600 + int(clock.minute) * 60 + int(clock.second)
	var mark := clamp_hour(hour) * 3600 + snap_minute(minute) * 60
	var target_shifted := shifted - seconds_into_day + mark
	if shifted >= target_shifted:
		target_shifted += 86400
	return target_shifted - bias_minutes * 60


## The next 12:00 local, strictly after now.
static func next_local_noon_unix(now_unix: int, bias_minutes: int) -> int:
	return next_local_clock_unix(now_unix, bias_minutes, 12, 0)


## A UTC date counts when the best of daily / easy / medium / hard is at least 1.
static func day_counts(completed: Dictionary, date: String) -> bool:
	var entry: Variant = completed.get(date, {})
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var best := 0
	for slot in STAR_SLOTS:
		best = maxi(best, int((entry as Dictionary).get(slot, 0)))
	return best > 0


## Same walk as the Java fallback: an open today keeps yesterday's run.
static func current_streak(today: String, completed: Dictionary) -> int:
	var cursor := today
	if not day_counts(completed, cursor):
		cursor = _shift_date(cursor, -1)
	var run := 0
	while day_counts(completed, cursor):
		run += 1
		cursor = _shift_date(cursor, -1)
		if run > 4000:
			break
	return run


## Prefer stored streak fields when present, matching GameSession.get_display_streak.
static func display_streak(
	today: String,
	completed: Dictionary,
	last_date: String = "",
	stored_current: int = -1
) -> int:
	if stored_current >= 0 and not last_date.is_empty():
		if stored_current <= 0:
			return 0
		if last_date == today or last_date == _shift_date(today, -1):
			return stored_current
		return 0
	return current_streak(today, completed)


static func _shift_date(iso: String, days: int) -> String:
	var unix := int(Time.get_unix_time_from_datetime_string(iso + "T00:00:00"))
	return Time.get_date_string_from_unix_time(unix + days * 86400 + 3600)


static func date_from_unix(unix_time: int) -> String:
	return Time.get_date_string_from_unix_time(unix_time)


## 0 means schedule nothing. Otherwise the UTC unix time of a future local
## reminder whose UTC date is still open and still has a streak.
static func scheduled_fire_unix(
	now_unix: int,
	bias_minutes: int,
	completed: Dictionary,
	enabled: bool,
	hour: int = 12,
	minute: int = 0,
	last_date: String = "",
	stored_current: int = -1
) -> int:
	if not enabled:
		return 0
	var today := date_from_unix(now_unix)
	if display_streak(today, completed, last_date, stored_current) <= 0:
		return 0
	var candidate := next_local_clock_unix(now_unix, bias_minutes, hour, minute)
	for _step in 3:
		if fire_would_show(candidate, completed, last_date, stored_current):
			return candidate
		candidate += 86400
	return 0


static func fire_would_show(
	fire_unix: int,
	completed: Dictionary,
	last_date: String = "",
	stored_current: int = -1
) -> bool:
	var date := date_from_unix(fire_unix)
	if day_counts(completed, date):
		return false
	return display_streak(date, completed, last_date, stored_current) > 0


static func variant_index(utc_date: String) -> int:
	var sum := 0
	for i in utc_date.length():
		sum += utc_date.unicode_at(i)
	return sum % BODY_KEYS.size()


static func notification_title() -> String:
	return TranslationServer.translate("UI_REMINDER_TITLE")


static func notification_body_template(utc_date: String) -> String:
	return TranslationServer.translate(BODY_KEYS[variant_index(utc_date)])


static func should_request_permission(
	reminders_enabled: bool,
	streak: int,
	already_asked: bool,
	plugin_present: bool,
	permission_granted: bool
) -> bool:
	return reminders_enabled and streak > 0 and not already_asked and plugin_present and not permission_granted


static func allows_test(debug_build: bool, develop_mode: bool) -> bool:
	return debug_build and develop_mode


static func available() -> bool:
	return Engine.has_singleton(PLUGIN)


static func singleton() -> Object:
	if not available():
		return null
	return Engine.get_singleton(PLUGIN)


## Returns the unix time that was scheduled, or 0 when nothing is armed.
static func sync(
	now_unix: int,
	bias_minutes: int,
	completed: Dictionary,
	enabled: bool,
	hour: int = 12,
	minute: int = 0,
	last_date: String = "",
	stored_current: int = -1
) -> int:
	var fire := scheduled_fire_unix(
		now_unix, bias_minutes, completed, enabled, hour, minute, last_date, stored_current
	)
	var plugin := singleton()
	if plugin == null:
		return fire
	if fire <= 0:
		plugin.cancel()
		return 0
	var date := date_from_unix(fire)
	plugin.schedule(str(int(fire) * 1000), notification_title(), notification_body_template(date))
	return fire


static func schedule_test() -> void:
	var plugin := singleton()
	if plugin == null:
		push_warning("Streak reminder plugin is not on this build.")
		return
	plugin.scheduleInSeconds(10, notification_title(), notification_body_template(date_from_unix(int(Time.get_unix_time_from_system()))))


static func request_permission() -> void:
	var plugin := singleton()
	if plugin == null:
		return
	plugin.requestPermission()


static func has_permission() -> bool:
	var plugin := singleton()
	if plugin == null:
		return false
	return bool(plugin.hasPermission())


static func consume_open_daily() -> bool:
	var plugin := singleton()
	if plugin == null:
		return false
	return bool(plugin.consumeOpenDaily())
