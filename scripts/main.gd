extends Node2D

## Arena: cada player faz um "trabalho pesado" por frame.
## Modo serial -> tudo na main thread, as tarefas saem em fila.
## Modo threads -> 1 Thread por player, elas rodam sobrepostas.
## Quem mostra os números é scenes/hud.tscn.

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
const ENEMY_COOLDOWN := 1.2  ## respiro entre golpes do inimigo, em segundos
const ENEMY_SPEED := 170.0  ## mais lento que os players, senão não tem fuga
const PURPLE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Attack1.png")
const YELLOW_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png")
const YELLOW_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Run.png")
const YELLOW_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Attack1.png")

## Pawns: dois azuis e dois amarelos indo do toco à base com madeira. Cenário
## vivo, igual às ovelhas — main thread, fora de units/threads.
const PAWN_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Idle.png")
const PAWN_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Run.png")
const PAWN_WOOD := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Run Wood.png")
const PAWN_AXE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Pawn/Pawn_Interact Axe.png")
const PAWN_IDLE_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Idle.png")
const PAWN_RUN_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Run.png")
const PAWN_WOOD_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Run Wood.png")
const PAWN_AXE_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Interact Axe.png")
const PAWN_COUNT := 4
const PAWN_SPEED := 120.0

const SHEEP_GRAZE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep/Sheep_Grass.png")
const SHEEP_MOVE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const SHEEP_COUNT := 18
const SHEEP_SPEED := 45.0

## Mundo maior que a janela; a câmera enquadra os três players.
const WORLD := ArenaMap.WORLD
const PLAY_AREA := ArenaMap.PLAY_AREA
const CAM_MARGIN := 300.0  ## folga em volta dos players ao enquadrar

@export var use_threads := false

var players: Array[Player] = []  ## só os controláveis (câmera enquadra estes)
var units: Array[Player] = []  ## players + inimigo: 1 Thread por unidade
## ponytail: ovelhas são cenário — andam na main thread, fora do units/threads.
var sheep: Array[Player] = []
## Pawns lenhadores: cenário vivo, como as ovelhas.
var workers: Array[Player] = []
## Tudo que se esbarra: units + sheep + workers, montado uma vez no _ready().
var bodies: Array[Player] = []
var _frame_t0 := 0
## Medidas retidas por modo (false = serial, true = threads), pra comparar
## os dois lado a lado mesmo depois de alternar.
var fps_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var ms_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}

@onready var map: ArenaMap = $ArenaMap
@onready var hud: Control = $UI/HUD
@onready var cam: Camera2D = $Camera


func _ready() -> void:
	# FPS destravado: sem vsync o custo do trabalho aparece direto no FPS.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spawn_players()
	_spawn_enemy()
	_spawn_sheep()
	_spawn_workers()
	bodies.assign(units)
	bodies.append_array(sheep)
	bodies.append_array(workers)
	# Cada unidade ganha um nó de desenho dentro do cenário y-sorted: é o que
	# faz o player passar atrás da árvore. O dado segue RefCounted.
	for u in units:
		map.add_unit(UnitSprite.create(u))
	for s in sheep:
		map.add_unit(UnitSprite.create(s, false))
	for w in workers:
		map.add_unit(UnitSprite.create(w, false))
	# Câmera presa ao mundo: nunca mostra fora do chão desenhado.
	cam.limit_right = int(WORLD.x)
	cam.limit_bottom = int(WORLD.y)
	cam.position = WORLD * 0.5


## P1 WASD + F, P2 setas + num0, P3 IJKL + O — cada um somando o controle
## de mesmo índice (ataque também no botão A do gamepad).
func _spawn_players() -> void:
	var size := PLAY_AREA.size
	var setups := [
		[Color.CORNFLOWER_BLUE, [KEY_W, KEY_S, KEY_A, KEY_D, KEY_F], BLUE_IDLE, BLUE_RUN, BLUE_ATK, 68.0],
		# roxo no lugar do vermelho: vermelho fica reservado pros inimigos
		[Color(0.65, 0.42, 0.86), [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0], PURPLE_IDLE, PURPLE_RUN, PURPLE_ATK, 452.0],
		[Color(0.96, 0.78, 0.22), [KEY_I, KEY_K, KEY_J, KEY_L, KEY_O], YELLOW_IDLE, YELLOW_RUN, YELLOW_ATK, 324.0],
	]
	for i in setups.size():
		var spot := PLAY_AREA.position + Vector2(
				size.x * (i + 1) / (setups.size() + 1), size.y * 0.5)
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
	var e := Player.new(PLAY_AREA.position + PLAY_AREA.size * Vector2(0.5, 0.12),
			Color(0.85, 0.25, 0.25), [0, 0, 0, 0, 0], -1, RED_IDLE, RED_RUN, RED_ATK)
	e.is_enemy = true
	e.ribbon_y = 196.0  ## faixa vermelha
	e.speed = ENEMY_SPEED
	units.append(e)


