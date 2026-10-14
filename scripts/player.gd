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
## Aldeão (ver work_think/_step_work): quanto dura cada serviço.
const CHOP_TIME := 3.0
const MINE_TIME := 4.0  ## o mais demorado: é o que faz a fila da mina aparecer
const ROAST_TIME := 5.0
const UNLOAD_TIME := 2.5  ## a carga entra no armazém aos poucos, uma fatia por frame
const DOOR_REACH := 10.0  ## em cima da porta: daqui ele some pra dentro do armazém
const DOOR_GIVE_UP := 6.0  ## com a vaga na mão e sem conseguir chegar na porta: entra assim mesmo
const DOOR_FADE := 0.25  ## segundos pra sumir porta adentro (e pra reaparecer)
const WORK_GIVE_UP := 30.0  ## andando há tanto tempo sem chegar: larga o serviço
const SPAWN_FX_DURATION := 0.5  ## baforada de poeira quando o aldeão volta
const LIGHT_TIME := 2.4  ## batendo a pederneira até a lenha pegar (4 batidas)
const WAIT_HOP_EVERY := 1.7  ## esperando: um pulinho de impaciência a cada tanto
const WAIT_HOP_TIME := 0.28
const STROLL_RADIUS := 150.0  ## aldeão livre não se afasta mais que isso da pracinha
const STROLL_PACE := 0.4  ## fração da velocidade: passeando, não correndo
const LIGHT_REACH := 40.0  ## perto o bastante do canto da fogueira pra acender
const CRANK_REACH := 12.0  ## em cima do ponto da manivela: daqui ele gira o espeto
const SPECIAL_HOLD_THRESHOLD := 0.5  ## segurar ataque por isso troca pro golpe especial
const HIT_FLASH_DURATION := 0.15  ## pisca vermelho ao tomar dano
const HIT_POP_DURATION := 0.2  ## "soco": dá um pulo de escala ao tomar dano
const BLOCK_FX_DURATION := 0.5  ## escudo aparece por cima ao bloquear

## Estamina: todo golpe/cura/flecha consome, e sem carga suficiente a ação nem
## sai — é o que impede segurar o botão e spammar pra sempre (ver poll_input).
const STAMINA_REGEN_RATE := 20.0  ## por segundo, sempre correndo (mesmo atacando)
const ATTACK_STAMINA_COST := 20.0  ## golpe normal / flecha / pulso de cura
const SPECIAL_STAMINA_COST := 40.0  ## golpe especial custa o dobro, como o dano

## Bot ([B] em main.gd): aperta os mesmos "botões" que o humano, via
## _apply_controls() — estamina, especial e guarda valem igual pros dois.
const BOT_FLEE_HP := 0.35  ## abaixo dessa fração da vida, foge pro Curandeiro (se tiver)
const BOT_DANGER_DIST := 300.0  ## goblin mais perto que isso conta como ameaça
const BOT_KITE_DIST := 250.0  ## arqueira: goblin mais perto que isso, ela se afasta
const BOT_GUARD_MARGIN := 30.0  ## folga sobre o alcance do goblin pra erguer a guarda

## Aldeão: `Job` é o serviço, `Phase` em que pé ele está, `Cargo` o que leva nas costas.
enum Job { NONE, WOOD, GOLD, HUNT, COOK, SERVE, FUEL }
enum Phase { GO, QUEUE, WORK, HAUL, UNLOAD, ENTER }
enum Cargo { WOOD, GOLD, MEAT, ROAST, NONE }

