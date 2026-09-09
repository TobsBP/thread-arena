class_name Dynamite
extends RefCounted

## Arremessada pelo Goblin da Dinamite (main.gd _throw_dynamite, disparada no
## mesmo instante que Arrow._fire_arrow: attack_time == 0.0 recém decidido
## por Player.chase()). Faz o mesmo lançamento oblíquo da flecha até pousar
## no alvo; pousada, fica com o pavio queimando por FUSE_TIME e SÓ ENTÃO
## estoura — o dano em área (main.gd _resolve_dynamite_hits) acontece nesse
## instante exato, não no impacto. Roda inteira na main thread: é leve, não
## precisa de Thread.

const TEXTURE := preload("res://assets/Tiny Swords/Tiny Swords (Update 010)/Factions/Goblins/Troops/TNT/Dynamite/Dynamite.png")
const FRAME_SIZE := 64.0
const FRAMES := 6  ## tira de 6 quadros (o pavio chiando), conferida abrindo o PNG
const SPIN_FPS := 10.0

## Reaproveita o estouro que UnitSprite já usa na morte — mesmo vocabulário
## visual, sem precisar de asset novo.
const EXPLOSION_TEXTURE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Particle FX/Explosion_01.png")
const EXPLOSION_FRAMES := 8
const EXPLOSION_SIZE := 192.0
const EXPLOSION_DURATION := 0.4

const FLIGHT_TIME := 0.6
const ARC_HEIGHT := 90.0
const FUSE_TIME := 0.55  ## parada, pavio chiando, antes de estourar
const BLAST_RADIUS := 80.0

var pos: Vector2  ## posição real atual (interpolada de start_pos até target_pos)
var start_pos: Vector2
var target_pos: Vector2
var dir: Vector2
var damage: float  ## herdado do attack_damage de quem arremessou (ver EnemyTypes)
var age := 0.0
var height := 0.0  ## deslocamento visual "pra cima"; 0 = no chão
var visual_angle := 0.0
var _blast_consumed := false  ## garante 1 dano só, mesmo com is_exploding() true por vários frames


func _init(from: Vector2, to: Vector2, dmg: float) -> void:
	start_pos = from
	target_pos = to
	dir = (to - from).normalized() if not to.is_equal_approx(from) else Vector2.RIGHT
	damage = dmg
	pos = from


func step(delta: float) -> void:
	age += delta
	if age < FLIGHT_TIME:
		var t := age / FLIGHT_TIME
		pos = start_pos.lerp(target_pos, t)
		height = 4.0 * ARC_HEIGHT * t * (1.0 - t)  ## parábola: 0 no início/fim, pico no meio
		visual_angle += delta * 12.0  ## gira enquanto voa (a arte não tem quadro de giro)
	else:
		pos = target_pos
		height = 0.0


func is_flying() -> bool:
	return age < FLIGHT_TIME


func is_exploding() -> bool:
	var t := age - FLIGHT_TIME - FUSE_TIME
	return t >= 0.0 and t < EXPLOSION_DURATION


## true na primeira chamada depois que o pavio termina, false depois disso —
## é o gatilho de dano de main.gd, que roda todo frame mas só pode aplicar
## a explosão uma vez.
func should_blast() -> bool:
	if _blast_consumed or age < FLIGHT_TIME + FUSE_TIME:
		return false
	_blast_consumed = true
	return true


func is_expired() -> bool:
	return age >= FLIGHT_TIME + FUSE_TIME + EXPLOSION_DURATION


func draw_pos() -> Vector2:
	return pos - Vector2(0, height)


func spin_frame() -> int:
	return int(age * SPIN_FPS) % FRAMES


func explosion_frame() -> int:
	var t := age - FLIGHT_TIME - FUSE_TIME
	return mini(int(t / EXPLOSION_DURATION * EXPLOSION_FRAMES), EXPLOSION_FRAMES - 1)
