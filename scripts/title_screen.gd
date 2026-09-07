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

## Avatar central: um dos retratos do HUD, só de enfeite aqui.
const BANNER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Warrior/Warrior_Idle.png")
const BANNER_FRAME_SIZE := Vector2(192.0, 192.0)
const BANNER_FPS := 8.0
const BANNER_FRAMES := 8

var _clouds: Array[Sprite2D] = []
var _blink_time := 0.0
var _show_hint := true
var _anim_time := 0.0


func _ready() -> void:
	_spawn_clouds()


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

	## Guerreiro animado, de enfeite, atrás do título.
	var frame := int(_anim_time * BANNER_FPS) % BANNER_FRAMES
	var src := Rect2(frame * BANNER_FRAME_SIZE.x, 0.0, BANNER_FRAME_SIZE.x, BANNER_FRAME_SIZE.y)
	var scale := 1.6
	var dw := BANNER_FRAME_SIZE.x * scale
	var dh := BANNER_FRAME_SIZE.y * scale
	draw_texture_rect_region(BANNER,
		Rect2(vp.x * 0.5 - dw * 0.5, vp.y * 0.5 - dh * 0.5 + 30.0, dw, dh), src,
		Color(1, 1, 1, 0.9))

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
