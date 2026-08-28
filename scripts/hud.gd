extends Control

## HUD: painel de números, timeline das tarefas e um histórico por player.
## Só apresenta — quem mede e guarda os tempos é o main.

const DIM := "#7d8590"
const HL := "#e6edf3"
const GOOD := "#56d364"
const BAD := "#f0883e"

const BG := Color(0.05, 0.06, 0.08, 0.88)
const LINE := Color(1, 1, 1, 0.12)
const TEXT := Color(0.49, 0.53, 0.59)

const WIDTH := 460.0
const GRAPH_H := 96.0   ## timeline do frame atual
const HIST_H := 108.0   ## histórico por player
const GAP := 22.0
const BAR_H := 20.0
const SAMPLES := 90  ## ~frames guardados por player

var _use_threads := false
var _ms: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var _fps: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var _players: Array[Player] = []
var _frame_t0 := 0
var _history: Array[PackedFloat32Array] = []
## StyleBox por player: só pra ter canto arredondado sem realocar por frame.
var _bars: Array[StyleBoxFlat] = []
## 0 = tudo, 1 = só o painel de números, 2 = nada. Alterna com [H].
var detail := 0

@onready var info: RichTextLabel = $Info


func _ready() -> void:
	info.add_theme_stylebox_override("normal", _panel())


func _panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BG
	box.border_color = LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(14)
	return box


## [H]: menos informação na tela.
func cycle_detail() -> void:
	detail = (detail + 1) % 3
	info.visible = detail < 2
	queue_redraw()


func update_stats(
	use_threads: bool,
	ms: Dictionary[bool, float],
	fps: Dictionary[bool, float],
	players: Array[Player],
	frame_t0: int,
) -> void:
	_use_threads = use_threads
	_ms = ms
	_fps = fps
	_players = players
	_frame_t0 = frame_t0
	_record()

	info.text = "\n".join([
		"[font_size=20][b]%s[/b][/font_size]" % _mode_title(),
		"",
		"[code][color=%s]                tempo/frame      FPS[/color]" % DIM,
		"[color=%s]  SERIAL         %6.2f ms    %5.0f[/color]" % [
			HL if not use_threads else DIM, _ms[false], _fps[false],
		],
		"[color=%s]  THREADS        %6.2f ms    %5.0f[/color][/code]" % [
			HL if use_threads else DIM, _ms[true], _fps[true],
		],
		"",
		_verdict(),
		"[color=%s][ESPAÇO] alternar modo   [H] menos info[/color]" % DIM,
	])
	queue_redraw()


## Janela deslizante do tempo de cada player, alimenta os mini-gráficos.
func _record() -> void:
	while _history.size() < _players.size():
		_history.append(PackedFloat32Array())
		_bars.append(_bar_box())
	for i in _players.size():
		var h := _history[i]
		h.append((_players[i].t_end - _players[i].t_start) / 1000.0)
		if h.size() > SAMPLES:
			h.remove_at(0)
		_history[i] = h


func _bar_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	return box


func _mode_title() -> String:
	if _use_threads:
		return "[color=%s]▮▮▮ THREADS[/color]  [font_size=13]%d tarefas no WorkerThreadPool[/font_size]" % [
			GOOD, _players.size(),
		]
	return "[color=%s]▮ SERIAL[/color]  [font_size=13]tudo na main thread[/font_size]" % BAD


## Só compara depois de ter medido os dois modos.
func _verdict() -> String:
	if _ms[false] <= 0.0 or _ms[true] <= 0.0:
		return "[color=%s]alterne de modo pra medir os dois[/color]" % DIM
	var speedup := _ms[false] / _ms[true]
	return "[color=%s][b]THREADS %.1fx mais rápido[/b][/color] [color=%s](%.0f%% do tempo do serial)[/color]\n" % [
		GOOD, speedup, DIM, 100.0 / speedup,
	]


func _draw() -> void:
	if detail != 0:
		return
	# Layout a partir da altura real do painel: ele cresce com o texto.
	var y := info.size.y + GAP
	_draw_timeline(Rect2(0, y, WIDTH, GRAPH_H))
	_draw_history(Rect2(0, y + GRAPH_H + GAP + 10, WIDTH, HIST_H))


