class_name DamageNumber
extends RefCounted

## Número flutuante de dano/cura — sobe e some. Leve, roda na main thread
## junto com o resto dos efeitos transitórios (Arrow, MeatDrop): sem Thread
## própria, não precisa.

const LIFETIME := 1.1
const HOLD_TIME := 0.5  ## fica no auge (tamanho/alfa máximos) até começar a sumir
const RISE_SPEED := 46.0
const DAMAGE_COLOR := Color(1.0, 0.25, 0.2)
const HEAL_COLOR := Color(0.35, 1.0, 0.4)

var pos: Vector2
var text: String
var color: Color
var age := 0.0


## `heal` só muda a cor (verde) — o número em si já vem pronto de quem chamou.
func _init(spawn_pos: Vector2, amount: float, heal := false) -> void:
	# Nasce acima da cabeça (não em cima da barra de vida) e com um pequeno
	# espalhamento horizontal: dois acertos no mesmo frame não empilham.
	pos = spawn_pos + Vector2(randf_range(-10.0, 10.0), -70.0)
	text = "+%d" % int(round(amount)) if heal else "-%d" % int(round(amount))
	color = HEAL_COLOR if heal else DAMAGE_COLOR


func step(delta: float) -> void:
	age += delta
	pos.y -= RISE_SPEED * delta


func is_expired() -> bool:
	return age >= LIFETIME


## 1.0 até HOLD_TIME, depois cai até 0 no fim da vida — segura no auge em vez
## de começar a sumir na hora, pra dar tempo de ler.
func alpha() -> float:
	if age < HOLD_TIME:
		return 1.0
	return clampf(1.0 - (age - HOLD_TIME) / (LIFETIME - HOLD_TIME), 0.0, 1.0)


## Cresce rápido ao nascer (pop) e depois assenta no tamanho normal.
func scale() -> float:
	return 1.0 + 0.6 * (1.0 - clampf(age / 0.15, 0.0, 1.0))
