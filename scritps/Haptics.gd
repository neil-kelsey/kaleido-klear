extends Node

## Handheld vibration helpers (Android / iOS). No-op on desktop.

## Lightest tick — tile press.
const LIGHT_DURATION_MS := 10
const LIGHT_AMPLITUDE := 0.12

## Clearer pulse — swipe commit / failed impact.
const MEDIUM_DURATION_MS := 32
const MEDIUM_AMPLITUDE := 0.48


func light() -> void:
	_vibrate(LIGHT_DURATION_MS, LIGHT_AMPLITUDE)


func medium() -> void:
	_vibrate(MEDIUM_DURATION_MS, MEDIUM_AMPLITUDE)


func _vibrate(duration_ms: int, amplitude: float) -> void:
	Input.vibrate_handheld(duration_ms, amplitude)
