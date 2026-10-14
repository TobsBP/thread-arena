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
## borda — daí sai a beirada da ilha inteira, e também as manchas de grama
## mais escura por cima dela.
const GRASS_PATCH := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color3.png")
const PATCH_COUNT := 18
## Só o miolo do bloco: as peças de borda são beirada de barranco e deixavam
## cada mancha com um contorno retangular no meio do campo.
const PATCH_CELL := Vector2i(1, 1)
## E translúcida, pra ser variação de tom e não um remendo.
const PATCH_ALPHA := 0.45

## Relevo: platôs de pedra com grama em cima, montados da metade direita do
## mesmo tileset (colunas 5-7 são o topo elevado, linhas 4-5 são a parede de
## pedra) — daí sai o barranco de verdade, sem terrain set.
## Cada platô é uma união de retângulos em tiles, pra a silhueta não ser
## sempre o mesmo bloco: um L, uma crista comprida e um T. `ramp` é a célula
## da beirada de baixo onde a parede abre — é o único jeito de subir, os
## blockers fecham todo o resto do contorno.
const PLATEAUS := [
	{"parts": [Rect2i(6, 13, 4, 5), Rect2i(10, 15, 5, 3)], "ramp": Vector2i(11, 17)},
	{"parts": [Rect2i(18, 8, 8, 3)], "ramp": Vector2i(21, 10)},
	{"parts": [Rect2i(37, 14, 6, 3), Rect2i(38, 17, 4, 3)], "ramp": Vector2i(39, 19)},
]
const WALL_ROWS := 2  ## altura da parede de pedra, em tiles
const RAMP_W := 2  ## largura do vão da rampa, em tiles
## Colunas e linhas do bloco elevado dentro do tileset, por posição
## (primeira / miolo / última).
## (a 4a coluna/linha de cada bloco é uma ponta estreita, com folga
## transparente do lado — encaixa com seam. A ilha já usa só as 3 primeiras.)
const TOP_COLS := [5, 6, 7]
const TOP_ROWS := [0, 1, 2]
const WALL_ROW := [4, 5]  ## de cima pra baixo
const PLATEAU_CLEAR := 48.0
## Tufos de mato espalhados pelo campo: são os arbustos do pack em escala
## menor, e já vêm com o balanço de 8 quadros.
const TUFT_COUNT := 80
const TUFT_SCALE := 0.42
## Onde fica o pé dos objetos de chão dentro do quadro: eles são pequenos e
## centrados, com folga transparente embaixo.
const GROUND_FOOT := 0.78

## Espuma da costa: 16 quadros, cada um um bloco 3x3 igual ao da grama. Vira
## tile animado e cerca a ilha por fora, na água.
const FOAM := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Water Foam.png")
const FOAM_FRAMES := 16
const FOAM_FPS := 10.0

const TREES := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Tree4.png"),
]
const TREE_FRAMES := 8  ## as folhas de árvore são 8 quadros de balanço lado a lado
## Toco de cada árvore acima, na mesma ordem — vira o desenho quando cortada
## (ver chop_tree()). REGROW_TIME é quanto tempo até a árvore voltar a crescer.
const STUMPS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 1.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 2.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 3.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Wood/Trees/Stump 4.png"),
]
const REGROW_TIME := 25.0
## Nos últimos GROW_TIME segundos o toco dá lugar a uma muda que cresce até o tamanho cheio.
const GROW_TIME := 7.0
const SAPLING_SCALE := 0.25
const FELL_TIME := 0.6  ## a árvore cortada tomba e some

## Castelo principal: a única construção que já começa no mapa (abre a
## árvore de evolução, ver CastleMenu) — o resto o jogador ergue. No meio da
## ilha, abaixo do platô central e logo abaixo da linha onde os players
## nascem. É o único azul: o Castelo que o jogador constrói é amarelo.
const MAIN_CASTLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Castle.png")
const MAIN_CASTLE_AT := Vector2(0.445, 0.58)  ## canto de cima, em fração da ilha
## Folga em volta do castelo onde árvore/pedra/enfeite não nascem. Os pontos
## sorteados são o canto de cima do sprite, por isso a folga é maior em
## cima/à esquerda (o tamanho de uma árvore); embaixo fica a pracinha da
## porta, onde se entrega a coleta.
const CASTLE_CLEAR_TOP_LEFT := Vector2(200, 260)
const CASTLE_CLEAR := 24.0
const CASTLE_PLAZA := 160.0

