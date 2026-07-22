extends RefCounted
class_name BlockShapes

const SINGLE := "single"
const LINE_2 := "line_2"
const LINE_3 := "line_3"
const L_SHAPE := "l_shape"


static func get_cells(shape_id: String) -> Array[Vector2i]:
	match shape_id:
		LINE_2:
			return [Vector2i(0, 0), Vector2i(1, 0)]
		LINE_3:
			return [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
		L_SHAPE:
			return [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
		_:
			return [Vector2i(0, 0)]


static func all_builtin_ids() -> Array[String]:
	return [SINGLE, LINE_2, LINE_3, L_SHAPE]
