extends SceneTree

## Headless checks for the Goals sequence modal. Run:
##   godot --headless --path . -s res://scritps/tools/goals_info_modal_checks.gd
##
## Do not type-hint GoalsInfoModal (or other UI classes that mention autoloads
## at parse time). --script compiles this file before autoloads are bound.

var _fails := 0
var _passes := 0


func _check(cond: bool, label: String) -> void:
	if cond:
		_passes += 1
		print("PASS ", label)
	else:
		_fails += 1
		printerr("FAIL ", label)


func _initialize() -> void:
	print("goals_info_modal_checks: start")
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://scenes/ui/goals_info_modal.tscn") as PackedScene
	_check(packed != null, "goals_info_modal.tscn loads")
	if packed == null:
		_finish()
		return

	var modal: Control = packed.instantiate()
	root.add_child(modal)
	if not modal.is_node_ready():
		await modal.ready
	print("goals_info_modal_checks: modal ready")

	var overlay := modal.get_node_or_null("Overlay") as Control
	var center := modal.get_node_or_null("Center") as Control
	var panel := modal.get_node_or_null("Center/Panel") as Control
	var close_button := modal.get_node_or_null("%CloseButton") as Button
	_check(overlay != null, "overlay exists")
	_check(center != null, "center container exists")
	_check(panel != null, "panel exists")
	_check(close_button != null, "close button exists")
	_check(modal.mouse_filter == Control.MOUSE_FILTER_STOP, "root stops input (no fall-through)")
	_check(
		overlay != null and overlay.mouse_filter == Control.MOUSE_FILTER_STOP,
		"overlay stops input"
	)
	_check(
		center != null and center.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"center ignores so backdrop taps reach the overlay"
	)
	_check(
		panel != null and panel.mouse_filter == Control.MOUSE_FILTER_STOP,
		"panel stops so a tap inside the modal is not a close"
	)
	_check(modal.has_method("_on_overlay_gui_input"), "overlay input handler exists")
	_check(modal.has_method("hide_modal"), "hide_modal exists")
	_check(modal.has_signal("closed"), "closed signal exists")

	var closed_count := [0]
	if modal.has_signal("closed"):
		modal.connect("closed", func() -> void: closed_count[0] += 1)

	var dummy := {
		"left": [{"color": 0, "unlimited": false, "count": 2, "status": "current", "scored": 0}],
		"top": [],
		"right": [{"color": 2, "unlimited": false, "count": 2, "status": "current", "scored": 0}],
		"bottom": [{"color": 1, "unlimited": false, "count": 1, "status": "current", "scored": 0}],
	}
	await modal.show_overview(dummy)
	_check(modal.visible, "show_overview makes the modal visible")

	# A tap inside the panel must not close it. Overlay never sees this event
	# because the panel stops it — emit on the panel and stay open.
	var inside := _mouse(false, panel.get_global_rect().get_center())
	panel.gui_input.emit(inside)
	_check(modal.visible, "tap inside the panel does not close")
	_check(closed_count[0] == 0, "tap inside does not emit closed")

	# Backdrop / outside tap (mouse release) closes.
	modal._on_overlay_gui_input(_mouse(false, Vector2(8, 8)))
	_check(not modal.visible, "tap on the dim backdrop closes the modal")
	_check(closed_count[0] == 1, "backdrop tap emits closed once")

	# Screen-touch release also closes.
	await modal.show_overview(dummy)
	_check(modal.visible, "modal can be opened again")
	var touch := InputEventScreenTouch.new()
	touch.pressed = false
	touch.position = Vector2(8, 8)
	modal._on_overlay_gui_input(touch)
	_check(not modal.visible, "touch release on the backdrop closes the modal")
	_check(closed_count[0] == 2, "touch close emits closed")

	# X still works.
	await modal.show_overview(dummy)
	close_button.pressed.emit()
	_check(not modal.visible, "X / close button still closes the modal")
	_check(closed_count[0] == 3, "close button emits closed")

	# hide_modal is idempotent (no extra closed signal).
	modal.hide_modal()
	_check(closed_count[0] == 3, "hide_modal while hidden does not re-emit closed")

	# A press (not release) on the overlay must not close, so a press cannot
	# uncover the board before the release is handled by Main._input.
	await modal.show_overview(dummy)
	modal._on_overlay_gui_input(_mouse(true, Vector2(8, 8)))
	_check(modal.visible, "overlay press does not close (close is on release)")
	modal.hide_modal()
	_check(closed_count[0] == 4, "cleanup hide after press-only test")

	# Main already returns early from _input while this modal is visible, so
	# board swipes cannot start. Confirm that guard is still in the script.
	var main_src := FileAccess.get_file_as_string("res://scritps/Main.gd")
	_check(
		main_src.contains("if goals_info_modal != null and goals_info_modal.visible"),
		"Main._input still guards board input while the goals modal is open"
	)

	modal.queue_free()
	_finish()


func _mouse(pressed: bool, pos: Vector2) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev


func _finish() -> void:
	print("goals_info_modal_checks: %d passed, %d failed" % [_passes, _fails])
	quit(1 if _fails > 0 else 0)
