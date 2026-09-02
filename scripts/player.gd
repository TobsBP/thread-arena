class_name Player
extends RefCounted

## Um player = uma Thread por frame (ver main.gd).
## Input é lido na main thread; a tarefa só escreve nos campos deste objeto,
## que é exclusivo daquele índice -> sem lock.

const SPEED := 260.0
const DEADZONE := 0.2

var pos: Vector2
var color: Color
var keys: PackedInt32Array  ## [cima, baixo, esquerda, direita] (physical keycodes)
var joy_device: int
var input := Vector2.ZERO  ## escrito na main thread, lido na thread do player
var heat := 0.0  ## resultado do trabalho pesado, só pra provar que rodou
var t_start := 0  ## usec, início do step -> alimenta o gráfico
var t_end := 0


func _init(start_pos: Vector2, col: Color, key_list: Array, device: int) -> void:
	pos = start_pos
	color = col
	keys = PackedInt32Array(key_list)
	joy_device = device


## Main thread only: a classe Input não é thread-safe.
func poll_input() -> void:
	var kb := Vector2(
		float(Input.is_physical_key_pressed(keys[3])) - float(Input.is_physical_key_pressed(keys[2])),
		float(Input.is_physical_key_pressed(keys[1])) - float(Input.is_physical_key_pressed(keys[0])),
	)
	var joy := Vector2(
		Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_Y),
	)
	if joy.length() < DEADZONE:
		joy = Vector2.ZERO
	input = (kb + joy).limit_length(1.0)


## Roda na Thread do player.
func step(delta: float, work_load: int, bounds: Vector2) -> void:
	t_start = Time.get_ticks_usec()
	var acc := 0.0
	for k in work_load:
		acc += sqrt(float(k) + pos.x)
	heat = fmod(acc, 1.0)
	pos = (pos + input * SPEED * delta).clamp(Vector2.ZERO, bounds)
	t_end = Time.get_ticks_usec()
