extends Node2D

## Arena: cada player faz um "trabalho pesado" por frame.
## Modo serial -> tudo na main thread, as tarefas saem em fila.
## Modo threads -> 1 Thread por player, elas rodam sobrepostas.
## Quem mostra os números é scenes/hud.tscn.

const WORK_LOAD := 40000  ## iterações de trabalho falso por player

## P1 continua Warrior (cavaleiro); P2 e P3 trocados pra ter silhueta
## diferente cada um — ajuda a identificar quem é quem de longe.
const BLUE_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png")
const BLUE_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Run.png")
const BLUE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Attack1.png")
## Golpe especial (segurar o ataque): Attack2, mais forte — ver SPECIAL_DAMAGE_MULT.
const BLUE_ATK2 := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Attack2.png")
## Bloqueio do P1 (só ele tem esse sprite no pacote): segura pra reduzir dano.
const BLUE_GUARD := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Guard.png")
## P2: Archer (arqueira) — Idle/Run têm menos quadros que o Warrior, e o
## "ataque" é o Shoot (atirar flecha) em vez de golpe de espada.
const PURPLE_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer_Idle.png")
const PURPLE_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer_Run.png")
const PURPLE_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Archer/Archer_Shoot.png")
## Vermelho (o time inimigo) virou o catálogo de EnemyTypes — cada level
## soma um tipo (Guerreiro → goblins do Update 010).
const ATTACK_RANGE := 90.0
const ATTACK_DAMAGE := 25.0
const SPECIAL_DAMAGE_MULT := 2.0  ## golpe especial (segurar) causa o dobro
const GUARD_DAMAGE_MULT := 0.2  ## bloqueando, só 20% do dano passa
const KNOCKBACK_DIST := 18.0  ## empurrão instantâneo de quem apanha, pra dar peso
const CAM_SHAKE_HIT := 3.0  ## tremor da câmera num golpe normal
const CAM_SHAKE_SPECIAL := 7.0  ## e num golpe especial/flecha — mais forte
const CAM_SHAKE_DECAY := 10.0  ## por segundo
## Caça: qualquer golpe mata a ovelha (sem HP nela) e larga carne, que cura
## quem chegar perto — sem botão, é só encostar. SHEEP_RESPAWN_TIME é bem
## maior que Player.DEATH_TIME pra não virar fonte infinita ali do lado.
const SHEEP_RESPAWN_TIME := 15.0
const HEAL_AMOUNT := 30.0
const MEAT_PICKUP_REACH := 50.0
const ENEMY_COOLDOWN := 1.2  ## respiro entre golpes do inimigo, em segundos
const ENEMY_SPEED := 170.0  ## mais lento que os players, senão não tem fuga
## P3/"yellow": Pawn (camponês) — mesma contagem de quadros do Warrior
## (8/6/4), só troca a arte; o "ataque" é a faca (Interact Knife).
const YELLOW_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Idle.png")
const YELLOW_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Run.png")
const YELLOW_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Interact Knife.png")
## Golpe especial do Pawn (segurar o ataque): martelada, mais forte que a faca.
const YELLOW_HAMMER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Interact Hammer.png")
## Coleta do P3 (2º botão perto de árvore/ouro/base — ver _try_harvest):
## PAWN_AXE_Y/PAWN_WOOD_Y ali embaixo já servem pro machado/carregar madeira.
const YELLOW_PICKAXE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Interact Pickaxe.png")
const YELLOW_GOLD := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Run Gold.png")
## Parado carregando (polimento: antes só trocava de sprite correndo).
const YELLOW_WOOD_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Idle Wood.png")
const YELLOW_GOLD_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Idle Gold.png")
const HARVEST_REACH := 70.0
## Indicativo flutuante: o quê vai ganhar (perto de árvore/ouro) ou pra onde
## levar (carregando, perto de qual construção) — ver _draw_harvest_prompt().
const WOOD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_02.png")
const GOLD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png")
## "black": 4ª skin da tela de seleção — Lanceiro (golpe de lança + guarda
## com a postura de defesa). Quadro 320×320, bem maior que os outros (192).
const BLACK_LANCER_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Black Units/Lancer/Lancer_Idle.png")
const BLACK_LANCER_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Black Units/Lancer/Lancer_Run.png")
const BLACK_LANCER_ATK := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Black Units/Lancer/Lancer_Right_Attack.png")
const BLACK_LANCER_GUARD := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Black Units/Lancer/Lancer_Right_Defence.png")
const LANCER_FRAME_SIZE := Vector2(320, 320)
## "monk": 5ª skin — Curandeiro. Não bate: o "ataque" cura o aliado ferido
## mais perto (ver _resolve_monk_heals). Cor de Blue Monk, mas com Color
## própria (bege/dourado) — não precisa bater com a pasta de onde veio.
const MONK_IDLE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Monk/Idle.png")
const MONK_RUN := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Monk/Run.png")
const MONK_HEAL := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Monk/Heal.png")
const MONK_HEAL_AMOUNT := 30.0
const MONK_AURA_RADIUS := 150.0  ## regen passivo pra quem fica perto, sem precisar de cura ativa
const MONK_AURA_RATE := 4.0  ## hp por segundo

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

## Ovelhas do pack Update 010 — mais fofas que a versão antiga (Sheep_Grass/Move).
const SHEEP_GRAZE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Sheep/HappySheep_Idle.png")
const SHEEP_MOVE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Sheep/HappySheep_Bouncing.png")
const SHEEP_COUNT := 18
const SHEEP_SPEED := 45.0

## Mundo maior que a janela; a câmera enquadra os três players.
const WORLD := ArenaMap.WORLD
const PLAY_AREA := ArenaMap.PLAY_AREA
const CAM_MARGIN := 300.0  ## folga em volta dos players ao enquadrar

