# Thread Arena

Jogo/demo educacional em **Godot 4.7 (GDScript)** que compara execução serial vs.
paralela da mesma simulação, ao vivo, com FPS na tela. Veja o README para os
controles.

## Estrutura

- `scenes/main.tscn` — cena principal (Node2D + Label do HUD)
- `scripts/main.gd` — simulação, alternância serial/threads, desenho e input
- `project.godot` — `run/main_scene` aponta pra `scenes/main.tscn`

## Convenções

- Cenas em `scenes/`, scripts em `scripts/`; caminhos sempre `res://`.
- Paralelismo via `WorkerThreadPool.add_group_task()` — **não** criar `Thread`
  manualmente a menos que a demo precise mostrar isso explicitamente.
- Sem locks enquanto cada tarefa escrever só no próprio índice. Se algum dado
  passar a ser compartilhado, aí sim `Mutex` (e vale mostrar na demo).
- `heat` é um `PackedFloat32Array` com uma única referência — copiá-lo dispara
  CoW e quebra a escrita concorrente.

## Notas

- O binário `godot` não está no PATH desta máquina; mudanças não foram
  executadas — teste no editor.
- Não commitar `.godot/` (já está no `.gitignore`).

## Git

- Mensagens de commit **sem** trailers `Co-Authored-By:` ou `Claude-Session:`.
