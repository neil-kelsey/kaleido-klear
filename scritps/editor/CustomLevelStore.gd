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
	return not _project_paths_for_level_id(level_id).is_empty()


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
	## Prefer the registry path that owns this id (filename may not match level_id).
	for path in _project_paths_for_level_id(level_id):
		var project_level := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
		if project_level != null:
			return project_level
	var fallback := _project_level_path(level_id)
	if ResourceLoader.exists(fallback):
		return ResourceLoader.load(fallback, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
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


func list_all_levels() -> Array[LevelConfig]:
	## Project + on-device drafts, deduped by level_id (project wins).
	var levels: Array[LevelConfig] = []
	var known_ids: Dictionary = {}
	for path in list_project_level_paths():
		var level := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
		if level == null or level.level_id.strip_edges().is_empty():
			continue
		if known_ids.has(level.level_id):
			continue
		known_ids[level.level_id] = true
		levels.append(level)
	for level in list_levels():
		if level == null or level.level_id.strip_edges().is_empty():
			continue
		if known_ids.has(level.level_id):
			continue
		known_ids[level.level_id] = true
		levels.append(level)
	levels.sort_custom(_sort_audit_levels)
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
		var paths := _project_paths_for_level_id(level_id)
		if paths.is_empty():
			var fallback := _project_level_path(level_id)
			if ResourceLoader.exists(fallback):
				paths.append(fallback)
		if paths.is_empty():
			return ERR_FILE_NOT_FOUND
		var last_err := OK
		for path in paths:
			var abs_path := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(abs_path):
				last_err = DirAccess.remove_absolute(abs_path)
				if last_err != OK:
					return last_err
		rewrite_project_manifest()
		if LevelCatalog != null:
			LevelCatalog.reload_levels()
		return last_err
	var user_path := _user_level_path(level_id)
	if not FileAccess.file_exists(user_path):
		return ERR_FILE_NOT_FOUND
	var user_err := DirAccess.remove_absolute(user_path)
	if user_err == OK and LevelCatalog != null:
		LevelCatalog.reload_levels()
	return user_err


func _save_project_level(level: LevelConfig) -> Error:
	## Write every on-disk copy of this id so renamed/legacy files stay in sync.
	var paths := _project_paths_for_level_id(level.level_id)
	if paths.is_empty():
		paths = PackedStringArray([_project_level_path(level.level_id)])
	for path in paths:
		var abs_path := ProjectSettings.globalize_path(path)
		DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
		var error := ResourceSaver.save(level, path)
		if error != OK:
			return error
	rewrite_project_manifest()
	if LevelCatalog != null:
		LevelCatalog.reload_levels()
	return OK


func _project_paths_for_level_id(level_id: String) -> PackedStringArray:
	var id := level_id.strip_edges()
	var paths := PackedStringArray()
	if id.is_empty():
		return paths
	for path in list_project_level_paths():
		var level := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as LevelConfig
		if level != null and level.level_id.strip_edges() == id:
			paths.append(path)
	return paths


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


func _sort_audit_levels(a: LevelConfig, b: LevelConfig) -> bool:
	var a_daily := DailyCatalog.is_daily_level(a) or a.section_index == DailyCatalog.SECTION_DAILY
	var b_daily := DailyCatalog.is_daily_level(b) or b.section_index == DailyCatalog.SECTION_DAILY
	if a_daily != b_daily:
		return not a_daily
	if a_daily:
		var date_cmp := a.daily_date.strip_edges() < b.daily_date.strip_edges()
		if a.daily_date.strip_edges() != b.daily_date.strip_edges():
			return date_cmp
	else:
		if a.section_index != b.section_index:
			return a.section_index < b.section_index
	return _sort_levels(a, b)


func _project_level_path(level_id: String) -> String:
	return PROJECT_LEVELS_DIR + _sanitize_id(level_id) + ".tres"


func _user_level_path(level_id: String) -> String:
	return USER_LEVELS_DIR + _sanitize_id(level_id) + ".tres"


func _sanitize_id(level_id: String) -> String:
	var cleaned := level_id.strip_edges()
	cleaned = cleaned.replace("/", "_").replace("\\", "_").replace("..", "_")
	return cleaned