const SHOT_RANGE := 480.0  ## alcance do tiro direto do arqueiro, e também a distância máxima de mira automática
const ARROW_DAMAGE := 22.0  ## um pouco menos que o corpo-a-corpo (25): é à distância
const ARROW_HIT_RANGE := 45.0  ## alcance de acerto — não precisa ser pixel perfeito
## Mira: cantos ao redor de quem o arqueiro atingiria se atirasse agora.
const TARGET_POINTER := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/UI/Pointers/02.png")

## Skill do arqueiro: segurar o ataque por HOLD_THRESHOLD segundos solta uma
## chuva de flechas numa área à frente, além do tiro direto normal.
const HOLD_THRESHOLD := 0.5
const RAIN_COUNT := 7
const RAIN_SPREAD := 130.0  ## raio da área onde as flechas caem

## Levels de goblin (ver EnemyTypes): cada fase soma um tipo novo, um banner
## grande anuncia e a fase acaba quando mata tudo OU quando o tempo estoura
## — o que vier primeiro. Não acumula: ao trocar de level, quem sobrou
## (onda ou avulso do [G]) é removido, pra próxima fase começar limpa.
enum LevelPhase { BANNER, COMBAT, INTERMISSION }
const BANNER_DURATION := 2.2
const INTERMISSION_DURATION := 1.0
const LEVEL_TIME_LIMIT := 30.0  ## timeout da fase, mesmo sem matar tudo
const WAVE_BASE := 2  ## inimigos no level 1; sobe 1 por level
## Teto por onda — acima disso, criar+destruir 1 Thread por unidade por
## frame passa a pesar mais que o próprio trabalho (WORK_LOAD é fixo de
## propósito), e threads deixa de ganhar de serial. É parte da lição, mas
## sem teto a demo trava de vez em máquina fraca.
const MAX_WAVE_ENEMIES := 8
const MAX_LIVE_ENEMIES := 14  ## teto do [G]: onda + avulsos juntos
const MIN_ENEMY_SPAWN_DIST := 260.0  ## nasce longe dos players, não em cima

@export var use_threads := false

var players: Array[Player] = []  ## só os controláveis (câmera enquadra estes)
var units: Array[Player] = []  ## players + inimigo: 1 Thread por unidade
## ponytail: ovelhas são cenário — andam na main thread, fora do units/threads.
var sheep: Array[Player] = []
## Pawns lenhadores: cenário vivo, como as ovelhas.
var workers: Array[Player] = []
## Tudo que se esbarra: units + sheep + workers, montado uma vez no _ready().
var bodies: Array[Player] = []
var arrows: Array[Arrow] = []  ## flechas em voo; roda fora do esquema de Threads
var meat_drops: Array[MeatDrop] = []  ## carne largada por ovelha morta, no chão
var damage_numbers: Array[DamageNumber] = []  ## "-25"/"+30" flutuando
var cam_shake := 0.0  ## magnitude do tremor de câmera; decai sozinho (ver _update_camera)
var _frame_t0 := 0
## Medidas retidas por modo (false = serial, true = threads), pra comparar
## os dois lado a lado mesmo depois de alternar.
var fps_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var ms_by_mode: Dictionary[bool, float] = {false: 0.0, true: 0.0}

var level := 1
var level_phase := LevelPhase.BANNER
var phase_timer := 0.0
var level_timer := 0.0  ## segundos em combate; dispara o timeout do level
var _wave_enemies: Array[Player] = []  ## só os da onda atual — decide "matou tudo"
## Único vínculo Player→nó de desenho (ArenaMap.add_unit não guarda
## referência nenhuma) — é o que permite remover um goblin de vez.
var _enemy_sprites: Dictionary[Player, UnitSprite] = {}

@onready var map: ArenaMap = $ArenaMap
@onready var hud: Control = $UI/HUD
@onready var banner: LevelBanner = $UI/LevelBanner
@onready var cam: Camera2D = $Camera


func _ready() -> void:
	# FPS destravado: sem vsync o custo do trabalho aparece direto no FPS.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spawn_players()
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
	# Sem inimigo fixo mais: o level 1 nasce depois do banner (ver _update_level).
	_start_banner()


## Skin escolhido na tela de seleção (PlayerConfig.skins) decide a CLASSE de
## cada player, não só a cor: "blue" = Guerreiro (golpe especial + bloqueio),
## "purple" = Arqueira (flecha em arco + chuva + mira), "yellow" = Camponês
## (faca/martelada + coleta de madeira/ouro), "black" = Lanceiro (lança +
## bloqueio), "monk" = Curandeiro (cura o aliado mais perto em vez de bater).
## Cada slot sempre tem os mesmos 6 botões — o 6º é guarda, coleta ou mira,
## dependendo de qual classe calhou de estar ali.
func _spawn_players() -> void:
	var size := PLAY_AREA.size
	var key_schemes := [
		[KEY_W, KEY_S, KEY_A, KEY_D, KEY_F, KEY_Q],
		[KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_KP_0, KEY_KP_1],
		[KEY_I, KEY_K, KEY_J, KEY_L, KEY_O, KEY_U],
	]
	for i in key_schemes.size():
		var kit := _skin_kit(PlayerConfig.skins[i])
		var spot := PLAY_AREA.position + Vector2(
				size.x * (i + 1) / (key_schemes.size() + 1), size.y * 0.5)
		var p := Player.new(
			spot,
			kit.color,
			key_schemes[i],
			i,
			kit.idle,
			kit.run,
			kit.atk,
			kit.idle_frames,
			kit.run_frames,
			kit.atk_frames,
			kit.get("special"),
			kit.get("special_frames", 4),
		)
		p.ribbon_y = kit.ribbon_y
		p.is_archer = kit.get("is_archer", false)
		p.is_monk = kit.get("is_monk", false)
		p.guard_texture = kit.get("guard")
		p.axe_texture = kit.get("axe")
		p.pickaxe_texture = kit.get("pickaxe")
		p.wood_texture = kit.get("wood")
		p.gold_texture = kit.get("gold")
		p.wood_idle_texture = kit.get("wood_idle")
		p.gold_idle_texture = kit.get("gold_idle")
		p.frame_size = kit.get("frame_size", Vector2(192, 192))  ## Lanceiro é 320x320
		p.attack_range = kit.get("attack_range", ATTACK_RANGE)  ## Lanceiro alcança mais
		p.attack_damage = kit.get("attack_damage", ATTACK_DAMAGE)
		p.special_damage_mult = kit.get("special_damage_mult", SPECIAL_DAMAGE_MULT)
		p.max_hp = kit.get("max_hp", 100.0)  ## linha de frente aguenta mais, suporte é frágil
		p.hp = p.max_hp
		p.speed = kit.get("speed", Player.SPEED)
		players.append(p)
	units.assign(players)  # o inimigo entra depois, quando o level 1 nasce (ver _spawn_wave)


