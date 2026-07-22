extends Resource
class_name LevelConfig

@export var level_id: String = "standard_demo"
@export var level_name_key: String = "UI_DEMO_LEVEL_STANDARD"
@export var display_name: String = ""
@export var section_index: int = 0
## Lower values appear earlier within a dimension. Creator saves use unix time.
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
