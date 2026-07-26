extends Node

## Routes Android system back / Escape to the current screen's handle_back().


func _ready() -> void:
	## Without this, Android edge-swipe back quits the app immediately.
	get_tree().quit_on_go_back = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		request_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		request_back()
		get_viewport().set_input_as_handled()


func request_back() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("handle_back"):
		scene.handle_back()