## Kit completo de uma skin: cor/ribbon + textura e quadros de idle/run/ataque,
## e as chaves opcionais que só a classe correspondente usa (special/guard
## pro Guerreiro; axe/pickaxe/wood/gold pro Camponês; is_archer pra Arqueira;
## guard sozinho, sem special, pro Lanceiro — a postura de Defence dele).
func _skin_kit(skin: String) -> Dictionary:
	match skin:
		"purple":
			return {
				color = Color(0.65, 0.42, 0.86), ribbon_y = 452.0,
				idle = PURPLE_IDLE, run = PURPLE_RUN, atk = PURPLE_ATK,
				idle_frames = 6, run_frames = 4, atk_frames = 8,
				is_archer = true,
				max_hp = 80.0, speed = 280.0,  ## suporte à distância: frágil, mas ágil pra manter distância
			}
		"yellow":
			return {
				color = Color(0.96, 0.78, 0.22), ribbon_y = 324.0,
				idle = YELLOW_IDLE, run = YELLOW_RUN, atk = YELLOW_ATK,
				idle_frames = 8, run_frames = 6, atk_frames = 4,
				special = YELLOW_HAMMER, special_frames = 3,
				axe = PAWN_AXE_Y, pickaxe = YELLOW_PICKAXE,
				wood = PAWN_WOOD_Y, gold = YELLOW_GOLD,
				wood_idle = YELLOW_WOOD_IDLE, gold_idle = YELLOW_GOLD_IDLE,
				## Martelo tem ciclo mais rápido que a faca (é a própria animação do
				## pack) — sem isso o especial seria estritamente melhor em tudo.
				special_damage_mult = 1.6,
			}
		"black":
			return {
				color = Color(0.55, 0.55, 0.60), ribbon_y = 196.0,
				idle = BLACK_LANCER_IDLE, run = BLACK_LANCER_RUN, atk = BLACK_LANCER_ATK,
				idle_frames = 12, run_frames = 6, atk_frames = 3,
				guard = BLACK_LANCER_GUARD, frame_size = LANCER_FRAME_SIZE,
				attack_range = ATTACK_RANGE + 55.0,  ## lança alcança mais longe
				## Ciclo de ataque já é mais rápido (3 quadros vs 4) por causa da
				## própria animação — dano um pouco menor compensa o alcance+velocidade.
				attack_damage = 22.0,
				max_hp = 120.0, speed = 230.0,  ## linha de frente pesada: aguenta mais, anda menos
			}
		"monk":
			return {
				color = Color(0.85, 0.82, 0.7), ribbon_y = 580.0,
				idle = MONK_IDLE, run = MONK_RUN, atk = MONK_HEAL,
				idle_frames = 6, run_frames = 4, atk_frames = 11,
				is_monk = true,
				max_hp = 70.0, speed = 270.0,  ## suporte puro: sem ataque nem guarda, o mais frágil
			}
	## "blue" e fallback: Guerreiro azul.
	return {
		color = Color.CORNFLOWER_BLUE, ribbon_y = 68.0,
		idle = BLUE_IDLE, run = BLUE_RUN, atk = BLUE_ATK,
		idle_frames = 8, run_frames = 6, atk_frames = 4,
		special = BLUE_ATK2, special_frames = 4, guard = BLUE_GUARD,
		max_hp = 120.0,  ## linha de frente: aguenta mais que suporte/arqueira
	}


## --- Level director --------------------------------------------------
## Roda inteiro na main thread. Só mexe em units/bodies antes do dispatch
## (spawn da onda, no início do _process) ou depois da barreira
## (_resolve_attacks já tirou quem morreu; aqui só se limpa sobra na troca
## de fase) — nunca entre um t.start() e o wait_to_finish() correspondente.

func _update_level(delta: float) -> void:
	phase_timer += delta
	match level_phase:
		LevelPhase.BANNER:
			if phase_timer >= BANNER_DURATION:
				_start_combat()
		LevelPhase.COMBAT:
			level_timer += delta
			if _wave_enemies.is_empty() or level_timer >= LEVEL_TIME_LIMIT:
				_end_combat()
		LevelPhase.INTERMISSION:
			if phase_timer >= INTERMISSION_DURATION:
				level += 1
				_start_banner()
	_update_banner()


