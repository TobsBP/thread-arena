extends Node2D

## Card de seleção de um único player na tela de Character Select.
## Recebe player_index e key_prev/key_next via _setup() e cicla os skins
## usando PlayerConfig. Emite skin_changed(player_index) ao navegar.
##
## Desenhado em papel do pack, igual ao HUD (PackUI.nine sobre RegularPaper),
## pra não destoar do resto da UI.

signal skin_changed(player_index: int)

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const PAPER_CAP := 20.0

const INK := Color(0.16, 0.13, 0.09)
const INK_SOFT := Color(0.35, 0.27, 0.19)

## Nomes de exibição dos skins, na mesma ordem que PlayerConfig.SKINS.
const SKIN_LABELS := {
	"blue":   "AZUL",
	"purple": "ROXO",
	"yellow": "AMARELO",
	"black":  "PRETO",
}

## Texturas idle (8 frames, 192×192) para preview — mesmos assets do main.gd.
const IDLE_TEXTURES := {
	"blue":   preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png"),
	"purple": preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Idle.png"),
	"yellow": preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png"),
	"black":  preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Black Units/Warrior/Warrior_Idle.png"),
}

## Cores de destaque por skin (borda do card e badge do player).
const SKIN_COLORS := {
	"blue":   Color.CORNFLOWER_BLUE,
	"purple": Color(0.65, 0.42, 0.86),
	"yellow": Color(0.96, 0.78, 0.22),
	"black":  Color(0.55, 0.55, 0.60),
}

## Teclas do controle de teclado deste player para navegar no card.
## Definidas externamente via _setup().
var _player_index := 0
var _key_prev := KEY_A   ## tecla "esquerda" deste player
var _key_next := KEY_D   ## tecla "direita" deste player
var _joy_device := 0

## Animação do sprite de preview.
var _anim_time := 0.0
const _IDLE_FPS := 8.0
const _IDLE_FRAMES := 8
const _FRAME_SIZE := Vector2(192.0, 192.0)

## Layout interno (calculado em _ready, baseado em card_size).
const CARD_SIZE := Vector2(220.0, 320.0)
const CARD_PADDING := 16.0

## Flag: este card está "pronto" (confirmado pelo player)?
var ready_confirmed := false


## Configura o card para um player específico.
## key_prev/key_next são os physical keycodes do esquema deste player.
func _setup(player_index: int, key_prev: int, key_next: int, joy_device: int) -> void:
	_player_index = player_index
	_key_prev = key_prev
	_key_next = key_next
	_joy_device = joy_device


## Constrói o nome de exibição do player (P1, P2, P3) com suas teclas.
func _player_label() -> String:
	match _player_index:
		0: return "P1  (WASD)"
		1: return "P2  (Setas)"
		2: return "P3  (IJKL)"
	return "P%d" % (_player_index + 1)


func _process(delta: float) -> void:
	_anim_time += delta
	_handle_input()
	queue_redraw()


func _handle_input() -> void:
	## Navegação: tecla "esquerda" do player = skin anterior; "direita" = próximo.
	if Input.is_physical_key_pressed(_key_prev) and not _prev_held:
		_prev_held = true
		PlayerConfig.prev_skin(_player_index)
		emit_signal("skin_changed", _player_index)
	elif not Input.is_physical_key_pressed(_key_prev):
		_prev_held = false

	if Input.is_physical_key_pressed(_key_next) and not _next_held:
		_next_held = true
		PlayerConfig.next_skin(_player_index)
		emit_signal("skin_changed", _player_index)
	elif not Input.is_physical_key_pressed(_key_next):
		_next_held = false

	## Analógico esquerdo: eixo X acima de 0.5 para navegar (com debounce).
	var joy_x := Input.get_joy_axis(_joy_device, JOY_AXIS_LEFT_X)
	if joy_x < -0.5 and not _joy_left_held:
		_joy_left_held = true
		PlayerConfig.prev_skin(_player_index)
		emit_signal("skin_changed", _player_index)
	elif joy_x >= -0.5:
		_joy_left_held = false

	if joy_x > 0.5 and not _joy_right_held:
		_joy_right_held = true
		PlayerConfig.next_skin(_player_index)
		emit_signal("skin_changed", _player_index)
	elif joy_x <= 0.5:
		_joy_right_held = false

var _prev_held := false
var _next_held := false
var _joy_left_held := false
var _joy_right_held := false


## Texto com um contorno escuro atrás, igual ao HUD (papel claro por trás).
func _ink(pos: Vector2, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(1, 1, 1, 0.7))
	draw_string(font, pos, text, align, width, size, color)


func _draw() -> void:
	var skin := PlayerConfig.skins[_player_index]
	var col: Color = SKIN_COLORS[skin]
	var half := CARD_SIZE * 0.5
	var font := ThemeDB.fallback_font

	## Fundo do card: papel do pack, mesmo nine-patch do HUD.
	PackUI.nine(self, PAPER, Rect2(-half, CARD_SIZE), PAPER_CAP)

	## Título: nome do player + teclas.
	var title := _player_label()
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	_ink(Vector2(-ts.x * 0.5, -half.y + CARD_PADDING + 14),
		title, 14, col.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER)

	## Sprite de preview animado (idle, centrado verticalmente).
	var tex: Texture2D = IDLE_TEXTURES[skin]
	if tex:
		var frame := int(_anim_time * _IDLE_FPS) % _IDLE_FRAMES
		var src := Rect2(frame * _FRAME_SIZE.x, 0.0, _FRAME_SIZE.x, _FRAME_SIZE.y)
		var scale := 0.72  ## reduz o sprite de 192px para caber no card
		var dw := _FRAME_SIZE.x * scale
		var dh := _FRAME_SIZE.y * scale
		var dest := Rect2(-dw * 0.5, -half.y + 44.0, dw, dh)
		draw_texture_rect_region(tex, dest, src)

	## Setas de navegação ◄ ►
	var arrow_y := half.y - 58.0
	_ink(Vector2(-half.x + CARD_PADDING, arrow_y), "◄", 20, INK)
	_ink(Vector2(half.x - CARD_PADDING - 20, arrow_y), "►", 20, INK)

	## Nome do skin selecionado.
	var label: String = SKIN_LABELS.get(skin, skin.to_upper())
	var ls := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
	_ink(Vector2(-ls.x * 0.5, arrow_y + 4.0), label, 16, INK, HORIZONTAL_ALIGNMENT_CENTER)

	## Linha separadora acima das setas.
	draw_line(Vector2(-half.x + CARD_PADDING, arrow_y - 30.0),
		Vector2(half.x - CARD_PADDING, arrow_y - 30.0),
		INK_SOFT.lerp(Color(1, 1, 1, 0), 0.5), 1.0)
