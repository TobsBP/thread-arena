class_name Kingdom
extends RefCounted

## Reino: banco de recursos compartilhado, árvore de evolução comprada e a
## distribuição dos trabalhadores por profissão. Dado puro, só main thread —
## quem desenha é o CastleMenu/HUD, quem deposita é main.gd (_try_harvest).
## Os trabalhadores ainda não nascem: aqui é só número, pronto pra quando
## eles virarem unidade.

enum Job { LUMBERJACK, MINER, BUTCHER, HEALER }
const JOB_TITLES := ["Lenhador", "Minerador", "Açougueiro", "Curandeiro"]

## Banco infinito: compra/constrói sem gastar. A coleta continua somando em
## wood/gold, então desligar volta à economia de verdade sem mexer em mais
## nada. A trava de level da árvore vale igual com ele ligado.
const INFINITE_BANK := true
const HOUSE_WORKERS := 2  ## moradia que cada Casa construída soma

var wood := 0
var gold := 0
var max_workers := 2
var job_cap: Array[int] = [2, 0, 0, 0]  ## 0 = profissão travada
var assigned: Array[int] = [2, 0, 0, 0]
var bought: Dictionary[StringName, bool] = {}
var built: Dictionary[StringName, int] = {}  ## construções prontas, por tipo


func deposit(kind: String, n := 1) -> void:
	if kind == "wood":
		wood += n
	elif kind == "gold":
		gold += n


## Texto do saldo pro HUD/menu: "∞" com o banco infinito.
func bank(kind: String) -> String:
	if INFINITE_BANK:
		return "∞"
	return str(wood if kind == "wood" else gold)


func has_funds(w: int, g: int) -> bool:
	return INFINITE_BANK or (wood >= w and gold >= g)


func pay(w: int, g: int) -> void:
	if INFINITE_BANK:
		return
	wood -= w
	gold -= g


## Por que o nó não compra agora: "" = pode; senão o motivo curto que o menu
## mostra no lugar do botão.
func buy_block(id: StringName, level: int) -> String:
	var node := UpgradeTree.find(id)
	if bought.has(id):
		return "comprado"
	if node.requires != &"" and not bought.has(node.requires):
		return "requer %s" % UpgradeTree.find(node.requires).title
	if level < node.level:
		return "Level %d" % node.level
	if not has_funds(node.wood, node.gold):
		return "sem recurso"
	return ""


func buy(id: StringName, level: int) -> bool:
	if not buy_block(id, level).is_empty():
		return false
	var node := UpgradeTree.find(id)
	pay(node.wood, node.gold)
	bought[id] = true
	var fx: Dictionary = node.effect
	max_workers += fx.get("max_workers", 0)
	if fx.has("job"):
		job_cap[fx.job] += fx.get("cap", 0)
	return true


## Mesma ideia do buy_block, pra construção: liberada pela árvore e paga.
func build_block(kind: StringName) -> String:
	var info: Dictionary = BuildSite.KINDS[kind]
	if not bought.has(info.unlock):
		return "requer %s" % UpgradeTree.find(info.unlock).title
	if not has_funds(info.wood, info.gold):
		return "sem recurso"
	return ""


func pay_build(kind: StringName) -> void:
	var info: Dictionary = BuildSite.KINDS[kind]
	pay(info.wood, info.gold)


## A obra terminou: conta e aplica o que for do reino (a Casa mora aqui; o
## resto — entrega, torre, vida — é main.gd quem aplica).
func on_built(kind: StringName) -> void:
	built[kind] = built.get(kind, 0) + 1
	if kind == &"house":
		max_workers += HOUSE_WORKERS


func is_job_unlocked(job: int) -> bool:
	return job_cap[job] > 0


func total_assigned() -> int:
	var n := 0
	for a in assigned:
		n += a
	return n


func free_workers() -> int:
	return max_workers - total_assigned()


## +1/-1 numa profissão, sem passar do limite dela nem do total.
func assign(job: int, delta: int) -> bool:
	var n := assigned[job] + delta
	if n < 0 or n > job_cap[job]:
		return false
	if delta > 0 and free_workers() <= 0:
		return false
	assigned[job] = n
	return true
