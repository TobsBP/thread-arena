extends Control

## HUD: painel de números, timeline das tarefas e um histórico por unidade.
## Só apresenta — quem mede e guarda os tempos é o main.
##
## Tudo é desenhado em papel do pack (PackUI.nine), então as cores são de
## tinta sobre papel claro, não de terminal escuro.

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const BIG_BAR := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Base.png")
const BIG_BAR_FILL := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Bars/BigBar_Fill.png")
## Retratos: um por unidade, na ordem de main.gd (P1..P3 e o inimigo).
const AVATARS := [
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_01.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_05.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_11.png"),
	preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Human Avatars/Avatars_17.png"),
]

## Recortes medidos nas texturas: a barra grande tem pontas de 24px e o miolo
## em 128..192; o preenchimento é a faixa y 20..44 da sua textura.
const BIG_BAR_SRC := Rect2(40, 0, 240, 64)
const BIG_BAR_CAP := 24.0
const BIG_FILL_SRC := Rect2(0, 20, 64, 24)
const PAPER_CAP := 20.0

## Tinta sobre papel.
const DIM := "#7a6650"
const GOOD := "#2f6b34"
const BAD := "#a1461e"

const INK := Color(0.16, 0.13, 0.09)
const INK_SOFT := Color(0.35, 0.27, 0.19)
## Texto sobre a madeira escura da barra grande.
const ON_WOOD := Color(0.97, 0.92, 0.80)
const TRACK := Color(0, 0, 0, 0.08)

const WIDTH := 460.0
const GAP := 30.0
## Faixa do título dentro do papel: o nine-patch do papel tem uma margem
## transparente na peça de canto, então o topo real fica uns 8px abaixo.
const TITLE_H := 24.0
const BAR_H := 18.0     ## barra da timeline
const LANE_H := 24.0    ## faixa do histórico
const GAUGE_H := 30.0   ## barra grande do comparativo
const AVATAR := 22.0
const PAD := 10.0
const SAMPLES := 90  ## ~frames guardados por unidade
const VILLAGE_W := 330.0  ## painel da vila
const VILLAGE_LINE := 18.0
## Onde o painel da vila começa.
const VILLAGE_TOP := 104.0
## Com tudo à mostra, a lista de comandos do SidePanel ocupa o canto de baixo à direita.
const CAPTION_LIFT := 150.0

var _use_threads := false
var _ms: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var _fps: Dictionary[bool, float] = {false: 0.0, true: 0.0}
var _units: Array[Player] = []
var _frame_t0 := 0
var _level := 1
var _no_mobs := false
var _history: Array[PackedFloat32Array] = []
## StyleBox por unidade: só pra ter canto arredondado sem realocar por frame.
var _bars: Array[StyleBoxFlat] = []
## 0 = tudo, 1 = só o painel de números, 2 = nada. Alterna com [H].
var detail := 0
## Números da vila, prontos de main.gd (_village_stats) — vazio até o 1º frame.
var _village := {}
## Legenda do modo apresentação ([C] em main.gd): vazia = câmera nos players.
var _camera_caption := ""
## Aviso curto no lugar da legenda (ex.: [T] longe do castelo): texto e até quando (ms) ele fica.
var _notice := ""
var _notice_until := 0
## Altura e passo das barras da linha do tempo.
var _bar_h := BAR_H
var _bar_step := BAR_H + 5.0

## Hardware/software da máquina que tá rodando — lido uma vez, não muda em
## runtime. É o que explica "no meu PC deu Xx, no do meu amigo deu Yx": a
## demo mede o ganho de threads, e esse ganho depende de quantos núcleos
## existem de verdade pra rodar em paralelo (o resto — GPU, SO, versão do
## Godot — é só contexto de "em que máquina isso foi medido").
var _cpu_name := ""
var _cpu_cores := 1
var _gpu_name := ""
var _os_name := ""
var _godot_version := ""

@onready var info: RichTextLabel = $Info


