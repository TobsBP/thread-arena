class_name CastleMenu
extends Control

## Menu do castelo principal: árvore de evolução, distribuição dos
## trabalhadores por profissão e a escolha de construção. Abre pausando o
## jogo (main.gd chama open() com um player perto do castelo e [T]) e fica
## vivo durante a pausa (process_mode ALWAYS, na cena).
##
## Mesma regra do HUD: não decide regra nenhuma — quem diz se compra, se
## cabe mais um trabalhador, se dá pra construir é o Kingdom. Aqui é cursor,
## desenho e chamar o Kingdom. Construir só escolhe o tipo: quem cobra e
## posiciona é main.gd, depois que o menu fecha (sinal build_chosen).

signal build_chosen(kind: StringName)

enum Tab { TREE, WORKERS, BUILD }
const TAB_TITLES := ["Evolução", "Trabalhadores", "Construir"]

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const WOOD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_02.png")
const GOLD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png")
const PAPER_CAP := 20.0
const INK := Color(0.16, 0.13, 0.09)
const INK_SOFT := Color(0.35, 0.27, 0.19)
const GOOD := Color(0.18, 0.42, 0.20)
const BAD := Color(0.63, 0.27, 0.12)
const CURSOR := Color(0.85, 0.55, 0.10)
const MAX_PANEL := Vector2(1080, 560)
const PAD := 34.0
const CARD_H := 78.0
const ROW_H := 54.0

var _kingdom: Kingdom
var _level := 1
var _tab := 0  ## Tab
var _col := 0  ## Evolução: ramo
var _row := 0  ## Evolução: nó no ramo; outras abas: linha
var _flash := ""  ## resposta da última ação ("comprado!", "sem recurso"...)
## Áreas clicáveis do último _draw(): [Rect2, Dictionary do que faz]. Refeito
## a cada desenho — o layout depende do tamanho da tela e da aba.
var _hits: Array = []


func open(kingdom: Kingdom, level: int) -> void:
	_kingdom = kingdom
	_level = level
	_flash = ""
	_clamp_cursor()
	visible = true
	get_tree().paused = true
	queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var action := _action(event)
	if action.is_empty():
		return
	get_viewport().set_input_as_handled()
	match action:
		"close":
			close()
			return
		"tab":
			_tab = wrapi(_tab + 1, 0, Tab.size())
			_row = 0
			_flash = ""
		"up":
			_row -= 1
		"down":
			_row += 1
		"left":
			if _tab == Tab.TREE:
				_col -= 1
			elif _tab == Tab.WORKERS:
				_adjust(-1)
		"right":
			if _tab == Tab.TREE:
				_col += 1
			elif _tab == Tab.WORKERS:
				_adjust(1)
		"minus":
			if _tab == Tab.WORKERS:
				_adjust(-1)
		"ok":
			_confirm()
			if not visible:
				return
	_clamp_cursor()
	queue_redraw()


## Teclado: setas/WASD/IJKL navegam (os três esquemas de player), Enter/F/O/
## KP_0 confirmam, Backspace/Q/U/KP_1 tiram 1, Tab troca a aba, ESC/T fecham.
## Controle: direcional, A confirma, X tira 1, LB/RB trocam a aba, B fecha.
func _action(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key and key.pressed:
		var k := key.physical_keycode
		# Segurar repete só a navegação; confirmar/fechar é um toque por vez.
		if key.echo and not (k in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
				KEY_W, KEY_S, KEY_A, KEY_D, KEY_I, KEY_K, KEY_J, KEY_L]):
			return ""
		match k:
			KEY_ESCAPE, KEY_T:
				return "close"
			KEY_TAB, KEY_E:
				return "tab"
			KEY_UP, KEY_W, KEY_I:
				return "up"
			KEY_DOWN, KEY_S, KEY_K:
				return "down"
			KEY_LEFT, KEY_A, KEY_J:
				return "left"
			KEY_RIGHT, KEY_D, KEY_L:
				return "right"
			KEY_ENTER, KEY_KP_ENTER, KEY_F, KEY_O, KEY_KP_0:
				return "ok"
			KEY_BACKSPACE, KEY_Q, KEY_U, KEY_KP_1:
				return "minus"
	var pad := event as InputEventJoypadButton
	if pad and pad.pressed:
		match pad.button_index:
			JOY_BUTTON_B:
				return "close"
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER:
				return "tab"
			JOY_BUTTON_DPAD_UP:
				return "up"
			JOY_BUTTON_DPAD_DOWN:
				return "down"
			JOY_BUTTON_DPAD_LEFT:
				return "left"
			JOY_BUTTON_DPAD_RIGHT:
				return "right"
			JOY_BUTTON_A:
				return "ok"
			JOY_BUTTON_X:
				return "minus"
	return ""


