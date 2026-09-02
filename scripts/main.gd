extends Node2D

## Arena: cada player faz um "trabalho pesado" por frame.
## Modo serial -> tudo na main thread, as tarefas saem em fila.
## Modo threads -> 1 Thread por player, elas rodam sobrepostas.
## Quem mostra os números é scenes/hud.tscn.

const RADIUS := 20.0
const WORK_LOAD := 40000  ## iterações de trabalho falso por player

const BLUE_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png")
const BLUE_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Run.png")
const RED_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Idle.png")
const RED_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Run.png")
const YELLOW_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png")
const YELLOW_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Run.png")

@export var use_threads := false

var players: Array[Player] = []
var _frame_t0 := 0
## Medidas retidas por modo (false = serial, true = threads), pra comparar
## os dois lado a lado mesmo depois de alternar.
var fps_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var ms_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}

@onready var hud: Control = $HUD


func _ready() -> void:
	# FPS destravado: sem vsync o custo do trabalho aparece direto no FPS.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spawn_players()


## P1 teclado WASD + controle 0, P2 setas + controle 1, P3 IJKL + controle 2.
func _spawn_players() -> void:
	var size := get_viewport_rect().size
	var setups := [
		[Color.CORNFLOWER_BLUE, [KEY_W, KEY_S, KEY_A, KEY_D], BLUE_IDLE, BLUE_RUN],
		[Color.INDIAN_RED, [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT], RED_IDLE, RED_RUN],
		[Color(0.96, 0.78, 0.22), [KEY_I, KEY_K, KEY_J, KEY_L], YELLOW_IDLE, YELLOW_RUN],
	]
	for i in setups.size():
		var spot := Vector2(size.x * (i + 1) / (setups.size() + 1), size.y * 0.5)
		players.append(Player.new(
			spot,
			setups[i][0],
			setups[i][1],
			i,
			setups[i][2],
			setups[i][3]
		))


func _process(delta: float) -> void:
	var bounds := get_viewport_rect().size
	for p in players:
		p.poll_input()  # main thread: Input não é thread-safe

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		# start() dispara e volta na hora; o trabalho já está rodando em paralelo.
		# ponytail: criar thread por frame custa ~50us contra ~3ms de trabalho.
		# Se WORK_LOAD cair muito, virar pool de threads persistentes + Semaphore.
		var threads: Array[Thread] = []
		for i in players.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta, bounds))
			threads.append(t)
		# Barreira: bloqueia até cada thread terminar (e libera os recursos dela).
		for t in threads:
			t.wait_to_finish()
	else:
		for i in players.size():
			_step_player(i, delta, bounds)

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, players, _frame_t0)
	queue_redraw()


## Roda na Thread do player i: escreve só em players[i].
func _step_player(i: int, delta: float, bounds: Vector2) -> void:
	players[i].step(delta, WORK_LOAD, bounds)


## Duração total do trecho de trabalho, do dispatch ao último player terminar.
func _span_usec() -> int:
	var last := _frame_t0
	for p in players:
		last = maxi(last, p.t_end)
	return last - _frame_t0


func _draw() -> void:
	for p in players:
		_draw_player(p)


func _draw_player(p: Player) -> void:
	# 1. Sombra elíptica sob os pés
	var shadow_pos := p.pos + Vector2(0, 36)
	draw_set_transform(shadow_pos, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 20.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Sprite animado do guerreiro com flip horizontal ao virar para a esquerda
	var tex := p.get_current_texture()
	if tex:
		var frame := p.get_current_frame()
		var fw := p.frame_size.x
		var fh := p.frame_size.y
		var src_rect := Rect2(frame * fw, 0, fw, fh)
		var dest_rect := Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
		var flip_scale := Vector2(1.0 if p.facing_right else -1.0, 1.0)

		draw_set_transform(p.pos, 0.0, flip_scale)
		draw_texture_rect_region(tex, dest_rect, src_rect)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(p.pos, RADIUS, p.color)

	# 3. Badge identificador do player (P1, P2, P3) acima da cabeça
	var badge_size := Vector2(26, 16)
	var badge_pos := p.pos + Vector2(-badge_size.x * 0.5, -58)
	var badge_rect := Rect2(badge_pos, badge_size)
	draw_rect(badge_rect, Color(0.05, 0.06, 0.08, 0.85), true)
	draw_rect(badge_rect, p.color, false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		badge_pos + Vector2(4, 12),
		"P%d" % (p.joy_device + 1),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		11,
		p.color
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		hud.cycle_detail()
