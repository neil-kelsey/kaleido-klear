extends Resource
class_name LevelConfig

@export var level_id: String = "standard_demo"
@export var level_name_key: String = "UI_DEMO_LEVEL_STANDARD"
@export var display_name: String = ""
@export var section_index: int = 0
## YYYY-MM-DD when this level is a daily puzzle. Empty = campaign dimension level.
@export var daily_date: String = ""
## Lower values appear earlier within a dimension / daily day. Creator saves use unix time.
@export var sort_index: int = 1000
@export var columns: int = 8
@export var rows: int = 8

@export var goal_left_color: Block.TileColor = Block.TileColor.RED
@export var goal_top_color: Block.TileColor = Block.TileColor.BLUE
@export var goal_right_color: Block.TileColor = Block.TileColor.GREEN
@export var goal_bottom_color: Block.TileColor = Block.TileColor.YELLOW

@export var multi_goal_mode: bool = false
@export var goal_left_phases: Array[GoalPhase] = []
@export var goal_top_phases: Array[GoalPhase] = []
@export var goal_right_phases: Array[GoalPhase] = []
@export var goal_bottom_phases: Array[GoalPhase] = []

@export var goal_left_enabled: bool = true
@export var goal_top_enabled: bool = true
@export var goal_right_enabled: bool = true
@export var goal_bottom_enabled: bool = false

@export var disabled_cells: Array[Vector2i] = []

@export var block_positions: Array[Vector2i] = []
@export var block_colors: Array[Block.TileColor] = []
@export var block_shapes: Array[String] = []
@export var block_kinds: Array[Block.BlockKind] = []
@export var block_cell_patterns: Array = []
@export var block_shape_names: Array[String] = []

@export_group("Level select grouping")
## Localization key for an in-dimension chapter header (e.g. UI_GROUP_BASIC_TRAINING).
## Empty = no header; levels with the same key stay in one group.
@export var group_title_key: String = ""

@export_group("Automation / curation")
## True when a headless solver (or creator playtest) has cleared this level.
@export var verified_solvable: bool = false
## Shortest known clear length from the solver (-1 = unknown).
@export var min_moves: int = -1
## Heuristic complexity used to place levels into dimensions.
@export var difficulty_score: float = 0.0
## 1 (tutorial-easy) … 5 (late-game hard).
@export_range(0, 5, 1) var difficulty_tier: int = 0
