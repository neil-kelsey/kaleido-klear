extends Object
class_name DailyCatalog

## Authored daily levels use LevelConfig.daily_date (YYYY-MM-DD).
## Level creator section id. Must not be -1 — OptionButton treats -1 as "auto id".
const SECTION_DAILY := 100


static func today_key() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [int(d.year), int(d.month), int(d.day)]


static func format_today_date() -> String:
	return format_date_key(today_key())


static func format_date_key(date_key: String) -> String:
	var parts := date_key.split("-")
	if parts.size() != 3:
		return date_key
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	var month_key := "UI_MONTH_%d" % month
	var month_name := TranslationServer.translate(month_key)
	if month_name == month_key:
		month_name = _fallback_month_name(month)
	return "%d %s %d" % [day, month_name, year]


static func get_todays_levels() -> Array[LevelConfig]:
	return get_levels_for_date(today_key())


static func get_levels_for_date(date_key: String) -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	var key := date_key.strip_edges()
	if key.is_empty():
		return levels

	for path in CustomLevelStore.list_project_level_paths():
		var level := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
		if level == null:
			continue
		if level.daily_date.strip_edges() != key:
			continue
		levels.append(level)

	## Device drafts with a daily date (phone creator) also count for that day.
	for level in CustomLevelStore.list_levels():
		if level == null:
			continue
		if level.daily_date.strip_edges() != key:
			continue
		var already := false
		for existing in levels:
			if existing.level_id == level.level_id:
				already = true
				break
		if not already:
			levels.append(level)

	levels.sort_custom(func(a: LevelConfig, b: LevelConfig) -> bool:
		if a.sort_index == b.sort_index:
			return a.level_id < b.level_id
		return a.sort_index < b.sort_index
	)
	return levels


static func is_level_unlocked(levels: Array[LevelConfig], level: LevelConfig) -> bool:
	if level == null or levels.is_empty():
		return false
	if GameSession.develop_mode:
		return true
	for i in levels.size():
		if levels[i].level_id != level.level_id:
			continue
		if i == 0:
			return true
		return GameSession.get_level_stars(levels[i - 1].level_id) > 0
	return false


static func is_daily_level(level: LevelConfig) -> bool:
	return level != null and not level.daily_date.strip_edges().is_empty()


static func _fallback_month_name(month: int) -> String:
	var names: PackedStringArray = [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December",
	]
	if month < 1 or month > 12:
		return ""
	return names[month - 1]
