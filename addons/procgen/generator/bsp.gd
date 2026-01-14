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

var parent: BSP = null
var sub1: BSP = null
var sub2: BSP = null

var graph: Graph = null

func _init(ctx: Context) -> void:
	self.ctx = ctx
	rect = Rect2i(0, 0, ctx.map_size.x, ctx.map_size.y)

func generate():
	split_recursive()
	generate_internal_data()
	graph = Graph.new(ctx)
	graph.generate(self)

func generate_internal_data():
	if is_leaf():
		generate_room()
	else:
		sub1.generate_internal_data()
		sub2.generate_internal_data()
	generate_frontiers()
	match_adjacents()

#region Utils ##################################################################

func create_child(rect: Rect2i) -> BSP:
	var child := BSP.new(ctx)
	child.depth = depth + 1
	child.rect = rect
	child.parent = self
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

#region Split ##################################################################

func split_recursive():
	var orient: SplitOrientation
	var leaf: BSP
	for i in range(ctx.room_amount - 1):
		leaf = get_shallowest_leaf()
		if leaf.parent == null:
			orient = SplitOrientation.values()[ctx.rng.randi() % 2]
		elif ctx.rng.randf() < ctx.zone_parent_inverse_orientation_chance:
			orient = alternate_split_orientation(leaf.parent.split_orientation)
		else:
			orient = leaf.parent.split_orientation
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

#region Room ###################################################################

func get_all_rooms() -> Array[Rect2i]:
	var rooms: Array[Rect2i]
	rooms.resize(ctx.room_amount)
	var leaves := get_leaves()
	for i in range(ctx.room_amount):
		rooms[i] = leaves[i].room_rect
	return rooms

func generate_room():
	var area := _compute_room_area()
	var size: Vector2i
	var pos: Vector2i
	if area == rect.get_area():
		var r := rect.grow(-1)
		size = r.size
		pos = r.position
	else:
		size = _compute_size(area)
		pos = _compute_position(size)
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

#region Adjacents ##############################################################

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
			if _get_biggest_overlap_ratio(b1.rect, b2.rect) >= ctx.corridor_edge_overlap_min_ratio:
				_make_adjacent(b1, b2)

func _make_adjacent(b1: BSP, b2: BSP):
	if not b1.adjacents.has(b2):
		b1.adjacents.append(b2)
	if not b2.adjacents.has(b1):
		b2.adjacents.append(b1)

func _get_biggest_overlap_ratio(r1: Rect2i, r2: Rect2i) -> float:
	var s1: Vector2i
	var s2: Vector2i
	var is_vertical: bool = r1.end.x == r2.position.x or r2.end.x == r1.position.x
	if is_vertical:
		s1 = Vector2i(r1.position.y, r1.end.y)
		s2 = Vector2i(r2.position.y, r2.end.y)
	else:
		s1 = Vector2i(r1.position.x, r1.end.x)
		s2 = Vector2i(r2.position.x, r2.end.x)

	var start := maxi(mini(s1.x, s1.y), mini(s2.x, s2.y))
	var end := mini(maxi(s1.x, s1.y), maxi(s2.x, s2.y))
	var overlap: float = maxf(0.0, float(end - start))

	var denom1 := float(r1.size.y if is_vertical else r1.size.x)
	var denom2 := float(r2.size.y if is_vertical else r2.size.x)
	if denom1 <= 0.0 or denom2 <= 0.0:
		return 0.0

	return maxf(overlap / denom1, overlap / denom2)


#endregion #####################################################################

#region Graph ##################################################################

class Graph:

	var ctx: Context
	var groups: Array[Group]
	var discarded_links: Array[Array]
	var final_links: Array[Array]

	func _init(context: Context) -> void:
		ctx = context

	func generate(bsp: BSP):
		var links := Nav.find_links(bsp, ctx.rng)
		var g1: Group
		var g2: Group
		for link: Array[BSP] in links:
			g1 = get_group(link[0])
			g2 = get_group(link[1])
			if not g1 and not g2:
				add_group().add(link)
			elif g1 and g2 and g1 != g2:
				g1.merge(g2)
				groups.erase(g2)
				g1.add(link)
			elif g1 and not g2:
				g1.add(link)
			elif not g1 and g2:
				g2.add(link)
			else:
				discarded_links.append(link)
		for link in discarded_links:
			if ctx.rng.randf() < ctx.corridor_cycle_chance:
				final_links.append(link)
		for group in groups:
			final_links.append_array(group.links)

	func add_group() -> Group:
		var new_group := Group.new()
		groups.append(new_group)
		return new_group

	func get_group(bsp: BSP) -> Group:
		for group in groups:
			if group.has_member(bsp):
				return group
		return null

	class Group:
		var members: Array[BSP]
		var links: Array[Array]
		
		func has_member(bsp: BSP) -> bool:
			return members.has(bsp)
		
		func add(link: Array):
			links.append(link)
			members.append_array(link)
		
		func merge(other: Group):
			members.append_array(other.members)
			links.append_array(other.links)

	class Nav:
		var visited: Array[BSP]
		var links: Array[Array]
		var rng: RandomNumberGenerator
		
		func _init(rng: RandomNumberGenerator) -> void:
			self.rng = rng
		
		func traverse(bsp: BSP):
			if not bsp.is_leaf():
				traverse(bsp.sub1)
				traverse(bsp.sub2)
				return
			if visited.has(bsp):
				return
			visited.append(bsp)
			for adjacent in bsp.adjacents:
				add_link(bsp, adjacent)
		
		func add_link(b1: BSP, b2: BSP):
			if links.find_custom(_link_has_members.bind(b1, b2)) == -1:
				links.append([b1, b2])
		
		func shuffle_links():
			var j: int
			var tmp: Array
			for i in links.size() - 2:
				j = rng.randi_range(i, links.size() - 1)
				tmp = links[i]
				links[i] = links[j]
				links[j] = tmp
		
		static func _link_has_members(link: Array, m1: BSP, m2: BSP) -> bool:
			return (link[0] == m1 and link[1] == m2) \
				or (link[1] == m1 and link[0] == m2)
		
		static func find_links(bsp: BSP, rng: RandomNumberGenerator) -> Array[Array]:
			var nav := Nav.new(rng)
			nav.traverse(bsp)
			nav.shuffle_links()
			return nav.links


#endregion #####################################################################
