extends Node

## Device-local drafts (phone / exported builds).
const USER_LEVELS_DIR := "user://custom_levels/"
## Official project levels — written when running from the editor on desktop.
const PROJECT_LEVELS_DIR := "res://resources/levels/"
const REGISTRY_PATH := "res://scritps/LevelRegistry.gd"


func ensure_directory() -> void:
	DirAccess.make_dir_recursive_absolute(USER_LEVELS_DIR)


func saves_to_project() -> bool:
	## Only the editor session can write into the repo. Phone drafts stay on-device.
	return OS.has_feature("editor")


func has_level(level_id: String) -> bool:
	## True for on-device drafts only (used to unlock creator drafts freely).
	if level_id.strip_edges().is_empty():
		return false
	return ResourceLoader.exists(_user_level_path(level_id))


func has_project_level(level_id: String) -> bool:
	if level_id.strip_edges().is_empty():
		return false
	return ResourceLoader.exists(_project_level_path(level_id))


func save_level(level: LevelConfig) -> Error:
	if level == null or level.level_id.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	if level.sort_index <= 0:
		level.sort_index = int(Time.get_unix_time_from_system())
	if saves_to_project():
		return _save_project_level(level)
	ensure_directory()
	return ResourceSaver.save(level, _user_level_path(level.level_id))


func load_level(level_id: String) -> LevelConfig:
	var project_path := _project_level_path(level_id)
	if ResourceLoader.exists(project_path):
		return ResourceLoader.load(project_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
	var user_path := _user_level_path(level_id)
	if ResourceLoader.exists(user_path):
		return ResourceLoader.load(user_path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
	return null


func list_levels() -> Array[LevelConfig]:
	## Device drafts only — project levels are owned by LevelCatalog.
	var levels: Array[LevelConfig] = []
	ensure_directory()
	var dir := DirAccess.open(USER_LEVELS_DIR)
	if dir == null:
		return levels
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var level := ResourceLoader.load(USER_LEVELS_DIR + file_name) as LevelConfig
			if level != null:
				levels.append(level)
		file_name = dir.get_next()
	dir.list_dir_end()
	levels.sort_custom(_sort_levels)
	return levels


func list_project_level_paths() -> PackedStringArray:
	## Packed registry works in Android APKs (DirAccess cannot list res:// there).
	var paths: PackedStringArray = []
	for path in LevelRegistry.LEVEL_PATHS:
		if ResourceLoader.exists(path):
			paths.append(path)
	if not paths.is_empty():
		return paths
	## Editor fallback if the registry is empty/out of date.
	return _scan_project_level_paths()


func rewrite_project_manifest() -> Error:
	var paths := _scan_project_level_paths()
	## Stable order for readable diffs; runtime order still uses sort_index.
	var sortable: Array[String] = []
	for path in paths:
		sortable.append(path)
	sortable.sort()

	var lines: PackedStringArray = [
		"extends Object",
		"class_name LevelRegistry",
		"",
		"## Auto-updated when the level creator saves into the project.",
		"## Do not hand-edit unless you know why — CustomLevelStore.rewrite_project_manifest() owns this file.",
		"const LEVEL_PATHS: PackedStringArray = [",
	]
	for path in sortable:
		lines.append("\t\"%s\"," % path)
	lines.append("]")
	lines.append("")

	var file := FileAccess.open(REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	return OK


func delete_level(level_id: String) -> Error:
	if saves_to_project():
		var project_path := _project_level_path(level_id)
		var abs_path := ProjectSettings.globalize_path(project_path)
		if FileAccess.file_exists(abs_path):
			var err := DirAccess.remove_absolute(abs_path)
			if err == OK:
				rewrite_project_manifest()
				if LevelCatalog != null:
					LevelCatalog.reload_levels()
			return err
	var user_path := _user_level_path(level_id)
	if not FileAccess.file_exists(user_path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(user_path)


func _save_project_level(level: LevelConfig) -> Error:
	var path := _project_level_path(level.level_id)
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var error := ResourceSaver.save(level, path)
	if error != OK:
		return error
	rewrite_project_manifest()
	if LevelCatalog != null:
		LevelCatalog.reload_levels()
	return OK


func _scan_project_level_paths() -> PackedStringArray:
	var paths: PackedStringArray = []
	var listed := ResourceLoader.list_directory(PROJECT_LEVELS_DIR)
	if not listed.is_empty():
		for file_name in listed:
			if str(file_name).ends_with(".tres"):
				paths.append(PROJECT_LEVELS_DIR + str(file_name))
		return paths
	var dir := DirAccess.open(PROJECT_LEVELS_DIR)
	if dir == null:
		return paths
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			paths.append(PROJECT_LEVELS_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return paths


func _sort_levels(a: LevelConfig, b: LevelConfig) -> bool:
	if a.sort_index == b.sort_index:
		return a.level_id < b.level_id
	return a.sort_index < b.sort_index


func _project_level_path(level_id: String) -> String:
	return PROJECT_LEVELS_DIR + _sanitize_id(level_id) + ".tres"


func _user_level_path(level_id: String) -> String:
	return USER_LEVELS_DIR + _sanitize_id(level_id) + ".tres"


func _sanitize_id(level_id: String) -> String:
	var cleaned := level_id.strip_edges()
	cleaned = cleaned.replace("/", "_").replace("\\", "_").replace("..", "_")
	return cleaned
