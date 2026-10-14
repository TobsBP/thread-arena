class_name Arrow
extends RefCounted

## Flecha disparada pelo Archer. Roda inteira na main thread (main.gd): é
## leve, não precisa de Thread. O dano em si (main.gd _resolve_arrow_hits)
## só rola enquanto ela está voando (not landed) — `hit` marca que já acertou,
## pra sumir na hora em vez de continuar voando/pousada.
##
## Mesmo conceito nos dois modos: sai de `start_pos`, faz lançamento oblíquo
## (interpola até `target_pos` enquanto `height` — deslocamento visual "pra
## cima" no desenho, não é posição real — sobe e desce numa parábola) e
## "aterrissa" exatamente no alvo — para de vez e fica parada no chão até
## LIFETIME acabar. Só muda o alcance/altura do arco entre os dois:
##   SHOT: tiro direto do arqueiro — arco baixo e rápido.
##   RAIN: skill de segurar o ataque — arco mais alto e longo, cara de volley.
enum Mode { SHOT, RAIN }

const LIFETIME := 3.0  ## segundos até sumir do mapa (voando + parada no chão)
const TEXTURE := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/Units/Purple Units/Archer/Arrow.png")

const SHOT_FLIGHT_TIME := 0.55
const SHOT_ARC_HEIGHT := 60.0  ## pico do arco, em pixels

const RAIN_FLIGHT_TIME := 0.9
const RAIN_ARC_HEIGHT := 160.0

var pos: Vector2  ## posição real atual (interpolada de start_pos até target_pos)
var start_pos: Vector2
var target_pos: Vector2
var dir: Vector2  ## normalizado, start->target (só a componente horizontal do arco)
var mode: Mode
var age := 0.0
var landed := false
var hit := false  ## já acertou alguém (ver main.gd _resolve_arrow_hits)
var height := 0.0  ## deslocamento visual "pra cima" pro desenho; 0 = no chão
var visual_angle: float  ## inclinação pra cima subindo, pra baixo descendo (ver step())
var trail: Array[Vector2] = []  ## últimas posições (draw_pos), pra desenhar o rastro
const TRAIL_LEN := 8


func _init(from: Vector2, to: Vector2, arrow_mode: Mode = Mode.SHOT) -> void:
	start_pos = from
	target_pos = to
	dir = (to - from).normalized() if not to.is_equal_approx(from) else Vector2.RIGHT
	mode = arrow_mode
	pos = from
	visual_angle = dir.angle()


func step(delta: float) -> void:
	age += delta
	if landed:
		return
	var flight_time := SHOT_FLIGHT_TIME if mode == Mode.SHOT else RAIN_FLIGHT_TIME
	var arc_height := SHOT_ARC_HEIGHT if mode == Mode.SHOT else RAIN_ARC_HEIGHT
	var t := clampf(age / flight_time, 0.0, 1.0)
	pos = start_pos.lerp(target_pos, t)
	height = 4.0 * arc_height * t * (1.0 - t)  ## parábola: 0 no início/fim, pico no meio

	# Inclinação = direção da velocidade real (horizontal + subida/descida do
	# arco), não só a mira horizontal — por isso a ponta acompanha a curva.
	var forward_speed := start_pos.distance_to(target_pos) / flight_time
	var vertical_rate := 4.0 * arc_height * (1.0 - 2.0 * t) / flight_time  ## d(height)/dt
	var visual_velocity := dir * forward_speed + Vector2(0, -1) * vertical_rate
	if visual_velocity.length_squared() > 0.0001:
		visual_angle = visual_velocity.angle()

	if age >= flight_time:
		landed = true
		pos = target_pos
		height = 0.0
		# SHOT aterrissa deitada (na direção do tiro); RAIN crava na vertical,
		# tipo dardo caindo do céu.
		visual_angle = dir.angle() if mode == Mode.SHOT else Vector2.DOWN.angle()
		trail.clear()  ## pousada não deixa rastro
		return

	trail.append(draw_pos())
	if trail.size() > TRAIL_LEN:
		trail.remove_at(0)


func is_expired() -> bool:
	return age >= LIFETIME


func draw_pos() -> Vector2:
	return pos - Vector2(0, height)
