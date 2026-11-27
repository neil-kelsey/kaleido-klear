extends SceneTree

## Headless checks for the main-menu Daily Puzzle streak cluster.
##   godot --headless --path . -s res://scritps/tools/streak_badge_checks.gd
## Does not write user://progress.json.

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _process(_delta: float) -> bool:
	var Cluster = load("res://scritps/ui/DailyStreakCluster.gd")
	var todo: Dictionary = Cluster.visual_for(false, false)
	_check(todo["icon_name"] == "fire", "not done uses flame icon")
	_check(todo["badge_fill"] == Cluster.BADGE_GREY_FILL, "not done badge is greyed out")
	_check(todo["icon_color"] == Cluster.FLAME_COLOR, "not done flame keeps streak colour")

	var done: Dictionary = Cluster.visual_for(true, false)
	_check(done["icon_name"] == "check", "done-imperfect uses tick icon")
	_check(done["badge_fill"] == Cluster.BADGE_GREEN_FILL, "done-imperfect badge is green")
	_check(done["icon_color"] == Cluster.TICK_COLOR, "done-imperfect tick is green")

	var perfect: Dictionary = Cluster.visual_for(true, true)
	_check(perfect["icon_name"] == "star", "perfect uses star icon")
	_check(perfect["badge_fill"] == Cluster.BADGE_GREEN_FILL, "perfect badge is green")
	_check(perfect["icon_color"] == Cluster.STAR_COLOR, "perfect star is gold")

	var perfect_wins: Dictionary = Cluster.visual_for(false, true)
	_check(perfect_wins["icon_name"] == "star", "perfect flag wins over not-done")

	var gs: Node = root.get_node("GameSession")
	var today := "2026-11-27"
	var saved_completed: Dictionary = gs.daily_completed.duplicate(true)
	var saved_current: int = gs.daily_streak_current
	var saved_best: int = gs.daily_streak_best
	var saved_last: String = gs.daily_streak_last_date

	gs.daily_completed = {}
	gs.daily_streak_current = 3
	gs.daily_streak_best = 3
	gs.daily_streak_last_date = "2026-11-26"
	_check(not gs.is_daily_done(today) and not gs.is_daily_perfect(today), "session: not done today")
	_check(gs.get_display_streak(today) == 3, "session: at-risk streak stays 3")
	var from_todo: Dictionary = Cluster.visual_for(gs.is_daily_done(today), gs.is_daily_perfect(today))
	_check(from_todo["icon_name"] == "fire" and from_todo["badge_fill"] == Cluster.BADGE_GREY_FILL, "session todo -> flame + grey badge")

	gs.daily_completed[today] = {"daily": 2}
	gs.daily_streak_last_date = today
	_check(gs.is_daily_done(today) and not gs.is_daily_perfect(today), "2 stars = 2 hearts or fewer remaining, not perfect")
	var from_done: Dictionary = Cluster.visual_for(gs.is_daily_done(today), gs.is_daily_perfect(today))
	_check(from_done["icon_name"] == "check" and from_done["badge_fill"] == Cluster.BADGE_GREEN_FILL, "session 2-star -> tick + green badge")

	gs.daily_completed[today] = {"daily": 1}
	_check(gs.is_daily_done(today) and not gs.is_daily_perfect(today), "1 star = 1 heart remaining, not perfect")
	var from_one: Dictionary = Cluster.visual_for(gs.is_daily_done(today), gs.is_daily_perfect(today))
	_check(from_one["icon_name"] == "check", "session 1-star -> tick")

	gs.daily_completed[today] = {"daily": 3}
	_check(gs.is_daily_done(today) and gs.is_daily_perfect(today), "3 stars = all hearts remaining, perfect")
	var from_perfect: Dictionary = Cluster.visual_for(gs.is_daily_done(today), gs.is_daily_perfect(today))
	_check(from_perfect["icon_name"] == "star" and from_perfect["badge_fill"] == Cluster.BADGE_GREEN_FILL, "session 3-star -> star + green badge")

	var cluster = Cluster.new()
	root.add_child(cluster)
	cluster.apply(3, false, false)
	_check(cluster.get_node("StreakIcon").icon_name == "fire", "cluster todo icon is fire")
	_check(cluster.get_node("StreakCountBadge/StreakCount").text == "3", "cluster todo shows streak 3")
	cluster.apply(3, true, false)
	_check(cluster.get_node("StreakIcon").icon_name == "check", "cluster done icon is check")
	cluster.apply(3, true, true)
	_check(cluster.get_node("StreakIcon").icon_name == "star", "cluster perfect icon is star")
	_check(cluster.get_node("StreakCountBadge/StreakCount").text == "3", "cluster perfect shows streak 3")

	var badge: Control = cluster.get_node("StreakCountBadge")
	var icon: Control = cluster.get_node("StreakIcon")
	_check(icon.custom_minimum_size.x == Cluster.ICON_SIZE, "main icon uses ICON_SIZE (%.0f)" % Cluster.ICON_SIZE)
	cluster.apply(3, false, false)
	var one: Vector2 = badge.custom_minimum_size
	_check(one.x >= one.y - 0.01, "1-digit badge is at least as wide as tall (got %s)" % one)
	_check(one.y >= Cluster.BADGE_MIN_HEIGHT - 0.01, "1-digit badge is at least BADGE_MIN_HEIGHT (h=%.1f)" % one.y)
	_check(one.y < Cluster.ICON_SIZE, "badge is smaller than the icon (h=%.1f, icon=%.0f)" % [one.y, Cluster.ICON_SIZE])
	cluster.apply(12, true, false)
	var two: Vector2 = badge.custom_minimum_size
	_check(two.x >= two.y - 0.01, "2-digit badge is at least as wide as tall (got %s)" % two)
	_check(two.x > two.y + 0.5, "2-digit badge is a wider pill, not a tall upright")
	var math_one: Vector2 = Cluster.badge_size_for_text(Vector2(10, 16))
	_check(math_one.x >= math_one.y, "badge_size_for_text keeps width >= height for a narrow glyph")
	var math_two: Vector2 = Cluster.badge_size_for_text(Vector2(22, 16))
	_check(math_two.x > math_two.y, "badge_size_for_text widens for a longer string")

	cluster.queue_free()

	gs.daily_completed = saved_completed
	gs.daily_streak_current = saved_current
	gs.daily_streak_best = saved_best
	gs.daily_streak_last_date = saved_last

	print("streak_badge_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
	return true
