class_name UpgradeTree

## Catálogo da árvore de evolução do castelo principal — mesmo espírito do
## EnemyTypes: só dado, quem interpreta o `effect` é Kingdom.buy(). Cada ramo
## é uma coluna no CastleMenu e os nós descem em sequência (`requires` é o de
## cima). Balanceamento todo aqui.
##
## effect: {max_workers = N} soma no total de trabalhadores;
##         {job = Kingdom.Job.X, cap = N} soma no limite da profissão (sair de
##         0 é o que libera ela); {build = &"tipo"} só libera a construção
##         (Kingdom.build_block confere se o nó foi comprado).

const BRANCHES := ["Moradia", "Lenhador", "Minerador", "Açougueiro", "Curandeiro", "Construções"]

const NODES := [
	# Moradia
	{id = &"houses_1", branch = 0, title = "Casas I", desc = "+2 trabalhadores no total",
		wood = 5, gold = 0, level = 1, requires = &"", effect = {max_workers = 2}},
	{id = &"houses_2", branch = 0, title = "Casas II", desc = "+2 trabalhadores no total",
		wood = 10, gold = 3, level = 3, requires = &"houses_1", effect = {max_workers = 2}},
	{id = &"houses_3", branch = 0, title = "Casas III", desc = "+2 trabalhadores no total",
		wood = 20, gold = 8, level = 6, requires = &"houses_2", effect = {max_workers = 2}},
	# Lenhador (já começa liberado, com 2 vagas)
	{id = &"axes_1", branch = 1, title = "Machados I", desc = "+1 vaga de Lenhador",
		wood = 6, gold = 0, level = 2, requires = &"", effect = {job = Kingdom.Job.LUMBERJACK, cap = 1}},
	{id = &"axes_2", branch = 1, title = "Machados II", desc = "+1 vaga de Lenhador",
		wood = 12, gold = 4, level = 4, requires = &"axes_1", effect = {job = Kingdom.Job.LUMBERJACK, cap = 1}},
	# Minerador
	{id = &"miner", branch = 2, title = "Liberar Minerador", desc = "libera a profissão (1 vaga)",
		wood = 8, gold = 0, level = 3, requires = &"", effect = {job = Kingdom.Job.MINER, cap = 1}},
	{id = &"picks_1", branch = 2, title = "Picaretas I", desc = "+1 vaga de Minerador",
		wood = 10, gold = 2, level = 4, requires = &"miner", effect = {job = Kingdom.Job.MINER, cap = 1}},
	{id = &"picks_2", branch = 2, title = "Picaretas II", desc = "+1 vaga de Minerador",
		wood = 16, gold = 6, level = 6, requires = &"picks_1", effect = {job = Kingdom.Job.MINER, cap = 1}},
	# Açougueiro
	{id = &"butcher", branch = 3, title = "Liberar Açougueiro", desc = "libera a profissão (1 vaga)",
		wood = 10, gold = 4, level = 5, requires = &"", effect = {job = Kingdom.Job.BUTCHER, cap = 1}},
	{id = &"knives_1", branch = 3, title = "Facas I", desc = "+1 vaga de Açougueiro",
		wood = 12, gold = 6, level = 6, requires = &"butcher", effect = {job = Kingdom.Job.BUTCHER, cap = 1}},
	# Curandeiro
	{id = &"healer", branch = 4, title = "Liberar Curandeiro", desc = "libera a profissão (1 vaga)",
		wood = 10, gold = 10, level = 7, requires = &"", effect = {job = Kingdom.Job.HEALER, cap = 1}},
	{id = &"herbs_1", branch = 4, title = "Ervas I", desc = "+1 vaga de Curandeiro",
		wood = 14, gold = 12, level = 8, requires = &"healer", effect = {job = Kingdom.Job.HEALER, cap = 1}},
	# Construções: cada nó libera um tipo na aba Construir
	{id = &"carpentry", branch = 5, title = "Carpintaria", desc = "libera construir Casa",
		wood = 3, gold = 0, level = 1, requires = &"", effect = {build = &"house"}},
	{id = &"masonry", branch = 5, title = "Alvenaria", desc = "libera construir Castelo",
		wood = 10, gold = 4, level = 3, requires = &"carpentry", effect = {build = &"castle"}},
	{id = &"watch", branch = 5, title = "Vigias", desc = "libera construir Torre",
		wood = 10, gold = 6, level = 4, requires = &"masonry", effect = {build = &"tower"}},
	{id = &"training", branch = 5, title = "Treino", desc = "libera construir Quartel",
		wood = 12, gold = 8, level = 5, requires = &"watch", effect = {build = &"barracks"}},
]


static func find(id: StringName) -> Dictionary:
	for n in NODES:
		if n.id == id:
			return n
	return {}


## Nós de um ramo, de cima pra baixo (a ordem do NODES já é a da coluna).
static func branch_nodes(branch: int) -> Array:
	return NODES.filter(func(n: Dictionary) -> bool: return n.branch == branch)


## Level em que a profissão libera — pro menu mostrar "Level N" na trava.
static func job_unlock_level(job: int) -> int:
	for n in NODES:
		var fx: Dictionary = n.effect
		if fx.get("job", -1) == job and n.requires == &"":
			return n.level
	return 1
