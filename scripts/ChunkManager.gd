extends Node2D

const CHUNK_SIZE := 16
const TILE_PX := 16
const LOAD_RADIUS := 2
const WORLD_COLLISION_LAYER := 1

# Terrain is ordered low to high, which is also the atlas strip order.
const WATER := 0
const SAND := 1
const GRASS := 2

# Each terrain is one independent tile, so the atlas is a single strip and a
# cell is painted from the terrain at its centre. Boundaries land on grid
# lines, which is how the handheld games this is styled after draw them.
#
# Each terrain ships interchangeable variants that share one base colour.
# Picking between them per cell is what stops a single tile from visibly
# repeating across the large areas each terrain covers. Indexed by terrain.
const TERRAIN_NAMES := ["water", "sand", "grass"]
const TERRAIN_VARIANTS := [16, 9, 16]
const TILE_PATH := "res://assets/tiles/%s/%s_%02d.png"

# Trees are objects standing on the grass rather than a terrain, so they carry
# their own collision and can be drawn in front of or behind the player.
const TREE_SCENE := preload("res://scenes/Tree.tscn")
# A block is filled either by one broad tree or by a pair of narrow conifers
# standing side by side. Either way the block is covered edge to edge, so the
# mix varies the canopy without opening gaps or overlapping.
const SMALL_TREE_SCENE := preload("res://scenes/SmallTree.tscn")
# A canopy covers two tiles each way, so trees are anchored on even
# coordinates: one per two-by-two block. They tile edge to edge instead of
# piling on each other, and because each blocks its whole block, neighbouring
# trees join into an unbroken wall.
const TREE_TILES := 2
const TREE_PX := TREE_TILES * TILE_PX

# Edge tiles let a terrain intrude into the one below it with a shaped border
# instead of stopping on a grid line. Pair index is the lower terrain, so pair
# 0 is water bordered by sand and pair 1 is sand bordered by grass.
const EDGE_PAIRS := [["water", "sand"], ["sand", "grass"]]
const EDGE_KINDS := [
	"edge_n", "edge_e", "edge_s", "edge_w",
	"corner_ne", "corner_se", "corner_sw", "corner_nw",
	"wrap_ne", "wrap_se", "wrap_sw", "wrap_nw",
]
const EDGE_PATH := "res://assets/tiles/edge/%s_%s_%s.png"

# Forests are broad noise masses; a second, finer noise punches clearings
# through them so a forest never becomes an impassable wall of trees.
const FOREST_LEVEL := 0.25
const CLEARING_LEVEL := -0.15
const CLEARING_FREQUENCY := 0.08

# One lake candidate per region. Centers are kept far enough from the region
# edge that a lake always fits inside it, so lakes never merge into rivers.
const LAKE_REGION := 24
const LAKE_CHANCE := 0.6
const LAKE_RADIUS_MIN := 3.0
const LAKE_RADIUS_MAX := 7.0
const SHORE_WOBBLE := 1.5

# Keeps the player's spawn area walkable so a random seed can't trap them at spawn.
const SPAWN_CLEARANCE := 2

@onready var tilemap: TileMap = $TileMap

var player: Node2D
var loaded_chunks: Dictionary = {}
var lakes: Dictionary = {}
var tree_parent: Node2D
var chunk_trees: Dictionary = {}
var atlas_offsets: Array[int] = []
var atlas_count := 0
var edge_offset := 0
var noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()
var clearing_noise := FastNoiseLite.new()
var world_seed := 0

func _ready() -> void:
	world_seed = randi()
	noise.seed = world_seed
	noise.frequency = 0.2
	forest_noise.seed = world_seed + 1
	forest_noise.frequency = 0.04
	clearing_noise.seed = world_seed + 2
	clearing_noise.frequency = CLEARING_FREQUENCY
	_build_tileset()

