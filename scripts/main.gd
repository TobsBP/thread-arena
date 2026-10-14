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
const BOMBER_BLAST_RADIUS := 90.0  ## alcance do estouro do Goblin do Barril
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
## Engrenagem sobre o castelo principal: "[T] evolução" (ver _draw_castle_prompt).
const CASTLE_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_10.png")
## Castelo principal: chegar perto + [T] abre o CastleMenu, que pausa o jogo.
const CASTLE_REACH := 140.0
## Construção (escolhida no CastleMenu): o fantasma fica à frente de quem
## abriu o menu, encaixado na grade de tiles; ataque confirma, 2º botão cancela.
const BUILD_AHEAD := 60.0  ## folga entre o pé do player e a base da obra
const TOWER_RANGE := 420.0
const TOWER_COOLDOWN := 1.4  ## segundos entre flechas da torre
## Quadro do Archer_Shoot em que a flecha sai do arco.
const TOWER_RELEASE_FRAME := 5.0
const BARRACKS_HP := 15.0  ## vida máxima a mais por Quartel pronto...
const BARRACKS_MAX := 3  ## ...até este tanto de quartéis
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

## Machado e madeira do Camponês jogável (skin "yellow", ver _skin_kit).
const PAWN_WOOD_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Run Wood.png")
const PAWN_AXE_Y := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Pawn/Pawn_Interact Axe.png")

## Aldeões: unidades de verdade, 1 Thread cada; o que dividem está em Village.
const PAWN_DIR := "res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/%s Units/Pawn/Pawn_%s.png"
## Teto de aldeões no mapa, por mais que o reino tenha moradia.
const MAX_VILLAGERS := 10
## Goblin derrubado rende ouro pro reino: é a parte dos players na economia.
const GOBLIN_GOLD := 1

## Derrota: os três players caídos ao mesmo tempo.
const PLAYER_RESPAWN_TIME := 6.0
const WAVE_GROWTH := 0.05  ## vida e dano dos goblins: +5% por level

## Quem a vila cura primeiro ([Z]): menos vida, mais perto ou há mais tempo sem receber.
enum HealMode { WEAKEST, NEAREST, FAIR }
const HEAL_MODE_NAMES := ["menos vida", "mais perto", "rodízio (há mais tempo sem)"]

## Modo bot ([B]) também cuida da vila: compra a árvore nesta ordem e ergue estas obras.
const BOT_GOVERN_EVERY := 1.0
const BOT_BUY_ORDER: Array[StringName] = [
	&"miner", &"houses_1", &"butcher", &"picks_1", &"healer", &"carpentry",
	&"houses_2", &"axes_1", &"masonry", &"watch", &"picks_2", &"knives_1",
	&"training", &"houses_3", &"herbs_1", &"axes_2",
]
const BOT_BUILD_ORDER: Array[StringName] = [&"barracks", &"tower", &"house"]
const BOT_BUILD_LIMIT := {&"barracks": 3, &"tower": 3, &"house": 2}
## Cor do "+N" que sobe quando um recurso entra no banco, por Village.Res.
const RES_TEXT: Array[Color] = [Color(0.95, 0.80, 0.52), Color(1.0, 0.86, 0.25), Color(1.0, 0.56, 0.56)]
const PAWN_SPEED := 150.0
const WORKER_HP := 120.0
## Estouro (dinamite, barril) pega o aldeão de raspão.
const WORKER_BLAST_MULT := 0.5
const WORKER_AGGRO := 1.7  ## goblin prefere player: ver Player.aggro_bias
## Bem mais que Player.DEATH_TIME: perder aldeão custa, o player tem que proteger.
const WORKER_RESPAWN_TIME := 15.0
const TREE_REACH := 70.0  ## perto o bastante do pé da árvore pra bater o machado
const HUNT_RANGE := 70.0  ## perto o bastante da ovelha pra dar a facada
const DELIVERY_REACH := 75.0  ## perto o bastante do player pra entregar a carne
const ROAST_HEAL := 70.0  ## assada cura bem mais que a crua (HEAL_AMOUNT)
const RAW_DELIVERY_HP := 0.5  ## player abaixo disso: a carne vai crua, direto pra ele
const SERVE_HP := 0.75  ## player abaixo disso: alguém busca uma assada na mesa
const LARDER_CAP := 4  ## carne crua + assada + a caminho; acima disso ninguém caça
## Carne assada: arte nossa, a carne do pack tostada.
const ROAST_MEAT := preload("res://assets/Thread Arena/Roast_Meat.png")
## O aldeão levando a assada: as tiras "Meat" do Pawn com a carne tostada.
const PAWN_ROAST_DIR := "res://assets/Thread Arena/Pawn_%s_%s_Roast.png"
## O cozinheiro na manivela do espeto (arte nossa, a partir do Idle do Pawn).
const PAWN_CRANK := "res://assets/Thread Arena/Pawn_%s_Crank.png"
## Quem acende o fogo, batendo pederneira na direção da lenha (idem).
const PAWN_KINDLE := "res://assets/Thread Arena/Pawn_%s_Kindle.png"
## Onde ficam o cozinheiro e quem acende, em relação ao pé da fogueira.
const COOK_SPOT := Vector2(85, -60)
const LIGHT_SPOT := Vector2(-72, -34)
## Porta do armazém, em relação a village.depot.
const DOOR_SPOT := Vector2(0, -38)
const FIRE_LOW := 6.0  ## segundos de fogo: abaixo disso, com carne pra assar, alguém traz lenha
## Quadro do Pawn_Interact Axe/Pickaxe em que a ferramenta pega.
const TOOL_IMPACT_FRAME := 3
const LIGHT_IMPACT_FRAME := 3  ## idem pro Pawn_*_Kindle (6 quadros): a batida da pederneira

## Ovelhas do pack Update 010 — mais fofas que a versão antiga (Sheep_Grass/Move).
const SHEEP_GRAZE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Sheep/HappySheep_Idle.png")
const SHEEP_MOVE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Resources/Sheep/HappySheep_Bouncing.png")
const SHEEP_COUNT := 18
const SHEEP_SPEED := 45.0

## Mundo maior que a janela; a câmera enquadra os três players.
const WORLD := ArenaMap.WORLD
const PLAY_AREA := ArenaMap.PLAY_AREA
const CAM_MARGIN := 300.0  ## folga em volta dos players ao enquadrar
## Modo apresentação: [C] tira a câmera dos players e para num ponto de trabalho da vila.
enum CamFocus { PLAYERS, DEPOT, MINE, KITCHEN, WOODCUTTER, HUNTER }
const FOCUS_ZOOM := 1.35
const FOCUS_CAPTIONS := [
	"",
	"ARMAZÉM  —  Semáforo na porta (%d por vez) + Mutex no estoque lá dentro" % Village.DEPOT_SLOTS,
	"MINA  —  Semáforo contador: %d vagas, o resto espera na fila" % Village.MINE_SLOTS,
	"FOGUEIRA  —  Semáforo binário (1 espeto) + produtor-consumidor (assadas)",
	"LENHADOR  —  cada aldeão é uma Thread; a árvore só cai depois da barreira",
	"CAÇADOR  —  a ovelha é reservada na main thread: sem disputa, sem lock",
]

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
## [M]: sem goblins — onda não nasce e [G] não invoca; o level segue subindo
## só pelo tempo (LEVEL_TIME_LIMIT), pra a árvore de evolução ir destravando.
var no_mobs := false

