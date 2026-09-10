class_name Player
extends RefCounted

## Um player = uma Thread por frame (ver main.gd).
## Input é lido na main thread; a tarefa só escreve nos campos deste objeto,
## que é exclusivo daquele índice -> sem lock.

const SPEED := 260.0
const BODY_RADIUS := 16.0  ## meia largura da unidade, pra afastar dos blockers
const FEET := Vector2(0, 26)  ## a colisão é nos pés, não no meio do sprite
const DEADZONE := 0.2
const DEATH_TIME := 1.6  ## tombar + sumir (dá tempo do efeito de morte tocar)
const HEAL_FX_DURATION := 1.1  ## dura o efeito de cura (Heal_Effect, 11 quadros a 10fps)
const WORK_PAUSE := 2.2  ## pawn: segundos parado no serviço e na entrega
const WORK_REACH := 60.0  ## perto o bastante do toco/da base pra parar
const SPECIAL_HOLD_THRESHOLD := 0.5  ## segurar ataque por isso troca pro golpe especial
const HIT_FLASH_DURATION := 0.15  ## pisca vermelho ao tomar dano
const HIT_POP_DURATION := 0.2  ## "soco": dá um pulo de escala ao tomar dano
const BLOCK_FX_DURATION := 0.5  ## escudo aparece por cima ao bloquear

## Estamina: todo golpe/cura/flecha consome, e sem carga suficiente a ação nem
## sai — é o que impede segurar o botão e spammar pra sempre (ver poll_input).
const STAMINA_REGEN_RATE := 20.0  ## por segundo, sempre correndo (mesmo atacando)
const ATTACK_STAMINA_COST := 20.0  ## golpe normal / flecha / pulso de cura
const SPECIAL_STAMINA_COST := 40.0  ## golpe especial custa o dobro, como o dano

var pos: Vector2
var spawn_pos: Vector2  ## volta pra cá ao renascer
var color: Color
var keys: PackedInt32Array  ## [cima, baixo, esquerda, direita, atacar, guarda] (physical keycodes)
var joy_device: int
var speed := SPEED
var is_enemy := false
var is_archer := false  ## dispara Arrow de verdade (ver main.gd _fire_arrow)
var is_sheep := false  ## morte mostra baforada em vez de caveira (ver UnitSprite)
var is_monk := false  ## "ataque" cura o aliado mais perto em vez de bater (ver main.gd)
var is_thrower := false  ## inimigo à distância: "ataque" arremessa Dynamite em vez de bater (ver main.gd)
var is_bomber := false  ## chega perto e explode em vez de bater (ver main.gd _resolve_bomber_blasts)
var bomber_fuse := 0.6  ## segundos entre "atacar" (chase()) e o estouro (só is_bomber)
var fuse_time := -1.0  ## >= 0 = pavio contando; ver _step_fuse() e Player.fuse_done()
var input := Vector2.ZERO  ## escrito na main thread, lido na thread do player
var heat := 0.0  ## resultado do trabalho pesado, só pra provar que rodou
var max_hp := 100.0
var hp := 100.0  ## dano em main.gd (_resolve_attacks), depois da barreira
var t_start := 0  ## usec, início do step -> alimenta o gráfico
var t_end := 0