func _frame(rect: Rect2, title: String) -> void:
	var box := rect.grow(6)
	draw_rect(box, BG)
	draw_rect(box, LINE, false, 1.0)
	draw_string(
		ThemeDB.fallback_font, rect.position + Vector2(2, -3),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT,
	)


## Timeline: uma barra por player, no instante real de start/end.
## Serial -> barras em escada. Threads -> barras empilhadas no mesmo x.
func _draw_timeline(rect: Rect2) -> void:
	# Escala fixa = pior modo medido, pros dois modos serem comparáveis a olho:
	# serial enche a régua, threads ocupa uma fração dela.
	var span := maxf(maxf(_ms[false], _ms[true]) * 1000.0, 1.0)
	_frame(rect, "linha do tempo do frame  →")

	# Régua a cada 25% do pior caso, pra dar noção de escala.
	for t in 4:
		var x := rect.size.x * (t / 4.0)
		draw_line(
			rect.position + Vector2(x, 0),
			rect.position + Vector2(x, rect.size.y),
			Color(1, 1, 1, 0.06), 1.0,
		)
	if _ms[false] > 0.0:
		var ref := rect.size.x * (_ms[false] * 1000.0 / span)
		draw_dashed_line(
			rect.position + Vector2(ref, 0),
			rect.position + Vector2(ref, rect.size.y),
			Color(1, 1, 1, 0.45), 1.0, 4.0,
		)

	for i in _players.size():
		var p := _players[i]
		var y := 10 + i * (BAR_H + 6)
		var x0 := float(p.t_start - _frame_t0) / span
		var x1 := minf(float(p.t_end - _frame_t0) / span, 1.0)
		# Trilho: mostra o quanto da régua a barra NÃO ocupa.
		draw_rect(
			Rect2(rect.position + Vector2(0, y), Vector2(rect.size.x, BAR_H)),
			Color(1, 1, 1, 0.04),
		)
		var bar := Rect2(
			rect.position + Vector2(rect.size.x * x0, y),
			Vector2(maxf(rect.size.x * (x1 - x0), 3.0), BAR_H),
		)
		_bars[i].bg_color = p.color
		draw_style_box(_bars[i], bar)
		draw_string(
			ThemeDB.fallback_font, bar.position + Vector2(6, BAR_H - 6),
			"P%d  %.2f ms" % [i + 1, (p.t_end - p.t_start) / 1000.0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.75),
		)


## Um mini-gráfico por player: tempo dele nos últimos SAMPLES frames.
## Alternar o modo faz o degrau aparecer nos três ao mesmo tempo.
func _peak() -> float:
	var peak := 0.001
	for h in _history:
		for v in h:
			peak = maxf(peak, v)
	return peak


func _draw_history(rect: Rect2) -> void:
	_frame(rect, "por player, últimos %d frames  (escala: pico %.2f ms)" % [
		SAMPLES, _peak(),
	])
	var peak := _peak()
	var lane_h := (rect.size.y - 8) / maxf(_players.size(), 1) - 4
	for i in _history.size():
		var h := _history[i]
		var top := rect.position + Vector2(0, 4 + i * (lane_h + 4))
		draw_rect(Rect2(top, Vector2(rect.size.x, lane_h)), Color(1, 1, 1, 0.04))
		if h.size() >= 2:
			var pts := PackedVector2Array()
			for j in h.size():
				pts.append(top + Vector2(
					rect.size.x * j / float(h.size() - 1),
					lane_h * (1.0 - h[j] / peak),
				))
			var fill := pts.duplicate()
			fill.append(top + Vector2(rect.size.x, lane_h))
			fill.append(top + Vector2(0, lane_h))
			draw_colored_polygon(fill, Color(_players[i].color, 0.22))
			draw_polyline(pts, _players[i].color, 1.5, true)
		draw_string(
			ThemeDB.fallback_font, top + Vector2(6, lane_h - 5),
			"P%d  %.2f ms" % [i + 1, h[-1] if not h.is_empty() else 0.0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT,
		)