func _ready() -> void:
	# O papel é desenhado por baixo, no _draw(); o label só reserva a margem.
	var box := StyleBoxEmpty.new()
	box.set_content_margin_all(20)
	info.add_theme_stylebox_override("normal", box)
	# Sem isto o texto sem [color] sai branco — invisível sobre o papel.
	info.add_theme_color_override("default_color", INK)
	_cpu_name = OS.get_processor_name()
	if _cpu_name.is_empty():
		_cpu_name = OS.get_name()  ## alguma plataforma pode não expor o nome do processador
	_cpu_cores = OS.get_processor_count()
	_gpu_name = RenderingServer.get_video_adapter_name()
	if _gpu_name.is_empty():
		_gpu_name = "GPU desconhecida"
	_os_name = OS.get_name()
	_godot_version = Engine.get_version_info().string


## [H]: menos informação na tela.
func cycle_detail() -> void:
	detail = (detail + 1) % 3
	info.visible = detail < 2
	queue_redraw()


func update_village(stats: Dictionary) -> void:
	_village = stats


func set_camera_caption(text: String) -> void:
	_camera_caption = text
	queue_redraw()


func show_notice(text: String, seconds: float) -> void:
	_notice = text
	_notice_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	queue_redraw()


## Quanto o meio da área livre da tela está à direita do meio da janela.
func free_center_shift() -> float:
	if detail > 1:
		return 0.0
	return (WIDTH - VILLAGE_W - 26.0) * 0.5


func update_stats(
	use_threads: bool,
	ms: Dictionary[bool, float],
	fps: Dictionary[bool, float],
	units: Array[Player],
	frame_t0: int,
	level: int,
	no_mobs: bool,
) -> void:
	_use_threads = use_threads
	_ms = ms
	_fps = fps
	_units = units
	_frame_t0 = frame_t0
	_level = level
	_no_mobs = no_mobs
	_record()

	info.text = "\n".join([
		"[font_size=20][b]%s[/b][/font_size]" % _mode_title(),
		"[color=%s][font_size=13]%s[/font_size][/color]" % [DIM, _system_line()],
		"",
		_verdict(),
		"[color=%s][ESPAÇO] modo  [B] bots  [H] info  [T] castelo  [M] mobs  [X] mutex  [V] filas  [Z] cura  [C] câmera[/color]" % DIM,
	])
	queue_redraw()


## Tudo sobre a máquina numa linha só (CPU/núcleos/threads em uso — o que
## importa pro comparativo — mais GPU/SO/versão do Godot, só contexto de "em
## que máquina isso foi medido"). Junto em vez de duas linhas separadas pra
## não esticar o painel.
func _system_line() -> String:
	var used := _units.size() if _use_threads else 1
	return "%s (%d núcleos, %d em uso)   —   %s   —   %s   —   Godot %s" % [
		_cpu_name, _cpu_cores, used, _gpu_name, _os_name, _godot_version,
	]


## Janela deslizante do tempo de cada unidade, alimenta os mini-gráficos.
func _record() -> void:
	while _history.size() < _units.size():
		_history.append(PackedFloat32Array())
		_bars.append(_bar_box())
	# Onda de goblin morreu: units encolhe. Corta o excedente pra
	# _draw_history() nunca indexar _units além do fim — o índice que sobra
	# passa a pertencer a outra unidade, então o gráfico dela pula uma vez
	# (cosmético, não trava).
	while _history.size() > _units.size():
		_history.pop_back()
		_bars.pop_back()
	for i in _units.size():
		var h := _history[i]
		h.append((_units[i].t_end - _units[i].t_start) / 1000.0)
		if h.size() > SAMPLES:
			h.remove_at(0)
		_history[i] = h


func _bar_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(4)
	return box


func _mode_title() -> String:
	var lvl := "LEVEL %d%s" % [_level, " — SEM MOBS" if _no_mobs else ""]
	if _use_threads:
		return "[color=%s]▮▮▮ THREADS[/color]  [font_size=13]%d Threads paralelas — %s[/font_size]" % [
			GOOD, _units.size(), lvl,
		]
	return "[color=%s]▮ SERIAL[/color]  [font_size=13]tudo na main thread — %s[/font_size]" % [
		BAD, lvl,
	]


