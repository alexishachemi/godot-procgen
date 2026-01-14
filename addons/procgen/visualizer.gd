@tool
class_name ProcGenVisualizer
extends Sprite2D

const Automaton = preload("generator/automaton.gd")

@export var generator: ProcGen:
	set(value):
		if generator:
			generator.finished.disconnect(_on_automaton_iteration)
			generator.automaton_iteration_finished.disconnect(_on_automaton_iteration)
		generator = value
		if generator:
			generator.finished.connect(_on_automaton_iteration)
			generator.automaton_iteration_finished.connect(_on_automaton_iteration)
		update_configuration_warnings()
		_on_automaton_iteration()
@export var show_partitions: bool = true:
	set(value):
		show_partitions = value
		queue_redraw()
@export var show_rooms: bool = true:
	set(value):
		show_rooms = value
		queue_redraw()
@export var show_links: bool = true:
	set(value):
		show_links = value
		queue_redraw()
@export var show_used_links: bool = true:
	set(value):
		show_used_links = value
		queue_redraw()
@export var show_corridors: bool = true:
	set(value):
		show_corridors = value
		queue_redraw()
@export var show_automaton: bool = true:
	set(value):
		show_automaton = value
		_update_automaton_visibility()
@export var highlight_automaton_fixed_states: bool = true:
	set(value):
		highlight_automaton_fixed_states = value
		_update_automaton()
		_update_automaton_visibility()

@export var partition_color: Color = Color.BLUE:
	set(value):
		partition_color = value
		queue_redraw()
@export var partition_room_color: Color = Color.BEIGE:
	set(value):
		partition_room_color = value
		queue_redraw()
@export var link_color: Color = Color.RED:
	set(value):
		link_color = value
		queue_redraw()
@export var used_link_color: Color = Color.GREEN:
	set(value):
		used_link_color = value
		queue_redraw()
@export var corridor_color: Color = Color.SADDLE_BROWN:
	set(value):
		corridor_color = value
		queue_redraw()
@export var automaton_empty_color: Color = Color("dfdfdf"):
	set(value):
		automaton_empty_color = value
		_update_automaton()
		_update_automaton_visibility()
@export var automaton_full_color: Color = Color("323232"):
	set(value):
		automaton_full_color = value
		_update_automaton()
		_update_automaton_visibility()
@export var automaton_fixed_empty_color: Color = Color.WHITE:
	set(value):
		automaton_fixed_empty_color = value
		_update_automaton()
		_update_automaton_visibility()
@export var automaton_fixed_full_color: Color = Color.BLACK:
	set(value):
		automaton_fixed_full_color = value
		_update_automaton()
		_update_automaton_visibility()

var _texture: ImageTexture


func _get_configuration_warnings() -> PackedStringArray:
	if not generator:
		return ["Generator not set."]
	return []


func _draw() -> void:
	if not generator:
		return
	draw_set_transform(-generator.map_size / 2)
	if show_corridors:
		for point in generator._generator.router.points:
			draw_rect(
				Rect2i(point.x, point.y, 1, 1).grow(generator.automaton_corridor_fixed_width_expand),
				corridor_color,
				true,
			)
	for leaf in generator._generator.bsp.get_leaves():
		if show_partitions:
			draw_rect(
				leaf.rect,
				partition_color,
				false,
				1 + generator.automaton_zones_fixed_outline_expand,
			)
		if show_rooms:
			draw_rect(leaf.room_rect, partition_room_color, true)
		if show_links:
			for adj in leaf.adjacents:
				draw_line(
					leaf.room_rect.get_center(),
					adj.room_rect.get_center(),
					link_color,
					1,
				)
	if show_used_links:
		for link in generator._generator.bsp.graph.final_links:
			draw_line(
				link[0].room_rect.get_center(),
				link[1].room_rect.get_center(),
				used_link_color,
				1,
			)


func _update_automaton():
	if not generator or not generator._generator.automaton.initialized:
		_texture = null
		return
	var image := Image.create_empty(
		generator._generator.automaton.ctx.map_size.x,
		generator._generator.automaton.ctx.map_size.y,
		false,
		Image.FORMAT_RGBA8,
	)
	var color: Color
	for x in range(generator.map_size.x):
		for y in range(generator.map_size.y):
			image.set_pixel(
				x,
				y,
				_get_state_color(generator._generator.automaton.get_front_cell(x, y)),
			)
	_texture = ImageTexture.create_from_image(image)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _get_state_color(state: Automaton.State) -> Color:
	match state:
		Automaton.State.ON, Automaton.State.FIXED_ON when not highlight_automaton_fixed_states:
			return automaton_full_color
		Automaton.State.OFF, Automaton.State.FIXED_OFF when not highlight_automaton_fixed_states:
			return automaton_empty_color
		Automaton.State.ON:
			return automaton_full_color
		Automaton.State.OFF:
			return automaton_empty_color
		Automaton.State.FIXED_ON:
			return automaton_fixed_full_color
		Automaton.State.FIXED_OFF:
			return automaton_fixed_empty_color
	return Color.WEB_PURPLE


func _update_automaton_visibility():
	texture = _texture if show_automaton else null


func _on_automaton_iteration():
	_update_automaton()
	_update_automaton_visibility()
	queue_redraw()
