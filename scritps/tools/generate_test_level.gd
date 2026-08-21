extends SceneTree

## Create + verify simple-but-interesting Test levels:
## 5x5 fully filled, shapes >= 3, no full-span bars, 4 goal edges, 2 colors.
## Run:
##   Godot --headless --path <project> -s res://scritps/tools/generate_test_level.gd

const SECTION_TEST := 10
const REPORT_PATH := "res://build/level_gen_report.txt"
const _GROUP_BASIC := "UI_GROUP_BASIC_TRAINING"
## Tutorial group order by sort_index: Basic → Walls → Shifting → Colour Mix → Bigger.
## Colour Mix: 160–200 (see generate_colour_mix_levels.gd).
## Bigger Boards 2–4: 220–240 (see generate_bigger_board_levels.gd).
const _GROUP_SHIFTING := "UI_GROUP_SHIFTING_GOALS"
const _GROUP_WALLS := "UI_GROUP_WALLS"
const _GROUP_BIGGER := "UI_GROUP_BIGGER_BOARDS"
const LevelSolverScript := preload("res://scritps/tools/LevelSolver.gd")
const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")
const LevelGenRulesScript := preload("res://scritps/tools/LevelGenRules.gd")


func _initialize() -> void:
	var lines: PackedStringArray = []
	lines.append("=== Level generate / verify ===")
	var exit_code := 0
	for spec in _level_specs():
		var level: LevelConfig = spec.level
		lines.append("")
		lines.append("--- %s ---" % level.level_id)
		lines.append(
			"section=%d size=%dx%d"
			% [level.section_index, level.columns, level.rows]
		)

		var rules: Dictionary = LevelGenRulesScript.validate(level)
		lines.append(
			"rules ok=%s occupied=%s disabled=%s empty=%s"
			% [
				rules.get("ok", false),
				rules.get("occupied", 0),
				rules.get("disabled", 0),
				rules.get("empty", 0),
			]
		)
		for err in rules.get("errors", []):
			lines.append("RULE ERROR: %s" % err)
		for warn in rules.get("warnings", []):
			lines.append("RULE WARN: %s" % warn)
		if not bool(rules.get("ok", false)):
			exit_code = 1
			continue

		var result: Dictionary = LevelSolverScript.solve(level)
		var rating: Dictionary = LevelDifficultyScript.rate(
			level, int(result.get("min_moves", -1))
		)
		lines.append(
			"solvable=%s min_moves=%s states=%s"
			% [
				result.get("solvable", false),
				result.get("min_moves", -1),
				result.get("states_explored", 0),
			]
		)
		lines.append(
			"difficulty score=%s tier=%s colors=%s blocks=%s"
			% [rating.score, rating.tier, rating.colors, rating.blocks]
		)
		if not bool(result.get("solvable", false)):
			lines.append("ERROR: Level is not solvable — not saving.")
			exit_code = 1
			continue

		if spec.has("bait"):
			var bait: Dictionary = spec.bait
			var trap: Dictionary = LevelSolverScript.bait_traps(
				level,
				int(bait.block_index),
				bait.direction as Vector2i
			)
			lines.append(
				"bait trap=%s (%s)"
				% [trap.get("traps", false), trap.get("reason", "")]
			)
			if not bool(trap.get("ok", false)) or not bool(trap.get("traps", false)):
				lines.append("ERROR: Bait does not trap the player — not saving.")
				exit_code = 1
				continue

		level.verified_solvable = true
		level.min_moves = int(result.min_moves)
		level.difficulty_score = float(rating.score)
		level.difficulty_tier = int(rating.tier)

		var save_err := _save_project_level(level)
		if save_err != OK:
			lines.append("ERROR: Failed to save level, error=%s" % save_err)
			exit_code = 1
			continue

		lines.append("Saved res://resources/levels/%s.tres" % level.level_id)

	lines.append("")
	lines.append("Done (Test dimension section %d)." % SECTION_TEST)
	_finish(lines, exit_code)


func _finish(lines: PackedStringArray, code: int) -> void:
	_write_report(lines)
	for line in lines:
		print(line)
	quit(code)


