extends Node2D

## Arena: cada player faz um "trabalho pesado" por frame.
## Modo serial -> tudo na main thread, as tarefas saem em fila.
## Modo threads -> 1 Thread por player, elas rodam sobrepostas.
## Quem mostra os números é scenes/hud.tscn.

const RADIUS := 20.0
const WORK_LOAD := 40000  ## iterações de trabalho falso por player

const BLUE_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png")
const BLUE_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Run.png")
const BLUE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Attack1.png")
const PURPLE_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Idle.png")
const PURPLE_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Run.png")
const RED_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Idle.png")
const RED_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Run.png")
const RED_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Red Units/Warrior/Warrior_Attack1.png")
const ENEMY_SPEED := 170.0  ## mais lento que os players, senão não tem fuga
const PURPLE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Attack1.png")
const YELLOW_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png")
const YELLOW_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Run.png")
const YELLOW_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Attack1.png")

## Mundo maior que a janela; a câmera enquadra os três players.
const WORLD := ArenaMap.WORLD
const CAM_MARGIN := 300.0  ## folga em volta dos players ao enquadrar

@export var use_threads := false

var players: Array[Player] = []  ## só os controláveis (câmera enquadra estes)
var units: Array[Player] = []  ## players + inimigo: 1 Thread por unidade
var _frame_t0 := 0
var map := ArenaMap.new()
## Medidas retidas por modo (false = serial, true = threads), pra comparar
## os dois lado a lado mesmo depois de alternar.
var fps_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var ms_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}

@onready var hud: Control = $UI/HUD
@onready var cam: Camera2D = $Camera


func _ready() -> void:
	# FPS destravado: sem vsync o custo do trabalho aparece direto no FPS.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spawn_players()
	_spawn_enemy()
	# Câmera presa ao mundo: nunca mostra fora do chão desenhado.
	cam.limit_right = int(WORLD.x)
	cam.limit_bottom = int(WORLD.y)
	cam.position = WORLD * 0.5


## P1 WASD + F, P2 setas + num0, P3 IJKL + O — cada um somando o controle
## de mesmo índice (ataque também no botão A do gamepad).
func _spawn_players() -> void:
	var size := WORLD
	var setups := [
		[Color.CORNFLOWER_BLUE, [KEY_W, KEY_S, KEY_A, KEY_D, KEY_F], BLUE_IDLE, BLUE_RUN, BLUE_ATK],
		# roxo no lugar do vermelho: vermelho fica reservado pros inimigos
		[Color(0.65, 0.42, 0.86), [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0], PURPLE_IDLE, PURPLE_RUN, PURPLE_ATK],
		[Color(0.96, 0.78, 0.22), [KEY_I, KEY_K, KEY_J, KEY_L, KEY_O], YELLOW_IDLE, YELLOW_RUN, YELLOW_ATK],
	]
	for i in setups.size():
		var spot := Vector2(size.x * (i + 1) / (setups.size() + 1), size.y * 0.5)
		players.append(Player.new(
			spot,
			setups[i][0],
			setups[i][1],
			i,
			setups[i][2],
			setups[i][3],
			setups[i][4]
		))
	units.assign(players)  # o inimigo entra depois, em _spawn_enemy()


## Um inimigo vermelho no meio do mundo: mais uma Thread no mesmo esquema.
func _spawn_enemy() -> void:
	var e := Player.new(WORLD * Vector2(0.5, 0.15), Color(0.85, 0.25, 0.25),
			[0, 0, 0, 0, 0], -1, RED_IDLE, RED_RUN, RED_ATK)
	e.is_enemy = true
	e.speed = ENEMY_SPEED
	units.append(e)


func _process(delta: float) -> void:
	var bounds := WORLD
	for u in units:
		# main thread: Input não é thread-safe, e a IA só escreve `input`.
		if u.is_enemy:
			u.chase(players)
		else:
			u.poll_input()

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		# start() dispara e volta na hora; o trabalho já está rodando em paralelo.
		# ponytail: criar thread por frame custa ~50us contra ~3ms de trabalho.
		# Se WORK_LOAD cair muito, virar pool de threads persistentes + Semaphore.
		var threads: Array[Thread] = []
		for i in units.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta, bounds))
			threads.append(t)
		# Barreira: bloqueia até cada thread terminar (e libera os recursos dela).
		for t in threads:
			t.wait_to_finish()
	else:
		for i in units.size():
			_step_player(i, delta, bounds)

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	_update_camera()
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, units, _frame_t0)
	queue_redraw()


## Roda na Thread da unidade i: escreve só em units[i].
func _step_player(i: int, delta: float, bounds: Vector2) -> void:
	units[i].step(delta, WORK_LOAD, bounds)


## Duração total do trecho de trabalho, do dispatch ao último player terminar.
func _span_usec() -> int:
	var last := _frame_t0
	for p in units:
		last = maxi(last, p.t_end)
	return last - _frame_t0


func _draw() -> void:
	map.draw_into(self)
	for u in units:
		_draw_player(u)


## Enquadra os três players: centro na caixa que os contém, zoom pra caber
## todo mundo (sem passar de 100% nem mostrar fora do mundo). Lerp pra não
## tremer a cada frame.
func _update_camera() -> void:
	var box := Rect2(players[0].pos, Vector2.ZERO)
	for p in players:
		box = box.expand(p.pos)
	box = box.grow(CAM_MARGIN)
	var vp := get_viewport_rect().size
	var min_zoom := maxf(vp.x / WORLD.x, vp.y / WORLD.y)
	var z := clampf(minf(vp.x / box.size.x, vp.y / box.size.y), min_zoom, 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.08)
	cam.position = cam.position.lerp(box.get_center(), 0.12)


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

	# 3. Barra de HP acima da cabeça
	var bar := Rect2(p.pos + Vector2(-24, -76), Vector2(48, 7))
	draw_rect(bar, Color(0.05, 0.06, 0.08, 0.85), true)
	var ratio := clampf(p.hp / p.max_hp, 0.0, 1.0)
	if ratio > 0.0:
		var fill := Rect2(bar.position + Vector2.ONE, Vector2((bar.size.x - 2) * ratio, bar.size.y - 2))
		draw_rect(fill, Color(0.85, 0.25, 0.25).lerp(Color(0.35, 0.8, 0.35), ratio), true)
	draw_rect(bar, p.color, false, 1.0)

	# 4. Badge identificador do player (P1, P2, P3) acima da cabeça
	var badge_size := Vector2(26, 16)
	var badge_pos := p.pos + Vector2(-badge_size.x * 0.5, -58)
	var badge_rect := Rect2(badge_pos, badge_size)
	draw_rect(badge_rect, Color(0.05, 0.06, 0.08, 0.85), true)
	draw_rect(badge_rect, p.color, false, 1.5)
	draw_string(
		ThemeDB.fallback_font,
		badge_pos + Vector2(4, 12),
		"E" if p.is_enemy else "P%d" % (p.joy_device + 1),
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
