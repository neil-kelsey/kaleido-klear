extends Control

## Veilmoth Games boot splash. Self-contained: every texture and shader lives
## under addons/veilmoth_splash/. The host game only chooses the scene that
## follows, and how long each colour holds.

@export var dark_hold_sec := 1.5
@export var light_hold_sec := 1.5
## If this is empty, ProjectSettings veilmoth_splash/next_scene is used,
## then application/run/main_scene_after_splash.
@export var next_scene_path := ""
## Off by default. accessibility_should_reduce_animation() returns an int:
## 1 to reduce, 0 not to, and -1 when the status is unknown. The call is
## implemented on macOS and Windows only, so Android and headless runs
## return -1. Version 1.1.0 stored that int in a bool, and every non-zero
## value (including -1) became true, which cut the wing beat. Turn this on
## to shorten the flap only when the call returns exactly 1. The beat,
## mist, and dust still play.
@export var respect_reduce_motion := false

const DARK_SHADER := preload("res://addons/veilmoth_splash/assets/shaders/veil_dark_key.gdshader")
const MIST_SHADER := preload("res://addons/veilmoth_splash/assets/shaders/veil_mist.gdshader")
const WORD_SHADER := preload("res://addons/veilmoth_splash/assets/shaders/veil_wordmark.gdshader")
const DARK_BODY := preload("res://addons/veilmoth_splash/assets/rig/moth-dark-body.png")
const DARK_LWING := preload("res://addons/veilmoth_splash/assets/rig/moth-dark-lwing.png")
const DARK_RWING := preload("res://addons/veilmoth_splash/assets/rig/moth-dark-rwing.png")
const LIGHT_BODY := preload("res://addons/veilmoth_splash/assets/rig/moth-light-body.png")
const LIGHT_LWING := preload("res://addons/veilmoth_splash/assets/rig/moth-light-lwing.png")
const LIGHT_RWING := preload("res://addons/veilmoth_splash/assets/rig/moth-light-rwing.png")
const WORDMARK := preload("res://addons/veilmoth_splash/assets/logo/veilmoth-wordmark-letters-splitv.png")

const NEXT_SETTING := "veilmoth_splash/next_scene"
const NEXT_FALLBACK := "application/run/main_scene_after_splash"

const BG_DARK := Color(0.043137, 0.043137, 0.043137, 1.0)
const BG_LIGHT := Color(0.925490, 0.894118, 0.823529, 1.0)
const BONE := Color(0.953, 0.937, 0.902, 1.0)
const GHOST := Color(0.498, 0.890, 0.788, 1.0)
const INK := Color(0.137255, 0.149020, 0.172549, 1.0)
const TEAL := Color(0.070588, 0.639216, 0.513725, 1.0)

const LEFT_PIVOT := Vector2(0.454688, 0.326389)
const RIGHT_PIVOT := Vector2(0.546875, 0.326389)
const PEAK := 76.0
const BEAT_START := 0.040
const BEAT_DUR := 0.860
const WIPE_DUR := 0.900
const FADE_DUR := 0.40
const REDUCE_FADE := 0.28
## When reduced motion is explicitly opted in, the flap and wipe take this
## fraction of their normal time. They are never skipped.
const REDUCE_FLAP_SCALE := 0.55
## An instant load never shows the bar. A slow load reveals it after this.
const BAR_REVEAL_SEC := 0.30
const RIG_W := 1280.0
const RIG_H := 720.0

## Set before the node enters the tree. "loading" holds the dark frame.
## "play" runs the beat but does not open the next scene (used for screenshots).
var capture_hold := ""

var _bg: ColorRect
var _stage: Control
var _lwing: TextureRect
var _rwing: TextureRect
var _body: TextureRect
var _word: TextureRect
var _word_mat: ShaderMaterial
var _dust: CPUParticles2D
var _mist: ColorRect
var _mist_mat: ShaderMaterial
var _bar: ColorRect
var _bar_fill: ColorRect

var _next := ""
var _reduce := false
var _load_done := false
var _skip := false
var _left := false
var _swapped := false
var _dust_on := false
var _freeze_load := false
var _shown_msec := 0
var _anim_start_msec := 0
var _phase := 0 ## 0 holding dark, 1 sequence, 2 fading
var _progress := 0.0
var _menu: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_msec = Time.get_ticks_msec()
	# Compare to 1. A bare assignment booleanizes -1 (unknown) to true.
	_reduce = respect_reduce_motion and DisplayServer.accessibility_should_reduce_animation() == 1
	_next = _resolve_next()
	_build()
	_layout()
	_apply_theme(false)
	_apply_wings(-1.0)
	get_viewport().size_changed.connect(_layout)
	if capture_hold == "loading":
		_freeze_load = true
		_bar.visible = false
		return
	if _next == "":
		push_error("Veilmoth splash has no next scene. Set next_scene_path, veilmoth_splash/next_scene, or application/run/main_scene_after_splash.")
		_load_done = true
		return
	_start_load()


