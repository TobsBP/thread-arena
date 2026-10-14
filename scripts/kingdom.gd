class_name Kingdom
extends RefCounted

## Reino: árvore de evolução comprada e a distribuição dos trabalhadores por
## profissão. Dado puro, só main thread — quem desenha é o CastleMenu/HUD.
##
## O banco não mora aqui: é o estoque da Village, o mesmo que os aldeões
## enchem (e que o mutex protege). Comprar evolução e erguer construção
## gastam a lenha e o ouro de verdade que eles trouxeram.
##
## Os números daqui mandam nos aldeões do mapa (main.gd): `max_workers` é
## quantos existem (_sync_workers) e `assigned` quantos trabalham em cada
## profissão (_assign_job); os que sobram ficam livres.

enum Job { LUMBERJACK, MINER, BUTCHER, HEALER }
const JOB_TITLES := ["Lenhador", "Minerador", "Açougueiro", "Curandeiro"]

## Banco infinito: compra/constrói sem gastar — só pra testar a árvore sem
## esperar a coleta. A trava de level vale igual com ele ligado.
const INFINITE_BANK := false
const HOUSE_WORKERS := 2  ## moradia que cada Casa construída soma

var village: Village  ## o estoque de verdade; main.gd liga ao criar a vila
## Começa com 2 lenhadores e 1 minerador: o minerador é o que faz o ouro
## entrar desde o início, mesmo no modo sem mobs.
var max_workers := 3
var job_cap: Array[int] = [2, 1, 0, 0]  ## 0 = profissão travada
var assigned: Array[int] = [2, 1, 0, 0]
var bought: Dictionary[StringName, bool] = {}
var built: Dictionary[StringName, int] = {}  ## construções prontas, por tipo


## Entrega do Camponês jogável (main.gd _try_harvest): vai pro mesmo estoque.
func deposit(kind: String, n := 1) -> void:
	village.add(Village.Res.WOOD if kind == "wood" else Village.Res.GOLD, n)


## Unidades inteiras no estoque (a carga dos aldeões entra em fatias).
func stock(kind: String) -> int:
	return floori((village.wood if kind == "wood" else village.gold) + Village.EPS)


## Texto do saldo pro HUD/menu: "∞" com o banco infinito.
func bank(kind: String) -> String:
	if INFINITE_BANK:
		return "∞"
	return str(stock(kind))


func has_funds(w: int, g: int) -> bool:
	return INFINITE_BANK or (stock("wood") >= w and stock("gold") >= g)


## Gasta do estoque da vila — com o lock dele, mesmo sendo main thread e o
## menu rodando com o jogo pausado: é a mesma porta que as Threads usam.
func pay(w: int, g: int) -> void:
	if INFINITE_BANK:
		return
	village.take(Village.Res.WOOD, w)
	village.take(Village.Res.GOLD, g)


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
	auto_assign()
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
		auto_assign()


## Trabalhador livre não fica parado esperando o jogador lembrar da aba: a
## cada compra, quem está sobrando vai pra profissão liberada com menos gente
## (a que acabou de abrir, com zero, ganha primeiro). A aba Trabalhadores
## continua mandando — isto só dá o primeiro arranjo.
func auto_assign() -> void:
	while free_workers() > 0:
		var best := -1
		for job in job_cap.size():
			if assigned[job] < job_cap[job] and (best < 0 or assigned[job] < assigned[best]):
				best = job
		if best < 0:
			return
		assigned[best] += 1


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
