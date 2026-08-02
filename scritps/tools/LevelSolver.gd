extends RefCounted
class_name LevelSolver

## BFS solvability search over PuzzleSim states.
## Only SCORE / SLIDE / MERGE advance the search. FAIL (life-loss bumps) never
## help clear a level once bounce-home rules are correct, so they are skipped.

const PuzzleSimScript := preload("res://scritps/tools/PuzzleSim.gd")

const MAX_STATES := 200000
const OUTCOME_NONE := 0
const OUTCOME_FAIL := 4
const OUTCOME_SCORE := 2


static func solve(config: LevelConfig, max_states: int = MAX_STATES) -> Dictionary:
	var sim = PuzzleSimScript.new()
	var start = sim.load_config(config)
	return solve_state(sim, start, max_states)


## After taking an obvious "bait" exit, the position should be unsolvable.
static func bait_traps(config: LevelConfig, block_index: int, direction: Vector2i) -> Dictionary:
	var sim = PuzzleSimScript.new()
	var start = sim.load_config(config)
	var applied: Dictionary = sim.apply_move(start, block_index, direction)
	if not bool(applied.get("ok", false)):
		return {"ok": false, "reason": "bait move not legal", "traps": false}
	if int(applied.get("outcome", OUTCOME_NONE)) != OUTCOME_SCORE:
		return {"ok": false, "reason": "bait move did not score", "traps": false}
	var after = applied.state
	var result: Dictionary = solve_state(sim, after)
	return {
		"ok": true,
		"traps": not bool(result.get("solvable", false)),
		"states_explored": result.get("states_explored", 0),
		"reason": (
			"bait leaves puzzle unsolvable"
			if not bool(result.get("solvable", false))
			else "bait still solvable — not a real trap"
		),
	}


static func solve_state(sim, start, max_states: int = MAX_STATES) -> Dictionary:
	if start.is_won():
		return {
			"solvable": true,
			"min_moves": 0,
			"states_explored": 0,
			"path": [],
			"used_fail": false,
		}

	var queue: Array = []
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var parent_action: Dictionary = {}

	var start_key: String = start.fingerprint()
	queue.append(start)
	visited[start_key] = true
	parent[start_key] = ""
	var explored := 0

	while not queue.is_empty() and explored < max_states:
		var state = queue.pop_front()
		explored += 1
		var state_key: String = state.fingerprint()
		if state.is_won():
			return {
				"solvable": true,
				"min_moves": _path_length(parent, state_key),
				"states_explored": explored,
				"path": _rebuild_path(parent, parent_action, state_key),
				"used_fail": false,
			}
		if state.is_lost():
			continue

		for action in sim.legal_actions(state):
			var result: Dictionary = sim.apply_move(
				state,
				int(action.block_index),
				action.direction as Vector2i
			)
			if not bool(result.get("ok", false)):
				continue
			var outcome: int = int(result.get("outcome", OUTCOME_NONE))
			if outcome == OUTCOME_NONE or outcome == OUTCOME_FAIL:
				continue
			var next_state = result.state
			var next_key: String = next_state.fingerprint()
			if visited.has(next_key):
				continue
			visited[next_key] = true
			parent[next_key] = state_key
			parent_action[next_key] = action
			queue.append(next_state)

	return {
		"solvable": false,
		"min_moves": -1,
		"states_explored": explored,
		"path": [],
		"used_fail": false,
	}


static func _path_length(parent: Dictionary, key: String) -> int:
	var n := 0
	var cur := key
	while parent.has(cur) and str(parent[cur]) != "":
		n += 1
		cur = str(parent[cur])
	return n


static func _rebuild_path(parent: Dictionary, parent_action: Dictionary, key: String) -> Array:
	var steps: Array = []
	var cur := key
	while parent.has(cur) and str(parent[cur]) != "":
		steps.push_front(parent_action.get(cur, {}))
		cur = str(parent[cur])
	return steps
