extends SceneTree

## Headless checks for Settings > Reset progress / Reset tutorials. Run:
##   godot --headless --path . -s res://scritps/tools/reset_progress_checks.gd
## After both resets the campaign must look like a fresh install: only the
## first level of each open dimension is unlocked, no stars, no tutorials seen.
## Leftover user://custom_levels drafts of shipped levels (phone edits from
## developer mode) must not unlock anything. Restores user:// files afterwards.

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _backup(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return ""


func _restore(path: String, text: String) -> void:
	if text.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _unlocked_indices(gs: Node, levels: Array) -> Array:
	var out: Array = []
	for i in levels.size():
		if gs.is_level_unlocked(levels[i]):
			out.append(i)
	return out


func _process(_delta: float) -> bool:
	var gs: Node = root.get_node("GameSession")
	var lc: Node = root.get_node("LevelCatalog")
	var cls: Node = root.get_node("CustomLevelStore")
	var progress_backup := _backup(gs.PROGRESS_PATH)
	var settings_backup := _backup(gs.SETTINGS_PATH)
	var saved_develop: bool = gs.develop_mode
	gs.develop_mode = false
	lc.reload_levels_as_exported()

	var dim0: Array = lc.get_section_levels(0)
	_check(dim0.size() >= 30, "dimension 1 has its campaign levels (%d)" % dim0.size())

	# --- play a bit: stars scattered through dimension 1, tutorials, daily ---
	for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 14, 15, 16, 20, 25, 26, 29]:
		if i < dim0.size():
			gs.record_level_stars(dim0[i], 3, true)
	gs.mark_tutorial_seen("basic_training_1")
	gs.mark_heart_tip_seen()
	gs.record_daily_completion("daily", 3)
	_check(gs.get_level_stars(dim0[0].level_id) == 3, "stars recorded before reset")
	_check(gs.has_seen_tutorial("basic_training_1"), "tutorial seen before reset")

	# --- leftover phone drafts of shipped levels (Neil's scattered pattern) ---
	cls.ensure_directory()
	var draft_paths: Array = []
	for i in [2, 5, 14, 15, 16, 20, 25, 26, 29, 33]:
		if i >= dim0.size():
			continue
		var id: String = dim0[i].level_id
		var path: String = cls.USER_LEVELS_DIR + id + ".tres"
		if FileAccess.file_exists(path):
			continue
		var err := ResourceSaver.save(dim0[i].duplicate(true), path)
		if err == OK:
			draft_paths.append(path)
	_check(not draft_paths.is_empty(), "wrote %d stray draft files" % draft_paths.size())

	# --- reset both, as Settings does ---
	gs.reset_progress()
	gs.reset_tutorials()

	var expected := [0]
	_check(_unlocked_indices(gs, dim0) == expected, "dimension 1: only level 1 unlocked after reset (got %s)" % str(_unlocked_indices(gs, dim0)))
	for path in draft_paths:
		var id: String = (path as String).get_file().get_basename()
		_check(not cls.has_level(id), "stray draft %s is not a draft outside developer mode" % id)
	_check(cls.user_draft_ids().is_empty(), "no device drafts merged outside developer mode")

	var any_stars := false
	for level in lc.get_all_levels():
		if gs.get_level_stars(level.level_id) > 0 or gs.level_perfect.has(level.level_id):
			any_stars = true
	_check(not any_stars, "no stars or perfect marks anywhere after reset")

	for section_index in lc.SECTIONS.size():
		var levels: Array = lc.get_section_levels(section_index)
		if levels.is_empty():
			continue
		var section: Dictionary = lc.SECTIONS[section_index]
		var should_open: bool = section_index == 0 or bool(section.get("starts_unlocked", false))
		_check(lc.is_dimension_unlocked(section_index) == should_open, "dimension %d open=%s after reset" % [section_index, should_open])
		var want: Array = [0] if should_open else []
		_check(_unlocked_indices(gs, levels) == want, "dimension %d unlocked levels %s" % [section_index, str(want)])

	_check(not gs.has_seen_tutorial("basic_training_1") and gs.seen_tutorials.is_empty(), "tutorials cleared")
	_check(not gs.has_seen_heart_tip(), "heart tip cleared by reset tutorials")
	_check(gs.daily_completed.is_empty() and gs.daily_streak_current == 0 and gs.daily_streak_best == 0, "daily completions and streak cleared")
	_check(gs.current_dimension_index == 0 and gs.selected_level == null, "map position back to start")

	# --- the reset is on disk, not just in memory ---
	gs._load_progress()
	_check(_unlocked_indices(gs, dim0) == expected, "after reload: still only level 1 unlocked")
	_check(gs.level_stars.is_empty() and gs.seen_tutorials.is_empty() and not gs.heart_tip_seen, "after reload: no stars, no tutorials")

	# --- normal progression still works after reset ---
	gs.record_level_stars(dim0[0], 1)
	_check(_unlocked_indices(gs, dim0) == [0, 1], "clearing level 1 opens level 2 only")

	# --- cleanup ---
	for path in draft_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	cls.invalidate_user_levels()
	gs.develop_mode = saved_develop
	_restore(gs.PROGRESS_PATH, progress_backup)
	_restore(gs.SETTINGS_PATH, settings_backup)
	print("reset_progress_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true
