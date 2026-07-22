extends SceneTree

## Run once:
##   Godot --headless --path <project> -s res://scritps/tools/bake_star_chart.gd

const Baker = preload("res://scritps/tools/StarChartBaker.gd")


func _initialize() -> void:
	print("Baking dimension star chart…")
	var err: Error = Baker.bake_and_save()
	if err == OK:
		print("Saved ", Baker.OUTPUT_PATH)
	else:
		push_error("Failed to save star chart, error=%s" % err)
	quit()
