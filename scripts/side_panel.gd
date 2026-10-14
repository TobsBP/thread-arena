class_name SidePanel
extends Control

## Canto direito: em cima o status da partida (level, banco, trabalhadores);
## no canto de baixo, sem fundo, os comandos de todos os players numa lista
## só (uma linha por ação, as teclas lado a lado com a cor de cada player) e,
## em destaque, o que dá pra fazer AGORA (chegou no castelo, perto de árvore,
## posicionando obra...). Mesma regra do HUD: só formata. Teclas e classe
## saem do Player; o contexto vem pronto de main.gd (_player_hints), que é
## quem sabe onde ficam castelo e árvore.

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const WOOD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_02.png")
const GOLD_ICON := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Icons/Icon_03.png")
const PAPER_CAP := 20.0
const INK := Color(0.16, 0.13, 0.09)
const BAD := Color(0.63, 0.27, 0.12)
const KEY_BG := Color(0.12, 0.10, 0.08, 0.88)
const KEY_FG := Color(0.97, 0.92, 0.80)
const WIDTH := 300.0
const MARGIN := 12.0
const PAD := 22.0
const STATUS_H := 58.0
## Card de comandos (sem fundo): menor que o resto do HUD.
const CMD_FONT := 12
const CMD_LINE := 17.0
const CMD_TEXT := Color(0.96, 0.93, 0.85)
const CMD_ACCENT := Color(1.0, 0.78, 0.30)

## 0 = status + controles, 1 = só status, 2 = nada. Segue o [H] do HUD.
var detail := 0
var _players: Array[Player] = []
var _hints: Array = []  ## por player: Array de [tecla, texto]
var _level := 1
var _no_mobs := false
var _kingdom: Kingdom


func update_panel(players: Array[Player], hints: Array, level: int, no_mobs: bool,
		kingdom: Kingdom) -> void:
	_players = players
	_hints = hints
	_level = level
	_no_mobs = no_mobs
	_kingdom = kingdom
	queue_redraw()


## Nome curto da tecla física: setas viram símbolo, teclado numérico "Num0".
static func key_name(code: int) -> String:
	match code:
		KEY_UP:
			return "↑"
		KEY_DOWN:
			return "↓"
		KEY_LEFT:
			return "←"
		KEY_RIGHT:
			return "→"
	if code >= KEY_KP_0 and code <= KEY_KP_9:
		return "Num%d" % (code - KEY_KP_0)
	return OS.get_keycode_string(code)


## O que o ataque e o 2º botão fazem em cada classe — "" = não tem.
static func _attack_name(p: Player) -> String:
	if p.is_archer:
		return "flecha"
	if p.is_monk:
		return "cura"
	if p.axe_texture:
		return "faca"
	if p.guard_texture and not p.special_texture:
		return "lança"
	return "golpe"


static func _action2_name(p: Player) -> String:
	if p.is_archer:
		return "mira"
	if p.is_monk:
		return ""
	if p.axe_texture:
		return "coleta"
	return "guarda"


## Lista única, sem bloco por player: uma linha por ação com as teclas de
## todos lado a lado, e as dicas do momento juntas (a mesma dica em dois
## players vira uma linha só, com as duas teclas). Cada item é
## [texto, Array de [tecla, cor do player], cor do texto].
func _rows() -> Array:
	var move: Array = []
	var atk: Array = []
	var act2: Array = []
	var atk_names: Array[String] = []
	var act2_names: Array[String] = []
	for p in _players:
		move.append([key_name(p.keys[0]) + key_name(p.keys[2]) + key_name(p.keys[1]) + key_name(p.keys[3]), p.color])
		atk.append([key_name(p.keys[4]), p.color])
		if not (_attack_name(p) in atk_names):
			atk_names.append(_attack_name(p))
		var a2 := _action2_name(p)
		if a2.is_empty():
			continue
		act2.append([key_name(p.keys[5]), p.color])
		if not (a2 in act2_names):
			act2_names.append(a2)
	var rows: Array = [
		["mover", move, CMD_TEXT],
		["atacar · %s (segurar: especial)" % " / ".join(atk_names), atk, CMD_TEXT],
	]
	if not act2.is_empty():
		rows.append(["2º botão · %s" % " / ".join(act2_names), act2, CMD_TEXT])

	var merged: Dictionary = {}  ## texto -> Array de [tecla, cor]
	var order: Array[String] = []
	for i in _players.size():
		var hints: Array = _hints[i] if i < _hints.size() else []
		for hint in hints:
			var text: String = hint[1]
			if not merged.has(text):
				merged[text] = []
				order.append(text)
			var key: String = hint[0]
			# Tecla compartilhada (o [T] do castelo) aparece uma vez só.
			if not key.is_empty() and not merged[text].any(func(k: Array) -> bool: return k[0] == key):
				merged[text].append([key, _players[i].color])
	for text in order:
		rows.append([text, merged[text], CMD_ACCENT])
	return rows


