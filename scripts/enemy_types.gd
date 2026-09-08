class_name EnemyTypes
extends RefCounted

## Catálogo dos inimigos por level — cada fase soma um tipo novo (ver
## main.gd LevelPhase/_spawn_wave). Mesmo espírito do _skin_kit() que
## main.gd já usa pros players, só que pro time vermelho: um Dictionary por
## tipo, com textura + quadros + status.
##
## Torch/TNT/Barrel vêm do pack Update 010 como GRADE — uma textura só, uma
## linha por animação (idle_row/run_row/attack_row) — diferente da tira de
## 1 linha do Free Pack (Guerreiro Vermelho, sheet_cols = 0). Cuidado: o
## tamanho da célula NÃO é sempre 192px só porque o PNG divide certinho por
## 192 (foi o que deu errado no Barril — a grade real dele é 6 colunas de
## 128px, não 4 de 192; um recorte no tamanho errado pega pedaço de mais de
## um quadro ao mesmo tempo). sheet_cols/frame_size/linhas/contagens aqui
## foram conferidos abrindo cada PNG, não só calculados — mesmo assim, teste
## no editor antes de confiar de olhos fechados.

const COUNT := 4

const RED_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Idle.png")
const RED_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Run.png")
const RED_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Attack1.png")

## 1344x960 = grade 7 colunas x 5 linhas @192px.
const TORCH := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/Torch/Red/Torch_Red.png")
## 1344x576 = grade 7 colunas x 3 linhas @192px.
const TNT := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Red/TNT_Red.png")
## 768x768 = grade 4 colunas x 4 linhas @192px.
const BARREL := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/Barrel/Red/Barrel_Red.png")


## Kit do inimigo do level `index` (0-based): index % COUNT, então passar do
## fim do catálogo repete do início (main.gd escala hp/dano nesse caso, pra
## dar pra jogar além do 4º tipo sem precisar de arte nova).
static func kind(index: int) -> Dictionary:
	match index % COUNT:
		1:
			return {
				title = "GOBLIN DA TOCHA",
				idle = TORCH, run = TORCH, attack = TORCH,
				sheet_cols = 7, idle_row = 0, run_row = 1, attack_row = 2,
				## Conferido abrindo o PNG: a linha de ataque tem 6 quadros
				## usados (giro da tocha até o fim do arco), não 4.
				idle_frames = 6, run_frames = 6, attack_frames = 6,
				color = Color(0.85, 0.42, 0.15),
				max_hp = 50.0, speed = 190.0, attack_range = 90.0, attack_damage = 16.0,
				cooldown = 0.9,  ## mais ágil, bate mais rápido que o Guerreiro
			}
		2:
			return {
				title = "GOBLIN DA DINAMITE",
				idle = TNT, run = TNT, attack = TNT,
				sheet_cols = 7, idle_row = 0, run_row = 1, attack_row = 2,
				idle_frames = 6, run_frames = 6, attack_frames = 6,
				color = Color(0.6, 0.5, 0.2),
				max_hp = 45.0, speed = 200.0, attack_range = 110.0, attack_damage = 20.0,
				cooldown = 1.6,  ## alcance maior compensa o respiro mais longo entre golpes
			}
		3:
			return {
				title = "GOBLIN DO BARRIL",
				idle = BARREL, run = BARREL, attack = BARREL,
				# Grade real é 6 colunas x 128px (não 4 x 192 — conferido
				# abrindo o PNG: um recorte de 192 pegava pedaço de até 3
				# quadros ao mesmo tempo, daí o "vários aparecem juntos").
				sheet_cols = 6, frame_size = Vector2(128, 128),
				idle_row = 0, run_row = 1, attack_row = 3,
				idle_frames = 1, run_frames = 6, attack_frames = 6,
				color = Color(0.5, 0.32, 0.15),
				max_hp = 70.0, speed = 150.0, attack_range = 90.0, attack_damage = 22.0,
				cooldown = 1.5,  ## o mais lento pra bater — tanque, não precisa de ritmo
			}
	## index % COUNT == 0: Guerreiro Vermelho — o inimigo original, tira de 1
	## linha (sheet_cols fica no default 0 do Player, não precisa setar aqui).
	return {
		title = "GUERREIRO VERMELHO",
		idle = RED_IDLE, run = RED_RUN, attack = RED_ATK,
		idle_frames = 8, run_frames = 6, attack_frames = 4,
		color = Color(0.85, 0.25, 0.25),
		max_hp = 60.0, speed = 170.0, attack_range = 90.0, attack_damage = 18.0,
		cooldown = 1.2,  ## ritmo do inimigo original
	}
