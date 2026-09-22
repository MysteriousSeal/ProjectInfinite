extends Node2D

const CHUNK_SIZE := 16
const TILE_PX := 16
const LOAD_RADIUS := 2
const WORLD_COLLISION_LAYER := 1

const GRASS_TILE := 0
const WATER_TILE := 1
const SAND_TILE := 2

# Keeps the player's spawn area walkable so a random seed can't trap them in water.
const SPAWN_CLEARANCE := 2

@onready var tilemap: TileMap = $TileMap

var player: Node2D
var loaded_chunks: Dictionary = {}
var noise := FastNoiseLite.new()

func _ready() -> void:
	noise.seed = randi()
	noise.frequency = 0.05
	_build_tileset()

func _build_tileset() -> void:
	var colors := [Color(0.19, 0.56, 0.24), Color(0.16, 0.45, 0.85), Color(0.75, 0.68, 0.45)]
	var img := Image.create_empty(TILE_PX * colors.size(), TILE_PX, false, Image.FORMAT_RGBA8)
	for i in colors.size():
		img.fill_rect(Rect2i(i * TILE_PX, 0, TILE_PX, TILE_PX), colors[i])
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
			var n := noise.get_noise_2d(wx, wy)
			var tile_id := GRASS_TILE
			if n < -0.3:
				tile_id = WATER_TILE
			elif n < -0.15:
				tile_id = SAND_TILE
			if absi(wx) <= SPAWN_CLEARANCE and absi(wy) <= SPAWN_CLEARANCE:
				tile_id = GRASS_TILE
			tilemap.set_cell(0, Vector2i(wx, wy), 0, Vector2i(tile_id, 0))
	loaded_chunks[chunk] = true

func _unload_chunk(chunk: Vector2i) -> void:
	for ly in range(CHUNK_SIZE):
		for lx in range(CHUNK_SIZE):
			var wx := chunk.x * CHUNK_SIZE + lx
			var wy := chunk.y * CHUNK_SIZE + ly
			tilemap.erase_cell(0, Vector2i(wx, wy))
	loaded_chunks.erase(chunk)
