extends Control

signal next_level_pressed
signal remove_ads_pressed
signal share_pressed
signal closed

const STAR_FILLED_COLOR := Color(0.98, 0.82, 0.2, 1.0)
const STAR_EMPTY_COLOR := Color(0.35, 0.36, 0.4, 1.0)

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var stars_row: HBoxContainer = %StarsRow
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var next_level_button: Button = %NextLevelButton
@onready var remove_ads_button: Button = %RemoveAdsButton
@onready var share_button: Button = %ShareButton
@onready var close_button: Button = %CloseButton

var _playtest_mode: bool = false


func _ready() -> void:
	visible = false
	_apply_translations()
	UiTheme.style_menu_button(next_level_button)
	UiTheme.style_menu_button(remove_ads_button)
	UiTheme.style_menu_button(share_button)
	UiTheme.style_close_button(close_button)
	close_button.tooltip_text = tr("UI_CLOSE")


func _apply_translations() -> void:
	title_label.text = tr("UI_LEVEL_COMPLETE")
	next_level_button.text = tr("UI_NEXT_LEVEL")
	remove_ads_button.text = tr("UI_REMOVE_ADS")
	share_button.text = tr("UI_SHARE")


func show_result(stars: int, section_complete: bool = false, has_next_section: bool = false) -> void:
	_playtest_mode = false
	_set_standard_layout_visible(true)
	if section_complete:
		title_label.text = tr("UI_SECTION_COMPLETE")
		if has_next_section:
			next_level_button.text = tr("UI_PLAY_NEXT_SECTION")
		else:
			next_level_button.text = tr("UI_CONTINUE")
	else:
		title_label.text = tr("UI_LEVEL_COMPLETE")
		next_level_button.text = tr("UI_NEXT_LEVEL")
	remove_ads_button.text = tr("UI_REMOVE_ADS")
	share_button.text = tr("UI_SHARE")
	_set_star(star_1, stars >= 1)
	_set_star(star_2, stars >= 2)
	_set_star(star_3, stars >= 3)
	visible = true


func show_playtest_success() -> void:
	_playtest_mode = true
	_set_standard_layout_visible(false)
	title_label.text = tr("UI_PLAYTEST_SUCCESS_TITLE")
	message_label.text = tr("UI_PLAYTEST_SUCCESS_MESSAGE")
	next_level_button.text = tr("UI_BACK_TO_LEVEL_CREATOR")
	visible = true


func hide_modal() -> void:
	_playtest_mode = false
	visible = false


func _set_standard_layout_visible(standard: bool) -> void:
	stars_row.visible = standard
	remove_ads_button.visible = standard
	share_button.visible = standard
	message_label.visible = not standard


func _on_close_button_pressed() -> void:
	if _playtest_mode:
		_on_next_level_button_pressed()
		return
	hide_modal()
	closed.emit()


func _set_star(star_label: Label, filled: bool) -> void:
	star_label.text = "★"
	star_label.add_theme_color_override(
		"font_color",
		STAR_FILLED_COLOR if filled else STAR_EMPTY_COLOR
	)


func _on_next_level_button_pressed() -> void:
	next_level_pressed.emit()


func _on_remove_ads_button_pressed() -> void:
	remove_ads_pressed.emit()


func _on_share_button_pressed() -> void:
	share_pressed.emit()
