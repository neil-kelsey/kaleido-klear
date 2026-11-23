extends Object

## Shared placement map for the 8×(30+30) campaign reshuffle.
const PATH := "res://scritps/tools/campaign_layout.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_data = JSON.parse_string(f.get_as_text())
	return _data


static func placement(level_id: String) -> Dictionary:
	var levels: Dictionary = data().get("levels", {})
	return levels.get(level_id, {}) as Dictionary


static func matches(level: LevelConfig) -> String:
	if level == null:
		return "level is null"
	var want: Dictionary = placement(level.level_id)
	if want.is_empty():
		return "not in campaign_layout.json"
	if int(level.section_index) != int(want.section_index):
		return "section_index %d != %d" % [level.section_index, int(want.section_index)]
	if level.group_title_key != str(want.group_title_key):
		return "group %s != %s" % [level.group_title_key, str(want.group_title_key)]
	if int(level.sort_index) != int(want.sort_index):
		return "sort_index %d != %d" % [level.sort_index, int(want.sort_index)]
	if int(level.difficulty_tier) != int(want.tier):
		return "tier %d != %d (ratings must not change)" % [level.difficulty_tier, int(want.tier)]
	return ""
