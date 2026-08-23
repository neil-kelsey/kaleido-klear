extends Node

## Ten dimensions (sections). Project levels come from levels_manifest.json
## (DirAccess can't list res:// inside Android APKs). Device drafts in user://
## are still merged for on-phone creator work until synced.

const PRIMARY_BLUE := Color(0.0, 0.28, 0.66, 1.0)

const SECTIONS: Array[Dictionary] = [
	## Dimension 1 is the root of the main path; Tutorial is a leading side branch.
	{
		"title_key": "UI_DIMENSION_1",
		"color": Color(0.0, 0.28, 0.66, 1.0),
		"background": "res://assets/backgrounds/section_1_fields.png",
		"parent": -1,
	},
	{
		"title_key": "UI_DIMENSION_2",
		"color": Color(0.12, 0.62, 0.48, 1.0),
		"background": "",
		"parent": 0,
	},
	{
		"title_key": "UI_DIMENSION_3",
		"color": Color(0.82, 0.28, 0.38, 1.0),
		"background": "",
		"parent": 1,
	},
	{
		"title_key": "UI_DIMENSION_4",
		"color": Color(0.72, 0.42, 0.95, 1.0),
		"background": "",
		"parent": 2,
	},
	{
		"title_key": "UI_DIMENSION_5",
		"color": Color(0.95, 0.55, 0.18, 1.0),
		"background": "",
		"parent": 3,
	},
	{
		"title_key": "UI_DIMENSION_6",
		"color": Color(0.15, 0.72, 0.85, 1.0),
		"background": "",
		"parent": 4,
	},
	{
		"title_key": "UI_DIMENSION_7",
		"color": Color(0.9, 0.72, 0.15, 1.0),
		"background": "",
		"parent": 5,
	},
	{
		"title_key": "UI_DIMENSION_8",
		"color": Color(0.95, 0.35, 0.55, 1.0),
		"background": "",
		"parent": 6,
	},
	{
		"title_key": "UI_DIMENSION_9",
		"color": Color(0.35, 0.55, 0.95, 1.0),
		"background": "",
		"parent": 7,
	},
	{
		"title_key": "UI_DIMENSION_10",
		"color": Color(0.72, 0.05, 0.08, 1.0),
		"background": "",
		"parent": 8,
	},
	## Tutorial sits at the bottom of the map; main dimensions climb upward from there.
	{
		"title_key": "UI_DIMENSION_TUTORIAL",
		"color": Color(0.45, 0.78, 0.35, 1.0),
		"background": "",
		"parent": -1,
		"starts_unlocked": true,
		"side_branch": true,
	},
]

## Cached project levels grouped by dimension index.
var _project_levels_by_section: Array = []
const EXTRA_GROUPS_PATH := "res://resources/catalog/dimension_groups.json"
## section_index (as string) -> Array of group_title_key strings created in audit.
var _extra_group_keys: Dictionary = {}


func _ready() -> void:
	_load_extra_group_keys()
	reload_levels()


func reload_levels() -> void:
	_project_levels_by_section.clear()
	_project_levels_by_section.resize(SECTIONS.size())
	for i in SECTIONS.size():
		var bucket: Array[LevelConfig] = []
		_project_levels_by_section[i] = bucket

	for path in CustomLevelStore.list_project_level_paths():
		var level := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
		if level == null:
			continue
		## Daily puzzles live in DailyCatalog, not on the dimension map.
		if (
			DailyCatalog.is_daily_level(level)
			or level.section_index == DailyCatalog.SECTION_DAILY
			or level.section_index < 0
		):
			continue
		var index := clampi(level.section_index, 0, SECTIONS.size() - 1)
		(_project_levels_by_section[index] as Array).append(level)

	for i in SECTIONS.size():
		sort_levels_by_chapter(_project_levels_by_section[i] as Array)


## Keep each chapter contiguous. Order chapters by the earliest sort_index in
## that group, then order levels inside the chapter by sort_index.
func sort_levels_by_chapter(levels: Array) -> void:
	if levels.size() < 2:
		return
	var chapter_min: Dictionary = {}
	for item in levels:
		var level := item as LevelConfig
		if level == null:
			continue
		var key := level.group_title_key.strip_edges()
		if not chapter_min.has(key) or level.sort_index < int(chapter_min[key]):
			chapter_min[key] = level.sort_index
	levels.sort_custom(func(a: Variant, b: Variant) -> bool:
		var la := a as LevelConfig
		var lb := b as LevelConfig
		if la == null or lb == null:
			return false
		var ka := la.group_title_key.strip_edges()
		var kb := lb.group_title_key.strip_edges()
		if ka != kb:
			var ma := int(chapter_min.get(ka, la.sort_index))
			var mb := int(chapter_min.get(kb, lb.sort_index))
			if ma != mb:
				return ma < mb
			return ka < kb
		if la.sort_index != lb.sort_index:
			return la.sort_index < lb.sort_index
		return la.level_id < lb.level_id
	)


