extends Node2D
class_name SwipeHintOverlay

## Press/hold swipe-direction chevrons.
## Parent under Blocks as first child (z_index 0) so hints draw above the
## playfield ColorRects and underneath tiles.

const CHEVRON_COLOR := Color(0.86, 0.88, 0.94, 1.0)
const CHEVRON_SPACING_RATIO := 0.44
const CHEVRON_DEPTH_RATIO := 0.28
const CHEVRON_HALF_WIDTH_RATIO := 0.36
## Cap visual width at ~2 cells so 3+ wide faces don't stretch the V.
const MAX_CROSS_CELLS := 2
const STROKE_RATIO := 0.17
const SCROLL_SPEED_RATIO := 0.28
const FADE_DISTANCE_CELLS := 3.4
## Peak opacity after the short spawn fade-in.
const NEAR_ALPHA := 0.14
const FAR_ALPHA := 0.0
## Distance over which a new chevron fades 0 → peak (fraction of a cell).
const SPAWN_FADE_RATIO := 0.42

var _active := false
var _corridors: Array[Dictionary] = []
var _cell_size: float = 64.0


func show_hints(corridors: Array[Dictionary], cell_size: float) -> void:
	_corridors = corridors
	_cell_size = maxf(cell_size, 1.0)
	_active = not corridors.is_empty()
	visible = true
	set_process(_active)
	queue_redraw()


func clear_hints() -> void:
	_active = false
	_corridors.clear()
	set_process(false)
	queue_redraw()


func _process(_delta: float) -> void:
	if _active:
		queue_redraw()


func _draw() -> void:
	if not _active or _corridors.is_empty():
		return

	var spacing := _cell_size * CHEVRON_SPACING_RATIO
	var depth := _cell_size * CHEVRON_DEPTH_RATIO
	var stroke := maxf(2.5, _cell_size * STROKE_RATIO)
	var scroll_speed := _cell_size * SCROLL_SPEED_RATIO
	var fade_distance := _cell_size * FADE_DISTANCE_CELLS
	var spawn_fade := _cell_size * SPAWN_FADE_RATIO
	var scroll := fposmod(Time.get_ticks_msec() / 1000.0 * scroll_speed, spacing)

	for corridor in _corridors:
		_draw_corridor(corridor, spacing, depth, stroke, scroll, fade_distance, spawn_fade)


func _draw_corridor(
	corridor: Dictionary,
	spacing: float,
	depth: float,
	stroke: float,
	scroll: float,
	fade_distance: float,
	spawn_fade: float
) -> void:
	var direction: Vector2 = corridor["direction"]
	var origin: Vector2 = corridor["origin"]
	var length: float = float(corridor["length"])
	if length < 4.0:
		return

	var cross_cells: int = mini(int(corridor.get("cross_cells", 1)), MAX_CROSS_CELLS)
	var half_width := _cell_size * CHEVRON_HALF_WIDTH_RATIO * float(maxi(cross_cells, 1))
	var side := Vector2(-direction.y, direction.x)
	var index_end := int(ceil(length / spacing)) + 2

	for index in range(-1, index_end + 1):
		var along := float(index) * spacing + scroll
		if along < 0.0 or along > length - stroke * 0.5:
			continue

		var alpha := _alpha_at_distance(along, fade_distance, length, spawn_fade)
		if alpha < 0.02:
			continue

		var center := origin + direction * along
		var tip := center + direction * (depth * 0.5)
		var back := center - direction * (depth * 0.5)
		var left := back - side * half_width
		var right := back + side * half_width

		var color := CHEVRON_COLOR
		color.a = alpha
		draw_polyline(PackedVector2Array([left, tip, right]), color, stroke, true)


func _alpha_at_distance(
	along: float,
	fade_distance: float,
	length: float,
	spawn_fade: float
) -> float:
	# Quick fade-in as the chevron emerges from the tile.
	var spawn_t := 1.0
	if spawn_fade > 0.0:
		spawn_t = clampf(along / spawn_fade, 0.0, 1.0)
		spawn_t = spawn_t * spawn_t * (3.0 - 2.0 * spawn_t) # smoothstep

	# Existing gentle fade-out with distance.
	var distance_fade := 1.0 - clampf(along / maxf(fade_distance, 1.0), 0.0, 1.0)
	var end_soft := minf(_cell_size * 0.4, length * 0.3)
	var end_fade := 1.0
	if end_soft > 0.0 and along > length - end_soft:
		end_fade = clampf((length - along) / end_soft, 0.0, 1.0)

	var t := spawn_t * distance_fade * distance_fade * end_fade
	return lerpf(FAR_ALPHA, NEAR_ALPHA, t)
