extends Control
class_name BrandTitleLine

## Logo-style title with Montserrat ExtraBold + scrolling rainbow.
## Soft glow/shadow are layered offset copies (reliable across renderers).

enum Style { RAINBOW_FILL, WHITE_RAINBOW_GLOW }

const SHADER := preload("res://assets/shaders/brand_title.gdshader")
const LOGO_FONT := preload("res://assets/fonts/Montserrat-ExtraBold.ttf")

@export var title_text: String = "Kaleido"
@export var style: Style = Style.RAINBOW_FILL
@export var font_size: int = 72
@export var scroll_speed: float = 0.035
@export var glow_strength: float = 0.9
@export var effect_radius: float = 14.0

var _phase: float = 0.0
var _font: Font
var _viewport: SubViewport
var _label: Label
var _layer_root: Control
var _fill_rect: TextureRect
var _fill_mat: ShaderMaterial
var _effect_mats: Array[ShaderMaterial] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_font = LOGO_FONT
	_build()
	_refresh()
	set_process(true)


func _process(delta: float) -> void:
	_phase = fposmod(_phase + delta * scroll_speed, 1.0)
	_fill_mat.set_shader_parameter("phase", _phase)
	for mat in _effect_mats:
		mat.set_shader_parameter("phase", _phase)


func set_title(text: String) -> void:
	title_text = text
	_refresh()


## Grow/shrink font so the word nearly fills [target_width] (glow padding excluded).
func fit_to_width(target_width: float) -> void:
	if _font == null:
		_font = LOGO_FONT
	var usable := maxf(target_width, 32.0)
	var lo := 24
	var hi := 320
	var best := font_size
	while lo <= hi:
		var mid := (lo + hi) >> 1
		var width := _font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, mid).x
		if width <= usable:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	font_size = best
	# Keep glow/shadow proportional to type size (tighter for hero readability)
	effect_radius = maxf(float(font_size) * 0.14, 10.0)
	_refresh()


## Match another title's scale (e.g. Klear from Kaleido).
func match_scale(reference_font_size: int, ratio: float) -> void:
	font_size = maxi(int(round(float(reference_font_size) * ratio)), 16)
	effect_radius = maxf(float(font_size) * 0.2, 12.0)
	_refresh()


func _build() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_2d = Viewport.MSAA_4X
	add_child(_viewport)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_constant_override("outline_size", 0)
	_label.text = title_text
	_viewport.add_child(_label)

	_layer_root = Control.new()
	_layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layer_root)

	_fill_mat = ShaderMaterial.new()
	_fill_mat.shader = SHADER

	_rebuild_effect_layers()

	_fill_rect = _make_rect(_fill_mat, Color.WHITE)
	add_child(_fill_rect)


func _clear_effect_layers() -> void:
	for child in _layer_root.get_children():
		child.queue_free()
	_effect_mats.clear()


func _make_rect(mat: ShaderMaterial, modulate: Color) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.texture = _viewport.get_texture()
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	rect.material = mat
	rect.modulate = modulate
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _add_effect_copy(offset: Vector2, alpha: float, mode: int) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("phase", _phase)
	_effect_mats.append(mat)
	var rect := _make_rect(mat, Color(1, 1, 1, alpha))
	rect.position = offset
	_layer_root.add_child(rect)


func _rebuild_effect_layers() -> void:
	_clear_effect_layers()
	match style:
		Style.RAINBOW_FILL:
			# Soft, light drop shadow — tighter spread for contrast on white.
			_fill_mat.set_shader_parameter("mode", 0)
			var rings := 8
			for ring in rings:
				var t := float(ring + 1) / float(rings)
				var radius := effect_radius * pow(t, 0.9) * 1.05
				var alpha := 0.032 * glow_strength * exp(-t * 2.8)
				var spokes := 12 + ring
				for s in spokes:
					var ang := TAU * float(s) / float(spokes) + float(ring) * 0.11
					var offset := Vector2(cos(ang), sin(ang)) * radius + Vector2(0.0, effect_radius * 0.22)
					_add_effect_copy(offset, alpha, 3)
		Style.WHITE_RAINBOW_GLOW:
			# Soft neon aura: larger, thinner layers so it fades instead of forming a bubble.
			_fill_mat.set_shader_parameter("mode", 2)
			var rings := 11
			for ring in rings:
				var t := float(ring + 1) / float(rings)
				var radius := effect_radius * pow(t, 0.9) * 1.4
				var alpha := 0.048 * glow_strength * exp(-t * 2.9)
				var spokes := 15 + ring
				for s in spokes:
					var ang := TAU * float(s) / float(spokes) + float(ring) * 0.08
					var offset := Vector2(cos(ang), sin(ang)) * radius
					_add_effect_copy(offset, alpha, 0)


func _refresh() -> void:
	if _label == null:
		return

	_label.add_theme_font_override("font", _font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.text = title_text
	_rebuild_effect_layers()

	# Keep horizontal room for glow, but don't inflate vertical gaps between titles/icon.
	var pad_x := maxf(effect_radius * 2.6, 28.0)
	var pad_y := maxf(effect_radius * 0.7, 8.0)
	var text_size := _font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var vp_size := Vector2i(
		maxi(int(ceil(text_size.x + pad_x * 2.0)), 8),
		maxi(int(ceil(text_size.y + pad_y * 2.0)), 8)
	)
	custom_minimum_size = Vector2(vp_size)
	size = Vector2(vp_size)
	_viewport.size = vp_size
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_viewport):
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
