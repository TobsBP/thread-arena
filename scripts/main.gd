extends Node2D

## Arena: cada agente faz um "trabalho pesado" por frame.
## Modo serial -> tudo na main thread, o FPS cai.
## Modo threads -> WorkerThreadPool distribui nos núcleos, o FPS aguenta.

const AGENTS := 256
const RADIUS := 8.0

@export var use_threads := false
@export var work_load := 20000  ## iterações de trabalho falso por agente

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var heat := PackedFloat32Array()  ## resultado do trabalho, só pra colorir

@onready var hud: Label = $HUD


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var size := get_viewport_rect().size
	for i in AGENTS:
		pos.append(Vector2(rng.randf() * size.x, rng.randf() * size.y))
		vel.append(Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * 120.0)
		heat.append(0.0)


func _process(delta: float) -> void:
	if use_threads:
		# ponytail: group_task já faz o particionamento; sem Thread/Mutex manual.
		var task := WorkerThreadPool.add_group_task(_step_agent, AGENTS, -1, true)
		WorkerThreadPool.wait_for_group_task_completion(task)
	else:
		for i in AGENTS:
			_step_agent(i)

	var size := get_viewport_rect().size
	for i in AGENTS:
		pos[i] += vel[i] * delta
		if pos[i].x < 0.0 or pos[i].x > size.x:
			vel[i] = Vector2(-vel[i].x, vel[i].y)
		if pos[i].y < 0.0 or pos[i].y > size.y:
			vel[i] = Vector2(vel[i].x, -vel[i].y)

	hud.text = "%s | FPS: %d | agentes: %d | carga: %d\n[ESPAÇO] alternar  [↑/↓] carga" % [
		"THREADS (WorkerThreadPool)" if use_threads else "SERIAL (main thread)",
		Engine.get_frames_per_second(), AGENTS, work_load,
	]
	queue_redraw()


## Roda em paralelo: só escreve em heat[i], índice exclusivo -> sem lock.
# ponytail: heat tem uma única referência (nunca copiada), então o CoW do Packed
# array não dispara durante a escrita. Se passar heat pra outro lugar, use Mutex
# ou buffers por thread.
func _step_agent(i: int) -> void:
	var acc := 0.0
	for k in work_load:
		acc += sqrt(float(k) + float(i))
	heat[i] = fmod(acc, 1.0)


func _draw() -> void:
	for i in AGENTS:
		draw_circle(pos[i], RADIUS, Color.from_hsv(heat[i], 0.7, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event.is_action_pressed("ui_up"):
		work_load += 5000
	elif event.is_action_pressed("ui_down"):
		work_load = max(0, work_load - 5000)