## Só compara depois de ter medido os dois modos.
func _verdict() -> String:
	if _ms[false] <= 0.0 or _ms[true] <= 0.0:
		return "[color=%s]alterne de modo pra medir os dois[/color]" % DIM
	var speedup := _ms[false] / _ms[true]
	return "[color=%s][b]THREADS %.1fx mais rápido[/b][/color] [color=%s](%.0f%% do tempo do serial)[/color]\n" % [
		GOOD, speedup, DIM, 100.0 / speedup,
	]


func _draw() -> void:
	_draw_camera_caption()
	if detail > 1:
		return
	# Papel atrás do painel de texto (o Control desenha antes dos filhos).
	PackUI.nine(self, PAPER, Rect2(0, 0, WIDTH, info.size.y), PAPER_CAP)
	_draw_village()
	if detail != 0:
		return
	# Layout a partir da altura real do painel: ele cresce com o texto.
	# Altura vem do número de unidades: entra/sai inimigo sem quebrar o layout.
	var n := maxf(_units.size(), 1)
	var y := info.size.y + GAP
	var gauge_h := PAD + 2.0 * (GAUGE_H + 8.0)
	_draw_gauges(Rect2(0, y, WIDTH, gauge_h))
	y += gauge_h + GAP + PAD
	# Com os aldeões (cada um é uma unidade) a pilha inteira não cabe mais na janela.
	var room := get_viewport_rect().size.y - position.y - y - 14.0
	var timeline_h := PAD + n * (BAR_H + 5)
	var hist_h := PAD + n * (LANE_H + 4)
	var show_history := timeline_h + GAP + PAD + hist_h <= room
	_bar_step = BAR_H + 5.0
	if timeline_h > room:
		_bar_step = maxf((room - PAD) / n, 4.0)
		timeline_h = PAD + n * _bar_step
	_bar_h = clampf(_bar_step - 3.0, 3.0, BAR_H)
	_draw_timeline(Rect2(0, y, WIDTH, timeline_h))
	if show_history:
		_draw_history(Rect2(0, y + timeline_h + GAP + PAD, WIDTH, hist_h))


## Legenda do modo apresentação, embaixo no meio.
func _draw_camera_caption() -> void:
	var noticing := Time.get_ticks_msec() < _notice_until
	if _camera_caption.is_empty() and not noticing:
		return
	var vp := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	var text := _notice if noticing else _camera_caption + "    [C] próximo"
	# Com tudo à mostra, a pilha da esquerda desce até o pé da tela.
	var left := WIDTH + 24.0 if detail == 0 else 0.0
	var room := vp.x - position.x - left - 12.0
	var font_size := 16
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0
	if w > room:
		font_size = 13
		w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 44.0
	var lift := CAPTION_LIFT if detail == 0 else 0.0
	var rect := Rect2(left + (room - w) * 0.5, vp.y - 58.0 - lift - position.y, w, 40.0)
	PackUI.nine(self, PAPER, rect, PAPER_CAP)
	_ink(rect.position + Vector2(22, 26), text, font_size, INK,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(1, 1, 1, 0.7))