## Sobe rápido, segura, desce no fim — só durante o BANNER. Quem cronometra
## é main.gd (o HUD/banner não medem nada, só formatam o que chega pronto).
func _update_banner() -> void:
	var alpha := 0.0
	if level_phase == LevelPhase.BANNER:
		var t := phase_timer / BANNER_DURATION
		alpha = clampf(minf(t / 0.15, (1.0 - t) / 0.25), 0.0, 1.0)
	banner.show_banner(_level_title(level), alpha)


func _level_title(lvl: int) -> String:
	return "LEVEL %d — %s" % [lvl, EnemyTypes.kind(lvl - 1).title]


func _start_banner() -> void:
	level_phase = LevelPhase.BANNER
	phase_timer = 0.0


func _start_combat() -> void:
	level_phase = LevelPhase.COMBAT
	phase_timer = 0.0
	level_timer = 0.0
	_spawn_wave(level)


func _end_combat() -> void:
	level_phase = LevelPhase.INTERMISSION
	phase_timer = 0.0
	_clear_enemies()  ## não acumula: some com a onda (e qualquer avulso do [G]) antes da próxima


## count cresce com o level até MAX_WAVE_ENEMIES; passar do fim do catálogo
## repete os tipos com hp/dano escalados (ver EnemyTypes.kind).
func _spawn_wave(lvl: int) -> void:
	var kind := EnemyTypes.kind(lvl - 1)
	var scale := 1.0 + 0.15 * floorf(float(lvl - 1) / EnemyTypes.COUNT)
	var count := clampi(WAVE_BASE + lvl - 1, WAVE_BASE, MAX_WAVE_ENEMIES)
	for _i in count:
		_wave_enemies.append(_spawn_enemy_of_type(kind, _random_enemy_spot(), scale))


## [G]: um inimigo avulso, tipo aleatório entre os já vistos até este level —
## não entra em _wave_enemies, então não conta pro "matou tudo" nem trava o
## level; só engorda a demo (mais uma Thread na tela) até o teto de segurança.
func _summon_random_enemy() -> void:
	if level_phase != LevelPhase.COMBAT:
		return
	if units.size() - players.size() >= MAX_LIVE_ENEMIES:
		return
	var idx := randi() % mini(level, EnemyTypes.COUNT)
	_spawn_enemy_of_type(EnemyTypes.kind(idx), _random_enemy_spot())


## Ponto aleatório na área andável, longe dos players — a arena é grande, então
## poucas tentativas bastam; sem sorte em 20, nasce no centro mesmo.
func _random_enemy_spot() -> Vector2:
	for _try in 20:
		var pt := PLAY_AREA.position + Vector2(randf(), randf()) * PLAY_AREA.size
		var far := true
		for p in players:
			if pt.distance_to(p.pos) < MIN_ENEMY_SPAWN_DIST:
				far = false
				break
		if far:
			return pt
	return PLAY_AREA.position + PLAY_AREA.size * 0.5


func _spawn_enemy_of_type(kind: Dictionary, spot: Vector2, scale := 1.0) -> Player:
	var e := Player.new(spot, kind.color, [0, 0, 0, 0, 0, 0], -1,
			kind.idle, kind.run, kind.attack,
			kind.idle_frames, kind.run_frames, kind.attack_frames)
	e.is_enemy = true
	e.ribbon_y = 196.0
	e.speed = kind.get("speed", ENEMY_SPEED)
	e.max_hp = kind.get("max_hp", 60.0) * scale
	e.hp = e.max_hp
	e.attack_range = kind.get("attack_range", ATTACK_RANGE)
	e.attack_damage = kind.get("attack_damage", ATTACK_DAMAGE) * scale
	e.frame_size = kind.get("frame_size", Vector2(192, 192))
	e.sheet_cols = kind.get("sheet_cols", 0)
	e.idle_row = kind.get("idle_row", 0)
	e.run_row = kind.get("run_row", 0)
	e.attack_row = kind.get("attack_row", 0)
	units.append(e)
	bodies.append(e)
	var sprite := UnitSprite.create(e)
	map.add_unit(sprite)
	_enemy_sprites[e] = sprite
	return e


## Some de vez: tira de units/bodies/_wave_enemies e libera o nó de desenho.
## Chamado só depois da barreira (_resolve_attacks) ou entre fases
## (_clear_enemies) — nunca com alguma Thread ainda rodando.
func _remove_enemy(e: Player) -> void:
	units.erase(e)
	bodies.erase(e)
	_wave_enemies.erase(e)
	var sprite: UnitSprite = _enemy_sprites.get(e)
	if sprite:
		sprite.queue_free()
		_enemy_sprites.erase(e)


func _clear_enemies() -> void:
	for e in units.filter(func(u: Player) -> bool: return u.is_enemy):
		_remove_enemy(e)


## Ovelhas espalhadas pela ilha: só decoração viva, sem input nem thread.
func _spawn_sheep() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260902
	for _i in SHEEP_COUNT:
		var spot := PLAY_AREA.position + Vector2(rng.randf(), rng.randf()) * PLAY_AREA.size
		var s := Player.new(spot, Color.WHITE, [0, 0, 0, 0, 0, 0], -1,
				SHEEP_GRAZE, SHEEP_MOVE, null, 8, 6, 0)
		s.frame_size = Vector2(128, 128)
		s.speed = SHEEP_SPEED
		s.is_sheep = true  ## morte mostra baforada em vez de caveira (ver UnitSprite)
		sheep.append(s)


## Cada pawn puxa madeira de uma árvore pra uma construção — os pontos vêm do
## mapa, que é quem sabe onde as coisas caíram.
func _spawn_workers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for i in PAWN_COUNT:
		var blue := i % 2 == 0
		var home: Vector2 = map.building_spots[i % map.building_spots.size()]
		var w := Player.new(home, Color.WHITE, [0, 0, 0, 0, 0, 0], -1,
				PAWN_IDLE if blue else PAWN_IDLE_Y,
				PAWN_RUN if blue else PAWN_RUN_Y,
				PAWN_AXE if blue else PAWN_AXE_Y, 8, 6, 6)
		w.loaded_texture = PAWN_WOOD if blue else PAWN_WOOD_Y
		w.speed = PAWN_SPEED
		w.work_home = home
		w.work_site = map.tree_spots[rng.randi() % map.tree_spots.size()]
		workers.append(w)


