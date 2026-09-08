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
## Caveira que aparece e desaparece — animação de morte de verdade (pack
## Update 010). Só pra quem não é ovelha (ver is_sheep) — ovelha vira baforada.
const DEAD := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Knights/Troops/Dead/Dead.png")
## Estouro rápido junto com a caveira, só pra dar mais impacto na morte.
const EXPLOSION := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png")
## Aura verde do Curandeiro — toca em volta de quem pegou carne (ver is_healing).
const HEAL_FX := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Blue Units/Monk/Heal_Effect.png")
## Contador de recursos dos lenhadores/mineradores (mesmos ícones do prompt de coleta em main.gd).
const WOOD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_02.png")
const GOLD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png")
## Escudinho que pisca quando o bloqueio absorve um golpe (ver is_blocking_fx).
const SHIELD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_06.png")

## Recortes: as duas texturas têm as pontas nas bordas e o miolo em x 128..192.
const BAR_SRC := Rect2(49, 22, 222, 19)
const BAR_CAP := 15.0
const RIBBON_SIZE := Vector2(315, 54)  ## faixa arredondada; o y muda por cor
const RIBBON_CAP := 62.0
const RADIUS := 20.0  ## círculo de reserva, se a unidade não tiver textura
const LOW_HP_RATIO := 0.25  ## abaixo disso, a barra pisca
const LOW_HP_PULSE_SPEED := 9.0  ## rad/s do piscar

const DUST_FRAMES := 8
const DUST_FPS := 14.0
const DUST_SIZE := 64.0
## Folha 896x256 = grade de 7 colunas x 2 linhas, lida em ordem (linha 0
## primeiro): caveira aparece, assenta e encolhe até sumir. Toca a
## Player.DEATH_TIME inteira — dura mais que o estouro de baixo.
const DEAD_COLS := 7
const DEAD_ROWS := 2
const DEAD_FRAMES := DEAD_COLS * DEAD_ROWS
const DEAD_SIZE := 128.0
## Estouro: rápido, só no começo da morte — o resto do tempo é só a caveira.
const EXPLOSION_FRAMES := 8
const EXPLOSION_SIZE := 192.0
const EXPLOSION_DURATION := 0.4
## Baforada da ovelha: reaproveita o quadro de poeira de corrida, mas maior
## e só uma vez, no instante da morte — sem caveira, ela é bicho, não gente.
const POOF_DURATION := 0.5
const POOF_SCALE := 1.9
## Aura de cura: 11 quadros, toca a HEAL_FX_DURATION inteira em volta do corpo.
const HEAL_FRAMES := 11
const HEAL_SIZE := 192.0

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
	_draw_dead(body)
	_draw_heal_fx(body)
	_draw_block_fx(body)
	if not show_badge or unit.is_dead():
		return

	_draw_resource_count(body)

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
		# Vida baixa: a faixa pisca (clareia e escurece) pra chamar atenção.
		var fill_tint := Color.WHITE
		if ratio < LOW_HP_RATIO:
			var pulse := 0.5 + 0.5 * sin(unit.anim_time * LOW_HP_PULSE_SPEED)
			fill_tint = Color.WHITE.lerp(Color(1.0, 1.0, 1.0, 0.35), pulse)
		# Faixa vermelha do asset: 3px de altura, 8px abaixo do topo da barra.
		draw_texture_rect_region(UI_BAR_FILL,
				Rect2(bar.position + Vector2(7, 8), Vector2((bar.size.x - 14) * ratio, 3)),
				Rect2(0, 30, 64, 3), fill_tint)

	# Estamina: barrinha amarela logo abaixo da de vida — mesmo asset da barra
	# de vida, só tintado, sem precisar de um sprite novo pra isso.
	var stam_bar := Rect2(bar.position + Vector2(0, bar.size.y - 2.0), Vector2(64, 10))
	PackUI.hslice(self, UI_BAR, stam_bar, BAR_SRC, BAR_CAP * stam_bar.size.y / bar.size.y)
	var stam_ratio := clampf(unit.stamina / unit.max_stamina, 0.0, 1.0)
	if stam_ratio > 0.0:
		draw_texture_rect_region(UI_BAR_FILL,
				Rect2(stam_bar.position + Vector2(7, 4), Vector2((stam_bar.size.x - 14) * stam_ratio, 3)),
				Rect2(0, 30, 64, 3), Color(1.0, 0.82, 0.15))


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
	# Morte: tomba de lado e some enquanto a caveira (_draw_dead) sobe por cima.
	var t := 0.0 if not unit.is_dead() else minf(unit.death_time / Player.DEATH_TIME, 1.0)
	var dir := 1.0 if unit.facing_right else -1.0
	# Flash vermelho de "acabei de tomar dano" — multiplica a cor, não precisa
	# de shader: apaga verde/azul e deixa passar o vermelho da própria arte.
	var tint := Color(1, 1, 1, 1.0 - t)
	if unit.is_flashing():
		tint = Color(1, 0.35, 0.35, 1.0 - t)
	elif unit.is_charging:
		# Carregando o golpe especial: pisca num dourado, cada vez mais rápido
		# — dá pra "ler" que o golpe forte tá quase saindo.
		var pulse := 0.5 + 0.5 * sin(unit.anim_time * 16.0)
		tint = Color(1.0, 1.0 - 0.35 * pulse, 0.35 + 0.3 * pulse, 1.0 - t)
	# "Soco" do impacto: infla e volta rápido, só no instante de tomar o golpe.
	draw_set_transform(body, dir * t * PI * 0.5, Vector2(dir, 1.0) * unit.pop_scale())
	draw_texture_rect_region(tex, dest_rect, src_rect, tint)
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