var players: Array[Player] = []  ## só os controláveis (câmera enquadra estes)
var units: Array[Player] = []  ## players + aldeões + inimigos: 1 Thread por unidade
## ponytail: ovelhas são cenário — andam na main thread, fora do units/threads.
var sheep: Array[Player] = []
## Aldeões: também estão em `units` (viram Thread); esta lista é só o recorte.
var workers: Array[Player] = []
## players + aldeões: quem os goblins perseguem e machucam. Não muda de tamanho.
var allies: Array[Player] = []
var _prey: Array[Player] = []  ## recorte de allies que os goblins miram neste frame
## O estado que os aldeões dividem — armazém (Mutex) e vagas (Semaphore).
var village: Village
var _kitchen_fire := 0  ## índice da fogueira da vila em ArenaMap.campfire_spots
var _fire_shown := true  ## como a fogueira da vila está desenhada agora
var _spit_shown := -1.0  ## progresso do assado desenhado agora (< 0 = sem espeto)
var _village_mine := 0  ## índice da mina da vila em ArenaMap.gold_spots
var _pawn_kits: Array = []  ## arte do Pawn azul e do amarelo (_pawn_textures)
var heal_mode := HealMode.WEAKEST
var _last_healed: Dictionary[Player, float] = {}  ## game_time da última cura de cada player (FAIR)
var game_over := false
var game_time := 0.0  ## segundos de partida (para na derrota)
var _govern_timer := 0.0
## Linha de comando (depois do "--"): partida sem ninguém, pra medir. Ver _apply_cli().
var _auto_quit := false
var _max_time := 0.0  ## > 0: encerra a partida nesse tempo mesmo sem derrota
var _world_ready := false  ## depois do _ready: aldeão novo já entra em allies/bodies/cena
var _village_now := {}  ## _village_stats() do frame: vai pro HUD e pros letreiros
## Tudo que se esbarra: units + sheep, montado no _ready().
var bodies: Array[Player] = []
var arrows: Array[Arrow] = []  ## flechas em voo; roda fora do esquema de Threads
var dynamites: Array[Dynamite] = []  ## dinamites arremessadas pelo Goblin da Dinamite
var meat_drops: Array[MeatDrop] = []  ## carne largada por ovelha morta, no chão
var damage_numbers: Array[DamageNumber] = []  ## "-25"/"+30" flutuando
var cam_shake := 0.0  ## magnitude do tremor de câmera; decai sozinho (ver _update_camera)
var cam_focus := CamFocus.PLAYERS  ## o que a câmera enquadra; [C] passa pro próximo
var _focus_point := Vector2.ZERO  ## último ponto focado (lenhador/caçador somem e voltam)
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

## Economia: banco, árvore e trabalhadores (dado puro, só main thread).
var kingdom := Kingdom.new()
## Construções erguidas pelo jogador (obra ou prontas). Nascem e terminam
## antes do dispatch: o blocker novo entra fora da janela das Threads.
var build_sites: Array[BuildSite] = []
var placing_kind: StringName = &""  ## "" = ninguém posicionando
var placer: Player = null  ## quem posiciona (quem abriu o menu)
var _place_dir := Vector2.RIGHT  ## último rumo do placer: o fantasma fica desse lado
var _menu_opener: Player = null
var _placer_was_bot := false  ## bot posicionando vira humano até confirmar/cancelar

@onready var map: ArenaMap = $ArenaMap
@onready var hud: Control = $UI/HUD
@onready var banner: LevelBanner = $UI/LevelBanner
@onready var cam: Camera2D = $Camera
@onready var castle_menu: CastleMenu = $UI/CastleMenu
@onready var side: SidePanel = $UI/SidePanel


func _ready() -> void:
	# FPS destravado: sem vsync o custo do trabalho aparece direto no FPS.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_spawn_players()
	_spawn_sheep()
	_spawn_workers()
	allies.assign(players)
	allies.append_array(workers)
	bodies.assign(units)
	bodies.append_array(sheep)
	# Cada unidade ganha um nó de desenho dentro do cenário y-sorted: é o que
	# faz o player passar atrás da árvore. O dado segue RefCounted.
	for u in units:
		map.add_unit(UnitSprite.create(u))
	for s in sheep:
		map.add_unit(UnitSprite.create(s, false))
	# Câmera presa ao mundo: nunca mostra fora do chão desenhado.
	cam.limit_right = int(WORLD.x)
	cam.limit_bottom = int(WORLD.y)
	cam.position = WORLD * 0.5
	castle_menu.build_chosen.connect(_on_build_chosen)
	_world_ready = true
	_apply_cli()
	# Sem inimigo fixo mais: o level 1 nasce depois do banner (ver _update_level).
	_start_banner()

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
	# Os aldeões entram logo depois (_spawn_workers) e o inimigo quando o level 1 nasce (_spawn_wave)
	units.assign(players)


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
			# Sem mobs, a onda vazia não conta como "matou tudo": só o tempo fecha a fase.
			if (_wave_enemies.is_empty() and not no_mobs) or level_timer >= LEVEL_TIME_LIMIT:
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
	if no_mobs:
		return "LEVEL %d — SEM MOBS" % lvl
	return "LEVEL %d — %s" % [lvl, EnemyTypes.kind(lvl - 1).title]


func _start_banner() -> void:
	level_phase = LevelPhase.BANNER
	phase_timer = 0.0


func _start_combat() -> void:
	level_phase = LevelPhase.COMBAT
	phase_timer = 0.0
	level_timer = 0.0
	if not no_mobs:
		_spawn_wave(level)


func _end_combat() -> void:
	level_phase = LevelPhase.INTERMISSION
	phase_timer = 0.0
	_clear_enemies()  ## não acumula: some com a onda (e qualquer avulso do [G]) antes da próxima


## count cresce com o level até MAX_WAVE_ENEMIES; passar do fim do catálogo
## repete os tipos com hp/dano escalados (ver EnemyTypes.kind).
func _spawn_wave(lvl: int) -> void:
	var kind := EnemyTypes.kind(lvl - 1)
	var scale := 1.0 + WAVE_GROWTH * (lvl - 1)
	var count := clampi(WAVE_BASE + lvl - 1, WAVE_BASE, MAX_WAVE_ENEMIES)
	for _i in count:
		_wave_enemies.append(_spawn_enemy_of_type(kind, _random_enemy_spot(), scale))


## [G]: um inimigo avulso, tipo aleatório entre os já vistos até este level —
## não entra em _wave_enemies, então não conta pro "matou tudo" nem trava o
## level; só engorda a demo (mais uma Thread na tela) até o teto de segurança.
func _summon_random_enemy() -> void:
	if level_phase != LevelPhase.COMBAT or no_mobs:
		return
	if units.size() - allies.size() >= MAX_LIVE_ENEMIES:
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
	e.attack_cooldown = kind.get("cooldown", ENEMY_COOLDOWN)
	e.is_thrower = kind.get("is_thrower", false)
	e.is_bomber = kind.get("is_bomber", false)
	e.bomber_fuse = kind.get("bomber_fuse", e.bomber_fuse)
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


## A vila fica em volta do castelo principal.
func _spawn_workers() -> void:
	village = Village.new()
	kingdom.village = village  ## o banco do reino é o estoque da vila
	village.depot = map.main_castle_spot
	village.mine = _nearest_reachable(map.gold_spots, village.depot)
	_village_mine = map.gold_spots.find(village.mine)
	for i in map.campfire_spots.size():
		if village.depot.distance_squared_to(map.campfire_spots[i]) \
				< village.depot.distance_squared_to(map.campfire_spots[_kitchen_fire]):
			_kitchen_fire = i
	village.kitchen = map.campfire_spots[_kitchen_fire]
	village.cook_spot = village.kitchen + COOK_SPOT
	village.light_spot = village.kitchen + LIGHT_SPOT
	village.door_spot = village.depot + DOOR_SPOT
	_pawn_kits = [_pawn_textures("Blue"), _pawn_textures("Yellow")]
	_sync_workers()


## Um aldeão no mapa por trabalhador do reino (Kingdom.max_workers), até MAX_VILLAGERS.
func _sync_workers() -> void:
	var before := workers.size()
	while workers.size() < mini(kingdom.max_workers, MAX_VILLAGERS):
		_spawn_worker()
	if _world_ready and workers.size() > before:
		hud.show_notice("Chegou gente nova na vila: %d aldeões" % workers.size(), 3.0)


func _spawn_worker() -> void:
	var i := workers.size()
	var blue := i % 2 == 0
	var kit: Dictionary = _pawn_kits[i % 2]
	# Em fila na frente da porta; a colisão espalha o resto.
	var home := village.depot + Vector2((i % 6 - 2.5) * 44.0, 30.0 + 34.0 * (i / 6))
	var w := Player.new(home,
			Color(0.45, 0.62, 0.88) if blue else Color(0.86, 0.72, 0.30),
			[0, 0, 0, 0, 0, 0], -1, kit.idle, kit.run, kit.knife, 8, 6, 4)
	w.is_worker = true
	w.village = village
	w.ribbon_y = 68.0 if blue else 324.0
	w.axe_texture = kit.axe
	w.pickaxe_texture = kit.pickaxe
	w.wood_texture = kit.wood
	w.wood_idle_texture = kit.wood_idle
	w.gold_texture = kit.gold
	w.gold_idle_texture = kit.gold_idle
	w.meat_texture = kit.meat
	w.meat_idle_texture = kit.meat_idle
	w.roast_texture = kit.roast
	w.roast_idle_texture = kit.roast_idle
	w.light_texture = kit.kindle
	w.crank_texture = kit.crank
	# Na ordem de Player.Job: NONE, WOOD, GOLD, HUNT, COOK, SERVE.
	w.job_run.assign([null, kit.axe_run, kit.pickaxe_run, kit.knife_run, kit.knife_run, null])
	w.job_idle.assign([null, kit.axe_idle, kit.pickaxe_idle, kit.knife_idle, kit.knife_idle, null])
	w.speed = PAWN_SPEED
	w.max_hp = WORKER_HP
	w.aggro_bias = WORKER_AGGRO
	w.hp = w.max_hp
	workers.append(w)
	units.append(w)
	if _world_ready:
		# Chegou no meio da partida (comprou Casas / ergueu Casa)
		allies.append(w)
		bodies.append(w)
		map.add_unit(UnitSprite.create(w))
		w.spawn_fx_time = 0.0