var idle_texture: Texture2D
var run_texture: Texture2D
var attack_texture: Texture2D
var special_texture: Texture2D  ## golpe "carregado" (segurar) — null = sem especial
var guard_texture: Texture2D  ## null = essa unidade não tem bloqueio
var idle_frames := 8
var run_frames := 6
var attack_frames := 4
var special_frames := 4
var guard_frames := 6
## Ataque: começa no poll (main thread) e roda até o ciclo terminar.
var attack_pressed := false
var attack_time := -1.0  ## < 0 = não está atacando
var is_special := false  ## o golpe em andamento é o especial (ver poll_input)
var is_guarding := false  ## segurando a tecla de guarda (ver poll_input)
## Modo mira do arqueiro: 2º botão segurado trava o movimento e libera
## cima/baixo pra trocar de alvo (aim_cycle) em vez de andar. main.gd lê
## is_aiming/aim_cycle e escreve aim_lock (o Player não sabe quem mais existe).
var is_aiming := false
var aim_cycle := 0  ## -1 = anterior, 0 = nada, 1 = próximo — só neste frame
var aim_lock: Player = null  ## alvo travado, escrito por main.gd
var _aim_up_prev := false
var _aim_down_prev := false
## Coleta do Pawn jogável (P3): 2º botão (keys[5]) perto de árvore/ouro/base.
## Decidido em main.gd (_try_harvest), que sabe onde as coisas estão no mapa.
var axe_texture: Texture2D  ## null = essa unidade não coleta
var pickaxe_texture: Texture2D
var wood_texture: Texture2D  ## corrida carregando madeira
var gold_texture: Texture2D  ## corrida carregando ouro
var wood_idle_texture: Texture2D  ## parado carregando madeira
var gold_idle_texture: Texture2D  ## parado carregando ouro
var axe_frames := 6
var pickaxe_frames := 6
var harvest_time := -1.0  ## < 0 = não está coletando
var harvest_kind := ""  ## "wood" ou "gold": qual ferramenta toca e qual carga rende
var harvest_triggered := false  ## borda de subida do 2º botão nesse frame
var wood := 0
var gold := 0
var _action2_prev := false  ## detecta a borda de subida do 2º botão (guarda/coleta)
var attack_hit := false  ## já causou dano neste golpe (1 acerto por ciclo)
var attack_cd := 0.0  ## inimigo: segundos até poder bater de novo (só chase())
var attack_cooldown := 1.2  ## inimigo: respiro entre golpes — varia por tipo (ver EnemyTypes)
var death_time := -1.0  ## < 0 = vivo; senão, segundos desde que morreu
var heal_fx_time := -1.0  ## >= 0 = tocando o efeito de cura (ver main.gd _resolve_meat_pickup)
var hit_flash_time := -1.0  ## >= 0 = piscando vermelho (acabou de tomar dano)
var hit_pop_time := -1.0  ## >= 0 = no meio do "soco" de escala do impacto
var block_fx_time := -1.0  ## >= 0 = mostrando o escudo de bloqueio bem-sucedido
var attack_range := 90.0  ## alcance de ataque/cura corpo a corpo — Lanceiro é maior
var attack_damage := 25.0  ## dano do golpe normal — Lanceiro é menor (compensa alcance/velocidade)
var special_damage_mult := 2.0  ## multiplicador do golpe especial sobre attack_damage
var attack_hold_time := 0.0  ## segurando a tecla de ataque; zera ao soltar
var is_charging := false  ## segurou além do 1º golpe: parado carregando o especial (ver poll_input)
var max_stamina := 100.0
var stamina := 100.0  ## consumida por golpe/cura/flecha, regenera sozinha (ver poll_input)
var frame_size := Vector2(192, 192)
## Sprite em grade (pack Update 010): 0 = tira de 1 linha, comportamento de
## sempre; > 0 = número de colunas, e idle_row/run_row/attack_row dizem qual
## linha da grade cada animação usa (ver EnemyTypes e UnitSprite._draw_body).
var sheet_cols := 0
var idle_row := 0
var run_row := 0
var attack_row := 0
var anim_fps := 10.0
var anim_time := 0.0
var facing_right := true
var wander_time := 0.0  ## ovelhas: segundos até trocar de rumo
## Pawn: vai do serviço à base e volta, carregando a carga na ida de volta.
var work_site := Vector2.ZERO
var work_home := Vector2.ZERO
var work_timer := 0.0
var carrying := false
var loaded_texture: Texture2D  ## sprite de corrida com a carga nas costas
var loaded_idle_texture: Texture2D  ## sprite parado com a carga (null = usa idle normal)
var ribbon_y := 68.0  ## linha da faixa em SmallRibbons.png (cor do badge)


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
	special_tex: Texture2D = null,
	s_frames := 4,
) -> void:
	pos = start_pos
	spawn_pos = start_pos
	color = col
	keys = PackedInt32Array(key_list)
	joy_device = device
	idle_texture = idle_tex
	run_texture = run_tex
	attack_texture = attack_tex
	idle_frames = i_frames
	run_frames = r_frames
	attack_frames = a_frames
	special_texture = special_tex
	special_frames = s_frames


