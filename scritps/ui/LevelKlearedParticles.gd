extends Control

## Draws the diamond burst for LevelKlearedOverlay (behind the brand).

func _draw() -> void:
	var host := get_parent()
	if host != null and host.has_method("draw_particles_on"):
		host.draw_particles_on(self)
