extends RefCounted
class_name FaVector

## Font Awesome classic solid glyphs drawn as tessellated SVG paths (true vectors).
## Paths are the official FA outlines — not imported bitmaps.

const LOCK_STEEL := Color(0.46, 0.50, 0.56, 1.0)

const LOCK_D := "M144 144v48H304V144c0-44.2-35.8-80-80-80s-80 35.8-80 80zM80 192V144C80 64.5 144.5 0 224 0s144 64.5 144 144v48h16c35.3 0 64 28.7 64 64V448c0 35.3-28.7 64-64 64H64c-35.3 0-64-28.7-64-64V256c0-35.3 28.7-64 64-64H80z"
const LOCK_VIEW := Vector2(448, 512)

const CHECK_D := "M1671 566q0 40-28 68l-724 724-136 136q-28 28-68 28t-68-28l-136-136-362-362q-28-28-28-68t28-68l136-136q28-28 68-28t68 28l294 295 656-657q28-28 68-28t68 28l136 136q28 28 28 68z"
const CHECK_VIEW := Vector2(1792, 1792)

const UNDO_D := "M125.7 160l50.3 0c17.7 0 32 14.3 32 32s-14.3 32-32 32L48 224c-17.7 0-32-14.3-32-32L16 64c0-17.7 14.3-32 32-32s32 14.3 32 32l0 51.2L97.6 97.6c87.5-87.5 229.3-87.5 316.8 0s87.5 229.3 0 316.8s-229.3 87.5-316.8 0c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0c62.5 62.5 163.8 62.5 226.3 0s62.5-163.8 0-226.3s-163.8-62.5-226.3 0L125.7 160z"
const UNDO_VIEW := Vector2(512, 512)

const REFRESH_D := "M142.9 142.9c-17.5 17.5-30.1 38-37.8 59.8c-5.9 16.7-24.2 25.4-40.8 19.5s-25.4-24.2-19.5-40.8C55.6 150.7 73.2 122 97.6 97.6c87.2-87.2 228.3-87.5 315.8-1L455 55c6.9-6.9 17.2-8.9 26.2-5.2s14.8 12.5 14.8 22.2l0 128c0 13.3-10.7 24-24 24l-8.4 0c0 0 0 0 0 0L344 224c-9.7 0-18.5-5.8-22.2-14.8s-1.7-19.3 5.2-26.2l41.1-41.1c-62.6-61.5-163.1-61.2-225.3 1zM16 312c0-13.3 10.7-24 24-24l7.6 0 .7 0L168 288c9.7 0 18.5 5.8 22.2 14.8s1.7 19.3-5.2 26.2l-41.1 41.1c62.6 61.5 163.1 61.2 225.3-1c17.5-17.5 30.1-38 37.8-59.8c5.9-16.7 24.2 25.4 40.8-19.5s25.4 24.2 19.5 40.8c-10.8 30.6-28.4 59.3-52.9 83.8c-87.2 87.2-228.3 87.5-315.8 1L57 457c-6.9 6.9-17.2 8.9-26.2 5.2S16 449.7 16 440l0-119.6 0-.7 0-7.6z"
const REFRESH_VIEW := Vector2(512, 512)

const ARROW_LEFT_D := "M9.4 233.4c-12.5 12.5-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L109.2 288 416 288c17.7 0 32-14.3 32-32s-14.3-32-32-32l-306.7 0L214.6 118.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0l-160 160z"
const ARROW_LEFT_VIEW := Vector2(448, 512)

const PLAY_D := "M73 39c-14.8-9.1-33.4-9.4-48.5-.9S0 62.6 0 80L0 432c0 17.4 9.4 33.4 24.5 41.9s33.7 8.1 48.5-.9L361 297c14.3-8.7 23-24.2 23-41s-8.7-32.2-23-41L73 39z"
const PLAY_VIEW := Vector2(384, 512)

const XMARK_D := "M342.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L192 210.7 86.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L146.7 256 41.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L192 301.3 297.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L237.3 256 342.6 150.6z"
const XMARK_VIEW := Vector2(384, 512)