func _level_specs() -> Array:
	return [
		{"level": _build_variant_a()},
		{"level": _build_variant_b()},
		{"level": _build_variant_c()},
		{"level": _build_variant_d()},
		{"level": _build_variant_e()},
		{"level": _build_walls_1()},
		{"level": _build_walls_2()},
		{"level": _build_walls_3()},
		{"level": _build_walls_4()},
		{"level": _build_walls_5()},
		{"level": _build_variant_f()},
		{"level": _build_variant_g()},
		{"level": _build_variant_h()},
		{"level": _build_variant_i()},
		{"level": _build_variant_j()},
		## Bigger Boards 1 is kept here. Levels 2–4 live in
		## generate_bigger_board_levels.gd so this script cannot recreate the
		## old bait-2/3/4 duplicates.
		_spec_bait(_build_bigger_1(), 0, Vector2i.LEFT),
	]


func _spec_bait(level: LevelConfig, bait_block: int, bait_dir: Vector2i) -> Dictionary:
	return {
		"level": level,
		"bait": {"block_index": bait_block, "direction": bait_dir},
	}


func _build_variant_a() -> LevelConfig:
	##   0 0 0 0 1
	##   2 3 3 0 1
	##   2 2 3 1 1
	##   2 4 3 5 5
	##   4 4 4 5 5
	return _make_level(
		"test_5x5_filled",
		"Test 5x5 Filled",
		10,
		_two_color_goals(),
		_GROUP_BASIC,
		[
			{
				"name": "Red Hook",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1),
				],
			},
			{
				"name": "Blue Corner",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 0), Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2),
				],
			},
			{
				"name": "Red Stair",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3),
				],
			},
			{
				"name": "Blue T",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3),
				],
			},
			{
				"name": "Red Base",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
				],
			},
			{
				"name": "Blue Square",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
				],
			},
		]
	)


func _build_variant_b() -> LevelConfig:
	## Different packing — staggered corners / center zig:
	##   0 0 1 1 1
	##   0 2 2 1 3
	##   4 2 5 5 3
	##   4 4 5 3 3
	##   4 6 6 6 6
	return _make_level(
		"test_5x5_filled_2",
		"Test 5x5 Filled 2",
		20,
		_two_color_goals(),
		_GROUP_BASIC,
		[
			{
				"name": "Red Cap",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				],
			},
			{
				"name": "Blue Top",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1),
				],
			},
			{
				"name": "Red Bend",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
				],
			},
			{
				"name": "Blue Side",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 1), Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3),
				],
			},
			{
				"name": "Red Column",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
				],
			},
			{
				"name": "Blue Center",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
				],
			},
			{
				"name": "Red Floor",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
				],
			},
		]
	)


func _build_variant_c() -> LevelConfig:
	## Three colours — red left, green top/bottom, blue right:
	##   0 0 1 1 2
	##   0 3 3 1 2
	##   4 3 5 5 2
	##   4 4 5 6 6
	##   4 7 7 7 6
	return _make_level(
		"test_5x5_three_color",
		"Test 5x5 Three Color",
		30,
		_three_color_goals(),
		_GROUP_BASIC,
		[
			{
				"name": "Red Cap",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
				],
			},
			{
				"name": "Green Top",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1),
				],
			},
			{
				"name": "Blue Column",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
				],
			},
			{
				"name": "Green Bend",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
				],
			},
			{
				"name": "Red Stair",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
				],
			},
			{
				"name": "Blue Zig",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
				],
			},
			{
				"name": "Blue Corner",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4),
				],
			},
			{
				"name": "Green Floor",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
				],
			},
		]
	)


func _build_variant_d() -> LevelConfig:
	##   0 0 0 1 1
	##   2 3 0 1 4
	##   2 3 3 4 4
	##   2 5 5 5 6
	##   7 7 7 6 6
	return _make_level(
		"test_5x5_three_color_2",
		"Test 5x5 Three Color 2",
		40,
		_three_color_goals(),
		_GROUP_BASIC,
		[
			{
				"name": "Green Hook",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
				],
			},
			{
				"name": "Blue Cap",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1),
				],
			},
			{
				"name": "Red Column",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
				],
			},
			{
				"name": "Green Bend",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2),
				],
			},
			{
				"name": "Blue Elbow",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2),
				],
			},
			{
				"name": "Green Mid",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
				],
			},
			{
				"name": "Blue Corner",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
				],
			},
			{
				"name": "Red Floor",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
				],
			},
		]
	)