## IA do inimigo: roda na main thread junto com o poll, só escreve `input` e
## `attack_pressed`. Persegue o alvo vivo mais próximo e, chegando no alcance,
## para e bate, respeitando o cooldown — a thread depois só aplica o movimento
## e a animação.
func chase(targets: Array[Player], attack_range: float, cooldown: float,
		delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	var best: Player = null
	for t in targets:
		if t.is_dead():
			continue
		if best == null or pos.distance_squared_to(t.pos) < pos.distance_squared_to(best.pos):
			best = t
	if best == null:
		input = Vector2.ZERO
		attack_pressed = false
		return
	var to_target := best.pos - pos
	var in_range := to_target.length() < attack_range
	attack_pressed = in_range and attack_cd <= 0.0 and not is_attacking()
	if attack_pressed:
		attack_cd = cooldown
		# Início do ataque decidido aqui, igual poll_input() faz pro player
		# desde o rework de estamina/golpe especial — _step_attack() (na
		# Thread) só avança o ciclo até o fim, não inicia mais sozinho.
		attack_time = 0.0
		attack_hit = false
		if is_bomber:
			fuse_time = 0.0  ## acendeu: main.gd._resolve_bomber_blasts() cuida do resto
	input = Vector2.ZERO if in_range else to_target.normalized()
	# Parado batendo o input zera, então o lado é decidido aqui mesmo.
	facing_right = to_target.x >= 0.0


## Ovelhas: rumo aleatório trocado a cada poucos segundos (main thread,
## junto com o poll dos players). A thread depois só aplica o movimento.
func wander(delta: float) -> void:
	wander_time -= delta
	if wander_time <= 0.0:
		wander_time = randf_range(1.0, 3.0)
		input = Vector2.ZERO if randf() < 0.35 else Vector2.RIGHT.rotated(randf() * TAU)


## Pawn: anda até o serviço, martela um tempo, leva a carga pra base e volta.
## Roda na main thread junto com o poll e só escreve `input`/`attack_pressed`
## — a animação de trabalho é a de ataque, que já existe.
func haul(delta: float) -> void:
	if work_timer > 0.0:
		work_timer -= delta
		input = Vector2.ZERO
		attack_pressed = not carrying  # machado no toco; na base só entrega
		if work_timer <= 0.0:
			carrying = not carrying
		return
	attack_pressed = false
	var to_target := (work_home if carrying else work_site) - pos
	if to_target.length() < WORK_REACH:
		work_timer = WORK_PAUSE
		input = Vector2.ZERO
		return
	input = to_target.normalized()
	facing_right = to_target.x >= 0.0


## Main thread only: a classe Input não é thread-safe. `delta` só serve pra
## contar attack_hold_time (a skill de segurar o ataque — ver main.gd).
func poll_input(delta: float) -> void:
	# 2º botão: vira Guarda (segurar), Coleta (apertar) ou Mira (segurar,
	# arqueiro) — cada um só reage ao que a classe atual suporta.
	var action2 := Input.is_physical_key_pressed(keys[5]) or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_B)
	var action2_started := action2 and not _action2_prev
	_action2_prev = action2
	harvest_triggered = (action2_started and axe_texture != null
			and not is_attacking() and not is_harvesting())

	# Guarda trava tudo: parado, sem atacar, com o escudo/braço erguido —
	# quem não tem guard_texture nunca entra aqui.
	is_guarding = guard_texture != null and action2 and not is_attacking()
	if is_guarding:
		input = Vector2.ZERO
		attack_pressed = false
		attack_hold_time = 0.0
		return

	is_aiming = is_archer and action2
	if not is_aiming:
		aim_lock = null  ## solta o alvo travado ao soltar o botão
		_aim_up_prev = false
		_aim_down_prev = false

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

	if is_aiming:
		# Parado no lugar: cima/baixo troca de alvo em vez de andar (um passo
		# por toque, não repete enquanto segura).
		input = Vector2.ZERO
		aim_cycle = 0
		var up := kb.y < -0.5
		var down := kb.y > 0.5
		if up and not _aim_up_prev:
			aim_cycle = -1
		elif down and not _aim_down_prev:
			aim_cycle = 1
		_aim_up_prev = up
		_aim_down_prev = down
	else:
		input = (kb + joy).limit_length(1.0)
	if is_charging:
		input = Vector2.ZERO  ## carregando o golpe especial: parado, sem escapatória de graça

	attack_pressed = (Input.is_physical_key_pressed(keys[4])
			or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_A))
	attack_hold_time = attack_hold_time + delta if attack_pressed else 0.0
	stamina = minf(stamina + STAMINA_REGEN_RATE * delta, max_stamina)  ## regenera sempre, mesmo atacando

	# Início do ataque decidido aqui (main thread), não na Thread do step():
	# main.gd precisa detectar "começou agora" no mesmo frame pra disparar a
	# flecha (ver _fire_arrow em main.gd).
	#
	# Toque = golpe normal na hora (responsivo). Segurar não repete golpes
	# normais: depois do primeiro, entra em carga (parado) até soltar ou
	# completar SPECIAL_HOLD_THRESHOLD, aí sim sai o especial — sem isso,
	# segurar virava uns 2 golpes normais de graça antes do especial "pegar".
	if not attack_pressed:
		is_charging = false
	elif not is_attacking():
		if is_charging:
			if attack_hold_time >= SPECIAL_HOLD_THRESHOLD and stamina >= SPECIAL_STAMINA_COST:
				attack_time = 0.0
				attack_hit = false
				is_special = true
				is_charging = false
				attack_hold_time = 0.0
				stamina -= SPECIAL_STAMINA_COST
		elif special_texture != null and attack_hold_time > delta * 1.5:
			# Ainda segurando depois do golpe (livre) inicial acabar: carrega
			# em vez de bater de novo. `attack_hold_time` maior que um frame
			# só é possível se já passamos por pelo menos um ciclo atacando.
			is_charging = true
		elif stamina >= ATTACK_STAMINA_COST:
			attack_time = 0.0
			attack_hit = false  ## novo golpe, novo direito a acertar (ver _resolve_attacks em main.gd)
			is_special = false
			stamina -= ATTACK_STAMINA_COST