func _confirm() -> void:
	match _tab:
		Tab.TREE:
			var node := _selected_node()
			var why := _kingdom.buy_block(node.id, _level)
			if why.is_empty():
				_kingdom.buy(node.id, _level)
				_flash = "%s comprado!" % node.title
			else:
				_flash = why
		Tab.WORKERS:
			_adjust(1)
		Tab.BUILD:
			var kind: StringName = BuildSite.ORDER[_row]
			var why := _kingdom.build_block(kind)
			if not why.is_empty():
				_flash = why
				return
			close()
			build_chosen.emit(kind)


func _adjust(delta: int) -> void:
	var job := _row
	if not _kingdom.is_job_unlocked(job):
		_flash = "Level %d" % UpgradeTree.job_unlock_level(job)
	elif not _kingdom.assign(job, delta):
		_flash = "sem trabalhador livre" if delta > 0 and _kingdom.free_workers() <= 0 \
				else "limite da profissão"
	else:
		_flash = ""


func _clamp_cursor() -> void:
	match _tab:
		Tab.TREE:
			_col = wrapi(_col, 0, UpgradeTree.BRANCHES.size())
			_row = clampi(_row, 0, UpgradeTree.branch_nodes(_col).size() - 1)
		Tab.WORKERS:
			_row = wrapi(_row, 0, Kingdom.JOB_TITLES.size())
		Tab.BUILD:
			_row = wrapi(_row, 0, BuildSite.ORDER.size())


## Mouse: passar por cima move o cursor (mesmo realce do teclado), clicar
## faz o que Enter faria naquele item. Em cima de tudo, então engole o clique
## mesmo fora das áreas (mouse_filter STOP na cena).
func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var click := event as InputEventMouseButton
	if not motion and not (click and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()
	var hit := _hit_at(event.position)
	if hit.is_empty():
		return
	if motion:
		if _hover(hit):
			queue_redraw()
		return
	if hit.has("close"):
		close()
		return
	if hit.has("tab"):
		_tab = hit.tab
		_row = 0
		_flash = ""
	elif hit.has("job") and hit.has("delta"):
		_row = hit.job
		_adjust(hit.delta)
	elif hit.has("job"):
		_hover(hit)  ## a linha só seleciona; somar/tirar é nos botões −/+
	else:
		_hover(hit)
		_confirm()
		if not visible:
			return
	_clamp_cursor()
	queue_redraw()


## O último registrado ganha: os botões −/+ entram depois da linha deles.
func _hit_at(pos: Vector2) -> Dictionary:
	for i in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(pos):
			return _hits[i][1]
	return {}


## Cursor vai pro item sob o mouse; true se mudou (pra só redesenhar aí).
func _hover(hit: Dictionary) -> bool:
	var col := _col
	var row := _row
	if hit.has("col"):
		_col = hit.col
		_row = hit.row
	elif hit.has("job"):
		_row = hit.job
	elif hit.has("build"):
		_row = hit.build
	return col != _col or row != _row


func _selected_node() -> Dictionary:
	return UpgradeTree.branch_nodes(_col)[_row]


# --- Desenho -------------------------------------------------------------

func _draw() -> void:
	if not _kingdom:
		return
	_hits.clear()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))
	var panel_size := Vector2(minf(size.x - 40.0, MAX_PANEL.x), minf(size.y - 40.0, MAX_PANEL.y))
	var panel := Rect2((size - panel_size) * 0.5, panel_size)
	PackUI.nine(self, PAPER, panel, PAPER_CAP)
	var inner := panel.grow(-PAD)

	_ink(inner.position + Vector2(0, 18), "CASTELO", 22, INK)
	_draw_bank(Vector2(inner.end.x - 44, inner.position.y + 18))
	# Fechar: o "✕" no canto, pro mouse (ESC/T seguem valendo).
	var close_box := Rect2(inner.end.x - 28, inner.position.y - 4, 28, 28)
	draw_rect(close_box, Color(0, 0, 0, 0.12))
	_ink(close_box.position + Vector2(8, 21), "✕", 18, INK)
	_hits.append([close_box, {close = true}])
	var tx := inner.position.x + 150.0
	for i in TAB_TITLES.size():
		var label: String = ("▸ %s" if i == _tab else "  %s") % TAB_TITLES[i]
		_ink(Vector2(tx, inner.position.y + 18), label, 16, CURSOR if i == _tab else INK_SOFT)
		_hits.append([Rect2(tx - 4, inner.position.y - 4, 150, 30), {tab = i}])
		tx += 160.0

	var body := Rect2(inner.position + Vector2(0, 40), inner.size - Vector2(0, 84))
	match _tab:
		Tab.TREE:
			_draw_tree(body)
		Tab.WORKERS:
			_draw_workers(body)
		Tab.BUILD:
			_draw_build(body)

	var foot := Vector2(inner.position.x, inner.end.y - 6)
	if not _flash.is_empty():
		_ink(foot + Vector2(0, -22), _flash, 15, GOOD if _flash.ends_with("!") else BAD)
	_ink(foot, "mouse: clique   setas: mover   Enter/F: confirmar   Q: tirar   Tab: aba   ESC/T: fechar",
			13, INK_SOFT)


