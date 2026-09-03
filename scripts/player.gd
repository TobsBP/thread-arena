class_name Player
extends RefCounted

## Um player = uma Thread por frame (ver main.gd).
## Input é lido na main thread; a tarefa só escreve nos campos deste objeto,
## que é exclusivo daquele índice -> sem lock.

const SPEED := 260.0
const DEADZONE := 0.2

var pos: Vector2
var color: Color
var keys: PackedInt32Array  ## [cima, baixo, esquerda, direita, atacar] (physical keycodes)
var joy_device: int
var speed := SPEED
var is_enemy := false
var input := Vector2.ZERO  ## escrito na main thread, lido na thread do player
var heat := 0.0  ## resultado do trabalho pesado, só pra provar que rodou
var max_hp := 100.0
var hp := 100.0  ## por enquanto só o HUD lê; nada tira vida ainda
var t_start := 0  ## usec, início do step -> alimenta o gráfico
var t_end := 0

var idle_texture: Texture2D
var run_texture: Texture2D
var attack_texture: Texture2D
var idle_frames := 8
var run_frames := 6
var attack_frames := 4
## Ataque: começa no poll (main thread) e roda até o ciclo terminar.
var attack_pressed := false
var attack_time := -1.0  ## < 0 = não está atacando
var frame_size := Vector2(192, 192)
var anim_fps := 10.0
var anim_time := 0.0
var facing_right := true


func _init(
	start_pos: Vector2,
	col: Color,
	key_list: Array,
	device: int,
	idle_tex: Texture2D = null,
	run_tex: Texture2D = null,
	attack_tex: Texture2D = null,
	i_frames := 8,
	r_frames := 6,
	a_frames := 4,
) -> void:
	pos = start_pos
	color = col
	keys = PackedInt32Array(key_list)
	joy_device = device
	idle_texture = idle_tex
	run_texture = run_tex
	attack_texture = attack_tex
	idle_frames = i_frames
	run_frames = r_frames
	attack_frames = a_frames


## IA do inimigo: roda na main thread junto com o poll, só escreve `input`.
## Persegue o alvo mais próximo — a thread depois só aplica o movimento.
func chase(targets: Array[Player]) -> void:
	var best: Player = null
	for t in targets:
		if best == null or pos.distance_squared_to(t.pos) < pos.distance_squared_to(best.pos):
			best = t
	input = Vector2.ZERO if best == null else (best.pos - pos).normalized()


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
	attack_pressed = (Input.is_physical_key_pressed(keys[4])
			or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_A))


## Roda na Thread do player.
func step(delta: float, work_load: int, bounds: Vector2) -> void:
	t_start = Time.get_ticks_usec()
	var acc := 0.0
	for k in work_load:
		acc += sqrt(float(k) + pos.x)
	heat = fmod(acc, 1.0)
	pos = (pos + input * speed * delta).clamp(Vector2(32, 32), bounds - Vector2(32, 32))
	anim_time += delta
	_step_attack(delta)
	if input.x > 0.05:
		facing_right = true
	elif input.x < -0.05:
		facing_right = false
	t_end = Time.get_ticks_usec()


## Um ataque não pode ser cancelado: só reinicia depois do ciclo acabar.
func _step_attack(delta: float) -> void:
	if is_attacking():
		attack_time += delta
		if attack_time >= attack_frames / anim_fps:
			attack_time = -1.0
	elif attack_pressed:
		attack_time = 0.0


func is_attacking() -> bool:
	return attack_time >= 0.0


func is_running() -> bool:
	return input.length_squared() > 0.01


func get_current_texture() -> Texture2D:
	if is_attacking() and attack_texture:
		return attack_texture
	return run_texture if is_running() else idle_texture


func get_current_frame() -> int:
	if is_attacking() and attack_texture:
		return mini(int(attack_time * anim_fps), attack_frames - 1)
	var total := run_frames if is_running() else idle_frames
	if total <= 0:
		return 0
	return int(anim_time * anim_fps) % total
