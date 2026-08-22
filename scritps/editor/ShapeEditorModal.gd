extends Control

signal confirmed(shape_name: String, kind: int, color: int)
signal deleted
signal cancelled

const BRAND_RAINBOW := preload("res://scritps/ui/BrandRainbow.gd")

@onready var title_label: Label = %TitleLabel
@onready var name_label: Label = %NameLabel
@onready var kind_label: Label = %KindLabel
@onready var color_label: Label = %ColorLabel
@onready var name_edit: LineEdit = %NameEdit
@onready var kind_option: OptionButton = %KindOption
@onready var color_option: OptionButton = %ColorOption
@onready var color_box: VBoxContainer = %ColorBox
@onready var confirm_button: MenuActionButton = %ConfirmButton
@onready var cancel_button: MenuActionButton = %CancelButton
@onready var delete_button: MenuActionButton = %DeleteButton

var _editing: bool = false
var _rainbow_hosts: Array[Control] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	UiTheme.style_chart_modal_copy(title_label)
	UiTheme.style_light_text_field(name_edit)
	_rainbow_hosts.append(name_edit)
	_populate_kind()
	_populate_color()
	UiTheme.style_light_option_field(kind_option)
	UiTheme.style_light_option_field(color_option)
	_rainbow_hosts.append(kind_option)
	_rainbow_hosts.append(color_option)
	kind_option.item_selected.connect(_on_kind_changed)
	cancel_button.pressed.connect(_on_cancel)
	confirm_button.pressed.connect(_on_confirm)
	delete_button.pressed.connect(_on_delete)
	$Overlay.gui_input.connect(_on_overlay_input)
	set_process(true)


func _process(delta: float) -> void:
	BRAND_RAINBOW.tick(delta)
	for host in _rainbow_hosts:
		if host == null or not is_instance_valid(host):
			continue
		var border := host.get_node_or_null("RainbowBorder") as ColorRect
		if border != null:
			UiTheme.sync_rainbow_border(border, host.size)


func show_create(default_name: String, kind: Block.BlockKind, color: Block.TileColor) -> void:
	_editing = false
	_apply_copy()
	title_label.text = tr("UI_CREATOR_SHAPE_MODAL_CREATE")
	confirm_button.set_label(tr("UI_CREATOR_SHAPE_MODAL_CONFIRM"))
	delete_button.visible = false
	_fill_fields(default_name, kind, color)
	visible = true
	_shrink_panel()
	name_edit.grab_focus()


func show_edit(shape_name: String, kind: Block.BlockKind, color: Block.TileColor) -> void:
	_editing = true
	_apply_copy()
	title_label.text = tr("UI_CREATOR_SHAPE_MODAL_EDIT")
	confirm_button.set_label(tr("UI_CREATOR_SHAPE_MODAL_SAVE"))
	delete_button.visible = true
	delete_button.set_label(tr("UI_CREATOR_GOAL_DELETE"))
	_fill_fields(shape_name, kind, color)
	visible = true
	_shrink_panel()


func hide_modal() -> void:
	visible = false


func _apply_copy() -> void:
	name_label.text = tr("UI_CREATOR_SHAPE_NAME")
	kind_label.text = tr("UI_CREATOR_SHAPE_TYPE")
	color_label.text = tr("UI_CREATOR_SHAPE_COLOR")
	cancel_button.set_label(tr("UI_CANCEL"))


func _fill_fields(shape_name: String, kind: Block.BlockKind, color: Block.TileColor) -> void:
	name_edit.text = shape_name
	_select_id(kind_option, int(kind))
	_select_id(color_option, int(color))
	_sync_color_enabled()


func _populate_kind() -> void:
	kind_option.clear()
	kind_option.add_item(tr("UI_CREATOR_KIND_STANDARD"), Block.BlockKind.STANDARD)
	kind_option.add_item(tr("UI_CREATOR_KIND_MERGE"), Block.BlockKind.MERGE)
	kind_option.add_item(tr("UI_CREATOR_KIND_WALL"), Block.BlockKind.WALL)


func _populate_color() -> void:
	color_option.clear()
	color_option.add_item(tr("UI_COLOR_RED"), Block.TileColor.RED)
	color_option.add_item(tr("UI_COLOR_GREEN"), Block.TileColor.GREEN)
	color_option.add_item(tr("UI_COLOR_BLUE"), Block.TileColor.BLUE)
	color_option.add_item(tr("UI_COLOR_YELLOW"), Block.TileColor.YELLOW)
	color_option.add_item(tr("UI_COLOR_PURPLE"), Block.TileColor.PURPLE)
	color_option.add_item(tr("UI_COLOR_ORANGE"), Block.TileColor.ORANGE)


func _select_id(option: OptionButton, id: int) -> void:
	for i in option.item_count:
		if option.get_item_id(i) == id:
			option.select(i)
			return
	if option.item_count > 0:
		option.select(0)


func _on_kind_changed(_index: int) -> void:
	_sync_color_enabled()


func _sync_color_enabled() -> void:
	var wall := kind_option.get_selected_id() == int(Block.BlockKind.WALL)
	color_option.disabled = wall
	color_box.modulate = Color(0.55, 0.55, 0.58, 0.7) if wall else Color.WHITE


func _shrink_panel() -> void:
	var panel := $Center/Panel as ChartModalPanel
	if panel == null:
		return
	await get_tree().process_frame
	panel.shrink_to_content()


func _on_confirm() -> void:
	var shape_name := name_edit.text.strip_edges()
	if shape_name.is_empty():
		shape_name = tr("UI_CREATOR_SHAPE_DEFAULT_NAME") % 1
	hide_modal()
	confirmed.emit(shape_name, kind_option.get_selected_id(), color_option.get_selected_id())


func _on_delete() -> void:
	hide_modal()
	deleted.emit()


func _on_cancel() -> void:
	hide_modal()
	cancelled.emit()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancel()
