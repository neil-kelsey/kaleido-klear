extends RefCounted
class_name BrandRainbow

## Single source for Kaleido rainbow scroll + materials.
## Title shaders and button borders both consume this phase / palette.

const TITLE_SHADER := preload("res://assets/shaders/brand_title.gdshader")
const BORDER_SHADER := preload("res://assets/shaders/rainbow_border.gdshader")

## Matches BrandTitleLine's default scroll so surfaces stay in sync.
const SCROLL_SPEED := 0.035

static var phase: float = 0.0
static var _tick_frame: int = -1


## Advance once per engine frame; safe to call from many nodes.
static func tick(delta: float) -> float:
	var frame := Engine.get_process_frames()
	if frame != _tick_frame:
		_tick_frame = frame
		phase = fposmod(phase + delta * SCROLL_SPEED, 1.0)
	return phase


static func make_title_material(mode: int = 0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = TITLE_SHADER
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("phase", phase)
	return mat


static func make_border_material(
	corner_radius_px: float = 40.0,
	border_width_px: float = 3.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BORDER_SHADER
	mat.set_shader_parameter("phase", phase)
	mat.set_shader_parameter("corner_radius_px", corner_radius_px)
	mat.set_shader_parameter("border_width_px", border_width_px)
	return mat


static func sync_material(mat: ShaderMaterial) -> void:
	if mat != null:
		mat.set_shader_parameter("phase", phase)