func _build_variant_e() -> LevelConfig:
	##   0 1 1 1 2
	##   0 0 3 2 2
	##   4 3 3 5 5
	##   4 4 6 5 7
	##   4 6 6 7 7
	return _make_level(
		"test_5x5_three_color_3",
		"Test 5x5 Three Color 3",
		50,
		_three_color_goals(),
		_GROUP_BASIC,
		[
			{
				"name": "Red Cap",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
				],
			},
			{
				"name": "Green Top",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
				],
			},
			{
				"name": "Blue Cap",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1),
				],
			},
			{
				"name": "Green Zig",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2),
				],
			},
			{
				"name": "Red Stair",
				"color": Block.TileColor.RED,
				"cells": [
					Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
				],
			},
			{
				"name": "Blue Mid",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3),
				],
			},
			{
				"name": "Green Base",
				"color": Block.TileColor.GREEN,
				"cells": [
					Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4),
				],
			},
			{
				"name": "Blue Corner",
				"color": Block.TileColor.BLUE,
				"cells": [
					Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
				],
			},
		]
	)


func _build_variant_f() -> LevelConfig:
	## Shifting Goals 1 — top edge flips green→blue mid-clear.
	##   0 0 1 1 2
	##   0 3 3 1 2
	##   4 3 5 5 2
	##   4 4 5 6 6
	##   4 7 7 7 6
	## R×2 G×3 B×3 | L R×2 · T G×2→B×1 · R B×2 · B G×1
	return _make_shifting_level(
		"test_5x5_shifting_1",
		"Test 5x5 Shifting 1",
		110,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			]},
			{"name": "Green Top", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1),
			]},
			{"name": "Blue Column", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
			]},
			{"name": "Green Bend", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
			]},
			{"name": "Blue Zig", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
			]},
			{"name": "Blue Corner", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4),
			]},
			{"name": "Green Floor", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
			]},
		],
		{
			"left": [_phase(Block.TileColor.RED, 2)],
			"top": [_phase(Block.TileColor.GREEN, 2), _phase(Block.TileColor.BLUE, 1)],
			"right": [_phase(Block.TileColor.BLUE, 2)],
			"bottom": [_phase(Block.TileColor.GREEN, 1)],
		}
	)


func _build_variant_g() -> LevelConfig:
	##   0 0 0 1 1
	##   2 3 0 1 4
	##   2 3 3 4 4
	##   2 5 5 5 6
	##   7 7 7 6 6
	## R×2 G×3 B×3 | L R×2 · T G×1→B×1 · R B×2 · B G×2
	return _make_shifting_level(
		"test_5x5_shifting_2",
		"Test 5x5 Shifting 2",
		120,
		[
			{"name": "Green Hook", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
			]},
			{"name": "Blue Cap", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 0), Vector2i(4, 0), Vector2i(3, 1),
			]},
			{"name": "Red Column", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
			]},
			{"name": "Green Bend", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 2),
			]},
			{"name": "Blue Elbow", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 1), Vector2i(3, 2), Vector2i(4, 2),
			]},
			{"name": "Green Mid", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
			]},
			{"name": "Blue Corner", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
			{"name": "Red Floor", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
			]},
		],
		{
			"left": [_phase(Block.TileColor.RED, 2)],
			"top": [_phase(Block.TileColor.GREEN, 1), _phase(Block.TileColor.BLUE, 1)],
			"right": [_phase(Block.TileColor.BLUE, 2)],
			"bottom": [_phase(Block.TileColor.GREEN, 2)],
		}
	)


