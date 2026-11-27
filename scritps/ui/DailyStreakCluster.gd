extends Control
class_name DailyStreakCluster

## Trailing streak status for the main-menu Daily Puzzle button.
## A large flame / tick / star, with a small notification badge on its top-right.
## Not done: flame + greyed-out streak count.
## Done with 1–2 stars (2 hearts or fewer remaining): tick + green count.
## Perfect (3 stars, all hearts remaining): star + green count.

const ICON_SIZE := 72.0
const BADGE_MIN_HEIGHT := 42.0
## White ring so the badge separates from the icon (esp. green tick + green badge).
const BADGE_RING := 4.0
const BADGE_PAD_H := 13.0
const BADGE_PAD_V := 5.0
const BADGE_FONT := 28
## How much of the badge overlaps the icon (1 = fully covering the corner).
const BADGE_OVERLAP_X := 0.42
const BADGE_OVERLAP_Y := 0.32

const FLAME_COLOR := Color(1.0, 0.48, 0.16, 1.0)
const TICK_COLOR := Color(0.18, 0.66, 0.38, 1.0)
const STAR_COLOR := Color(1.0, 0.78, 0.30, 1.0)

const BADGE_GREY_FILL := Color(0.62, 0.64, 0.68, 1.0)
const BADGE_GREY_TEXT := Color(0.98, 0.98, 0.99, 1.0)
const BADGE_GREEN_FILL := Color(0.22, 0.72, 0.42, 1.0)
const BADGE_GREEN_TEXT := Color(1.0, 1.0, 1.0, 1.0)


var _icon: FaIconView
var _badge: PanelContainer
var _count: Label


func _init() -> void:
	name = "DailyStreakCluster"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon = FaIconView.new()
	_icon.name = "StreakIcon"
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_badge = PanelContainer.new()
	_badge.name = "StreakCountBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.z_index = 1
	_count = Label.new()
	_count.name = "StreakCount"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	## Do not use UiTheme.apply_label_font — it floors to MIN_MENU_FONT_SIZE (56)
	## and turns the badge into a tall upright pill.
	_count.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	_count.add_theme_font_size_override("font_size", BADGE_FONT)
	_badge.add_child(_count)
	add_child(_badge)
	custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_cluster()


## Visual tokens for the three daily states. Used by the cluster and by checks.
static func visual_for(done: bool, perfect: bool) -> Dictionary:
	if perfect:
		return {
			"icon_name": "star",
			"icon_color": STAR_COLOR,
			"badge_fill": BADGE_GREEN_FILL,
			"badge_text": BADGE_GREEN_TEXT,
		}
	if done:
		return {
			"icon_name": "check",
			"icon_color": TICK_COLOR,
			"badge_fill": BADGE_GREEN_FILL,
			"badge_text": BADGE_GREEN_TEXT,
		}
	return {
		"icon_name": "fire",
		"icon_color": FLAME_COLOR,
		"badge_fill": BADGE_GREY_FILL,
		"badge_text": BADGE_GREY_TEXT,
	}


## Width is always >= height: circle-ish for one digit, a wider pill for 2+.
static func badge_size_for_text(text_size: Vector2) -> Vector2:
	var h := maxf(BADGE_MIN_HEIGHT, text_size.y + BADGE_PAD_V * 2.0)
	var w := maxf(h, text_size.x + BADGE_PAD_H * 2.0)
	return Vector2(w, h)


func apply(streak: int, done: bool, perfect: bool) -> void:
	var visual := visual_for(done, perfect)
	_icon.icon_name = str(visual["icon_name"])
	_icon.icon_color = visual["icon_color"]
	_count.text = str(maxi(streak, 0))
	_count.add_theme_color_override("font_color", visual["badge_text"])
	var bg := UiTheme.circle_stylebox(visual["badge_fill"])
	bg.border_color = Color.WHITE
	bg.set_border_width_all(int(BADGE_RING))
	bg.anti_aliasing = true
	bg.content_margin_left = BADGE_PAD_H
	bg.content_margin_right = BADGE_PAD_H
	bg.content_margin_top = BADGE_PAD_V
	bg.content_margin_bottom = BADGE_PAD_V
	_badge.add_theme_stylebox_override("panel", bg)
	var dims := badge_size_for_text(_count.get_minimum_size())
	_badge.custom_minimum_size = dims
	_badge.size = dims
	_layout_cluster()


func _layout_cluster() -> void:
	var badge_s: Vector2 = _badge.custom_minimum_size
	if badge_s.x < 2.0:
		badge_s = Vector2(BADGE_MIN_HEIGHT, BADGE_MIN_HEIGHT)
	var overhang_right := badge_s.x * (1.0 - BADGE_OVERLAP_X)
	custom_minimum_size = Vector2(ICON_SIZE + overhang_right, ICON_SIZE)
	_icon.position = Vector2.ZERO
	_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_badge.position = Vector2(
		ICON_SIZE - badge_s.x * BADGE_OVERLAP_X,
		-badge_s.y * BADGE_OVERLAP_Y
	)
	_badge.size = badge_s


func apply_from_session(date_key: String = "") -> void:
	apply(
		GameSession.get_display_streak(date_key),
		GameSession.is_daily_done(date_key),
		GameSession.is_daily_perfect(date_key)
	)
