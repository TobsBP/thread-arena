extends Node2D

## Tela de seleção de personagem (lobby).
## Instancia 3 PlayerCard, um por player controlável, e aguarda [ESPAÇO]
## para iniciar a arena com os skins escolhidos.
##
## Fluxo:
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

## Espaçamento horizontal entre o centro de cada card.
const CARD_SPACING := 260.0

var _cards: Array[Node2D] = []
var _blink_time := 0.0
var _show_hint := true


func _ready() -> void:
	_spawn_cards()


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
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	## ESPAÇO ou ENTER: vai para a arena.
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	## Fundo escuro de tela cheia.
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.05, 0.06, 0.09), true)

	## Título.
	var title := "ESCOLHA SEU GUERREIRO"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28)
	draw_string(font,
		Vector2(vp.x * 0.5 - ts.x * 0.5, 72.0),
		title, HORIZONTAL_ALIGNMENT_CENTER, -1, 28,
		Color(0.92, 0.85, 0.60))

	## Linha decorativa abaixo do título.
	draw_line(Vector2(vp.x * 0.2, 88.0), Vector2(vp.x * 0.8, 88.0),
		Color(0.92, 0.85, 0.60, 0.4), 1.5)

	## Dica: "ESPAÇO para iniciar" (pisca).
	if _show_hint:
		var hint := "[ ESPAÇO ]  iniciar"
		var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		draw_string(font,
			Vector2(vp.x * 0.5 - hs.x * 0.5, vp.y - 48.0),
			hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18,
			Color(0.75, 0.75, 0.80, 0.9))
