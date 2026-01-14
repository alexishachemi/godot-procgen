extends RefCounted

enum State { ON, OFF, FIXED_ON, FIXED_OFF }

signal finished
signal iteration_finished
signal _region_compute_step_finished
signal _region_compute_finished
signal _flood_fill_finished
signal _smooth_step_finished

const Context = preload("context.gd")
const BSP = preload("bsp.gd")
const Router = preload("router.gd")

const NEIGHBOR_DIRS := [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1),
]

var ctx: Context
var front_matrix: Array[Array]
var back_matrix: Array[Array]
var threads: Array[Array]
var initialized: bool = false

var _region_computed: int
var _visited_cells: Dictionary[Vector2i, bool]
var _current_cell_group: Array[Vector2i]


func _init() -> void:
	_region_compute_step_finished.connect(_on_region_compute_step_finished)


func generate(context: Context, bsp: BSP, router: Router):
	ctx = context
	initialized = true
	front_matrix.resize(ctx.map_size.y)
	for line in front_matrix:
		line.resize(ctx.map_size.x)
		line.fill(State.OFF)
	pre_fill()
	add_initial(bsp, router)
	if ctx.automaton_iterations <= 0:
		finished.emit()
		return
	if ctx.automaton_iterations:
		back_matrix = front_matrix.duplicate_deep()
		init_threads()
		for i in range(ctx.automaton_iterations):
			await iterate()
			iteration_finished.emit()
		if ctx.automaton_flood_fill:
			await apply_flood_fill()
		await run_smooth_step()
	finished.emit()


func add_initial(bsp: BSP, router: Router):
	var leaves := bsp.get_leaves()
	var corridor_fixed_expand := ctx.automaton_corridor_fixed_width_expand
	var corridor_expand := corridor_fixed_expand + ctx.automaton_corridor_non_fixed_width_expand
	for leaf in leaves:
		set_rect_outline_fixed(leaf.rect)
	for point in router.points:
		set_front_point(point, State.OFF, corridor_expand)
	for point in router.points:
		set_front_point(point, State.FIXED_OFF, corridor_fixed_expand)
	for leaf in leaves:
		fill_front_region(leaf.room_rect, State.FIXED_OFF)


func set_rect_outline_fixed(rect: Rect2i):
	for x in range(rect.position.x, rect.end.x):
		set_front_point(
			Vector2i(x, rect.position.y),
			State.FIXED_ON,
			ctx.automaton_zones_fixed_outline_expand,
		)
	for x in range(rect.position.x, rect.end.x):
		set_front_point(
			Vector2i(x, rect.end.y - 1),
			State.FIXED_ON,
			ctx.automaton_zones_fixed_outline_expand,
		)
	for y in range(rect.position.y, rect.end.y):
		set_front_point(
			Vector2i(rect.position.x, y),
			State.FIXED_ON,
			ctx.automaton_zones_fixed_outline_expand,
		)
	for y in range(rect.position.y, rect.end.y):
		set_front_point(
			Vector2i(rect.end.x - 1, y),
			State.FIXED_ON,
			ctx.automaton_zones_fixed_outline_expand,
		)


func pre_fill():
	for x in range(ctx.map_size.x):
		for y in range(ctx.map_size.y):
			if ctx.rng.randf() < ctx.automaton_noise_rate:
				set_front_cell(x, y, State.ON)
			else:
				set_front_cell(x, y, State.OFF)


func iterate():
	if threads.is_empty():
		compute_all()
		return

	_region_computed = 0
	for t in threads:
		t[0].start(t[1])
	await _region_compute_finished
	for t in threads:
		t[0].wait_to_finish()

	_region_computed = 0
	for t in threads:
		t[0].start(t[2])
	await _region_compute_finished
	for t in threads:
		t[0].wait_to_finish()


func run_smooth_step():
	if threads.is_empty():
		_run_smooth_step()
		return
	threads[0][0].start(_run_smooth_step)
	await _smooth_step_finished
	threads[0][0].wait_to_finish()


func _run_smooth_step():
	for x in range(ctx.map_size.x):
		for y in range(ctx.map_size.y):
			if get_front_cell(x, y) == State.ON \
			and get_surrounding_front_on_cells_count(x, y) < ctx.automaton_smoothing_step_cell_min_neighbors:
				set_front_cell(x, y, State.OFF)
	call_deferred("emit_signal", "_smooth_step_finished")


func get_front_cell(x: int, y: int) -> State:
	if is_in_bounds(x, y):
		return front_matrix[y][x]
	return State.FIXED_ON


func set_front_cell(x: int, y: int, state: State):
	if is_in_bounds(x, y):
		front_matrix[y][x] = state


func fill_front_region(region: Rect2i, state: State):
	for x in range(region.position.x, region.end.x):
		for y in range(region.position.y, region.end.y):
			set_front_cell(x, y, state)


func set_front_point(at: Vector2i, state: State, expand: int = 0):
	if expand <= 0:
		set_front_cell(at.x, at.y, state)
		return
	for x in range(at.x - expand, at.x + expand + 1):
		for y in range(at.y - expand, at.y + expand + 1):
			set_front_cell(x, y, state)


func get_back_cell(x: int, y: int) -> State:
	if is_in_bounds(x, y):
		return back_matrix[y][x]
	return State.FIXED_ON


func set_back_cell(x: int, y: int, state: State):
	if is_in_bounds(x, y):
		back_matrix[y][x] = state


func is_cell_on(x: int, y: int) -> bool:
	var state := get_front_cell(x, y)
	return state == State.ON or state == State.FIXED_ON


