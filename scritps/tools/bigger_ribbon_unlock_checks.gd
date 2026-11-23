extends SceneTree

## Verify Bigger Boards counts and that ribbon unlocks after the previous level.

func _initialize() -> void:
	var failed := 0
	var catalog = Engine.get_main_loop().root.get_node_or_null("LevelCatalog")
	if catalog == null:
		# Autoload is usually a child of root with its script name.
		for child in Engine.get_main_loop().root.get_children():
			if child.get_script() != null and str(child.get_script().resource_path).ends_with("LevelCatalog.gd"):
				catalog = child
				break
	if catalog == null:
		print("ERROR: LevelCatalog autoload missing")
		quit(1)
		return

	var section: int = int(catalog.get_tutorial_section_index())
	print("tutorial_section=", section)
	var levels = catalog.get_section_levels(section)
	var groups := {}
	for level in levels:
		var key: String = level.group_title_key.strip_edges()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(level)

	var expected := {
		"UI_GROUP_BASIC_TRAINING": 5,
		"UI_GROUP_SHIFTING_GOALS": 5,
		"UI_GROUP_COLOUR_MIX": 5,
		"UI_GROUP_BIGGER_BOARDS": 5,
	}
	for key in expected.keys():
		var got: int = groups[key].size() if groups.has(key) else 0
		var ok := got == int(expected[key])
		print("%s count=%d expected=%d %s" % [key, got, int(expected[key]), "OK" if ok else "FAIL"])
		if not ok:
			failed += 1
		if groups.has(key):
			for level in groups[key]:
				print("  %s sort=%d %dx%d moves=%d" % [
					level.level_id, level.sort_index, level.columns, level.rows, level.min_moves
				])

	var bigger: Array = groups.get("UI_GROUP_BIGGER_BOARDS", [])
	if bigger.is_empty() or bigger[-1].level_id != "test_bigger_ribbon" or bigger[-1].sort_index != 260:
		print("FAIL: ribbon is not last in Bigger Boards")
		failed += 1
	else:
		print("OK: ribbon is last in Bigger Boards (sort 260)")

	var session = Engine.get_main_loop().root.get_node_or_null("GameSession")
	if session == null:
		for child in Engine.get_main_loop().root.get_children():
			if child.get_script() != null and str(child.get_script().resource_path).ends_with("GameSession.gd"):
				session = child
				break
	if session == null:
		print("ERROR: GameSession autoload missing")
		quit(1)
		return

	session.develop_mode = false
	session.level_stars = {}
	var ribbon: LevelConfig = bigger[-1] if not bigger.is_empty() else null
	var previous: LevelConfig = bigger[-2] if bigger.size() >= 2 else null
	if ribbon == null or previous == null:
		print("FAIL: missing ribbon or previous")
		failed += 1
	else:
		var before: bool = bool(session.is_level_unlocked(ribbon))
		print("ribbon unlocked before starring %s: %s" % [previous.level_id, before])
		if before:
			print("FAIL: ribbon should be locked until the previous Bigger Boards level is starred")
			failed += 1
		session.level_stars[previous.level_id] = 1
		var after: bool = bool(session.is_level_unlocked(ribbon))
		print("ribbon unlocked after starring %s: %s" % [previous.level_id, after])
		if not after:
			print("FAIL: ribbon should unlock after starring %s" % previous.level_id)
			failed += 1
		else:
			print("OK: sequential unlock still works with the extra level")

	print("bigger_ribbon_unlock_checks failed=%d" % failed)
	quit(1 if failed else 0)
