extends Node

## Lightweight one-shot SFX helper (autoload).

const ERROR_STREAM := preload("res://assets/audio/error.wav")
const SWOOSH_STREAM := preload("res://assets/audio/swoosh.wav")
const FAIL_STREAM := preload("res://assets/audio/fail.wav")

var _error_player: AudioStreamPlayer
var _swoosh_player: AudioStreamPlayer
var _fail_player: AudioStreamPlayer


func _ready() -> void:
	_error_player = _make_player("ErrorPlayer", ERROR_STREAM, -4.0)
	_swoosh_player = _make_player("SwooshPlayer", SWOOSH_STREAM, -14.0)
	_fail_player = _make_player("FailPlayer", FAIL_STREAM, -2.0)


func _make_player(player_name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	player.bus = "Master"
	add_child(player)
	return player


func play_bump() -> void:
	## Wrong move — solid puck hit.
	Haptics.medium()
	if _error_player == null:
		return
	_error_player.pitch_scale = 1.0
	_error_player.play()


func play_swoosh() -> void:
	if _swoosh_player == null:
		return
	_swoosh_player.pitch_scale = randf_range(0.96, 1.05)
	_swoosh_player.play()


func play_fail() -> void:
	## Level failed — leave a beat after the puck so they don't collide.
	if _fail_player == null:
		return
	await get_tree().create_timer(0.45).timeout
	if _fail_player == null:
		return
	_fail_player.pitch_scale = 1.0
	_fail_player.play()
