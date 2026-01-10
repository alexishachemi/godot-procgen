extends RefCounted

enum SplitOrientation { HORIZONTAL, VERTICAL }

const Context = preload("context.gd")
const BSP = preload("bsp.gd")

var ctx: Context

var rect: Rect2i
var room_rect: Rect2i
var depth: int = 0
var split_orientation: SplitOrientation

var north_frontiers: Array[BSP]
var south_frontiers: Array[BSP]
var west_frontiers: Array[BSP]
var east_frontiers: Array[BSP]
var adjacents: Array[BSP]

var sub1: BSP = null
var sub2: BSP = null

func generate():
	split_recursive()
	generate_internal_data()

func _init(ctx: Context) -> void:
	self.ctx = ctx
	rect = Rect2i(0, 0, ctx.map_size.x, ctx.map_size.y)

#region Split ##################################################################

func split_recursive():
	var orientation = SplitOrientation.values()[ctx.rng.randi() % 2]
	for i in range(ctx.room_amount - 1):
		get_shallowest_leaf().split(orientation)
		if ctx.rng.randf() < ctx.zone_orientation_alternate_chance:
			orientation = alternate_split_orientation(orientation)

func split(orientation: SplitOrientation):
	split_orientation = orientation
	var rect1: Rect2i
	var rect2: Rect2i
	if orientation == SplitOrientation.HORIZONTAL:
		var min_n := rect.size.y * ctx.zone_split_max_ratio
		var max_n := rect.size.y - min_n
		var n: int = ctx.rng.randi_range(min_n, max_n)
		rect1 = Rect2i(rect.position, Vector2i(rect.size.x, n))
		rect2 = Rect2i(rect.position.x, rect.position.y + n, rect.size.x, rect.size.y - rect1.size.y)
	else:
		var min_n := rect.size.x * ctx.zone_split_max_ratio
		var max_n := rect.size.x - min_n
		var n: int = ctx.rng.randi_range(min_n, max_n)
		rect1 = Rect2i(rect.position, Vector2i(n, rect.size.y))
		rect2 = Rect2i(rect.position.x + n, rect.position.y, rect.size.x - rect1.size.x, rect.size.y)
	sub1 = create_child(rect1)
	sub2 = create_child(rect2)

func get_shallowest_leaf() -> BSP:
	return _traverse_to_shallowest(self, null)

static func _traverse_to_shallowest(bsp: BSP, shallowest: BSP) -> BSP:
	if bsp.is_leaf():
		if not shallowest or bsp.depth < shallowest.depth:
			return bsp
		return shallowest
	shallowest = _traverse_to_shallowest(bsp.sub1, shallowest)
	shallowest = _traverse_to_shallowest(bsp.sub2, shallowest)
	return shallowest

#endregion #####################################################################

#region Internal Data ##########################################################

func generate_internal_data():
	if is_leaf():
		generate_room()
	else:
		sub1.generate_internal_data()
		sub2.generate_internal_data()
	generate_frontiers()
	match_adjacents()

func generate_room():
	var room_size: Vector2i
	var rect_area := rect.get_area()
	var room_area := ctx.rng.randi_range(
		rect_area * ctx.room_min_coverage_ratio,
		rect_area * ctx.room_max_coverage_ratio
	)
	var n_max: int = mini(sqrt(room_area), mini(rect.size.x, rect.size.y))
	var n_min: int = n_max * ctx.room_max_ratio
	var n := max(1, ctx.rng.randi_range(n_min, n_max))
	if ctx.rng.randi() % 2:
		room_size = Vector2i(n, min(room_area / n, rect.size.y))
	else:
		room_size = Vector2i(min(room_area / n, rect.size.x), n)
	var margins := (rect.size - room_size) / 2
	var offset := Vector2i(
		ctx.rng.randi_range(0, margins.x * ctx.room_center_ratio),
		ctx.rng.randi_range(0, margins.y * ctx.room_center_ratio)
	)
	room_rect = Rect2i(rect.position + margins + offset, room_size)

func generate_frontiers():
	if is_leaf():
		north_frontiers = [self]
		south_frontiers = [self]
		west_frontiers = [self]
		east_frontiers = [self]
	elif split_orientation == SplitOrientation.HORIZONTAL:
		north_frontiers = sub1.north_frontiers
		south_frontiers = sub2.south_frontiers
		west_frontiers = sub1.west_frontiers + sub2.west_frontiers
		east_frontiers = sub1.east_frontiers + sub2.east_frontiers
	else:
		north_frontiers = sub1.north_frontiers + sub2.north_frontiers
		south_frontiers = sub1.south_frontiers + sub2.south_frontiers
		west_frontiers = sub1.west_frontiers
		east_frontiers = sub2.east_frontiers

func match_adjacents():
	if is_leaf():
		return
	var frontiers_1: Array[BSP]
	var frontiers_2: Array[BSP]
	if split_orientation == SplitOrientation.HORIZONTAL:
		frontiers_1 = sub1.south_frontiers
		frontiers_2 = sub2.north_frontiers
	else:
		frontiers_1 = sub1.east_frontiers
		frontiers_2 = sub2.west_frontiers
	for b1 in frontiers_1:
		for b2 in frontiers_2:
			if _get_edge_overlap(b1.rect, b2.rect) >= ctx.corridor_edge_overlap_min_ratio:
				b1.adjacents.append(b2)
				b2.adjacents.append(b1)

func _get_edge_overlap(r1: Rect2i, r2: Rect2i) -> int:
	var x1: int = r1.position.x
	var y1: int = r1.position.y
	var w1: int = r1.size.x
	var h1: int = r1.size.y
	var x2: int = r2.position.x
	var y2: int = r2.position.y
	var w2: int = r2.size.x
	var h2: int = r2.size.y
	var overlap: int = 0

	if x1 + w1 == x2 or x2 + w2 == x1:
		overlap = min(y1 + h1, y2 + h2) - max(y1, y2)
	elif y1 + h1 == y2 or y2 + h2 == y1:
		overlap = min(x1 + w1, x2 + w2) - max(x1, x2)
	return max(overlap, 0)

#endregion #####################################################################

#region Utils ##################################################################

func create_child(rect: Rect2i) -> BSP:
	var child := BSP.new(ctx)
	child.depth = depth + 1
	child.rect = rect
	return child

func is_leaf() -> bool:
	return sub1 == null

func get_leaves() -> Array[BSP]:
	if is_leaf():
		return [self]
	return sub1.get_leaves() + sub2.get_leaves()

func print_tree():
	print_rich(_get_tree_string())

func _get_tree_string(indent: String = "") -> String:
	var str: String = "[rect: %s; room: %s; depth: %s; split: %s]" % [
		rect, room_rect, depth, get_split_orientation_str(split_orientation)
	]
	if is_leaf():
		str = "[color=light_green]%s[/color]" % str
	else:
		str += "\n" + indent + "├──" + sub1._get_tree_string(indent + "│  ")
		str += "\n" + indent + "└──" +sub2._get_tree_string(indent + "   ")
	return str

static func get_split_orientation_str(orientation: SplitOrientation) -> String:
	match orientation:
		SplitOrientation.HORIZONTAL: return "H"
		SplitOrientation.VERTICAL: return "V"
	return "U"

static func alternate_split_orientation(orientation: SplitOrientation) -> SplitOrientation:
	if orientation == SplitOrientation.HORIZONTAL:
		return SplitOrientation.VERTICAL
	return SplitOrientation.HORIZONTAL

#endregion #####################################################################