var pos: Vector2
var spawn_pos: Vector2  ## volta pra cá ao renascer
var color: Color
var keys: PackedInt32Array  ## [cima, baixo, esquerda, direita, atacar, guarda] (physical keycodes)
var joy_device: int
var speed := SPEED
var is_enemy := false
## Quanto o goblin "enxerga" esta unidade mais longe do que ela está, ao escolher o alvo (chase)
var aggro_bias := 1.0
var is_bot := false  ## bot_think() no lugar de poll_input() — ligado por [B] em main.gd
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
## Posicionando uma construção (main.gd): ataque confirma, 2º botão cancela.
var build_mode := false
var build_confirm := false  ## borda de subida do ataque neste frame
var build_cancel := false  ## borda de subida do 2º botão neste frame
var _build_attack_prev := false
var _build_action2_prev := false
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
## Estado do aldeão: a main thread decide (work_think), a Thread dele executa (_step_work).
var is_worker := false
var village: Village  ## compartilhada por todos os aldeões; null pra quem não é
var job := Job.NONE
var phase := Phase.GO
var work_target := Vector2.ZERO  ## pra onde ir agora
var work_reach := 70.0  ## perto o bastante de work_target pra parar
var work_tree := -1  ## índice em ArenaMap.tree_spots (só Job.WOOD)
var work_prey: Player = null  ## ovelha reservada (HUNT) ou quem vai receber a carne
var work_timer := 0.0
var work_hits := -1  ## golpes de machado/picareta já contados neste serviço; só main.gd mexe (_resolve_work_fx)
var walk_time := 0.0  ## segundos andando nesta fase (ver WORK_GIVE_UP)
var cargo := Cargo.NONE
var cargo_size := 1.0  ## quanto vale a carga inteira (Village.LOAD)
var cargo_left := 0.0  ## quanto dela ainda está nas costas durante a descarga
var delivered := 0.0  ## tudo que ESTE aldeão já descarregou — só a Thread dele escreve
var holds_mine := false  ## está com uma vaga do semáforo da mina
var holds_fire := false  ## está com o espeto da fogueira
var holds_door := false  ## está com uma vaga do armazém (indo pra porta ou lá dentro)
var hide_amount := 0.0  ## 0 = à vista, 1 = dentro do armazém (UnitSprite não desenha)
var meat_texture: Texture2D  ## corrida carregando carne crua
var meat_idle_texture: Texture2D
var roast_texture: Texture2D  ## idem, carregando a assada
var roast_idle_texture: Texture2D
var light_texture: Texture2D  ## acendendo a fogueira com a pederneira (Job.FUEL)
var light_frames := 6
var crank_texture: Texture2D  ## girando a manivela do espeto (Job.COOK)
var crank_frames := 8
## Por Job: a corrida e o parado com a ferramenta do serviço na mão.
var job_run: Array[Texture2D] = []
var job_idle: Array[Texture2D] = []
var fx_cargo := Cargo.NONE  ## o que estava descarregando no frame passado; só main.gd mexe
var spawn_fx_time := -1.0  ## >= 0 = tocando a baforada de quem acabou de voltar
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
## e a animação. Chega perto pelo A* do mapa, contornando o platô até a rampa.
func chase(targets: Array[Player], map: ArenaMap, attack_range: float,
		cooldown: float, delta: float) -> void:
	attack_cd = maxf(attack_cd - delta, 0.0)
	var best: Player = null
	for t in targets:
		if t.is_dead():
			continue
		if best == null or pos.distance_to(t.pos) * t.aggro_bias \
				< pos.distance_to(best.pos) * best.aggro_bias:
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
	input = Vector2.ZERO if in_range else map.nav_dir(pos + FEET, best.pos + FEET)
	# Parado batendo o input zera, então o lado é decidido aqui mesmo.
	facing_right = to_target.x >= 0.0


## Ovelhas: rumo aleatório trocado a cada poucos segundos (main thread,
## junto com o poll dos players). A thread depois só aplica o movimento.
func wander(delta: float) -> void:
	wander_time -= delta
	if wander_time <= 0.0:
		wander_time = randf_range(1.0, 3.0)
		input = Vector2.ZERO if randf() < 0.35 else Vector2.RIGHT.rotated(randf() * TAU)


## Aldeão, na main thread: só escreve `input` e o lado, como o chase().
func work_think(map: ArenaMap) -> void:
	attack_pressed = false
	if job == Job.NONE and not is_dead():
		return  ## livre: quem decide o passo é stroll(), chamado por main.gd
	# Cozinheiro com o espeto: primeiro vai até a manivela (ponto exato, ao lado do fogo)
	if phase == Phase.ENTER and not is_dead():
		var to_door := village.door_spot - pos
		input = to_door.normalized() if holds_door and to_door.length() > DOOR_REACH * 0.4 \
				else Vector2.ZERO
		return
	# (Quem acende o fogo, idem: ponto exato do outro lado, virado pra lenha.)
	if phase == Phase.WORK and (job == Job.COOK or job == Job.FUEL) and not is_dead():
		var to_spot := (village.cook_spot if job == Job.COOK else village.light_spot) - pos
		if to_spot.length() > CRANK_REACH * 0.5:
			input = to_spot.normalized()
		else:
			input = Vector2.ZERO
			facing_right = village.kitchen.x >= pos.x
		return
	if work_prey:
		work_target = work_prey.pos  # alvo que anda: ovelha ou player
	var to_target := work_target - pos
	var walking := job != Job.NONE and (phase == Phase.GO or phase == Phase.HAUL)
	if is_dead() or not walking or to_target.length() < work_reach:
		input = Vector2.ZERO
		# Parado o input zera, então o lado é decidido aqui — igual ao chase().
		if job != Job.NONE and absf(to_target.x) > 1.0:
			facing_right = to_target.x >= 0.0
		return
	input = map.nav_dir(pos + FEET, work_target + FEET)