const GEAR_D := "M495.9 166.6c3.2 8.7 .5 18.4-6.4 24.6l-43.3 39.4c1.1 8.3 1.7 16.8 1.7 25.4s-.6 17.1-1.7 25.4l43.3 39.4c6.9 6.2 9.6 15.9 6.4 24.6c-4.4 11.9-9.7 23.3-15.8 34.3l-4.7 8.1c-6.6 11-14 21.4-22.1 31.2c-5.9 7.2-15.7 9.6-24.5 6.8l-55.7-17.7c-13.4 10.3-28.2 18.9-44 25.4l-12.5 57.1c-2 9.1-9 16.3-18.2 17.8c-13.8 2.3-28 3.5-42.5 3.5s-28.7-1.2-42.5-3.5c-9.2-1.5-16.2-8.7-18.2-17.8l-12.5-57.1c-15.8-6.5-30.6-15.1-44-25.4L83.1 425.9c-8.8 2.8-18.6 .3-24.5-6.8c-8.1-9.8-15.5-20.2-22.1-31.2l-4.7-8.1c-6.1-11-11.4-22.4-15.8-34.3c-3.2-8.7-.5-18.4 6.4-24.6l43.3-39.4C64.6 273.1 64 264.6 64 256s.6-17.1 1.7-25.4L22.4 191.2c-6.9-6.2-9.6-15.9-6.4-24.6c4.4-11.9 9.7-23.3 15.8-34.3l4.7-8.1c6.6-11 14-21.4 22.1-31.2c5.9-7.2 15.7-9.6 24.5-6.8l55.7 17.7c13.4-10.3 28.2-18.9 44-25.4l12.5-57.1c2-9.1 9-16.3 18.2-17.8C227.3 1.2 241.5 0 256 0s28.7 1.2 42.5 3.5c9.2 1.5 16.2 8.7 18.2 17.8l12.5 57.1c15.8 6.5 30.6 15.1 44 25.4l55.7-17.7c8.8-2.8 18.6-.3 24.5 6.8c8.1 9.8 15.5 20.2 22.1 31.2l4.7 8.1c6.1 11 11.4 22.4 15.8 34.3zM256 336a80 80 0 1 0 0-160 80 80 0 1 0 0 160z"
const GEAR_VIEW := Vector2(512, 512)

const ANGLES_RIGHT_D := "M470.6 278.6c12.5-12.5 12.5-32.8 0-45.3l-160-160c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L402.7 256 265.4 393.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0l160-160zm-352 160l160-160c12.5-12.5 12.5-32.8 0-45.3l-160-160c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L210.7 256 73.4 393.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0z"
const ANGLES_RIGHT_VIEW := Vector2(512, 512)

const BULLSEYE_D := "M448 256A192 192 0 1 0 64 256a192 192 0 1 0 384 0zM0 256a256 256 0 1 1 512 0A256 256 0 1 1 0 256zm256 80a80 80 0 1 0 0-160 80 80 0 1 0 0 160zm0-224a144 144 0 1 1 0 288 144 144 0 1 1 0-288zM224 256a32 32 0 1 1 64 0 32 32 0 1 1 -64 0z"
const BULLSEYE_VIEW := Vector2(512, 512)


static func draw_lock(item: CanvasItem, center: Vector2, height: float, fill: Color = LOCK_STEEL) -> void:
	SvgPath.draw_icon(item, LOCK_D, LOCK_VIEW, center, height, fill, true)


static func draw_check(item: CanvasItem, center: Vector2, height: float, fill: Color = Color(0.95, 0.78, 0.2, 1.0)) -> void:
	SvgPath.draw_icon(item, CHECK_D, CHECK_VIEW, center, height, fill, true)


static func draw_named(item: CanvasItem, name: String, center: Vector2, height: float, fill: Color) -> void:
	match name:
		"lock":
			draw_lock(item, center, height, fill)
		"check":
			draw_check(item, center, height, fill)
		"undo":
			SvgPath.draw_icon(item, UNDO_D, UNDO_VIEW, center, height, fill, false)
		"refresh":
			SvgPath.draw_icon(item, REFRESH_D, REFRESH_VIEW, center, height, fill, false)
		"arrow-left":
			SvgPath.draw_icon(item, ARROW_LEFT_D, ARROW_LEFT_VIEW, center, height, fill, false)
		"play":
			SvgPath.draw_icon(item, PLAY_D, PLAY_VIEW, center, height, fill, false)
		"xmark":
			SvgPath.draw_icon(item, XMARK_D, XMARK_VIEW, center, height, fill, false)
		"gear":
			SvgPath.draw_icon(item, GEAR_D, GEAR_VIEW, center, height, fill, false)
		"angles-right":
			SvgPath.draw_icon(item, ANGLES_RIGHT_D, ANGLES_RIGHT_VIEW, center, height, fill, false)
		"bullseye":
			_draw_bullseye(item, center, height, fill)
		_:
			push_warning("FaVector: unknown icon '%s'" % name)


static func _draw_bullseye(item: CanvasItem, center: Vector2, height: float, fill: Color) -> void:
	## FA bullseye is concentric rings — draw as vector arcs, not a bitmap.
	var r := height * 0.5
	item.draw_arc(center, r, 0.0, TAU, 48, fill, maxf(height * 0.08, 1.6), true)
	item.draw_arc(center, r * 0.62, 0.0, TAU, 40, fill, maxf(height * 0.08, 1.6), true)
	item.draw_circle(center, r * 0.22, fill)
