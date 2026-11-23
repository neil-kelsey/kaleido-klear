extends SceneTree

## Verifies the 8×(30+30) campaign layout, unlock rules, and the Easy+Medium
## daily pool size. Run:
##   godot --headless --path . -s res://scritps/tools/campaign_layout_checks.gd

const EXPECTED_EASY_MEDIUM := 369
const MIN_EASY_MEDIUM := 365
var NEW_GROUP_KEYS := PackedStringArray([
	"UI_GROUP_TEMPEST_RELIQUARY",
	"UI_GROUP_EMBER_CACHE",
	"UI_GROUP_DUST_ORCHARD",
	"UI_GROUP_SHORE_RELICS",
	"UI_GROUP_LAST_QUAY",
])

var _fails := 0
var _passes := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _run() -> void:
	var catalog = root.get_node("LevelCatalog")
	var gs = root.get_node("GameSession")
	var store = root.get_node("CustomLevelStore")
	var registry = load("res://scritps/LevelRegistry.gd")
	var DC = load("res://scritps/DailyCatalog.gd")
	var layout_script = load("res://scritps/tools/CampaignLayout.gd")
	var data: Dictionary = layout_script.data() as Dictionary
	var layout_levels: Dictionary = data.get("levels", {})

	## Count the way an exported APK does (LevelRegistry), not an editor disk scan.
	catalog.reload_levels_as_exported()

	_check(catalog.SECTIONS.size() == 9, "8 campaign dimensions + Tutorial")
	_check(str(catalog.SECTIONS[8].get("title_key", "")) == "UI_DIMENSION_TUTORIAL", "tutorial is section 8")
	_check(bool(catalog.SECTIONS[8].get("starts_unlocked", false)), "Tutorial starts unlocked")
	_check(not bool(catalog.SECTIONS[1].get("starts_unlocked", false)), "Dewfall does not start unlocked")
	_check(str(catalog.SECTIONS[7].get("title_key", "")) == "UI_DIMENSION_10", "dimension 8 reuses The Maw title key")
	TranslationServer.set_locale("en")
	_check(catalog.get_dimension_title(7) == "The Maw", "dimension 8 displays as The Maw")
	var maw_color: Color = catalog.SECTIONS[7].get("color", Color.BLACK)
	_check(is_equal_approx(maw_color.r, 0.72) and is_equal_approx(maw_color.g, 0.05) and is_equal_approx(maw_color.b, 0.08), "dimension 8 uses The Maw red")
	_check(catalog.get_dimension_parent(7) == 6, "The Maw still follows Redshift Wastes")

	_check(catalog.get_tutorial_section_index() == 8, "tutorial section index is 8 after stubs were removed")

	# Registry must match the disk set, and every layout id must be in the registry.
	# This is the failure mode that let checks pass while shipped APKs were short.
	var packaged_set: Dictionary = {}
	for path in store.list_packaged_level_paths():
		packaged_set[str(path)] = true
	_check(packaged_set.size() == registry.LEVEL_PATHS.size(), "every LevelRegistry path exists (%d of %d)" % [packaged_set.size(), registry.LEVEL_PATHS.size()])
	var orphans: Array[String] = []
	for path in store._scan_project_level_paths():
		if not packaged_set.has(str(path)):
			orphans.append(str(path))
	_check(orphans.is_empty(), "no on-disk levels missing from LevelRegistry (orphans: %s)" % [orphans])

	for dim in range(8):
		var levels: Array = catalog.get_section_levels(dim)
		_check(levels.size() == 60, "dimension %d has 60 levels (got %d)" % [dim + 1, levels.size()])
		var groups: Array[String] = []
		for lv in levels:
			var k := (lv as LevelConfig).group_title_key.strip_edges()
			if groups.is_empty() or groups[-1] != k:
				groups.append(k)
		_check(groups.size() == 2, "dimension %d has two subsections (got %s)" % [dim + 1, groups])
		if groups.size() == 2:
			var n0 := 0
			var n1 := 0
			for lv in levels:
				if (lv as LevelConfig).group_title_key == groups[0]:
					n0 += 1
				elif (lv as LevelConfig).group_title_key == groups[1]:
					n1 += 1
			_check(n0 == 30 and n1 == 30, "dimension %d subsections are 30+30 (%d+%d)" % [dim + 1, n0, n1])
			var first: Array[LevelConfig] = catalog.get_first_subsection_levels(dim)
			_check(first.size() == 30 and first[0].group_title_key == groups[0], "first subsection helper matches")

	# Every layout id is on the map in the planned slot, ratings unchanged.
	var seen := {}
	for dim in range(8):
		for lv in catalog.get_section_levels(dim):
			var level := lv as LevelConfig
			seen[level.level_id] = true
			var err: String = layout_script.matches(level)
			_check(err == "", "%s %s" % [level.display_name if level.display_name != "" else level.level_id, err if err != "" else "placement ok"])

	for level_id in layout_levels.keys():
		_check(seen.has(str(level_id)), "layout id %s is in the shipped catalog" % level_id)

	# Dimension 1 is all core, with Scarab and Spiral Conch as its two Very Hards.
	var d1: Array = catalog.get_section_levels(0)
	var d1_core := true
	var vh: Array[String] = []
	var extremes := 0
	for lv in d1:
		var level := lv as LevelConfig
		var origin := str((layout_levels.get(level.level_id, {}) as Dictionary).get("origin", ""))
		if origin != "core":
			d1_core = false
		if level.difficulty_tier == 4:
			vh.append(level.display_name)
		if level.difficulty_tier == 5:
			extremes += 1
	_check(d1_core, "dimension 1 is 100% core")
	vh.sort()
	_check(vh == ["Scarab", "Spiral Conch"], "dimension 1 Very Hards are Scarab and Spiral Conch (got %s)" % [vh])
	_check(extremes == 0, "dimension 1 has no Extreme")

	# Tutorial and daily demo stay put.
	var tutorial: Array = catalog.get_section_levels(8)
	_check(tutorial.size() == 20, "tutorial still has 20 levels")
	for lv in tutorial:
		_check((lv as LevelConfig).section_index == 8, "tutorial level stays in section 8")
	var demo := load("res://resources/levels/multi_goal_demo_1.tres") as LevelConfig
	_check(demo != null and demo.section_index == 100 and demo.difficulty_tier == 0, "multi_goal_demo_1 stays in daily section, unrated")

	# New group keys are translated in the three shipped locales.
	for key in NEW_GROUP_KEYS:
		for locale in ["en", "fr", "pirate"]:
			TranslationServer.set_locale(locale)
			var trn := tr(key)
			_check(trn != key and not trn.is_empty(), "%s translates in %s (%s)" % [key, locale, trn])
	TranslationServer.set_locale("en")

	# Unlock + migration (stars in memory only, then restored).
	var saved_stars: Dictionary = gs.level_stars.duplicate()
	var saved_dev: bool = gs.develop_mode
	gs.develop_mode = false
	gs.level_stars.clear()

	_check(catalog.is_dimension_unlocked(0), "dimension 1 is open with no stars")
	_check(not catalog.is_dimension_unlocked(1), "dimension 2 stays locked until the first subsection of D1 is complete")
	_check(gs.is_level_unlocked(d1[0] as LevelConfig), "first D1 level is unlocked")
	_check(not gs.is_level_unlocked(d1[1] as LevelConfig), "second D1 level waits for a star on the first")

	var first30: Array[LevelConfig] = catalog.get_first_subsection_levels(0)
	for i in 29:
		gs.level_stars[first30[i].level_id] = 1
	_check(not catalog.is_dimension_unlocked(1), "29 of 30 in D1A does not unlock D2")
	gs.level_stars[first30[29].level_id] = 1
	_check(catalog.is_dimension_unlocked(1), "completing D1A (30 levels) unlocks D2")
	_check(not catalog.is_dimension_complete(0), "D1 is not fully complete after only the first subsection")

	# Existing stars later in a later dimension unlock that dimension and the prefix.
	var d6: Array = catalog.get_section_levels(5)
	gs.level_stars.clear()
	_check(not catalog.is_dimension_unlocked(5), "Glass Tempest locked with a fresh save")
	gs.level_stars[(d6[40] as LevelConfig).level_id] = 3
	_check(catalog.is_dimension_unlocked(5), "stars already in Glass Tempest unlock that dimension")
	_check(gs.is_level_unlocked(d6[40] as LevelConfig), "the already-starred later level stays reachable")
	_check(gs.is_level_unlocked(d6[0] as LevelConfig), "earlier levels in that dimension open so the new order can be played")
	_check(gs.is_level_unlocked(d6[39] as LevelConfig), "prefix up to the furthest star is unlocked")
	_check(gs.is_level_unlocked(d6[41] as LevelConfig), "the level after a starred furthest opens sequentially")
	_check(not gs.is_level_unlocked(d6[42] as LevelConfig), "levels after that stay locked until played in order")

	# Tutorial remains unlocked with no stars.
	_check(catalog.is_dimension_unlocked(8), "Tutorial stays unlocked")

	_check(gs._migrate_dimension_index(10) == 8, "saved tutorial index 10 migrates to 8")
	_check(gs._migrate_dimension_index(7) == 7, "The Maw index 7 is unchanged")
	_check(gs._migrate_dimension_index(0) == 0, "Twinkle Drift index is unchanged")
	_check(gs._migrate_dimension_index(9) == 8, "old empty-stub index 9 clamps to Tutorial")

	# Hard go-live gate: Easy+Medium daily pool from the shipped registry path.
	DC.invalidate_cache()
	var em_shipped: int = int(DC.get_pool(1).size()) + int(DC.get_pool(2).size())
	_check(em_shipped >= MIN_EASY_MEDIUM, "SHIPPED Easy+Medium daily pool is >= %d (got %d, counted from LevelRegistry)" % [MIN_EASY_MEDIUM, em_shipped])
	_check(em_shipped == EXPECTED_EASY_MEDIUM, "SHIPPED Easy+Medium daily pool is %d (got %d)" % [EXPECTED_EASY_MEDIUM, em_shipped])


	_test_stale_device_overrides(catalog, gs)

	gs.level_stars = saved_stars
	gs.develop_mode = saved_dev
	print("campaign_layout_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)


## Device drafts of shipped levels must not keep stale chapters / ratings.
func _test_stale_device_overrides(catalog, gs) -> void:
	## Headless/editor sessions have OS.has_feature("editor"), so
	## uses_dynamic_level_list() stays false. Inject the draft map the same
	## way a phone would in develop mode.
	var stale_ids := PackedStringArray([
		"custom_level_1789153906", ## Uuu -> D2 Nebula Menagerie
		"custom_level_1790075993", ## lick my wounds -> D2 Paint Nova
		"custom_level_1787544095", ## There wasn't an upstairs -> D2 Paint Nova
		"custom_level_1791805189", ## One day, this will all be yours -> D2 Paint Nova
	])
	var packed_by_id: Dictionary = {}
	var overrides: Dictionary = {}
	for level_id in stale_ids:
		var packed: LevelConfig = null
		for lv in catalog.get_project_section_levels(1):
			if (lv as LevelConfig).level_id == level_id:
				packed = lv as LevelConfig
				break
		if packed == null:
			for lv in catalog.get_all_levels():
				if (lv as LevelConfig).level_id == level_id:
					packed = lv as LevelConfig
					break
		if packed == null:
			_check(false, "stale-override fixture %s is packaged" % level_id)
			catalog.refresh_runtime_levels()
			return
		packed_by_id[level_id] = packed
		var draft := packed.duplicate(true) as LevelConfig
		draft.section_index = 0
		draft.group_title_key = "UI_GROUP_SOLAR_STACK"
		draft.sort_index = 4000
		draft.difficulty_tier = 5
		draft.difficulty_score = 999.0
		overrides[level_id] = draft
	var unique_id := "override_merge_test_draft"
	var unique := (packed_by_id[stale_ids[0]] as LevelConfig).duplicate(true) as LevelConfig
	unique.level_id = unique_id
	unique.display_name = "Override Merge Test Draft"
	unique.section_index = 0
	unique.group_title_key = "UI_GROUP_SOLAR_STACK"
	unique.sort_index = 5000
	unique.difficulty_tier = 1
	unique.daily_date = ""
	overrides[unique_id] = unique

	# Without applying device drafts, packaged D1 is unchanged.
	catalog.refresh_runtime_levels()
	var d1_off: Array = catalog.get_section_levels(0)
	_check(d1_off.size() == 60, "no injected drafts: D1 stays 60 (got %d)" % d1_off.size())
	var solar_off := 0
	for lv in d1_off:
		if (lv as LevelConfig).group_title_key == "UI_GROUP_SOLAR_STACK":
			solar_off += 1
	_check(solar_off == 0, "no injected drafts: Solar Stack does not appear")

	var first_id := stale_ids[0]
	gs.level_stars[first_id] = 3
	_check(gs.get_level_stars(first_id) == 3, "stars on a shipped id survive a stale override")

	catalog.refresh_runtime_levels_with_overrides(overrides)
	var d1_on: Array = catalog.get_section_levels(0)
	var solar_ids: Array[String] = []
	for lv in d1_on:
		var level := lv as LevelConfig
		if level.group_title_key.strip_edges() == "UI_GROUP_SOLAR_STACK":
			solar_ids.append(level.level_id)
	_check(solar_ids == [unique_id], "Solar Stack is only the unique draft (got %s)" % [solar_ids])
	_check(d1_on.size() == 61, "D1 is 60 packaged + 1 unique draft (got %d)" % d1_on.size())
	for level_id in stale_ids:
		var packed: LevelConfig = packed_by_id[level_id]
		var ctx: Dictionary = catalog.find_level_context(level_id)
		_check(not ctx.is_empty(), "%s still on the map" % packed.display_name)
		if ctx.is_empty():
			continue
		var found: LevelConfig = ctx.level
		_check(found.section_index == packed.section_index and found.group_title_key == packed.group_title_key and found.sort_index == packed.sort_index, "%s keeps packaged placement (section %d %s sort %d)" % [packed.display_name, found.section_index, found.group_title_key, found.sort_index])
		_check(found.difficulty_tier == packed.difficulty_tier and found.difficulty_score == packed.difficulty_score, "%s keeps packaged rating (tier %d)" % [packed.display_name, found.difficulty_tier])
		_check(int(ctx.section_index) == packed.section_index, "%s lives in packaged dimension %d" % [packed.display_name, packed.section_index + 1])
	_check(gs.get_level_stars(first_id) == 3, "stars still on the packaged id after the merge")

	catalog.refresh_runtime_levels()
	var d1: Array = catalog.get_section_levels(0)
	_check(d1.size() == 60, "restoring packaged catalog leaves D1 at 60 (got %d)" % d1.size())