## Aldeão livre: passeia devagar perto do castelo.
func stroll(home: Vector2, delta: float) -> void:
	wander_time -= delta
	var away := pos - home
	if away.length() > STROLL_RADIUS:
		input = -away.normalized() * STROLL_PACE
		wander_time = 1.0
	elif wander_time <= 0.0:
		wander_time = randf_range(1.2, 3.5)
		input = Vector2.ZERO if randf() < 0.55 \
				else Vector2.RIGHT.rotated(randf() * TAU) * STROLL_PACE


## Novo destino e nova fase de uma vez.
func head_to(target: Vector2, reach: float, new_phase: Phase) -> void:
	work_target = target
	work_reach = reach
	phase = new_phase
	walk_time = 0.0


func load_cargo(kind: Cargo) -> void:
	cargo = kind
	cargo_size = Village.LOAD[kind] if kind < Village.LOAD.size() else 1.0
	cargo_left = cargo_size
	carrying = true
	match kind:
		Cargo.WOOD:
			loaded_texture = wood_texture
			loaded_idle_texture = wood_idle_texture
		Cargo.GOLD:
			loaded_texture = gold_texture
			loaded_idle_texture = gold_idle_texture
		Cargo.ROAST:
			loaded_texture = roast_texture
			loaded_idle_texture = roast_idle_texture
		_:
			loaded_texture = meat_texture
			loaded_idle_texture = meat_idle_texture


## Larga tudo: serviço, carga e — o que importa — as vagas de semáforo que estiver segurando.
func drop_work() -> void:
	_release_slots()
	job = Job.NONE
	phase = Phase.GO
	cargo = Cargo.NONE
	cargo_left = 0.0
	carrying = false
	work_prey = null
	work_tree = -1
	walk_time = 0.0


func _release_slots() -> void:
	if village != null:
		if holds_mine:
			village.leave_slot(Village.Slot.MINE)
		if holds_fire:
			village.leave_slot(Village.Slot.FIRE)
		if holds_door:
			village.leave_slot(Village.Slot.DEPOT)
	holds_mine = false
	holds_fire = false
	holds_door = false


## Tenta ocupar um lugar com vagas.
func _take_slot(slot: int) -> bool:
	return village.try_enter_slot(slot)


## Quão rápido o serviço anda.
func _work_rate() -> float:
	if job == Job.GOLD:
		return village.mine_rate
	if job == Job.COOK:
		return village.fire_rate
	return 1.0


## Faixa do aldeão (UnitSprite): o que ele está fazendo agora.
func work_label() -> String:
	if phase == Phase.QUEUE and not (holds_mine or holds_fire):
		return "FILA"
	if phase == Phase.ENTER and not holds_door:
		return "FILA"
	match job:
		Job.WOOD:
			return "LENHA"
		Job.GOLD:
			return "OURO"
		Job.HUNT:
			return "CARNE" if carrying else "CAÇA"
		Job.COOK:
			return "ASSA"
		Job.SERVE:
			return "ASSADA"
		Job.FUEL:
			return "FOGO"
	return "LIVRE"


## Main thread only: a classe Input não é thread-safe. Só lê o teclado/controle
## — o que os botões fazem é _apply_controls(), o mesmo que o bot usa.
func poll_input(delta: float) -> void:
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
	var attack := (Input.is_physical_key_pressed(keys[4])
			or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_A))
	var action2 := Input.is_physical_key_pressed(keys[5]) or Input.is_joy_button_pressed(joy_device, JOY_BUTTON_B)
	if build_mode:
		# Posicionando construção: os dois botões viram confirmar/cancelar
		# (borda de subida) e nunca chegam ao golpe/coleta — o resto (andar)
		# segue igual, que é o que move o fantasma.
		build_confirm = attack and not _build_attack_prev
		build_cancel = action2 and not _build_action2_prev
		_build_attack_prev = attack
		_build_action2_prev = action2
		attack = false
		action2 = false
	_apply_controls(kb, joy, attack, action2, delta)


