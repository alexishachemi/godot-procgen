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
@export var show_bsp: bool = true:
	set(value):
		show_bsp = value
		queue_redraw()
@export var show_corridors: bool = true:
	set(value):
		show_corridors = value
		queue_redraw()
@export var show_automaton: bool = true:
	set(value):
		show_automaton = value
		queue_redraw()

@export var zone_rect_color: Color = Color.GREEN
@export var room_rect_color: Color = Color.BEIGE
@export var zone_adjacent_color: Color = Color.BLUE

func _get_configuration_warnings() -> PackedStringArray:
	if not generator:
		return ["Generator not set."]
	return []


func _draw() -> void:
	if not generator or not generator._generator.bsp:
		return
	for leaf in generator._generator.bsp.get_leaves():
		draw_rect(leaf.rect, zone_rect_color, false, 1)
		#draw_rect(leaf.room_rect, room_rect_color, true)
		#for adj in leaf.adjacents:
			#draw_circle(leaf.room_rect.get_center(), 1, zone_adjacent_color)
			#draw_circle(adj.room_rect.get_center(), 1, zone_adjacent_color)
			#draw_line(
				#leaf.room_rect.get_center(),
				#adj.room_rect.get_center(),
				#zone_adjacent_color, 1
			#)