func _build_tileset() -> void:
	atlas_offsets.clear()
	var total := 0
	for terrain in TERRAIN_NAMES.size():
		atlas_offsets.append(total)
		total += TERRAIN_VARIANTS[terrain]
	edge_offset = total
	total += EDGE_PAIRS.size() * EDGE_KINDS.size()
	atlas_count = total
	var img := Image.create_empty(TILE_PX * atlas_count, TILE_PX, false, Image.FORMAT_RGBA8)
	for terrain in TERRAIN_NAMES.size():
		var name: String = TERRAIN_NAMES[terrain]
		for variant in TERRAIN_VARIANTS[terrain]:
			_blit_tile(img, load(TILE_PATH % [name, name, variant]), atlas_offsets[terrain] + variant)
	for pair in EDGE_PAIRS.size():
		var names: Array = EDGE_PAIRS[pair]
		for kind in EDGE_KINDS.size():
			_blit_tile(img, load(EDGE_PATH % [names[0], names[1], EDGE_KINDS[kind]]),
				_edge_atlas(pair, kind))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for i in atlas_count:
		atlas.create_tile(Vector2i(i, 0))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_PX, TILE_PX)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, WORLD_COLLISION_LAYER)
	tileset.add_source(atlas, 0)
	for variant in TERRAIN_VARIANTS[WATER]:
		_make_tile_solid(atlas, atlas_offsets[WATER] + variant)
	# A water cell keeps blocking even where sand intrudes into its border.
	for kind in EDGE_KINDS.size():
		_make_tile_solid(atlas, _edge_atlas(WATER, kind))
	tilemap.tile_set = tileset

func _edge_atlas(pair: int, kind: int) -> int:
	return edge_offset + pair * EDGE_KINDS.size() + kind

func _blit_tile(img: Image, texture: Texture2D, atlas_x: int) -> void:
	var src := texture.get_image()
	src.convert(Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(0, 0, TILE_PX, TILE_PX), Vector2i(atlas_x * TILE_PX, 0))

func _make_tile_solid(atlas: TileSetAtlasSource, tile_id: int) -> void:
	var half := TILE_PX / 2.0
	var tile_data := atlas.get_tile_data(Vector2i(tile_id, 0), 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	]))

func follow(target: Node2D) -> void:
	player = target

# Trees live outside this node so they can sort against the player by depth.
func set_tree_parent(target: Node2D) -> void:
	tree_parent = target

func _process(_delta: float) -> void:
	if player and is_instance_valid(player):
		_update_chunks(player.global_position)

func _update_chunks(center: Vector2) -> void:
	var cx := int(floor(center.x / (CHUNK_SIZE * TILE_PX)))
	var cy := int(floor(center.y / (CHUNK_SIZE * TILE_PX)))
	for y in range(cy - LOAD_RADIUS, cy + LOAD_RADIUS + 1):
		for x in range(cx - LOAD_RADIUS, cx + LOAD_RADIUS + 1):
			var key := Vector2i(x, y)
			if not loaded_chunks.has(key):
				_generate_chunk(key)
	var to_unload := []
	for key in loaded_chunks.keys():
		if abs(key.x - cx) > LOAD_RADIUS + 1 or abs(key.y - cy) > LOAD_RADIUS + 1:
			to_unload.append(key)
	for key in to_unload:
		_unload_chunk(key)

func _generate_chunk(chunk: Vector2i) -> void:
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx := chunk.x * CHUNK_SIZE + lx
			var wy := chunk.y * CHUNK_SIZE + ly
			tilemap.set_cell(0, Vector2i(wx, wy), 0, Vector2i(_atlas_tile(wx, wy), 0))
	loaded_chunks[chunk] = true
	_spawn_trees(chunk)

func _spawn_trees(chunk: Vector2i) -> void:
	if tree_parent == null:
		return
	var trees: Array[Node] = []
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx := chunk.x * CHUNK_SIZE + lx
			var wy := chunk.y * CHUNK_SIZE + ly
			if not _has_tree(wx, wy):
				continue
			# Anchored at the foot of the block, which is what depth sorting
			# compares, with the canopy filling the block above.
			var foot := wy * TILE_PX + TREE_PX
			if absi(hash(Vector3i(wx, wy, world_seed + 13))) % 2 == 0:
				trees.append(_add_tree(TREE_SCENE, Vector2(wx * TILE_PX + TREE_PX / 2.0, foot)))
			else:
				trees.append(_add_tree(SMALL_TREE_SCENE, Vector2(wx * TILE_PX + TILE_PX * 0.5, foot)))
				trees.append(_add_tree(SMALL_TREE_SCENE, Vector2(wx * TILE_PX + TILE_PX * 1.5, foot)))
	chunk_trees[chunk] = trees

func _add_tree(scene: PackedScene, at: Vector2) -> Node:
	var tree := scene.instantiate()
	tree.position = at
	tree_parent.add_child(tree)
	return tree

# The variant is derived from the position so a chunk looks the same every
# time it is streamed back in, rather than reshuffling on every visit.
func _atlas_tile(wx: int, wy: int) -> int:
	var terrain := _terrain_at(wx, wy)
	if terrain < EDGE_PAIRS.size():
		var kind := _edge_kind(wx, wy, terrain + 1)
		if kind >= 0:
			return _edge_atlas(terrain, kind)
	var count: int = TERRAIN_VARIANTS[terrain]
	if count == 1:
		return atlas_offsets[terrain]
	return atlas_offsets[terrain] + absi(hash(Vector3i(wx, wy, world_seed))) % count

