extends Control
class_name LevelDetailsModal

signal play_pressed(level: LevelConfig)
signal closed

const LevelDifficultyScript := preload("res://scritps/tools/LevelDifficulty.gd")

@onready var title_label: Label = %TitleLabel
@onready var close_button: Button = %CloseButton
@onready var difficulty_label: Label = %DifficultyLabel
@onready var par_label: Label = %ParLabel
@onready var par_value: Label = %ParValue
@onready var best_moves_label: Label = %BestMovesLabel
@onready var best_moves_value: Label = %BestMovesValue
@onready var best_time_label: Label = %BestTimeLabel
@onready var best_time_value: Label = %BestTimeValue
@onready var play_button: MenuActionButton = %PlayButton
@onready var panel: Control = $Center/Panel

var _level: LevelConfig = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_close_button(close_button)
	UiTheme.style_chart_modal_copy(title_label)
	title_label.add_theme_font_size_override("font_size", 44)
	_style_stat_label(difficulty_label, 52, UiTheme.TEXT)
	_style_stat_label(par_label, 32, UiTheme.TEXT_MUTED)
	_style_stat_label(best_moves_label, 32, UiTheme.TEXT_MUTED)
	_style_stat_label(best_time_label, 32, UiTheme.TEXT_MUTED)
	_style_stat_label(par_value, 36, UiTheme.TEXT)
	_style_stat_label(best_moves_value, 36, UiTheme.TEXT)
	_style_stat_label(best_time_value, 36, UiTheme.TEXT)
	close_button.pressed.connect(hide_modal)
	play_button.pressed.connect(_on_play_pressed)
	var overlay := get_node_or_null("Overlay") as Control
	if overlay != null:
		overlay.gui_input.connect(_on_overlay_gui_input)
	_apply_translations()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_apply_translations()
		if visible and _level != null:
			show_level(_level)


func _style_stat_label(label: Label, size_px: int, color: Color) -> void:
	label.add_theme_font_override("font", UiTheme.BUTTON_FONT)
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)


func _apply_translations() -> void:
	if par_label != null:
		par_label.text = tr("UI_LEVEL_STAT_PAR")
	if best_moves_label != null:
		best_moves_label.text = tr("UI_LEVEL_STAT_BEST_MOVES")
	if best_time_label != null:
		best_time_label.text = tr("UI_LEVEL_STAT_BEST_TIME")
	if play_button != null:
		play_button.set_label(tr("UI_PLAY_LEVEL"))
	HintTooltip.bind(close_button, tr("UI_CLOSE"))


func show_level(level: LevelConfig) -> void:
	_level = level
	_apply_translations()
	if level == null:
		return
	title_label.text = LevelCatalog.get_level_label(level)
	difficulty_label.text = LevelDifficultyScript.label_for(level)
	var dash := tr("UI_LEVEL_STAT_DASH")
	if level.min_moves >= 0:
		par_value.text = str(level.min_moves)
	else:
		par_value.text = dash
	var completed := GameSession.is_level_completed(level.level_id)
	var best_moves := GameSession.get_level_best_moves(level.level_id)
	var best_time := GameSession.get_level_best_time_ms(level.level_id)
	best_moves_value.text = str(best_moves) if completed and best_moves > 0 else dash
	best_time_value.text = (
		GameSession.format_play_time(best_time) if completed and best_time > 0 else dash
	)
	visible = true
	await get_tree().process_frame
	if panel != null and panel.has_method("shrink_to_content"):
		panel.shrink_to_content()


func hide_modal() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			hide_modal()
	elif event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			hide_modal()


func _on_play_pressed() -> void:
	var level := _level
	hide_modal()
	if level != null:
		play_pressed.emit(level)