## Toda a arte do Pawn de uma cor ("Blue"/"Yellow")
func _pawn_textures(color: String) -> Dictionary:
	var kit := {}
	for entry in [["idle", "Idle"], ["run", "Run"], ["knife", "Interact Knife"],
			["axe", "Interact Axe"], ["pickaxe", "Interact Pickaxe"],
			["wood", "Run Wood"], ["wood_idle", "Idle Wood"],
			["gold", "Run Gold"], ["gold_idle", "Idle Gold"],
			["meat", "Run Meat"], ["meat_idle", "Idle Meat"],
			["axe_run", "Run Axe"], ["axe_idle", "Idle Axe"],
			["pickaxe_run", "Run Pickaxe"], ["pickaxe_idle", "Idle Pickaxe"],
			["knife_run", "Run Knife"], ["knife_idle", "Idle Knife"]]:
		kit[entry[0]] = load(PAWN_DIR % [color, entry[1]])
	kit.roast = load(PAWN_ROAST_DIR % [color, "Run"])
	kit.roast_idle = load(PAWN_ROAST_DIR % [color, "Idle"])
	kit.crank = load(PAWN_CRANK % color)
	kit.kindle = load(PAWN_KINDLE % color)
	return kit


## Dá pra um aldeão parar ao lado deste ponto? (parte das árvores/minas cai fora da área andável)
func _reachable(spot: Vector2) -> bool:
	return spot.distance_to(spot.clamp(PLAY_AREA.position, PLAY_AREA.end)) < 40.0


func _nearest_reachable(points: Array[Vector2], from: Vector2) -> Vector2:
	var best: Variant = null
	for pt in points:
		if not _reachable(pt):
			continue
		if best == null or from.distance_squared_to(pt) < from.distance_squared_to(best):
			best = pt
	# Nenhum alcançável: fica o mais perto mesmo.
	return best if best != null else _nearest_point(points, from)


## --- Derrota, bots governando e partidas de medição ---------------------

## Os três caídos ao mesmo tempo: acabou.
func _check_defeat() -> void:
	for p in players:
		if not p.is_dead():
			return
	_finish_game("derrota")


func _finish_game(why: String) -> void:
	game_over = true
	if _auto_quit:
		var v := _village_stats()
		print("RESULT fim=%s level=%d tempo=%.0f mutex=%d fila=%d cura=%d entregue=%.1f contado=%.1f perdido=%.1f comprados=%d aldeoes=%d obras=%d madeira=%d ouro=%d" % [
			why, level, game_time, int(village.use_mutex), int(village.use_semaphores), heal_mode,
			v.delivered, v.counted, v.delivered - v.counted, kingdom.bought.size(),
			workers.size(), build_sites.size(), kingdom.stock("wood"), kingdom.stock("gold")])
		get_tree().quit()


## Partida sem ninguém jogando, pra comparar configurações.
func _apply_cli() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--bots":
			for p in players:
				p.is_bot = true
		elif arg == "--threads":
			use_threads = true
		elif arg == "--no-mutex":
			village.use_mutex = false
		elif arg == "--no-fila":
			village.set_semaphores_enabled(false)
		elif arg == "--auto-quit":
			_auto_quit = true
		elif arg.begins_with("--cura="):
			heal_mode = clampi(arg.trim_prefix("--cura=").to_int(), 0, HealMode.size() - 1) as HealMode
		elif arg == "--no-mobs":
			_toggle_no_mobs()
		elif arg.begins_with("--seed="):
			seed(arg.trim_prefix("--seed=").to_int())
		elif arg.begins_with("--timescale="):
			Engine.time_scale = arg.trim_prefix("--timescale=").to_float()
		elif arg.begins_with("--max-time="):
			_max_time = arg.trim_prefix("--max-time=").to_float()


## Mina e espeto acima da lotação (só acontece com os semáforos desligados)
func _update_work_rates() -> void:
	var miners := 0
	var cooks := 0
	for w in workers:
		if w.holds_mine:
			miners += 1
		if w.holds_fire:
			cooks += 1
	village.mine_rate = minf(1.0, float(Village.MINE_SLOTS) / maxi(miners, 1))
	village.fire_rate = minf(1.0, float(Village.FIRE_SLOTS) / maxi(cooks, 1))
	if _max_time > 0.0 and game_time >= _max_time:
		_finish_game("tempo")


## Os bots cuidando do reino: ver BOT_BUY_ORDER.
func _bot_govern(delta: float) -> void:
	_govern_timer -= delta
	if _govern_timer > 0.0:
		return
	_govern_timer = BOT_GOVERN_EVERY
	for id in BOT_BUY_ORDER:
		if kingdom.bought.has(id):
			continue
		var why := kingdom.buy_block(id, level)
		if why.is_empty():
			kingdom.buy(id, level)
			hud.show_notice("Os bots compraram: %s" % UpgradeTree.find(id).title, 2.5)
			return
		if why == "sem recurso":
			break  ## guarda o ouro pra este em vez de gastar nos de baixo
	for kind in BOT_BUILD_ORDER:
		var have: int = kingdom.built.get(kind, 0)
		for site in build_sites:
			if site.kind == kind and not site.done:
				have += 1
		if have >= BOT_BUILD_LIMIT[kind] or not kingdom.build_block(kind).is_empty():
			continue
		if kind == &"house" and kingdom.max_workers >= MAX_VILLAGERS:
			continue
		if _bot_build(kind):
			return


## Acha um lugar em volta do castelo e ergue.
func _bot_build(kind: StringName) -> bool:
	var size := _build_size(kind)
	var center := map.main_castle_spot + Vector2(0, -150)
	for ring in range(4, 13):
		for step in ring * 6:
			var ang := TAU * step / (ring * 6)
			var at := center + Vector2(cos(ang), sin(ang) * 0.7) * ring * ArenaMap.TILE
			var pos := ((at - size * 0.5) / ArenaMap.TILE).round() * ArenaMap.TILE
			if not _bot_can_place(pos, size):
				continue
			kingdom.pay_build(kind)
			var node := map.place_building(kind, pos)
			build_sites.append(BuildSite.new(kind, pos, size, node))
			hud.show_notice("Os bots começaram uma obra: %s" % BuildSite.KINDS[kind].title, 2.5)
			return true
	return false


func _bot_can_place(pos: Vector2, size: Vector2) -> bool:
	var base := ArenaMap.base_rect(pos, size)
	if not map.can_build(base):
		return false
	var clear := base.grow(120.0)
	for spot in [village.depot, village.door_spot, village.kitchen, village.cook_spot,
			village.light_spot, village.mine]:
		if clear.has_point(spot):
			return false
	var grown := base.grow(Player.BODY_RADIUS)
	for b in bodies:
		if not b.is_dead() and grown.has_point(b.pos + Player.FEET):
			return false
	return true


## --- Aldeões ---------------------------------------------------------
## Mesma divisão do resto: decidir é na main thread, antes do dispatch
## (escolher serviço, destino, árvore, ovelha — tudo que olha pros outros);
## executar é na Thread do aldeão (Player._step_work, que é onde ele disputa
## o armazém e as vagas); e o que mexe em outro objeto — matar a ovelha,
## curar o player, virar a árvore em toco — só depois da barreira.