func _build_variant_h() -> LevelConfig:
	##   0 1 1 1 2
	##   0 0 3 2 2
	##   4 3 3 5 5
	##   4 4 6 5 7
	##   4 6 6 7 7
	## R×2 G×3 B×3 | L R×2 · T G×2 · R B×2→G×1 · B B×1
	return _make_shifting_level(
		"test_5x5_shifting_3",
		"Test 5x5 Shifting 3",
		130,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
			]},
			{"name": "Green Top", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0),
			]},
			{"name": "Blue Cap", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 0), Vector2i(3, 1), Vector2i(4, 1),
			]},
			{"name": "Green Zig", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
			]},
			{"name": "Blue Mid", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 2), Vector2i(4, 2), Vector2i(3, 3),
			]},
			{"name": "Green Base", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(2, 3), Vector2i(1, 4), Vector2i(2, 4),
			]},
			{"name": "Blue Corner", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
		],
		{
			"left": [_phase(Block.TileColor.RED, 2)],
			"top": [_phase(Block.TileColor.GREEN, 2)],
			"right": [_phase(Block.TileColor.BLUE, 2), _phase(Block.TileColor.GREEN, 1)],
			"bottom": [_phase(Block.TileColor.BLUE, 1)],
		}
	)


func _build_variant_i() -> LevelConfig:
	##   0 1 1 2 2
	##   0 0 1 3 2
	##   4 5 5 3 3
	##   4 4 5 6 6
	##   4 7 7 7 6
	## R×2 G×3 B×3 | L R×2 · T G×2→B×1 · R B×2 · B G×1
	return _make_shifting_level(
		"test_5x5_shifting_4",
		"Test 5x5 Shifting 4",
		140,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1),
			]},
			{"name": "Green Top", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1),
			]},
			{"name": "Blue Cap", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1),
			]},
			{"name": "Blue Side", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
			]},
			{"name": "Green Zig", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3),
			]},
			{"name": "Blue Corner", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4),
			]},
			{"name": "Green Floor", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
			]},
		],
		{
			"left": [_phase(Block.TileColor.RED, 2)],
			"top": [_phase(Block.TileColor.GREEN, 2), _phase(Block.TileColor.BLUE, 1)],
			"right": [_phase(Block.TileColor.BLUE, 2)],
			"bottom": [_phase(Block.TileColor.GREEN, 1)],
		}
	)


func _build_variant_j() -> LevelConfig:
	##   0 0 0 1 2
	##   3 0 1 1 2
	##   3 3 4 4 2
	##   5 5 4 6 6
	##   5 7 7 7 6
	## R×2 G×3 B×3 | L R×2 · T G×2→B×1 · R B×1→G×1 · B B×1
	return _make_shifting_level(
		"test_5x5_shifting_5",
		"Test 5x5 Shifting 5",
		150,
		[
			{"name": "Red Hook", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1),
			]},
			{"name": "Green Cap", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1),
			]},
			{"name": "Blue Column", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
			]},
			{"name": "Red Bend", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
			]},
			{"name": "Green Mid", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
			]},
			{"name": "Blue Stair", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4),
			]},
			{"name": "Blue Corner", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 3), Vector2i(4, 3), Vector2i(4, 4),
			]},
			{"name": "Green Floor", "color": Block.TileColor.GREEN, "cells": [
				Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4),
			]},
		],
		{
			"left": [_phase(Block.TileColor.RED, 2)],
			"top": [_phase(Block.TileColor.GREEN, 2), _phase(Block.TileColor.BLUE, 1)],
			"right": [_phase(Block.TileColor.BLUE, 1), _phase(Block.TileColor.GREEN, 1)],
			"bottom": [_phase(Block.TileColor.BLUE, 1)],
		}
	)


func _make_shifting_level(
	level_id: String,
	display_name: String,
	sort_index: int,
	pieces: Array,
	phases: Dictionary
) -> LevelConfig:
	var level := _make_level(
		level_id,
		display_name,
		sort_index,
		_three_color_goals(),
		_GROUP_SHIFTING,
		pieces
	)
	level.multi_goal_mode = true
	var left_phases: Array[GoalPhase] = []
	var top_phases: Array[GoalPhase] = []
	var right_phases: Array[GoalPhase] = []
	var bottom_phases: Array[GoalPhase] = []
	for phase in phases.left:
		left_phases.append(phase)
	for phase in phases.top:
		top_phases.append(phase)
	for phase in phases.right:
		right_phases.append(phase)
	for phase in phases.bottom:
		bottom_phases.append(phase)
	level.goal_left_phases = left_phases
	level.goal_top_phases = top_phases
	level.goal_right_phases = right_phases
	level.goal_bottom_phases = bottom_phases
	return level