func _process(delta: float) -> void:
	_update_level(delta)

	for u in units:
		# main thread: Input não é thread-safe, e a IA só escreve `input`.
		if u.is_enemy:
			u.chase(players, ATTACK_RANGE, ENEMY_COOLDOWN, delta)
		else:
			u.poll_input(delta)
			if u.is_archer and u.is_aiming:
				_update_aim_lock(u)
			# poll_input() acabou de decidir "começou a atacar agora" (attack_time
			# vira 0.0 nesse exato frame) — é o ponto certo pra nascer a flecha,
			# antes de qualquer Thread mexer no resto do estado do player.
			if u.is_archer and u.attack_time == 0.0:
				_fire_arrow(u)
			# Segurou até passar de HOLD_THRESHOLD: dispara a skill uma única vez
			# (só no frame exato em que o hold cruza o limite, não a cada frame) —
			# e só se a estamina aguentar, senão a chuva de flechas ficaria de graça.
			if u.is_archer and u.attack_hold_time >= HOLD_THRESHOLD \
					and u.attack_hold_time - delta < HOLD_THRESHOLD \
					and u.stamina >= Player.SPECIAL_STAMINA_COST:
				u.stamina -= Player.SPECIAL_STAMINA_COST
				_fire_arrow_rain(u)
			if u.harvest_triggered:
				_try_harvest(u)

	for a in arrows:
		a.step(delta)
	arrows = arrows.filter(func(a: Arrow) -> bool: return not a.is_expired() and not a.hit)

	for m in meat_drops:
		m.step(delta)
	meat_drops = meat_drops.filter(func(m: MeatDrop) -> bool: return not m.is_expired())

	for n in damage_numbers:
		n.step(delta)
	damage_numbers = damage_numbers.filter(func(n: DamageNumber) -> bool: return not n.is_expired())

	for s in sheep:
		s.wander(delta)
		s.step(delta, 0, PLAY_AREA, map.blockers)

	for w in workers:
		w.haul(delta)
		w.step(delta, 0, PLAY_AREA, map.blockers)

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		# start() dispara e volta na hora; o trabalho já está rodando em paralelo.
		# ponytail: criar thread por frame custa ~50us contra ~3ms de trabalho.
		# Se WORK_LOAD cair muito, virar pool de threads persistentes + Semaphore.
		var threads: Array[Thread] = []
		for i in units.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta))
			threads.append(t)
		# Barreira: bloqueia até cada thread terminar (e libera os recursos dela).
		for t in threads:
			t.wait_to_finish()
	else:
		for i in units.size():
			_step_player(i, delta)

	_resolve_attacks()
	_resolve_arrow_hits()
	_resolve_monk_heals()
	_resolve_monk_aura(delta)
	_resolve_sheep_hits()
	_resolve_meat_pickup()
	_resolve_collisions()

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	_update_camera(delta)
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, units, _frame_t0, level)
	queue_redraw()  ## só as flechas usam _draw() agora (ver comentário lá)


## Roda na Thread da unidade i: escreve só em units[i].
func _step_player(i: int, delta: float) -> void:
	units[i].step(delta, WORK_LOAD, PLAY_AREA, map.blockers)


## Dano e morte: mexe em dois objetos ao mesmo tempo, então roda na main
## thread depois da barreira — as tarefas continuam sem lock. Vale pros dois
## lados: player bate no inimigo e o inimigo bate nos players.
func _resolve_attacks() -> void:
	var to_remove: Array[Player] = []
	for u in units:
		if u.is_dead():
			if u.death_time > Player.DEATH_TIME:
				if u.is_enemy:
					to_remove.append(u)  ## onda: inimigo morto não volta, só some
				else:
					# ponytail: respawn em vez de remover — a demo precisa de todos.
					u.hp = u.max_hp
					u.death_time = -1.0
					u.pos = u.spawn_pos
			continue
		if u.is_archer or u.is_monk:
			continue  ## arqueira é à distância (flecha); curandeiro não briga
		if not u.is_attacking() or u.attack_hit:
			continue
		for v in units:
			if v.is_enemy == u.is_enemy or v.is_dead():
				continue
			if u.pos.distance_to(v.pos) < u.attack_range:
				u.attack_hit = true
				var blocked := v.is_guarding
				var dmg := u.attack_damage * (u.special_damage_mult if u.is_special else 1.0)
				if blocked:
					dmg *= GUARD_DAMAGE_MULT
					v.block_fx_time = 0.0
				v.hp -= dmg
				v.hit_flash_time = 0.0
				v.hit_pop_time = 0.0
				_knockback(v, u.pos)
				damage_numbers.append(DamageNumber.new(v.pos, dmg))
				_shake_camera(CAM_SHAKE_SPECIAL if u.is_special else CAM_SHAKE_HIT)
				if v.hp <= 0.0:
					v.hp = 0.0
					v.death_time = 0.0
	for u in to_remove:
		_remove_enemy(u)


## Empurrão instantâneo de quem apanha, na direção oposta a quem bateu — dá
## peso ao golpe sem precisar animar nada. Clampa pra não empurrar pra fora
## da área andável (blockers não entram na conta, é só um empurrãozinho).
func _knockback(victim: Player, from: Vector2) -> void:
	var d := victim.pos - from
	var dir := d.normalized() if d.length() > 0.5 else Vector2.RIGHT
	victim.pos = (victim.pos + dir * KNOCKBACK_DIST).clamp(PLAY_AREA.position, PLAY_AREA.end)


