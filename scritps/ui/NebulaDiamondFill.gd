extends Node2D
class_name NebulaDiamondFill

## Diamond-shaped nebula fill (same bake/twinkle language as primary CTAs).
## Parent should draw theme glow + outline on top (keep this at z_index -1).

const NEBULA_SHADER := preload("res://assets/shaders/diamond_nebula.gdshader")
const NEBULA_FILL := preload("res://scritps/ui/NebulaFill.gd")

var _poly: Polygon2D
var _mat: ShaderMaterial
var _size: float = 96.0
var _fx_time: float = 0.0


func _ready() -> void:
	z_index = -1
	z_as_relative = true
	_poly = Polygon2D.new()
	_poly.texture = NEBULA_FILL.texture()
	_poly.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_mat = ShaderMaterial.new()
	_mat.shader = NEBULA_SHADER
	_mat.set_shader_parameter("brightness", 1.0)
	_mat.set_shader_parameter("time_sec", 0.0)
	_poly.material = _mat
	add_child(_poly)
	_rebuild_polygon()
	set_process(true)


func _process(delta: float) -> void:
	_fx_time += delta
	if _mat != null:
		_mat.set_shader_parameter("time_sec", _fx_time)


func configure(center: Vector2, diamond_size: float, brightness: float = 1.0) -> void:
	position = center
	_size = maxf(diamond_size, 8.0)
	if _mat != null:
		_mat.set_shader_parameter("brightness", brightness)
		_mat.set_shader_parameter("rect_size", Vector2(_size, _size))
	if _poly != null:
		_rebuild_polygon()


func _rebuild_polygon() -> void:
	var half := _size * 0.5
	_poly.polygon = PackedVector2Array([
		Vector2(0, -half),
		Vector2(half, 0),
		Vector2(0, half),
		Vector2(-half, 0),
	])
	## Map the axis-aligned bounds of the diamond into 0..1 UVs.
	_poly.uv = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5),
	])