func _two_color_goals() -> Dictionary:
	return {
		"left": Block.TileColor.RED,
		"top": Block.TileColor.RED,
		"right": Block.TileColor.BLUE,
		"bottom": Block.TileColor.BLUE,
	}


func _three_color_goals() -> Dictionary:
	return {
		"left": Block.TileColor.RED,
		"top": Block.TileColor.GREEN,
		"right": Block.TileColor.BLUE,
		"bottom": Block.TileColor.GREEN,
	}


func _phase(color: Block.TileColor, count: int, unlimited: bool = false) -> GoalPhase:
	var phase := GoalPhase.new()
	phase.color = color
	phase.count = count
	phase.unlimited = unlimited
	return phase


func _make_level(
	level_id: String,
	display_name: String,
	sort_index: int,
	goals: Dictionary,
	group_title_key: String,
	pieces: Array,
	opts: Dictionary = {}
) -> LevelConfig:
	var level := LevelConfig.new()
	level.level_id = level_id
	level.display_name = display_name
	level.level_name_key = ""
	level.section_index = SECTION_TEST
	level.sort_index = sort_index
	level.group_title_key = group_title_key
	level.columns = int(opts.get("columns", 5))
	level.rows = int(opts.get("rows", 5))
	level.disabled_cells = []

	level.goal_left_enabled = bool(opts.get("left_enabled", true))
	level.goal_left_color = goals.left as Block.TileColor
	level.goal_top_enabled = bool(opts.get("top_enabled", true))
	level.goal_top_color = goals.top as Block.TileColor
	level.goal_right_enabled = bool(opts.get("right_enabled", true))
	level.goal_right_color = goals.right as Block.TileColor
	level.goal_bottom_enabled = bool(opts.get("bottom_enabled", true))
	level.goal_bottom_color = goals.bottom as Block.TileColor

	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []

	for piece in pieces:
		var cells: Array[Vector2i] = []
		for cell in piece.cells:
			cells.append(cell as Vector2i)
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cells)
		var kind: int = int(piece.get("kind", Block.BlockKind.STANDARD))
		level.block_positions.append(packed.anchor)
		level.block_colors.append(piece.get("color", Block.TileColor.RED))
		level.block_shapes.append(BlockShapes.SINGLE)
		level.block_kinds.append(kind)
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append(str(piece.name))
	return level


func _build_walls_1() -> LevelConfig:
	## One straight wall (3 cells). Intro to immovable obstacles.
	##   0 0 1 1 1
	##   0 2 2 2 1
	##   3 W W W 4
	##   3 3 5 4 4
	##   3 3 5 5 5
	return _make_level(
		"test_5x5_walls_1",
		"Test Walls 1 — Single",
		60,
		_two_color_goals(),
		_GROUP_WALLS,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			]},
			{"name": "Blue Top", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1),
			]},
			{"name": "Red Mid", "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4),
			]},
			{"name": "Wall Bar", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2),
			]},
			{"name": "Blue Elbow", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 2), Vector2i(3, 3), Vector2i(4, 3),
			]},
			{"name": "Blue Floor", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 3), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
			]},
		]
	)


func _build_walls_2() -> LevelConfig:
	## One L-shaped wall.
	##   0 0 1 1 1
	##   0 2 2 2 1
	##   3 W W 4 4
	##   3 3 W 5 4
	##   3 6 6 5 5
	return _make_level(
		"test_5x5_walls_2",
		"Test Walls 2 — L Shape",
		70,
		_two_color_goals(),
		_GROUP_WALLS,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			]},
			{"name": "Blue Top", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1),
			]},
			{"name": "Red Mid", "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
			]},
			{"name": "Wall L", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3),
			]},
			{"name": "Blue Elbow", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 2), Vector2i(4, 2), Vector2i(4, 3),
			]},
			{"name": "Blue Zig", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
		]
	)


func _build_walls_3() -> LevelConfig:
	## Larger L-shaped wall (4 cells).
	##   0 0 1 1 2
	##   0 0 0 1 2
	##   4 W W 5 2
	##   4 4 W 5 5
	##   4 4 W 5 5
	return _make_level(
		"test_5x5_walls_3",
		"Test Walls 3 — Big L",
		80,
		_two_color_goals(),
		_GROUP_WALLS,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			]},
			{"name": "Blue Top", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1),
			]},
			{"name": "Blue Column", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
			]},
			{"name": "Wall Big L", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4),
			]},
			{"name": "Red Stair", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4),
			]},
			{"name": "Blue Cluster", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 2), Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
		]
	)