func get_dimension_count() -> int:
	return SECTIONS.size()


func get_dimension_color(section_index: int) -> Color:
	if section_index < 0 or section_index >= SECTIONS.size():
		return PRIMARY_BLUE
	return SECTIONS[section_index].get("color", PRIMARY_BLUE) as Color


func get_dimension_parent(section_index: int) -> int:
	if section_index < 0 or section_index >= SECTIONS.size():
		return -1
	return int(SECTIONS[section_index].get("parent", -1))


func get_dimension_title(section_index: int) -> String:
	if section_index < 0 or section_index >= SECTIONS.size():
		return ""
	return tr(str(SECTIONS[section_index].get("title_key", "")))


func is_dimension_side_branch(section_index: int) -> bool:
	## Side branches (e.g. Tutorial) sit off the main unlock path and never own CURRENT.
	if section_index < 0 or section_index >= SECTIONS.size():
		return false
	return bool(SECTIONS[section_index].get("side_branch", false))


func is_tutorial_dimension(section_index: int) -> bool:
	if section_index < 0 or section_index >= SECTIONS.size():
		return false
	return str(SECTIONS[section_index].get("title_key", "")) == "UI_DIMENSION_TUTORIAL"


func is_first_level_of_group(level: LevelConfig) -> bool:
	if level == null:
		return false
	var group := level.group_title_key.strip_edges()
	if group.is_empty():
		return false
	var context := find_level_context(level.level_id)
	if context.is_empty():
		return false
	var section_levels := get_section_levels(int(context.section_index))
	var index := int(context.level_index)
	for i in index:
		var earlier: LevelConfig = section_levels[i]
		if earlier != null and earlier.group_title_key.strip_edges() == group:
			return false
	return true


func is_dimension_unlocked(section_index: int) -> bool:
	if section_index < 0 or section_index >= SECTIONS.size():
		return false
	## Dimension progression is always enforced on the star map (even in develop mode).
	## Dimension 1 is always available; marked test branches can start unlocked too.
	var section: Dictionary = SECTIONS[section_index]
	if section_index == 0 or bool(section.get("starts_unlocked", false)):
		return true
	return is_dimension_complete(section_index - 1)


func is_dimension_complete(section_index: int) -> bool:
	if section_index < 0 or section_index >= SECTIONS.size():
		return false
	var levels := get_section_levels(section_index)
	if levels.is_empty():
		## Stub dimensions can't be completed yet.
		return false
	for level in levels:
		if GameSession.get_level_stars(level.level_id) <= 0:
			return false
	return true


func is_dimension_perfect(section_index: int) -> bool:
	if not is_dimension_complete(section_index):
		return false
	for level in get_section_levels(section_index):
		if not GameSession.is_perfect_clear(level.level_id):
			return false
	return true


func get_section_background(section_index: int) -> String:
	if section_index < 0 or section_index >= SECTIONS.size():
		return ""
	var section: Dictionary = SECTIONS[section_index]
	return str(section.get("background", ""))


func get_level_label(level: LevelConfig) -> String:
	return get_level_label_for_locale(level, GameSession.locale)


func get_level_label_for_locale(level: LevelConfig, locale_code: String) -> String:
	if level == null:
		return ""
	var code := locale_code.strip_edges()
	if code.is_empty():
		code = GameSession.locale
	var localized := ""
	if level.locale_display_names.has(code):
		localized = str(level.locale_display_names[code]).strip_edges()
	if not localized.is_empty():
		return localized
	if not level.display_name.strip_edges().is_empty():
		return level.display_name.strip_edges()
	var key := level.level_name_key.strip_edges()
	if not key.is_empty():
		var translation := TranslationServer.get_translation_object(code)
		if translation != null:
			var msg := str(translation.get_message(key)).strip_edges()
			if not msg.is_empty() and msg != key:
				return msg
		return tr(key)
	return level.level_id