func _think_worker(w: Player) -> void:
	if w.is_dead():
		w.input = Vector2.ZERO
		return
	if w.job == Player.Job.NONE:
		_assign_job(w)
		if w.job == Player.Job.NONE:
			# Sem vaga em profissão nenhuma: passeia pela pracinha do castelo.
			w.stroll(village.depot + Vector2(0, 80), get_process_delta_time())
	if w.job == Player.Job.WOOD and w.phase == Player.Phase.GO \
			and map.tree_regrow[w.work_tree] > 0.0:
		w.drop_work()  ## o Camponês derrubou esta árvore antes
	elif w.job == Player.Job.HUNT and w.cargo == Player.Cargo.NONE:
		var prey := w.work_prey
		if prey == null or prey.is_dead():
			w.drop_work()  ## alguém matou a ovelha antes
		elif not w.is_attacking() and w.pos.distance_to(prey.pos) < HUNT_RANGE:
			# Início do golpe na main thread, como o chase() e o poll_input().
			w.attack_time = 0.0
			w.attack_hit = false
	elif w.phase == Player.Phase.HAUL and (w.cargo == Player.Cargo.ROAST
			or (w.cargo == Player.Cargo.MEAT and w.work_prey != null)):
		_aim_delivery(w)
	w.work_think(map)


## Sem serviço: pega um de uma profissão com menos gente do que a aba Trabalhadores pede.
func _assign_job(w: Player) -> void:
	var busy: Array[int] = [0, 0, 0, 0]  ## por Kingdom.Job: quantos já estão nela
	var hunters := 0
	var cooks_coming := 0  ## ainda não pegaram a carne do armazém
	var cooks_roasting := 0
	var servers_coming := 0  ## ainda não pegaram a assada da mesa
	var fuelers := 0  ## levando lenha pra fogueira
	for o in workers:
		match o.job:
			Player.Job.WOOD:
				busy[Kingdom.Job.LUMBERJACK] += 1
			Player.Job.FUEL:
				busy[Kingdom.Job.LUMBERJACK] += 1
				fuelers += 1
			Player.Job.GOLD:
				busy[Kingdom.Job.MINER] += 1
			Player.Job.HUNT:
				busy[Kingdom.Job.BUTCHER] += 1
				hunters += 1
			Player.Job.COOK:
				busy[Kingdom.Job.BUTCHER] += 1
				if o.phase == Player.Phase.WORK:
					cooks_roasting += 1
				else:
					cooks_coming += 1
			Player.Job.SERVE:
				busy[Kingdom.Job.HEALER] += 1
				if o.phase == Player.Phase.GO:
					servers_coming += 1
	var lumberjack := kingdom.assigned[Kingdom.Job.LUMBERJACK] > busy[Kingdom.Job.LUMBERJACK]
	var miner := kingdom.assigned[Kingdom.Job.MINER] > busy[Kingdom.Job.MINER]
	var butcher := kingdom.assigned[Kingdom.Job.BUTCHER] > busy[Kingdom.Job.BUTCHER]
	var healer := kingdom.assigned[Kingdom.Job.HEALER] > busy[Kingdom.Job.HEALER]
	var raw := floori(village.meat + Village.EPS)
	if healer and village.roasts > servers_coming and _hurt_player(SERVE_HP) != null:
		w.job = Player.Job.SERVE
		w.head_to(village.kitchen, Village.SITE_REACH, Player.Phase.GO)
		return
	# Carne pra assar e fogueira apagada ou quase: um lenhador (não o cozinheiro) leva lenha.
	var cooking := cooks_coming + cooks_roasting
	var fire_wanted := village.fire_fuel < FIRE_LOW and fuelers == 0 and (cooking > 0 or raw > 0)
	if lumberjack and fire_wanted and village.wood >= 1.0 - Village.EPS:
		w.job = Player.Job.FUEL
		w.head_to(village.depot, Village.SITE_REACH, Player.Phase.GO)
		return
	# Um espeto só: um assando e, no máximo, um esperando a vez (a fila do semáforo).
	if butcher and raw > cooks_coming and cooking < Village.FIRE_SLOTS + 1:
		w.job = Player.Job.COOK
		w.head_to(village.kitchen, Village.SITE_REACH, Player.Phase.GO)
		return
	var options: Array = []
	if miner:
		options.append([busy[Kingdom.Job.MINER] * 1000.0 + village.gold, Player.Job.GOLD])
	if lumberjack:
		# A cozinha esperando fogo e o armazém sem lenha: lenha passa na frente.
		options.append([busy[Kingdom.Job.LUMBERJACK] * 1000.0 + village.wood
				- (5000.0 if fire_wanted else 0.0), Player.Job.WOOD])
	# Despensa cheia: ninguém caça.
	var larder := raw + village.roasts + hunters + cooks_roasting
	if butcher and larder < LARDER_CAP:
		options.append([busy[Kingdom.Job.BUTCHER] * 1000.0 + larder, Player.Job.HUNT])
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for o in options:
		if _start_gathering(w, o[1]):
			return


func _start_gathering(w: Player, job: int) -> bool:
	match job:
		Player.Job.GOLD:
			w.job = Player.Job.GOLD
			w.head_to(village.mine, Village.SITE_REACH, Player.Phase.GO)
			return true
		Player.Job.WOOD:
			var tree := _free_tree(w.pos)
			if tree < 0:
				return false
			w.job = Player.Job.WOOD
			w.work_tree = tree
			w.head_to(map.tree_spots[tree], TREE_REACH, Player.Phase.GO)
			return true
	var prey := _free_sheep(w.pos)
	if prey == null:
		return false
	w.job = Player.Job.HUNT
	w.work_prey = prey
	w.head_to(prey.pos, HUNT_RANGE * 0.8, Player.Phase.GO)
	return true