func _build_walls_4() -> LevelConfig:
	## Two separate wall pieces.
	##   0 0 1 1 2
	##   0 A A 1 2
	##   3 3 A A 2
	##   3 B B B 4
	##   5 5 5 4 4
	return _make_level(
		"test_5x5_walls_4",
		"Test Walls 4 — Two Walls",
		90,
		_two_color_goals(),
		_GROUP_WALLS,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
			]},
			{"name": "Blue Top", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(2, 0), Vector2i(3, 0), Vector2i(3, 1),
			]},
			{"name": "Blue Column", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
			]},
			{"name": "Wall A", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 2), Vector2i(3, 2),
			]},
			{"name": "Red Mid", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 2), Vector2i(1, 2), Vector2i(0, 3),
			]},
			{"name": "Wall B", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
			]},
			{"name": "Blue Elbow", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
			{"name": "Red Floor", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
			]},
		]
	)


func _build_walls_5() -> LevelConfig:
	## Three wall pieces — denser obstacle course.
	##   0 0 A 1 1
	##   3 0 A 4 1
	##   3 B A 4 2
	##   3 B B C C
	##   5 5 5 C C
	return _make_level(
		"test_5x5_walls_5",
		"Test Walls 5 — Many Walls",
		100,
		_two_color_goals(),
		_GROUP_WALLS,
		[
			{"name": "Red Cap", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1),
			]},
			{"name": "Wall A", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2),
			]},
			{"name": "Blue Top", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 0), Vector2i(4, 0), Vector2i(4, 1),
			]},
			{"name": "Red Column", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3),
			]},
			{"name": "Wall B", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3),
			]},
			{"name": "Blue Mid", "color": Block.TileColor.BLUE, "cells": [
				Vector2i(3, 1), Vector2i(3, 2), Vector2i(4, 2),
			]},
			{"name": "Wall C", "kind": Block.BlockKind.WALL, "color": Block.TileColor.RED, "cells": [
				Vector2i(3, 3), Vector2i(4, 3), Vector2i(3, 4), Vector2i(4, 4),
			]},
			{"name": "Red Floor", "color": Block.TileColor.RED, "cells": [
				Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
			]},
		]
	)


## Bigger Boards 1 — left-blue bait on interlocking towers. Levels 2–4 are in
## generate_bigger_board_levels.gd (do not recreate the old bait-2/3/4 copies).

func _bait_phase(color: Block.TileColor, count: int = 1) -> GoalPhase:
	var phase := GoalPhase.new()
	phase.color = color
	phase.count = count
	return phase


func _bigger_std_colors() -> Dictionary:
	return {
		"0": Block.TileColor.BLUE,
		"1": Block.TileColor.RED,
		"2": Block.TileColor.GREEN,
		"3": Block.TileColor.BLUE,
		"4": Block.TileColor.RED,
		"5": Block.TileColor.GREEN,
		"6": Block.TileColor.RED,
		"7": Block.TileColor.GREEN,
		"8": Block.TileColor.RED,
	}


func _bigger_std_phases() -> Dictionary:
	## LEFT/RIGHT bait colour ×1; TOP greens then reds; BOTTOM red → green → bait colour.
	return {
		"left": [_bait_phase(Block.TileColor.BLUE)] as Array[GoalPhase],
		"top": [
			_bait_phase(Block.TileColor.GREEN, 2),
			_bait_phase(Block.TileColor.RED, 3),
		] as Array[GoalPhase],
		"bottom": [
			_bait_phase(Block.TileColor.RED),
			_bait_phase(Block.TileColor.GREEN),
			_bait_phase(Block.TileColor.BLUE),
		] as Array[GoalPhase],
		"right": [] as Array[GoalPhase],
	}


