extends Node

const LEVELS_DIR := "user://custom_levels/"


func ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(LEVELS_DIR)


func has_level(level_id: String) -> bool:
	return ResourceLoader.exists(_level_path(level_id))


func save_level(level: LevelConfig) -> Error:
	if level == null or level.level_id.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	ensure_directory()
	var path := _level_path(level.level_id)
	return ResourceSaver.save(level, path)


func load_level(level_id: String) -> LevelConfig:
	var path := _level_path(level_id)
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as LevelConfig


func list_levels() -> Array[LevelConfig]:
	var levels: Array[LevelConfig] = []
	ensure_directory()
	var dir := DirAccess.open(LEVELS_DIR)
	if dir == null:
		return levels
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var level := ResourceLoader.load(LEVELS_DIR + file_name) as LevelConfig
			if level != null:
				levels.append(level)
		file_name = dir.get_next()
	dir.list_dir_end()
	levels.sort_custom(func(a: LevelConfig, b: LevelConfig) -> bool:
		return a.level_id < b.level_id
	)
	return levels


func delete_level(level_id: String) -> Error:
	var path := _level_path(level_id)
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)


func _level_path(level_id: String) -> String:
	return LEVELS_DIR + level_id + ".tres"
