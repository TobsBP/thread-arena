# Thread Arena

Jogo/demo educacional em **Godot 4.7 (GDScript)** que compara execução serial vs.
paralela da mesma simulação, ao vivo, com FPS na tela. Veja o README para os
controles.

## Estrutura

- `scenes/main.tscn` — cena principal (Node2D + instância do HUD)
- `scripts/main.gd` — simulação, alternância serial/threads, medição e input
- `scenes/hud.tscn` / `scripts/hud.gd` — painel de números e a timeline das
  tarefas; só apresenta, recebe tudo por `update_stats()`
- `scenes/world/arena_map.tscn` / `scripts/world/arena_map.gd` — `ArenaMap`:
  cenário em nós (TileMapLayer de grama + Sprite2D/AnimatedSprite2D de
  construções, árvores, arbustos e pedras) e o tamanho do mundo (`WORLD`);
  monta tudo no `_ready()`, não sabe de threads. `z_index = -1` pra ficar atrás
  das unidades, que `main.gd` ainda desenha no `_draw()`. Expõe `blockers`
  (`Array[Rect2]` da base das árvores e construções), montado no `_ready()` e
  só lido depois — as threads leem sem lock, e `Player._push_out()` empurra a
  unidade pra fora pelo lado mais perto (sem física)
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

Ovelhas (`sheep`) são cenário vivo: andam a esmo via `Player.wander()`, rodam
na main thread e ficam fora de `units` — não entram na comparação serial/threads.

## Convenções

- Cenas em `scenes/`, scripts em `scripts/`, com as subpastas espelhadas
  (`scenes/world/` ↔ `scripts/world/`); caminhos sempre `res://`.
- Cenário é árvore de cena; unidades (players, inimigo, ovelhas) continuam
  `RefCounted` desenhados no `_draw()` — é o que deixa o `step()` rodar na
  thread sem tocar na árvore.
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

- Mensagens de commit **sem** trailers `Co-Authored-By:` ou `Claude-Session:`.
