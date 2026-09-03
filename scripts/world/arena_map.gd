class_name ArenaMap
extends Node2D

## Cenário da arena: uma ilha de grama cercada de água, com construções,
## árvores, pedras, acampamento e fogueiras, mais as nuvens passando por cima.
## Só monta os nós no _ready() — não sabe nada de players, threads ou medição
## (isso é main.gd). Fica com z_index negativo pra ficar atrás do HUD.
##
## As unidades entram aqui pelo `add_unit()`: elas são desenhadas por nós
## irmãos das árvores dentro do `Decor`, que é y-sorted — é assim que o player
## passa atrás de uma árvore. O dado da unidade continua RefCounted, longe da
## árvore de cena, então a Thread segue mexendo só no Player.

## Mundo maior que a janela; a câmera de main.gd enquadra os players nele.
## Múltiplo de TILE nos dois eixos pra ilha fechar na grade.
const WORLD := Vector2(3200, 1792)
const TILE := 64
const SHORE := 192.0  ## 3 tiles de água em volta da ilha
## Terra firme (WORLD menos a faixa de água), e dentro dela a faixa onde as
## unidades andam — 96px a menos de cada lado pra ninguém pisar na beirada.
const ISLAND := Rect2(192, 192, 2816, 1408)
const PLAY_AREA := Rect2(288, 288, 2624, 1216)

const GROUND := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png")
const WATER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Water Background color.png")
## O tileset tem a ilha de grama num bloco 3x3: (1,1) é o miolo, o resto é
## borda — daí sai a beirada da ilha inteira.
const GRASS_CELL := Vector2i(1, 1)

const TREES := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree4.png"),
]
const TREE_FRAMES := 8  ## as folhas de árvore são 8 quadros de balanço lado a lado

## Construções fixas: [textura, posição em fração da ilha].
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

## Cacareco de acampamento: conta que alguém trabalha aqui. Tudo parado e sem
## blocker — é enfeite de chão, não obstáculo.
const PROPS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 4.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Wood Resource/Wood Resource.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Meat Resource/Meat Resource.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Resource/Gold_Resource.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Tools/Tool_01.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Tools/Tool_02.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Tools/Tool_03.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Tools/Tool_04.png"),
]
const GOLD_STONES := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Stones/Gold Stone 1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Stones/Gold Stone 3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Gold/Gold Stones/Gold Stone 5.png"),
]

## Pedras e um pato boiando na faixa de água — a borda não fica vazia. As
## duas texturas são tiras animadas (marola na pedra, pato balançando).
const WATER_ROCKS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_01.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_02.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_03.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rocks in the Water/Water Rocks_04.png"),
]
const WATER_ROCK_FRAMES := 16
const DUCK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Rubber Duck/Rubber duck.png")
const DUCK_FRAMES := 3

## Fogueiras: os únicos pontos quentes do mapa, um por canto habitado. O pack
## não tem uma fogueira pronta — é a pilha de lenha com a chama por cima, a
## sombra embaixo e uma luz em volta.
const FIRE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Fire_02.png")
const FIRE_WOOD := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Wood Resource/Wood Resource.png")
const FIRE_SHADOW := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Shadow.png")
const FIRE_FRAMES := 10
const FIRE_FPS := 12.0
const CAMPFIRES := [
	Vector2(0.14, 0.20), Vector2(0.53, 0.10), Vector2(0.71, 0.19),
	Vector2(0.30, 0.88), Vector2(0.88, 0.82),
]
## Chama assentada na lenha e luz centrada nela — os dois no olho, ajuste aqui.
@export var fire_offset := Vector2(0, -34)
@export var fire_light_color := Color(1.0, 0.72, 0.36)
@export var fire_light_energy := 1.1
@export var fire_light_scale := 3.0
## Fim de tarde: sem isso a luz das fogueiras não teria o que clarear.
@export var ambient := Color(0.80, 0.78, 0.92)

## Nuvens: a única coisa que atravessa o mapa inteiro — passam por cima das
## unidades, translúcidas, cada uma na sua velocidade (parallax pelo alpha).
const CLOUDS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_01.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_03.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_05.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_07.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_08.png"),
]
const CLOUD_COUNT := 9
const CLOUD_SPEED := 90.0  ## px/s no alpha máximo; as fracas andam mais devagar
const CLOUD_WIDTH := 576.0

const SWAY_FPS := 8.0  ## balanço de árvores e arbustos

## Layout fixo (seed constante) pra a demo abrir sempre igual.
@export var layout_seed := 20260902

## Retângulos que barram as unidades (base das árvores e das construções).
## Preenchido no _ready() e só lido depois — as threads leem sem lock.
var blockers: Array[Rect2] = []