func list_group_title_keys(section_index: int) -> Array[String]:
	var seen: Dictionary = {}
	var keys: Array[String] = []
	for level in get_section_levels(section_index):
		if level == null:
			continue
		var key := level.group_title_key.strip_edges()
		if key.is_empty() or seen.has(key):
			continue
		seen[key] = true
		keys.append(key)
	for extra in extra_group_keys_for(section_index):
		if extra.is_empty() or seen.has(extra):
			continue
		seen[extra] = true
		keys.append(extra)
	keys.sort()
	return keys


func extra_group_keys_for(section_index: int) -> PackedStringArray:
	var packed: PackedStringArray = PackedStringArray()
	var raw: Variant = _extra_group_keys.get(str(section_index), [])
	if raw is PackedStringArray:
		return raw
	if raw is Array:
		for item in raw:
			packed.append(str(item).strip_edges())
	return packed


func register_extra_group_key(section_index: int, group_key: String) -> Error:
	var key := group_key.strip_edges()
	if key.is_empty() or section_index < 0 or section_index >= SECTIONS.size():
		return ERR_INVALID_PARAMETER
	var bucket: PackedStringArray = extra_group_keys_for(section_index)
	if bucket.has(key):
		return OK
	bucket.append(key)
	_extra_group_keys[str(section_index)] = bucket
	return _save_extra_group_keys()


func make_group_title_key(english_name: String) -> String:
	var slug := ""
	var upper := english_name.strip_edges().to_upper()
	for i in upper.length():
		var ch := upper.substr(i, 1)
		var code := ch.unicode_at(0)
		if (code >= 65 and code <= 90) or (code >= 48 and code <= 57):
			slug += ch
		elif ch == " " or ch == "-" or ch == "_":
			if not slug.ends_with("_"):
				slug += "_"
	slug = slug.trim_prefix("_").trim_suffix("_")
	if slug.is_empty():
		slug = "SECTION"
	var base := "UI_GROUP_%s" % slug
	var candidate := base
	var n := 2
	while _group_key_taken(candidate):
		candidate = "%s_%d" % [base, n]
		n += 1
	return candidate


func _group_key_taken(key: String) -> bool:
	for i in SECTIONS.size():
		if extra_group_keys_for(i).has(key):
			return true
		for level in get_section_levels(i):
			if level != null and level.group_title_key.strip_edges() == key:
				return true
	return false


