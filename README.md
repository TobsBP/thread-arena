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
| `T` | perto do castelo azul: abre o menu do castelo (pausa o jogo) |
| `M` | modo sem mobs: some com os goblins e para as ondas (o level segue subindo pelo tempo) |
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

### Castelos e evolução

A madeira e o ouro que o Camponês coleta são entregues nos **castelos** e vão
pro banco do reino (`Kingdom`). O castelo azul é o principal: chegar perto e
apertar `[T]` abre o menu, com três abas:

- **Evolução**: a árvore (`UpgradeTree`). Cada nó custa madeira/ouro e
  exige um level mínimo. Ela aumenta o total de trabalhadores, abre vagas por
  profissão (Lenhador desde o início, Minerador no L3, Açougueiro no L5 e
  Curandeiro no L7) e libera as construções.
- **Trabalhadores**: distribui o total entre as profissões liberadas. Por
  enquanto é só número, os trabalhadores ainda não nascem no mapa.
- **Construir**: Casa (+2 trabalhadores), Castelo (novo ponto de entrega),
  Torre (atira nos goblins) e Quartel (+vida máxima). Depois de escolher,
  aparece um fantasma na frente do player: o ataque confirma e a 6ª tecla
  (ou ESC) cancela. A obra leva alguns segundos pra ficar pronta.

No menu: dá pra usar o mouse (clicar no nó compra, − e + nos trabalhadores,
✕ fecha) ou o teclado: setas/WASD movem, Enter/F confirma, Q tira 1, Tab
troca de aba e ESC/T fecha.

No canto superior direito fica o status (level, madeira, ouro,
trabalhadores). No inferior direito ficam os comandos dos 3 players numa lista
só: uma linha por ação, com a tecla de cada player marcada com a cor dele. Em
destaque aparece o que dá pra fazer naquele momento, como "[T] abrir o
castelo" ao chegar perto dele. Por enquanto o banco está **infinito**
(`Kingdom.INFINITE_BANK`), e só os levels travam a árvore.

## Estrutura

```
scenes/   cenas (.tscn)
scripts/  scripts (.gd)
```
