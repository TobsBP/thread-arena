# Thread Arena

Jogo/demo educacional em **Godot 4.7 (GDScript)** que compara execução serial vs.
paralela da mesma simulação, ao vivo, com FPS na tela. Veja o README para os
controles.

## Estrutura

- `scenes/main.tscn` — cena principal (Node2D + instância do HUD)
- `scripts/main.gd` — simulação, alternância serial/threads, medição e input
- `scenes/hud.tscn` / `scripts/hud.gd` — painel de números, o comparativo em
  barras e a timeline das tarefas, tudo desenhado em papel do pack; só
  apresenta, recebe tudo por `update_stats()`
- `scripts/pack_ui.gd` — `PackUI`: estáticas de desenho das peças de UI do
  pack (`hslice`, `nine`), que vêm em pedaços soltos dentro da textura e não
  servem pra `NinePatchRect`/`StyleBoxTexture`. Usadas pelo HUD e pelo
  `UnitSprite`
- `scenes/world/arena_map.tscn` / `scripts/world/arena_map.gd` — `ArenaMap`:
  cenário em nós (TileMapLayer de água, espuma animada na costa, a ilha de
  grama, os platôs de relevo — silhueta em união de retângulos (L, crista,
  T) com autotile por vizinho, topo de grama, parede de pedra, a sombra na
  camada `PlateauShadow` (a silhueta repetida um tile abaixo, como manda o
  Tilemap Guide do pack) e a rampa nas peças de escada do tileset, único
  acesso ao topo — e as manchas de grama escura, todas
  montadas do mesmo tileset sem terrain set, mais Sprite2D/AnimatedSprite2D
  de construções, árvores, arbustos, pedras, tralha de acampamento e
  fogueiras), a camada `Clouds` que
  atravessa o mapa (única coisa que o `_process()` do mapa mexe), um
  `CanvasModulate` de fim de tarde com `PointLight2D` nas fogueiras, e as
  medidas do mundo: `WORLD`, `ISLAND` (terra firme) e `PLAY_AREA` (onde as
  unidades andam). Monta tudo no `_ready()`, não sabe de threads. Expõe
  `blockers` (`Array[Rect2]` da base das árvores e construções, mais o
  barranco dos platôs — beiradas e parede, menos o vão da rampa), montado
  no `_ready()` e só lido depois — as threads leem sem lock, e
  `Player._push_out()` empurra a unidade pra fora pelo lado mais perto
- `scripts/world/unit_sprite.gd` — `UnitSprite`: um nó de desenho por unidade,
  irmão das árvores dentro do `Decor` y-sorted (é o que faz o player passar
  atrás da árvore). Lê `unit.pos` no `_process()` e desenha sombra, sprite,
  poeira de corrida, faixa, barra de vida/estamina e os efeitos de flash/pop/
  bloqueio/cura/morte; `map.add_unit()` põe ele na cena. O corpo lê a tira de
  1 linha do Free Pack (`sheet_cols == 0`, um quadro atrás do outro) ou uma
  grade 2D do pack Update 010 (`sheet_cols > 0`, coluna = quadro, linha =
  `Player.get_current_row()`) — mesmo padrão de leitura por linha/coluna que
  a caveira da morte (`DEAD_COLS`/`DEAD_ROWS`) já usava
- `scripts/player.gd` — `Player` (`RefCounted`): input, trabalho pesado e os
  timestamps `t_start`/`t_end` que alimentam o gráfico. Campos por unidade
  decidem a classe/tipo (arqueira, curandeiro, lenhador, goblin...): texturas,
  quadros, alcance/dano, estamina, e `sheet_cols`/`idle_row`/`run_row`/
  `attack_row` pra sprite em grade
- `scripts/enemy_types.gd` — `EnemyTypes`: catálogo dos inimigos por level
  (`kind(index)`), mesmo espírito do `_skin_kit()` de `main.gd` pros players,
  só que pro time vermelho — textura, quadros (inclusive de grade), status
- `scripts/level_banner.gd` — `LevelBanner`: "LEVEL N — TIPO" no meio da
  tela, aparece e some sozinho; só desenha o que `main.gd` manda pronto
  (texto + alfa) — não cronometra nada, mesma regra do HUD
- `project.godot` — `run/main_scene` aponta pra `scenes/title_screen.tscn`
  (tela de título → seleção de personagem → `scenes/main.tscn`)

