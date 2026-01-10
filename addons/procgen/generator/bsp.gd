extends RefCounted

enum SplitOrientation { HORIZONTAL, VERTICAL }

const Context = preload("context.gd")
const Bsp = preload("bsp.gd")

var ctx: Context

var rect: Rect2i
var room_rect: Rect2i
var depth: int = 0
var split_orientation: SplitOrientation

var sub1: Bsp = null
var sub2: Bsp = null

func generate():
	split(SplitOrientation.HORIZONTAL)
	print(self)

func _init(ctx: Context) -> void:
	self.ctx = ctx
	rect = Rect2i(0, 0, ctx.map_size.x, ctx.map_size.y)

# Split ########################################################################

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

# Utils ########################################################################

func create_child(rect: Rect2i) -> Bsp:
	var child := Bsp.new(ctx)
	child.depth = depth + 1
	child.rect = rect
	return child

func is_leaf() -> bool:
	return sub1 == null

func _to_string() -> String:
	return get_tree_string()

func get_tree_string(indent: String = "") -> String:
	var str: String = "[rect: %s; room: %s; depth: %s; split: %s]" % [
		rect, room_rect, depth, get_split_orientation_str(split_orientation)
	]
	if not is_leaf():
		str += "\n" + indent + "├──" + sub1.get_tree_string(indent + "│  ")
		str += "\n" + indent + "└──" +sub2.get_tree_string(indent + "   ")
	return str

static func get_split_orientation_str(orientation: SplitOrientation) -> String:
	match orientation:
		SplitOrientation.HORIZONTAL: return "H"
		SplitOrientation.VERTICAL: return "V"
	return "U"