## Tremor de câmera: só guarda a magnitude mais forte pedida no frame, quem
## consome e decai é _update_camera(). Pancadas menores não "atropelam" uma
## grande que já esteja em andamento.
func _shake_camera(amount: float) -> void:
	cam_shake = maxf(cam_shake, amount)


## Flecha acerta: enquanto está voando (not landed), qualquer inimigo vivo
## perto dela toma dano, ou qualquer ovelha viva morre e larga carne (mesma
## regra de _resolve_sheep_hits, só que à distância) — ela some na hora
## (marca `hit`, o filtro em cima tira do array). Pousada, já não machuca
## mais ninguém.
func _resolve_arrow_hits() -> void:
	for a in arrows:
		if a.hit or a.landed:
			continue
		for u in units:
			if not u.is_enemy or u.is_dead():
				continue
			if a.pos.distance_to(u.pos) < ARROW_HIT_RANGE:
				a.hit = true
				u.hp -= ARROW_DAMAGE
				u.hit_flash_time = 0.0
				u.hit_pop_time = 0.0
				_knockback(u, a.pos - a.dir * 40.0)  ## empurra na direção que a flecha vinha
				damage_numbers.append(DamageNumber.new(u.pos, ARROW_DAMAGE))
				_shake_camera(CAM_SHAKE_SPECIAL if a.mode == Arrow.Mode.RAIN else CAM_SHAKE_HIT)
				if u.hp <= 0.0:
					u.hp = 0.0
					u.death_time = 0.0
				break
		if a.hit:
			continue
		for s in sheep:
			if s.is_dead():
				continue
			if a.pos.distance_to(s.pos) < ARROW_HIT_RANGE:
				a.hit = true
				s.death_time = 0.0
				meat_drops.append(MeatDrop.new(s.pos))
				break


## Curandeiro: em vez de bater, o "ataque" cura o aliado ferido mais perto
## (pode ser ela mesma) dentro do alcance normal de ataque. Mesmo timing que
## o resto do dano — depois da barreira, mexe no hp de outro player.
func _resolve_monk_heals() -> void:
	for u in units:
		if u.is_dead() or not u.is_monk or not u.is_attacking() or u.attack_hit:
			continue
		var best: Player = null
		var best_d := INF
		for v in players:
			if v.is_dead() or v.hp >= v.max_hp:
				continue
			var d := u.pos.distance_squared_to(v.pos)
			if d < best_d:
				best_d = d
				best = v
		if best != null and u.pos.distance_to(best.pos) < u.attack_range:
			u.attack_hit = true
			best.hp = minf(best.hp + MONK_HEAL_AMOUNT, best.max_hp)
			best.heal_fx_time = 0.0
			damage_numbers.append(DamageNumber.new(best.pos, MONK_HEAL_AMOUNT, true))


## Curandeiro (passivo): quem está perto regenera um pouquinho de HP com o
## tempo, sem precisar que ela ataque — reforça o papel de "ficar por perto"
## além da cura ativa. Sem número flutuando nem efeito visual: é sutil de
## propósito, pra não competir com a cura de verdade.
func _resolve_monk_aura(delta: float) -> void:
	for u in units:
		if u.is_dead() or not u.is_monk:
			continue
		for v in players:
			if v == u or v.is_dead() or v.hp >= v.max_hp:
				continue
			if u.pos.distance_to(v.pos) <= MONK_AURA_RADIUS:
				v.hp = minf(v.hp + MONK_AURA_RATE * delta, v.max_hp)


## Caça: ovelha não tem HP — um golpe de qualquer player mata (o inimigo não
## caça). Larga carne no lugar da morte e volta a existir só depois de
## SHEEP_RESPAWN_TIME. Roda depois da barreira, igual ao dano.
func _resolve_sheep_hits() -> void:
	for s in sheep:
		if s.is_dead():
			if s.death_time > SHEEP_RESPAWN_TIME:
				s.death_time = -1.0
				s.pos = s.spawn_pos
			continue
		for u in players:
			if not u.is_attacking() or u.attack_hit:
				continue
			if u.pos.distance_to(s.pos) < ATTACK_RANGE:
				u.attack_hit = true
				s.death_time = 0.0
				meat_drops.append(MeatDrop.new(s.pos))
				break


## Cura ao encostar na carne — sem botão, só chegar perto. Roda depois da
## barreira: mexe no hp do player de fora da Thread dele.
func _resolve_meat_pickup() -> void:
	for i in range(meat_drops.size() - 1, -1, -1):
		var m := meat_drops[i]
		for p in players:
			if p.is_dead():
				continue
			if p.pos.distance_to(m.pos) < MEAT_PICKUP_REACH:
				p.hp = minf(p.hp + HEAL_AMOUNT, p.max_hp)
				p.heal_fx_time = 0.0  ## liga o efeito visual (ver UnitSprite._draw_heal_fx)
				damage_numbers.append(DamageNumber.new(p.pos, HEAL_AMOUNT, true))
				meat_drops.remove_at(i)
				break


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


## Mira automática: o alvo vivo mais perto (inimigo OU ovelha — as duas
## contam pro arqueiro caçar à distância, não só no corpo a corpo), se
## estiver a SHOT_RANGE de distância. null se não tiver ninguém no alcance.
func _nearest_target(from: Vector2) -> Player:
	var targets := _targets_in_range(from)
	return targets[0] if not targets.is_empty() else null


