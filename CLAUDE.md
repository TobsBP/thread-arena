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
  do castelo principal, árvores, arbustos, pedras, tralha de acampamento e
  fogueiras), a camada `Clouds` que
  atravessa o mapa (única coisa que o `_process()` do mapa mexe), um
  `CanvasModulate` de fim de tarde com `PointLight2D` nas fogueiras, e as
  medidas do mundo: `WORLD`, `ISLAND` (terra firme) e `PLAY_AREA` (onde as
  unidades andam). Monta tudo no `_ready()`, não sabe de threads. Expõe
  `blockers` (`Array[Rect2]` da base das árvores e construções, mais o
  barranco dos platôs — beiradas e parede, menos o vão da rampa), montado
  no `_ready()` e depois só crescendo via `add_blocker()` (construção do
  jogador), na main thread e fora da janela `t.start()`/`wait_to_finish()`
  — as threads leem sem lock, e
  `Player._push_out()` empurra a unidade pra fora pelo lado mais perto. Dos
  mesmos blockers sai `nav` (`AStarGrid2D`, células de `NAV_CELL`), que
  `nav_dir()` usa pra levar bots e goblins (`chase()`) contornando o platô
  até a rampa — só a main thread consulta
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
- `scripts/kingdom.gd` — `Kingdom` (RefCounted, só main thread): banco de
  madeira/ouro (`INFINITE_BANK` liga o banco infinito; a trava de level
  segue valendo), nós comprados da árvore, `max_workers`, `job_cap`/`assigned`
  por profissão (`Job`) e `built` (construções prontas). Quem diz se compra,
  constrói ou aloca é ele (`buy_block`/`build_block`/`assign`)
- `scripts/upgrade_tree.gd` — `UpgradeTree`: catálogo da árvore de evolução
  (ramos em colunas, `requires` em sequência, `effect` interpretado por
  `Kingdom.buy`), mesmo espírito do `EnemyTypes`
- `scripts/castle_menu.gd` — `CastleMenu` (nó em `UI` do `main.tscn`,
  `process_mode` ALWAYS): menu do castelo principal com as abas Evolução,
  Trabalhadores e Construir, por teclado ou mouse (hover move o cursor,
  clique confirma; `_hits` guarda as áreas do último `_draw()`). Abre/fecha
  pausando o jogo; só desenha e chama o
  `Kingdom`. Construir só escolhe o tipo (sinal `build_chosen`), e quem cobra e
  posiciona é `main.gd`
- `scripts/side_panel.gd` — `SidePanel` (nó em `UI`): no canto superior
  direito o status (level, SEM MOBS, banco, trabalhadores); no inferior
  direito, sem fundo, os comandos de todos os players numa lista só (uma
  linha por ação, teclas lado a lado com um risco da cor de cada player) e as
  dicas do momento (perto do castelo, árvore, carregando, posicionando obra;
  dica repetida entre players vira uma linha). As dicas vêm prontas de
  `main.gd _player_hints()`; o painel só formata e segue o `[H]` do HUD
- `scripts/build_site.gd` — `BuildSite`: construção erguida pelo jogador
  (Casa/Castelo/Torre/Quartel, catálogo em `KINDS`) — obra com `progress`, vira
  prédio em `main.gd _update_build_sites()`, que aplica o efeito
- `scripts/dynamite.gd` — `Dynamite`: projétil do Goblin da Dinamite, mesmo
  esquema da `Arrow` (nasce, voa em arco, pousa) — só que pousada tem um
  pavio (`FUSE_TIME`) antes de estourar em área; `should_blast()` dispara o
  dano uma vez só, no fim do pavio
- `scripts/village.gd` — `Village` (`RefCounted`): o que os aldeões dividem
  e, por isso, o único lugar com sincronização — `Mutex` no armazém
  (`deposit`/`take`/`add_fuel`), `Semaphore` contador nas vagas da mina
  (`mine_slots`) e no espeto da fogueira (`fire_slots`), e `Semaphore`
  contando as assadas prontas (`roast_ready`, produtor-consumidor)
