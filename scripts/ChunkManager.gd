extends Node2D

const CHUNK_SIZE := 16
const TILE_PX := 16
const LOAD_RADIUS := 2
const WORLD_COLLISION_LAYER := 1

const GRASS_TILE := 0
const WATER_TILE := 1
const SAND_TILE := 2
const TREE_TILE := 3

const GRASS_COLOR := Color(0.19, 0.56, 0.24)
const WATER_COLOR := Color(0.16, 0.45, 0.85)
const SAND_COLOR := Color(0.75, 0.68, 0.45)

# Wang tileset from PixelLab. Only the all-canopy tile is used for now; the
# other 15 are edge and corner pieces kept for when forests get autotiled.
const CANOPY_SHEET := preload("res://assets/tilesets/forest_canopy.png")
const CANOPY_SHEET_RECT := Rect2i(0, 48, 16, 16)

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
	var colors := [GRASS_COLOR, WATER_COLOR, SAND_COLOR, GRASS_COLOR]
	var img := Image.create_empty(TILE_PX * colors.size(), TILE_PX, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.fill_rect(Rect2i(i * TILE_PX, 0, TILE_PX, TILE_PX), colors[i])
	var canopy := CANOPY_SHEET.get_image()
	canopy.convert(Image.FORMAT_RGBA8)
	img.blit_rect(canopy, CANOPY_SHEET_RECT, Vector2i(TREE_TILE * TILE_PX, 0))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(img)
	atlas.texture_region_size = Vector2i(TILE_PX, TILE_PX)
	for i in colors.size():
		atlas.create_tile(Vector2i(i, 0))
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_PX, TILE_PX)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, WORLD_COLLISION_LAYER)
	tileset.add_source(atlas, 0)
	_make_tile_solid(atlas, WATER_TILE)
	_make_tile_solid(atlas, TREE_TILE)
	tilemap.tile_set = tileset

func _make_tile_solid(atlas: TileSetAtlasSource, tile_id: int) -> void:
	var half := TILE_PX / 2.0
	var tile_data := atlas.get_tile_data(Vector2i(tile_id, 0), 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)
	]))

func follow(target: Node2D) -> void:
	player = target

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
			tilemap.set_cell(0, Vector2i(wx, wy), 0, Vector2i(_tile_at(wx, wy), 0))
	loaded_chunks[chunk] = true

func _tile_at(wx: int, wy: int) -> int:
	if _is_water(wx, wy):
		return WATER_TILE
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if _is_water(wx + ox, wy + oy):
				return SAND_TILE
	if _is_forest(wx, wy):
		return TREE_TILE
	return GRASS_TILE

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
