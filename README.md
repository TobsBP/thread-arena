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
| `B` | liga/desliga o modo bot dos 3 players |
| `T` | abre o menu do castelo de qualquer lugar: evolução, trabalhadores, obras (pausa o jogo) |
| `M` | modo sem mobs: some com os goblins e para as ondas (o level segue subindo pelo tempo) |
| `X` | liga/desliga o mutex do armazém da vila |
| `V` | liga/desliga os semáforos de capacidade (mina, espeto e armazém; carnes assadas continuam sincronizadas) |
| `Z` | quem a vila cura primeiro: menos vida → mais perto → rodízio |
| `R` | depois da derrota: recomeça a partida |
| `C` | modo apresentação: a câmera para em cada ponto de trabalho da vila |
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

3 players + aldeões + goblins da onda atual — cada unidade executa seu passo
por frame. No modo serial, tudo roda na main thread; no modo threads,
`main.gd` cria e finaliza uma `Thread` por unidade a cada frame. O sistema
operacional decide como escalonar essas threads entre os núcleos.

Players e goblins escrevem só nos próprios campos (`Player.step()`), então
não há lock: é o caso fácil de paralelismo (dados particionados, sem estado
compartilhado). O que toca duas unidades ao mesmo tempo — dano, colisão,
spawn/remoção de goblin — roda na main thread, depois de todas as Threads
terminarem.

### A vila: mutex e semáforo

Os aldeões são o caso difícil. Cada um também é uma Thread por frame, mas
eles dividem coisas — e aí precisa de sincronização (`scripts/village.gd`):

- **Mutex — o armazém.** Madeira, ouro e carne crua entram no mesmo estoque.
  Depositar é ler o total, somar e escrever; duas Threads fazendo isso juntas
  perdem uma das somas. `[X]` desliga o lock: no painel da vila, "entregue"
  (o que cada aldeão diz que descarregou) e "contado" (o que o armazém
  registrou) começam a se afastar. Em SERIAL não se perde nada mesmo sem
  mutex — não existe "ao mesmo tempo".
- **Semáforo contador — as vagas.** A mina tem 2 lugares, a fogueira tem 1
  espeto e no armazém cabem 2 por vez: o aldeão entra pela porta, some lá
  dentro enquanto descarrega e sai. Quem chega sem vaga fica na `FILA`, com
  um balão em cima da cabeça dizendo o que está esperando. O armazém junta
  os dois conceitos: o semáforo decide quem entra, o mutex protege o estoque
  entre os que entraram.
- **Semáforo contando itens — as assadas.** Produtor-consumidor: o cozinheiro
  dá `post()` a cada carne pronta, quem vai levar faz `try_wait()`.

O ciclo: lenha e ouro vão pro armazém; a ovelha caçada vira carne, que vai
crua direto pro player que estiver mal (cura pouco, chega já) ou pra
fogueira virar assada (cura bem mais). Assar é trabalho de dois: um aldeão
gira o espeto e outro busca lenha no armazém e acende a fogueira — 1 lenha
dá 25 s de fogo.

O que eles trazem é o banco do reino. O **ouro** compra a árvore de
evolução; a **lenha** ergue as construções e alimenta a fogueira. Ouro vem
dos mineradores (2 por viagem) e de cada goblin derrubado (+1); lenha vem
dos lenhadores (3 por viagem). Tudo pelo menu do castelo (`[T]`).

A árvore manda na vila: a partida começa com 2 lenhadores e 1 minerador;
"Casas" traz mais aldeões, Açougueiro e Curandeiro precisam ser liberados, e
na aba Trabalhadores você decide quantos fazem o quê (quem chega já vai
sozinho pra profissão com vaga; os que sobram passeiam pela pracinha).

Goblins atacam os aldeões, e aldeão morto leva 15 s pra voltar: sem
proteger a vila, a comida para de chegar. Com um player por perto o goblin
prefere o player; a vila só apanha de verdade se ninguém estiver defendendo. Eles só escolhem como alvo quem
está andando ou na fila — aldeão no meio do serviço (cortando, minerando,
assando, dentro do armazém) não é mirado.

Pra apresentar: `[C]` leva a câmera, mais de perto, pro armazém, pra mina,
pra fogueira, pra um lenhador e pra um caçador, com uma legenda dizendo o
que está acontecendo ali (qual é o mutex, qual é o semáforo). `[H]` duas
vezes esconde os painéis e deixa só a cena e a legenda.

### Derrota e o experimento

A partida acaba quando os três players estão caídos ao mesmo tempo (player
caído leva 6 s pra voltar, e os goblins ficam 5% mais fortes a cada level).
O level em que isso acontece é a nota da partida.

Com `[B]` os bots também cuidam do reino: compram a árvore numa ordem fixa
e erguem Quartel, Torre e Casa em volta do castelo. Isso permite rodar a
partida sozinha e comparar até onde eles chegam com e sem mutex (`[X]`) e
com e sem fila (`[V]`). Sem fila ninguém espera vaga: todo mundo entra de
uma vez, a mina e o espeto continuam do mesmo tamanho (quem entra a mais
divide o lugar, cada um rende menos) e no armazém são mais Threads somando
o estoque no mesmo frame.

Pra rodar sem ninguém jogando e sem janela (uma linha `RESULT ...` no fim):

```
godot --headless --path . res://scenes/main.tscn -- --bots --threads     --timescale=5 --auto-quit --max-time=1200 [--no-mutex] [--no-fila]
```

### Levels

Os inimigos são goblins em ondas: um banner anuncia o level, a onda nasce, e
a fase acaba quando mata todo mundo ou quando o tempo estoura — o que vier
primeiro. Não acumula: a próxima onda começa limpa. `[G]` solta um goblin
avulso de tipo aleatório a qualquer momento, até um teto de segurança —
é a forma mais rápida de ver o comparativo serial × threads esticar.

### Castelo e evolução

A madeira e o ouro coletados pelos aldeões vão para o estoque compartilhado da
vila (`Village`), que alimenta o banco do reino (`Kingdom`). O castelo azul é
o principal: `[T]` abre o menu de qualquer lugar, com três abas:

- **Evolução**: a árvore (`UpgradeTree`). Cada nó custa madeira/ouro e
  exige um level mínimo. Ela aumenta o total de trabalhadores, abre vagas por
  profissão (Lenhador desde o início, Minerador no L3, Açougueiro no L5 e
  Curandeiro no L7) e libera as construções.
- **Trabalhadores**: distribui os aldeões que aparecem e trabalham no mapa,
  entre as profissões liberadas. Os novos aldeões chegam e procuram uma vaga.
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
castelo". O estoque é finito: depósitos, construções, combustível e compras
consomem recursos.

## Estrutura

```
scenes/   cenas (.tscn)
scripts/  scripts (.gd)
```
