# Thread Arena

Demo em Godot 4.7 do impacto de threads: a mesma simulação rodando **serial**
(tudo na main thread) ou **paralela** (`WorkerThreadPool`), alternando em tempo
real com o FPS na tela.

## Rodar

Abra a pasta no Godot 4.7 e dê F5 (a cena principal já é `scenes/main.tscn`).

## Controles

| Tecla | Ação |
|-------|------|
| `ESPAÇO` | alterna SERIAL ↔ THREADS |
| `↑` / `↓` | aumenta / diminui a carga de trabalho por agente |

## O que a demo mostra

256 agentes; cada um executa um trabalho pesado por frame (`work_load`
iterações de `sqrt`). No modo serial esse custo cai inteiro no frame da main
thread e o FPS despenca. No modo threads, `WorkerThreadPool.add_group_task()`
distribui os agentes pelos núcleos e o FPS se mantém — a diferença aumenta
conforme você sobe a carga com `↑`.

Cada agente escreve só no próprio índice de `heat`, então não há lock: é o caso
fácil de paralelismo (dados particionados, sem estado compartilhado).

## Estrutura

```
scenes/   cenas (.tscn)
scripts/  scripts (.gd)
```
