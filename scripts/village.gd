class_name Village
extends RefCounted

## O que os aldeões dividem: Mutex no estoque, Semaphore nas vagas e nas assadas prontas.
## Sempre try_wait(), nunca wait(): a Thread morre no fim do frame e bloquear travaria a main.

enum Res { WOOD, GOLD, MEAT }

const MINE_SLOTS := 2
const DEPOT_SLOTS := 2  ## quantos cabem dentro do armazém descarregando ao mesmo tempo
## Quanto rende uma viagem de aldeão, por Res (lenha, ouro, carne)
const LOAD: Array[float] = [3.0, 2.0, 1.0]
const FIRE_SLOTS := 1  ## um espeto só: semáforo binário
const FIRE_BURN_TIME := 25.0  ## segundos de fogo por lenha
const SITE_REACH := 90.0  ## perto o bastante do armazém/mina/fogueira pra parar
const EPS := 0.001  ## a carga entra em fatias (float): 1.0 pode chegar como 0.9999
## Janela entre ler e escrever o total, em iterações de trabalho falso.
const COUNT_WORK := 6000

## Pontos fixos, escritos uma vez por main.gd antes de qualquer Thread existir e só lidos depois.
var depot := Vector2.ZERO
var mine := Vector2.ZERO
var kitchen := Vector2.ZERO
var cook_spot := Vector2.ZERO  ## onde o cozinheiro fica pra girar a manivela do espeto
var light_spot := Vector2.ZERO  ## onde fica quem traz a lenha e acende o fogo
var door_spot := Vector2.ZERO  ## em frente à porta do armazém: daqui o aldeão entra

var use_mutex := true  ## só o depósito obedece: é ele que a demo quebra de propósito
## [V]: desligado, ninguém pede vaga e todo mundo entra de uma vez.
var use_semaphores := true
## Ritmo de trabalho de quem está na mina / no espeto.
var mine_rate := 1.0
var fire_rate := 1.0
var wood := 0.0
var gold := 0.0
var meat := 0.0  ## carne crua esperando o espeto
var counted := 0.0  ## total que o armazém registrou — compare com a soma de Player.delivered
var fire_fuel := 0.0  ## segundos de fogo restantes; <= 0 = apagada
var roasts := 0  ## assadas na mesa: espelho da contagem de roast_ready, que não dá pra ler

var mine_slots := Semaphore.new()
## Vagas da porta do armazém (quem entra); o mutex protege o estoque lá dentro.
var depot_slots := Semaphore.new()
var fire_slots := Semaphore.new()
var roast_ready := Semaphore.new()
var _lock := Mutex.new()


func _init() -> void:
	# Semaphore nasce em 0: cada post() é uma vaga livre.
	for _i in MINE_SLOTS:
		mine_slots.post()
	for _i in DEPOT_SLOTS:
		depot_slots.post()
	for _i in FIRE_SLOTS:
		fire_slots.post()


## Roda na Thread do aldeão, uma fatia da carga por frame (Player.UNLOAD_TIME)
func deposit(kind: int, amount: float) -> void:
	var locked := use_mutex
	if locked:
		_lock.lock()
	var seen := _stock(kind)
	var seen_total := counted
	var acc := 0.0
	for k in COUNT_WORK:
		acc += sqrt(float(k))
	_set_stock(kind, seen + amount)
	counted = seen_total + amount
	if locked:
		_lock.unlock()


## Soma direto, com lock, sem entrar em `counted`.
func add(kind: int, amount: float) -> void:
	_lock.lock()
	_set_stock(kind, _stock(kind) + amount)
	_lock.unlock()


## Tira do armazém se tiver.
func take(kind: int, amount: float) -> bool:
	_lock.lock()
	var ok := _stock(kind) >= amount - EPS
	if ok:
		_set_stock(kind, maxf(_stock(kind) - amount, 0.0))
	_lock.unlock()
	return ok


## A lenha chegou e pegou: mais FIRE_BURN_TIME de fogo.
func add_fuel() -> void:
	_lock.lock()
	fire_fuel += FIRE_BURN_TIME
	_lock.unlock()


func fire_lit() -> bool:
	return fire_fuel > 0.0


## Main thread, antes do dispatch: nenhuma Thread de aldeão está rodando.
func burn(delta: float) -> void:
	fire_fuel = maxf(fire_fuel - delta, 0.0)


## Produtor: o cozinheiro põe a assada na mesa.
func put_roast() -> void:
	_lock.lock()
	roasts += 1
	_lock.unlock()
	roast_ready.post()


## Consumidor: false se outro aldeão chegou antes e levou a última.
func take_roast() -> bool:
	if not roast_ready.try_wait():
		return false
	_lock.lock()
	roasts -= 1
	_lock.unlock()
	return true


func _stock(kind: int) -> float:
	match kind:
		Res.WOOD:
			return wood
		Res.GOLD:
			return gold
	return meat


func _set_stock(kind: int, value: float) -> void:
	match kind:
		Res.WOOD:
			wood = value
		Res.GOLD:
			gold = value
		_:
			meat = value