func _gui_input(event: InputEvent) -> void:
	if _is_press(event):
		_request_skip()
		accept_event()


func handle_back() -> void:
	_request_skip()


func begin_playback() -> void:
	## Screenshot helper: leave the held dark frame and run the beat.
	capture_hold = "play"
	_freeze_load = false
	_load_done = true
	_begin_sequence()


func _process(_delta: float) -> void:
	_layout()
	if _freeze_load:
		_apply_wings(-1.0)
		return
	if _left:
		return
	var since := _since(_shown_msec)
	if not _load_done:
		_poll_load()
		_bar.visible = since >= BAR_REVEAL_SEC
	else:
		_bar.visible = false
	if _phase == 0:
		if _load_done and _skip:
			_jump_to_menu()
			return
		if _load_done and since >= dark_hold_sec:
			_begin_sequence()
		return
	if _phase != 1:
		return
	var elapsed := _since(_anim_start_msec)
	var anim_s := elapsed / _flap_scale()
	_apply_frame(anim_s)
	if capture_hold == "play":
		return
	if elapsed >= WIPE_DUR * _flap_scale() + light_hold_sec:
		_begin_fade()


func _begin_sequence() -> void:
	_phase = 1
	_bar.visible = false
	_anim_start_msec = Time.get_ticks_msec()
	_swapped = false
	_dust_on = false
	_apply_theme(false)
	_apply_frame(0.0)


func _build() -> void:
	_bg = ColorRect.new()
	_bg.color = BG_DARK
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.clip_contents = false
	add_child(_stage)

	_lwing = _make_layer(DARK_LWING)
	_rwing = _make_layer(DARK_RWING)
	_body = _make_layer(DARK_BODY)
	_stage.add_child(_lwing)
	_stage.add_child(_rwing)
	_stage.add_child(_body)

	_word = _make_layer(WORDMARK)
	_word_mat = ShaderMaterial.new()
	_word_mat.shader = WORD_SHADER
	_word.material = _word_mat
	_stage.add_child(_word)

	_dust = CPUParticles2D.new()
	_dust.amount = 110
	_dust.one_shot = true
	_dust.explosiveness = 0.90
	_dust.lifetime = 1.9
	_dust.lifetime_randomness = 0.47
	_dust.randomness = 0.55
	_dust.local_coords = true
	_dust.emitting = false
	_dust.direction = Vector2(1.0, -0.12)
	_dust.spread = 22.0
	_dust.initial_velocity_min = 70.0
	_dust.initial_velocity_max = 220.0
	_dust.gravity = Vector2(16.0, -8.0)
	_dust.scale_amount_min = 0.14
	_dust.scale_amount_max = 0.32
	_dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust.color = Color(TEAL.r, TEAL.g, TEAL.b, 0.9)
	_dust.texture = _dust_texture()
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.05, Color(1, 1, 1, 1))
	fade.add_point(0.62, Color(1, 1, 1, 0.9))
	_dust.color_ramp = fade
	_stage.add_child(_dust)

	_mist = ColorRect.new()
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.color = Color.WHITE
	_mist.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = MIST_SHADER
	_mist_mat.set_shader_parameter("progress", 0.0)
	_mist_mat.set_shader_parameter("mist_color", BG_LIGHT)
	_mist_mat.set_shader_parameter("edge_color", Color(0.75, 0.93, 0.86, 1.0))
	_mist.material = _mist_mat
	add_child(_mist)

	_bar = ColorRect.new()
	_bar.color = Color(BONE.r, BONE.g, BONE.b, 0.28)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.visible = false
	add_child(_bar)
	_bar_fill = ColorRect.new()
	_bar_fill.color = GHOST
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_bar_fill)


func _make_layer(texture: Texture2D) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return layer


func _dust_texture() -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var center := Vector2(31.5, 31.5)
	for y in 64:
		for x in 64:
			var dist := Vector2(x, y).distance_to(center) / 32.0
			var alpha := clampf(1.0 - dist, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, alpha * alpha))
	return ImageTexture.create_from_image(image)


func _start_load() -> void:
	var err := ResourceLoader.load_threaded_request(_next, "", true)
	if err != OK:
		_load_done = true


