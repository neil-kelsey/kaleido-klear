extends Node

## Ten dimensions (sections). First three have playable levels; the rest are stubs.
## Map links form a linear path: each dimension unlocks the next.

const PRIMARY_BLUE := Color(0.0, 0.28, 0.66, 1.0)

const SECTIONS: Array[Dictionary] = [
	{
		"title_key": "UI_DIMENSION_1",
		"color": Color(0.0, 0.28, 0.66, 1.0),
		"background": "res://assets/backgrounds/section_1_fields.png",
		"parent": -1,
		"levels": [
			preload("res://resources/levels/demo_level.tres"),
			preload("res://resources/levels/demo_level_2.tres"),
		],
	},
	{
		"title_key": "UI_DIMENSION_2",
		"color": Color(0.12, 0.62, 0.48, 1.0),
		"background": "",
		"parent": 0,
		"levels": [
			preload("res://resources/levels/merge_demo_level.tres"),
			preload("res://resources/levels/merge_demo_level_2.tres"),
		],
	},
	{
		"title_key": "UI_DIMENSION_3",
		"color": Color(0.82, 0.28, 0.38, 1.0),
		"background": "",
		"parent": 1,
		"levels": [
			preload("res://resources/levels/multi_goal_demo_1.tres"),
			preload("res://resources/levels/multi_goal_demo_2.tres"),
		],
	},
	{
		"title_key": "UI_DIMENSION_4",
		"color": Color(0.72, 0.42, 0.95, 1.0),
		"background": "",
		"parent": 2,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_5",
		"color": Color(0.95, 0.55, 0.18, 1.0),
		"background": "",
		"parent": 3,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_6",
		"color": Color(0.15, 0.72, 0.85, 1.0),
		"background": "",
		"parent": 4,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_7",
		"color": Color(0.9, 0.72, 0.15, 1.0),
		"background": "",
		"parent": 5,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_8",
		"color": Color(0.95, 0.35, 0.55, 1.0),
		"background": "",
		"parent": 6,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_9",
		"color": Color(0.35, 0.55, 0.95, 1.0),
		"background": "",
		"parent": 7,
		"levels": [],
	},
	{
		"title_key": "UI_DIMENSION_10",
		"color": Color(0.45, 0.78, 0.35, 1.0),
		"background": "",
		"parent": 8,
		"levels": [],
	},
]


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


func is_dimension_unlocked(section_index: int) -> bool:
	if section_index < 0 or section_index >= SECTIONS.size():
		return false
	## Dimension progression is always enforced on the star map (even in develop mode).
	## Dimension 1 is always available; each next unlocks after the previous is cleared.
	if section_index == 0:
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


func get_section_background(section_index: int) -> String:
	if section_index < 0 or section_index >= SECTIONS.size():
		return ""
	var section: Dictionary = SECTIONS[section_index]
	return str(section.get("background", ""))


func get_level_label(level: LevelConfig) -> String:
	if level == null:
		return ""
	if not level.display_name.strip_edges().is_empty():
		return level.display_name
	if not level.level_name_key.strip_edges().is_empty():
		return tr(level.level_name_key)
	return level.level_id


func get_section_levels(section_index: int) -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	if section_index < 0 or section_index >= SECTIONS.size():
		return levels
	var section: Dictionary = SECTIONS[section_index]
	for level in section["levels"]:
		levels.append(level)
	for custom_level in _custom_levels_for_section(section_index):
		levels.append(custom_level)
	return levels


func _custom_levels_for_section(section_index: int) -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	for level in CustomLevelStore.list_levels():
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


## Linear path upward with a gentle zig-zag (not a perfectly straight line).
## Dimension 1 stays at the origin; each next step is above with a slight side sway.
func build_dimension_positions(step_distance: float = 280.0) -> Array[Vector2]:
	var count := SECTIONS.size()
	var positions: Array[Vector2] = []
	positions.resize(count)
	positions[0] = Vector2.ZERO
	## Alternating lean amounts so the path feels organic but readable.
	var sways: Array[float] = [0.0, 95.0, -70.0, 110.0, -85.0, 75.0, -100.0, 60.0, -90.0, 80.0]
	for i in range(1, count):
		var sway := sways[i] if i < sways.size() else ((1.0 if i % 2 == 0 else -1.0) * 80.0)
		positions[i] = Vector2(sway, -step_distance * float(i))
	return positions