func _draw() -> void:
	if detail > 1 or not _kingdom:
		return
	var x0 := size.x - WIDTH - MARGIN
	var status := Rect2(x0, MARGIN, WIDTH, STATUS_H + PAD)
	PackUI.nine(self, PAPER, status, PAPER_CAP)
	_draw_status(status.grow(-PAD * 0.5))
	if detail > 0 or _players.is_empty():
		return

	# Comandos: sem papel, pequeno, no canto de baixo à direita — uma lista
	# só, sem bloco por player (a cor de cada um vai no risco da tecla).
	var rows := _rows()
	var right := size.x - MARGIN
	var y := size.y - MARGIN - CMD_LINE * rows.size() - 4.0
	for row in rows:
		_line(right, y, row[0], row[1], row[2])
		y += CMD_LINE
	_text_right(Vector2(right, y), "controle: analógico · A ataque · B 2º botão", CMD_FONT - 1,
			CMD_TEXT)


## Duas linhas: "LEVEL N" (+ SEM MOBS) e o banco com os ícones + trabalhadores.
func _draw_status(r: Rect2) -> void:
	var x := r.position.x + PAD * 0.5
	var y := r.position.y + 22
	_text(Vector2(x, y), "LEVEL %d" % _level, 18, INK)
	if _no_mobs:
		_text(Vector2(x + 90, y), "SEM MOBS", 13, BAD)
	y += 26
	draw_texture_rect(WOOD_ICON, Rect2(x - 2, y - 17, 22, 22), false)
	_text(Vector2(x + 22, y), _kingdom.bank("wood"), 15, INK)
	draw_texture_rect(GOLD_ICON, Rect2(x + 62, y - 17, 22, 22), false)
	_text(Vector2(x + 86, y), _kingdom.bank("gold"), 15, INK)
	_text(Vector2(x + 128, y), "trabalhadores %d/%d" % [
		_kingdom.total_assigned(), _kingdom.max_workers], 14, INK)


## Uma linha alinhada à direita: as teclas em plaquinhas escuras coladas em
## `right` (com um risco da cor do player embaixo) e o texto terminando logo
## antes delas.
func _line(right: float, y: float, text: String, keys: Array, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var tx := right
	for i in range(keys.size() - 1, -1, -1):
		var key: String = keys[i][0]
		var w := maxf(font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, CMD_FONT - 1).x + 8.0, 16.0)
		var box := Rect2(tx - w, y - 11, w, 15)
		draw_rect(box, KEY_BG)
		draw_rect(Rect2(box.position.x, box.end.y - 2, w, 2), keys[i][1])
		_text(Vector2(box.position.x + 4, y), key, CMD_FONT - 1, KEY_FG)
		tx = box.position.x - 3
	_text_right(Vector2(tx - 3, y), text, CMD_FONT, color)


## Texto terminando em `pos.x`, com contorno escuro: sem papel atrás, é o
## contorno que segura a leitura em cima da grama/água.
func _text_right(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var at := pos - Vector2(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0, 0, 0, 0.8))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text(pos: Vector2, text: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
