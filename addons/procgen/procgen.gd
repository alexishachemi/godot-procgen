@tool
class_name ProcGen
extends Node

signal finished
signal automaton_iteration_finished

const Context = preload("generator/context.gd")

@export_tool_button("Generate") var _generate_callback = generate
@export var map_size: Vector2i = Vector2i(100, 100):
	set(value):
		map_size = Vector2i.ONE.max(value)

## Generates a new seed and writes it to [member ProcGen.seed] before running
## a generation.
@export var generate_new_seed_on_run: bool = true

## Seed used by the generator's random number generator. Will be overwritten if
## [member ProcGen.generate_new_seed_on_run] is set to [code]true[/code].
@export var seed: int

@export_group("Zones", "zone")

## The maximum ratio when splitting zones.
## (i.e. when splitting a zone into 2 subzones,
## dictates how larger zone A can be over zone B) [br]
## [code]0.5[/code] -> The split will always be in the middle [br]
## [code]0.7[/code] -> The split will be between 30%~70% of the zone's length
@export_range(0.5, 0.99) var zone_split_max_ratio: float = 0.6

## The chance that a zone uses the opposite split orientation as its parent. [br]
## For example, given zone A that was split [i]horizontally[/i]
## to produce zone B and C: [br]
## [code]0.0[/code] -> Zone B will be split [i]horizontally[/i] like its parent
## zone A. [br]
## [code]1.0[/code] -> Zone B will be split [i]vertically[/i], opposite to its
## parent. [br]
## [code]0.5[/code] -> 50% chance of being split either [i]horizontally[/i] or
## [i]vertically[/i]
@export_range(0.0, 1.0, 0.01) var zone_parent_inverse_orientation_chance: float = 0.9

@export_group("Rooms", "room")

## The amount of rooms that will be generated.
@export_range(1, 1, 1, "or_greater") var room_amount: int = 5

## The ratio of how squared rooms are. Note that this can impact the
## target coverage of rooms. [br]
## [code]0.0[/code] -> No limits on the width to height ratio. [br]
## [code]1.0[/code] -> Width and height are always the same (square rooms)
@export_range(0.0, 1.0) var room_min_squared_ratio: float = 0.3:
	set(value):
		room_min_squared_ratio = min(value, room_max_squared_ratio)

## The ratio of how squared rooms are. Note that this can impact the
## target coverage of rooms. [br]
## [code]0.0[/code] -> No limits on the width to height ratio. [br]
## [code]1.0[/code] -> Width and height are always the same (square rooms)
@export_range(0.0, 1.0) var room_max_squared_ratio: float = 1.0:
	set(value):
		room_max_squared_ratio = max(value, room_min_squared_ratio)

## The minimum coverage of a room. Coverage is how much of the zone the
## room occupies.
@export_range(0.01, 1.0, 0.01) var room_min_coverage: float = 0.1:
	set(value):
		room_min_coverage = min(value, room_max_coverage)

## The maximum coverage of a room. Coverage is how much of the zone the
## room occupies.
@export_range(0.01, 1.0, 0.01) var room_max_coverage: float = 0.3:
	set(value):
		room_max_coverage = max(value, room_min_coverage)

## How centered is a room inside its zone. [br]
## [code]0.0[/code] -> Rooms can be anywhere inside their zone. [br]
## [code]1.0[/code] -> Rooms are always at the center of their zone.
@export_range(0.0, 1.0, 0.01) var room_center_ratio: float = 0.5

@export_group("Corridors", "corridor")

## The minimum ratio, of overlap between 2 zones' edges to be considered
## adjacent. Adjacent zones are zones whose rooms can be connected with
## corridors [br]
## [code]0.3[/code] -> if at least 30% of a zone's edge touches another [br] [br]
## [b]Note[/b]: if set to [code]0.0[/code], every room will be considered
## adjacent.
@export_range(0.0, 1.0, 0.01) var corridor_edge_overlap_min_ratio: float = 0.3

## The chance that an unused room connection is marked as used.
## This means that the path created by corridors will be cyclical. [br]
## [code]0.0[/code] -> No extra connection will be added. [br]
## [code]1.0[/code] -> Every connection will be used.
@export_range(0.0, 1.0, 0.01) var corridor_cycle_chance: float = 0.1

@export_group("Automaton", "automaton")

## The number of iteration to run the Cellular Automata. More iterations will
## lead to more "eroded" looking terrain. [code]0[/code] to disable it.
@export_range(0, 1, 1, "or_greater") var automaton_iterations: int = 5

## The minimum number of neighboring cells set to full for the current cell to
## also be full. (i.e. given a cell at a given position,
## how many surrounding cells needs to be full for it to be full as well)
@export_range(0, 8) var automaton_cell_min_neighbors: int = 5:
	set(value):
		automaton_cell_min_neighbors = min(value, automaton_cell_max_neighbors)

## The maximum number of neighboring cells set to full for the current cell to
## also be full. (i.e. given a cell at a given position,
## how many surrounding cells needs to be full for it to be empty)
@export_range(0, 8) var automaton_cell_max_neighbors: int = 8:
	set(value):
		automaton_cell_max_neighbors = max(value, automaton_cell_min_neighbors)

## The chance that a cell will be full at the initial state of the automaton.
## [code]0.0[/code] -> every cell is empty. [br]
## [code]1.0[/code] -> every cell is full.
@export_range(0.0, 1.0, 0.01) var automaton_noise_rate: float = 0.7

