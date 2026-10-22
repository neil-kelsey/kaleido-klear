extends Object
class_name DailyCatalog

## Authored daily levels use LevelConfig.daily_date (YYYY-MM-DD).
## Level creator section id. Must not be -1 — OptionButton treats -1 as "auto id".
const SECTION_DAILY := 100


const SLOT_EASY := "easy"
const SLOT_MEDIUM := "medium"
const SLOT_HARD := "hard"
const SLOTS: PackedStringArray = ["easy", "medium", "hard"]
const SECONDS_PER_DAY := 86400

## Candidate pools, built once from LevelCatalog's startup scan (no .tres reloads).
static var _pools: Dictionary = {}
static var _dated: Array[LevelConfig] = []
static var _cache_ready := false
static var _cache_dev_mode := false


## Day key is the UTC calendar date, so everyone shares one daily.
static func today_key() -> String:
	return date_key_for_unix(int(Time.get_unix_time_from_system()))


static func date_key_for_unix(unix_time: int) -> String:
	return Time.get_date_string_from_unix_time(unix_time)


static func unix_for_date_key(date_key: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date_key + "T00:00:00"))


static func shift_date_key(date_key: String, days: int) -> String:
	return date_key_for_unix(unix_for_date_key(date_key) + days * SECONDS_PER_DAY + 3600)


static func slot_label_key(slot: String) -> String:
	match slot:
		SLOT_EASY:
			return "UI_DIFFICULTY_EASY"
		SLOT_MEDIUM:
			return "UI_DIFFICULTY_MEDIUM"
		_:
			return "UI_DIFFICULTY_HARD"


static func slot_tier(slot: String) -> int:
	match slot:
		SLOT_EASY:
			return 1
		SLOT_MEDIUM:
			return 2
		_:
			return 3


## Tier 0 (unrated) counts as extreme, like the rest of the game.
static func effective_tier(level: LevelConfig) -> int:
	if level == null:
		return 5
	var t := clampi(level.difficulty_tier, 0, 5)
	return 5 if t == 0 else t


static func slot_for_tier(tier: int) -> String:
	match tier:
		1:
			return SLOT_EASY
		2:
			return SLOT_MEDIUM
		_:
			return SLOT_HARD


static func invalidate_cache() -> void:
	_cache_ready = false
	_pools.clear()
	_dated.clear()


static func _ensure_cache() -> void:
	var dev := GameSession.develop_mode
	if _cache_ready and dev == _cache_dev_mode:
		return
	_cache_dev_mode = dev
	_pools = {1: [], 2: [], 3: [], 4: []}
	_dated.clear()
	for section_index in LevelCatalog.get_dimension_count():
		if LevelCatalog.is_tutorial_dimension(section_index):
			continue
		## Drafts may only shape the daily in develop mode.
		var levels: Array[LevelConfig] = (
			LevelCatalog.get_section_levels(section_index) if dev
			else LevelCatalog.get_project_section_levels(section_index)
		)
		for level in levels:
			if level == null or is_daily_level(level):
				continue
			var tier := effective_tier(level)
			if _pools.has(tier):
				(_pools[tier] as Array).append(level)
	for tier in _pools.keys():
		(_pools[tier] as Array).sort_custom(func(a: LevelConfig, b: LevelConfig) -> bool:
			return a.level_id < b.level_id
		)
	_dated = LevelCatalog.get_project_daily_levels()
	if dev:
		var overrides: Dictionary = CustomLevelStore._user_levels_by_id()
		var kept: Array[LevelConfig] = []
		for level in _dated:
			if not overrides.has(level.level_id) and not CustomLevelStore.is_level_deleted(level.level_id):
				kept.append(level)
		for level_id in overrides.keys():
			var draft: LevelConfig = overrides[level_id]
			if draft != null and is_daily_level(draft) and not CustomLevelStore.is_level_deleted(level_id):
				kept.append(draft)
		_dated = kept
	_cache_ready = true


static func get_pool(tier: int) -> Array:
	_ensure_cache()
	return (_pools.get(tier, []) as Array).duplicate()


## Stable 32-bit FNV-1a, so the pick never depends on engine hash changes.
static func stable_hash(text: String) -> int:
	var h := 2166136261
	for b in text.to_utf8_buffer():
		h = ((h ^ int(b)) * 16777619) & 0xFFFFFFFF
	return h


static func pick_from_pool(pool: Array, date_key: String, slot: String) -> LevelConfig:
	if pool.is_empty():
		return null
	return pool[stable_hash("kaleido-daily:%s:%s" % [date_key, slot]) % pool.size()] as LevelConfig


## Pure selection (testable): dated levels win their slot, then the seeded rotation.
static func select_from(dated: Array, pools: Dictionary, date_key: String) -> Dictionary:
	var out := {}
	var todays: Array = []
	for level in dated:
		if level != null and (level as LevelConfig).daily_date.strip_edges() == date_key:
			todays.append(level)
	todays.sort_custom(func(a: LevelConfig, b: LevelConfig) -> bool:
		if a.sort_index == b.sort_index:
			return a.level_id < b.level_id
		return a.sort_index < b.sort_index
	)
	for level in todays:
		var slot := slot_for_tier(effective_tier(level))
		if not out.has(slot):
			out[slot] = level
	for slot in SLOTS:
		if out.has(slot):
			continue
		var pool: Array = pools.get(slot_tier(slot), [])
		if pool.is_empty() and slot == SLOT_HARD:
			pool = pools.get(4, [])
		var pick := pick_from_pool(pool, date_key, slot)
		if pick != null:
			out[slot] = pick
	return out


## slot -> LevelConfig for a UTC day key.
static func get_daily_set(date_key: String) -> Dictionary:
	_ensure_cache()
	return select_from(_dated, _pools, date_key)


static func get_todays_set() -> Dictionary:
	return get_daily_set(today_key())


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


## Hand-dated levels for one day (Level Audit / tooling). Uses the cached scan.
static func get_levels_for_date(date_key: String) -> Array[LevelConfig]:
	_ensure_cache()
	var levels: Array[LevelConfig] = []
	var key := date_key.strip_edges()
	for level in _dated:
		if level.daily_date.strip_edges() == key:
			levels.append(level)
	return levels


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
