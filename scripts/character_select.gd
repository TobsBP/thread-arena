extends Node2D

## Tela de seleção de personagem (lobby).
## Instancia 3 PlayerCard, um por player controlável, e aguarda [ESPAÇO]
## para iniciar a arena com os skins escolhidos.
##
## Fluxo:
##   title_screen.tscn     → (ESPAÇO) → character_select.tscn
##   character_select.tscn → (ESPAÇO) → main.tscn
##   main.tscn             → (ESC)    → character_select.tscn

## Configuração de cada player: [key_prev, key_next, joy_device]
## key_prev/next seguem o mesmo esquema de teclas da arena (player.gd):
##   P1 WASD  → A (esquerda) / D (direita)
##   P2 setas → LEFT / RIGHT
##   P3 IJKL  → J (esquerda) / L (direita)
const PLAYER_CONFIGS := [
	[KEY_A,    KEY_D,     0],  # P1
	[KEY_LEFT, KEY_RIGHT, 1],  # P2
	[KEY_J,    KEY_L,     2],  # P3
]

const CARD_SCENE := preload("res://scenes/player_card.tscn")
const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const PAPER_CAP := 20.0
const INK := Color(0.16, 0.13, 0.09)

## Espaçamento horizontal entre o centro de cada card.
const CARD_SPACING := 260.0

## Céu: gradiente desenhado (o pack não tem uma textura de céu pronta) com
## as mesmas nuvens do ArenaMap flutuando por cima, mais lentas e mais
## opacas que na arena — aqui não têm unidade nenhuma pra tapar.
const SKY_TOP := Color(0.42, 0.62, 0.88)
const SKY_BOTTOM := Color(0.74, 0.86, 0.95)
const CLOUDS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_01.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_03.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_05.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_07.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Decorations/Clouds/Clouds_08.png"),
]
const CLOUD_COUNT := 7
const CLOUD_SPEED := 26.0  ## px/s no alpha máximo; as fracas andam mais devagar
const CLOUD_WIDTH := 576.0
const CLOUD_LAYOUT_SEED := 20260907

var _cards: Array[Node2D] = []
var _blink_time := 0.0
var _show_hint := true
var _clouds: Array[Sprite2D] = []


func _ready() -> void:
	_spawn_cards()
	_spawn_clouds()


## Nuvem mais opaca = mais perto = mais rápida, igual ArenaMap._build_clouds.
func _spawn_clouds() -> void:
	var vp := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.seed = CLOUD_LAYOUT_SEED
	for _i in CLOUD_COUNT:
		var sprite := Sprite2D.new()
		sprite.texture = CLOUDS[rng.randi() % CLOUDS.size()]
		sprite.centered = false
		sprite.scale = Vector2.ONE * rng.randf_range(1.0, 2.0)
		sprite.position = Vector2(rng.randf() * vp.x, rng.randf() * vp.y * 0.6)
		sprite.modulate = Color(1.0, 1.0, 1.0, rng.randf_range(0.55, 0.9))
		add_child(sprite)
		_clouds.append(sprite)


func _spawn_cards() -> void:
	var count := PLAYER_CONFIGS.size()
	## Distribui os cards horizontalmente ao redor do centro da janela.
	var vp := get_viewport_rect().size
	var total_w := CARD_SPACING * (count - 1)
	var start_x := vp.x * 0.5 - total_w * 0.5

	for i in count:
		var card: Node2D = CARD_SCENE.instantiate()
		card.position = Vector2(start_x + CARD_SPACING * i, vp.y * 0.5 + 20.0)
		add_child(card)
		card._setup(i, PLAYER_CONFIGS[i][0], PLAYER_CONFIGS[i][1], PLAYER_CONFIGS[i][2])
		_cards.append(card)


func _process(delta: float) -> void:
	_blink_time += delta
	_show_hint = fmod(_blink_time, 1.2) < 0.85
	var vp := get_viewport_rect().size
	for sprite in _clouds:
		sprite.position.x += CLOUD_SPEED * sprite.modulate.a * delta
		if sprite.position.x > vp.x:
			sprite.position.x = -CLOUD_WIDTH * sprite.scale.x
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	## ESPAÇO ou ENTER: vai para a arena.
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	## Céu em gradiente (as nuvens, filhas do nó, desenham por cima em seguida).
	const BANDS := 24
	var band_h := vp.y / BANDS
	for i in BANDS:
		draw_rect(Rect2(0.0, i * band_h, vp.x, band_h + 1.0),
			SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(BANDS - 1)), true)

	## Título: faixa de papel do pack, igual ao HUD, com tinta em vez de texto claro.
	var title := "ESCOLHA SEU GUERREIRO"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	var title_rect := Rect2(vp.x * 0.5 - ts.x * 0.5 - 24.0, 40.0, ts.x + 48.0, 56.0)
	PackUI.nine(self, PAPER, title_rect, PAPER_CAP)
	draw_string(font,
		Vector2(vp.x * 0.5 - ts.x * 0.5, 78.0),
		title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28, INK)

	## Dica: "ESPAÇO para iniciar" (pisca), também em faixa de papel.
	if _show_hint:
		var hint := "[ ESPAÇO ]  iniciar"
		var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		var hint_rect := Rect2(vp.x * 0.5 - hs.x * 0.5 - 16.0, vp.y - 76.0, hs.x + 32.0, 40.0)
		PackUI.nine(self, PAPER, hint_rect, PAPER_CAP)
		draw_string(font,
			Vector2(vp.x * 0.5 - hs.x * 0.5, vp.y - 50.0),
			hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18, INK)