- `assets/Thread Arena/` — arte nossa, desenhada no estilo do pack (formas
  chapadas, contorno marinho de 2px): `Campfire_Lit.png`/`Campfire_Out.png`
  (fogueira acesa e apagada, tiras de 8 quadros de 96x112 — todas as
  fogueiras do mapa usam; árvore não nasce a menos de `CAMPFIRE_CLEAR` delas)
  `Roast_Meat.png` (a carne do pack tostada, mesmo quadro de 128px),
  `Pawn_{Blue,Yellow}_{Run,Idle}_Roast.png` (as tiras "Meat" do Pawn com a
  carne tostada — o aldeão levando a assada), `Pawn_{Blue,Yellow}_Crank.png`
  (o Idle do Pawn com a mão da frente numa manivela),
  `Pawn_{Blue,Yellow}_Kindle.png` (idem, batendo pederneira: 6 quadros),
  `Wait_Bubble.png` (balão de espera: 4 linhas × 4 quadros de 44x38) e
  `Spit_Raw.png`/`Spit_Roast.png` (espeto sobre a fogueira, mesmo quadro
  dela, com a carne do pack girando; `ArenaMap.set_spit()` mostra a assada
  por cima da crua conforme o progresso do cozinheiro)
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

`[B]` liga/desliga o modo bot dos 3 players juntos (`Player.is_bot`, faixa
mostra "BOT"). O bot é um controle virtual: `bot_think()` decide direção,
ataque e 2º botão e passa pelo mesmo `_apply_controls()` do `poll_input()` —
estamina, especial, guarda, flecha e chuva valem igual pros dois, sem
vantagem. A classe muda só alvo e distância: corpo a corpo encosta no goblin
mais perto e ergue a guarda quando ele está no meio de um golpe; a Arqueira
mantém distância (`BOT_KITE_DIST`..`SHOT_RANGE`); o Curandeiro segue o aliado
mais ferido. Abaixo de `BOT_FLEE_HP` o bot recua pro Curandeiro — sem ele não
tem o que recuperar a vida, então segue lutando. O Camponês bot não coleta.

Inimigos são goblins em ondas por level (ver `scripts/enemy_types.gd` e o
`LevelPhase` de `main.gd`): banner anuncia, a onda nasce, e o level acaba
quando mata todo mundo OU quando o tempo estoura — o que vier primeiro. Não
acumula: ao trocar de level, quem sobrou é removido antes da próxima onda.
Derrota: os três players caídos ao mesmo tempo (`_check_defeat`, depois da
barreira). Player caído volta em `PLAYER_RESPAWN_TIME`; vida e dano dos
goblins crescem `WAVE_GROWTH` por level. Na derrota o `_process` para de
despachar Threads e só mantém o letreiro; `[R]` recarrega a cena.

Com `[B]`, `_bot_govern()` cuida do reino: compra o próximo nó de
`BOT_BUY_ORDER` que der (guardando ouro pro primeiro que falta) e ergue
`BOT_BUILD_ORDER` em anéis em volta do castelo (`_bot_build`), sem tapar
porta, cozinha nem mina.

`[V]` alterna os semáforos de capacidade (`Village.set_semaphores_enabled`).
`Village.try_enter_slot` contabiliza ocupantes mesmo com a fila desligada, e
`leave_slot` devolve a vaga; ao reativar, as permissões são recalculadas a
partir de quem já está dentro. O semáforo de carnes assadas (`roast_ready`)
continua ativo, pois coordena disponibilidade de itens, não capacidade.
Acima da lotação, mina e espeto rendem
lotação/ocupantes pra cada um (`Village.mine_rate`/`fire_rate`, calculados
por `_update_work_rates` antes do dispatch).

`[Z]` troca ao vivo quem a vila cura primeiro (`HealMode`, lido por
`_hurt_player`): WEAKEST (menor fração de vida), NEAREST (mais perto de quem
leva a carne) ou FAIR (há mais tempo sem receber, `_last_healed`). A escolha
vale na hora em que o aldeão pega o alvo; quem já está a caminho não muda.
Na linha de comando: `--cura=0|1|2`.

Partida de medição pela linha de comando: `_apply_cli()` (`--bots --threads
--no-mutex --no-fila --timescale=N --auto-quit --max-time=S`); no fim
imprime `RESULT ...`. A variação entre partidas iguais é grande — comparar
sempre por várias rodadas.

