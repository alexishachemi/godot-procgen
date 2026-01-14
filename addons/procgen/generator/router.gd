extends RefCounted

const BSP = preload("bsp.gd")
const Context = preload("context.gd")

var grid: AStar = AStar.new()
var ctx: Context

var points: Array[Vector2i]


func _init():
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN


func generate(context: Context, bsp: BSP):
	var rooms = bsp.get_all_rooms()
	ctx = context
	points = []
	grid.region = bsp.rect
	grid.update()
	for room in rooms:
		discourage_room(room)
	for link in bsp.graph.final_links:
		grid.restart()
		route_rooms(link[0].room_rect, link[1].room_rect)


func route_rooms(from: Rect2i, to: Rect2i):
	var path: Array[Vector2i] = grid.get_id_path(from.get_center(), to.get_center())
	path = path.filter(func(x): return not from.has_point(x) and not to.has_point(x))
	for point in path:
		if grid.get_point_weight_scale(point) == 1.0:
			grid.set_point_weight_scale(point, 0.5)
	points.append_array(path)


func discourage_room(room: Rect2i):
	grid.fill_weight_scale_region(room.grow(ctx.automaton_corridor_fixed_width_expand), 2)
	grid.fill_weight_scale_region(room, 1)


class AStar extends AStarGrid2D:
	var prev_id: Vector2i
	var _has_previous: bool


	func restart():
		_has_previous = false


	func _compute_cost(from_id: Vector2i, to_id: Vector2i) -> float:
		if not _has_previous:
			prev_id = from_id
			_has_previous = true
			return 1.0
		if prev_id.x == from_id.x and from_id.x == to_id.x \
		or prev_id.y == from_id.y and from_id.y == to_id.y:
			prev_id = from_id
			return 1.0
		prev_id = from_id
		return 2.0
