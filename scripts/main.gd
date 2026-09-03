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
const ATTACK_RANGE := 90.0
const ATTACK_DAMAGE := 25.0
const DEATH_TIME := 0.9  ## tombar + sumir
const ENEMY_SPEED := 170.0  ## mais lento que os players, senão não tem fuga
const PURPLE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Attack1.png")
const YELLOW_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png")
const YELLOW_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Run.png")
const YELLOW_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Attack1.png")

## HUD dos players, do pack: barra de vida + faixa com o nome.
const UI_BAR := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Base.png")
const UI_BAR_FILL := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Fill.png")
const UI_RIBBON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/SmallRibbons.png")
## Recortes: as duas texturas têm as pontas nas bordas e o miolo em x 128..192.
const BAR_SRC := Rect2(49, 22, 222, 19)
const BAR_CAP := 15.0
const RIBBON_SIZE := Vector2(315, 54)  ## faixa arredondada; o y muda por cor
const RIBBON_CAP := 62.0

const SHEEP_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep/Sheep_Idle.png")
const SHEEP_MOVE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const SHEEP_COUNT := 12
const SHEEP_SPEED := 45.0

## Mundo maior que a janela; a câmera enquadra os três players.
const WORLD := ArenaMap.WORLD
const CAM_MARGIN := 300.0  ## folga em volta dos players ao enquadrar

@export var use_threads := false

var players: Array[Player] = []  ## só os controláveis (câmera enquadra estes)
var units: Array[Player] = []  ## players + inimigo: 1 Thread por unidade
## ponytail: ovelhas são cenário — andam na main thread, fora do units/threads.
var sheep: Array[Player] = []
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
	_spawn_sheep()
	# Câmera presa ao mundo: nunca mostra fora do chão desenhado.
	cam.limit_right = int(WORLD.x)
	cam.limit_bottom = int(WORLD.y)
	cam.position = WORLD * 0.5


## P1 WASD + F, P2 setas + num0, P3 IJKL + O — cada um somando o controle
## de mesmo índice (ataque também no botão A do gamepad).
func _spawn_players() -> void:
	var size := WORLD
	var setups := [
		[Color.CORNFLOWER_BLUE, [KEY_W, KEY_S, KEY_A, KEY_D, KEY_F], BLUE_IDLE, BLUE_RUN, BLUE_ATK, 68.0],
		# roxo no lugar do vermelho: vermelho fica reservado pros inimigos
		[Color(0.65, 0.42, 0.86), [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0], PURPLE_IDLE, PURPLE_RUN, PURPLE_ATK, 452.0],
		[Color(0.96, 0.78, 0.22), [KEY_I, KEY_K, KEY_J, KEY_L, KEY_O], YELLOW_IDLE, YELLOW_RUN, YELLOW_ATK, 324.0],
	]
	for i in setups.size():
		var spot := Vector2(size.x * (i + 1) / (setups.size() + 1), size.y * 0.5)
		var p := Player.new(
			spot,
			setups[i][0],
			setups[i][1],
			i,
			setups[i][2],
			setups[i][3],
			setups[i][4]
		)
		p.ribbon_y = setups[i][5]
		players.append(p)
	units.assign(players)  # o inimigo entra depois, em _spawn_enemy()


## Um inimigo vermelho no meio do mundo: mais uma Thread no mesmo esquema.
func _spawn_enemy() -> void:
	var e := Player.new(WORLD * Vector2(0.5, 0.15), Color(0.85, 0.25, 0.25),
			[0, 0, 0, 0, 0], -1, RED_IDLE, RED_RUN, RED_ATK)
	e.is_enemy = true
	e.ribbon_y = 196.0  ## faixa vermelha
	e.speed = ENEMY_SPEED
	units.append(e)


## Ovelhas espalhadas pelo mundo: só decoração viva, sem input nem thread.
func _spawn_sheep() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	for _i in SHEEP_COUNT:
		var s := Player.new(Vector2(rng.randf(), rng.randf()) * WORLD, Color.WHITE,
				[0, 0, 0, 0, 0], -1, SHEEP_IDLE, SHEEP_MOVE, null, 6, 4, 0)
		s.frame_size = Vector2(128, 128)
		s.speed = SHEEP_SPEED
		sheep.append(s)


func _process(delta: float) -> void:
	var bounds := WORLD
	for u in units:
		# main thread: Input não é thread-safe, e a IA só escreve `input`.
		if u.is_enemy:
			u.chase(players)
		else:
			u.poll_input()

	for s in sheep:
		s.wander(delta)
		s.step(delta, 0, bounds)

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		var threads: Array[Thread] = []
		for i in units.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta, bounds))
			threads.append(t)
		for t in threads:
			t.wait_to_finish()
	else:
		for i in units.size():
			_step_player(i, delta, bounds)

	_resolve_attacks()

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	_update_camera()
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, units, _frame_t0)
	queue_redraw()


