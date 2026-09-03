class_name ArenaMap
extends RefCounted

## Cenário da arena: chão de grama, construções, árvores e pedras.
## Só desenha — não sabe nada de players, threads ou medição (isso é main.gd).

## Mundo maior que a janela; a câmera de main.gd enquadra os players nele.
const WORLD := Vector2(3200, 1800)
const TILE := 64.0

const GROUND := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Tileset/Tilemap_color1.png")
const GRASS_TILE := Rect2(64, 64, 64, 64)  ## célula 100% grama do tileset 9x6

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

## Decoração gerada: [textura, posição em fração do mundo, nº de quadros].
## Fração pra sobreviver a mudança de WORLD sem recalcular nada.
var _decor: Array = []


## Layout fixo (seed constante) pra a demo abrir sempre igual.
## Árvores e construções ficam nas bordas; a faixa do meio é a arena.
func _init(seed_value := 20260902) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for b in BUILDINGS:
		_decor.append([b[0], b[1], 1])
	for _i in 60:
		_decor.append([TREES[rng.randi() % TREES.size()],
				_edge_spot(rng), TREE_FRAMES])
	for _i in 30:
		_decor.append([BUSHES[rng.randi() % BUSHES.size()],
				_edge_spot(rng), BUSH_FRAMES])
	for _i in 40:
		_decor.append([ROCKS[rng.randi() % ROCKS.size()],
				Vector2(rng.randf(), rng.randf()), 1])


## Posição em fração do mundo fora da faixa central, onde os players andam.
func _edge_spot(rng: RandomNumberGenerator) -> Vector2:
	var y := rng.randf()
	if y > 0.32 and y < 0.7:
		y = 0.72 + rng.randf() * 0.24
	return Vector2(rng.randf(), y)


## Chão cobrindo todo o mundo + cenário por cima. Chamado do _draw() de main.gd.
## ponytail: ~1400 draw_texture_rect_region por frame (mundo inteiro, sem culling);
## se pesar, virar TileMapLayer ou recortar pelo retângulo visível da câmera.
func draw_into(c: CanvasItem) -> void:
	for y in range(0, int(WORLD.y), int(TILE)):
		for x in range(0, int(WORLD.x), int(TILE)):
			c.draw_texture_rect_region(GROUND, Rect2(x, y, TILE, TILE), GRASS_TILE)
	for i in _decor.size():
		var tex: Texture2D = _decor[i][0]
		var pos: Vector2 = (_decor[i][1] as Vector2) * WORLD
		var frames: int = _decor[i][2]
		if frames == 1:
			c.draw_texture(tex, pos)
			continue
		# Balanço das árvores: mesmo ciclo pra todas, defasado pelo índice.
		var fw := tex.get_width() / frames
		var fh := tex.get_height()
		var f := (int(Time.get_ticks_msec() / 120.0) + i) % frames
		c.draw_texture_rect_region(tex, Rect2(pos, Vector2(fw, fh)),
				Rect2(f * fw, 0, fw, fh))