## Construções que o jogador ergue (BuildSite): [pronta, obra]. As obras do
## Update 010 têm o mesmo tamanho de quadro das prontas do Free Pack; o
## Quartel não tem obra no pack, então usa a pronta apagada (BUILD_GHOST_TINT).
const BUILD_TEX := {
	&"house": [preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/House1.png"),
		preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Buildings/House/House_Construction.png")],
	&"castle": [preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Yellow Buildings/Castle.png"),
		preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Buildings/Castle/Castle_Construction.png")],
	&"tower": [preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Tower.png"),
		preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Buildings/Tower/Tower_Construction.png")],
	&"barracks": [preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Buildings/Blue Buildings/Barracks.png"), null],
}
const BUILD_GHOST_TINT := Color(0.6, 0.6, 0.6, 0.55)

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
## Mina de ouro de verdade (pack Update 010) no lugar das pedrinhas soltas —
## prédio, então ganha blocker como as construções, e a coleta (main.gd) usa
## a mesma gold_spots de sempre, só menos pontos (mina é maior que pedra).
const GOLD_MINE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Gold Mine/GoldMine_Active.png")
const GOLD_MINE_COUNT := 8

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

## Ponte de enfeite saindo da borda de baixo da ilha pra dentro da água — só
## visual (PLAY_AREA não chega lá, não precisa de blocker nem de conectar
## nada). BRIDGE_ALL é uma folha com vários pedaços; BRIDGE_PIECE_RECT
## recorta só o segmento horizontal (canto superior esquerdo da folha).
const BRIDGE_ALL := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Terrain/Bridge/Bridge_All.png")
const BRIDGE_PIECE_RECT := Rect2(18, 0, 132, 64)

## Fogueiras: os únicos pontos quentes do mapa, um por canto habitado. O pack
## não tem uma fogueira pronta.
const CAMPFIRE_LIT := preload("res://assets/Thread Arena/Campfire_Lit.png")
const CAMPFIRE_OUT := preload("res://assets/Thread Arena/Campfire_Out.png")
const FIRE_SHADOW := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Shadow.png")
const CAMPFIRE_FRAMES := 8
const CAMPFIRE_SIZE := Vector2(96, 112)
const FIRE_FPS := 10.0
const CAMPFIRE_CLEAR := 140.0  ## raio em volta da fogueira onde não nasce árvore
## Espeto sobre a fogueira da vila (arte nossa, mesmo quadro da fogueira)
const SPIT_RAW := preload("res://assets/Thread Arena/Spit_Raw.png")
const SPIT_ROAST := preload("res://assets/Thread Arena/Spit_Roast.png")
## Recurso "pipocando" (pack Update 010, 7 quadros de 128px)
const RESOURCE_POPS := [
	preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Resources/W_Spawn.png"),
	preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Resources/G_Spawn.png"),
	preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Resources/M_Spawn.png"),
]
const RESOURCE_POP_FRAMES := 7
const RESOURCE_FOOT := 0.86
const WOOD_CHIP := Color(0.86, 0.71, 0.44)
const GOLD_CHIP := Color(1.0, 0.84, 0.22)
const SPARK := Color(1.0, 0.62, 0.16)
const CAMPFIRES := [
	Vector2(0.14, 0.20), Vector2(0.53, 0.10), Vector2(0.71, 0.19),
	Vector2(0.30, 0.88), Vector2(0.88, 0.82),
	# A da vila: à direita da pracinha do castelo principal, onde os aldeões assam a carne.
	Vector2(0.574, 0.741),
]
## Luz centrada na chama — no olho, ajuste aqui.
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
const NAV_CELL := 32  ## grade dos bots: meio tile, deixa 3 células livres no vão da rampa

## Layout fixo (seed constante) pra a demo abrir sempre igual.
@export var layout_seed := 20260902

## Retângulos que barram as unidades (base das árvores e das construções).
## Montado no _ready() e lido sem lock pelas threads. Só cresce depois disso
## pelo add_blocker() (construção do jogador), na main thread e fora da
## janela t.start()/wait_to_finish() — mesma regra do spawn de goblin.
var blockers: Array[Rect2] = []
## Porta dos castelos (o principal + os erguidos pelo jogador): onde a
## coleta é entregue. main_castle_spot é a porta do principal, que também é
## a base dos pawns de cenário. tree_spots é o pé das árvores.
var castle_spots: Array[Vector2] = []
var main_castle_spot := Vector2.ZERO
var _castle_rect := Rect2()  ## quadro inteiro do principal, pra cenário não nascer em cima
var tree_spots: Array[Vector2] = []
var gold_spots: Array[Vector2] = []
var _mine_nodes: Array[Node2D] = []  ## paralelo a gold_spots, pra mina tremer na picaretada
var _mine_x: Array[float] = []  ## x de repouso de cada mina
## Pé de cada fogueira, na ordem de CAMPFIRES, e os nós de cada uma.
var campfire_spots: Array[Vector2] = []
var _fire_parts: Array[Array] = []
var _fire_corners: Array[Vector2] = []  ## canto do quadro de cada fogueira
var _spits: Dictionary[int, Array] = {}  ## fogueira -> [crua, assada], criado no 1º uso
## Paralelos a tree_spots, pra cada árvore poder virar toco e voltar a
## crescer (ver chop_tree() e o _process()).
var _tree_nodes: Array[Node2D] = []
var _tree_raw_spots: Array[Vector2] = []  ## canto antes do offset do pé, pra recriar o nó
var _tree_tex: Array[Texture2D] = []  ## árvore original, pra restaurar ao crescer de novo
var _tree_stump_tex: Array[Texture2D] = []
var tree_regrow: Array[float] = []  ## <= 0 = árvore em pé e crescida; > 0 = segundos até voltar
var _tree_growing: Array[bool] = []  ## já trocou o toco pela muda (ver GROW_TIME)
var _tree_shake: Dictionary[int, Tween] = {}  ## balanço da machadada em andamento
## Grade A* da PLAY_AREA, com os blockers marcados como sólidos — montada no
## _ready() e só consultada pela main thread (bot_think/chase), nunca na tarefa.
var nav := AStarGrid2D.new()

@onready var water: TileMapLayer = $Water
@onready var foam: TileMapLayer = $Foam
@onready var ground: TileMapLayer = $Ground
@onready var patches: TileMapLayer = $Patches
@onready var plateaus: TileMapLayer = $Plateaus
@onready var decor: Node2D = $Decor
@onready var clouds: Node2D = $Clouds


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	$Ambient.color = ambient
	_build_ground(rng)
	_build_decor(rng)
	_build_clouds(rng)
	_build_nav()


## Só as nuvens se mexem por conta própria e as árvores cortadas contam pra
## voltar a crescer; o resto do cenário é parado ou anima sozinho no
## AnimatedSprite2D.
func _process(delta: float) -> void:
	for c in clouds.get_children():
		var sprite := c as Sprite2D
		sprite.position.x += CLOUD_SPEED * sprite.modulate.a * delta
		if sprite.position.x > WORLD.x:
			sprite.position.x = -CLOUD_WIDTH * sprite.scale.x

	for i in tree_regrow.size():
		if tree_regrow[i] <= 0.0:
			continue
		tree_regrow[i] -= delta
		if not _tree_growing[i] and tree_regrow[i] < GROW_TIME:
			_tree_growing[i] = true
			_tree_nodes[i].queue_free()
			_tree_nodes[i] = _add_tree(_tree_tex[i], _tree_raw_spots[i], TREE_FRAMES)
		if _tree_growing[i]:
			# Cresce a partir do pé (a origem do nó), do tamanho de muda ao cheio.
			var grown := clampf(1.0 - tree_regrow[i] / GROW_TIME, 0.0, 1.0)
			_tree_nodes[i].scale = Vector2.ONE * lerpf(SAPLING_SCALE, 1.0, grown)
			if tree_regrow[i] <= 0.0:
				_tree_growing[i] = false


## Derruba a árvore: tomba pro lado `dir` (+1 direita, -1 esquerda), some e deixa o toco.
func chop_tree(index: int, dir := 1.0) -> void:
	if tree_regrow[index] > 0.0:
		return
	tree_regrow[index] = REGROW_TIME
	_stop_shake(index)
	var falling := _tree_nodes[index]
	_tree_nodes[index] = _add_tree(_tree_stump_tex[index], _tree_raw_spots[index], 1)
	var tween := falling.create_tween()
	tween.tween_property(falling, "rotation", dir * 1.45, FELL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(falling, "modulate:a", 0.0, FELL_TIME * 0.35) \
			.set_delay(FELL_TIME * 0.65)
	tween.tween_callback(falling.queue_free)
	_spawn_chips(tree_spots[index] + Vector2(-dir * 16.0, -16.0), dir, 12, WOOD_CHIP)


## Machadada: a árvore estremece em torno do pé e solta lascas pro lado de quem bate.
func hit_tree(index: int, dir: float) -> void:
	if tree_regrow[index] > 0.0:
		return
	_stop_shake(index)
	var node := _tree_nodes[index]
	var tween := node.create_tween()
	tween.tween_property(node, "rotation", dir * 0.08, 0.05)
	tween.tween_property(node, "rotation", -dir * 0.045, 0.09)
	tween.tween_property(node, "rotation", 0.0, 0.11)
	_tree_shake[index] = tween
	_spawn_chips(tree_spots[index] + Vector2(-dir * 16.0, -16.0), dir, 6, WOOD_CHIP)


## Picaretada: a mina dá um tranco e solta lascas de ouro pro lado de quem bate.
func hit_mine(index: int, dir: float) -> void:
	var node := _mine_nodes[index]
	var rest := _mine_x[index]
	var tween := node.create_tween()
	tween.tween_property(node, "position:x", rest + dir * 3.0, 0.04)
	tween.tween_property(node, "position:x", rest - dir * 2.0, 0.07)
	tween.tween_property(node, "position:x", rest, 0.08)
	_spawn_chips(gold_spots[index] + Vector2(-dir * 44.0, -34.0), dir, 5, GOLD_CHIP)


## O recurso pipoca no chão (a animação de spawn do pack, uma vez só), fica um instante e some.
func pop_resource(kind: int, at: Vector2) -> void:
	var tex: Texture2D = RESOURCE_POPS[kind]
	var anim := _add_decor(tex, at - Vector2(tex.get_height() * 0.5, tex.get_height() * RESOURCE_FOOT),
			RESOURCE_POP_FRAMES, 12.0, RESOURCE_FOOT) as AnimatedSprite2D
	anim.sprite_frames.set_animation_loop("default", false)
	anim.set_frame_and_progress(0, 0.0)
	anim.play()
	var tween := anim.create_tween()
	tween.tween_interval(1.1)
	tween.tween_property(anim, "modulate:a", 0.0, 0.3)
	tween.tween_callback(anim.queue_free)


func _stop_shake(index: int) -> void:
	var tween: Tween = _tree_shake.get(index)
	if tween != null and tween.is_valid():
		tween.kill()
	_tree_shake.erase(index)
	_tree_nodes[index].rotation = 0.0


## Lascas (de madeira, de ouro) saltando de `at` pro lado de quem bate.
func _spawn_chips(at: Vector2, dir: float, amount: int, color: Color) -> void:
	var chips := CPUParticles2D.new()
	chips.position = at
	chips.z_index = 1  # por cima do tronco/da mina, apesar de nascer atrás do pé
	chips.one_shot = true
	chips.explosiveness = 1.0
	chips.amount = amount
	chips.lifetime = 0.5
	chips.direction = Vector2(-dir, -1.3)
	chips.spread = 38.0
	chips.initial_velocity_min = 90.0
	chips.initial_velocity_max = 190.0
	chips.gravity = Vector2(0, 560)
	chips.scale_amount_min = 3.0
	chips.scale_amount_max = 6.0
	chips.color = color
	chips.finished.connect(chips.queue_free)
	decor.add_child(chips)
	chips.emitting = true


## Carne no espeto da fogueira `index`: `progress` < 0 tira o espeto.
func set_spit(index: int, progress: float, turning := true) -> void:
	if not _spits.has(index):
		if progress < 0.0:
			return
		var pair: Array = []
		for tex: Texture2D in [SPIT_RAW, SPIT_ROAST]:
			var node := _add_decor(tex, _fire_corners[index], CAMPFIRE_FRAMES, FIRE_FPS)
			# Mesma linha de base da fogueira + 2px: o espeto fica na frente da chama.
			node.position.y += 2.0
			node.set("offset", (node.get("offset") as Vector2) - Vector2(0, 2))
			pair.append(node)
		_spits[index] = pair
	var raw: Node2D = _spits[index][0]
	var roast: Node2D = _spits[index][1]
	raw.visible = progress >= 0.0
	roast.visible = progress >= 0.0
	roast.modulate.a = clampf(progress, 0.0, 1.0)
	# As duas tiras no mesmo quadro, senão a assada "descola" da crua.
	(raw as AnimatedSprite2D).speed_scale = 1.0 if turning else 0.0
	(roast as AnimatedSprite2D).speed_scale = 1.0 if turning else 0.0
	(roast as AnimatedSprite2D).set_frame_and_progress(
			(raw as AnimatedSprite2D).frame, (raw as AnimatedSprite2D).frame_progress)


## Árvore, toco ou muda: enfeite com a origem no pé do tronco.
func _add_tree(tex: Texture2D, spot: Vector2, frames: int) -> Node2D:
	var node := _add_decor(tex, spot, frames)
	_center_pivot(node, tex.get_width() / frames * 0.5)
	return node


## Leva a origem do nó do canto de baixo pro meio da base do quadro, sem mexer onde ele aparece.
func _center_pivot(node: Node2D, half: float) -> void:
	node.position.x += half
	node.set("offset", (node.get("offset") as Vector2) - Vector2(half, 0))


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


## Célula sólida = o centro dela, como pé de unidade, cairia dentro de um
## blocker — o mesmo teste do Player._push_out(). Toco de árvore segue sólido,
## igual ao blocker, que não muda.
func _build_nav() -> void:
	nav.region = Rect2i(Vector2i(PLAY_AREA.position) / NAV_CELL, Vector2i(PLAY_AREA.size) / NAV_CELL)
	nav.cell_size = Vector2(NAV_CELL, NAV_CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for r in blockers:
		_mark_solid(r)


## Células da grade cobertas pelo blocker (alargado do raio do corpo) viram
## sólidas — usado na montagem e quando o jogador ergue uma construção.
func _mark_solid(r: Rect2) -> void:
	var grown := r.grow(Player.BODY_RADIUS)
	var c0 := Vector2i(grown.position / NAV_CELL)
	var c1 := Vector2i(grown.end / NAV_CELL)
	for x in range(c0.x, c1.x + 1):
		for y in range(c0.y, c1.y + 1):
			var cell := Vector2i(x, y)
			if not nav.is_in_boundsv(cell):
				continue
			if grown.has_point((Vector2(cell) + Vector2(0.5, 0.5)) * NAV_CELL):
				nav.set_point_solid(cell)


## Direção do próximo passo de `from` até `to` (pontos dos pés), contornando
## os blockers. Sem caminho (mesma célula, fora da grade) devolve a reta — o
## _push_out() do step() resolve o resto.
## ponytail: A* a cada chamada, sem cache — ~0,1 ms por frame com 14 goblins
## + 3 bots; cachear o caminho por unidade se o teto de inimigos subir muito.
func nav_dir(from: Vector2, to: Vector2) -> Vector2:
	var straight := (to - from).normalized()
	var a := _free_cell(Vector2i(from / NAV_CELL))
	var b := _free_cell(Vector2i(to / NAV_CELL))
	if a == b or not nav.is_in_boundsv(a) or not nav.is_in_boundsv(b):
		return straight
	var path := nav.get_id_path(a, b, true)
	if path.size() < 3:
		return straight
	# Mira duas células à frente: corta o zigue-zague da grade sem pular quina.
	var next := nav.get_point_position(path[2]) + nav.cell_size * 0.5
	return (next - from).normalized()


## Pé encostado na parede costuma cair numa célula sólida (a borda do blocker
## alargado passa no meio dela): começa da vizinha livre, senão o A* não sai.
func _free_cell(c: Vector2i) -> Vector2i:
	if not nav.is_in_boundsv(c) or not nav.is_point_solid(c):
		return c
	for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var n: Vector2i = c + d
		if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
			return n
	return c


## Nó de desenho de uma unidade, irmão das árvores: entra no Decor y-sorted,
## então unidade e cenário se ordenam pela linha dos pés.
func add_unit(sprite: UnitSprite) -> void:
	decor.add_child(sprite)


## --- Construção pelo jogador -------------------------------------------
## Tudo main thread, chamado por main.gd antes do dispatch das tarefas.

## Base que bloqueia: a metade de baixo do quadro, sem a beirada do telhado —
## a mesma conta das construções fixas.
static func base_rect(pos: Vector2, size: Vector2) -> Rect2:
	return Rect2(pos + Vector2(size.x * 0.15, size.y * 0.5),
			Vector2(size.x * 0.7, size.y * 0.45))


## Cabe ali: dentro da área andável, sem encostar em blocker nenhum (árvore,
## prédio, obra, barranco) e fora do platô (o topo é andável, mas construir
## lá em cima fecharia a rampa). Unidade no caminho é main.gd quem confere.
func can_build(base: Rect2) -> bool:
	if not PLAY_AREA.encloses(base):
		return false
	var grown := base.grow(Player.BODY_RADIUS)
	for r in blockers:
		if grown.intersects(r):
			return false
	for r in _plateau_rects():
		if grown.intersects(r):
			return false
	return true


## Nasce a obra: nó em Decor (y-sorted como o resto) com a textura de obra e
## o blocker já valendo — ninguém atravessa nem o andaime.
func place_building(kind: StringName, pos: Vector2) -> Sprite2D:
	var tex: Array = BUILD_TEX[kind]
	var done: Texture2D = tex[0]
	var node := _add_decor(tex[1] if tex[1] else done, pos, 1) as Sprite2D
	if not tex[1]:
		node.modulate = BUILD_GHOST_TINT
	add_blocker(base_rect(pos, done.get_size()))
	return node


func finish_building(node: Sprite2D, kind: StringName) -> void:
	node.texture = BUILD_TEX[kind][0]
	node.modulate = Color.WHITE


func add_blocker(r: Rect2) -> void:
	blockers.append(r)
	_mark_solid(r)


## Caixa de cada platô (topo + parede), como o _off_plateau() calcula.
func _plateau_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for pl in PLATEAUS:
		var box: Rect2i = pl["parts"][0]
		for r: Rect2i in pl["parts"]:
			box = box.merge(r)
		box.size.y += WALL_ROWS
		out.append(Rect2(Vector2(box.position) * TILE, Vector2(box.size) * TILE))
	return out


## Camadas de chão: água no mundo inteiro, espuma cercando a ilha, a ilha de
## grama e as manchas de grama escura por cima — todas montadas do mesmo bloco
## 3x3 do tileset, sem terrain set nenhum.
func _build_ground(rng: RandomNumberGenerator) -> void:
	var cols := int(WORLD.x) / TILE
	var rows := int(WORLD.y) / TILE
	var water_id := _single_tile_set(water, WATER, Vector2i.ZERO)
	for y in rows:
		for x in cols:
			water.set_cell(Vector2i(x, y), water_id, Vector2i.ZERO)

	var first := int(SHORE) / TILE
	var last_x := cols - first - 1
	var last_y := rows - first - 1
	# A espuma é uma casca de 1 tile em volta da ilha: só a moldura.
	_fill_block(foam, _block_tile_set(foam, FOAM, FOAM_FRAMES),
			first - 1, last_x + 1, first - 1, last_y + 1, true)
	_fill_block(ground, _block_tile_set(ground, GROUND),
			first, last_x, first, last_y)

	# Manchas de grama escura: quebram o verde chapado sem mudar o mapa.
	patches.modulate = Color(1, 1, 1, PATCH_ALPHA)
	var patch_id := _block_tile_set(patches, GRASS_PATCH)
	for _i in PATCH_COUNT:
		var rx := rng.randi_range(2, 5)
		var ry := rng.randi_range(2, 4)
		_fill_blob(patches, patch_id,
				rng.randi_range(first + rx, last_x - rx),
				rng.randi_range(first + ry, last_y - ry), rx, ry, rng)

	var plateau_id := _full_tile_set(plateaus, GROUND)
	for p in PLATEAUS:
		_build_plateau(plateau_id, p["parts"], p["ramp"])


## Um platô: o topo de grama, a parede de pedra embaixo e a rampa, que é uma
## faixa de grama descendo pela parede no lugar da pedra.
## O tile de cada célula sai dos vizinhos (autotile na unha: sem vizinho à
## esquerda = coluna da esquerda, e assim por diante), que é o que deixa a
## silhueta ser qualquer união de retângulos e não só um bloco.
## ponytail: canto côncavo usa o tile de miolo — o tileset não tem peça de
## canto interno. Some no meio da grama; se incomodar, é peça nova, não código.
## ponytail: rampa em tile de grama, e não nas peças diagonais do tileset —
## elas são a ponta chanfrada de um barranco (1 tile de largura, encaixe
## fixo), não um vão de tamanho livre. Trocar se a demo pedir a diagonal.
func _build_plateau(source_id: int, parts: Array, ramp: Vector2i) -> void:
	var cells := {}
	for r: Rect2i in parts:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cells[Vector2i(x, y)] = true

	for c: Vector2i in cells:
		var cx: int = TOP_COLS[_neighbor_cell(cells, c, Vector2i.RIGHT)]
		var cy: int = TOP_ROWS[_neighbor_cell(cells, c, Vector2i.DOWN)]
		var on_ramp := c.y == ramp.y and c.x >= ramp.x and c.x < ramp.x + RAMP_W
		if on_ramp:
			cy = TOP_ROWS[1]  # sem beirada: a grama desce direto pra parede
		plateaus.set_cell(c, source_id, Vector2i(cx, cy))
		if cells.has(c + Vector2i.DOWN):
			continue
		for w in WALL_ROWS:
			# No vão a parede vira grama: é a faixa que desce até o campo.
			var cell := Vector2i(TOP_COLS[1], TOP_ROWS[1])
			if not on_ramp:
				cell = Vector2i(cx, WALL_ROW[w])
			plateaus.set_cell(c + Vector2i.DOWN * (w + 1), source_id, cell)
		if not on_ramp:
			blockers.append(_cell_rect(c + Vector2i.DOWN, WALL_ROWS))

	# Contorno do topo: quem faz beirada é barranco, o miolo fica livre pra
	# andar em cima. O vão da rampa é a única célula de borda sem blocker.
	for c: Vector2i in cells:
		if c.y == ramp.y and c.x >= ramp.x and c.x < ramp.x + RAMP_W:
			continue
		for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(c + dir):
				blockers.append(_cell_rect(c, 1))
				break


## 0 sem vizinho pro lado contrário, 2 sem vizinho pra `dir`, 1 no miolo —
## é o `_edge_cell()` das camadas retangulares, só que olhando os vizinhos.
func _neighbor_cell(cells: Dictionary, c: Vector2i, dir: Vector2i) -> int:
	if not cells.has(c - dir):
		return 0
	return 2 if not cells.has(c + dir) else 1


func _cell_rect(c: Vector2i, rows: int) -> Rect2:
	return Rect2(Vector2(c) * TILE, Vector2(TILE, TILE * rows))


## TileSet com a folha inteira: o platô usa células espalhadas pelo tileset,
## não o bloco 3x3 contíguo que a ilha e a espuma usam.
func _full_tile_set(layer: TileMapLayer, tex: Texture2D) -> int:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE, TILE)
	var size := tex.get_size() / TILE
	for cy in int(size.y):
		for cx in int(size.x):
			atlas.create_tile(Vector2i(cx, cy))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	layer.tile_set = tile_set
	return tile_set.add_source(atlas)


## Mancha em elipse com a borda roída pelo rng: retângulo de tiles se
## reconhece de longe, isto some no campo.
func _fill_blob(layer: TileMapLayer, source_id: int, cx: int, cy: int,
		rx: int, ry: int, rng: RandomNumberGenerator) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / rx
			var dy := float(y - cy) / ry
			if dx * dx + dy * dy > 1.0 - rng.randf() * 0.4:
				continue
			layer.set_cell(Vector2i(x, y), source_id, PATCH_CELL)


## Bloco 3x3 do tileset: borda nas pontas, miolo no meio. `hollow` deixa só a
## moldura, que é o que a espuma precisa.
func _fill_block(layer: TileMapLayer, source_id: int, x0: int, x1: int,
		y0: int, y1: int, hollow := false) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if hollow and x > x0 and x < x1 and y > y0 and y < y1:
				continue
			layer.set_cell(Vector2i(x, y), source_id,
					Vector2i(_edge_cell(x, x0, x1), _edge_cell(y, y0, y1)))


## TileSet com as 9 células do bloco. Com `frames > 1` cada célula vira tile
## animado: os quadros são blocos 3x3 lado a lado, daí a separação de 2.
func _block_tile_set(layer: TileMapLayer, tex: Texture2D, frames := 1) -> int:
	var atlas := TileSetAtlasSource.new()
	atlas.texture = tex
	atlas.texture_region_size = Vector2i(TILE, TILE)
	for cy in 3:
		for cx in 3:
			var cell := Vector2i(cx, cy)
			atlas.create_tile(cell)
			if frames <= 1:
				continue
			atlas.set_tile_animation_separation(cell, Vector2i(2, 0))
			atlas.set_tile_animation_frames_count(cell, frames)
			for f in frames:
				atlas.set_tile_animation_frame_duration(cell, f, 1.0 / FOAM_FPS)
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	layer.tile_set = tile_set
	return tile_set.add_source(atlas)


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
	var castle_pos := _fit(ISLAND.position + MAIN_CASTLE_AT * ISLAND.size, MAIN_CASTLE, 1)
	_add_decor(MAIN_CASTLE, castle_pos, 1)
	var castle_size := MAIN_CASTLE.get_size()
	_castle_rect = Rect2(castle_pos, castle_size)
	blockers.append(base_rect(castle_pos, castle_size))
	main_castle_spot = castle_pos + Vector2(castle_size.x * 0.5, castle_size.y + 20.0)
	castle_spots.append(main_castle_spot)
	for _i in 60:
		var idx := rng.randi() % TREES.size()
		var tree: Texture2D = TREES[idx]
		var spot := _fit(_edge_spot(rng), tree, TREE_FRAMES)
		var fw := tree.get_width() / TREE_FRAMES
		var foot := spot + Vector2(fw * 0.5, tree.get_height() - 25.0)
		# Árvore em cima de fogueira esconde o fogo atrás da copa: essa não nasce.
		if _near_campfire(foot):
			continue
		var node := _add_tree(tree, spot, TREE_FRAMES)
		# Tronco: um retângulo pequeno no pé do quadro, a copa não bloqueia.
		blockers.append(Rect2(spot + Vector2(fw * 0.5 - 18.0, tree.get_height() - 38.0),
				Vector2(36.0, 26.0)))
		tree_spots.append(foot)
		_tree_nodes.append(node)
		_tree_raw_spots.append(spot)
		_tree_tex.append(tree)
		_tree_stump_tex.append(STUMPS[idx])
		tree_regrow.append(0.0)
		_tree_growing.append(false)
	for _i in 30:
		var bush: Texture2D = BUSHES[rng.randi() % BUSHES.size()]
		_add_decor(bush, _fit(_edge_spot(rng), bush, BUSH_FRAMES), BUSH_FRAMES)
	# Tufos: o mesmo arbusto pequeno, espalhado pelo campo todo. É o que faz a
	# grama mexer — o balanço já vem no sprite.
	for _i in TUFT_COUNT:
		var tuft: Texture2D = BUSHES[rng.randi() % BUSHES.size()]
		var node := _add_decor(tuft, _fit(_land_spot(rng), tuft, BUSH_FRAMES),
				BUSH_FRAMES, SWAY_FPS, GROUND_FOOT)
		node.scale = Vector2.ONE * TUFT_SCALE
	for _i in 40:
		var rock: Texture2D = ROCKS[rng.randi() % ROCKS.size()]
		_add_decor(rock, _fit(_land_spot(rng), rock, 1), 1, SWAY_FPS, GROUND_FOOT)
	for _i in 26:
		var prop: Texture2D = PROPS[rng.randi() % PROPS.size()]
		_add_decor(prop, _fit(_land_spot(rng), prop, 1), 1, SWAY_FPS, GROUND_FOOT)
	# Minas só nas bordas: no meio ia virar obstáculo no meio da arena.
	for _i in GOLD_MINE_COUNT:
		var pos := _fit(_edge_spot(rng), GOLD_MINE, 1)
		var mine_node := _add_decor(GOLD_MINE, pos, 1)
		var size := GOLD_MINE.get_size()
		# Prédio pequeno: só a base bloqueia, igual às construções fixas.
		blockers.append(Rect2(pos + Vector2(size.x * 0.15, size.y * 0.55),
				Vector2(size.x * 0.7, size.y * 0.35)))
		gold_spots.append(mine_node.position + Vector2(size.x * 0.5, 0))
		_mine_nodes.append(mine_node)
		_mine_x.append(mine_node.position.x)
	for _i in 14:
		_add_decor(WATER_ROCKS[rng.randi() % WATER_ROCKS.size()], _water_spot(rng),
				WATER_ROCK_FRAMES)
	# Ponte de enfeite saindo da beirada de baixo da ilha pra dentro da água.
	var bridge_tex := AtlasTexture.new()
	bridge_tex.atlas = BRIDGE_ALL
	bridge_tex.region = BRIDGE_PIECE_RECT
	var bridge_cx := ISLAND.position.x + ISLAND.size.x * 0.5
	var bridge_cy := ISLAND.end.y + 20.0
	_add_decor(bridge_tex,
			Vector2(bridge_cx - BRIDGE_PIECE_RECT.size.x * 0.5, bridge_cy - BRIDGE_PIECE_RECT.size.y * 0.5),
			1, SWAY_FPS, 0.5)
	_add_decor(DUCK, _water_spot(rng), DUCK_FRAMES)
	for spot in CAMPFIRES:
		_add_campfire(ISLAND.position + (spot as Vector2) * ISLAND.size)


func _near_campfire(foot: Vector2) -> bool:
	for spot in CAMPFIRES:
		var fire := ISLAND.position + (spot as Vector2) * ISLAND.size + Vector2(32, 64)
		if foot.distance_to(fire) < CAMPFIRE_CLEAR:
			return true
	return false


## Empurra o canto do quadro pra dentro da ilha: sorteio perto da beirada
## deixaria a árvore (ou a casa) com metade na água.
func _fit(spot: Vector2, tex: Texture2D, frames: int) -> Vector2:
	var size := Vector2(tex.get_width() / frames, tex.get_height())
	return spot.clamp(ISLAND.position, ISLAND.end - size)


## Sombra + fogueira (acesa e apagada, só uma visível) + luz.
func _add_campfire(pos: Vector2) -> void:
	# Sombra 192x192 centrada na lenha, com a base logo acima dela pra o
	# y-sort desenhar a sombra primeiro.
	var shadow := _add_decor(FIRE_SHADOW, pos + Vector2(-64, -132), 1) as Sprite2D
	shadow.modulate = Color(1, 1, 1, 0.3)
	var corner := pos + Vector2(32.0 - CAMPFIRE_SIZE.x * 0.5, 64.0 - CAMPFIRE_SIZE.y)
	var burnt := _add_decor(CAMPFIRE_OUT, corner, CAMPFIRE_FRAMES, FIRE_FPS)
	burnt.visible = false
	var flame := _add_decor(CAMPFIRE_LIT, corner, CAMPFIRE_FRAMES, FIRE_FPS)
	_center_pivot(flame, CAMPFIRE_SIZE.x * 0.5)  # pra chama crescer do pé ao acender
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.color = fire_light_color
	light.energy = fire_light_energy
	light.texture_scale = fire_light_scale
	light.position = pos + fire_offset + Vector2(32, 32)
	decor.add_child(light)
	campfire_spots.append(pos + Vector2(32, 64))
	_fire_parts.append([flame, light, burnt])
	_fire_corners.append(corner)


## Troca a fogueira acesa (com a luz) pela apagada, ou o contrário. Main thread.
func set_fire_lit(index: int, lit: bool) -> void:
	var parts := _fire_parts[index]
	(parts[0] as Node2D).visible = lit
	(parts[1] as Node2D).visible = lit
	(parts[2] as Node2D).visible = not lit
	if lit:
		# Pega aos poucos: a chama cresce do pé, passa um tico do tamanho e assenta.
		var flame := parts[0] as Node2D
		flame.scale = Vector2.ONE * 0.2
		flame.create_tween().tween_property(flame, "scale", Vector2.ONE, 0.6) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Faísca da pederneira caindo na lenha da fogueira `index`.
func spark_fire(index: int) -> void:
	_spawn_chips(campfire_spots[index] + Vector2(-30, -24), -1.0, 6, SPARK)


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
func _add_decor(tex: Texture2D, pos: Vector2, frames: int, fps := SWAY_FPS,
		foot := 1.0) -> Node2D:
	var node: Node2D
	# `foot` é onde está o pé do desenho dentro do quadro. Pedra e tralha são
	# pequenas e centradas num quadro com folga embaixo: usar a borda do quadro
	# como linha de ordenação punha o objeto na frente de quem está mais perto
	# da câmera do que ele.
	var height := tex.get_height() * foot
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
	return _off_plateau(ISLAND.position + Vector2(rng.randf(), rng.randf()) * ISLAND.size)


## Em terra, fora da faixa central onde os players andam.
func _edge_spot(rng: RandomNumberGenerator) -> Vector2:
	var y := rng.randf()
	if y > 0.32 and y < 0.7:
		y = 0.72 + rng.randf() * 0.24
	return _off_plateau(ISLAND.position + Vector2(rng.randf(), y) * ISLAND.size)


## Empurra o ponto pra fora dos platôs e do castelo principal, pelo lado mais
## curto. Sortear de novo até cair fora seria loop sem teto garantido; isto
## sempre termina.
func _off_plateau(p: Vector2) -> Vector2:
	var zones: Array[Rect2] = []
	for box in _plateau_rects():
		zones.append(box.grow(PLATEAU_CLEAR))
	if _castle_rect.has_area():
		zones.append(_castle_rect.grow_individual(CASTLE_CLEAR_TOP_LEFT.x,
				CASTLE_CLEAR_TOP_LEFT.y, CASTLE_CLEAR, CASTLE_PLAZA))
	for rect in zones:
		if not rect.has_point(p):
			continue
		var left := p.x - rect.position.x
		var right := rect.end.x - p.x
		var top_d := p.y - rect.position.y
		var bottom := rect.end.y - p.y
		var m: float = min(min(left, right), min(top_d, bottom))
		if m == left:
			p.x = rect.position.x
		elif m == right:
			p.x = rect.end.x
		elif m == top_d:
			p.y = rect.position.y
		else:
			p.y = rect.end.y
	return p


## Na água: sorteia no mundo inteiro e joga pra fora da ilha pelo lado mais
## perto — a faixa é estreita demais pra sortear direto nela.
func _water_spot(rng: RandomNumberGenerator) -> Vector2:
	var p := Vector2(rng.randf(), rng.randf()) * WORLD
	if rng.randf() < 0.5:
		p.x = rng.randf() * SHORE if p.x < WORLD.x * 0.5 else WORLD.x - rng.randf() * SHORE
	else:
		p.y = rng.randf() * SHORE if p.y < WORLD.y * 0.5 else WORLD.y - rng.randf() * SHORE
	return p