## Painel da vila, no canto de cima à direita.
func _draw_village() -> void:
	if _village.is_empty():
		return
	var v := _village
	var mutex_on: bool = v.mutex
	var lost: float = maxf(v.delivered - v.counted, 0.0)
	var lines := [
		["madeira %d    ouro %d" % [floori(v.wood + 0.001), floori(v.gold + 0.001)], INK],
		["carne crua %d    assada %d" % [floori(v.meat + 0.001), v.roasts], INK],
		["cura primeiro: %s   [Z]" % v.heal, INK_SOFT],
		["fogueira: %s" % ("acesa, %ds de lenha" % ceili(v.fire) if v.fire > 0.0
				else "apagada (1 lenha acende)"), INK_SOFT],
		["", INK],
		["MUTEX do armazém: %s   [X]" % ("LIGADO" if mutex_on else "DESLIGADO"),
				Color(GOOD) if mutex_on else Color(BAD)],
		["entregue %.1f   contado %.1f" % [v.delivered, v.counted], INK],
		["perdido %.1f%s" % [lost, _lost_note(mutex_on, v.threads, lost)],
				Color(BAD) if lost > 0.05 else INK_SOFT],
		["", INK],
		["SEMÁFOROS (filas): %s   [V]" % ("LIGADOS" if v.semaphores else "DESLIGADOS"),
				Color(GOOD) if v.semaphores else Color(BAD)],
		["SEMÁFORO armazém: %d/%d dentro, fila %d" % [v.door_used, Village.DEPOT_SLOTS, v.door_queue], INK],
		["SEMÁFORO mina: %d/%d vagas, fila %d" % [v.mine_used, Village.MINE_SLOTS, v.mine_queue], INK],
		["SEMÁFORO espeto: %d/%d em uso, fila %d" % [v.fire_used, Village.FIRE_SLOTS, v.fire_queue], INK],
		["SEMÁFORO assadas prontas: %d" % v.roasts, INK],
	]
	var rect := Rect2(get_viewport_rect().size.x - position.x - VILLAGE_W - 26.0,
			VILLAGE_TOP + TITLE_H - position.y,
			VILLAGE_W, lines.size() * VILLAGE_LINE + 6.0)
	_frame(rect, "vila — o que as threads dividem")
	for i in lines.size():
		_ink(rect.position + Vector2(6, 14 + i * VILLAGE_LINE), lines[i][0], 13, lines[i][1],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(1, 1, 1, 0.7))


## Por que (não) está perdendo: sem mutex a soma some só quando duas Threads descarregam juntas.
func _lost_note(mutex_on: bool, threads: bool, lost: float) -> String:
	if mutex_on:
		return "" if lost <= 0.05 else "  (de quando estava desligado)"
	if not threads:
		return "  (serial: sem disputa)"
	return "  ← corrida!" if lost > 0.05 else "  (ainda sem colisão)"


## Moldura de papel com o título dentro dela: antes o título caía na borda de
## cima e ficava lendo em cima do cenário.
func _frame(rect: Rect2, title: String) -> void:
	PackUI.nine(self, PAPER,
			Rect2(rect.position - Vector2(14, TITLE_H),
					rect.size + Vector2(28, TITLE_H + 14)),
			PAPER_CAP)
	_ink(rect.position + Vector2(4, -8), title, 14, INK_SOFT,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(1, 1, 1, 0.7))


## As duas barras grandes do pack, uma por modo: o tempo de cada um contra o
## pior dos dois. É a leitura de relance, então o número vive dentro da barra,
## em texto claro sobre a madeira — tinta escura ali some.
func _draw_gauges(rect: Rect2) -> void:
	_frame(rect, "tempo por frame")
	var worst := maxf(maxf(_ms[false], _ms[true]), 0.001)
	for i in 2:
		var threads := i == 1
		var bar := Rect2(rect.position + Vector2(0, PAD * 0.5 + i * (GAUGE_H + 8.0)),
				Vector2(rect.size.x, GAUGE_H))
		PackUI.hslice(self, BIG_BAR, bar, BIG_BAR_SRC, BIG_BAR_CAP)
		var inset := GAUGE_H * 0.22
		var measured := _ms[threads] > 0.0
		if measured:
			var fill := Rect2(
				bar.position + Vector2(inset, GAUGE_H * 20.0 / 64.0),
				Vector2(maxf((bar.size.x - inset * 2.0) * (_ms[threads] / worst), 2.0),
						GAUGE_H * 24.0 / 64.0),
			)
			draw_texture_rect_region(BIG_BAR_FILL, fill, BIG_FILL_SRC,
					Color(1, 1, 1) if threads == _use_threads else Color(1, 1, 1, 0.5))
		var baseline := bar.position + Vector2(inset + 4, GAUGE_H * 0.7)
		_ink(baseline, "THREADS" if threads else "SERIAL", 14, ON_WOOD)
		var right := Vector2(bar.position.x + inset, baseline.y)
		var width := bar.size.x - inset * 2.0 - 4.0
		if measured:
			_ink(right, "%.2f ms   %.0f FPS" % [_ms[threads], _fps[threads]], 14,
					ON_WOOD, HORIZONTAL_ALIGNMENT_RIGHT, width)
		else:
			_ink(right, "sem medida — aperte [ESPAÇO]", 13,
					Color(ON_WOOD, 0.7), HORIZONTAL_ALIGNMENT_RIGHT, width)


