extends Node2D
class_name NebulaEffect

## Reusable nebula fill — same bake + twinkle as the landing-screen CTA.
## Use apply_to_control() on TextureRect buttons, or add this node and
## call configure_diamond() / configure_rect() for world-space shapes.

const SHADER := preload("res://assets/shaders/nebula.gdshader")
const BACKDROP_SHADER := preload("res://assets/shaders/nebula_backdrop.gdshader")
const FILL := preload("res://scritps/ui/NebulaFill.gd")

const MASK_NONE := 0
const MASK_ROUNDED_RECT := 1
const MASK_DIAMOND := 2

var _sprite: Sprite2D
var _mat: ShaderMaterial
var _mask_mode: int = MASK_DIAMOND
var _rect_size: Vector2 = Vector2(128, 128)
var _corner_radius: float = 40.0
var _brightness: float = 1.0
var _wash_out: float = 0.0
var _modulate: Color = Color.WHITE
var _pulse: bool = true
var _fx_time: float = 0.0


static func make_material(mask_mode: int = MASK_ROUNDED_RECT) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("mask_mode", mask_mode)
	mat.set_shader_parameter("brightness", 1.0)
	mat.set_shader_parameter("wash_out", 0.0)
	mat.set_shader_parameter("time_sec", 0.0)
	mat.set_shader_parameter("opacity", 1.0)
	return mat


## Landing / Control buttons: stretch the baked nebula into a TextureRect.
static func apply_to_control(target: TextureRect, corner_radius_px: float) -> ShaderMaterial:
	target.texture = FILL.texture()
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_SCALE
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var mat := make_material(MASK_ROUNDED_RECT)
	mat.set_shader_parameter("corner_radius_px", corner_radius_px)
	target.material = mat
	return mat


## Level-select night sky — same bake, dedicated dark/cover shader.
static func apply_backdrop(target: TextureRect) -> ShaderMaterial:
	target.texture = FILL.texture()
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_SCALE
	target.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP_SHADER
	mat.set_shader_parameter("brightness", 1.12)
	mat.set_shader_parameter("time_sec", 0.0)
	mat.set_shader_parameter("ink", 0.34)
	var tex := FILL.texture()
	if tex != null:
		mat.set_shader_parameter("tex_size", tex.get_size())
	target.material = mat
	return mat


static func attach_diamond(parent: Node) -> NebulaEffect:
	var fx := NebulaEffect.new()
	parent.add_child(fx)
	return fx


static func diamond_points(center: Vector2, size: float) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		center + Vector2(0, -half),
		center + Vector2(half, 0),
		center + Vector2(0, half),
		center + Vector2(-half, 0),
	])


## Soft layered outline glow in the dimension / selection colour.
static func draw_selection_glow(item: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var scales := [1.14, 1.24, 1.34]
	var alphas := [0.6, 0.35, 0.16]
	var widths := [4.5, 6.5, 8.5]
	for i in scales.size():
		var pts := diamond_points(center, size * scales[i])
		item.draw_polyline(
			pts + PackedVector2Array([pts[0]]),
			Color(color.r, color.g, color.b, alphas[i]),
			widths[i],
			true
		)


func _ready() -> void:
	show_behind_parent = true
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture = FILL.texture()
	_mat = make_material(_mask_mode)
	_sprite.material = _mat
	add_child(_sprite)
	_sync()
	set_process(true)


func _process(delta: float) -> void:
	_fx_time += delta
	if _mat == null:
		return
	_mat.set_shader_parameter("time_sec", _fx_time)
	if not _pulse:
		return
	var breathe := 0.97 + 0.03 * sin(_fx_time * 0.55)
	_mat.set_shader_parameter("brightness", _brightness * breathe)


func configure_diamond(
	center: Vector2,
	diamond_size: float,
	brightness: float = 1.0,
	pulse: bool = true,
	modulate: Color = Color.WHITE,
	wash_out: float = 0.0
) -> void:
	position = center
	_mask_mode = MASK_DIAMOND
	_rect_size = Vector2(diamond_size, diamond_size)
	_brightness = brightness
	_pulse = pulse
	_modulate = modulate
	_wash_out = wash_out
	_sync()


func configure_rect(center: Vector2, size: Vector2, corner_radius: float, brightness: float = 1.0, pulse: bool = true) -> void:
	position = center
	_mask_mode = MASK_ROUNDED_RECT
	_rect_size = size
	_corner_radius = corner_radius
	_brightness = brightness
	_pulse = pulse
	_sync()


func _sync() -> void:
	if _sprite == null or _mat == null:
		return
	_mat.set_shader_parameter("mask_mode", _mask_mode)
	_mat.set_shader_parameter("rect_size", _rect_size)
	_mat.set_shader_parameter("corner_radius_px", _corner_radius)
	_mat.set_shader_parameter("brightness", _brightness)
	_mat.set_shader_parameter("wash_out", _wash_out)
	_mat.set_shader_parameter("opacity", _modulate.a)
	if _sprite != null:
		_sprite.modulate = Color(_modulate.r, _modulate.g, _modulate.b, 1.0)
	var tex := _sprite.texture
	if tex == null:
		return
	var tex_size := tex.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	_sprite.scale = Vector2(_rect_size.x / tex_size.x, _rect_size.y / tex_size.y)
