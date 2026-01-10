extends RefCounted

var map_size: Vector2i

var zone_split_max_ratio: float
var zone_orientation_alternate_chance: float

var room_amount: int
var room_max_ratio: float
var room_min_coverage_ratio: float
var room_max_coverage_ratio: float
var room_center_ratio: float

var corridor_touch_min_ratio: float
var corridor_cycle_chance: float

var automaton_iterations: int
var automaton_cell_min_neighbors: int
var automaton_cell_max_neighbors: int
var automaton_noise_rate: float
var automaton_flood_fill: bool

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
