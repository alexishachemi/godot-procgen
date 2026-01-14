extends RefCounted

enum State { ON, OFF, FIXED_ON, FIXED_OFF }

signal finished
signal _region_compute_step_finished
signal _region_compute_finished

const Context = preload("context.gd")

var ctx: Context
var front_matrix: Array[Array]
var back_matrix: Array[Array]
var threads: Array[Array]

var _region_computed: int

func _init(context: Context) -> void:
	_region_compute_step_finished.connect(_on_region_compute_step_finished)
	ctx = context
	front_matrix.resize(ctx.map_size.y)
	for line in front_matrix:
		line.resize(ctx.map_size.x)
		line.fill(State.OFF)


func generate():
	if ctx.automaton_iterations <= 0:
		finished.emit()
		return
	pre_fill()
	back_matrix = front_matrix.duplicate_deep()
	init_threads()
	for i in range(ctx.automaton_iterations):
		await iterate()
	finished.emit()


func pre_fill():
	var state: State
	for x in range(ctx.map_size.x):
		for y in range(ctx.map_size.y):
			state = get_front_cell(x, y)
			if state == State.FIXED_ON or state == State.FIXED_OFF:
				continue
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


func get_front_cell(x: int, y: int) -> State:
	if x >= 0 and x < ctx.map_size.x and y >= 0 and y < ctx.map_size.y:
		return front_matrix[y][x]
	return State.OFF


func set_front_cell(x: int, y: int, state: State):
	if x >= 0 and x < ctx.map_size.x and y >= 0 and y < ctx.map_size.y:
		front_matrix[y][x] = state


func get_back_cell(x: int, y: int) -> State:
	if x >= 0 and x < ctx.map_size.x and y >= 0 and y < ctx.map_size.y:
		return back_matrix[y][x]
	return State.OFF


func set_back_cell(x: int, y: int, state: State):
	if x >= 0 and x < ctx.map_size.x and y >= 0 and y < ctx.map_size.y:
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
			update_back_matrix_region.bind(rects[i])
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
			var a_w := size.x / 2
			var b_w := size.x - a_w
			var a := Rect2i(pos, Vector2i(a_w, size.y))
			var b := Rect2i(pos + Vector2i(a_w, 0), Vector2i(b_w, size.y))
			rects.append(a)
			rects.append(b)
		elif size.y > 1:
			var a_h := size.y / 2
			var b_h := size.y - a_h  # remainder goes here
			var a := Rect2i(pos, Vector2i(size.x, a_h))
			var b := Rect2i(pos + Vector2i(0, a_h), Vector2i(size.x, b_h))
			rects.append(a)
			rects.append(b)
		else:
			rects.append(cur)
			break

	rects.resize(min(rects.size(), n))
	return rects


func _accumulate_on_cell(on_count: int, state: State) -> int:
	if state == State.ON or state == State.FIXED_ON:
		on_count += 1
	return on_count


func _on_region_compute_step_finished():
	if ctx.automaton_threads > 0 and _region_computed == ctx.automaton_threads:
		_region_compute_finished.emit()
