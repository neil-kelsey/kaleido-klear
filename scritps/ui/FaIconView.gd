extends Control
class_name FaIconView

## Draws a Font Awesome glyph as tessellated vectors.

@export var icon_name: String = "arrow-left"
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()


func _draw() -> void:
	var h := minf(size.x, size.y)
	if h < 2.0:
		return
	FaVector.draw_named(self, icon_name, size * 0.5, h, icon_color)
