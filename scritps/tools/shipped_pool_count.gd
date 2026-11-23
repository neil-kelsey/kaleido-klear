extends SceneTree

## Prints shipped (LevelRegistry) campaign / daily-pool counts.
##   godot --headless --path . -s res://scritps/tools/shipped_pool_count.gd
##   godot --headless --main-pack <exported.pck> -s res://scritps/tools/shipped_pool_count.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog = root.get_node("LevelCatalog")
	var store = root.get_node("CustomLevelStore")
	var DC = load("res://scritps/DailyCatalog.gd")
	catalog.reload_levels_as_exported()
	var packaged: PackedStringArray = store.list_packaged_level_paths()
	print("PACKAGED_REGISTRY_PATHS=", packaged.size())
	print("EDITOR_FEATURE=", OS.has_feature("editor"))
	var campaign := 0
	var tutorial := 0
	for i in catalog.get_dimension_count():
		var levels: Array = catalog.get_project_section_levels(i)
		var title: String = str(catalog.get_dimension_title(i))
		var groups: Dictionary = {}
		for lv in levels:
			var level: LevelConfig = lv as LevelConfig
			var key := level.group_title_key.strip_edges()
			if key.is_empty():
				key = "(ungrouped)"
			if not groups.has(key):
				groups[key] = 0
			groups[key] = int(groups[key]) + 1
		if catalog.is_tutorial_dimension(i):
			tutorial = levels.size()
			print("TUTORIAL count=%d groups=%s" % [tutorial, groups])
		else:
			campaign += levels.size()
			print("CHAPTER dim=%d title=%s count=%d groups=%s" % [i + 1, title, levels.size(), groups])
	print("CAMPAIGN_TOTAL=", campaign)
	print("TUTORIAL_TOTAL=", tutorial)
	DC.invalidate_cache()
	var t1: int = DC.get_pool(1).size()
	var t2: int = DC.get_pool(2).size()
	var t3: int = DC.get_pool(3).size()
	var t4: int = DC.get_pool(4).size()
	print("DAILY_POOL easy=%d medium=%d hard=%d very_hard=%d easy_medium=%d" % [t1, t2, t3, t4, t1 + t2])
	var rc := 0 if (t1 + t2) >= 365 and campaign == 480 else 1
	print("GO_LIVE_EM_OK=", (t1 + t2) >= 365)
	quit(rc)