# Which border piece a cell needs, from the sides the terrain above touches.
# Returns -1 when no single piece fits, which falls back to a plain fill.
func _edge_kind(wx: int, wy: int, upper: int) -> int:
	var n := _terrain_at(wx, wy - 1) >= upper
	var e := _terrain_at(wx + 1, wy) >= upper
	var s := _terrain_at(wx, wy + 1) >= upper
	var w := _terrain_at(wx - 1, wy) >= upper
	match int(n) + int(e) + int(s) + int(w):
		1:
			if n: return 0
			if e: return 1
			if s: return 2
			return 3
		2:
			if n and e: return 8
			if s and e: return 9
			if s and w: return 10
			if n and w: return 11
			return -1
		0:
			if _terrain_at(wx + 1, wy - 1) >= upper: return 4
			if _terrain_at(wx + 1, wy + 1) >= upper: return 5
			if _terrain_at(wx - 1, wy + 1) >= upper: return 6
			if _terrain_at(wx - 1, wy - 1) >= upper: return 7
	return -1

func _terrain_at(vx: int, vy: int) -> int:
	if _is_water(vx, vy):
		return WATER
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if _is_water(vx + ox, vy + oy):
				return SAND
	return GRASS

# Forest cells still come from the noise, but now decide where a tree object
# stands rather than which tile gets painted.
func _has_tree(wx: int, wy: int) -> bool:
	if wx % TREE_TILES != 0 or wy % TREE_TILES != 0:
		return false
	if not _is_forest(wx, wy):
		return false
	# The canopy covers the whole block, so every cell under it has to be
	# grass; otherwise a tree ends up standing in a lake or on the shoreline.
	for oy in TREE_TILES:
		for ox in TREE_TILES:
			if _terrain_at(wx + ox, wy + oy) != GRASS:
				return false
	return true

# A lone tree in open grass reads as debris rather than woodland, so a tile
# only keeps its tree if it has at least one orthogonal neighbour tree.
func _is_forest(wx: int, wy: int) -> bool:
	if not _is_forest_candidate(wx, wy):
		return false
	return (_is_forest_candidate(wx - 1, wy) or _is_forest_candidate(wx + 1, wy)
		or _is_forest_candidate(wx, wy - 1) or _is_forest_candidate(wx, wy + 1))

func _is_forest_candidate(wx: int, wy: int) -> bool:
	if absi(wx) <= SPAWN_CLEARANCE and absi(wy) <= SPAWN_CLEARANCE:
		return false
	if forest_noise.get_noise_2d(wx, wy) < FOREST_LEVEL:
		return false
	return clearing_noise.get_noise_2d(wx, wy) > CLEARING_LEVEL

func _is_water(wx: int, wy: int) -> bool:
	if absi(wx) <= SPAWN_CLEARANCE and absi(wy) <= SPAWN_CLEARANCE:
		return false
	var lake := _lake_for_region(floori(float(wx) / LAKE_REGION), floori(float(wy) / LAKE_REGION))
	if lake.z == 0.0:
		return false
	var dist := Vector2(wx, wy).distance_to(Vector2(lake.x, lake.y))
	return dist + noise.get_noise_2d(wx, wy) * SHORE_WOBBLE < lake.z

# Returns (center_x, center_y, radius) for the region's lake; radius 0 means none.
func _lake_for_region(rx: int, ry: int) -> Vector3:
	var key := Vector2i(rx, ry)
	if lakes.has(key):
		return lakes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(rx, ry, world_seed))
	var lake := Vector3.ZERO
	if rng.randf() < LAKE_CHANCE:
		var radius := rng.randf_range(LAKE_RADIUS_MIN, LAKE_RADIUS_MAX)
		var margin := radius + SHORE_WOBBLE + 1.0
		lake = Vector3(
			rx * LAKE_REGION + rng.randf_range(margin, LAKE_REGION - margin),
			ry * LAKE_REGION + rng.randf_range(margin, LAKE_REGION - margin),
			radius
		)
	lakes[key] = lake
	return lake

func _unload_chunk(chunk: Vector2i) -> void:
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx := chunk.x * CHUNK_SIZE + lx
			var wy := chunk.y * CHUNK_SIZE + ly
			tilemap.erase_cell(0, Vector2i(wx, wy))
	loaded_chunks.erase(chunk)
	for tree: Node in chunk_trees.get(chunk, []):
		tree.queue_free()
	chunk_trees.erase(chunk)
