extends Node2D

## Tela de título: primeira coisa que abre (run/main_scene). Nome do jogo e
## um "aperte ESPAÇO" piscando, mesmo céu com nuvens do character_select
## pra não ter um corte visual na transição entre as duas telas.
##
## Fluxo:
##   title_screen.tscn → (ESPAÇO) → character_select.tscn

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const PAPER_CAP := 20.0
const INK := Color(0.16, 0.13, 0.09)
const INK_SOFT := Color(0.35, 0.27, 0.19)

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
const CLOUD_LAYOUT_SEED := 20260907  ## mesmo seed do character_select: nuvens alinhadas na transição

## Trio de guerreiros parados de enfeite atrás do título — mesmos skins do
## seletor de personagem (menos o preto, pra não empatar visualmente com o
## inimigo vermelho da arena).
const BANNERS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Warrior/Warrior_Idle.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Yellow Units/Warrior/Warrior_Idle.png"),
]
const BANNER_FRAME_SIZE := Vector2(192.0, 192.0)
const BANNER_FPS := 8.0
const BANNER_FRAMES := 8
const BANNER_SPACING := 150.0

## Ovelhas atravessando a tela, cada uma no seu ritmo — mesmos assets e
## frame_size que main.gd usa pra cenário vivo (Player.frame_size = 128, não
## 192: a ovelha é um sprite bem menor que o dos guerreiros, e é desenhada em
## tamanho natural, sem escala extra — só copiamos esse mesmo tamanho aqui).
const SHEEP_MOVE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Terrain/Resources/Meat/Sheep/Sheep_Move.png")
const SHEEP_FRAME_SIZE := Vector2(128.0, 128.0)
const SHEEP_FPS := 8.0
const SHEEP_FRAMES := 4  ## Sheep_Move.png tem 4 quadros (main.gd: r_frames=4)
## Escala relativa ao guerreiro: BANNER_FRAME_SIZE é 192, a ovelha é 128 —
## aplicando o mesmo fator de scale dos guerreiros (1.6) o tamanho fica igual
## à proporção real das duas texturas lado a lado.
const SHEEP_SCALE := 1.6
const SHEEP_COUNT := 3
const SHEEP_BOB_HEIGHT := 3.0
## Travessia: cada ovelha vai de uma borda da tela à outra e volta, com
## velocidade, fase e altura próprias (semeadas uma vez em _ready), pra não
## andarem sincronizadas.
const SHEEP_SPEED_MIN := 30.0
const SHEEP_SPEED_MAX := 55.0
const SHEEP_LAYOUT_SEED := 20260907

var _clouds: Array[Sprite2D] = []
var _blink_time := 0.0
var _show_hint := true
var _anim_time := 0.0

## Estado por ovelha: velocidade própria, fase inicial e um leve offset
## vertical (linha dos pés não exatamente igual entre elas).
var _sheep_speed: Array[float] = []
var _sheep_phase: Array[float] = []
var _sheep_row: Array[float] = []


func _ready() -> void:
	_spawn_clouds()
	_spawn_sheep()


func _spawn_sheep() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SHEEP_LAYOUT_SEED
	for _i in SHEEP_COUNT:
		_sheep_speed.append(rng.randf_range(SHEEP_SPEED_MIN, SHEEP_SPEED_MAX))
		_sheep_phase.append(rng.randf())
		_sheep_row.append(rng.randf_range(0.0, 40.0))


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


func _process(delta: float) -> void:
	_blink_time += delta
	_anim_time += delta
	_show_hint = fmod(_blink_time, 1.2) < 0.85
	var vp := get_viewport_rect().size
	for sprite in _clouds:
		sprite.position.x += CLOUD_SPEED * sprite.modulate.a * delta
		if sprite.position.x > vp.x:
			sprite.position.x = -CLOUD_WIDTH * sprite.scale.x
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file("res://scenes/character_select.tscn")


func _ink(pos: Vector2, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos + Vector2(1, 1), text, align, width, size, Color(1, 1, 1, 0.7))
	draw_string(font, pos, text, align, width, size, color)


