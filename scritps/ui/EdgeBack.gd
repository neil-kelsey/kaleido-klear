extends RefCounted
class_name EdgeBack

## Screen-edge swipe that means "back", distinct from a drag that pans.
##
## A finger that starts in the left or right inset and travels inward,
## mostly horizontally, is back (same idea as Android's edge back and
## iOS's interactive pop). A vertical move from that inset falls through
## to panning, so the edge is not a dead zone. The board or map should
## not move while this gesture is still a back candidate.

## ~32dp on the 915-wide design viewport. Wide enough to catch a real
## edge swipe, narrow enough that the playfield still pans.
const EDGE_PX := 72.0
const COMMIT_PX := 120.0
const FLICK_MIN_PX := 56.0
const FLICK_SPEED := 900.0
const VERTICAL_SLOP := 42.0

var _active := false
var _id := -1
var _origin := Vector2.ZERO
var _last := Vector2.ZERO
var _from_left := false
var _handed_off := false
var _started_msec := 0


func owns(pointer_id: int) -> bool:
	return _active and _id == pointer_id


func watching(pointer_id: int) -> bool:
	return owns(pointer_id) and not _handed_off


func cancel() -> void:
	_active = false
	_handed_off = false
	_id = -1


func try_begin(pointer_id: int, pos: Vector2, viewport_width: float) -> bool:
	if pointer_id < 0:
		return false
	var from_left := pos.x <= EDGE_PX
	var from_right := pos.x >= viewport_width - EDGE_PX
	if not from_left and not from_right:
		return false
	_active = true
	_handed_off = false
	_id = pointer_id
	_origin = pos
	_last = pos
	_from_left = from_left
	_started_msec = Time.get_ticks_msec()
	return true


## Returns true when the gesture has turned into a pan and the caller
## should start moving the board or map from here.
func drag(pointer_id: int, pos: Vector2) -> bool:
	if not watching(pointer_id):
		return false
	_last = pos
	var delta := pos - _origin
	var inward := delta.x if _from_left else -delta.x
	if absf(delta.y) > VERTICAL_SLOP and absf(delta.y) > maxf(inward, 0.0) * 1.15:
		_handed_off = true
		return true
	return false


## Returns true when the finger lifted on a completed back swipe.
func release(pointer_id: int) -> bool:
	if not owns(pointer_id):
		return false
	var go_back := false
	if not _handed_off:
		var delta := _last - _origin
		var inward := delta.x if _from_left else -delta.x
		var horizontal := inward > absf(delta.y) * 1.2
		var elapsed := maxi(Time.get_ticks_msec() - _started_msec, 1)
		var speed := inward / (float(elapsed) / 1000.0)
		var flicked := inward >= FLICK_MIN_PX and speed >= FLICK_SPEED
		go_back = horizontal and (inward >= COMMIT_PX or flicked)
	cancel()
	return go_back