## Roda na Thread da unidade i: escreve só em units[i].
func _step_player(i: int, delta: float, bounds: Vector2) -> void:
	units[i].step(delta, WORK_LOAD, bounds)


## Dano e morte: mexe em dois objetos ao mesmo tempo, então roda na main
## thread depois da barreira — as tarefas continuam sem lock.
func _resolve_attacks() -> void:
	for u in units:
		if not u.is_enemy:
			continue
		if u.is_dead():
			# ponytail: respawn em vez de remover — a demo precisa do inimigo.
			if u.death_time > DEATH_TIME:
				u.hp = u.max_hp
				u.death_time = -1.0
				u.pos = WORLD * Vector2(0.5, 0.15)
			continue
		for p in players:
			if p.is_attacking() and not p.attack_hit \
					and p.pos.distance_to(u.pos) < ATTACK_RANGE:
				p.attack_hit = true
				u.hp -= ATTACK_DAMAGE
				if u.hp <= 0.0:
					u.hp = 0.0
					u.death_time = 0.0


## Duração total do trecho de trabalho, do dispatch ao último player terminar.
func _span_usec() -> int:
	var last := _frame_t0
	for p in units:
		last = maxi(last, p.t_end)
	return last - _frame_t0


func _draw() -> void:
	map.draw_into(self)
	for s in sheep:
		_draw_sprite(s)
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


## Sprite animado, com flip ao virar pra esquerda. Serve players, inimigo e
## ovelhas — sombra e HUD do player ficam em _draw_player().
func _draw_sprite(p: Player) -> void:
	var tex := p.get_current_texture()
	if tex:
		var fw := p.frame_size.x
		var fh := p.frame_size.y
		var src_rect := Rect2(p.get_current_frame() * fw, 0, fw, fh)
		var dest_rect := Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
		# Morte: sem sprite próprio no pack — tomba de lado e some.
		var t := 0.0 if not p.is_dead() else minf(p.death_time / DEATH_TIME, 1.0)
		var dir := 1.0 if p.facing_right else -1.0
		draw_set_transform(p.pos, dir * t * PI * 0.5, Vector2(dir, 1.0))
		draw_texture_rect_region(tex, dest_rect, src_rect, Color(1, 1, 1, 1.0 - t))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_circle(p.pos, RADIUS, p.color)


## 9-slice horizontal: as pontas de `cap` px saem inteiras (só escaladas) e o
## miolo (sempre x 128..192 nas texturas do pack) estica no que sobrar.
func _draw_hslice(tex: Texture2D, dest: Rect2, src: Rect2, cap: float) -> void:
	var c := cap * dest.size.y / src.size.y
	draw_texture_rect_region(tex, Rect2(dest.position, Vector2(c, dest.size.y)),
			Rect2(src.position, Vector2(cap, src.size.y)))
	draw_texture_rect_region(tex,
			Rect2(dest.position + Vector2(c, 0), Vector2(dest.size.x - 2.0 * c, dest.size.y)),
			Rect2(128, src.position.y, 64, src.size.y))
	draw_texture_rect_region(tex,
			Rect2(dest.position + Vector2(dest.size.x - c, 0), Vector2(c, dest.size.y)),
			Rect2(src.end.x - cap, src.position.y, cap, src.size.y))


func _draw_player(p: Player) -> void:
	# 1. Sombra elíptica sob os pés (as ovelhas já vêm com a sua no sprite)
	var shadow_pos := p.pos + Vector2(0, 36)
	draw_set_transform(shadow_pos, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 20.0, Color(0.0, 0.0, 0.0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_sprite(p)
	if p.is_dead():
		return

	# 2. Faixa com o nome e barra de vida, ambas do pack de UI.
	_draw_hslice(UI_RIBBON, Rect2(p.pos + Vector2(-30, -92), Vector2(60, 22)),
			Rect2(Vector2(2, p.ribbon_y), RIBBON_SIZE), RIBBON_CAP)
	draw_string(
		ThemeDB.fallback_font,
		p.pos + Vector2(-30, -75),
		"ENEMY" if p.is_enemy else "P%d" % (p.joy_device + 1),
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		12,
		Color(0.15, 0.12, 0.15)
	)

	var bar := Rect2(p.pos + Vector2(-32, -68), Vector2(64, 19))
	_draw_hslice(UI_BAR, bar, BAR_SRC, BAR_CAP)
	var ratio := clampf(p.hp / p.max_hp, 0.0, 1.0)
	if ratio > 0.0:
		# Faixa vermelha do asset: 3px de altura, 8px abaixo do topo da barra.
		draw_texture_rect_region(UI_BAR_FILL,
				Rect2(bar.position + Vector2(7, 8), Vector2((bar.size.x - 14) * ratio, 3)),
				Rect2(0, 30, 64, 3))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		hud.cycle_detail()
