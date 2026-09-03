class_name UnitSprite
extends Node2D

## Desenho de uma unidade (player, inimigo ou ovelha). O dado continua sendo
## um Player RefCounted — este nó só lê `unit.pos` na main thread e desenha,
## que é o que permite o y-sort com o cenário: unidade e árvore são irmãs no
## mesmo Decor, ordenadas pela linha dos pés.
##
## A tarefa da Thread nunca toca aqui: ela escreve no Player, este nó lê
## depois da barreira, no _process.

## HUD da unidade, do pack: barra de vida + faixa com o nome.
const UI_BAR := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Base.png")
const UI_BAR_FILL := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/SmallBar_Fill.png")
const UI_RIBBON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Ribbons/SmallRibbons.png")
const DUST := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Dust_01.png")
const BOOM := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png")

## Recortes: as duas texturas têm as pontas nas bordas e o miolo em x 128..192.
const BAR_SRC := Rect2(49, 22, 222, 19)
const BAR_CAP := 15.0
const RIBBON_SIZE := Vector2(315, 54)  ## faixa arredondada; o y muda por cor
const RIBBON_CAP := 62.0
const RADIUS := 20.0  ## círculo de reserva, se a unidade não tiver textura

const DUST_FRAMES := 8
const DUST_FPS := 14.0
const DUST_SIZE := 64.0
const BOOM_FRAMES := 8
const BOOM_SIZE := 192.0

var unit: Player
var show_badge := true  ## ovelha não tem nome nem barra de vida


static func create(u: Player, badge := true) -> UnitSprite:
	var s := UnitSprite.new()
	s.unit = u
	s.show_badge = badge
	return s


## A ordenação do Decor é por position.y, então o nó fica na linha dos pés e
## o desenho sobe a partir dela.
func _process(_delta: float) -> void:
	position = unit.pos + Player.FEET
	queue_redraw()


func _draw() -> void:
	var body := -Player.FEET  # centro do corpo, relativo aos pés
	if show_badge:
		# Sombra elíptica sob os pés (a ovelha já vem com a sua no sprite).
		draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2.ZERO, 20.0, Color(0.0, 0.0, 0.0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_dust()
	_draw_body(body)
	_draw_boom(body)
	if not show_badge or unit.is_dead():
		return

	# Faixa com o nome e barra de vida, ambas do pack de UI.
	PackUI.hslice(self, UI_RIBBON, Rect2(body + Vector2(-30, -92), Vector2(60, 22)),
			Rect2(Vector2(2, unit.ribbon_y), RIBBON_SIZE), RIBBON_CAP)
	draw_string(
		ThemeDB.fallback_font,
		body + Vector2(-30, -75),
		"ENEMY" if unit.is_enemy else "P%d" % (unit.joy_device + 1),
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		12,
		Color(0.15, 0.12, 0.15)
	)

	var bar := Rect2(body + Vector2(-32, -68), Vector2(64, 19))
	PackUI.hslice(self, UI_BAR, bar, BAR_SRC, BAR_CAP)
	var ratio := clampf(unit.hp / unit.max_hp, 0.0, 1.0)
	if ratio > 0.0:
		# Faixa vermelha do asset: 3px de altura, 8px abaixo do topo da barra.
		draw_texture_rect_region(UI_BAR_FILL,
				Rect2(bar.position + Vector2(7, 8), Vector2((bar.size.x - 14) * ratio, 3)),
				Rect2(0, 30, 64, 3))


## Sprite animado, com flip ao virar pra esquerda.
func _draw_body(body: Vector2) -> void:
	var tex := unit.get_current_texture()
	if not tex:
		draw_circle(body, RADIUS, unit.color)
		return
	var fw := unit.frame_size.x
	var fh := unit.frame_size.y
	var src_rect := Rect2(unit.get_current_frame() * fw, 0, fw, fh)
	var dest_rect := Rect2(-fw * 0.5, -fh * 0.5, fw, fh)
	# Morte: sem sprite próprio no pack — tomba de lado e some.
	var t := 0.0 if not unit.is_dead() else minf(unit.death_time / Player.DEATH_TIME, 1.0)
	var dir := 1.0 if unit.facing_right else -1.0
	draw_set_transform(body, dir * t * PI * 0.5, Vector2(dir, 1.0))
	draw_texture_rect_region(tex, dest_rect, src_rect, Color(1, 1, 1, 1.0 - t))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Poeira nos pés enquanto corre: o ciclo vem do anim_time da própria unidade,
## então cada uma levanta pó no seu tempo.
func _draw_dust() -> void:
	if unit.is_dead() or not unit.is_running():
		return
	var frame := int(unit.anim_time * DUST_FPS) % DUST_FRAMES
	draw_texture_rect_region(DUST,
			Rect2(Vector2(-DUST_SIZE * 0.5, -DUST_SIZE * 0.7), Vector2(DUST_SIZE, DUST_SIZE)),
			Rect2(frame * DUST_SIZE, 0, DUST_SIZE, DUST_SIZE),
			Color(1, 1, 1, 0.8))


## Estouro no golpe que derruba: o pack não tem sprite de morte, então a
## explosão cobre o tombo nos primeiros quadros.
func _draw_boom(body: Vector2) -> void:
	if not unit.is_dead():
		return
	var frame := int(unit.death_time / Player.DEATH_TIME * BOOM_FRAMES)
	if frame >= BOOM_FRAMES:
		return
	draw_texture_rect_region(BOOM,
			Rect2(body - Vector2(BOOM_SIZE, BOOM_SIZE) * 0.5,
					Vector2(BOOM_SIZE, BOOM_SIZE)),
			Rect2(frame * BOOM_SIZE, 0, BOOM_SIZE, BOOM_SIZE))