## Texto com um contorno escuro atrás: sobre madeira ou sobre gráfico, o
## traço fino é o que mantém o número legível.
func _ink(pos: Vector2, text: String, size: int, color: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0,
		halo := Color(0.08, 0.06, 0.04, 0.55)) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, pos + Vector2(1, 1), text, align, width, size, halo)
	draw_string(font, pos, text, align, width, size, color)


## Timeline: uma barra por unidade (players + inimigo), no start/end real.
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
			Color(0, 0, 0, 0.06), 1.0,
		)
	if _ms[false] > 0.0:
		var ref := rect.size.x * (_ms[false] * 1000.0 / span)
		draw_dashed_line(
			rect.position + Vector2(ref, 0),
			rect.position + Vector2(ref, rect.size.y),
			Color(0, 0, 0, 0.35), 1.0, 4.0,
		)

	for i in _units.size():
		var p := _units[i]
		var y := 8 + i * _bar_step
		var x0 := float(p.t_start - _frame_t0) / span
		var x1 := minf(float(p.t_end - _frame_t0) / span, 1.0)
		# Trilho: mostra o quanto da régua a barra NÃO ocupa.
		draw_rect(
			Rect2(rect.position + Vector2(0, y), Vector2(rect.size.x, _bar_h)),
			TRACK,
		)
		var bar := Rect2(
			rect.position + Vector2(rect.size.x * x0, y),
			Vector2(maxf(rect.size.x * (x1 - x0), 3.0), _bar_h),
		)
		_bars[i].bg_color = p.color
		draw_style_box(_bars[i], bar)
		# Barra encolhida demais não cabe letra: fica só a cor.
		if _bar_h >= 11.0:
			var font_size := clampi(int(_bar_h) - 4, 9, 13)
			_ink(bar.position + Vector2(8, _bar_h - (_bar_h - font_size) * 0.5 - 2.0),
					"%s  %.2f ms" % [_label(i), (p.t_end - p.t_start) / 1000.0],
					font_size, Color(1, 1, 1, 0.95))


## Rótulo da faixa: os controláveis são P1..Pn, o aldeão é A e o inimigo é E.
func _label(i: int) -> String:
	if i < _units.size() and _units[i].is_enemy:
		return "E "
	if i < _units.size() and _units[i].is_worker:
		return "A "
	return "P%d" % (i + 1)


## Um mini-gráfico por unidade: tempo dela nos últimos SAMPLES frames.
## Alternar o modo faz o degrau aparecer em todas ao mesmo tempo.
func _peak() -> float:
	var peak := 0.001
	for h in _history:
		for v in h:
			peak = maxf(peak, v)
	return peak


func _draw_history(rect: Rect2) -> void:
	_frame(rect, "por thread, últimos %d frames  (escala: pico %.2f ms)" % [
		SAMPLES, _peak(),
	])
	var peak := _peak()
	var lane_h := LANE_H
	for i in _history.size():
		var h := _history[i]
		var top := rect.position + Vector2(0, 4 + i * (lane_h + 4))
		draw_rect(Rect2(top, Vector2(rect.size.x, lane_h)), TRACK)
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
			draw_colored_polygon(fill, Color(_units[i].color, 0.28))
			draw_polyline(pts, _units[i].color, 1.5, true)
		# Retrato da unidade na ponta da faixa.
		var face: Texture2D = AVATARS[i % AVATARS.size()]
		draw_texture_rect(face, Rect2(top + Vector2(2, (lane_h - AVATAR) * 0.5),
				Vector2(AVATAR, AVATAR)), false)
		# Aqui o fundo é papel claro com o gráfico por trás: tinta escura com
		# halo claro, o contrário das barras.
		_ink(top + Vector2(AVATAR + 8, lane_h - 6),
				"%s  %.2f ms" % [_label(i), h[-1] if not h.is_empty() else 0.0],
				13, INK, HORIZONTAL_ALIGNMENT_LEFT, -1.0, Color(1, 1, 1, 0.7))