func _load_extra_group_keys() -> void:
	_extra_group_keys.clear()
	if not FileAccess.file_exists(EXTRA_GROUPS_PATH):
		return
	var file := FileAccess.open(EXTRA_GROUPS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var groups: Variant = (parsed as Dictionary).get("groups", {})
	if groups is Dictionary:
		_extra_group_keys = (groups as Dictionary).duplicate(true)


func _save_extra_group_keys() -> Error:
	var groups := {}
	for key in _extra_group_keys.keys():
		var values: Array = []
		for item in extra_group_keys_for(int(str(key))):
			values.append(str(item))
		groups[str(key)] = values
	var payload := {"groups": groups}
	var text := JSON.stringify(payload, "\t")
	var abs_path := ProjectSettings.globalize_path(EXTRA_GROUPS_PATH)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file == null:
		file = FileAccess.open(EXTRA_GROUPS_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	file.close()
	return OK


func get_section_levels(section_index: int) -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	if section_index < 0 or section_index >= SECTIONS.size():
		return levels
	if _project_levels_by_section.is_empty():
		reload_levels()
	for level in _project_levels_by_section[section_index]:
		levels.append(level as LevelConfig)
	var known_ids: Dictionary = {}
	for level in levels:
		known_ids[level.level_id] = true
	## Append on-device creator drafts that aren't already in the project.
	for custom_level in _custom_levels_for_section(section_index):
		if not known_ids.has(custom_level.level_id):
			levels.append(custom_level)
	sort_levels_by_chapter(levels)
	return levels


func _custom_levels_for_section(section_index: int) -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	for level in CustomLevelStore.list_levels():
		if (
			DailyCatalog.is_daily_level(level)
			or level.section_index == DailyCatalog.SECTION_DAILY
			or level.section_index < 0
		):
			continue
		var index := clampi(level.section_index, 0, SECTIONS.size() - 1)
		if index == section_index:
			levels.append(level)
	return levels


func get_all_levels() -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	for section_index in SECTIONS.size():
		levels.append_array(get_section_levels(section_index))
	return levels


func find_level_context(level_id: String) -> Dictionary:
	for section_index in SECTIONS.size():
		var section_levels := get_section_levels(section_index)
		for level_index in section_levels.size():
			var level: LevelConfig = section_levels[level_index]
			if level.level_id == level_id:
				return {
					"section_index": section_index,
					"level_index": level_index,
					"level": level,
				}
	return {}


func get_next_level(current: LevelConfig) -> LevelConfig:
	if current == null:
		return null
	var context: Dictionary = find_level_context(current.level_id)
	if context.is_empty():
		return null
	var section_levels := get_section_levels(context.section_index)
	var next_index: int = context.level_index + 1
	if next_index < section_levels.size():
		return section_levels[next_index] as LevelConfig
	return null


func is_last_level_in_section(level: LevelConfig) -> bool:
	if level == null:
		return false
	var context: Dictionary = find_level_context(level.level_id)
	if context.is_empty():
		return false
	var section_levels := get_section_levels(context.section_index)
	return context.level_index == section_levels.size() - 1


func has_next_section(current: LevelConfig) -> bool:
	if current == null:
		return false
	var context: Dictionary = find_level_context(current.level_id)
	if context.is_empty():
		return false
	return context.section_index + 1 < SECTIONS.size()


func get_first_level_of_next_section(current: LevelConfig) -> LevelConfig:
	if current == null:
		return null
	var context: Dictionary = find_level_context(current.level_id)
	if context.is_empty():
		return null
	var next_section_index: int = context.section_index + 1
	if next_section_index >= SECTIONS.size():
		return null
	var section_levels := get_section_levels(next_section_index)
	if section_levels.is_empty():
		return null
	return section_levels[0] as LevelConfig


## Bottom → top map order: Tutorial first, then Dimension 1 → 10.
func get_dimension_map_order() -> Array[int]:
	var order: Array[int] = []
	## Side branches that should lead the path (Tutorial) go first.
	for i in SECTIONS.size():
		if is_dimension_side_branch(i) and int(SECTIONS[i].get("parent", -1)) < 0:
			order.append(i)
	for i in SECTIONS.size():
		if not is_dimension_side_branch(i):
			order.append(i)
	## Any remaining side branches sit just before their parent.
	for i in SECTIONS.size():
		if not is_dimension_side_branch(i):
			continue
		if order.has(i):
			continue
		var parent_i := get_dimension_parent(i)
		var insert_at := order.find(parent_i)
		if insert_at >= 0:
			order.insert(insert_at, i)
		else:
			order.append(i)
	return order


## Straight vertical path: bottom slot is Tutorial / first in map order.
func build_dimension_positions(step_distance: float = 280.0) -> Array[Vector2]:
	var count := SECTIONS.size()
	var positions: Array[Vector2] = []
	positions.resize(count)
	var order := get_dimension_map_order()
	for slot in order.size():
		var idx: int = order[slot]
		positions[idx] = Vector2(0.0, -step_distance * float(slot))
	return positions


## Level-select grid under a hub at the origin. 5 columns, rows grow +Y.
## Index 0 is top-left of the grid (under the hub).
func build_level_grid_positions(
	level_count: int,
	columns: int = 5,
	col_spacing: float = 100.0,
	row_spacing: float = 100.0,
	hub_gap: float = 160.0
) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var cols := maxi(columns, 1)
	for i in level_count:
		var col := i % cols
		var row := int(i / cols)
		var x := (float(col) - float(cols - 1) * 0.5) * col_spacing
		var y := hub_gap + float(row) * row_spacing
		positions.append(Vector2(x, y))
	return positions


## Group all levels of a chapter together, then lay out each chapter as a grid.
## headers: Array[{ "title_key": String, "position": Vector2 }]
func build_grouped_level_layout(
	levels: Array[LevelConfig],
	columns: int = 5,
	col_spacing: float = 100.0,
	row_spacing: float = 100.0,
	hub_gap: float = 160.0,
	group_gap: float = 56.0,
	header_clearance: float = 48.0
) -> Dictionary:
	var positions: Array[Vector2] = []
	var headers: Array = []
	var cols := maxi(columns, 1)
	var col := 0
	var row_y := hub_gap
	var prev_group := ""
	var first := true
	var clearance := maxf(header_clearance, 1.0)

	for level in levels:
		var group := level.group_title_key.strip_edges() if level != null else ""
		if first or group != prev_group:
			if not first:
				if col != 0:
					col = 0
					row_y += row_spacing
				row_y += group_gap
			if not group.is_empty():
				headers.append({
					"title_key": group,
					"position": Vector2(0.0, row_y - clearance),
				})
			prev_group = group
			first = false

		var x := (float(col) - float(cols - 1) * 0.5) * col_spacing
		positions.append(Vector2(x, row_y))
		col += 1
		if col >= cols:
			col = 0
			row_y += row_spacing

	return {"positions": positions, "headers": headers}