func get_surrounding_on_cells_count(x: int, y: int) -> int:
	return [
		get_back_cell(x, y - 1),
		get_back_cell(x, y + 1),
		get_back_cell(x - 1, y),
		get_back_cell(x + 1, y),
		get_back_cell(x - 1, y - 1),
		get_back_cell(x - 1, y + 1),
		get_back_cell(x + 1, y - 1),
		get_back_cell(x + 1, y + 1),
	].reduce(_accumulate_on_cell, 0)


func get_surrounding_front_on_cells_count(x: int, y: int) -> int:
	return [
		get_front_cell(x, y - 1),
		get_front_cell(x, y + 1),
		get_front_cell(x - 1, y),
		get_front_cell(x + 1, y),
		get_front_cell(x - 1, y - 1),
		get_front_cell(x - 1, y + 1),
		get_front_cell(x + 1, y - 1),
		get_front_cell(x + 1, y + 1),
	].reduce(_accumulate_on_cell, 0)


func is_in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < ctx.map_size.x and y >= 0 and y < ctx.map_size.y


func compute_cell(x: int, y: int):
	var state := get_back_cell(x, y)
	if state == State.FIXED_ON or state == State.FIXED_OFF:
		return
	var surrounding := get_surrounding_on_cells_count(x, y)
	if surrounding >= ctx.automaton_cell_min_neighbors \
	and surrounding <= ctx.automaton_cell_max_neighbors:
		set_front_cell(x, y, State.ON)
	else:
		set_front_cell(x, y, State.OFF)


func compute_region(rect: Rect2i):
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			compute_cell(x, y)
	_region_computed += 1
	call_deferred("emit_signal", "_region_compute_step_finished")


func compute_all():
	var rect := Rect2i(0, 0, ctx.map_size.x, ctx.map_size.y)
	compute_region(rect)
	update_back_matrix_region(rect)


func update_back_matrix_region(rect: Rect2i):
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			set_back_cell(x, y, get_front_cell(x, y))
	_region_computed += 1
	call_deferred("emit_signal", "_region_compute_step_finished")


func init_threads():
	threads.clear()
	if ctx.automaton_threads <= 0:
		return
	var rects := get_sub_rects(ctx.automaton_threads)
	threads.resize(ctx.automaton_threads)
	for i in range(ctx.automaton_threads):
		threads[i] = [
			Thread.new(),
			compute_region.bind(rects[i]),
			update_back_matrix_region.bind(rects[i]),
		]


func get_sub_rects(n: int) -> Array[Rect2i]:
	var r := Rect2i(0, 0, ctx.map_size.x, ctx.map_size.y)
	if n <= 1:
		return [r]
	var rects: Array[Rect2i] = [r]

	while rects.size() < n:
		var best_i := 0
		var best_area := rects[0].size.x * rects[0].size.y
		for i in range(1, rects.size()):
			var s := rects[i].size
			var area := s.x * s.y
			if area > best_area:
				best_area = area
				best_i = i

		var cur := rects[best_i]
		rects.remove_at(best_i)
		var pos := cur.position
		var size := cur.size

		if size.x <= 1 and size.y <= 1:
			rects.append(cur)
			break

		if size.x >= size.y and size.x > 1:
			var a_w := int(size.x / 2.0)
			var b_w := size.x - a_w
			var a := Rect2i(pos, Vector2i(a_w, size.y))
			var b := Rect2i(pos + Vector2i(a_w, 0), Vector2i(b_w, size.y))
			rects.append(a)
			rects.append(b)
		elif size.y > 1:
			var a_h := int(size.y / 2.0)
			var b_h := size.y - a_h
			var a := Rect2i(pos, Vector2i(size.x, a_h))
			var b := Rect2i(pos + Vector2i(0, a_h), Vector2i(size.x, b_h))
			rects.append(a)
			rects.append(b)
		else:
			rects.append(cur)
			break

	rects.resize(min(rects.size(), n))
	return rects


func apply_flood_fill():
	if threads.is_empty():
		_apply_flood_fill()
		return
	threads[0][0].start(_apply_flood_fill)
	await _flood_fill_finished
	threads[0][0].wait_to_finish()


func _apply_flood_fill():
	var pos: Vector2i
	_visited_cells.clear()
	for x in range(ctx.map_size.x):
		for y in range(ctx.map_size.y):
			pos = Vector2i(x, y)
			_current_cell_group.clear()
			if not _visited_cells.has(pos) \
			and get_front_cell(x, y) == State.OFF \
			and _flood_fill_explore(pos):
				for point in _current_cell_group:
					set_front_cell(point.x, point.y, State.ON)
	call_deferred("emit_signal", "_flood_fill_finished")


func _flood_fill_explore(start: Vector2i) -> bool:
	var is_hole := true
	var stack: Array[Vector2i] = [start]

	while not stack.is_empty():
		var at: Vector2i = stack.pop_back()
		if not is_in_bounds(at.x, at.y):
			is_hole = false
			continue
		if _visited_cells.has(at):
			continue

		var state := get_front_cell(at.x, at.y)
		if state == State.ON or state == State.FIXED_ON:
			continue
		_visited_cells[at] = true
		_current_cell_group.append(at)
		if state == State.FIXED_OFF:
			is_hole = false
		for dir in NEIGHBOR_DIRS:
			stack.push_back(at + dir)

	return is_hole


func _accumulate_on_cell(on_count: int, state: State) -> int:
	if state == State.ON or state == State.FIXED_ON:
		on_count += 1
	return on_count


func _on_region_compute_step_finished():
	if ctx.automaton_threads > 0 and _region_computed == ctx.automaton_threads:
		_region_compute_finished.emit()
