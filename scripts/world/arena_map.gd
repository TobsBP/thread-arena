class_name ArenaMap
extends Node2D

## Cenário da arena: chão de grama, construções, árvores e pedras.
## Só monta os nós no _ready() — não sabe nada de players, threads ou medição
## (isso é main.gd). Fica com z_index negativo pra ficar atrás das unidades,
## que main.gd ainda desenha no próprio _draw().

## Mundo maior que a janela; a câmera de main.gd enquadra os players nele.
const WORLD := Vector2(3200, 1800)
const TILE := 64

const GROUND := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png")
const GRASS_CELL := Vector2i(1, 1)  ## célula 100% grama do tileset 9x6

const TREES := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree4.png"),
]
const TREE_FRAMES := 8  ## as folhas de árvore são 8 quadros de balanço lado a lado

## Construções fixas: [textura, posição em fração do mundo].
const BUILDINGS := [
	[preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Castle.png"), Vector2(0.04, 0.04)],
	[preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Red Buildings/Tower.png"), Vector2(0.46, 0.02)],
	[preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Yellow Buildings/House1.png"), Vector2(0.62, 0.08)],
	[preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png"), Vector2(0.80, 0.03)],
]

const BUSHES := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Bushes/Bushe4.png"),
]
const BUSH_FRAMES := 8

const ROCKS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks/Rock4.png"),
]

const SWAY_FPS := 8.0  ## balanço de árvores e arbustos

## Layout fixo (seed constante) pra a demo abrir sempre igual.
@export var layout_seed := 20260902

## Retângulos que barram as unidades (base das árvores e das construções).
## Preenchido no _ready() e só lido depois — as threads leem sem lock.
var blockers: Array[Rect2] = []

@onready var ground: TileMapLayer = $Ground
@onready var decor: Node2D = $Decor


func _ready() -> void:
	_build_ground()
	_build_decor()


## Um TileMapLayer com um TileSet de uma célula só: o chão inteiro vira um
## desenho só, no lugar dos ~1400 draw_texture_rect_region por frame de antes.
func _build_ground() -> void:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = GROUND
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(GRASS_CELL)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source_id := tile_set.add_source(atlas)
	ground.tile_set = tile_set
	for y in ceili(WORLD.y / TILE):
		for x in ceili(WORLD.x / TILE):
			ground.set_cell(Vector2i(x, y), source_id, GRASS_CELL)


## Construções e vegetação viram nós filhos de Decor: as fixas nas frações
## dadas, o resto sorteado nas bordas — a faixa do meio é a arena.
func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	for b in BUILDINGS:
		var tex: Texture2D = b[0]
		var pos := (b[1] as Vector2) * WORLD
		_add_decor(tex, pos, 1)
		# Base da construção: a metade de baixo, sem a beirada do telhado.
		var size := tex.get_size()
		blockers.append(Rect2(pos + Vector2(size.x * 0.15, size.y * 0.5),
				Vector2(size.x * 0.7, size.y * 0.45)))
	for _i in 60:
		var tree: Texture2D = TREES[rng.randi() % TREES.size()]
		var spot := _edge_spot(rng)
		_add_decor(tree, spot, TREE_FRAMES)
		# Tronco: um retângulo pequeno no pé do quadro, a copa não bloqueia.
		var fw := tree.get_width() / TREE_FRAMES
		blockers.append(Rect2(spot + Vector2(fw * 0.5 - 18.0, tree.get_height() - 38.0),
				Vector2(36.0, 26.0)))
	for _i in 30:
		_add_decor(BUSHES[rng.randi() % BUSHES.size()], _edge_spot(rng), BUSH_FRAMES)
	for _i in 40:
		_add_decor(ROCKS[rng.randi() % ROCKS.size()],
				Vector2(rng.randf(), rng.randf()) * WORLD, 1)


## Parado vira Sprite2D; animado vira AnimatedSprite2D tocando sozinho, com o
## ciclo defasado pelo índice pra as árvores não balançarem em bloco.
func _add_decor(tex: Texture2D, pos: Vector2, frames: int) -> void:
	var node: Node2D
	if frames == 1:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		node = sprite
	else:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = _sway_frames(tex, frames)
		node = anim
		anim.play()
		anim.set_frame_and_progress(decor.get_child_count() % frames, 0.0)
	node.centered = false
	node.position = pos
	decor.add_child(node)


func _sway_frames(tex: Texture2D, frames: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", SWAY_FPS)
	var size := Vector2i(tex.get_width() / frames, tex.get_height())
	for f in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(Vector2i(f * size.x, 0), size)
		sf.add_frame("default", atlas)
	return sf


## Posição fora da faixa central, onde os players andam.
func _edge_spot(rng: RandomNumberGenerator) -> Vector2:
	var y := rng.randf()
	if y > 0.32 and y < 0.7:
		y = 0.72 + rng.randf() * 0.24
	return Vector2(rng.randf(), y) * WORLD
