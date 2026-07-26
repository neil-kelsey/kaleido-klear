extends SceneTree

## Run once:
##   Godot --headless --path <project> -s res://scritps/tools/bake_level_star_chart.gd

const Baker = preload("res://scritps/tools/StarChartBaker.gd")


func _initialize() -> void:
	print("Baking level star chart…")
	var err: Error = Baker.bake_level_chart_and_save()
	if err == OK:
		print("Saved ", Baker.LEVEL_OUTPUT_PATH)
	else:
		push_error("Failed to save level star chart, error=%s" % err)
	quit()
