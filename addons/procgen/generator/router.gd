extends RefCounted

const BSP = preload("bsp.gd")
const Context = preload("context.gd")

var grid: AStarGrid2D = AStarGrid2D.new()
var ctx: Context

var points: Array[Vector2i]


func _init(context: Context):
	ctx = context
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN


func route_all_rooms(bsp: BSP):
	var path: Array[Vector2i]
	points = []
	grid.region = bsp.rect
	grid.update()
	grid.rooms = bsp.get_all_rooms()
	for room in grid.rooms:
		grid.fill_solid_region(room.grow(1), true)
	for link in bsp.graph.final_links:
		path = grid.get_rooms_path(link[0].room_rect, link[1].room_rect)
		for point in path:
			discourage_point(point)
		points.append_array(path)


func route_rooms(from: Rect2i, to: Rect2i):
	allow_room(from)
	allow_room(to)
	var path := grid.get_id_path(from.get_center(), to.get_center())
	for point in path:
		discourage_point(point)
	path.filter(func(x): from.has_point(x) or to.has_point(x))
	points.append_array(path)
	forbid_room(from)
	forbid_room(to)


func allow_room(room: Rect2i):
	grid.fill_solid_region(room.grow(1), false)


func forbid_room(room: Rect2i):
	grid.fill_solid_region(room.grow(1), true)


func discourage_point(point: Vector2i):
	var expand := Vector2i(ctx.corridor_width_expand, ctx.corridor_width_expand)
	grid.fill_weight_scale_region(Rect2i(point - expand, expand * 2), 9999.0)