## "madeira N  ouro N  trabalhadores X/Y" alinhado à direita do topo.
func _draw_bank(right: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var wood := _kingdom.bank("wood") + "   "
	var rest := "%s      livres %d / %d" % [
		_kingdom.bank("gold"), _kingdom.free_workers(), _kingdom.max_workers]
	var wood_w := font.get_string_size(wood, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var rest_w := font.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := right.x - (52.0 + wood_w + rest_w)
	draw_texture_rect(WOOD_ICON, Rect2(x, right.y - 20, 24, 24), false)
	_ink(Vector2(x + 26, right.y), wood, 16, INK)
	x += 26.0 + wood_w
	draw_texture_rect(GOLD_ICON, Rect2(x, right.y - 20, 24, 24), false)
	_ink(Vector2(x + 26, right.y), rest, 16, INK)


## Uma coluna por ramo, os nós descendo em sequência; o detalhe do nó
## selecionado vai embaixo.
func _draw_tree(body: Rect2) -> void:
	var branches := UpgradeTree.BRANCHES.size()
	var col_w := body.size.x / branches
	for b in branches:
		var x := body.position.x + b * col_w
		_ink(Vector2(x + 6, body.position.y + 14), UpgradeTree.BRANCHES[b], 15, INK)
		var nodes := UpgradeTree.branch_nodes(b)
		for r in nodes.size():
			var node: Dictionary = nodes[r]
			var card := Rect2(x + 4, body.position.y + 26 + r * (CARD_H + 10), col_w - 8, CARD_H)
			if r > 0:
				draw_line(Vector2(card.get_center().x, card.position.y - 10),
						Vector2(card.get_center().x, card.position.y), INK_SOFT, 2.0)
			_draw_card(card, node, b == _col and r == _row)
			_hits.append([card, {col = b, row = r}])

	var sel := _selected_node()
	var why := _kingdom.buy_block(sel.id, _level)
	var info := "%s — %s" % [sel.title, sel.desc]
	if not why.is_empty():
		info += "   (%s)" % why
	_ink(Vector2(body.position.x, body.end.y - 8), info, 15, INK)


func _draw_card(card: Rect2, node: Dictionary, selected: bool) -> void:
	var why := _kingdom.buy_block(node.id, _level)
	var fill := Color(1, 1, 1, 0.35)
	var status := "comprar"
	var status_col := GOOD
	if why == "comprado":
		fill = Color(0.35, 0.65, 0.35, 0.35)
		status = "✔ comprado"
	elif not why.is_empty():
		fill = Color(0, 0, 0, 0.10)
		status = why
		status_col = BAD
	draw_rect(card, fill)
	draw_rect(card, CURSOR if selected else Color(0, 0, 0, 0.25), false, 3.0 if selected else 1.0)
	_ink(card.position + Vector2(6, 18), node.title, 13, INK)
	_draw_cost(card.position + Vector2(6, 42), node.wood, node.gold)
	_ink(card.position + Vector2(6, card.size.y - 8), status, 12, status_col)


func _draw_cost(pos: Vector2, wood: int, gold: int) -> void:
	var x := pos.x
	if wood > 0:
		draw_texture_rect(WOOD_ICON, Rect2(x, pos.y - 14, 18, 18), false)
		_ink(Vector2(x + 19, pos.y), str(wood), 13, INK)
		x += 50
	if gold > 0:
		draw_texture_rect(GOLD_ICON, Rect2(x, pos.y - 14, 18, 18), false)
		_ink(Vector2(x + 19, pos.y), str(gold), 13, INK)
	if wood <= 0 and gold <= 0:
		_ink(pos, "grátis", 13, INK_SOFT)


func _draw_workers(body: Rect2) -> void:
	for job in Kingdom.JOB_TITLES.size():
		var y := body.position.y + 30 + job * ROW_H
		var row := Rect2(body.position.x, y - 26, body.size.x, ROW_H - 10)
		_hits.append([row, {job = job}])
		if job == _row:
			draw_rect(row, CURSOR, false, 3.0)
		var title: String = Kingdom.JOB_TITLES[job]
		if not _kingdom.is_job_unlocked(job):
			draw_rect(row, Color(0, 0, 0, 0.10))
			_ink(Vector2(row.position.x + 12, y), title, 18, INK_SOFT)
			_ink(Vector2(row.position.x + 260, y), "travado — Level %d" % UpgradeTree.job_unlock_level(job),
					15, BAD)
			continue
		_ink(Vector2(row.position.x + 12, y), title, 18, INK)
		_button(Rect2(row.position.x + 250, row.position.y + 6, 32, 32), "−", {job = job, delta = -1})
		_ink(Vector2(row.position.x + 296, y), "%d / %d" % [
			_kingdom.assigned[job], _kingdom.job_cap[job]], 18, INK)
		_button(Rect2(row.position.x + 360, row.position.y + 6, 32, 32), "+", {job = job, delta = 1})
	var foot_y := body.position.y + 30 + Kingdom.JOB_TITLES.size() * ROW_H + 10
	_ink(Vector2(body.position.x + 12, foot_y), "Livres: %d   —   Total: %d   (os trabalhadores ainda não aparecem no mapa)" % [
		_kingdom.free_workers(), _kingdom.max_workers], 15, INK_SOFT)


## Botãozinho quadrado (madeira escura + sinal claro) que também vira área clicável.
func _button(r: Rect2, label: String, hit: Dictionary) -> void:
	draw_rect(r, Color(0.12, 0.10, 0.08, 0.85))
	draw_string(ThemeDB.fallback_font, r.position + Vector2(r.size.x * 0.5 - 6, r.size.y - 8), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.97, 0.92, 0.80))
	_hits.append([r, hit])


func _draw_build(body: Rect2) -> void:
	for i in BuildSite.ORDER.size():
		var kind: StringName = BuildSite.ORDER[i]
		var info: Dictionary = BuildSite.KINDS[kind]
		var y := body.position.y + 30 + i * ROW_H
		var row := Rect2(body.position.x, y - 26, body.size.x, ROW_H - 10)
		var why := _kingdom.build_block(kind)
		_hits.append([row, {build = i}])
		if not why.is_empty():
			draw_rect(row, Color(0, 0, 0, 0.10))
		if i == _row:
			draw_rect(row, CURSOR, false, 3.0)
		_ink(Vector2(row.position.x + 12, y), info.title, 18, INK if why.is_empty() else INK_SOFT)
		_draw_cost(Vector2(row.position.x + 170, y), info.wood, info.gold)
		_ink(Vector2(row.position.x + 290, y), "%ds  —  %s" % [int(info.time), info.desc], 15, INK)
		var built: int = _kingdom.built.get(kind, 0)
		_ink(Vector2(row.end.x - 12, y), why if not why.is_empty() else "construídas: %d" % built,
				14, BAD if not why.is_empty() else GOOD, HORIZONTAL_ALIGNMENT_RIGHT, 220.0)
	var foot_y := body.position.y + 30 + BuildSite.ORDER.size() * ROW_H + 10
	_ink(Vector2(body.position.x + 12, foot_y),
			"Escolha e posicione no mapa: o ataque do player confirma, o 2º botão cancela.",
			15, INK_SOFT)


func _ink(pos: Vector2, text: String, font_size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	var font := ThemeDB.fallback_font
	if align == HORIZONTAL_ALIGNMENT_RIGHT and width > 0.0:
		pos.x -= width
	draw_string(font, pos + Vector2(1, 1), text, align, width, font_size, Color(1, 1, 1, 0.5))
	draw_string(font, pos, text, align, width, font_size, color)