## Todo alvo válido (inimigo vivo OU ovelha viva) a até SHOT_RANGE, do mais
## perto pro mais longe — usado tanto pra mira automática (pega o [0]) quanto
## pra ciclar manualmente no modo mira (ver _update_aim_lock).
func _targets_in_range(from: Vector2) -> Array[Player]:
	var result: Array[Player] = []
	for u in units:
		if u.is_enemy and not u.is_dead() and from.distance_to(u.pos) <= SHOT_RANGE:
			result.append(u)
	for s in sheep:
		if not s.is_dead() and from.distance_to(s.pos) <= SHOT_RANGE:
			result.append(s)
	result.sort_custom(func(a: Player, b: Player) -> bool:
		return from.distance_squared_to(a.pos) < from.distance_squared_to(b.pos))
	return result


## Modo mira do arqueiro: mantém aim_lock em cima de um alvo válido, trocando
## quando aim_cycle pede (cima/baixo em poll_input) ou quando o alvo travado
## saiu do alcance/morreu. Só roda enquanto is_aiming (ver main.gd _process).
func _update_aim_lock(p: Player) -> void:
	var targets := _targets_in_range(p.pos)
	if targets.is_empty():
		p.aim_lock = null
		return
	if p.aim_lock == null or not targets.has(p.aim_lock):
		p.aim_lock = targets[0]
		return
	if p.aim_cycle != 0:
		var idx := targets.find(p.aim_lock)
		p.aim_lock = targets[wrapi(idx + p.aim_cycle, 0, targets.size())]


## Nasce na posição do arqueiro, mirando o inimigo mais próximo (se estiver
## no alcance) — senão, pra onde ele está se movendo ou virado, só de
## enfeite, já que sem alvo não tem quem acertar. Lançamento oblíquo até o
## alvo: sobe, desce e "aterrissa" — só depois disso conta o resto de
## Arrow.LIFETIME parada no chão, até sumir de vez.
func _fire_arrow(p: Player) -> void:
	var from := p.pos + Vector2(0, -20)
	var target := p.aim_lock if p.is_aiming and p.aim_lock != null else _nearest_target(p.pos)
	if target != null:
		arrows.append(Arrow.new(from, target.pos, Arrow.Mode.SHOT))
		return
	var dir := p.input.normalized() if p.input.length() > 0.05 \
			else (Vector2.RIGHT if p.facing_right else Vector2.LEFT)
	arrows.append(Arrow.new(from, from + dir * SHOT_RANGE, Arrow.Mode.SHOT))


## Skill: RAIN_COUNT flechas saem do arqueiro e fazem o mesmo lançamento
## oblíquo, cada uma mirando um ponto espalhado ao redor do inimigo mais
## próximo (ou de um ponto à frente, sem alvo) — arco mais alto/longo
## (Arrow.RAIN_*), cara de volley em vez de tiro único.
func _fire_arrow_rain(p: Player) -> void:
	var target := p.aim_lock if p.is_aiming and p.aim_lock != null else _nearest_target(p.pos)
	var from := p.pos + Vector2(0, -20)
	var center: Vector2
	if target != null:
		center = target.pos
	else:
		var aim := p.input.normalized() if p.input.length() > 0.05 \
				else (Vector2.RIGHT if p.facing_right else Vector2.LEFT)
		center = p.pos + aim * 220.0
	for _i in RAIN_COUNT:
		var offset := Vector2(
			randf_range(-RAIN_SPREAD, RAIN_SPREAD),
			randf_range(-RAIN_SPREAD, RAIN_SPREAD) * 0.5,
		)
		arrows.append(Arrow.new(from, center + offset, Arrow.Mode.RAIN))


## Cantos de mira sobre quem o arqueiro atingiria se atirasse agora — mesma
## conta de _nearest_target(), então some/troca de alvo exatamente igual ao
## que vai acontecer quando ela realmente atirar. Pulsa um pouco pra não
## parecer decoração estática.
func _draw_aim_pointer(p: Player) -> void:
	var target := p.aim_lock if p.is_aiming and p.aim_lock != null else _nearest_target(p.pos)
	if target == null:
		return
	var pulse := 1.0 + 0.08 * sin(Time.get_ticks_msec() / 150.0)
	var size := TARGET_POINTER.get_size() * pulse
	# unit.pos já é o centro do corpo (ver UnitSprite) — sem offset, fica
	# certo em qualquer tamanho de sprite (Lanceiro é bem maior que ovelha).
	var alpha := 1.0 if p.is_aiming else 0.5  ## travado (mirando) vs só prévia
	draw_texture_rect(TARGET_POINTER, Rect2(target.pos - size * 0.5, size), false,
			Color(1, 1, 1, alpha))


## Duração total do trecho de trabalho, do dispatch ao último player terminar.
func _span_usec() -> int:
	var last := _frame_t0
	for p in units:
		last = maxi(last, p.t_end)
	return last - _frame_t0


## Só as flechas — players/inimigo/ovelhas/pawns agora se desenham sozinhos via
## UnitSprite (y-sorted dentro do ArenaMap). Continua em z_index 0 (Main),
## então fica sempre por cima do mapa (que é z_index -1) — sem y-sort com
## árvore ainda, mas ok pra um projétil que já some rápido.
func _draw() -> void:
	for a in arrows:
		_draw_arrow(a)
	for m in meat_drops:
		var tex := MeatDrop.TEXTURE
		draw_texture(tex, m.pos - tex.get_size() * 0.5)
	for p in players:
		_draw_harvest_prompt(p)
		if p.is_archer:
			_draw_aim_pointer(p)
	for n in damage_numbers:
		_draw_damage_number(n)