## Árvore em pé mais perto que nenhum outro aldeão já pegou.
func _free_tree(from: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in map.tree_spots.size():
		if map.tree_regrow[i] > 0.0 or not _reachable(map.tree_spots[i]):
			continue
		var d := from.distance_squared_to(map.tree_spots[i])
		if d >= best_d:
			continue
		var taken := false
		for o in workers:
			if o.work_tree == i:
				taken = true
				break
		if not taken:
			best = i
			best_d = d
	return best


func _free_sheep(from: Vector2) -> Player:
	var best: Player = null
	var best_d := INF
	for s in sheep:
		if s.is_dead():
			continue
		var d := from.distance_squared_to(s.pos)
		if d >= best_d:
			continue
		var taken := false
		for o in workers:
			if o.work_prey == s:
				taken = true
				break
		if not taken:
			best = s
			best_d = d
	return best


## Player vivo e ferido (abaixo de `below` da vida) que a vila atende agora, conforme heal_mode.
func _hurt_player(below: float, from := Vector2.ZERO) -> Player:
	var best: Player = null
	var best_score := INF
	for p in players:
		if p.is_dead() or p.hp >= p.max_hp * below:
			continue
		var score: float
		match heal_mode:
			HealMode.NEAREST:
				score = from.distance_squared_to(p.pos)
			HealMode.FAIR:
				score = _last_healed.get(p, -1.0)  # nunca recebeu = primeiro da fila
			_:
				score = p.hp / p.max_hp
		if score < best_score:
			best = p
			best_score = score
	return best


## Carne na mão: crua vai direto pra quem está mal (cura menos, mas chega já)
func _route_meat(w: Player) -> void:
	var hurt := _hurt_player(RAW_DELIVERY_HP, w.pos)
	w.work_prey = hurt
	if hurt != null:
		w.head_to(hurt.pos, DELIVERY_REACH * 0.8, Player.Phase.HAUL)
	else:
		w.head_to(village.kitchen, Village.SITE_REACH, Player.Phase.HAUL)


## Entrega em mãos: mantém o aldeão apontado pra alguém vivo.
func _aim_delivery(w: Player) -> void:
	if w.work_prey != null and not w.work_prey.is_dead():
		return
	if w.cargo == Player.Cargo.MEAT:
		_route_meat(w)
		return
	var target := _hurt_player(1.0, w.pos)
	if target == null:
		target = _nearest_ally(w.pos, players)
	w.work_prey = target
	if target != null:
		w.head_to(target.pos, DELIVERY_REACH * 0.8, Player.Phase.HAUL)


## Caça: a facada do aldeão mata a ovelha reservada e a carne já sai nas costas dele.
func _resolve_worker_hunts() -> void:
	for w in workers:
		if w.is_dead() or w.job != Player.Job.HUNT or w.cargo != Player.Cargo.NONE:
			continue
		if not w.is_attacking() or w.attack_hit:
			continue
		var s := w.work_prey
		if s == null or s.is_dead() or w.pos.distance_to(s.pos) > ATTACK_RANGE:
			continue
		w.attack_hit = true
		s.death_time = 0.0
		w.load_cargo(Player.Cargo.MEAT)
		_route_meat(w)


## Aldeão encostou em quem ia receber: cura e fica livre.
func _resolve_deliveries() -> void:
	for w in workers:
		var p := w.work_prey
		if w.is_dead() or w.phase != Player.Phase.HAUL or p == null or p.is_dead():
			continue
		if w.cargo != Player.Cargo.MEAT and w.cargo != Player.Cargo.ROAST:
			continue
		if w.pos.distance_to(p.pos) > DELIVERY_REACH:
			continue
		var heal := ROAST_HEAL if w.cargo == Player.Cargo.ROAST else HEAL_AMOUNT
		p.hp = minf(p.hp + heal, p.max_hp)
		p.heal_fx_time = 0.0
		damage_numbers.append(DamageNumber.new(p.pos, heal, true))
		_last_healed[p] = game_time
		w.drop_work()


## O que o serviço do aldeão faz no cenário.
func _resolve_work_fx() -> void:
	for w in workers:
		var chopping := w.job == Player.Job.WOOD and w.work_tree >= 0
		var lighting := w.job == Player.Job.FUEL and w.is_working()  # já no lugar, batendo
		var swinging := w.phase == Player.Phase.WORK \
				and (chopping or lighting or w.job == Player.Job.GOLD)
		if swinging:
			# A ferramenta está em laço (Player.get_current_frame)
			var frames := w.light_frames if lighting else (w.axe_frames if chopping else w.pickaxe_frames)
			var impact := LIGHT_IMPACT_FRAME if lighting else TOOL_IMPACT_FRAME
			var hits := int((w.anim_time * w.anim_fps + frames - impact) / frames)
			if w.work_hits >= 0 and hits != w.work_hits:
				if chopping:
					map.hit_tree(w.work_tree, _side(map.tree_spots[w.work_tree], w))
				elif lighting:
					map.spark_fire(_kitchen_fire)
				else:
					map.hit_mine(_village_mine, _side(village.mine, w))
			w.work_hits = hits
		else:
			w.work_hits = -1
		if chopping and not swinging and w.cargo == Player.Cargo.WOOD:
			map.chop_tree(w.work_tree, _side(map.tree_spots[w.work_tree], w))
			w.work_tree = -1  ## cortada: não é mais dele (e não derruba de novo quando ela voltar)
		# Descarga terminou (descarregava no frame passado, agora não): o recurso pipoca.
		if w.phase == Player.Phase.UNLOAD:
			w.fx_cargo = w.cargo
		elif w.fx_cargo != Player.Cargo.NONE:
			if not w.is_dead():
				var at := village.kitchen + Vector2(-84, 4) if w.fx_cargo == Player.Cargo.MEAT \
						else village.depot + Vector2(randf_range(-56, 56), randf_range(-8, 14))
				map.pop_resource(w.fx_cargo, at)
				damage_numbers.append(DamageNumber.note(at + Vector2(0, 44),
						"+%d" % int(Village.LOAD[w.fx_cargo]), RES_TEXT[w.fx_cargo]))
			w.fx_cargo = Player.Cargo.NONE


## +1 se `spot` está à direita do aldeão, -1 se à esquerda.
func _side(spot: Vector2, w: Player) -> float:
	return 1.0 if spot.x >= w.pos.x else -1.0


## Espeto na fogueira da vila.
func _update_spit() -> void:
	var progress := -1.0
	var turning := false
	for w in workers:
		if w.job == Player.Job.COOK and w.phase == Player.Phase.WORK:
			progress = 1.0 - w.work_timer / Player.ROAST_TIME
			turning = w.is_working()
	if progress < 0.0 and _spit_shown < 0.0:
		return
	_spit_shown = progress
	map.set_spit(_kitchen_fire, progress, turning)


## Números da vila pro HUD e pros letreiros no mapa: o HUD não mede nem conta nada, recebe pronto.
func _village_stats() -> Dictionary:
	var stats := {
		wood = village.wood, gold = village.gold, meat = village.meat,
		roasts = village.roasts, fire = village.fire_fuel,
		mutex = village.use_mutex, semaphores = village.use_semaphores, threads = use_threads,
		heal = HEAL_MODE_NAMES[heal_mode],
		counted = village.counted, delivered = 0.0,
		mine_used = 0, mine_queue = 0, fire_used = 0, fire_queue = 0,
		door_used = 0, door_queue = 0,
	}
	for w in workers:
		stats.delivered += w.delivered
		if w.holds_door:
			stats.door_used += 1
		elif w.phase == Player.Phase.ENTER:
			stats.door_queue += 1
		if w.holds_mine:
			stats.mine_used += 1
		elif w.holds_fire:
			stats.fire_used += 1
		elif w.phase == Player.Phase.QUEUE and w.job == Player.Job.GOLD:
			stats.mine_queue += 1
		elif w.phase == Player.Phase.QUEUE and w.job == Player.Job.COOK:
			stats.fire_queue += 1
	return stats


func _process(delta: float) -> void:
	if game_over:
		# Tudo parado: só o letreiro. Nenhuma Thread nasce depois da derrota.
		banner.show_banner("FIM DE JOGO — chegaram ao LEVEL %d     [R] recomeça" % level, 1.0)
		return
	game_time += delta
	_update_level(delta)
	# A fogueira da vila gasta a lenha aqui, com nenhuma Thread rodando.
	village.burn(delta)
	if players[0].is_bot:
		_bot_govern(delta)
	_sync_workers()  # o reino ganhou moradia (árvore/Casa): nasce o aldeão
	_update_work_rates()
	if village.fire_lit() != _fire_shown:
		_fire_shown = village.fire_lit()
		map.set_fire_lit(_kitchen_fire, _fire_shown)

	# Quem os goblins podem escolher neste frame.
	_prey.clear()
	for a in allies:
		if not a.is_busy():
			_prey.append(a)

	for u in units:
		# main thread: Input não é thread-safe, e a IA só escreve `input`.
		if u.is_worker:
			_think_worker(u)
		elif u.is_enemy:
			# Goblin vai em quem estiver mais perto, player ou aldeão.
			u.chase(_prey, map, u.attack_range, u.attack_cooldown, delta)
			# Mesmo instante que o arqueiro dispara a flecha: chase() acabou
			# de decidir "começou a atacar agora" (attack_time == 0.0).
			# not is_dead(): morrer bem nesse frame congela attack_time em
			# 0.0 pro resto da animação de morte (step() pula _step_attack()
			# enquanto is_dead()) — sem o guard, arremessava uma dinamite
			# por frame até a Thread liberar o cadáver.
			if u.is_thrower and u.attack_time == 0.0 and not u.is_dead():
				_throw_dynamite(u)
		else:
			if u.is_bot:
				u.bot_think(units, players, map, SHOT_RANGE, delta)
			else:
				u.poll_input(delta)
			if u.is_archer and u.is_aiming:
				_update_aim_lock(u)
			# poll_input() acabou de decidir "começou a atacar agora" (attack_time
			# vira 0.0 nesse exato frame) — é o ponto certo pra nascer a flecha,
			# antes de qualquer Thread mexer no resto do estado do player.
			# not is_dead(): mesma armadilha do goblin da dinamite — morto,
			# attack_time congela em 0.0 e disparava uma flecha por frame.
			if u.is_archer and u.attack_time == 0.0 and not u.is_dead():
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

	# Antes do dispatch: obra nova mexe em blockers/nav, que as Threads leem.
	_update_placement()
	_update_build_sites(delta)

	for a in arrows:
		a.step(delta)
	arrows = arrows.filter(func(a: Arrow) -> bool: return not a.is_expired() and not a.hit)

	for d in dynamites:
		d.step(delta)
	dynamites = dynamites.filter(func(d: Dynamite) -> bool: return not d.is_expired())

	for m in meat_drops:
		m.step(delta)
	meat_drops = meat_drops.filter(func(m: MeatDrop) -> bool: return not m.is_expired())

	for n in damage_numbers:
		n.step(delta)
	damage_numbers = damage_numbers.filter(func(n: DamageNumber) -> bool: return not n.is_expired())

	for s in sheep:
		s.wander(delta)
		s.step(delta, 0, PLAY_AREA, map.blockers)

	_frame_t0 = Time.get_ticks_usec()
	if use_threads:
		# Uma Thread por player, criada e destruída a cada frame.
		var threads: Array[Thread] = []
		for i in units.size():
			var t := Thread.new()
			t.start(_step_player.bind(i, delta))
			threads.append(t)
		# bloqueia até cada thread terminar
		for t in threads:
			t.wait_to_finish()
	else:
		for i in units.size():
			_step_player(i, delta)

	_resolve_attacks()
	_resolve_arrow_hits()
	_resolve_dynamite_hits()
	_resolve_bomber_blasts()
	_resolve_monk_heals()
	_resolve_monk_aura(delta)
	_resolve_sheep_hits()
	_resolve_meat_pickup()
	_resolve_worker_hunts()
	_resolve_deliveries()
	_resolve_work_fx()
	_update_spit()
	_resolve_collisions()
	_check_defeat()
	if game_over:
		return

	# lerp: o FPS instantâneo do Godot oscila demais pra ler na tela.
	fps_by_mode[use_threads] = lerpf(fps_by_mode[use_threads], Engine.get_frames_per_second(), 0.1)
	ms_by_mode[use_threads] = lerpf(ms_by_mode[use_threads], _span_usec() / 1000.0, 0.1)
	_update_camera(delta)
	_village_now = _village_stats()
	hud.update_village(_village_now)
	hud.update_stats(use_threads, ms_by_mode, fps_by_mode, units, _frame_t0, level, no_mobs)
	side.update_panel(players, players.map(_player_hints), level, no_mobs, kingdom)
	queue_redraw()  ## só as flechas usam _draw() agora (ver comentário lá)


## Roda na Thread da unidade i: escreve só em units[i].
func _step_player(i: int, delta: float) -> void:
	units[i].step(delta, WORK_LOAD, PLAY_AREA, map.blockers)


## Dano e morte: mexe em dois objetos ao mesmo tempo, então roda na main
## thread depois da barreira — as tarefas continuam sem lock. Vale pros dois
## lados: player bate no inimigo e o inimigo bate em players e aldeões.
func _resolve_attacks() -> void:
	var to_remove: Array[Player] = []
	for u in units:
		if u.is_dead():
			# Aldeão demora bem mais pra voltar (a Thread dele segue rodando, só contando o tempo)
			var wait := Player.DEATH_TIME if u.is_enemy \
					else (WORKER_RESPAWN_TIME if u.is_worker else PLAYER_RESPAWN_TIME)
			if u.death_time > wait:
				if u.is_enemy:
					to_remove.append(u)  ## onda: inimigo morto não volta, só some
				else:
					# ponytail: respawn em vez de remover — a demo precisa de todos.
					u.hp = u.max_hp
					u.death_time = -1.0
					u.pos = u.spawn_pos
					if u.is_worker:
						u.spawn_fx_time = 0.0  ## baforada: não surge do nada
			continue
		if u.is_archer or u.is_monk or u.is_thrower or u.is_bomber or u.is_worker:
			continue  ## arqueira/dinamite são à distância; curandeiro e aldeão não brigam; barril explode
		if not u.is_attacking() or u.attack_hit:
			continue
		for v in units:
			if v.is_enemy == u.is_enemy or v.is_dead() or v.is_hidden():
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
		village.add(Village.Res.GOLD, GOBLIN_GOLD)
		map.pop_resource(Village.Res.GOLD, u.pos + Vector2(0, 24))
		damage_numbers.append(DamageNumber.note(u.pos + Vector2(0, 40), "+%d" % GOBLIN_GOLD,
				RES_TEXT[Village.Res.GOLD]))
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


## Estouro em área: dano só quando should_blast() vira true (uma vez só, no
## fim do pavio — ver Dynamite) e só em players e aldeões dentro de BLAST_RADIUS do
## ponto onde ela pousou. Roda depois da barreira, igual ao resto do dano.
func _resolve_dynamite_hits() -> void:
	for d in dynamites:
		if not d.should_blast():
			continue
		_shake_camera(CAM_SHAKE_SPECIAL)
		for p in allies:
			if p.is_dead() or p.is_hidden():
				continue
			if p.pos.distance_to(d.target_pos) > Dynamite.BLAST_RADIUS:
				continue
			var dmg := d.damage * (WORKER_BLAST_MULT if p.is_worker else 1.0)
			p.hp -= dmg
			p.hit_flash_time = 0.0
			p.hit_pop_time = 0.0
			_knockback(p, d.target_pos)
			damage_numbers.append(DamageNumber.new(p.pos, dmg))
			if p.hp <= 0.0:
				p.hp = 0.0
				p.death_time = 0.0


## Goblin do Barril: não bate, chega perto e explode — chase() já acendeu o
## pavio (fuse_time = 0.0) no mesmo instante que decidiu atacar; aqui só
## checamos se ele já terminou (fuse_done(), uma vez só). Estoura em área
## em players e aldeões por perto E mata ele mesmo — mexe em dois objetos ao mesmo
## tempo, então roda depois da barreira, igual ao resto do dano.
func _resolve_bomber_blasts() -> void:
	for u in units:
		if u.is_dead() or not u.is_bomber or not u.fuse_done():
			continue
		_shake_camera(CAM_SHAKE_SPECIAL)
		for p in allies:
			if p.is_dead() or p.is_hidden():
				continue
			if p.pos.distance_to(u.pos) > BOMBER_BLAST_RADIUS:
				continue
			var dmg := u.attack_damage * (WORKER_BLAST_MULT if p.is_worker else 1.0)
			p.hp -= dmg
			p.hit_flash_time = 0.0
			p.hit_pop_time = 0.0
			_knockback(p, u.pos)
			damage_numbers.append(DamageNumber.new(p.pos, dmg))
			if p.hp <= 0.0:
				p.hp = 0.0
				p.death_time = 0.0
		u.hp = 0.0
		u.death_time = 0.0  ## suicídio: o próprio estouro também mata ele


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
			if a.is_dead() or b.is_dead() or a.is_hidden() or b.is_hidden():
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


## Nasce na posição do goblin, mirando o player ou aldeão vivo mais perto.
func _throw_dynamite(u: Player) -> void:
	var target := _nearest_ally(u.pos, _prey)
	if target == null:
		return
	var from := u.pos + Vector2(0, -20)
	dynamites.append(Dynamite.new(from, target.pos, u.attack_damage))


func _nearest_ally(from: Vector2, among: Array[Player]) -> Player:
	var best: Player = null
	var best_d := INF
	for p in among:
		if p.is_dead():
			continue
		var d := from.distance_squared_to(p.pos)
		if d < best_d:
			best_d = d
			best = p
	return best


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


## Só as flechas — players/inimigo/ovelhas/aldeões agora se desenham sozinhos via
## UnitSprite (y-sorted dentro do ArenaMap). Continua em z_index 0 (Main),
## então fica sempre por cima do mapa (que é z_index -1) — sem y-sort com
## árvore ainda, mas ok pra um projétil que já some rápido.
func _draw() -> void:
	for a in arrows:
		_draw_arrow(a)
	for d in dynamites:
		_draw_dynamite(d)
	for m in meat_drops:
		var tex := MeatDrop.TEXTURE
		draw_texture(tex, m.pos - tex.get_size() * 0.5)
	for p in players:
		_draw_harvest_prompt(p)
		if p.is_archer:
			_draw_aim_pointer(p)
	_draw_village()
	for site in build_sites:
		if not site.done:
			_draw_build_progress(site)
	_draw_castle_prompt()
	_draw_ghost()
	for n in damage_numbers:
		_draw_damage_number(n)


## Letreiros da vila no próprio mapa.
func _draw_village() -> void:
	if _village_now.is_empty():
		return
	var v := _village_now
	var depot_text := "ARMAZÉM %d/%d" % [v.door_used, Village.DEPOT_SLOTS]
	if v.door_queue > 0:
		depot_text += " · fila %d" % v.door_queue
	_draw_sign(village.depot + Vector2(0, -150), depot_text)
	var mine_text := "MINA %d/%d" % [v.mine_used, Village.MINE_SLOTS]
	if v.mine_queue > 0:
		mine_text += " · fila %d" % v.mine_queue
	_draw_sign(village.mine + Vector2(0, -140), mine_text)
	var fire_text := "FOGUEIRA %ds" % ceili(v.fire) if v.fire > 0.0 else "FOGUEIRA apagada"
	if v.fire_queue > 0:
		fire_text += " · fila %d" % v.fire_queue
	_draw_sign(village.kitchen + Vector2(0, -110), fire_text)
	var tex := MeatDrop.TEXTURE
	for i in floori(v.meat + Village.EPS):
		draw_texture_rect(tex, Rect2(village.kitchen + Vector2(-96 - i * 22, -44), Vector2(56, 56)), false)
	for i in int(v.roasts):
		draw_texture_rect(ROAST_MEAT, Rect2(village.kitchen + Vector2(40 + i * 22, -44), Vector2(56, 56)), false)


func _draw_sign(pos: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var at := pos - Vector2(150, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, 5, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 300, 16, Color(1.0, 0.95, 0.75))


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


## Voando: mesma sombra da flecha + o graveto girando. Pousada com o pavio
## queimando, fica parada (sem desenho extra — o pavio "chiando" já é a
## textura em si girando, ver Dynamite.spin_frame). No instante do estouro,
## troca pro mesmo estouro que a morte usa (UnitSprite._draw_explosion).
func _draw_dynamite(d: Dynamite) -> void:
	if d.is_exploding():
		var frame := d.explosion_frame()
		var s := Dynamite.EXPLOSION_SIZE
		draw_texture_rect_region(Dynamite.EXPLOSION_TEXTURE,
				Rect2(d.target_pos - Vector2(s, s) * 0.5, Vector2(s, s)),
				Rect2(frame * s, 0, s, s))
		return
	if d.height > 0.5:
		draw_set_transform(d.pos, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 6.0, Color(0.0, 0.0, 0.0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var frame := d.spin_frame()
	var s := Dynamite.FRAME_SIZE
	draw_set_transform(d.draw_pos(), d.visual_angle, Vector2.ONE)
	draw_texture_rect_region(Dynamite.TEXTURE, Rect2(-s * 0.5, -s * 0.5, s, s),
			Rect2(frame * s, 0, s, s))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Só quem coleta (P3, tem axe_texture) ganha indicativo. Sem carga: ícone da
## árvore/ouro mais perto, se estiver ao alcance. Carregando: ícone sobre a
## construção mais perto, pra onde entregar — mesmo se estiver longe, guia o
## olho na direção certa assim que entrar na tela.
func _draw_harvest_prompt(p: Player) -> void:
	if not p.axe_texture or p.is_dead():
		return
	if p.carrying:
		var target: Variant = _nearest_point(map.castle_spots, p.pos)
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


## Ícone do pack + a tecla numa bolha escura — não tem sprite de tecla no
## pacote, então a bolha é desenhada na mão, do mesmo jeito que o resto do HUD.
func _draw_prompt(pos: Vector2, icon: Texture2D, key := "U") -> void:
	var top := pos + Vector2(0, -76)
	draw_texture_rect(icon, Rect2(top + Vector2(-16, -16), Vector2(32, 32)), false)
	var badge_pos := top + Vector2(14, -4)
	draw_circle(badge_pos, 11.0, Color(0.05, 0.06, 0.08, 0.9))
	draw_arc(badge_pos, 11.0, 0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
	draw_string(
		ThemeDB.fallback_font, badge_pos + Vector2(-4, 5), key,
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
	var target := box.get_center()
	if cam_focus != CamFocus.PLAYERS:
		z = FOCUS_ZOOM
		# O painel da esquerda do HUD é mais largo que o da direita.
		target = _focus_target() - Vector2(hud.free_center_shift(), 0.0) / z
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.08)
	cam.position = cam.position.lerp(target, 0.12)

	# Tremor: offset separado do lerp de posição, pra não "puxar" o
	# enquadramento — decai sozinho até a próxima pancada empurrar de novo.
	cam_shake = maxf(cam_shake - CAM_SHAKE_DECAY * delta, 0.0)
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * cam_shake


## Onde a câmera para no modo apresentação.
func _focus_target() -> Vector2:
	match cam_focus:
		CamFocus.DEPOT:
			_focus_point = village.depot + Vector2(0, -50)
		CamFocus.MINE:
			_focus_point = village.mine + Vector2(0, -50)
		CamFocus.KITCHEN:
			_focus_point = village.kitchen + Vector2(0, -40)
		CamFocus.WOODCUTTER:
			_follow_worker(Player.Job.WOOD)
		CamFocus.HUNTER:
			_follow_worker(Player.Job.HUNT)
	return _focus_point


func _follow_worker(job: int) -> void:
	var best: Player = null
	for w in workers:
		if w.is_dead() or w.job != job:
			continue
		if best == null or (w.phase == Player.Phase.WORK and best.phase != Player.Phase.WORK):
			best = w
	if best != null:
		_focus_point = best.pos


func _unhandled_input(event: InputEvent) -> void:
	if placer != null and event.is_action_pressed("ui_cancel"):
		_end_placement()  ## ESC posicionando: só desiste da obra, não sai da partida
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		use_threads = not use_threads
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_T:
		_open_castle_menu()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_H:
		hud.cycle_detail()
		side.detail = hud.detail
		side.queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_G:
		_summon_random_enemy()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_M:
		_toggle_no_mobs()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_B:
		# Os três juntos: liga/desliga o bot no lugar do teclado/controle.
		var on := not players[0].is_bot
		for p in players:
			p.is_bot = on
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_C:
		cam_focus = wrapi(cam_focus + 1, 0, CamFocus.size()) as CamFocus
		_focus_point = cam.position
		hud.set_camera_caption(FOCUS_CAPTIONS[cam_focus])
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_R and game_over:
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_Z:
		heal_mode = wrapi(heal_mode + 1, 0, HealMode.size()) as HealMode
		hud.show_notice("Cura primeiro: %s" % HEAL_MODE_NAMES[heal_mode], 2.5)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_V:
		# Liga/desliga os semáforos de capacidade (as filas)
		village.set_semaphores_enabled(not village.use_semaphores)
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_X:
		# Liga/desliga o lock do depósito no armazém (Village.deposit)
		village.use_mutex = not village.use_mutex
	elif event.is_action_pressed("ui_cancel"):
		## ESC: volta para a seleção de personagem.
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")


## Coleta do P3 (botão de coleta): sem carga, procura árvore ou ouro perto
## pra começar a golpear (Player._step_harvest cuida da animação e vira
## "carrying" sozinho); carregando, procura um castelo perto pra entregar
## (aqui, na hora, sem animação — main thread). Vai pro banco do reino; o
## contador do p continua só pro UnitSprite mostrar quanto ele já entregou.
func _try_harvest(p: Player) -> void:
	if p.carrying:
		for b in map.castle_spots:
			if p.pos.distance_to(b) < HARVEST_REACH:
				# O Camponês rende por viagem o mesmo que um aldeão.
				kingdom.deposit(p.harvest_kind, int(Village.LOAD[
						Village.Res.WOOD if p.harvest_kind == "wood" else Village.Res.GOLD]))
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
			map.chop_tree(i, 1.0 if map.tree_spots[i].x >= p.pos.x else -1.0)
			p.harvest_kind = "wood"
			p.harvest_time = 0.0
			return
	for g in map.gold_spots:
		if p.pos.distance_to(g) < HARVEST_REACH:
			p.harvest_kind = "gold"
			p.harvest_time = 0.0
			return


## [M]. Fora do _process (input), então nenhuma Thread está rodando: pode
## tirar/pôr goblin em units direto, igual à troca de fase.
func _toggle_no_mobs() -> void:
	no_mobs = not no_mobs
	if no_mobs:
		_clear_enemies()
	elif level_phase == LevelPhase.COMBAT:
		_spawn_wave(level)  ## voltou no meio da fase: a onda dela nasce agora


## O que esse player pode fazer agora, pro painel da direita: [tecla, texto].
## Mesma conta do _draw_harvest_prompt/_player_at_castle — quem sabe onde
## fica castelo e árvore é o main, o SidePanel só formata.
func _player_hints(p: Player) -> Array:
	var atk := SidePanel.key_name(p.keys[4])
	var act2 := SidePanel.key_name(p.keys[5])
	if p.is_dead():
		return [["", "caído — renasce já já"]]
	if p == placer:
		return [[atk, "confirmar obra"], [act2, "cancelar obra"]]
	var out: Array = []
	if p.is_bot:
		out.append(["B", "bot jogando — devolve o controle"])
	out.append(["T", "castelo: evolução, trabalhadores, obras"])
	if p.axe_texture:
		if p.carrying:
			var at_castle := false
			for c in map.castle_spots:
				at_castle = at_castle or p.pos.distance_to(c) < HARVEST_REACH
			out.append([act2, "entregar no castelo"] if at_castle else ["", "leve a carga até um castelo"])
		elif not p.is_harvesting():
			for i in map.tree_spots.size():
				if map.tree_regrow[i] <= 0.0 and p.pos.distance_to(map.tree_spots[i]) < HARVEST_REACH:
					out.append([act2, "cortar árvore"])
					break
			for g in map.gold_spots:
				if p.pos.distance_to(g) < HARVEST_REACH:
					out.append([act2, "minerar ouro"])
					break
	if p.stamina < Player.ATTACK_STAMINA_COST:
		out.append(["", "sem estamina — espere recarregar"])
	return out


## --- Castelo e construção ---------------------------------------------
## Tudo main thread. Obra nasce (_update_placement) e termina
## (_update_build_sites) antes do dispatch das tarefas — blockers/nav só
## mudam fora da janela t.start()/wait_to_finish(), igual ao spawn de goblin.

## Qualquer um dos players vivos (bot ou não) mais perto da porta do castelo
## principal, dentro de CASTLE_REACH — null se ninguém estiver lá.
func _player_at_castle() -> Player:
	var best: Player = null
	var best_d := CASTLE_REACH
	for p in players:
		if p.is_dead():
			continue
		var d := p.pos.distance_to(map.main_castle_spot)
		if d < best_d:
			best_d = d
			best = p
	return best


func _open_castle_menu() -> void:
	# De qualquer lugar: quem posiciona a obra é quem está na porta ou o 1º player vivo fora do bot.
	var p := _player_at_castle()
	if p == null:
		for q in players:
			if not q.is_dead() and (p == null or (p.is_bot and not q.is_bot)):
				p = q
	if p == null:
		return
	_end_placement()
	_menu_opener = p
	castle_menu.open(kingdom, level)
	get_viewport().set_input_as_handled()


## Menu fechou com uma construção escolhida: quem abriu passa a posicionar.
func _on_build_chosen(kind: StringName) -> void:
	if _menu_opener == null or _menu_opener.is_dead():
		return
	placing_kind = kind
	placer = _menu_opener
	# Bot não lê o controle: quem posiciona anda com o teclado/controle dele
	# até confirmar ou cancelar, e aí o bot volta.
	_placer_was_bot = placer.is_bot
	placer.is_bot = false
	placer.set_build_mode(true)
	_place_dir = Vector2.RIGHT if placer.facing_right else Vector2.LEFT


func _end_placement() -> void:
	if placer != null:
		placer.set_build_mode(false)
		if _placer_was_bot:
			placer.is_bot = true
	_placer_was_bot = false
	placer = null
	placing_kind = &""


## Lê o confirmar/cancelar que o poll_input() do placer já decidiu neste
## frame. Confirmar num lugar ruim não faz nada (o fantasma vermelho avisa).
func _update_placement() -> void:
	if placer == null:
		return
	if placer.is_bot or placer.is_dead() or placer.build_cancel:
		_end_placement()
		return
	if placer.input.length() > 0.05:
		_place_dir = placer.input.normalized()
	if not placer.build_confirm:
		return
	var pos := _ghost_pos()
	if not _can_place(pos):
		return
	if not kingdom.build_block(placing_kind).is_empty():
		_end_placement()  ## o banco mudou desde a escolha no menu
		return
	kingdom.pay_build(placing_kind)
	var node := map.place_building(placing_kind, pos)
	build_sites.append(BuildSite.new(placing_kind, pos, _build_size(placing_kind), node))
	_end_placement()


## Canto de cima do quadro da obra: a base fica centrada a BUILD_AHEAD do pé
## do placer, pro lado que ele anda/olha, encaixada na grade de tiles.
func _ghost_pos() -> Vector2:
	var size := _build_size(placing_kind)
	var reach := absf(_place_dir.x) * size.x * 0.35 + absf(_place_dir.y) * size.y * 0.225
	var base_center := placer.pos + Player.FEET + _place_dir * (reach + BUILD_AHEAD)
	var pos := base_center - Vector2(size.x * 0.5, size.y * 0.725)
	return (pos / ArenaMap.TILE).round() * ArenaMap.TILE


## Mapa livre (ArenaMap.can_build) e ninguém em pé na base — senão a
## unidade nasceria presa dentro do blocker.
func _can_place(pos: Vector2) -> bool:
	var base := ArenaMap.base_rect(pos, _build_size(placing_kind))
	if not map.can_build(base):
		return false
	var grown := base.grow(Player.BODY_RADIUS)
	for b in bodies:
		if not b.is_dead() and grown.has_point(b.pos + Player.FEET):
			return false
	return true


func _build_size(kind: StringName) -> Vector2:
	return (ArenaMap.BUILD_TEX[kind][0] as Texture2D).get_size()


## Obra avança; no frame em que termina vira prédio e aplica o efeito. Torre
## pronta atira sozinha — a flecha é a mesma Arrow do arqueiro, então o dano
## sai do _resolve_arrow_hits() de sempre.
func _update_build_sites(delta: float) -> void:
	for site in build_sites:
		if not site.done:
			site.progress += delta
			if site.is_finished():
				site.done = true
				map.finish_building(site.node, site.kind)
				_on_building_done(site)
			continue
		if site.kind != &"tower":
			continue
		site.cooldown -= delta
		if site.release >= 0.0:
			# A flecha sai quando ele solta a corda.
			site.release -= delta
			if site.release < 0.0:
				var aim := site.aim if site.aim != null and not site.aim.is_dead() \
						else _nearest_enemy(site.top(), TOWER_RANGE)
				if aim != null:
					var side := -1.0 if site.archer.flip_h else 1.0
					arrows.append(Arrow.new(site.archer.global_position + Vector2(22.0 * side, -6.0),
							aim.pos, Arrow.Mode.SHOT))
			continue
		if site.cooldown > 0.0:
			continue
		var target := _nearest_enemy(site.top(), TOWER_RANGE)
		if target != null:
			site.aim = target
			site.release = TOWER_RELEASE_FRAME / ArenaMap.ARCHER_SHOOT_FPS
			site.cooldown = TOWER_COOLDOWN
			map.tower_shoot(site.archer, target.pos)


func _on_building_done(site: BuildSite) -> void:
	kingdom.on_built(site.kind)
	if site.kind == &"tower":
		site.archer = map.add_tower_archer(site.node)
	match site.kind:
		&"castle":
			map.castle_spots.append(site.door())
		&"barracks":
			if kingdom.built[&"barracks"] <= BARRACKS_MAX:
				for p in players:
					p.max_hp += BARRACKS_HP
					if not p.is_dead():
						p.hp += BARRACKS_HP


func _nearest_enemy(from: Vector2, reach: float) -> Player:
	var best: Player = null
	var best_d := reach * reach
	for u in units:
		if not u.is_enemy or u.is_dead():
			continue
		var d := from.distance_squared_to(u.pos)
		if d < best_d:
			best_d = d
			best = u
	return best


## Fantasma da construção: a textura pronta translúcida, verde se cabe e
## vermelha se não, com a base que vai bloquear contornada.
func _draw_ghost() -> void:
	if placer == null:
		return
	var pos := _ghost_pos()
	var ok := _can_place(pos)
	var tint := Color(0.5, 1.0, 0.5, 0.6) if ok else Color(1.0, 0.4, 0.4, 0.6)
	var tex: Texture2D = ArenaMap.BUILD_TEX[placing_kind][0]
	draw_texture(tex, pos, tint)
	draw_rect(ArenaMap.base_rect(pos, tex.get_size()), Color(tint, 0.9), false, 2.0)


## Barra de obra em cima do prédio: a mesma barrinha da vida das unidades.
func _draw_build_progress(site: BuildSite) -> void:
	var bar := Rect2(site.pos + Vector2(site.size.x * 0.5 - 48, site.size.y * 0.3), Vector2(96, 19))
	PackUI.hslice(self, UnitSprite.UI_BAR, bar, UnitSprite.BAR_SRC, UnitSprite.BAR_CAP)
	draw_texture_rect_region(UnitSprite.UI_BAR_FILL,
			Rect2(bar.position + Vector2(7, 8), Vector2((bar.size.x - 14) * site.ratio(), 3)),
			Rect2(0, 30, 64, 3), Color(1.0, 0.82, 0.15))


## "[T]" sobre o castelo principal quando tem player perto pra abrir o menu.
func _draw_castle_prompt() -> void:
	if placer == null and _player_at_castle() != null:
		_draw_prompt(map.main_castle_spot + Vector2(0, -40), CASTLE_ICON, "T")
