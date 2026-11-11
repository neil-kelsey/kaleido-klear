extends Control
class_name TutorialClip

## Looping card-inset video (Ogg Theora) with a dark playfield surround.

const BG := Color(2.0 / 255.0, 2.0 / 255.0, 4.0 / 255.0, 1.0)
const RADIUS := 20
const CLIP_SIZES := {
	"res://assets/tutorials/colour_mix_preview.ogv": Vector2(1040, 720),
	"res://assets/tutorials/colour_mix_score.ogv": Vector2(1080, 1216),
	"res://assets/tutorials/arrows.ogv": Vector2(1080, 1100),
}

var content_size: Vector2 = Vector2(1080, 840)

var _bg: Panel
var _player: VideoStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_bg = Panel.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.set_corner_radius_all(RADIUS)
	_bg.add_theme_stylebox_override("panel", style)
	add_child(_bg)

	_player = VideoStreamPlayer.new()
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player.expand = true
	_player.volume_db = -80.0
	_player.finished.connect(_on_finished)
	add_child(_player)
	resized.connect(_fit_player)


func content_aspect() -> float:
	if content_size.y <= 1.0:
		return 1.5
	return content_size.x / content_size.y


func set_stream_path(path: String) -> void:
	if _player == null:
		return
	_player.stop()
	if path.is_empty():
		visible = false
		_player.stream = null
		custom_minimum_size = Vector2.ZERO
		return
	visible = true
	if CLIP_SIZES.has(path):
		content_size = CLIP_SIZES[path]
	var stream := load(path)
	_player.stream = stream
	_player.play()
	_fit_player()
	call_deferred("_fit_player")


func _on_finished() -> void:
	if visible and _player.stream != null:
		_player.play()


func _fit_player() -> void:
	if _player == null or size.x <= 1.0 or size.y <= 1.0:
		return
	var tex: Texture2D = _player.get_video_texture()
	if tex != null:
		var tex_size := tex.get_size()
		if tex_size.x > 1.0 and tex_size.y > 1.0:
			content_size = tex_size
	var aspect := content_aspect()
	var view := size
	var play_size := view
	if view.x / view.y > aspect:
		play_size = Vector2(view.y * aspect, view.y)
	else:
		play_size = Vector2(view.x, view.x / aspect)
	_player.position = (view - play_size) * 0.5
	_player.size = play_size