func _draw() -> void:
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font

	## Céu em gradiente, igual character_select (as nuvens desenham por cima).
	const BANDS := 24
	var band_h := vp.y / BANDS
	for i in BANDS:
		draw_rect(Rect2(0.0, i * band_h, vp.x, band_h + 1.0),
			SKY_TOP.lerp(SKY_BOTTOM, float(i) / float(BANDS - 1)), true)

	## Trio de guerreiros animados, de enfeite, atrás do título.
	var frame := int(_anim_time * BANNER_FPS) % BANNER_FRAMES
	var src := Rect2(frame * BANNER_FRAME_SIZE.x, 0.0, BANNER_FRAME_SIZE.x, BANNER_FRAME_SIZE.y)
	var scale := 1.6
	var dw := BANNER_FRAME_SIZE.x * scale
	var dh := BANNER_FRAME_SIZE.y * scale
	var total_w := BANNER_SPACING * (BANNERS.size() - 1)
	var banner_top := vp.y * 0.5 - dh * 0.5 + 30.0
	var first_banner_cx := vp.x * 0.5 - total_w * 0.5
	for i in BANNERS.size():
		var cx := first_banner_cx + BANNER_SPACING * i
		draw_texture_rect_region(BANNERS[i],
			Rect2(cx - dw * 0.5, banner_top, dw, dh), src,
			Color(1, 1, 1, 0.9))

	## Ovelhas atravessando a tela, cada uma no seu ritmo, abaixo do trio.
	var sheep_frame := int(_anim_time * SHEEP_FPS) % SHEEP_FRAMES
	var sheep_src := Rect2(sheep_frame * SHEEP_FRAME_SIZE.x, 0.0, SHEEP_FRAME_SIZE.x, SHEEP_FRAME_SIZE.y)
	var sdw := SHEEP_FRAME_SIZE.x * SHEEP_SCALE
	var sdh := SHEEP_FRAME_SIZE.y * SHEEP_SCALE
	var feet_y := banner_top + dh * 0.60  ## um pouco mais abaixo dos pés do trio
	var left_edge := sdw * 0.5
	var walk_range := vp.x - sdw
	for i in SHEEP_COUNT:
		## Triângulo 0↔1 por ovelha: vai de uma borda à outra e volta, cada
		## uma com sua velocidade e fase (sem pulo na virada).
		var phase := fmod(_anim_time * _sheep_speed[i] / (2.0 * walk_range) + _sheep_phase[i], 1.0)
		var t := 1.0 - absf(phase * 2.0 - 1.0)
		var x := left_edge + t * walk_range
		var going_right := phase < 0.5
		var flip := 1.0 if going_right else -1.0
		var bob := sin(_anim_time * 3.0 + i) * SHEEP_BOB_HEIGHT
		var center := Vector2(x, feet_y + _sheep_row[i] + bob)
		draw_set_transform(center, 0.0, Vector2(flip, 1.0))
		draw_texture_rect_region(SHEEP_MOVE,
			Rect2(-sdw * 0.5, -sdh * 0.5, sdw, sdh), sheep_src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## Placa de papel com o título do jogo.
	var title := "THREAD ARENA"
	var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, 44)
	var title_rect := Rect2(vp.x * 0.5 - ts.x * 0.5 - 36.0, vp.y * 0.18, ts.x + 72.0, 84.0)
	PackUI.nine(self, PAPER, title_rect, PAPER_CAP)
	_ink(Vector2(vp.x * 0.5 - ts.x * 0.5, title_rect.position.y + 58.0),
		title, 44, INK)

	var subtitle := "serial vs. paralelo, ao vivo"
	var ss := font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	_ink(Vector2(vp.x * 0.5 - ss.x * 0.5, title_rect.end.y + 22.0), subtitle, 15, INK_SOFT)

	## Dica piscando, em papel.
	if _show_hint:
		var hint := "[ ESPAÇO ]  começar"
		var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_CENTER, -1, 18)
		var hint_rect := Rect2(vp.x * 0.5 - hs.x * 0.5 - 16.0, vp.y - 96.0, hs.x + 32.0, 40.0)
		PackUI.nine(self, PAPER, hint_rect, PAPER_CAP)
		_ink(Vector2(vp.x * 0.5 - hs.x * 0.5, vp.y - 70.0), hint, 18, INK)