São 3 players controláveis: P1 WASD+F+Q, P2 setas+KP_0+KP_1, P3 IJKL+O+U —
6 teclas cada (`Player.keys`), a 5ª é ataque e a 6ª é guarda/coleta/mira,
dependendo da classe. Cada um soma o analógico esquerdo e os botões A/B do
controle de mesmo índice (device 0/1/2). A skin escolhida na seleção de
personagem decide a CLASSE, não só a cor: Guerreiro (golpe especial + guarda),
Arqueira (flecha, mira, chuva de flechas), Camponês (coleta madeira/ouro),
Lanceiro (alcance maior + guarda) e Curandeiro (cura em vez de bater). Estamina
limita golpe/flecha/cura — sem carga a ação não sai. `poll_input(delta)` decide
o INÍCIO do ataque/especial na main thread (não no `step()` da Thread), porque
`main.gd` precisa saber "começou agora" no mesmo frame pra nascer a flecha.
`[ESPAÇO]` alterna serial/threads.

Inimigos são goblins em ondas por level (ver `scripts/enemy_types.gd` e o
`LevelPhase` de `main.gd`): banner anuncia, a onda nasce, e o level acaba
quando mata todo mundo OU quando o tempo estoura — o que vier primeiro. Não
acumula: ao trocar de level, quem sobrou é removido antes da próxima onda.
`[G]` invoca um inimigo avulso de tipo aleatório (não conta pro "matou tudo"),
até um teto de segurança — mais inimigo é mais uma Thread, e é isso que a
tecla existe pra mostrar. Todo inimigo (`is_enemy`) que morre é removido de
vez (`main.gd _remove_enemy`), diferente do player, que sempre respawna.
`units` = players + inimigos vivos é o que vira Thread — cresce/encolhe com a
onda; `players` são só os controláveis (usados pela câmera, nunca muda de
tamanho).

Ataque em alcance tira vida do outro lado (1 acerto por golpe), nos dois
sentidos: player bate no inimigo e o inimigo bate nos players — a IA para de
andar e ataca quando chega em `ATTACK_RANGE`/`attack_range`. A zero de vida a
unidade tomba e some (`death_time`); player volta inteiro no `spawn_pos`,
inimigo é removido de `units`/`bodies` e perde o nó de desenho. Dano e colisão
entre unidades tocam dois objetos, então `_resolve_attacks()` e
`_resolve_collisions()` rodam na main thread depois da barreira — as tarefas
seguem sem lock. Spawn/remoção de inimigo (onda, `[G]`, troca de level)
também só acontece fora da janela `t.start()`/`wait_to_finish()`: antes do
dispatch (nasce a onda) ou depois da barreira (morte/limpeza de fase).

Ovelhas (`sheep`) e pawns lenhadores (`workers`) são cenário vivo: as ovelhas
andam a esmo (`Player.wander()`) e os pawns vão do toco à construção com
madeira nas costas (`Player.haul()`, com os pontos vindos de
`ArenaMap.tree_spots`/`building_spots`). Os dois rodam na main thread e ficam
fora de `units` — não entram na comparação serial/threads, só na colisão, via
`bodies` (= `units` + `sheep` + `workers`).

## Convenções

- Cenas em `scenes/`, scripts em `scripts/`, com as subpastas espelhadas
  (`scenes/world/` ↔ `scripts/world/`); caminhos sempre `res://`.
- Cenário é árvore de cena; unidades (players, inimigo, ovelhas) continuam
  `RefCounted` — quem toca na árvore é o `UnitSprite`, na main thread, o que
  deixa o `step()` rodar na thread sem tocar em nó nenhum.
- Paralelismo com `Thread` explícita (`new`/`start`/`wait_to_finish`), 1 por
  player, criada e destruída por frame — a demo existe pra mostrar isso na cara.
  Não trocar por `WorkerThreadPool` sem o custo de criação virar problema.
- Sem locks enquanto cada tarefa escrever só no próprio índice (`players[i]`).
  Se algum dado passar a ser compartilhado, aí sim `Mutex` (e vale mostrar na
  demo).
- `Input` só na main thread: os players fazem `poll_input()` antes do dispatch;
  a tarefa lê `input` e nunca chama `Input`.
- Nada de tocar na árvore de cena dentro da tarefa — os players são dados
  puros, desenhados depois no `_draw()`.
- O HUD não mede nada: quem cronometra é `main.gd`, o HUD só formata.

## Notas

- O binário `godot` não está no PATH desta máquina; mudanças não foram
  executadas — teste no editor.
- Vsync é desligado em `_ready()` (`VSYNC_DISABLED` + `Engine.max_fps = 0`)
  pro FPS refletir o custo do trabalho. É via script, não no `project.godot`.
- `WORK_LOAD` é constante de propósito (o ajuste por teclado foi removido). Com
  carga baixa demais o custo de despachar as tarefas domina e threads perde.
- Não commitar `.godot/` (já está no `.gitignore`).

## Git

- Mensagens de commit **sem** trailers `Co-Authored-By:`, `Claude-Session:` ou
  qualquer outra assinatura de ferramenta — vale mesmo que a sessão peça o
  contrário.
- Descrição de PR igual: sem rodapé "Generated with Claude Code" nem link de
  sessão.
