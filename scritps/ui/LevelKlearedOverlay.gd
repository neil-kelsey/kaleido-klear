extends Control

## Brief "Level / Kleared" brand sting with diamond confetti, then the result modal.

signal brand_finished

const ICON_TEX := preload("res://assets/branding/kaleido_klear_icon_512.png")
const ICON_KEY := preload("res://assets/shaders/brand_icon_key.gdshader")

const KLEAR_TO_LEVEL_RATIO := 0.68
const ICON_WIDTH_RATIO := 0.50
const SIDE_MARGIN_RATIO := 0.16
const MAX_LEVEL_FONT := 122
const MIN_ICON := 168.0
const MAX_ICON := 260.0
## Shift the brand cluster up from true centre (fraction of viewport height).
const BRAND_LIFT_RATIO := 0.10

const LOGO_IN := 0.40
const LOGO_HOLD := 3.10
const LOGO_OUT := 0.50
const BRAND_DURATION := LOGO_IN + LOGO_HOLD + LOGO_OUT

const BURST_COUNT := 58
const SPARKLE_COUNT := 18
const MAX_FALL_SEC := 16.0
const LAYER_STING := 8
const LAYER_BEHIND_MODAL := 2

const DIAMOND_COLORS := [
	Color(0.00, 0.72, 0.92),
	Color(0.22, 0.42, 0.95),
	Color(0.68, 0.24, 0.95),
	Color(0.95, 0.18, 0.62),
	Color(0.95, 0.45, 0.12),
	Color(0.92, 0.72, 0.08),
	Color(0.12, 0.78, 0.38),
	Color(0.42, 0.92, 0.22),
]

@onready var blocker: ColorRect = %Blocker
@onready var brand_root: Control = %BrandRoot
@onready var hero_title: BrandTitleLine = %HeroTitle
@onready var subtitle_title: BrandTitleLine = %SubtitleTitle
@onready var brand_icon: TextureRect = %BrandIcon
@onready var particle_layer: Control = %ParticleLayer

var _bits: Array[Dictionary] = []
var _brand_visible := false
var _brand_done := false
var _playing := false
var _elapsed := 0.0
var _gravity := 2100.0
var _brand_tween: Tween = null
var _brand_timer: SceneTreeTimer = null


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_key()
	_apply_translations()
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		if visible:
			_fit_brand()


func is_blocking() -> bool:
	return _brand_visible


func play() -> void:
	_playing = true
	_brand_visible = true
	_brand_done = false
	_elapsed = 0.0
	_bits.clear()
	visible = true
	_set_canvas_layer(LAYER_STING)
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	_arm_brand_timer()
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = true
	brand_root.visible = true
	brand_root.modulate = Color(1, 1, 1, 0)
	brand_root.scale = Vector2(0.86, 0.86)
	_apply_translations()
	_fit_brand()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _playing or not _brand_visible or not is_inside_tree():
		return
	_center_brand_pivot()
	brand_root.scale = Vector2(0.86, 0.86)
	_spawn_burst()
	if particle_layer != null:
		particle_layer.queue_redraw()
	Haptics.medium()
	Sfx.play_swoosh()
	_play_brand_motion()


