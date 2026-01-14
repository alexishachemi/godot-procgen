extends RefCounted

var map_size: Vector2i

var zone_split_max_ratio: float
var zone_parent_inverse_orientation_chance: float

var room_amount: int
var room_min_coverage: float
var room_max_coverage: float
var room_min_squared_ratio: float
var room_max_squared_ratio: float
var room_center_ratio: float

var corridor_width_expand: int
var corridor_edge_overlap_min_ratio: float
var corridor_cycle_chance: float

var automaton_iterations: int
var automaton_cell_min_neighbors: int
var automaton_cell_max_neighbors: int
var automaton_noise_rate: float
var automaton_flood_fill: bool
var automaton_threads: int
var automaton_zones_outline_expand: int

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