## Entra/sai do modo posicionamento (main.gd). Os "anteriores" começam
## apertados: a tecla que fechou o menu ainda pode estar no dedo, e sem isso
## ela confirmaria a obra no frame seguinte.
func set_build_mode(on: bool) -> void:
	build_mode = on
	build_confirm = false
	build_cancel = false
	_build_attack_prev = true
	_build_action2_prev = true


## Controle virtual: decide os mesmos 3 "botões" (direção, ataque, 2º botão)
## que o humano apertaria, a partir de quem está onde — main thread, antes do
## dispatch, como o chase() dos goblins. `others` são todas as unidades (os
## goblins saem dali), `allies` os players. Classe muda só alvo/distância/guarda.
## Chegar perto usa o A* do mapa (contorna platô); se afastar é em linha reta.
## ponytail: sem coleta nem carne no chão; o Camponês bot só luta.
func bot_think(others: Array[Player], allies: Array[Player], map: ArenaMap,
		shot_range: float, delta: float) -> void:
	var move := Vector2.ZERO
	var attack := false
	var guard := false
	var face: Player = null  ## pra quem olhar quando parado
	var threat := _nearest_foe(others)
	var to_threat := threat.pos - pos if threat else Vector2.ZERO
	var dist := to_threat.length()
	var healer := _nearest_monk(allies)
	if is_dead():
		pass
	elif threat and healer and hp < max_hp * BOT_FLEE_HP and dist < BOT_DANGER_DIST:
		# Recua pro Curandeiro: a aura/cura dele é quem recupera. Sem ele não
		# tem o que recuperar a vida, então recuar só virava um vaivém — luta.
		move = -to_threat.normalized()
		if pos.distance_to(healer.pos) > 1.0:
			move = (move + (healer.pos - pos).normalized()).normalized()
	elif is_monk:
		face = _most_wounded(allies)
		if face == null:
			face = _nearest_ally(allies)
		if face:
			var to_friend := face.pos - pos
			if to_friend.length() > attack_range * 0.8:
				move = map.nav_dir(pos + FEET, face.pos + FEET)
			attack = face.hp < face.max_hp and to_friend.length() < attack_range
	elif threat:
		face = threat
		if is_archer:
			if dist < BOT_KITE_DIST:
				move = -to_threat.normalized()
			elif dist > shot_range * 0.9:
				move = map.nav_dir(pos + FEET, threat.pos + FEET)
			else:
				attack = true
		else:
			if dist > attack_range * 0.8:
				move = map.nav_dir(pos + FEET, threat.pos + FEET)
			else:
				attack = true
			guard = (guard_texture != null and threat.is_attacking() and not is_attacking()
					and dist < threat.attack_range + BOT_GUARD_MARGIN)
	_apply_controls(move, Vector2.ZERO, attack, guard, delta)
	# Parado o input zera, então o lado é decidido aqui — igual ao chase().
	if face and input == Vector2.ZERO and face != self:
		facing_right = face.pos.x >= pos.x


func _nearest_foe(others: Array[Player]) -> Player:
	var best: Player = null
	for u in others:
		if u.is_enemy == is_enemy or u.is_dead():
			continue
		if best == null or pos.distance_squared_to(u.pos) < pos.distance_squared_to(best.pos):
			best = u
	return best


func _nearest_ally(allies: Array[Player]) -> Player:
	var best: Player = null
	for a in allies:
		if a == self or a.is_dead():
			continue
		if best == null or pos.distance_squared_to(a.pos) < pos.distance_squared_to(best.pos):
			best = a
	return best


func _nearest_monk(allies: Array[Player]) -> Player:
	var best: Player = null
	for a in allies:
		if a == self or a.is_dead() or not a.is_monk:
			continue
		if best == null or pos.distance_squared_to(a.pos) < pos.distance_squared_to(best.pos):
			best = a
	return best


## Menor fração de vida entre os vivos feridos (pode ser o próprio Curandeiro).
func _most_wounded(allies: Array[Player]) -> Player:
	var best: Player = null
	for a in allies:
		if a.is_dead() or a.hp >= a.max_hp:
			continue
		if best == null or a.hp / a.max_hp < best.hp / best.max_hp:
			best = a
	return best


