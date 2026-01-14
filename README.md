## Room-based procedural cave/dungeon generator for Godot 4.5

Generates room-based dungeon/caves with extensive settings.

**Note**: This is a GDScript implementation (with some changes) of https://github.com/alexishachemi/ProcGen

## How to use

You first need to set the appropriate `map_size`. Higher values will drastically increase generation time. Optionally, you may also set a custom seed.

The generator uses an internal `RandomNumberGenerator` and is thus not affected by the global random seed. Don’t forget to disable `generate_new_seed_on_run`, or else your seed will be overwritten before starting the generator.

Once set, you may specify the amount of rooms desired with `room_amount`, and the number of iterations to apply on the resulting layout with `automaton_iterations`. Each section has more settings you can use to fine-tune the desired appearance of the dungeon/cave.

You can test the generator either by calling `generate` in your game or pressing the **Generate** button in the inspector.

Once generated, you can call the following methods to get information about the resulting grid:
`is_full_at`, `get_rooms`, `get_corridor_areas`.

See `ProcGenVisualizer` for an easy way to see and debug the result of the generator.

## Implementation details

There are 3 main algorithms used for the generator:

- [**Binary Space Partitioning**](https://en.wikipedia.org/wiki/Binary_space_partitioning): Separating the initial space into sub-spaces to place rooms
- [**Kruskal's algorithm**](https://en.wikipedia.org/wiki/Kruskal's_algorithm): Finding the minimum spanning tree of the generated room graph
- [**Cellular Automaton**](https://en.wikipedia.org/wiki/Cellular_automaton): Creating natural-looking terrain around the generated rooms and corridors

### Generation Steps

#### Partitioning
1. Partitions the space until the required amount of rooms is reached  
2. Places an inner rectangle for the room inside each partition  

#### Mapping
3. Finds which rooms are adjacent  
4. Links a given amount of rooms to connect the entire structure  

#### Corridors
5. Pathfinds corridors to connect each room  

#### Automaton
6. Places random cells (empty/full) inside every partition  
7. Sets the cells around partitions’ outlines to have an immutable full state  
8. Sets the cells inside rooms and corridors to have an immutable empty state  
9. Runs the Cellular Automaton for the given amount of iterations  
10. If enabled, applies a flood fill to remove closed-off areas  
11. Runs a final step to smooth out ragged edges  

---

> ⚠️ **About Threads**
>
> Usage of threads to generate (see `automaton_threads`) is currently quite unstable and inefficient.
>
> The current implementation splits the map into equally sized regions (with a minimal offset if not possible) and assigns a single thread per region.
>
> During testing, increasing the number of threads resulted in a performance decrease. For now, it is recommended to leave this value at `1`, which still provides the benefit of not freezing the caller thread during generation.
