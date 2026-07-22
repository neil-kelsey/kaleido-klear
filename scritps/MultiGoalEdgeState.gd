extends RefCounted
class_name MultiGoalEdgeState

var phases: Array[GoalPhase] = []
var phase_index: int = 0
var scored_in_phase: int = 0


func _init(goal_phases: Array[GoalPhase] = []) -> void:
	phases = goal_phases


func is_finished() -> bool:
	return phase_index >= phases.size()


func current_phase() -> GoalPhase:
	if is_finished():
		return null
	return phases[phase_index]


func next_phase() -> GoalPhase:
	if is_finished() or phase_index + 1 >= phases.size():
		return null
	return phases[phase_index + 1]


func current_color() -> int:
	var phase: GoalPhase = current_phase()
	if phase == null:
		return -1
	return phase.color


func current_target() -> int:
	var phase: GoalPhase = current_phase()
	if phase == null:
		return 0
	if phase.unlimited:
		return 0
	return phase.count


func next_color() -> int:
	var phase: GoalPhase = next_phase()
	if phase == null:
		return -1
	return phase.color


func remaining_in_phase() -> int:
	if is_unlimited_phase():
		return 0
	return maxi(0, current_target() - scored_in_phase)


func is_unlimited_phase() -> bool:
	var phase: GoalPhase = current_phase()
	return phase != null and phase.unlimited


func record_score() -> void:
	if is_finished():
		return
	scored_in_phase += 1
	if is_unlimited_phase():
		return
	if scored_in_phase >= current_target():
		phase_index += 1
		scored_in_phase = 0


func get_display_state() -> Dictionary:
	if is_finished():
		return {
			"active": false,
			"base_color": Color.TRANSPARENT,
			"next_color": Color.TRANSPARENT,
			"progress": 0,
			"target": 0,
			"has_next_preview": false,
		}

	var phase: GoalPhase = current_phase()
	var upcoming: GoalPhase = next_phase()
	var base: Color = Block.get_color(phase.color as Block.TileColor)
	var preview: Color = Color.TRANSPARENT
	var has_preview: bool = upcoming != null
	if has_preview:
		preview = Block.get_color(upcoming.color as Block.TileColor)

	return {
		"active": true,
		"base_color": base,
		"next_color": preview,
		"progress": scored_in_phase,
		"target": phase.count if not phase.unlimited else 0,
		"has_next_preview": has_preview,
		"unlimited": phase.unlimited,
	}
