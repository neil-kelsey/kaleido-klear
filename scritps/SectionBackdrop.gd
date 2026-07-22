extends Node2D
class_name SectionBackdrop

## World-space section theme backdrop (pans/zooms with the camera).

const COVERAGE_SCALE := 3.2

var _sprite: Sprite2D


func _ready() -> void:
	z_index = -100
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	_layout()


func apply_section(section_index: int) -> void:
	var path := LevelCatalog.get_section_background(section_index)
	if path.is_empty() or not ResourceLoader.exists(path):
		_sprite.texture = null
		visible = false
		return
	var texture := load(path) as Texture2D
	_sprite.texture = texture
	visible = texture != null
	relayout()


func relayout() -> void:
	_layout()


func _on_viewport_size_changed() -> void:
	_layout()


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	position = viewport_size * 0.5
	if _sprite == null or _sprite.texture == null:
		return
	var tex_size := _sprite.texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var target := viewport_size * COVERAGE_SCALE
	var scale_x := target.x / tex_size.x
	var scale_y := target.y / tex_size.y
	# Cover the oversized area (may crop edges slightly)
	var s := maxf(scale_x, scale_y)
	_sprite.scale = Vector2(s, s)