@onready var water: TileMapLayer = $Water
@onready var ground: TileMapLayer = $Ground
@onready var decor: Node2D = $Decor
@onready var clouds: Node2D = $Clouds


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	$Ambient.color = ambient
	_build_ground()
	_build_decor(rng)
	_build_clouds(rng)


## Só as nuvens se mexem por conta própria; o resto do cenário é parado ou
## anima sozinho no AnimatedSprite2D.
func _process(delta: float) -> void:
	for c in clouds.get_children():
		var sprite := c as Sprite2D
		sprite.position.x += CLOUD_SPEED * sprite.modulate.a * delta
		if sprite.position.x > WORLD.x:
			sprite.position.x = -CLOUD_WIDTH * sprite.scale.x


## Nuvem mais opaca = mais perto = mais rápida: a camada inteira ganha
## profundidade sem nenhuma conta de parallax.
func _build_clouds(rng: RandomNumberGenerator) -> void:
	for _i in CLOUD_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = CLOUDS[rng.randi() % CLOUDS.size()]
		sprite.centered = false
		sprite.scale = Vector2.ONE * rng.randf_range(1.0, 2.2)
		sprite.position = Vector2(rng.randf() * WORLD.x, rng.randf() * WORLD.y)
		sprite.modulate = Color(1.0, 1.0, 1.0, rng.randf_range(0.10, 0.30))
		clouds.add_child(sprite)


## Nó de desenho de uma unidade, irmão das árvores: entra no Decor y-sorted,
## então unidade e cenário se ordenam pela linha dos pés.
func add_unit(sprite: UnitSprite) -> void:
	decor.add_child(sprite)


## Dois TileMapLayer de uma célula cada: água no mundo inteiro e a ilha de
## grama por cima, com a beirada montada do bloco 3x3 do tileset.
func _build_ground() -> void:
	var cols := int(WORLD.x) / TILE
	var rows := int(WORLD.y) / TILE
	var water_id := _single_tile_set(water, WATER, Vector2i.ZERO)
	for y in rows:
		for x in cols:
			water.set_cell(Vector2i(x, y), water_id, Vector2i.ZERO)

	var atlas := TileSetAtlasSource.new()
	atlas.texture = GROUND
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for cy in 3:
		for cx in 3:
			atlas.create_tile(Vector2i(cx, cy))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	var source_id := tile_set.add_source(atlas)
	ground.tile_set = tile_set
	var first := int(SHORE) / TILE
	var last_x := cols - first - 1
	var last_y := rows - first - 1
	for y in range(first, last_y + 1):
		for x in range(first, last_x + 1):
			ground.set_cell(Vector2i(x, y), source_id,
					Vector2i(_edge_cell(x, first, last_x), _edge_cell(y, first, last_y)))


## 0 na primeira faixa, 2 na última, o miolo no meio: serve pros dois eixos.
func _edge_cell(i: int, first: int, last: int) -> int:
	if i == first:
		return 0
	return 2 if i == last else 1


func _single_tile_set(layer: TileMapLayer, tex: Texture2D, cell: Vector2i) -> int:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE, TILE)
	atlas.create_tile(cell)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	layer.tile_set = tile_set
	return tile_set.add_source(atlas)


## Construções e vegetação viram nós filhos de Decor: as fixas nas frações
## dadas, o resto sorteado nas bordas — a faixa do meio é a arena.
func _build_decor(rng: RandomNumberGenerator) -> void:
	# Quem está mais embaixo é desenhado por cima — vale entre cenário e
	# unidades, que entram neste mesmo nó pelo add_unit().
	decor.y_sort_enabled = true
	for b in BUILDINGS:
		var tex: Texture2D = b[0]
		var pos := _fit(ISLAND.position + (b[1] as Vector2) * ISLAND.size, tex, 1)
		_add_decor(tex, pos, 1)
		# Base da construção: a metade de baixo, sem a beirada do telhado.
		var size := tex.get_size()
		blockers.append(Rect2(pos + Vector2(size.x * 0.15, size.y * 0.5),
				Vector2(size.x * 0.7, size.y * 0.45)))
	for _i in 60:
		var tree: Texture2D = TREES[rng.randi() % TREES.size()]
		var spot := _fit(_edge_spot(rng), tree, TREE_FRAMES)
		_add_decor(tree, spot, TREE_FRAMES)
		# Tronco: um retângulo pequeno no pé do quadro, a copa não bloqueia.
		var fw := tree.get_width() / TREE_FRAMES
		blockers.append(Rect2(spot + Vector2(fw * 0.5 - 18.0, tree.get_height() - 38.0),
				Vector2(36.0, 26.0)))
	for _i in 30:
		var bush: Texture2D = BUSHES[rng.randi() % BUSHES.size()]
		_add_decor(bush, _fit(_edge_spot(rng), bush, BUSH_FRAMES), BUSH_FRAMES)
	for _i in 40:
		var rock: Texture2D = ROCKS[rng.randi() % ROCKS.size()]
		_add_decor(rock, _fit(_land_spot(rng), rock, 1), 1)
	for _i in 26:
		var prop: Texture2D = PROPS[rng.randi() % PROPS.size()]
		_add_decor(prop, _fit(_land_spot(rng), prop, 1), 1)
	# Ouro só nas bordas: no meio ia virar enfeite pisado o tempo todo.
	for _i in 8:
		var gold: Texture2D = GOLD_STONES[rng.randi() % GOLD_STONES.size()]
		_add_decor(gold, _fit(_edge_spot(rng), gold, 1), 1)
	for _i in 14:
		_add_decor(WATER_ROCKS[rng.randi() % WATER_ROCKS.size()], _water_spot(rng),
				WATER_ROCK_FRAMES)
	_add_decor(DUCK, _water_spot(rng), DUCK_FRAMES)
	for spot in CAMPFIRES:
		_add_campfire(ISLAND.position + (spot as Vector2) * ISLAND.size)


