extends Node

## Singleton (Autoload) que persiste a escolha de skin de cada player
## entre a cena de seleção (character_select.tscn) e a arena (main.tscn).
##
## Skin é uma String que mapeia para um conjunto de texturas em main.gd:
##   "blue"   → Blue Units / Warrior
##   "purple" → Purple Units / Warrior
##   "yellow" → Yellow Units / Warrior
##   "black"  → Black Units / Warrior
##
## O inimigo (index -1) usa sempre "red" — não configurável.

const SKINS := ["blue", "purple", "yellow", "black"]

## Skin padrão para cada um dos 3 players controláveis.
var skins: Array[String] = ["blue", "purple", "yellow"]


## Retorna o índice dentro de SKINS para o player dado.
func skin_index(player_index: int) -> int:
	var s := skins[player_index]
	var idx := SKINS.find(s)
	return idx if idx >= 0 else 0


## Avança para o próximo skin (com wraparound).
func next_skin(player_index: int) -> void:
	var idx := (skin_index(player_index) + 1) % SKINS.size()
	skins[player_index] = SKINS[idx]


## Recua para o skin anterior (com wraparound).
func prev_skin(player_index: int) -> void:
	var idx := (skin_index(player_index) - 1 + SKINS.size()) % SKINS.size()
	skins[player_index] = SKINS[idx]

