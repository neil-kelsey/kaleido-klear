extends Control

## "Level / Kleared" sting with diamond confetti, then stars and continue actions.

signal next_level_pressed
signal remove_ads_pressed
signal share_pressed
signal closed

const ICON_TEX := preload("res://assets/branding/kaleido_klear_icon_512.png")
const ICON_KEY := preload("res://assets/shaders/brand_icon_key.gdshader")

const KLEAR_TO_LEVEL_RATIO := 0.68
const ICON_WIDTH_RATIO := 0.42
const SIDE_MARGIN_RATIO := 0.16
const MAX_LEVEL_FONT := 140
const MIN_ICON := 148.0
const MAX_ICON := 220.0

const LOGO_IN := 0.40
const RESULTS_DELAY := 0.55
const RESULTS_FADE := 0.32

const STAR_FILLED_COLOR := Color(0.98, 0.82, 0.2, 1.0)
const STAR_EMPTY_COLOR := Color(1.0, 1.0, 1.0, 0.38)
const STAR_FONT_SIZE := 140

const BURST_COUNT := 58
const SPARKLE_COUNT := 18
const MAX_FALL_SEC := 16.0
const LAYER_STING := 100

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
@onready var content: MarginContainer = %Content
@onready var playtest_message: Label = %PlaytestMessage
@onready var stars_row: HBoxContainer = %StarsRow
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var next_level_button: MenuActionButton = %NextLevelButton
@onready var remove_ads_button: MenuActionButton = %RemoveAdsButton
@onready var share_button: MenuActionButton = %ShareButton

var _bits: Array[Dictionary] = []
var _open := false
var _results_shown := false
var _playtest_mode := false
var _playing_particles := false
var _elapsed := 0.0
var _gravity := 2100.0
var _brand_tween: Tween = null
var _results_tween: Tween = null
var _results_timer: SceneTreeTimer = null


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_icon_key()
	_apply_translations()
	_hide_results_now()
	_set_results_interactive(false)
	resized.connect(_fit_action_pad)
	_fit_action_pad()
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		if visible:
			_fit_brand()


func is_blocking() -> bool:
	return _open


func play() -> void:
	_open = true
	_results_shown = false
	_playing_particles = false
	_elapsed = 0.0
	_bits.clear()
	brand_root.visible = not _playtest_mode
	brand_root.modulate = Color(1, 1, 1, 0)
	brand_root.scale = Vector2(0.86, 0.86)
	_hide_results_now()
	visible = true
	_set_canvas_layer(LAYER_STING)
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(false)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = true
	_apply_translations()
	_fit_brand()
	_fit_action_pad()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _open or not is_inside_tree():
		return
	_center_brand_pivot()
	brand_root.scale = Vector2(0.86, 0.86)
	if not _playtest_mode:
		_spawn_burst()
		_playing_particles = true
		set_process(true)
		if particle_layer != null:
			particle_layer.queue_redraw()
		Haptics.medium()
		Sfx.play_swoosh()
		_play_brand_motion()
		_arm_results_timer()
	else:
		_reveal_results()


func show_result(stars: int, section_complete: bool = false, has_next_section: bool = false) -> void:
	_playtest_mode = false
	_set_standard_layout(true)
	if section_complete:
		if has_next_section:
			next_level_button.label_text = tr("UI_PLAY_NEXT_SECTION")
		else:
			next_level_button.label_text = tr("UI_CONTINUE")
	else:
		next_level_button.label_text = tr("UI_NEXT_LEVEL")
	remove_ads_button.label_text = tr("UI_REMOVE_ADS")
	share_button.label_text = tr("UI_SHARE")
	_set_star(star_1, stars >= 1)
	_set_star(star_2, stars >= 2)
	_set_star(star_3, stars >= 3)


func show_playtest_success() -> void:
	_playtest_mode = true
	_set_standard_layout(false)
	playtest_message.text = "%s\n%s" % [tr("UI_PLAYTEST_SUCCESS_TITLE"), tr("UI_PLAYTEST_SUCCESS_MESSAGE")]
	next_level_button.label_text = tr("UI_BACK_TO_LEVEL_CREATOR")
	play()


func hide_overlay() -> void:
	if not _open:
		return
	_open = false
	_results_shown = false
	_playtest_mode = false
	_kill_brand_tween()
	_kill_results_tween()
	_clear_results_timer()
	_set_results_interactive(false)
	blocker.visible = false
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_playing_particles = false
	_bits.clear()
	set_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED
	if particle_layer != null:
		particle_layer.queue_redraw()


func handle_back() -> void:
	if not _open:
		return
	hide_overlay()
	closed.emit()


func skip_brand() -> void:
	handle_back()