## Roda na Thread do player. `area` é a faixa andável (ArenaMap.PLAY_AREA):
## fora dela é beirada de ilha ou água.
func step(delta: float, work_load: int, area: Rect2,
		blockers: Array[Rect2] = []) -> void:
	t_start = Time.get_ticks_usec()
	var acc := 0.0
	for k in work_load:
		acc += sqrt(float(k) + pos.x)
	heat = fmod(acc, 1.0)
	if is_dead():
		death_time += delta
		t_end = Time.get_ticks_usec()
		return
	pos = (pos + input * speed * delta).clamp(area.position, area.end)
	_push_out(blockers)
	anim_time += delta
	_step_attack(delta)
	_step_harvest(delta)
	_step_heal_fx(delta)
	_step_hit_flash(delta)
	_step_hit_pop(delta)
	_step_block_fx(delta)
	_step_fuse(delta)
	if input.x > 0.05:
		facing_right = true
	elif input.x < -0.05:
		facing_right = false
	t_end = Time.get_ticks_usec()


## Tira a unidade de dentro dos blockers pelo lado mais perto — sem física:
## o cenário é só uma lista de Rect2 imutável, lida por todas as threads.
func _push_out(blockers: Array[Rect2]) -> void:
	var feet := pos + FEET
	for r in blockers:
		var box := r.grow(BODY_RADIUS)
		if not box.has_point(feet):
			continue
		var dx := box.position.x - feet.x if feet.x - box.position.x < box.end.x - feet.x \
				else box.end.x - feet.x
		var dy := box.position.y - feet.y if feet.y - box.position.y < box.end.y - feet.y \
				else box.end.y - feet.y
		if absf(dx) < absf(dy):
			pos.x += dx
			feet.x += dx
		else:
			pos.y += dy
			feet.y += dy


## Um ataque não pode ser cancelado: só reinicia depois do ciclo acabar.
## (O início do ataque é decidido em poll_input(), não aqui — ver comentário lá.)
func _step_attack(delta: float) -> void:
	if is_attacking():
		attack_time += delta
		var frames := special_frames if is_special and special_texture else attack_frames
		if attack_time >= frames / anim_fps:
			attack_time = -1.0


## Toca o machado/picareta até o fim e então passa a carregar a carga (a
## entrega em si é decidida em main.gd — _try_harvest — que zera carrying).
func _step_harvest(delta: float) -> void:
	if harvest_time < 0.0:
		return
	harvest_time += delta
	var frames := axe_frames if harvest_kind == "wood" else pickaxe_frames
	if harvest_time >= frames / anim_fps:
		harvest_time = -1.0
		carrying = true
		loaded_texture = wood_texture if harvest_kind == "wood" else gold_texture
		loaded_idle_texture = wood_idle_texture if harvest_kind == "wood" else gold_idle_texture


