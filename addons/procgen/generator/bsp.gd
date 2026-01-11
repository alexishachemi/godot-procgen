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
var group: Array[BSP]

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
	var base_orient = SplitOrientation.values()[ctx.rng.randi() % 2]
	var orient: SplitOrientation
	var leaf: BSP
	for i in range(ctx.room_amount - 1):
		leaf = get_shallowest_leaf()
		if leaf.depth != 0 \
		and leaf.depth % 2 == 0 \
		and ctx.rng.randf() < ctx.zone_orientation_alternate_chance:
			orient = alternate_split_orientation(base_orient)
		else:
			orient = base_orient
		leaf.split(orient)

func split(orientation: SplitOrientation):
	split_orientation = orientation
	var rect1: Rect2i
	var rect2: Rect2i
	if orientation == SplitOrientation.HORIZONTAL:
		var min_n: int = max(1, rect.size.y / 2)
		min_n = max(min_n, round(rect.size.y * ctx.zone_split_max_ratio))
		var max_n: int = clamp(rect.size.y - min_n, 1, rect.size.y)
		var n: int = ctx.rng.randi_range(min_n, max_n)
		rect1 = Rect2i(rect.position, Vector2i(rect.size.x, n))
		rect2 = Rect2i(rect.position.x, rect.position.y + n, rect.size.x, rect.size.y - rect1.size.y)
	else:
		var min_n: int = max(1, rect.size.x / 2)
		min_n = max(min_n, round(rect.size.x * ctx.zone_split_max_ratio))
		var max_n: int = clamp(rect.size.x - min_n, 1, rect.size.x)
		var n: int = ctx.rng.randi_range(min_n, max_n)
		rect1 = Rect2i(rect.position, Vector2i(n, rect.size.y))
		rect2 = Rect2i(rect.position.x + n, rect.position.y, rect.size.x - rect1.size.x, rect.size.y)
	sub1 = create_child(rect1)
	sub2 = create_child(rect2)

func get_shallowest_leaf(shallowest: BSP = null) -> BSP:
	if is_leaf():
		if not shallowest or depth < shallowest.depth:
			return self
		return shallowest
	var first_checked := sub1
	var seconds_checked := sub2
	if ctx.rng.randi() % 2:
		first_checked = sub2
		seconds_checked = sub1
	shallowest = first_checked.get_shallowest_leaf(shallowest)
	return seconds_checked.get_shallowest_leaf(shallowest)

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
			if _edges_overlap(b1.rect, b2.rect):
				b1.adjacents.append(b2)
				b2.adjacents.append(b1)

func _edges_overlap(r1: Rect2i, r2: Rect2i) -> bool:
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
		return overlap > 30
		return max(overlap, 0) >= min(x1, x2) * ctx.corridor_edge_overlap_min_ratio
	elif y1 + h1 == y2 or y2 + h2 == y1:
		overlap = min(x1 + w1, x2 + w2) - max(x1, x2)
		return overlap > 30
		return max(overlap, 0) >= min(y1, y2) * ctx.corridor_edge_overlap_min_ratio
	return 0

#endregion #####################################################################

#region Room ###################################################################

func generate_room():
	var area := _compute_room_area()
	var size := _compute_size(area)
	var pos := _compute_position(size)
	room_rect = Rect2i(pos, size)


func _compute_room_area() -> int:
	var outer_area: int = rect.get_area()
	var min_area: int = max(1, outer_area * ctx.room_min_coverage)
	var max_area: int = min(outer_area, outer_area * ctx.room_max_coverage)
	return ctx.rng.randi_range(min_area, max_area)


func _compute_size(area: int) -> Vector2i:
	var smallest_size: float = min(rect.size.x, rect.size.y)
	var biggest_size: float = max(rect.size.x, rect.size.y)
	var max_ratio: float = smallest_size / biggest_size
	var squared_ratio: float = ctx.rng.randf_range(
		ctx.room_min_squared_ratio, ctx.room_max_squared_ratio
	)
	var ratio: float = lerp(max_ratio, 1.0, squared_ratio)
	var base_size: int = max(1, sqrt(area))
	var size := Vector2i(max(1, base_size / ratio), max(1, base_size * ratio))
	var width_is_smallest: bool = smallest_size == rect.size.x
	if width_is_smallest:
		size = Vector2i(size.y, size.x)
	return size.min(rect.size)


func _compute_position(size: Vector2i) -> Vector2i:
	var max_margin: Vector2i = (rect.size - size).maxi(0)
	var center_margin := max_margin / 2
	var min_margin := _lerp_v2i(Vector2i.ZERO, center_margin, ctx.room_center_ratio)
	max_margin = _lerp_v2i(max_margin, center_margin, ctx.room_center_ratio)
	var x: int = ctx.rng.randi_range(min_margin.x, max_margin.x)
	var y: int = ctx.rng.randi_range(min_margin.y, max_margin.y)
	return rect.position + Vector2i(x, y)

func _lerp_v2i(from: Vector2i, to: Vector2i, weigth: float) -> Vector2i:
	return Vector2i(lerp(from.x, to.x, weigth), lerp(from.y, to.y, weigth))

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

#region Graph ##################################################################

#class NavTree:
	#class Link:
		#var b1: BSP
		#var b2: BSP
		#
		#func _init(b1: BSP, b2: BSP):
			#self.b1 = b1
			#self.b2 = b2
	#class Nav:
		#var visited: Array[BSP]
		#var links: Array[Link]
#
		#func traverse(bsp: BSP):
			#if not bsp.is_leaf():
				#traverse(bsp.sub1)
			#visited.append(bsp)
			#for adjacent in bsp.adjacents:
				#links.append(Link.new(bsp, adjacent))
				#if not visited.has(adjacent):
					#traverse(adjacent)
	#
	#func generate(bsp: BSP):
		#var nav := Nav.new()
		#nav.traverse(bsp)
		#

#endregion #####################################################################
