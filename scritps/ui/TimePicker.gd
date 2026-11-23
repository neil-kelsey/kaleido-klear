extends Control

## Hour and minute steppers for the daily reminder. Minutes move in 15-minute
## steps. OK saves. Cancel leaves the stored time alone. Styled like other
## Kaleido Klear chart-card modals.

signal confirmed(hour: int, minute: int)
signal cancelled

const Reminders := preload("res://scritps/StreakReminder.gd")

var _hour: int = 12
var _minute: int = 0
var _clock: Label
var _hour_value: Label
var _minute_value: Label
var _title: Label
var _hour_caption: Label
var _minute_caption: Label
var _ok: MenuActionButton
var _cancel: MenuActionButton
var _panel: ChartModalPanel


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 80
	_build()
	_apply_copy()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and visible:
		_apply_copy()


func open_at(hour: int, minute: int) -> void:
	_hour = Reminders.clamp_hour(hour)
	_minute = Reminders.snap_minute(minute)
	_apply_copy()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _panel != null:
		_panel.shrink_to_content()


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.016, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel()
	)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = ChartModalPanel.new()
	_panel.shrink_wrap = true
	_panel.custom_minimum_size = Vector2(720, 0)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 28)
	_panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)

	_clock = Label.new()
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_clock)

	box.add_child(_stepper_row(true))
	box.add_child(_stepper_row(false))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(actions)

	_cancel = MenuActionButton.new()
	_cancel.kind = MenuActionButton.Kind.SECONDARY
	_cancel.compact = true
	_cancel.show_trailing_icon = false
	_cancel.custom_minimum_size = Vector2(260, 112)
	_cancel.pressed.connect(_on_cancel)
	actions.add_child(_cancel)

	_ok = MenuActionButton.new()
	_ok.kind = MenuActionButton.Kind.PRIMARY
	_ok.compact = true
	_ok.show_trailing_icon = false
	_ok.custom_minimum_size = Vector2(260, 112)
	_ok.pressed.connect(_on_ok)
	actions.add_child(_ok)


func _stepper_row(hour_row: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var caption := Label.new()
	caption.custom_minimum_size = Vector2(220, 88)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hour_row:
		_hour_caption = caption
	else:
		_minute_caption = caption
	row.add_child(caption)

	var down := _step_button()
	down.pressed.connect(_step.bind(hour_row, -1))
	down.text = "−"
	row.add_child(down)

	var value := Label.new()
	value.custom_minimum_size = Vector2(120, 88)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if hour_row:
		_hour_value = value
	else:
		_minute_value = value
	row.add_child(value)

	var up := _step_button()
	up.pressed.connect(_step.bind(hour_row, 1))
	up.text = "+"
	row.add_child(up)
	return row


func _step_button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(88, 88)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.08, 0.05, 0.22, 1.0)
	face.set_corner_radius_all(44)
	var pressed := face.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.05, 0.03, 0.16, 1.0)
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", face)
	button.add_theme_stylebox_override("focus", face)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	button.add_theme_font_size_override("font_size", 48)
	button.add_theme_color_override("font_color", Color(0.97, 0.97, 0.985, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.97, 0.97, 0.985, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(0.97, 0.97, 0.985, 1.0))
	return button


func _apply_copy() -> void:
	if _title == null:
		return
	UiTheme.style_chart_modal_copy(_title, _clock)
	_title.text = tr("UI_REMINDER_TIME_LABEL")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.text = Reminders.format_clock(_hour, _minute)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiTheme.apply_label_font(_clock, 84, 64)
	_style_caption(_hour_caption, tr("UI_TIME_HOUR"))
	_style_caption(_minute_caption, tr("UI_TIME_MINUTE"))
	_style_value(_hour_value, "%02d" % _hour)
	_style_value(_minute_value, "%02d" % _minute)
	_ok.set_label(tr("UI_OK"))
	_cancel.set_label(tr("UI_CANCEL"))
	if _panel != null:
		_panel.shrink_to_content()


func _style_caption(label: Label, text: String) -> void:
	label.text = text
	UiTheme.style_settings_row_label(label)
	label.add_theme_color_override("font_color", Color(0.22, 0.18, 0.14, 0.78))


func _style_value(label: Label, text: String) -> void:
	label.text = text
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	UiTheme.apply_label_font(label, 48, 36)
	label.add_theme_color_override("font_color", Color(0.12, 0.10, 0.10, 1.0))


func _step(hour_row: bool, direction: int) -> void:
	if hour_row:
		_hour = Reminders.clamp_hour(_hour + direction)
	else:
		var steps: Array[int] = [0, 15, 30, 45]
		var index := steps.find(_minute)
		if index < 0:
			index = 0
		index = posmod(index + direction, steps.size())
		_minute = steps[index]
	_apply_copy()


func _on_ok() -> void:
	var hour := _hour
	var minute := _minute
	close()
	confirmed.emit(hour, minute)


func _on_cancel() -> void:
	close()
	cancelled.emit()
