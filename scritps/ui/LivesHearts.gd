extends Control
class_name LivesHearts

## Top-of-screen lives: Font Awesome solid hearts (red remaining, grey lost).

const HEART_RED := Color(0.86, 0.16, 0.22, 1.0)
const HEART_GREY := Color(0.62, 0.64, 0.68, 1.0)
const HEART_SIZE := 52.0
const HEART_GAP := 14.0

var remaining: int = 3
var maximum: int = 3
var _safe_top := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_top()


func set_lives(remaining_lives: int, max_lives: int = -1) -> void:
	remaining = maxi(remaining_lives, 0)
	if max_lives > 0:
		maximum = max_lives
	_pin_top()
	queue_redraw()


func set_top_chrome(safe_top: float) -> void:
	_safe_top = maxf(safe_top, 0.0)
	_pin_top()


func occupied_bottom() -> float:
	return offset_bottom


func _pin_top() -> void:
	var count := maxi(maximum, 1)
	var w := count * HEART_SIZE + float(count - 1) * HEART_GAP
	var h := HEART_SIZE + 8.0
	## Always sit below the quota-badge slot so lives don't jump when a top
	## goal is missing or unlimited.
	var inset := (
		_safe_top
		+ float(GoalBorder.BAR_WIDTH)
		- GoalBorder.BADGE_OVERLAP
		+ GoalBorder.BADGE_H
		+ 22.0
	)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_END
	offset_left = -w * 0.5
	offset_right = w * 0.5
	offset_top = inset
	offset_bottom = inset + h
	custom_minimum_size = Vector2(w, h)


func _draw() -> void:
	var count := maxi(maximum, 1)
	var total_w := count * HEART_SIZE + float(count - 1) * HEART_GAP
	var start_x := (size.x - total_w) * 0.5 + HEART_SIZE * 0.5
	var cy := size.y * 0.5
	for i in count:
		var filled := i < remaining
		var col := HEART_RED if filled else HEART_GREY
		var center := Vector2(start_x + float(i) * (HEART_SIZE + HEART_GAP), cy)
		FaVector.draw_named(self, "heart", center, HEART_SIZE, col)
