# Thread Arena — Apresentação

Demo educacional em **Godot 4.7 / GDScript** que roda a **mesma simulação** de
dois jeitos — serial (tudo na main thread) e paralelo (`WorkerThreadPool`) —
alternando em tempo real com `[ESPAÇO]` e mostrando o custo dos dois modos lado
a lado na tela.

Máquina de referência das medições: **AMD Ryzen 7 4800HS** (8 núcleos físicos,
16 threads lógicas), Windows 11, vsync desligado.

**Sumário**

- [0. Conceitos base](#0-conceitos-base) — o vocabulário mínimo
- [1. Apresentação do jogo](#1-apresentação-do-jogo)
- [2. Threads em código](#2-threads-em-código)
- [3. Por que os resultados deram isso](#3-por-que-os-resultados-deram-isso)
- [Apêndice A — Glossário](#apêndice-a--glossário)
- [Apêndice B — Perguntas frequentes](#apêndice-b--perguntas-frequentes)

---

## 0. Conceitos base

Antes dos números, o vocabulário. Tudo nesta seção reaparece no código.

### Processo × thread

Um **processo** é um programa em execução com seu **próprio espaço de
endereçamento** (sua própria memória). Uma **thread** é uma linha de execução
*dentro* de um processo: tem sua própria pilha (variáveis locais) e seus
próprios registradores, mas **compartilha a memória (heap) com as outras
threads do mesmo processo**.

Esse compartilhamento é a fonte de todo o poder e de todo o perigo:

- **poder** — passar dados entre threads é só passar um ponteiro, custo zero;
- **perigo** — duas threads podem escrever no mesmo endereço ao mesmo tempo.

No Thread Arena, o array `players` é visível por todas as threads. A demo é
segura não porque impede o acesso, mas porque **particiona** quem escreve onde
(seção 2a).

### Concorrência × paralelismo

Não são sinônimos, e a distinção é o conceito central da matéria:

| | Concorrência | Paralelismo |
|---|---|---|
| O que é | várias tarefas **em progresso** ao mesmo tempo | várias tarefas **executando** no mesmo instante |
| Precisa de | 1 núcleo basta (o SO alterna) | 2+ núcleos de verdade |
| É sobre | **estrutura** do programa | **execução** do programa |
| Ganho | organização, responsividade | tempo de parede (wall clock) |

> Concorrência é lidar com muitas coisas ao mesmo tempo; paralelismo é *fazer*
> muitas coisas ao mesmo tempo. — Rob Pike

Um programa concorrente num processador de 1 núcleo **não fica mais rápido**: o
SO só reveza as threads (isso é o *time slicing*), e cada troca custa um
**context switch** — salvar registradores, trocar contexto, poluir o cache.

**Esta demo mede paralelismo de verdade**, não concorrência: as 3 tarefas rodam
em núcleos físicos distintos e o tempo de parede cai. Se rodasse num CPU de 1
núcleo, o modo threads seria *mais lento* que o serial (mesmo trabalho + custo
de coordenar).

### Latência × throughput

Duas métricas diferentes, e a demo mostra as duas:

- **latência** = quanto demora **um** frame → o `ms` do HUD (menor é melhor);
- **throughput** = quantos frames cabem por segundo → o **FPS** (maior é
  melhor).

Paralelizar aqui melhora as duas porque o gargalo é o mesmo trabalho. Nem sempre
é assim: dá pra aumentar throughput piorando a latência (ex.: processar em lote).

### Data race × race condition

Confundidos com frequência:

- **Data race** — dois acessos concorrentes ao **mesmo endereço**, pelo menos um
  sendo **escrita**, sem sincronização. É **comportamento indefinido**: o valor
  lido pode ser lixo, uma mistura de dois valores, ou o compilador pode até
  reordenar/eliminar o acesso.
- **Race condition** — o resultado do programa depende da **ordem** em que as
  threads rodaram. Pode existir *sem* data race (ex.: dois `Mutex` corretos, mas
  quem chegar primeiro ganha).

O sintoma clássico dos dois é o pior possível para depurar: **funciona 99 vezes
e quebra na centésima**, geralmente só na máquina do professor.

### Seção crítica, mutex e o custo do lock

Uma **seção crítica** é um trecho que só pode ser executado por uma thread por
vez. Um **`Mutex`** (*mutual exclusion*) garante isso: quem chega primeiro
entra, os outros **bloqueiam** até ele liberar.

O custo do lock não é só o tempo de travar/destravar — é a **serialização**: a
seção crítica vira uma parte que **não paralelizou**, e portanto entra
diretamente na Lei de Amdahl (seção 3). Locks demais e o programa paralelo fica
mais lento que o serial.

Riscos associados:

- **deadlock** — A espera por B enquanto B espera por A; ninguém anda;
- **contenção** (*lock contention*) — todo mundo disputando o mesmo lock, as
  threads passam mais tempo esperando do que trabalhando;
- **starvation** — uma thread nunca consegue o lock.

**A demo não usa nenhum `Mutex`** — e isso não é sorte, é design (seção 2a).

### Thread pool e o padrão fork-join

Criar uma thread do zero é caro: o SO precisa alocar pilha, registrar no
scheduler etc. Criar 3 por frame, 100 vezes por segundo, seria absurdo.

Um **thread pool** resolve isso: as threads são criadas **uma vez** na
inicialização e ficam **dormindo**; despachar trabalho é só acordar uma delas.
É exatamente o que o `WorkerThreadPool` do Godot é.

O padrão de uso aqui é o **fork-join**:

```
        ┌─ tarefa 0 ─┐
main ───┼─ tarefa 1 ─┼─── barreira ─── main continua
 fork   └─ tarefa 2 ─┘      join
```

- **fork** — `add_group_task()` divide o trabalho em N tarefas;
- **join / barreira** — `wait_for_group_task_completion()` bloqueia a main
  thread até **todas** terminarem.

A barreira é o que devolve o programa a um ponto **determinístico**: depois
dela, tudo que as threads escreveram está pronto e visível.

### Visibilidade de memória (o conceito mais sutil)

Não basta a escrita "acontecer antes" no relógio — a outra thread precisa
**enxergar** essa escrita. Caches por núcleo e reordenação de instruções (pelo
compilador *e* pelo processador) podem fazer uma thread ler um valor velho.

A garantia se chama relação **happens-before**: se A acontece-antes de B, então
tudo que A escreveu está visível para B. Primitivas de sincronização (mutex,
barreira, atômicos) **estabelecem** essa relação.

Na demo: `poll_input()` escreve `input` na main thread; a **barreira do
dispatch** estabelece o happens-before, então a worker enxerga o valor correto
sem precisar de lock. Não é "deu certo por sorte" — é o modelo de memória
funcionando.

### Granularidade e o ponto de equilíbrio

**Granularidade** é o tamanho de cada tarefa:

- **fina** — muitas tarefas curtas → ótimo balanceamento, **muito overhead**;
- **grossa** — poucas tarefas longas → pouco overhead, **risco de desbalanceamento**.

Existe um **ponto de equilíbrio** (*break-even*): se o trabalho de uma tarefa
custa menos que despachá-la, **paralelizar piora**. É por isso que o
`WORK_LOAD` desta demo é uma constante alta (seção 3).

### Speedup, eficiência e escalabilidade

- **Speedup** `S = T_serial / T_paralelo` — quantas vezes mais rápido;
- **Eficiência** `E = S / N` — quanto de cada núcleo foi realmente aproveitado
  (100% = speedup linear, ideal e raríssimo);
- **Escalabilidade forte** (*strong scaling*) — problema **fixo**, mais
  núcleos. É o que esta demo mede;
- **Escalabilidade fraca** (*weak scaling*) — problema **cresce junto** com os
  núcleos.

A distinção importa porque a Lei de Amdahl (limite pessimista) vale para
escalabilidade **forte**; a Lei de Gustafson (otimista) vale para a **fraca**.
Ambas na seção 3.

---

## 1. Apresentação do jogo

### O que é

Uma arena 2D com **3 players controláveis ao mesmo tempo**, cada um representado
por um círculo colorido. Cada player, **a cada frame**, executa um "trabalho
pesado" artificial antes de se mover. Esse trabalho é o objeto do estudo: é ele
que roda em fila (serial) ou sobreposto (paralelo).

O jogo em si é propositalmente simples — o conteúdo é a **medição**.

### O laço do jogo (game loop) e a main thread

Contexto necessário pra entender por que threads importam num jogo. Toda engine
roda um laço:

```
repete pra sempre:
    lê input  →  atualiza o mundo  →  desenha  →  apresenta o frame
```

Esse laço roda na **main thread**, e ele tem um **orçamento de tempo**: pra
manter 60 FPS, todo o ciclo precisa caber em **16,7 ms**; pra 120 FPS, em
8,3 ms. Estourou o orçamento → o frame atrasa → o jogo engasga.

O "atualiza o mundo" é a parte que cresce com o jogo (mais inimigos, mais
física, mais IA) e é a candidata natural a paralelizar. É exatamente o que a
demo faz — e nada mais, de propósito: **render e input continuam serial**, o que
mais tarde vira a explicação do resultado (seção 3).

### Controles

| Player | Teclado | Controle |
|--------|---------|----------|
| P1 (azul) | `W` `A` `S` `D` | analógico esquerdo do device 0 |
| P2 (vermelho) | setas `↑` `↓` `←` `→` | analógico esquerdo do device 1 |
| P3 (verde) | `I` `J` `K` `L` | analógico esquerdo do device 2 |

| Tecla | Ação |
|-------|------|
| `ESPAÇO` | alterna **SERIAL ↔ THREADS** |
| `H` | cicla o nível de detalhe do HUD (tudo → só números → nada) |

Teclado e analógico **somam** no mesmo player, então dá pra jogar com teclado,
com controle ou com os dois.

### O que aparece na tela

O HUD ([scripts/hud.gd](scripts/hud.gd)) tem três blocos:

1. **Painel de números** — tempo/frame e FPS dos **dois** modos ao mesmo tempo.
   Os valores ficam retidos por modo, então depois de alternar uma vez você
   compara serial e threads na mesma tela, sem precisar decorar número. Embaixo
   sai o veredito (`THREADS 1.7x mais rápido`).

2. **Linha do tempo do frame** — uma barra por player, desenhada no instante
   real de início e fim da tarefa daquele player. É a **visualização direta do
   conceito de paralelismo**:
   - modo **serial** → barras em **escada** (P1 termina, P2 começa…): é a
     definição de execução sequencial, desenhada;
   - modo **threads** → barras **empilhadas no mesmo x**, começando juntas: as
     três ocupam o *mesmo intervalo de tempo*, que é a definição de paralelismo.

   A régua tem escala fixa no pior modo já medido, então serial enche a barra e
   threads ocupa só uma fração dela. A barra mais comprida do modo paralelo é o
   **straggler** — o retardatário que define o custo do frame (seção 3).

3. **Histórico por player** — os últimos 90 frames de cada player. Ao apertar
   `[ESPAÇO]` o degrau aparece nos três gráficos ao mesmo tempo, o que mostra
   que a mudança é **global** (o modo de execução), não um player específico.

### Por que 3 players e não 256 agentes

A versão anterior tinha 256 agentes anônimos. Trocar por 3 players jogáveis
custa speedup (o teto cai de "todos os núcleos" para 3x), mas ganha o que
importa numa demo: **cada thread tem dono**. Você segura `W` e vê a barra azul
— aquela thread — reagindo. O paralelismo deixa de ser um número e vira uma
coisa que você controla com a mão.

Em compensação, a demo passa a exibir bem o custo da **granularidade grossa**:
com só 3 tarefas, o overhead fixo pesa e a eficiência cai pra 58%. Com 256
tarefas ela seria muito maior — é a diferença entre demonstrar o teto teórico e
demonstrar o mundo real.

---

## 2. Threads em código

### O padrão: `add_group_task`

O núcleo da demo são estas 8 linhas em
[scripts/main.gd:43-57](scripts/main.gd#L43-L57):

```gdscript
func _process(delta: float) -> void:
	var bounds := get_viewport_rect().size
	for p in players:
		p.poll_input()  # main thread: Input não é thread-safe

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		var task := WorkerThreadPool.add_group_task(
			_step_player.bind(delta, bounds), players.size(), -1, true
		)
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for i in players.size():
			_step_player(i, delta, bounds)
```

Os dois ramos chamam **exatamente a mesma função**
([`_step_player`](scripts/main.gd#L67)) com os mesmos argumentos. A única
diferença é *quem* chama: um `for` na main thread, ou o pool distribuindo os
índices pelas threads. Isso é o que torna a comparação honesta — não existe
"versão otimizada para threads", só uma mudança de **quem executa**.

Os argumentos de `add_group_task(action, elements, tasks_needed, high_priority)`:

| Argumento | Valor | Conceito |
|---|---|---|
| `action` | `_step_player.bind(delta, bounds)` | o `Callable` que recebe o **índice** do elemento; `.bind()` fixa os parâmetros extras |
| `elements` | `players.size()` = 3 | quantos itens processar — o pool chama `_step_player(0)`, `(1)`, `(2)` |
| `tasks_needed` | `-1` | "decida você" — o pool usa no máximo min(núcleos, elementos) = **3** |
| `high_priority` | `true` | fila de alta prioridade: trabalho que **precisa** caber no frame |

`wait_for_group_task_completion()` é a **barreira** do fork-join: a main thread
bloqueia até o último player terminar. É o que garante que o `_draw()` do frame
veja os três já atualizados — sem ela, o jogo desenharia um estado
**parcialmente atualizado**, com um player já movido e outro não.

### Por que `WorkerThreadPool` e não `Thread.new()`

Godot oferece as duas coisas. A demo usa o pool de propósito, e a justificativa
é conceitual:

| | `Thread.new()` manual | `WorkerThreadPool` |
|---|---|---|
| Criação | uma thread nova por uso — **caro** | threads criadas uma vez, reutilizadas |
| A 100 FPS | 300 threads criadas/destruídas por segundo | zero criação: só acorda quem dorme |
| Nº de threads | você decide (e erra) | dimensionado pelos núcleos da máquina |
| Oversubscription | fácil criar mais threads que núcleos → só context switch | evitada por construção |
| Balanceamento | manual | o pool distribui os índices |

**Oversubscription** é o erro clássico: criar 100 threads num CPU de 8 núcleos
não faz 100 coisas ao mesmo tempo — faz 8, com o SO gastando tempo revezando as
outras 92. Mais threads que núcleos **não** é mais paralelismo; é mais
concorrência (e mais overhead).

### As 4 regras de segurança que o código segue

Threads em jogo dão errado por motivos previsíveis. A demo respeita quatro
regras, e cada uma está marcada com comentário no código:

**a) Cada tarefa escreve só no próprio índice → nenhum lock.**

```gdscript
## Roda na thread do player i: escreve só em players[i].
func _step_player(i: int, delta: float, bounds: Vector2) -> void:
	players[i].step(delta, WORK_LOAD, bounds)
```

`players[i]` é exclusivo da tarefa `i`. Como **duas threads nunca escrevem no
mesmo endereço**, não existe data race — e portanto **`Mutex` é desnecessário**.

Esse é o padrão que se chama **particionamento de dados** (*data partitioning*)
ou paralelismo **embaraçosamente paralelo** (*embarrassingly parallel*): o
problema se divide em pedaços independentes, sem estado compartilhado. É o caso
fácil, e é o que se deve procurar antes de sair colocando lock.

O contraste vale a pena: se houvesse um **placar global** `total += p.heat`,
teríamos:

- **data race** — `+=` é ler-modificar-escrever, três operações não atômicas;
- ao proteger com `Mutex`, uma **seção crítica** que serializa as 3 threads —
  parte do ganho evapora, e isso apareceria no próprio gráfico da demo;
- e um efeito sutil: soma de `float` **não é associativa**, então o resultado
  mudaria conforme a ordem de chegada das threads. Ou seja, **não-determinismo**
  mesmo com o lock correto — uma *race condition* sem *data race*.

**b) `Input` só na main thread.**

A classe `Input` do Godot **não é thread-safe** (thread-safe = pode ser chamada
de várias threads sem corromper estado interno). Por isso todos os players fazem
[`poll_input()`](scripts/player.gd#L29) **antes** do dispatch, guardando o
resultado num campo simples:

```gdscript
var input := Vector2.ZERO  ## escrito na main thread, lido na thread do player
```

Esse é o padrão **snapshot** (ou *double buffering* de input): em vez de
sincronizar o acesso a um recurso compartilhado, você **copia o valor antes** e
as threads leem uma foto imutável.

Repare no fluxo: a main thread **escreve** `input` → barreira do fork → a worker
**lê** `input`. Escrita e leitura estão separadas pelo happens-before da
sincronização (seção 0), então nem esse campo precisa de lock. Sem essa
separação, seria data race.

**c) Nada de árvore de cena dentro da tarefa.**

`Player` é `RefCounted`, **não** `Node`. É **dado puro**: posição, cor, input,
timestamps. Nenhuma tarefa cria nó, muda propriedade de nó ou chama
`queue_redraw()`.

O motivo é conceitual: a **SceneTree é um estado global mutável e não
thread-safe**. Mexer nela de uma worker pode corromper a estrutura interna da
engine — que é o pior tipo de bug, porque o crash acontece longe da causa.

A separação usada aqui é **simulação (paralela) / apresentação (serial)**: as
threads só transformam dados; desenhar é sempre na main thread, depois da
barreira:

```gdscript
func _draw() -> void:
	for p in players:
		draw_circle(p.pos, RADIUS, p.color)
```

> Nota: em Godot 4 o contador de referências do `RefCounted` é **atômico**,
> então passar o objeto entre threads não corrompe o refcount. Isso protege o
> *ciclo de vida* do objeto — **não** os campos dele. A segurança dos campos vem
> da regra (a).

**d) Quem mede é o main; o HUD só formata.**

Os timestamps saem de dentro da própria tarefa
([scripts/player.gd:44-51](scripts/player.gd#L44-L51)):

```gdscript
func step(delta: float, work_load: int, bounds: Vector2) -> void:
	t_start = Time.get_ticks_usec()
	var acc := 0.0
	for k in work_load:
		acc += sqrt(float(k) + pos.x)
	heat = fmod(acc, 1.0)
	pos = (pos + input * SPEED * delta).clamp(Vector2.ZERO, bounds)
	t_end = Time.get_ticks_usec()
```

O `heat` guarda o resultado do loop — sem ele o cálculo seria trabalho jogado
fora, e num ambiente otimizador poderia até ser eliminado como **código morto**.

E o tempo do frame é o **span** — do dispatch até o **último** player terminar,
não a soma nem a média:

```gdscript
func _span_usec() -> int:
	var last := _frame_t0
	for p in players:
		last = maxi(last, p.t_end)
	return last - _frame_t0
```

O `max` não é detalhe de implementação, é o conceito: num grupo paralelo com
barreira, **o custo é o do mais lento**, porque todo mundo espera por ele. Usar
a média esconderia exatamente o fenômeno que a seção 3 explica.

### Determinismo: os dois modos dão o mesmo resultado?

Sim — e isso é uma propriedade que se conquista, não um acaso. Como cada tarefa
só lê dados imutáveis durante o frame (`delta`, `bounds`, `input`) e só escreve
no próprio `Player`, **a ordem de execução não afeta o resultado**. Rodar em
qualquer ordem, ou todos juntos, produz o mesmo estado final.

Isso é o que torna a comparação válida: os dois modos fazem **o mesmo trabalho e
chegam ao mesmo lugar**; só o *tempo* muda. Uma versão paralela que produzisse
resultado diferente não estaria sendo comparada — estaria sendo trocada.

### Detalhe de medição: vsync desligado

```gdscript
DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
Engine.max_fps = 0
```

Com **vsync** (sincronismo vertical) ligado, a engine espera o monitor pra
apresentar o frame, e os dois modos marcariam 60 FPS: o custo do trabalho
ficaria escondido dentro da espera. Isso é um caso de **gargalo deslocado** — a
métrica pararia de medir o que interessa.

Sem trava, o FPS reflete direto o custo do frame, e o gargalo volta a ser a CPU
— que é o que a demo quer estudar.

---

## 3. Por que os resultados deram isso

### Os números

| Modo | Tempo do trecho de trabalho | FPS | Tempo total do frame (1000/FPS) |
|------|------|-----|------|
| **SERIAL** | 7,39 ms | 97 | 10,31 ms |
| **THREADS** | 4,27 ms | 126 | 7,94 ms |

- **Speedup do trecho paralelizado:** `S = 7,39 / 4,27 =` **1,73x**
- **Eficiência:** `E = S / N = 1,73 / 3 =` **58%**
- **Ganho de FPS (speedup do programa inteiro):** `126 / 97 =` **+30%**

Três números, três conceitos, e a distância entre eles é a aula inteira: o
speedup **local** (1,73x) não é o speedup **global** (1,30x), e nenhum dos dois
é o ideal (3x).

### Por que o serial deu 7,39 ms

Direto: são 3 players × ~2,46 ms de trabalho cada, **em fila**, tudo na main
thread. É a definição de execução sequencial — o tempo total é a **soma**.

```
SERIAL   [--- P1 2,46ms ---][--- P2 2,46ms ---][--- P3 2,46ms ---]
         0                                                     7,39 ms
```

Cada `step()` roda 40.000 iterações de `sqrt` **em GDScript interpretado** — é
por isso que 40 mil iterações custam milissegundos e não microssegundos (uma
linguagem interpretada paga o custo de *decodificar* cada operação, além de
executá-la).

O `WORK_LOAD` alto é deliberado: é o que coloca a demo do lado certo do **ponto
de equilíbrio** da granularidade (seção 0). Com carga baixa, cada tarefa custaria
menos que despachá-la e **threads perderia para serial** — o que, aliás, é uma
demonstração igualmente válida, só que de outra lição.

Com 7,39 ms só de simulação dentro de um orçamento de ~10 ms, sobra pouco pro
resto — daí os 97 FPS.

### Por que threads deu 4,27 ms e não ~2,46 ms

O ideal teórico com 3 threads seria os 3 players em paralelo: **2,46 ms**
(speedup linear, eficiência 100%). Deu 4,27 ms — **1,81 ms de sobrecusto**.
Quatro motivos, do maior pro menor:

```
THREADS  [dispatch][--- P1 ---]
                   [--- P2 ---]
                   [------ P3 ------]       ← o span é o MAIOR, não a média
         0                            4,27 ms
```

**1. Desbalanceamento de carga: quem manda é o retardatário (*straggler*).**
`_span_usec()` mede até o **último** `t_end`, porque a barreira faz todo mundo
esperar por ele. Duas threads terminando em 2,5 ms não ajudam se a terceira
levou 4,2 ms — o tempo ocioso das duas primeiras é **desperdício puro**, e é ele
que derruba a eficiência de 100% para 58%. Em paralelismo com barreira, o custo
é sempre o do mais lento.

**2. Granularidade grossa: só existem 3 tarefas.**
A máquina tem 8 núcleos / 16 threads lógicas, mas o pool não tem como usar mais
do que 3, porque `elements = players.size() = 3`. O **teto de speedup é 3x**,
não 8x — e com poucas tarefas o pool não tem como reequilibrar (com 256 tarefas,
uma thread que terminasse cedo pegaria a próxima da fila; com 3, ela só espera).

**3. Overhead fixo de dispatch e sincronização.**
`add_group_task` precisa acordar threads que estavam dormindo, enfileirar as
tarefas e criar o `Callable` bindado; `wait_for_group_task_completion` bloqueia
a main thread e depois a reacorda. Isso custa dezenas a centenas de
microssegundos **por frame** — desprezível se cada tarefa durasse 100 ms,
relevante quando ela dura 2,5 ms. É o **preço de coordenar**, e ele não some
com mais núcleos: só é diluído por tarefas maiores.

**4. O hardware não escala linearmente.**
Uma thread sozinha num Ryzen 4800HS roda em **boost clock** mais alto do que
três threads simultâneas (mais núcleos ativos → mais calor/energia → clock
menor). Além disso, o scheduler do Windows pode colocar duas tarefas em threads
lógicas do **mesmo** núcleo físico — **SMT**, em que duas threads lógicas
dividem as unidades de execução de um núcleo real e portanto **não** entregam 2x.
Resultado: cada tarefa fica individualmente mais lenta no modo paralelo.

> Um quinto efeito, ausente aqui mas clássico na prova: **false sharing**. Se
> duas threads escrevem em variáveis *diferentes* que caem na **mesma linha de
> cache** (~64 bytes), o hardware invalida a linha inteira a cada escrita e o
> desempenho despenca — sem nenhum data race, só pela geometria da memória. Na
> demo os `Player` são objetos separados no heap e cada tarefa escreve poucos
> campos, uma vez, no fim — então o efeito não domina.

### Por que o FPS subiu só 30%, se o trecho ficou 1,73x mais rápido

Esta é a parte mais instrutiva, e o nome dela é **Lei de Amdahl**: *o speedup
total é limitado pela fração que você não paralelizou.*

```
             1                    p = fração paralelizável
S = ─────────────────────         N = número de threads
      (1 − p) + p / N             (1 − p) = a parte serial, o teto
```

O frame não é só a simulação. Descontando o trecho medido:

| | Trecho paralelizável | Resto do frame (render, HUD, `_draw`, `poll_input`) | Total |
|---|---|---|---|
| SERIAL | 7,39 ms | ~2,92 ms | 10,31 ms |
| THREADS | 4,27 ms | ~3,67 ms | 7,94 ms |

Os ~3 ms de render, desenho do HUD (que faz `draw_polyline`, `draw_string` e
polígonos todo frame), input e apresentação **continuam serial nos dois modos**.
Threads não toca neles. Então `p = 7,39 / 10,31 = 0,72` — **72% do frame é
paralelizável, 28% não é**.

Aplicando a fórmula com um speedup **perfeito** de 3x na parte paralela:

```
S = 1 / (0,28 + 0,72/3) = 1 / 0,522 = 1,92x  →  10,31 / 1,92 = 5,38 ms  →  ~186 FPS
```

Ou seja: **mesmo com paralelização perfeita**, o máximo alcançável seria ~186
FPS, nunca 3 × 97 = 291. E o limite absoluto, com N infinito, é
`1 / 0,28 = 3,5x` — otimizar 72% do frame **jamais** rende mais que 3,5x, por
mais núcleos que se jogue no problema.

O que de fato aconteceu:

- Economia no trecho paralelo (medido): **3,12 ms**
- Economia no frame inteiro (via FPS): **2,37 ms**

A diferença de ~0,75 ms é o que a barreira cobra **fora** da janela medida:
`_span_usec()` para no último `t_end`, mas ainda há o tempo de a main thread ser
acordada e retomar. Isso é o **viés do observador** — o instrumento mede o
trabalho, não o custo de coordenar o trabalho. O FPS, sendo medida do frame
inteiro, não tem como escapar dele. Invertendo a conta, o speedup **efetivo** da
parte paralela (sobrecusto incluído) foi `7,39 / 5,02 = 1,47x`, não 1,73x — e é
esse 1,47 que produz os 30% de FPS.

### A outra metade: Lei de Gustafson

Amdahl é pessimista porque assume o **problema fixo** (escalabilidade forte).
**Gustafson** observa que, na prática, ninguém compra mais núcleos pra rodar o
mesmo problema mais rápido — compra pra rodar um problema **maior** no mesmo
tempo:

```
S = (1 − p) + p × N        (escalabilidade fraca: o trabalho cresce com N)
```

É a leitura correta pra um jogo: threads não servem só pra ganhar 30% de FPS;
servem pra caber **mais inimigos, mais partículas, mais física** dentro do mesmo
orçamento de 16,7 ms. A demo mostra isso ao vivo — subir o número de players
melhora a eficiência, porque dilui o overhead fixo e dá ao pool mais tarefas
para equilibrar.

### Resumindo em três frases

1. **Serial = 7,39 ms** porque três trabalhos de ~2,5 ms rodam **em fila**: o
   tempo sequencial é a soma.
2. **Threads = 4,27 ms (1,73x, não 3x)** por quatro razões conjuntas —
   desbalanceamento (o span é o do straggler), granularidade grossa (só 3
   tarefas, teto de 3x), overhead fixo de fork-join, e hardware que não escala
   linearmente (boost clock, SMT).
3. **FPS +30% (não +73%)** pela **Lei de Amdahl**: só 72% do frame foi
   paralelizado, o resto (render e HUD) continua serial e limita o ganho a
   1,92x mesmo em condições perfeitas — e a 3,5x com núcleos infinitos.

> A moral da demo: paralelizar **funciona** (30% de FPS, com a mesma lógica de
> jogo, o mesmo resultado determinístico e sem um único lock), mas o ganho nunca
> é o número de núcleos. Ele é limitado pela parte serial que sobrou, pela
> granularidade das tarefas, pelo custo de coordenar e pelo hardware real.
> **Medir os dois modos lado a lado, ao vivo, é a única forma de saber se valeu
> a pena** — a intuição, em concorrência, erra quase sempre.

---

## Apêndice A — Glossário

| Termo | Definição | Onde aparece |
|---|---|---|
| **Thread** | Linha de execução dentro de um processo; pilha própria, **memória compartilhada** | tudo |
| **Concorrência** | Várias tarefas *em progresso*; questão de estrutura | seção 0 |
| **Paralelismo** | Várias tarefas *executando* no mesmo instante; precisa de vários núcleos | seção 0 |
| **Latência** | Tempo de *um* frame (o `ms` do HUD) | HUD |
| **Throughput** | Frames por segundo (o FPS) | HUD |
| **Data race** | Dois acessos ao mesmo endereço, um sendo escrita, sem sincronização → indefinido | regra (a) |
| **Race condition** | O resultado depende da ordem de execução das threads | regra (a) |
| **Seção crítica** | Trecho que só uma thread pode executar por vez | contraexemplo (a) |
| **Mutex** | Primitiva que garante exclusão mútua; serializa e entra em Amdahl | contraexemplo (a) |
| **Deadlock** | Threads esperando umas pelas outras em ciclo; nada progride | seção 0 |
| **Contenção** | Threads disputando o mesmo lock, esperando mais do que trabalhando | seção 0 |
| **Thread pool** | Threads criadas uma vez e reutilizadas — `WorkerThreadPool` | `main.gd` |
| **Fork-join** | Dividir em N tarefas e esperar todas numa barreira | `_process()` |
| **Barreira** | Ponto onde todas as threads precisam chegar — `wait_for_group_task_completion` | `main.gd:54` |
| **Happens-before** | Garantia de que o que A escreveu está visível para B | regra (b) |
| **Thread-safe** | Pode ser chamado de várias threads sem corromper estado — `Input` **não** é | regra (b) |
| **Particionamento** | Dividir os dados em pedaços exclusivos → dispensa lock | regra (a) |
| **Embaraçosamente paralelo** | Problema que se divide sem estado compartilhado; o caso fácil | regra (a) |
| **Snapshot** | Copiar o valor antes de despachar, em vez de sincronizar o acesso | regra (b) |
| **Determinismo** | Mesmo resultado independente da ordem de execução | seção 2 |
| **Granularidade** | Tamanho de cada tarefa: fina (overhead) × grossa (desbalanceamento) | `WORK_LOAD` |
| **Ponto de equilíbrio** | Carga abaixo da qual paralelizar **piora** | `WORK_LOAD` |
| **Straggler** | A tarefa mais lenta; define o custo do grupo inteiro | `_span_usec()` |
| **Desbalanceamento** | Threads terminando em tempos diferentes → ociosidade | seção 3 |
| **Oversubscription** | Mais threads que núcleos → context switch, não paralelismo | seção 2 |
| **Context switch** | Troca de thread no núcleo: salva registradores, polui cache | seção 0 |
| **Speedup** | `T_serial / T_paralelo` | 1,73x |
| **Eficiência** | `Speedup / N` — quanto de cada núcleo foi aproveitado | 58% |
| **Lei de Amdahl** | `1 / ((1−p) + p/N)` — a parte serial limita o ganho | seção 3 |
| **Lei de Gustafson** | `(1−p) + p×N` — com mais núcleos, resolva um problema maior | seção 3 |
| **Escalabilidade forte** | Problema fixo, mais núcleos (o que a demo mede) | seção 3 |
| **Escalabilidade fraca** | Problema cresce com os núcleos | seção 3 |
| **SMT** | Duas threads lógicas dividindo um núcleo físico; não entrega 2x | seção 3 |
| **False sharing** | Variáveis distintas na mesma linha de cache; degrada sem haver race | seção 3 |
| **Vsync** | Sincronia com o monitor; mascara o custo real do frame | `_ready()` |

---

## Apêndice B — Perguntas frequentes

**Por que não usar `Mutex` "por segurança"?**
Porque lock não é seguro por padrão — é **caro** por padrão. Ele cria uma seção
crítica, e seção crítica é código serial, que entra direto na Lei de Amdahl.
Aqui não há dado compartilhado sendo escrito, então o lock só custaria, sem
proteger nada. A ordem certa é: primeiro tente **particionar**; só se não der,
sincronize.

**Threads sempre deixam o programa mais rápido?**
Não. Se a carga por tarefa for menor que o custo de despachá-la, o paralelo
perde (ponto de equilíbrio). Num CPU de 1 núcleo, perde sempre. E se a parte
serial for grande, o ganho é limitado independentemente dos núcleos (Amdahl).

**Por que 3 tarefas e não uma por núcleo?**
Porque `elements = 3` — a divisão do trabalho segue o domínio (players), não o
hardware. Isso é honesto: em jogo real você paraleliza pela estrutura do jogo,
e o número de unidades raramente coincide com o número de núcleos.

**O modo paralelo pode dar resultado diferente do serial?**
Nesta demo, não — por construção (particionamento + dados imutáveis durante o
frame). Bastaria um acumulador compartilhado para introduzir não-determinismo,
inclusive **com** o lock correto, porque soma de `float` não é associativa.

**Por que medir o `max` dos tempos e não a média?**
Porque existe barreira: a main thread só continua quando a **última** terminar.
A média descreveria as threads; o `max` descreve o **frame**, que é o que o
jogador sente.

**Por que o FPS não subiu na mesma proporção que o `ms`?**
Porque `ms` mede só a parte paralelizada (72% do frame) e o FPS mede o frame
inteiro, sobrecusto de sincronização incluído. É Amdahl mais o viés do
instrumento — detalhado na seção 3.
