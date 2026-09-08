class_name EnemyTypes
extends RefCounted

## Catálogo dos inimigos por level — cada fase soma um tipo novo (ver
## main.gd LevelPhase/_spawn_wave). Mesmo espírito do _skin_kit() que
## main.gd já usa pros players, só que pro time vermelho: um Dictionary por
## tipo, com textura + quadros + status.
##
## Torch/TNT/Barrel vêm do pack Update 010 como GRADE — uma textura só, uma
## linha por animação (idle_row/run_row/attack_row) — diferente da tira de
## 1 linha do Free Pack (Guerreiro Vermelho, sheet_cols = 0). As contagens de
## quadro por linha foram lidas dividindo o PNG por 192px e são um chute
## conservador (menos quadros do que cabe na grade), pra nunca sobrar quadro
## transparente no fim do ciclo — confira no editor e ajuste se a animação
## cortar cedo demais.

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
				idle_frames = 6, run_frames = 6, attack_frames = 4,
				color = Color(0.85, 0.42, 0.15),
				max_hp = 50.0, speed = 190.0, attack_range = 90.0, attack_damage = 16.0,
			}
		2:
			return {
				title = "GOBLIN DA DINAMITE",
				idle = TNT, run = TNT, attack = TNT,
				sheet_cols = 7, idle_row = 0, run_row = 1, attack_row = 2,
				idle_frames = 6, run_frames = 6, attack_frames = 6,
				color = Color(0.6, 0.5, 0.2),
				max_hp = 45.0, speed = 200.0, attack_range = 110.0, attack_damage = 20.0,
			}
		3:
			return {
				title = "GOBLIN DO BARRIL",
				idle = BARREL, run = BARREL, attack = BARREL,
				sheet_cols = 4, idle_row = 0, run_row = 1, attack_row = 2,
				idle_frames = 4, run_frames = 4, attack_frames = 4,
				color = Color(0.5, 0.32, 0.15),
				max_hp = 70.0, speed = 150.0, attack_range = 90.0, attack_damage = 22.0,
			}
	## index % COUNT == 0: Guerreiro Vermelho — o inimigo original, tira de 1
	## linha (sheet_cols fica no default 0 do Player, não precisa setar aqui).
	return {
		title = "GUERREIRO VERMELHO",
		idle = RED_IDLE, run = RED_RUN, attack = RED_ATK,
		idle_frames = 8, run_frames = 6, attack_frames = 4,
		color = Color(0.85, 0.25, 0.25),
		max_hp = 60.0, speed = 170.0, attack_range = 90.0, attack_damage = 18.0,
	}