## Empurra o canto do quadro pra dentro da ilha: sorteio perto da beirada
## deixaria a árvore (ou a casa) com metade na água.
func _fit(spot: Vector2, tex: Texture2D, frames: int) -> Vector2:
	var size := Vector2(tex.get_width() / frames, tex.get_height())
	return spot.clamp(ISLAND.position, ISLAND.end - size)


## Sombra + lenha + chama + luz, todos na mesma linha de base pra o y-sort
## tratar a fogueira como um objeto só.
func _add_campfire(pos: Vector2) -> void:
	# Sombra 192x192 centrada na lenha, com a base logo acima dela pra o
	# y-sort desenhar a sombra primeiro.
	var shadow := _add_decor(FIRE_SHADOW, pos + Vector2(-64, -132), 1) as Sprite2D
	shadow.modulate = Color(1, 1, 1, 0.3)
	_add_decor(FIRE_WOOD, pos, 1)
	_add_decor(FIRE, pos + fire_offset, FIRE_FRAMES, FIRE_FPS)
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.color = fire_light_color
	light.energy = fire_light_energy
	light.texture_scale = fire_light_scale
	light.position = pos + fire_offset + Vector2(32, 32)
	decor.add_child(light)


## Um degradê radial branco->transparente serve de luz; não tem sprite de luz
## no pack e o Godot gera essa textura sozinho.
func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


## Parado vira Sprite2D; animado vira AnimatedSprite2D tocando sozinho, com o
## ciclo defasado pelo índice pra as árvores não balançarem em bloco. A
## origem do nó fica no pé do quadro: é a linha que o y-sort compara.
func _add_decor(tex: Texture2D, pos: Vector2, frames: int, fps := SWAY_FPS) -> Node2D:
	var node: Node2D
	var height := tex.get_height()
	if frames == 1:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.offset = Vector2(0, -height)
		node = sprite
	else:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = _sway_frames(tex, frames, fps)
		anim.centered = false
		anim.offset = Vector2(0, -height)
		node = anim
		anim.play()
		anim.set_frame_and_progress(decor.get_child_count() % frames, 0.0)
	node.position = pos + Vector2(0, height)
	decor.add_child(node)
	return node


func _sway_frames(tex: Texture2D, frames: int, fps: float) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", fps)
	var size := Vector2i(tex.get_width() / frames, tex.get_height())
	for f in frames:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2i(Vector2i(f * size.x, 0), size)
		sf.add_frame("default", atlas)
	return sf


## Em terra firme, em qualquer lugar.
func _land_spot(rng: RandomNumberGenerator) -> Vector2:
	return ISLAND.position + Vector2(rng.randf(), rng.randf()) * ISLAND.size


## Em terra, fora da faixa central onde os players andam.
func _edge_spot(rng: RandomNumberGenerator) -> Vector2:
	var y := rng.randf()
	if y > 0.32 and y < 0.7:
		y = 0.72 + rng.randf() * 0.24
	return ISLAND.position + Vector2(rng.randf(), y) * ISLAND.size


## Na água: sorteia no mundo inteiro e joga pra fora da ilha pelo lado mais
## perto — a faixa é estreita demais pra sortear direto nela.
func _water_spot(rng: RandomNumberGenerator) -> Vector2:
	var p := Vector2(rng.randf(), rng.randf()) * WORLD
	if rng.randf() < 0.5:
		p.x = rng.randf() * SHORE if p.x < WORLD.x * 0.5 else WORLD.x - rng.randf() * SHORE
	else:
		p.y = rng.randf() * SHORE if p.y < WORLD.y * 0.5 else WORLD.y - rng.randf() * SHORE
	return p
