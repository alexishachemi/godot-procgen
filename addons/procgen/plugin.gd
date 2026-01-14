@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("ProcGen", "Node", preload("procgen.gd"), preload("assets/procgen.png"))
	add_custom_type("ProcGenVisualizer", "Sprite2D", preload("visualizer.gd"), preload("assets/visualizer.png"))


func _exit_tree() -> void:
	remove_custom_type("ProcGen")
	remove_custom_type("ProcGenVisualizer")