func _from_ascii_level(
	level_id: String,
	display_name: String,
	sort_index: int,
	rows: PackedStringArray,
	colors: Dictionary,
	opts: Dictionary = {}
) -> LevelConfig:
	var height := rows.size()
	var width := rows[0].length()
	var cells_by_id: Dictionary = {}
	for y in height:
		for x in width:
			var ch := rows[y].substr(x, 1)
			if not cells_by_id.has(ch):
				cells_by_id[ch] = [] as Array[Vector2i]
			(cells_by_id[ch] as Array).append(Vector2i(x, y))
	var ids: Array = cells_by_id.keys()
	ids.sort()

	var level := LevelConfig.new()
	level.level_id = level_id
	level.display_name = display_name
	level.level_name_key = ""
	level.section_index = SECTION_TEST
	level.sort_index = sort_index
	level.group_title_key = _GROUP_BIGGER
	level.columns = width
	level.rows = height
	level.disabled_cells = []
	level.goal_left_enabled = bool(opts.get("left_enabled", true))
	level.goal_top_enabled = bool(opts.get("top_enabled", true))
	level.goal_right_enabled = bool(opts.get("right_enabled", false))
	level.goal_bottom_enabled = bool(opts.get("bottom_enabled", true))
	level.goal_left_color = Block.TileColor.BLUE
	level.goal_top_color = Block.TileColor.GREEN
	level.goal_right_color = Block.TileColor.RED
	level.goal_bottom_color = Block.TileColor.RED
	level.multi_goal_mode = true
	var phases: Dictionary = opts.get("phases", _bigger_std_phases())
	level.goal_left_phases = phases.get("left", []) as Array[GoalPhase]
	level.goal_top_phases = phases.get("top", []) as Array[GoalPhase]
	level.goal_right_phases = phases.get("right", []) as Array[GoalPhase]
	level.goal_bottom_phases = phases.get("bottom", []) as Array[GoalPhase]
	level.block_positions = []
	level.block_colors = []
	level.block_shapes = []
	level.block_kinds = []
	level.block_cell_patterns = []
	level.block_shape_names = []
	for id in ids:
		var cell_list: Array[Vector2i] = []
		for cell in cells_by_id[id]:
			cell_list.append(cell as Vector2i)
		var packed: Dictionary = LevelGenRulesScript.pack_cells(cell_list)
		level.block_positions.append(packed.anchor)
		level.block_colors.append(colors[id])
		level.block_shapes.append(BlockShapes.SINGLE)
		level.block_kinds.append(Block.BlockKind.STANDARD)
		level.block_cell_patterns.append(packed.offsets)
		level.block_shape_names.append("Piece %s" % id)
	return level


func _build_bigger_1() -> LevelConfig:
	## 8×8 left-blue bait — interlocking towers, bottom shelf for R→G→bait.
	return _from_ascii_level(
		"test_bigger_bait_1",
		"Bigger Bait 1 — Towers",
		210,
		PackedStringArray([
			"01133557",
			"01233557",
			"01233557",
			"01233457",
			"01234457",
			"01244467",
			"01222668",
			"00222688",
		]),
		_bigger_std_colors()
	)


func _save_project_level(level: LevelConfig) -> Error:
	var path := "res://resources/levels/%s.tres" % level.level_id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://resources/levels/"))
	var err := ResourceSaver.save(level, path)
	if err != OK:
		return err
	var store: Node = Engine.get_main_loop().root.get_node_or_null("CustomLevelStore")
	if store != null and store.has_method("rewrite_project_manifest"):
		return store.call("rewrite_project_manifest") as Error
	return _rewrite_registry_fallback(path)


func _rewrite_registry_fallback(new_path: String) -> Error:
	var paths: Array[String] = []
	var dir := DirAccess.open("res://resources/levels/")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				paths.append("res://resources/levels/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if not paths.has(new_path):
		paths.append(new_path)
	paths.sort()
	var lines: PackedStringArray = [
		"extends Object",
		"class_name LevelRegistry",
		"",
		"## Auto-updated when the level creator saves into the project.",
		"## Do not hand-edit unless you know why — CustomLevelStore.rewrite_project_manifest() owns this file.",
		"const LEVEL_PATHS: PackedStringArray = [",
	]
	for p in paths:
		lines.append("\t\"%s\"," % p)
	lines.append("]")
	lines.append("")
	var file := FileAccess.open("res://scritps/LevelRegistry.gd", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	return OK


func _write_report(lines: PackedStringArray) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/"))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write report: %s" % FileAccess.get_open_error())
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
