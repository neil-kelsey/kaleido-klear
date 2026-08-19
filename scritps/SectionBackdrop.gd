extends Node2D
class_name SectionBackdrop

## In-level sky: same nebula as level select (no star-chart overlay).

var _nebula_bg: TextureRect
var _nebula_mat: ShaderMaterial
var _fx_time := 0.0


func _ready() -> void:
	z_index = -100
	_ensure_nebula_layer()
	set_process(true)


func _process(delta: float) -> void:
	_fx_time += delta
	if _nebula_mat != null and _nebula_bg != null:
		_nebula_mat.set_shader_parameter("time_sec", _fx_time)
		_nebula_mat.set_shader_parameter("rect_size", _nebula_bg.size)
		var pulse := 0.99 + 0.01 * sin(_fx_time * 0.25)
		_nebula_mat.set_shader_parameter("brightness", pulse)


func apply_section(_section_index: int) -> void:
	visible = true


func focus_on(_world_point: Vector2) -> void:
	pass


func relayout() -> void:
	pass


func _ensure_nebula_layer() -> void:
	if _nebula_bg != null and is_instance_valid(_nebula_bg):
		return
	var layer := CanvasLayer.new()
	layer.layer = -1
	layer.name = "SkyLayer"
	add_child(layer)

	var night := ColorRect.new()
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night.color = Color(0.01, 0.01, 0.016, 1)
	layer.add_child(night)

	_nebula_bg = TextureRect.new()
	_nebula_bg.name = "NebulaBg"
	_nebula_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nebula_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nebula_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_nebula_bg.stretch_mode = TextureRect.STRETCH_SCALE
	layer.add_child(_nebula_bg)
	_nebula_mat = NebulaEffect.apply_backdrop(_nebula_bg)