func is_harvesting() -> bool:
	return harvest_time >= 0.0


## Conta o efeito de cura até HEAL_FX_DURATION e desliga sozinho — main.gd só
## precisa ligar (heal_fx_time = 0.0) quando o player pega a carne.
func _step_heal_fx(delta: float) -> void:
	if heal_fx_time < 0.0:
		return
	heal_fx_time += delta
	if heal_fx_time >= HEAL_FX_DURATION:
		heal_fx_time = -1.0


func is_healing() -> bool:
	return heal_fx_time >= 0.0


## Conta o flash de dano até HIT_FLASH_DURATION e desliga sozinho — main.gd só
## precisa ligar (hit_flash_time = 0.0) quando o hp cai.
func _step_hit_flash(delta: float) -> void:
	if hit_flash_time < 0.0:
		return
	hit_flash_time += delta
	if hit_flash_time >= HIT_FLASH_DURATION:
		hit_flash_time = -1.0


func is_flashing() -> bool:
	return hit_flash_time >= 0.0


func _step_hit_pop(delta: float) -> void:
	if hit_pop_time < 0.0:
		return
	hit_pop_time += delta
	if hit_pop_time >= HIT_POP_DURATION:
		hit_pop_time = -1.0


## 0 no início/fim, pico no meio — multiplicador de escala extra pro "soco".
func pop_scale() -> float:
	if hit_pop_time < 0.0:
		return 1.0
	var t := hit_pop_time / HIT_POP_DURATION
	return 1.0 + 0.25 * 4.0 * t * (1.0 - t)


func _step_block_fx(delta: float) -> void:
	if block_fx_time < 0.0:
		return
	block_fx_time += delta
	if block_fx_time >= BLOCK_FX_DURATION:
		block_fx_time = -1.0


## Só conta — quem decide o que fazer quando o pavio termina é main.gd
## (_resolve_bomber_blasts, depois da barreira: mexe no bomber E nos players).
func _step_fuse(delta: float) -> void:
	if fuse_time < 0.0:
		return
	fuse_time += delta


## true na primeira checagem depois que o pavio passa de bomber_fuse, false
## depois disso (consome o pavio) — mesmo padrão do Dynamite.should_blast().
func fuse_done() -> bool:
	if fuse_time < 0.0 or fuse_time < bomber_fuse:
		return false
	fuse_time = -1.0
	return true


func is_blocking_fx() -> bool:
	return block_fx_time >= 0.0


func is_dead() -> bool:
	return death_time >= 0.0


func is_attacking() -> bool:
	return attack_time >= 0.0


func is_running() -> bool:
	return input.length_squared() > 0.01


func get_current_texture() -> Texture2D:
	if is_guarding and guard_texture:
		return guard_texture
	if is_harvesting():
		return axe_texture if harvest_kind == "wood" else pickaxe_texture
	if is_attacking():
		if is_special and special_texture:
			return special_texture
		if attack_texture:
			return attack_texture
	if not is_running():
		return loaded_idle_texture if carrying and loaded_idle_texture else idle_texture
	return loaded_texture if carrying and loaded_texture else run_texture


func get_current_frame() -> int:
	if is_guarding and guard_texture:
		return int(anim_time * anim_fps) % guard_frames
	if is_harvesting():
		var hframes := axe_frames if harvest_kind == "wood" else pickaxe_frames
		return mini(int(harvest_time * anim_fps), hframes - 1)
	if is_attacking():
		var frames := special_frames if is_special and special_texture else attack_frames
		if (special_texture if is_special else attack_texture):
			return mini(int(attack_time * anim_fps), frames - 1)
	var total := run_frames if is_running() else idle_frames
	if total <= 0:
		return 0
	return int(anim_time * anim_fps) % total


## Linha da grade pra animação atual — só importa quando sheet_cols > 0
## (goblins do Update 010); numa tira de 1 linha (sheet_cols == 0) o
## UnitSprite ignora isto e desenha direto na linha 0.
func get_current_row() -> int:
	if is_attacking():
		return attack_row
	if is_running():
		return run_row
	return idle_row