## Ovelhas espalhadas pela ilha: só decoração viva, sem input nem thread.
func _spawn_sheep() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	for _i in SHEEP_COUNT:
		var spot := PLAY_AREA.position + Vector2(rng.randf(), rng.randf()) * PLAY_AREA.size
		var s := Player.new(spot, Color.WHITE, [0, 0, 0, 0, 0], -1,
				SHEEP_GRAZE, SHEEP_MOVE, null, 12, 4, 0)
		s.frame_size = Vector2(128, 128)
		s.speed = SHEEP_SPEED
		sheep.append(s)


## Cada pawn puxa madeira de uma árvore pra uma construção — os pontos vêm do
## mapa, que é quem sabe onde as coisas caíram.
func _spawn_workers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in PAWN_COUNT:
		var blue := i % 2 == 0
		var home: Vector2 = map.building_spots[i % map.building_spots.size()]
		var w := Player.new(home, Color.WHITE, [0, 0, 0, 0, 0], -1,
				PAWN_IDLE if blue else PAWN_IDLE_Y,
				PAWN_RUN if blue else PAWN_RUN_Y,
				PAWN_AXE if blue else PAWN_AXE_Y, 8, 6, 6)
		w.loaded_texture = PAWN_WOOD if blue else PAWN_WOOD_Y
		w.speed = PAWN_SPEED
		w.work_home = home
		w.work_site = map.tree_spots[rng.randi() % map.tree_spots.size()]
		workers.append(w)


func _process(delta: float) -> void:
	for u in units:
		# main thread: Input não é thread-safe, e a IA só escreve `input`.
		if u.is_enemy:
			u.chase(players, ATTACK_RANGE, ENEMY_COOLDOWN, delta)
		else:
			u.poll_input()

	for s in sheep:
		s.wander(delta)
		s.step(delta, 0, PLAY_AREA, map.blockers)

	for w in workers:
		w.haul(delta)
		w.step(delta, 0, PLAY_AREA, map.blockers)

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		var threads: Array[Thread] = []
		for i in units.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta))
			threads.append(t)
		for t in threads:
			t.wait_to_finish()
	else:
		for i in units.size():
			_step_player(i, delta)

	_resolve_attacks()
	_resolve_collisions()

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	_update_camera()
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, units, _frame_t0)


## Roda na Thread da unidade i: escreve só em units[i].
func _step_player(i: int, delta: float) -> void:
	units[i].step(delta, WORK_LOAD, PLAY_AREA, map.blockers)


## Dano e morte: mexe em dois objetos ao mesmo tempo, então roda na main
## thread depois da barreira — as tarefas continuam sem lock. Vale pros dois
## lados: player bate no inimigo e o inimigo bate nos players.
func _resolve_attacks() -> void:
	for u in units:
		if u.is_dead():
			# ponytail: respawn em vez de remover — a demo precisa de todos.
			if u.death_time > Player.DEATH_TIME:
				u.hp = u.max_hp
				u.death_time = -1.0
				u.pos = u.spawn_pos
			continue
		if not u.is_attacking() or u.attack_hit:
			continue
		for v in units:
			if v.is_enemy == u.is_enemy or v.is_dead():
				continue
			if u.pos.distance_to(v.pos) < ATTACK_RANGE:
				u.attack_hit = true
				v.hp -= ATTACK_DAMAGE
				if v.hp <= 0.0:
					v.hp = 0.0
					v.death_time = 0.0


## Colisão entre corpos (players, inimigo e ovelhas): mexe em dois objetos ao
## mesmo tempo, então roda na main thread depois da barreira — igual ao dano, as
## tarefas seguem sem lock. Empurra os dois pela metade da sobreposição.
## ponytail: O(n²) com ~22 corpos; virar grid só se entrar muita unidade.
func _resolve_collisions() -> void:
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			var a := bodies[i]
			var b := bodies[j]
			if a.is_dead() or b.is_dead():
				continue
			var d := b.pos - a.pos
			var dist := d.length()
			var overlap := 2.0 * Player.BODY_RADIUS - dist
			if overlap <= 0.0:
				continue
			# Sobrepostos exatamente: qualquer direção serve pra separar.
			var dir := d / dist if dist > 0.01 else Vector2.RIGHT
			a.pos -= dir * overlap * 0.5
			b.pos += dir * overlap * 0.5


## Duração total do trecho de trabalho, do dispatch ao último player terminar.
func _span_usec() -> int:
	var last := _frame_t0
	for p in units:
		last = maxi(last, p.t_end)
	return last - _frame_t0


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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		hud.cycle_detail()