## O que os botões fazem — igual pra humano (poll_input) e bot (bot_think).
## `kb` e `joy` chegam separados porque a mira troca de alvo só pelo teclado.
## `delta` só serve pra contar attack_hold_time (a skill de segurar o ataque).
func _apply_controls(kb: Vector2, joy: Vector2, attack: bool, action2: bool,
		delta: float) -> void:
	# 2º botão: vira Guarda (segurar), Coleta (apertar) ou Mira (segurar,
	# arqueiro) — cada um só reage ao que a classe atual suporta.
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

	attack_pressed = attack
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
		if is_worker:
			drop_work()  ## morreu: devolve a vaga que estivesse segurando
			hide_amount = 0.0
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
	if spawn_fx_time >= 0.0:
		spawn_fx_time += delta
		if spawn_fx_time >= SPAWN_FX_DURATION:
			spawn_fx_time = -1.0
	if is_worker:
		_step_work(delta)
		# Dentro do armazém = descarregando com a vaga da porta.
		var inside := phase == Phase.UNLOAD and holds_door
		hide_amount = clampf(hide_amount + (delta if inside else -delta) / DOOR_FADE, 0.0, 1.0)
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


## Serviço do aldeão, na Thread dele.
func _step_work(delta: float) -> void:
	if job == Job.NONE:
		return
	var arrived := pos.distance_to(work_target) < work_reach
	match phase:
		Phase.GO:
			if not arrived:
				_walk(delta)
			elif job == Job.WOOD:
				_start_work(CHOP_TIME)
			elif job == Job.GOLD or job == Job.COOK:
				phase = Phase.QUEUE
			elif job == Job.FUEL:
				# Chegou no armazém: tira 1 lenha (checar e tirar no mesmo lock) e leva pra fogueira.
				if village.take(Village.Res.WOOD, 1.0):
					load_cargo(Cargo.WOOD)
					head_to(village.light_spot, LIGHT_REACH, Phase.HAUL)
				else:
					drop_work()  ## gastaram a lenha antes
			elif job == Job.SERVE:
				# Consumidor: só leva se ainda tiver assada na mesa.
				if village.take_roast():
					load_cargo(Cargo.ROAST)
					phase = Phase.HAUL  # main.gd aponta pra quem está ferido
				else:
					drop_work()
		Phase.QUEUE:
			if job == Job.GOLD:
				if _take_slot(Village.Slot.MINE):
					holds_mine = true
					_start_work(MINE_TIME)
			elif holds_fire or _take_slot(Village.Slot.FIRE):
				if not holds_fire:
					holds_fire = true
				if village.take(Village.Res.MEAT, 1.0):
					_start_work(ROAST_TIME)
				else:
					drop_work()  ## a carne que vinha buscar já foi; devolve o espeto
		Phase.WORK:
			# Sem fogo a carne não assa.
			if job == Job.COOK and not village.fire_lit():
				return
			work_timer -= delta * _work_rate()
			if work_timer > 0.0:
				return
			match job:
				Job.WOOD:
					load_cargo(Cargo.WOOD)
					head_to(village.depot, Village.SITE_REACH, Phase.HAUL)
				Job.GOLD:
					_release_slots()  ## saiu da mina: a vaga volta pro semáforo
					load_cargo(Cargo.GOLD)
					head_to(village.depot, Village.SITE_REACH, Phase.HAUL)
				Job.COOK:
					village.put_roast()
					drop_work()
				Job.FUEL:
					village.add_fuel()
					drop_work()
		Phase.HAUL:
			if cargo == Cargo.ROAST or work_prey != null:
				return  ## entrega em mãos: main.gd resolve (_resolve_deliveries)
			if job == Job.FUEL:
				if arrived:
					# A lenha vai pra fogueira: sai das costas e ele se abaixa pra acender.
					cargo = Cargo.NONE
					carrying = false
					_start_work(LIGHT_TIME)
				else:
					_walk(delta)
				return
			if arrived:
				# Carne crua fica na cozinha, ao ar livre; lenha e ouro entram no armazém.
				phase = Phase.UNLOAD if cargo == Cargo.MEAT else Phase.ENTER
				walk_time = 0.0
			else:
				_walk(delta)
		Phase.ENTER:
			# A porta do armazém: semáforo contador, DEPOT_SLOTS dentro por vez.
			if not holds_door:
				if not _take_slot(Village.Slot.DEPOT):
					return
				holds_door = true
				walk_time = 0.0
			# Com a vaga, main.gd o leva até a porta (work_think); chegou, entra.
			walk_time += delta
			if pos.distance_to(village.door_spot) < DOOR_REACH or walk_time > DOOR_GIVE_UP:
				phase = Phase.UNLOAD
		Phase.UNLOAD:
			# Uma fatia por frame: é o que põe dois aldeões escrevendo no armazém no mesmo frame.
			var amount := minf(cargo_left, cargo_size * delta / UNLOAD_TIME)
			village.deposit(cargo, amount)
			cargo_left -= amount
			delivered += amount
			if cargo_left <= 0.0:
				drop_work()


