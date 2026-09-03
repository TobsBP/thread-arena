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
  poeira de corrida, faixa e barra de vida; `map.add_unit()` põe ele na cena
- `scripts/player.gd` — `Player` (`RefCounted`): input, trabalho pesado e os
  timestamps `t_start`/`t_end` que alimentam o gráfico
- `project.godot` — `run/main_scene` aponta pra `scenes/main.tscn`

São 3 players controláveis: P1 WASD+F, P2 setas+num0, P3 IJKL+O (a última tecla
é o ataque), cada um somando o analógico esquerdo e o botão A do controle de
mesmo índice (device 0/1/2). `[ESPAÇO]` alterna serial/threads.

Além deles há 1 inimigo vermelho (`is_enemy`) que persegue o player mais
próximo. Ele não tem input: a IA roda na main thread (`Player.chase()`) e só
escreve `input`/`attack_pressed`. `units` = players + inimigo é o que vira Thread; `players` são
só os controláveis (usados pela câmera).

Ataque em alcance tira vida do outro lado (1 acerto por golpe), nos dois
sentidos: player bate no inimigo e o inimigo bate nos players — a IA para de
andar e ataca quando chega em `ATTACK_RANGE`. A zero de vida a unidade tomba e
some (`death_time`), e volta inteira no `spawn_pos`. Dano e colisão entre
unidades tocam dois objetos, então `_resolve_attacks()` e `_resolve_collisions()`
rodam na main thread depois da barreira — as tarefas seguem sem lock.

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