func _play_brand_motion() -> void:
	_kill_brand_tween()
	_brand_tween = create_tween()
	_brand_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_brand_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_brand_tween.set_parallel(true)
	_brand_tween.tween_property(brand_root, "modulate:a", 1.0, LOGO_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_brand_tween.tween_property(brand_root, "scale", Vector2.ONE, LOGO_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_brand() -> void:
	_finish_brand()


func skip_brand() -> void:
	if not _brand_visible:
		return
	_kill_brand_tween()
	_clear_brand_timer()
	_finish_brand()


func _arm_brand_timer() -> void:
	_clear_brand_timer()
	if get_tree() == null:
		return
	_brand_timer = get_tree().create_timer(BRAND_DURATION, true, true, true)
	_brand_timer.timeout.connect(_finish_brand, CONNECT_ONE_SHOT)


func _clear_brand_timer() -> void:
	if _brand_timer != null:
		if _brand_timer.timeout.is_connected(_finish_brand):
			_brand_timer.timeout.disconnect(_finish_brand)
		_brand_timer = null


func _set_canvas_layer(layer_idx: int) -> void:
	var canvas := get_parent() as CanvasLayer
	if canvas != null:
		canvas.layer = layer_idx


func _finish_brand() -> void:
	if _brand_done:
		return
	_brand_done = true
	_brand_visible = false
	_kill_brand_tween()
	_clear_brand_timer()
	brand_root.visible = false
	blocker.visible = false
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Drop behind the result modal. Leftover diamonds keep falling underneath.
	_set_canvas_layer(LAYER_BEHIND_MODAL)
	brand_finished.emit()


func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta
	_step_bits(delta)
	if particle_layer != null:
		particle_layer.queue_redraw()
	if _brand_visible and _elapsed >= LOGO_IN + LOGO_HOLD and brand_root.visible:
		_fade_brand_out()
	if _brand_done and _bits.is_empty():
		_stop()
	elif _elapsed > MAX_FALL_SEC:
		_bits.clear()
		_stop()


func _fade_brand_out() -> void:
	if _brand_tween != null and is_instance_valid(_brand_tween) and _brand_tween.is_running():
		return
	_kill_brand_tween()
	if brand_root == null or not brand_root.visible:
		return
	_brand_tween = create_tween()
	_brand_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_brand_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_brand_tween.set_parallel(true)
	_brand_tween.tween_property(brand_root, "modulate:a", 0.0, LOGO_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_brand_tween.tween_property(brand_root, "scale", Vector2(0.94, 0.94), LOGO_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _stop() -> void:
	_playing = false
	_brand_visible = false
	_clear_brand_timer()
	set_process(false)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_bits.clear()
	if particle_layer != null:
		particle_layer.queue_redraw()


func _apply_translations() -> void:
	if hero_title == null or subtitle_title == null:
		return
	hero_title.set_title(tr("UI_KLEARED_PRIMARY"))
	subtitle_title.set_title(tr("UI_KLEARED_SECONDARY"))


func _apply_icon_key() -> void:
	if brand_icon == null:
		return
	brand_icon.texture = ICON_TEX
	var mat := ShaderMaterial.new()
	mat.shader = ICON_KEY
	brand_icon.material = mat


func _fit_brand() -> void:
	if hero_title == null or subtitle_title == null:
		return
	var vp := get_viewport_rect().size
	var usable := maxf(vp.x * (1.0 - SIDE_MARGIN_RATIO * 2.0), 120.0)
	hero_title.fit_to_width(usable)
	if hero_title.font_size > MAX_LEVEL_FONT:
		hero_title.font_size = MAX_LEVEL_FONT
		hero_title.effect_radius = maxf(float(hero_title.font_size) * 0.14, 10.0)
		hero_title.set_title(hero_title.title_text)
	subtitle_title.match_scale(hero_title.font_size, KLEAR_TO_LEVEL_RATIO)
	if brand_icon != null:
		var icon_size := clampf(usable * ICON_WIDTH_RATIO, MIN_ICON, MAX_ICON)
		brand_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_lift_brand()


func _lift_brand() -> void:
	if brand_root == null:
		return
	var lift := get_viewport_rect().size.y * BRAND_LIFT_RATIO
	brand_root.offset_top = 0.0
	brand_root.offset_bottom = -lift * 2.0


func _center_brand_pivot() -> void:
	if brand_root == null:
		return
	brand_root.pivot_offset = brand_root.size * 0.5


func _spawn_origin() -> Vector2:
	if brand_icon != null and brand_icon.is_inside_tree():
		return brand_icon.get_global_rect().get_center() - global_position
	return get_viewport_rect().size * 0.5


func _spawn_burst() -> void:
	_bits.clear()
	var origin := _spawn_origin()
	var vp := get_viewport_rect().size
	_gravity = maxf(vp.y * 0.55, 420.0)
	var scale := maxf(vp.y / 915.0, 0.85)
	for i in BURST_COUNT:
		_bits.append(_make_bit(origin, scale, false))
	for i in SPARKLE_COUNT:
		_bits.append(_make_bit(origin, scale, true))


func _make_bit(origin: Vector2, scale: float, sparkle: bool) -> Dictionary:
	var angle := randf() * TAU
	if randf() < 0.62:
		angle = lerp_angle(angle, -PI * 0.5, randf_range(0.35, 0.88))
	var speed := randf_range(280.0, 680.0) * scale
	if sparkle:
		speed *= randf_range(0.55, 0.9)
	var vel := Vector2.from_angle(angle) * speed
	vel.y -= randf_range(80.0, 280.0) * scale
	var length := randf_range(22.0, 46.0) * scale
	if sparkle:
		length *= randf_range(0.38, 0.58)
	var width := length * randf_range(0.18, 0.30)
	if sparkle:
		width = length * randf_range(0.32, 0.46)
	var color: Color = DIAMOND_COLORS[randi() % DIAMOND_COLORS.size()]
	if sparkle:
		color = Color(1.0, 1.0, 1.0, 0.96)
	return {
		"pos": origin + vel.normalized() * randf_range(4.0, 18.0),
		"vel": vel,
		"rot": vel.angle() + PI * 0.5,
		"length": length,
		"width": width,
		"color": color,
		"sparkle": sparkle,
	}


func _step_bits(delta: float) -> void:
	var vp := get_viewport_rect().size
	var pad := 90.0
	var next: Array[Dictionary] = []
	for bit in _bits:
		var vel: Vector2 = bit.vel
		vel.y += _gravity * delta
		vel *= exp(-0.55 * delta)
		bit.vel = vel
		bit.pos = bit.pos + vel * delta
		if vel.length() > 28.0:
			var align := vel.angle() + PI * 0.5
			bit.rot = lerp_angle(bit.rot, align, 1.0 - exp(-14.0 * delta))
		var pos: Vector2 = bit.pos
		if pos.y < vp.y + pad and pos.x > -pad and pos.x < vp.x + pad:
			next.append(bit)
	_bits = next


func _kill_brand_tween() -> void:
	if _brand_tween != null and is_instance_valid(_brand_tween):
		_brand_tween.kill()
	_brand_tween = null


func draw_particles_on(item: CanvasItem) -> void:
	for bit in _bits:
		_draw_diamond(item, bit)


func _draw_diamond(item: CanvasItem, bit: Dictionary) -> void:
	var pos: Vector2 = bit.pos
	var rot: float = bit.rot
	var half_l: float = bit.length * 0.5
	var half_w: float = bit.width * 0.5
	var local := PackedVector2Array([
		Vector2(0.0, -half_l),
		Vector2(half_w, 0.0),
		Vector2(0.0, half_l),
		Vector2(-half_w, 0.0),
	])
	var pts := PackedVector2Array()
	var cs := cos(rot)
	var sn := sin(rot)
	for p in local:
		pts.append(pos + Vector2(p.x * cs - p.y * sn, p.x * sn + p.y * cs))
	var color: Color = bit.color
	var shadow := Color(0.05, 0.06, 0.1, 0.28)
	var shadow_pts := PackedVector2Array()
	var shadow_off := Vector2(0.0, bit.length * 0.08)
	for p in pts:
		shadow_pts.append(p + shadow_off)
	item.draw_colored_polygon(shadow_pts, shadow)
	if bit.sparkle:
		var glow := color
		glow.a = 0.22
		var glow_pts := PackedVector2Array()
		for p in local:
			var q := p * 1.55
			glow_pts.append(pos + Vector2(q.x * cs - q.y * sn, q.x * sn + q.y * cs))
		item.draw_colored_polygon(glow_pts, glow)
	item.draw_colored_polygon(pts, color)