`[M]` liga o modo sem mobs (`no_mobs`): limpa os goblins, a onda não nasce,
`[G]` não invoca, e a fase só fecha pelo tempo — o level segue subindo pra a
árvore de evolução destravar. `[G]` invoca um inimigo avulso de tipo aleatório (não conta pro "matou tudo"),
até um teto de segurança — mais inimigo é mais uma Thread, e é isso que a
tecla existe pra mostrar. Todo inimigo (`is_enemy`) que morre é removido de
vez (`main.gd _remove_enemy`), diferente do player, que sempre respawna.
`units` = players + aldeões + inimigos vivos é o que vira Thread —
cresce/encolhe com a onda; `players` são só os controláveis (usados pela câmera, nunca muda de
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

Nem todo goblin bate corpo-a-corpo: `is_thrower` (Goblin da Dinamite) arremessa
uma `Dynamite` de verdade (`scripts/dynamite.gd`, mesmo esquema da `Arrow` do
arqueiro — nasce em `_throw_dynamite()`, voa em arco, pousa e só depois de um
pavio estoura em área) em vez de tocar o outro lado; `is_bomber` (Goblin do
Barril) não bate nenhuma vez — chega perto, acende um pavio próprio
(`Player.fuse_time`/`fuse_done()`) e estoura em área, se matando no processo
(`main.gd _resolve_bomber_blasts()`). Os dois ficam de fora do golpe
corpo-a-corpo genérico em `_resolve_attacks()`.

Castelos: o mapa começa só com o castelo principal (`ArenaMap.MAIN_CASTLE`,
azul, no meio da ilha) — nenhuma outra construção fixa; o resto o jogador
ergue (o Castelo construído é amarelo, pra não confundir com o principal).
A coleta do Camponês só é entregue em `castle_spots` e vai
pro banco do `Kingdom`. Perto do castelo principal (`main_castle_spot`), `[T]`
abre o `CastleMenu`. Ao escolher uma construção, quem abriu o menu entra em
`Player.build_mode`: o ataque/2º botão viram `build_confirm`/`build_cancel` e
o fantasma segue à frente dele. A obra nasce em `_update_placement()`
(`ArenaMap.place_building`, que já soma o blocker e marca o `nav`) e termina em
`_update_build_sites()`, as duas **antes do dispatch**. A Torre pronta atira
`Arrow` comum (o dano sai do `_resolve_arrow_hits()`). O `[T]`
abre de qualquer lugar: quem "abriu" (e posiciona a obra) é quem está na
porta do castelo ou, sem ninguém lá, o primeiro player vivo fora do bot.

Reino e vila são um sistema só. O banco do `Kingdom` É o estoque da
`Village` (`kingdom.village`; `INFINITE_BANK` fica desligado): evolução e
obra gastam a lenha e o ouro que os aldeões trouxeram, via
`Village.take` (com lock). `Kingdom.max_workers` é quantos aldeões existem
no mapa (`_sync_workers`, até `MAX_VILLAGERS`; começa em 2) e
`Kingdom.assigned` — a aba Trabalhadores — quantos trabalham em cada
profissão: `_assign_job` só dá serviço de uma profissão com menos gente do
que o jogador mandou (Lenhador = WOOD e FUEL, Minerador = GOLD, Açougueiro =
HUNT e COOK, Curandeiro = SERVE); os que sobram ficam `LIVRE`, passeando
pela pracinha (`Player.stroll`). A cada compra os livres se distribuem
sozinhos (`Kingdom.auto_assign`).

Economia: a árvore custa só OURO, as construções custam LENHA (e um pouco
de ouro), o fogo queima lenha. Uma viagem rende `Village.LOAD` (3 lenhas, 2
ouros, 1 carne) e cada goblin derrubado dá `GOBLIN_GOLD`. O reino começa com
2 lenhadores e 1 minerador (sem ouro a árvore não andaria no modo sem mobs).
Medido com os bots lutando: árvore inteira em ~4 min. Aldeão tem
`aggro_bias` > 1 (goblin prefere player), leva metade do dano de estouro
(`WORKER_BLAST_MULT`) e `WORKER_HP` 120 — sem isso morria quase 1 vez por
minuto cada, com a vila no meio do campo de batalha. Recurso que entra no
banco sobe um "+N" (`DamageNumber.note`).


Ovelhas (`sheep`) são cenário vivo: andam a esmo (`Player.wander()`), rodam
na main thread e ficam fora de `units` — não entram na comparação
serial/threads, só na colisão, via `bodies` (= `units` + `sheep`).

Aldeões (`workers`, `Player.is_worker`) são unidades de verdade: estão em
`units` (cada um é uma Thread por frame, aparece na linha do tempo do HUD
como `A`) e em `allies` (= `players` + `workers`, quem os goblins perseguem
e machucam). Cada um tem um `Job` (WOOD, GOLD, HUNT, COOK, SERVE, FUEL) e uma
`Phase` (GO, QUEUE, WORK, HAUL, UNLOAD, ENTER):

- **decidir** é na main thread, antes do dispatch: `main.gd _think_worker`
  escolhe o serviço (`_assign_job`: primeiro o que cura, depois a coleta com
  menos gente), a árvore/ovelha (reserva é só um campo, sem lock — quem
  distribui é a main) e chama `Player.work_think()`, que só escreve `input`;
- **executar** é na Thread dele, `Player._step_work()`: anda, trabalha,
  pega/devolve vaga de semáforo e descarrega no armazém — a carga entra em
  fatias, uma por frame (`UNLOAD_TIME`), que é o que põe dois aldeões
  escrevendo no armazém no mesmo frame;
- **o que mexe em outro objeto** é depois da barreira: `_resolve_worker_hunts`
  (mata a ovelha, a carne já sai nas costas), `_resolve_deliveries` (cura o
  player), `_resolve_work_fx` (a árvore estremece a cada machadada —
  `ArenaMap.hit_tree` — e tomba quando ele sai com a madeira —
  `chop_tree`; a mina dá um tranco a cada picaretada — `hit_mine`; o recurso
  pipoca no armazém quando a descarga termina — `pop_resource`) e
  `_update_spit` (a carne no espeto).

Lenha e ouro entram no armazém pela porta (`Phase.ENTER`): o aldeão chega
perto, pega uma vaga de `Village.depot_slots` (semáforo contador,
`DEPOT_SLOTS` dentro por vez — sem vaga, fila do lado de fora), anda até
`Village.door_spot`, some porta adentro (`Player.hide_amount`, que o
`UnitSprite` usa pra apagar o desenho) e só lá dentro descarrega
(`Phase.UNLOAD`, `UNLOAD_TIME`). Com dois dentro ao mesmo tempo o mutex do
estoque continua fazendo falta — a demo do `[X]` depende disso, por isso a
porta não é de 1. Quem está dentro (`is_hidden()`) não colide nem apanha.

Goblin só escolhe como alvo (`main.gd _prey`) player ou aldeão que não esteja
no meio de uma atividade (`Player.is_busy()`: trabalhando, entrando ou dentro
do armazém). Dano em área e golpe já em andamento ainda podem pegar.

Assar é trabalho de dois. O cozinheiro (COOK) pega o espeto — um só,
semáforo binário — e a carne, vai até a manivela (`Village.cook_spot`) e
gira (`Pawn_*_Crank.png`); a carne no espeto é a do pack vista quase de
perfil, com a vara atravessando o buraco do osso e a peça rodando em torno
dele. Mas ele não acende o fogo: com a fogueira apagada ou abaixo de
`FIRE_LOW`, OUTRO aldeão (FUEL) tira 1 lenha do armazém, leva até
`Village.light_spot`, bate a pederneira na direção da lenha
(`Pawn_*_Kindle.png`, com faísca — `ArenaMap.spark_fire`) e só aí
`Village.add_fuel()` acende; a chama cresce
do pé (`set_fire_lit`). Enquanto isso o cozinheiro espera com o espeto na
mão, e a carne parada.

O aldeão anda e espera com a ferramenta do serviço na mão
(`Player.job_run`/`job_idle`, indexados por `Job`: machado, picareta, faca —
tiras "Run/Idle Axe|Pickaxe|Knife" do pack), e volta de morto com uma
baforada de poeira (`spawn_fx_time`). Quem está esperando — vaga na mina, o
espeto, o fogo pegar ou vaga no armazém (`Player.waiting_for()`) — ganha um balão com o que
espera e pontinhos passando (`Wait_Bubble.png`, desenhado pelo `UnitSprite`)
e dá um pulinho de impaciência de tempos em tempos (`wait_hop()`).

Árvore cortada vira toco, e nos últimos `GROW_TIME` segundos do
`REGROW_TIME` uma muda cresce no lugar. Só com `tree_regrow <= 0` (crescida
de vez) ela pode ser cortada de novo — vale pro aldeão (`_free_tree`) e pro
Camponês. As árvores têm a origem no pé do tronco (`_add_tree`), que é em
torno de onde estremecem, tombam e crescem.

A vila fica em volta do castelo principal (`ArenaMap.main_castle_spot`):
a porta é o armazém, a fogueira mais perto (a última de `CAMPFIRES`, posta
ao lado da pracinha do castelo)
é a cozinha (só queima com lenha: 1 lenha = `FIRE_BURN_TIME`, e apagada ela
some do mapa via `ArenaMap.set_fire_lit`), e todos usam a mesma mina — é o
que faz a fila. Carne crua vai direto pro player abaixo de `RAW_DELIVERY_HP`,
senão vira assada (`ROAST_HEAL`). Aldeão morto volta só
depois de `WORKER_RESPAWN_TIME` e larga as vagas que segurava
(`Player.drop_work()`, chamado no `step()` enquanto morto).

`[C]` é o modo apresentação (`CamFocus` em `main.gd`): a câmera sai dos
players e para, com `FOCUS_ZOOM`, no armazém, na mina, na fogueira, num
lenhador e num caçador (`_focus_target`), deslocada pro meio da área livre
do HUD (`hud.free_center_shift()`); a legenda (`FOCUS_CAPTIONS`) vai pro HUD
por `set_camera_caption()` e aparece mesmo com o resto escondido.

`[X]` desliga o mutex do DEPÓSITO (`Village.use_mutex`; `take`/`add_fuel`
seguem com lock): o painel da vila no HUD mostra "entregue" (soma dos
`Player.delivered`, campo privado de cada Thread) × "contado"
(`Village.counted`) se afastando. Só acontece em modo THREADS.

## Convenções

- Cenas em `scenes/`, scripts em `scripts/`, com as subpastas espelhadas
  (`scenes/world/` ↔ `scripts/world/`); caminhos sempre `res://`.
- Cenário é árvore de cena; unidades (players, inimigo, ovelhas) continuam
  `RefCounted` — quem toca na árvore é o `UnitSprite`, na main thread, o que
  deixa o `step()` rodar na thread sem tocar em nó nenhum.
- Paralelismo com `Thread` explícita (`new`/`start`/`wait_to_finish`), 1 por
  player, criada e destruída por frame — a demo existe pra mostrar isso na cara.
  Não trocar por `WorkerThreadPool` sem o custo de criação virar problema.
- Sem locks enquanto cada tarefa escrever só no estado da própria unidade.
  O único dado compartilhado é a `Village` dos aldeões — toda sincronização
  mora lá dentro, e a demo mostra (painel da vila, `[X]`).
- `Semaphore` sempre com `try_wait()`, nunca `wait()`: a Thread morre no fim
  do frame e a vaga fica com o aldeão por vários frames; bloquear esperaria
  um `post()` que só outra Thread do mesmo frame daria, e o
  `wait_to_finish()` da main não voltaria. Sem vaga = `Phase.QUEUE`, tenta
  de novo no frame seguinte.
- `Village.COUNT_WORK` é a janela entre ler e escrever o estoque. É de
  propósito: sem ela a corrida existe mas quase não aparece.
- `Input` e IA só na main thread: os players fazem `poll_input()` (ou
  `bot_think()`, no modo bot) antes do dispatch; a tarefa lê `input` e nunca
  chama `Input` nem olha outra unidade.
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