func _poll_load() -> void:
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(_next, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if not progress.is_empty():
			_progress = clampf(float(progress[0]), 0.0, 1.0)
		_update_bar()
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_progress = 1.0
		_load_done = true
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		_progress = 1.0
		_load_done = true


func _apply_frame(anim_s: float) -> void:
	_layout()
	if not _swapped and anim_s >= WIPE_DUR * 0.5:
		_swapped = true
		_apply_theme(true)
	_apply_wings(anim_s)
	var wipe := clampf(anim_s / WIPE_DUR, 0.0, 1.0)
	_mist_mat.set_shader_parameter("progress", wipe)
	_place_dust(anim_s)
	if not _dust_on and anim_s >= BEAT_START + BEAT_DUR * 0.54:
		_dust_on = true
		_dust.restart()
		_dust.emitting = true


func _apply_theme(light: bool) -> void:
	_bg.color = BG_LIGHT if light else BG_DARK
	if light:
		_lwing.texture = LIGHT_LWING
		_rwing.texture = LIGHT_RWING
		_body.texture = LIGHT_BODY
		_lwing.material = null
		_rwing.material = null
		_body.material = null
		_word_mat.set_shader_parameter("ink", INK)
		_word_mat.set_shader_parameter("accent", TEAL)
		_dust.color = Color(TEAL.r, TEAL.g, TEAL.b, 0.85)
	else:
		_lwing.texture = DARK_LWING
		_rwing.texture = DARK_RWING
		_body.texture = DARK_BODY
		_lwing.material = _new_dark_mat()
		_rwing.material = _new_dark_mat()
		_body.material = _new_dark_mat()
		_word_mat.set_shader_parameter("ink", BONE)
		_word_mat.set_shader_parameter("accent", GHOST)
		_dust.color = Color(GHOST.r, GHOST.g, GHOST.b, 0.8)


func _new_dark_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = DARK_SHADER
	return mat


func _apply_wings(anim_s: float) -> void:
	var stage_size := _stage.size
	if stage_size.x < 2.0:
		return
	var t := (anim_s - BEAT_START) / BEAT_DUR
	_place_wing(_lwing, t, true, stage_size)
	_place_wing(_rwing, t - 0.025, false, stage_size)
	_body.size = stage_size
	_body.pivot_offset = stage_size * 0.5
	_body.scale = Vector2.ONE
	_body.rotation = 0.0
	_body.position = Vector2(0.0, _body_lift(t, stage_size.y))
	_word.size = stage_size
	_word.position = Vector2.ZERO
	_word.scale = Vector2.ONE
	_word.rotation = 0.0


func _place_wing(wing: TextureRect, t: float, is_left: bool, stage_size: Vector2) -> void:
	var pivot_n := LEFT_PIVOT if is_left else RIGHT_PIVOT
	var pivot := Vector2(pivot_n.x * stage_size.x, pivot_n.y * stage_size.y)
	wing.size = stage_size
	wing.pivot_offset = pivot
	var ang := _angle(t)
	var up := maxf(ang, 0.0) / PEAK
	var sx := cos(deg_to_rad(ang)) * (1.0 - 0.08 * up)
	wing.position = Vector2(0.0, _body_lift(t, stage_size.y))
	wing.scale = Vector2(maxf(sx, 0.02), 1.0)
	var rz := 2.5 * up * (1.0 if is_left else -1.0)
	wing.rotation = deg_to_rad(rz)


func _place_dust(anim_s: float) -> void:
	var stage_size := _stage.size
	if stage_size.x < 2.0:
		return
	## Changing emission extents after particles exist restarts the system
	## and wipes the ones already shed. Park the emitter once they start.
	if _dust_on:
		return
	var shed_end := BEAT_START + BEAT_DUR * 0.76
	if anim_s > shed_end:
		return
	var t := (anim_s - BEAT_START) / BEAT_DUR - 0.025
	var ang := _angle(t)
	var up := maxf(ang, 0.0) / PEAK
	var sx := cos(deg_to_rad(ang)) * (1.0 - 0.08 * up)
	var hinge := Vector2(RIGHT_PIVOT.x * stage_size.x, RIGHT_PIVOT.y * stage_size.y)
	var rest := Vector2(0.73 * stage_size.x, 0.34 * stage_size.y)
	var center := hinge + Vector2((rest.x - hinge.x) * sx, (rest.y - hinge.y))
	center.y += _body_lift(t, stage_size.y)
	_dust.position = center
	_dust.rotation = deg_to_rad(-2.5 * up)
	_dust.emission_rect_extents = Vector2(stage_size.x * 0.14 * maxf(sx, 0.2), stage_size.y * 0.16)


func _layout() -> void:
	if _stage == null:
		return
	var vp := _view_size()
	if vp.x < 8.0 or vp.y < 8.0:
		return
	# Fit the 1280x720 rig to the width, keep a margin, and shrink to the
	# height if a short viewport would crop it. Then centre the rig.
	var margin_x := vp.x * 0.06
	var margin_y := vp.y * 0.05
	var avail_w := maxf(8.0, vp.x - margin_x * 2.0)
	var avail_h := maxf(8.0, vp.y - margin_y * 2.0)
	var stage_w := avail_w
	var stage_h := stage_w * RIG_H / RIG_W
	if stage_h > avail_h:
		stage_h = avail_h
		stage_w = stage_h * RIG_W / RIG_H
	var left := (vp.x - stage_w) * 0.5
	var top := (vp.y - stage_h) * 0.5
	_stage.position = Vector2(left, top)
	_stage.size = Vector2(stage_w, stage_h)
	var bar_h := clampf(stage_h * 0.012, 3.0, 8.0)
	var bar_w := stage_w * 0.38
	# The wordmark ends near 86% of the canvas. Sit the bar just under it,
	# still inside the rig, so it cannot push the moth off centre or off screen.
	var bar_y := top + stage_h * (640.0 / RIG_H)
	_bar.position = Vector2(left + (stage_w - bar_w) * 0.5, bar_y)
	_bar.size = Vector2(bar_w, bar_h)
	_update_bar()


func _view_size() -> Vector2:
	var visible := get_viewport().get_visible_rect().size
	if visible.x >= 8.0 and visible.y >= 8.0:
		return visible
	return size


func _update_bar() -> void:
	if _bar == null:
		return
	_bar_fill.position = Vector2.ZERO
	_bar_fill.size = Vector2(_bar.size.x * clampf(_progress, 0.0, 1.0), _bar.size.y)


func _begin_fade() -> void:
	if _phase == 2 or _left or capture_hold != "":
		return
	_phase = 2
	_mount_next()
	var tween := create_tween()
	var dur := REDUCE_FADE if _reduce else FADE_DUR
	tween.tween_property(self, "modulate:a", 0.0, dur)
	tween.finished.connect(_finish_fade)


func _mount_next() -> void:
	if _menu != null:
		return
	var packed := _take_scene()
	if packed == null:
		return
	_menu = packed.instantiate()
	var tree := get_tree()
	tree.root.add_child(_menu)
	tree.root.move_child(_menu, get_index())
	z_as_relative = false
	z_index = 20


func _finish_fade() -> void:
	if _left:
		return
	_left = true
	if _menu != null:
		get_tree().current_scene = _menu
	queue_free()


func _request_skip() -> void:
	if _left or capture_hold != "":
		return
	_skip = true
	if _load_done:
		_jump_to_menu()


func _jump_to_menu() -> void:
	if _left or capture_hold != "":
		return
	_mount_next()
	_finish_fade()


func _take_scene() -> PackedScene:
	if _next == "":
		return null
	if ResourceLoader.has_cached(_next):
		var cached := ResourceLoader.load_threaded_get(_next)
		if cached is PackedScene:
			return cached
	if ResourceLoader.exists(_next):
		var loaded := load(_next)
		if loaded is PackedScene:
			return loaded
	return null


func _resolve_next() -> String:
	var chosen := next_scene_path.strip_edges()
	if chosen == "":
		chosen = _setting_string(NEXT_SETTING)
	if chosen == "":
		chosen = _setting_string(NEXT_FALLBACK)
	return chosen


func _setting_string(key: String) -> String:
	if not ProjectSettings.has_setting(key):
		return ""
	return str(ProjectSettings.get_setting(key)).strip_edges()


func _flap_scale() -> float:
	if _reduce:
		return REDUCE_FLAP_SCALE
	return 1.0


func _since(start_msec: int) -> float:
	return float(Time.get_ticks_msec() - start_msec) / 1000.0


func _is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


func _angle(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	if t < 0.48:
		return PEAK * _sine_in_out(pow(t / 0.48, 0.75))
	if t < 0.74:
		return PEAK + (-7.0 - PEAK) * _cubic_in_out(_seg(t, 0.48, 0.74))
	if t < 0.88:
		return -7.0 + 8.5 * _sine_in_out(_seg(t, 0.74, 0.88))
	return 1.5 - 1.5 * _sine_in_out(_seg(t, 0.88, 1.0))


func _body_lift(t: float, height: float) -> float:
	if t <= 0.5 or t >= 1.0:
		return 0.0
	return -height * 0.007 * sin(PI * _seg(t, 0.5, 1.0))


func _sine_in_out(x: float) -> float:
	return -(cos(PI * x) - 1.0) / 2.0


func _cubic_in_out(x: float) -> float:
	if x < 0.5:
		return 4.0 * x * x * x
	return 1.0 - pow(-2.0 * x + 2.0, 3.0) / 2.0


func _seg(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)