## Número flutuante de dano/cura: grande, com contorno preto grosso pra
## destacar de qualquer fundo (grama, água, sprite) — o desenho simples de
## antes (só draw_string colorido) sumia no cenário.
func _draw_damage_number(n: DamageNumber) -> void:
	var font := ThemeDB.fallback_font
	var size := int(30 * n.scale())
	var pos := n.pos
	var col := Color(n.color, n.alpha())
	var outline := Color(0, 0, 0, n.alpha() * 0.85)
	draw_string_outline(font, pos, n.text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, 6, outline)
	draw_string(font, pos, n.text, HORIZONTAL_ALIGNMENT_CENTER, -1, size, col)


func _draw_arrow(a: Arrow) -> void:
	# Sombra no chão enquanto ela está no ar — vende o efeito do arco.
	if a.height > 0.5:
		draw_set_transform(a.pos, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 6.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Rastro: pontos recentes ligados por linhas cada vez mais fracas/finas,
	# num tom quente pra destacar tanto na grama quanto na água.
	for i in range(1, a.trail.size()):
		var t := float(i) / a.trail.size()
		draw_line(a.trail[i - 1], a.trail[i], Color(1.0, 0.95, 0.6, 0.8 * t), 4.0 * t)

	draw_set_transform(a.draw_pos(), a.visual_angle, Vector2.ONE)
	draw_texture(Arrow.TEXTURE, -Arrow.TEXTURE.get_size() * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Só quem coleta (P3, tem axe_texture) ganha indicativo. Sem carga: ícone da
## árvore/ouro mais perto, se estiver ao alcance. Carregando: ícone sobre a
## construção mais perto, pra onde entregar — mesmo se estiver longe, guia o
## olho na direção certa assim que entrar na tela.
func _draw_harvest_prompt(p: Player) -> void:
	if not p.axe_texture or p.is_dead():
		return
	if p.carrying:
		var target: Variant = _nearest_point(map.building_spots, p.pos)
		if target != null:
			_draw_prompt(target, GOLD_ICON if p.harvest_kind == "gold" else WOOD_ICON)
		return
	if p.is_harvesting() or p.is_attacking() or p.is_guarding:
		return
	for i in map.tree_spots.size():
		if map.tree_regrow[i] <= 0.0 and p.pos.distance_to(map.tree_spots[i]) < HARVEST_REACH:
			_draw_prompt(map.tree_spots[i], WOOD_ICON)
			return
	for g in map.gold_spots:
		if p.pos.distance_to(g) < HARVEST_REACH:
			_draw_prompt(g, GOLD_ICON)
			return


func _nearest_point(points: Array[Vector2], from: Vector2) -> Variant:
	var best_pt: Variant = null
	var best_d := INF
	for pt in points:
		var d := from.distance_squared_to(pt)
		if d < best_d:
			best_d = d
			best_pt = pt
	return best_pt


## Ícone do pack + "U" numa bolha escura — não tem sprite de tecla no pacote,
## então a bolha é desenhada na mão, do mesmo jeito que o resto do HUD.
func _draw_prompt(pos: Vector2, icon: Texture2D) -> void:
	var top := pos + Vector2(0, -76)
	draw_texture_rect(icon, Rect2(top + Vector2(-16, -16), Vector2(32, 32)), false)
	var badge_pos := top + Vector2(14, -4)
	draw_circle(badge_pos, 11.0, Color(0.05, 0.06, 0.08, 0.9))
	draw_arc(badge_pos, 11.0, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
	draw_string(
		ThemeDB.fallback_font, badge_pos + Vector2(-4, 5), "U",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.95),
	)



## Enquadra os três players: centro na caixa que os contém, zoom pra caber
## todo mundo (sem passar de 100% nem mostrar fora do mundo). Lerp pra não
## tremer a cada frame.
func _update_camera(delta: float) -> void:
	var box := Rect2(players[0].pos, Vector2.ZERO)
	for p in players:
		box = box.expand(p.pos)
	box = box.grow(CAM_MARGIN)
	var vp := get_viewport_rect().size
	var min_zoom := maxf(vp.x / WORLD.x, vp.y / WORLD.y)
	var z := clampf(minf(vp.x / box.size.x, vp.y / box.size.y), min_zoom, 1.0)
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.08)
	cam.position = cam.position.lerp(box.get_center(), 0.12)

	# Tremor: offset separado do lerp de posição, pra não "puxar" o
	# enquadramento — decai sozinho até a próxima pancada empurrar de novo.
	cam_shake = maxf(cam_shake - CAM_SHAKE_DECAY * delta, 0.0)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * cam_shake


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		hud.cycle_detail()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_G:
		_summon_random_enemy()
	elif event.is_action_pressed("ui_cancel"):
		## ESC: volta para a seleção de personagem.
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")


## Coleta do P3 (botão de coleta): sem carga, procura árvore ou ouro perto
## pra começar a golpear (Player._step_harvest cuida da animação e vira
## "carrying" sozinho); carregando, procura uma construção perto pra entregar
## (aqui, na hora, sem animação — main thread, mexe direto no contador do p).
func _try_harvest(p: Player) -> void:
	if p.carrying:
		for b in map.building_spots:
			if p.pos.distance_to(b) < HARVEST_REACH:
				if p.harvest_kind == "wood":
					p.wood += 1
				else:
					p.gold += 1
				p.carrying = false
				p.harvest_kind = ""
				return
		return
	for i in map.tree_spots.size():
		if map.tree_regrow[i] > 0.0:
			continue  ## já virou toco, ainda crescendo de novo
		if p.pos.distance_to(map.tree_spots[i]) < HARVEST_REACH:
			map.chop_tree(i)
			p.harvest_kind = "wood"
			p.harvest_time = 0.0
			return
	for g in map.gold_spots:
		if p.pos.distance_to(g) < HARVEST_REACH:
			p.harvest_kind = "gold"
			p.harvest_time = 0.0
			return
