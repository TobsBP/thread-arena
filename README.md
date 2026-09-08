# Thread Arena

Jogo/demo em Godot 4.7 do impacto de threads: a mesma simulação de combate
rodando **serial** (tudo na main thread) ou **paralela** (1 `Thread` por
unidade), alternando em tempo real com o FPS e um comparativo lado a lado na
tela.

## Rodar

Abra a pasta no Godot 4.7 e dê F5 (a cena inicial é a tela de título; ESC no
jogo volta pra seleção de personagem).

## Controles

| Tecla | Ação |
|-------|------|
| `ESPAÇO` | alterna SERIAL ↔ THREADS |
| `H` | menos informação no HUD (cicla 3 níveis) |
| `G` | invoca um goblin avulso, tipo aleatório |
| `ESC` | volta pra seleção de personagem |

Cada player tem 6 teclas: mover (4), atacar e uma 6ª que vira guarda, coleta
ou mira dependendo da classe escolhida na seleção de personagem.

| Player | Mover | Atacar | 6ª tecla |
|--------|-------|--------|----------|
| P1 | WASD | F | Q |
| P2 | setas | `KP_0` | `KP_1` |
| P3 | IJKL | O | U |

Também dá pra jogar de controle (analógico esquerdo + botões A/B), um por
player, na ordem dos devices 0/1/2.

## O que a demo mostra

3 players + os goblins da onda atual — cada um executa um trabalho pesado
por frame (`WORK_LOAD` iterações de `sqrt`, em `Player.step()`). No modo
serial esse custo cai inteiro no frame da main thread e o FPS despenca. No
modo threads, `main.gd` cria e destrói 1 `Thread` por unidade a cada frame e
o FPS se mantém — a diferença aumenta conforme mais goblins entram em campo
(cada um é mais uma Thread).

Cada unidade escreve só nos próprios campos (`Player.step()`), então não há
lock: é o caso fácil de paralelismo (dados particionados, sem estado
compartilhado). O que toca duas unidades ao mesmo tempo — dano, colisão,
spawn/remoção de goblin — roda na main thread, depois de todas as Threads
terminarem.

### Levels

Os inimigos são goblins em ondas: um banner anuncia o level, a onda nasce, e
a fase acaba quando mata todo mundo ou quando o tempo estoura — o que vier
primeiro. Não acumula: a próxima onda começa limpa. `[G]` solta um goblin
avulso de tipo aleatório a qualquer momento, até um teto de segurança —
é a forma mais rápida de ver o comparativo serial × threads esticar.

## Estrutura

```
scenes/   cenas (.tscn)
scripts/  scripts (.gd)
```
