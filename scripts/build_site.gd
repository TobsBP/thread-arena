class_name BuildSite
extends RefCounted

## Uma construção erguida pelo jogador: nasce como obra (textura de
## Construction, blocker já valendo) e fica pronta depois de `time` segundos.
## Dado puro na main thread — quem avança `progress` e aplica o efeito é
## main.gd (_update_build_sites), quem tem o nó de desenho é o ArenaMap.

## Catálogo: custo, tempo de obra e o nó da árvore (UpgradeTree) que libera.
const KINDS := {
	&"house": {title = "Casa", desc = "+2 trabalhadores (moradia)",
		wood = 8, gold = 0, time = 8.0, unlock = &"carpentry"},
	&"castle": {title = "Castelo", desc = "novo ponto de entrega",
		wood = 20, gold = 10, time = 20.0, unlock = &"masonry"},
	&"tower": {title = "Torre", desc = "atira nos goblins por perto",
		wood = 12, gold = 6, time = 12.0, unlock = &"watch"},
	&"barracks": {title = "Quartel", desc = "+15 de vida máxima pros players",
		wood = 15, gold = 8, time = 15.0, unlock = &"training"},
}
const ORDER: Array[StringName] = [&"house", &"castle", &"tower", &"barracks"]

var kind: StringName
var pos: Vector2  ## canto de cima do quadro, igual às construções fixas do mapa
var size: Vector2
var node: Sprite2D
var progress := 0.0
var done := false  ## efeito já aplicado (vira true uma vez só, em main.gd)
var cooldown := 0.0  ## torre: segundos até a próxima flecha


func _init(k: StringName, p: Vector2, s: Vector2, n: Sprite2D) -> void:
	kind = k
	pos = p
	size = s
	node = n


func build_time() -> float:
	return KINDS[kind].time


func ratio() -> float:
	return clampf(progress / build_time(), 0.0, 1.0)


func is_finished() -> bool:
	return progress >= build_time()


## Porta: mesmo ponto que o ArenaMap usa pras construções fixas.
func door() -> Vector2:
	return pos + Vector2(size.x * 0.5, size.y + 20.0)


## De onde a torre atira: o alto do quadro, não o pé.
func top() -> Vector2:
	return pos + Vector2(size.x * 0.5, size.y * 0.25)
