@tool
class_name ProcGenVisualizer extends Node2D

@export var generator: ProcGen:
	set(value):
		if generator:
			generator.finished.disconnect(queue_redraw)
		generator = value
		if generator:
			generator.finished.connect(queue_redraw)
		update_configuration_warnings()
		queue_redraw()
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
		queue_redraw()

@export var partition_color: Color = Color.BLUE
@export var partition_room_color: Color = Color.BEIGE
@export var link_color: Color = Color.RED
@export var used_link_color: Color = Color.GREEN

func _get_configuration_warnings() -> PackedStringArray:
	if not generator:
		return ["Generator not set."]
	return []


func _draw() -> void:
	if not generator or not generator._generator.bsp:
		return
	for leaf in generator._generator.bsp.get_leaves():
		if show_partitions:
			draw_rect(leaf.rect, partition_color, false, 1)
		if show_rooms:
			draw_rect(leaf.room_rect, partition_room_color, true)
		if show_links:
			for adj in leaf.adjacents:
				draw_line(
					leaf.room_rect.get_center(),
					adj.room_rect.get_center(),
					link_color,
					1
				)
	if show_used_links:
		for link in generator._generator.bsp.graph.final_links:
			draw_line(
				link[0].room_rect.get_center(),
				link[1].room_rect.get_center(),
				used_link_color,
				1
			)