func _play_brand_motion() -> void:
	_kill_brand_tween()
	_brand_tween = create_tween()
	_brand_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_brand_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_brand_tween.set_parallel(true)
	_brand_tween.tween_property(brand_root, "modulate:a", 1.0, LOGO_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_brand_tween.tween_property(brand_root, "scale", Vector2.ONE, LOGO_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _arm_results_timer() -> void:
	_clear_results_timer()
	if get_tree() == null:
		return
	_results_timer = get_tree().create_timer(RESULTS_DELAY, true, true, true)
	_results_timer.timeout.connect(_reveal_results, CONNECT_ONE_SHOT)


func _clear_results_timer() -> void:
	if _results_timer != null:
		if _results_timer.timeout.is_connected(_reveal_results):
			_results_timer.timeout.disconnect(_reveal_results)
		_results_timer = null


func _reveal_results() -> void:
	if _results_shown or not _open:
		return
	_results_shown = true
	_clear_results_timer()
	if brand_root.visible:
		brand_root.modulate.a = 1.0
		brand_root.scale = Vector2.ONE
	var targets := _result_controls()
	for node in targets:
		node.visible = true
		node.modulate = Color(1, 1, 1, 0)
	_set_results_interactive(true)
	_kill_results_tween()
	_results_tween = create_tween()
	_results_tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	_results_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_results_tween.set_parallel(true)
	for node in targets:
		_results_tween.tween_property(node, "modulate:a", 1.0, RESULTS_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _hide_results_now() -> void:
	_results_shown = false
	_set_results_interactive(false)
	for node in _result_controls():
		node.modulate = Color(1, 1, 1, 0)


func _result_controls() -> Array[Control]:
	var nodes: Array[Control] = [next_level_button]
	if _playtest_mode:
		nodes.append(playtest_message)
	else:
		nodes.append(stars_row)
		nodes.append(remove_ads_button)
		nodes.append(share_button)
	return nodes


func _set_standard_layout(standard: bool) -> void:
	brand_root.visible = standard
	stars_row.visible = standard
	remove_ads_button.visible = standard
	share_button.visible = standard
	playtest_message.visible = not standard


func _set_results_interactive(enabled: bool) -> void:
	var filter := Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	next_level_button.mouse_filter = filter
	remove_ads_button.mouse_filter = filter
	share_button.mouse_filter = filter
	next_level_button.disabled = not enabled
	remove_ads_button.disabled = not enabled
	share_button.disabled = not enabled


func _set_canvas_layer(layer_idx: int) -> void:
	var canvas := get_parent() as CanvasLayer
	if canvas != null:
		canvas.layer = layer_idx


func _process(delta: float) -> void:
	if not _playing_particles:
		return
	_elapsed += delta
	_step_bits(delta)
	if particle_layer != null:
		particle_layer.queue_redraw()
	if _elapsed > MAX_FALL_SEC:
		_bits.clear()
	if _bits.is_empty():
		_playing_particles = false
		if particle_layer != null:
			particle_layer.queue_redraw()
		if not _open:
			set_process(false)


func _apply_translations() -> void:
	if hero_title == null or subtitle_title == null:
		return
	hero_title.set_title(tr("UI_KLEARED_PRIMARY"))
	subtitle_title.set_title(tr("UI_KLEARED_SECONDARY"))
	if playtest_message != null:
		playtest_message.text = "%s\n%s" % [tr("UI_PLAYTEST_SUCCESS_TITLE"), tr("UI_PLAYTEST_SUCCESS_MESSAGE")]
	if not is_node_ready():
		return
	if _playtest_mode:
		next_level_button.label_text = tr("UI_BACK_TO_LEVEL_CREATOR")
	elif next_level_button != null and not _open:
		next_level_button.label_text = tr("UI_NEXT_LEVEL")
		remove_ads_button.label_text = tr("UI_REMOVE_ADS")
		share_button.label_text = tr("UI_SHARE")


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


func _center_brand_pivot() -> void:
	if brand_root == null:
		return
	brand_root.pivot_offset = brand_root.size * 0.5


func _fit_action_pad() -> void:
	## Pull the sting up now hearts are gone, and keep CTAs clear of the HUD cluster.
	if content == null:
		return
	content.add_theme_constant_override("margin_top", int(round(_title_top_clearance())))
	content.add_theme_constant_override("margin_bottom", int(round(_hud_bottom_clearance())))


func _title_top_clearance() -> float:
	var insets := UiTheme.viewport_safe_insets(get_viewport())
	return insets.y + float(GoalBorder.BAR_WIDTH) + GoalBorder.BADGE_H + 16.0


func _hud_bottom_clearance() -> float:
	var insets := UiTheme.viewport_safe_insets(get_viewport())
	return (
		insets.w
		+ float(GoalBorder.BAR_WIDTH)
		+ GoalBorder.BADGE_H
		+ 12.0
		+ float(UiTheme.CIRCLE_BUTTON_EMPHASIS_SIZE)
		+ 56.0
	)


func _spawn_origin() -> Vector2:
	if brand_icon != null and brand_icon.is_inside_tree():
		return brand_icon.get_global_rect().get_center() - global_position
	return get_viewport_rect().size * Vector2(0.5, 0.28)


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


func _kill_results_tween() -> void:
	if _results_tween != null and is_instance_valid(_results_tween):
		_results_tween.kill()
	_results_tween = null


func _set_star(star_label: Label, filled: bool) -> void:
	star_label.text = "★"
	star_label.add_theme_font_size_override("font_size", STAR_FONT_SIZE)
	star_label.add_theme_color_override(
		"font_color",
		STAR_FILLED_COLOR if filled else STAR_EMPTY_COLOR
	)
	if filled:
		star_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.05, 0.0, 0.45))
		star_label.add_theme_constant_override("shadow_offset_y", 6)
	else:
		star_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.25))
		star_label.add_theme_constant_override("shadow_offset_y", 4)


func _on_next_level_button_pressed() -> void:
	next_level_pressed.emit()


func _on_remove_ads_button_pressed() -> void:
	remove_ads_pressed.emit()


func _on_share_button_pressed() -> void:
	share_pressed.emit()


func _on_blocker_gui_input(event: InputEvent) -> void:
	if not _open:
		return
	if not _is_dismiss_press(event):
		return
	handle_back()
	blocker.accept_event()


func _is_dismiss_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


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