## Morte: ovelha só dá uma baforada e some (é bicho, não solta caveira);
## quem mais morre ganha o estouro rápido + a caveira, que fica mais tempo.
func _draw_dead(body: Vector2) -> void:
	if not unit.is_dead():
		return
	if unit.is_sheep:
		_draw_poof(body)
		return
	_draw_explosion(body)
	_draw_skull(body)


func _draw_explosion(body: Vector2) -> void:
	var frame := int(unit.death_time / EXPLOSION_DURATION * EXPLOSION_FRAMES)
	if frame >= EXPLOSION_FRAMES:
		return
	draw_texture_rect_region(EXPLOSION,
			Rect2(body - Vector2(EXPLOSION_SIZE, EXPLOSION_SIZE) * 0.5,
					Vector2(EXPLOSION_SIZE, EXPLOSION_SIZE)),
			Rect2(frame * EXPLOSION_SIZE, 0, EXPLOSION_SIZE, EXPLOSION_SIZE))


func _draw_skull(body: Vector2) -> void:
	var frame := int(unit.death_time / Player.DEATH_TIME * DEAD_FRAMES)
	if frame >= DEAD_FRAMES:
		return
	var col := frame % DEAD_COLS
	var row := frame / DEAD_COLS
	draw_texture_rect_region(DEAD,
			Rect2(body - Vector2(DEAD_SIZE, DEAD_SIZE) * 0.5,
					Vector2(DEAD_SIZE, DEAD_SIZE)),
			Rect2(col * DEAD_SIZE, row * DEAD_SIZE, DEAD_SIZE, DEAD_SIZE))


func _draw_poof(body: Vector2) -> void:
	var frame := int(unit.death_time / POOF_DURATION * DUST_FRAMES)
	if frame >= DUST_FRAMES:
		return
	var s := DUST_SIZE * POOF_SCALE
	draw_texture_rect_region(DUST,
			Rect2(body - Vector2(s, s) * 0.5, Vector2(s, s)),
			Rect2(frame * DUST_SIZE, 0, DUST_SIZE, DUST_SIZE),
			Color(1, 1, 1, 0.9))


## Aura verde em volta de quem acabou de comer a carne.
func _draw_heal_fx(body: Vector2) -> void:
	if not unit.is_healing():
		return
	var frame := int(unit.heal_fx_time / Player.HEAL_FX_DURATION * HEAL_FRAMES)
	frame = mini(frame, HEAL_FRAMES - 1)
	draw_texture_rect_region(HEAL_FX,
			Rect2(body - Vector2(HEAL_SIZE, HEAL_SIZE) * 0.5, Vector2(HEAL_SIZE, HEAL_SIZE)),
			Rect2(frame * HEAL_SIZE, 0, HEAL_SIZE, HEAL_SIZE))


## Escudinho que aparece um instante sobre quem bloqueou um golpe (guard ativo).
func _draw_block_fx(body: Vector2) -> void:
	if not unit.is_blocking_fx():
		return
	var t := unit.block_fx_time / Player.BLOCK_FX_DURATION
	var a := clampf(1.0 - t, 0.0, 1.0)
	var s := 26.0 + 6.0 * (1.0 - a)  # cresce um pouco enquanto some
	var pos := body + Vector2(0, -78)
	draw_texture_rect(SHIELD_ICON, Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)),
			false, Color(1, 1, 1, a))


## Contador de madeira/ouro carregado, só pra quem tem machado/picareta (lenhador/minerador).
func _draw_resource_count(body: Vector2) -> void:
	if not unit.axe_texture:
		return
	if unit.wood <= 0 and unit.gold <= 0:
		return
	var pos := body + Vector2(36, -58)
	if unit.wood > 0:
		draw_texture_rect(WOOD_ICON, Rect2(pos, Vector2(16, 16)), false)
		draw_string(ThemeDB.fallback_font, pos + Vector2(18, 13), str(unit.wood),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.15, 0.12, 0.15))
		pos.y += 18
	if unit.gold > 0:
		draw_texture_rect(GOLD_ICON, Rect2(pos, Vector2(16, 16)), false)
		draw_string(ThemeDB.fallback_font, pos + Vector2(18, 13), str(unit.gold),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.15, 0.12, 0.15))