## If set, will fill up isolated holes in the grid at the end of the all
## automaton iterations.
## [br][br][b]Note[/b]: If [member ProcGen.automaton_threads] if at least
## [code]1[/code], then a separate thread is used to compute the flood fill.
@export var automaton_flood_fill: bool = true

## Number of separate threads to use when generating the cellular automata.
## To avoid freezing the editor, the main thread is not used to generate. [br] [br]
## [b]Note[/b]: If set to [code]0[/code], does not create any separate thread and
## uses the main thread instead which may freeze the game/editor during generation.
@export_range(0, 1, 1, "or_greater") var automaton_threads: int = 1

## Amount to expand the outline of [i]immutable[/i] walls around a zone. [br]
## This is to ensure that new path aren't created during iterations of the
## automaton. [br]
## [code]0[/code] -> 1 unit wide outline. [br]
## [code]1[/code] -> 3 units wide outline. [br]
## [code]3[/code] -> 5 units wide outline. [br]
## [code]-1[/code] -> No outline. [br]
@export_range(-1, 1, 1, "or_greater") var automaton_zones_fixed_outline_expand: int = 1

## Amount to expand the [i]immutable[/i] width of corridors. [br]
## Fixed width cannot change during the generation and is thus guaranteed to be at
## least this amount.
## [code]0[/code] -> 1 unit wide corridors. [br]
## [code]1[/code] -> 3 units wide corridors. [br]
## [code]3[/code] -> 5 units wide corridors. [br]
@export_range(0, 1, 1, "or_greater") var automaton_corridor_fixed_width_expand: int = 0

## Amount to expand the [i]mutable[/i] width of corridors. [br]
## Non-fixed width can change during the generation. this amount expands on
## [member ProcGen.automaton_corridor_fixed_width_expand].
## [code]0[/code] -> fixed_width + 1 unit wide corridors at the start. [br]
## [code]1[/code] -> fixed_width + 3 unit wide corridors at the start. [br]
## [code]3[/code] -> fixed_width + 5 unit wide corridors at the start. [br]
@export_range(0, 1, 1, "or_greater") var automaton_corridor_non_fixed_width_expand: int = 2

## The minimum number of neighboring cells set to full for the current cell to
## also be full.[br]
## This is applied once after the last iteration and only on full tiles.
@export_range(0, 8, 1) var automaton_smoothing_step_cell_min_neighbors: int = 4

var _generator := preload("generator/generator.gd").new()


func _ready() -> void:
	_generator.finished.connect(finished.emit)
	_generator.automaton_iteration_finished.connect(automaton_iteration_finished.emit)
	if not Engine.is_editor_hint():
		generate()


## Runs a generation using the provided settings. [br]
## TODO
func generate():
	if is_generating():
		push_error("Generator is already running. Ignoring call to generate()")
		return
	var ctx := Context.new()

	ctx.map_size = map_size

	ctx.zone_split_max_ratio = zone_split_max_ratio
	ctx.zone_parent_inverse_orientation_chance = zone_parent_inverse_orientation_chance

	ctx.room_amount = room_amount
	ctx.room_min_squared_ratio = room_min_squared_ratio
	ctx.room_max_squared_ratio = room_max_squared_ratio
	ctx.room_min_coverage = room_min_coverage
	ctx.room_max_coverage = room_max_coverage
	ctx.room_center_ratio = room_center_ratio

	ctx.corridor_edge_overlap_min_ratio = corridor_edge_overlap_min_ratio
	ctx.corridor_cycle_chance = corridor_cycle_chance

	ctx.automaton_iterations = automaton_iterations
	ctx.automaton_cell_min_neighbors = automaton_cell_min_neighbors
	ctx.automaton_cell_max_neighbors = automaton_cell_max_neighbors
	ctx.automaton_noise_rate = automaton_noise_rate
	ctx.automaton_flood_fill = automaton_flood_fill
	ctx.automaton_threads = automaton_threads
	ctx.automaton_zones_fixed_outline_expand = automaton_zones_fixed_outline_expand
	ctx.automaton_corridor_fixed_width_expand = automaton_corridor_fixed_width_expand
	ctx.automaton_corridor_non_fixed_width_expand = automaton_corridor_non_fixed_width_expand
	ctx.automaton_smoothing_step_cell_min_neighbors = automaton_smoothing_step_cell_min_neighbors

	if generate_new_seed_on_run:
		seed = randi()
	ctx.rng.seed = seed
	await _generator.generate(ctx)


## Returns [code]true[/code] if the cell at the given position is not open space. [br]
## Make sure to call [method ProcGen.generate] beforehand or this will always return
## [code]false[/code].
func is_full_at(at: Vector2i) -> bool:
	return _generator.automaton and _generator.automaton.is_cell_on(at.x, at.y)


## Returns rectangles representing space reserved for rooms.
## The area of those rectangles is [i]guaranteed[/i] to be empty space. [br]
## Returns an empty array if called before calling [method ProcGen.generate].
func get_rooms() -> Array[Rect2i]:
	return _generator.bsp.get_all_rooms()


## Returns points that have been designated as corridors.
## These points (and the area around them defined by
## [member ProcGen.automaton_corridor_fixed_width_expand])
## are [i]guaranteed[/i] to be empty space. [br]
## Returns an empty array if called before calling [method ProcGen.generate].
func get_corridor_areas() -> Array[Vector2i]:
	return _generator.router.points


## Returns [code]true[/code] if the generator is currently active.
func is_generating() -> bool:
	return _generator.generating