func _start_work(seconds: float) -> void:
	phase = Phase.WORK
	work_timer = seconds
	walk_time = 0.0


## Rede de segurança: destino que não dá pra alcançar.
func _walk(delta: float) -> void:
	walk_time += delta
	if walk_time > WORK_GIVE_UP:
		drop_work()


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


## Lá dentro do armazém: não esbarra em ninguém nem apanha.
func is_hidden() -> bool:
	return hide_amount > 0.5


## Aldeão no meio de uma atividade — trabalhando, entrando no armazém ou lá dentro.
func is_busy() -> bool:
	if not is_worker or job == Job.NONE:
		return false
	return phase == Phase.WORK or phase == Phase.UNLOAD or (phase == Phase.ENTER and holds_door)


## Aldeão no meio do serviço: machado, picareta, pedra na lenha ou a manivela do espeto.
func is_working() -> bool:
	if not is_worker or job == Job.NONE or phase != Phase.WORK:
		return false
	if job == Job.COOK:
		return village.fire_lit() and pos.distance_to(village.cook_spot) < CRANK_REACH
	if job == Job.FUEL:
		return pos.distance_to(village.light_spot) < CRANK_REACH
	return true


## O que o aldeão está esperando, pro balão em cima da cabeça (linha da Wait_Bubble.png)
func waiting_for() -> int:
	if not is_worker or is_dead() or job == Job.NONE:
		return -1
	if phase == Phase.QUEUE and not (holds_mine or holds_fire):
		return 0 if job == Job.GOLD else 1
	if phase == Phase.ENTER and not holds_door:
		return 3
	if job == Job.COOK and phase == Phase.WORK and not village.fire_lit():
		return 2
	return -1


## Deslocamento vertical do corpo de quem espera.
func wait_hop() -> float:
	if waiting_for() < 0:
		return 0.0
	var t := fmod(anim_time + spawn_pos.x * 0.013, WAIT_HOP_EVERY)
	return -5.0 * sin(t / WAIT_HOP_TIME * PI) if t < WAIT_HOP_TIME else 0.0


func _work_texture() -> Texture2D:
	match job:
		Job.WOOD:
			return axe_texture
		Job.GOLD:
			return pickaxe_texture
		Job.FUEL:
			return light_texture
	return crank_texture


func _work_frames() -> int:
	match job:
		Job.WOOD:
			return axe_frames
		Job.GOLD:
			return pickaxe_frames
		Job.FUEL:
			return light_frames
	return crank_frames


func get_current_texture() -> Texture2D:
	if is_guarding and guard_texture:
		return guard_texture
	if is_harvesting():
		return axe_texture if harvest_kind == "wood" else pickaxe_texture
	if is_working():
		return _work_texture()
	if is_attacking():
		if is_special and special_texture:
			return special_texture
		if attack_texture:
			return attack_texture
	if not is_running():
		if carrying and loaded_idle_texture:
			return loaded_idle_texture
		return _job_texture(job_idle, idle_texture)
	if carrying and loaded_texture:
		return loaded_texture
	return _job_texture(job_run, run_texture)


## A textura do serviço atual, se a unidade tiver uma (ver job_run/job_idle).
func _job_texture(by_job: Array[Texture2D], fallback: Texture2D) -> Texture2D:
	if job < by_job.size() and by_job[job] != null:
		return by_job[job]
	return fallback


func get_current_frame() -> int:
	if is_guarding and guard_texture:
		return int(anim_time * anim_fps) % guard_frames
	if is_harvesting():
		var hframes := axe_frames if harvest_kind == "wood" else pickaxe_frames
		return mini(int(harvest_time * anim_fps), hframes - 1)
	if is_working():
		# Em laço enquanto durar o serviço, não uma vez só como o golpe.
		return int(anim_time * anim_fps) % _work_frames()
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
