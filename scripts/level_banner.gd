class_name LevelBanner
extends Control

## "LEVEL N — TIPO" grande no meio da tela, aparece e some sozinho. Quem
## cronometra é main.gd (mesma regra do HUD: ele não mede nada) — a cada
## frame manda o texto e o alfa já prontos (ver main.gd _update_banner);
## este nó só desenha, em papel do pack, igual ao resto da UI.

const PAPER := preload("res://assets/Tiny Swords (Free Pack)/Tiny Swords (Free Pack)/UI Elements/UI Elements/Papers/RegularPaper.png")
const PAPER_CAP := 20.0
const INK := Color(0.16, 0.13, 0.09)
const FONT_SIZE := 34

var _text := ""


## `alpha` <= 0 esconde o nó inteiro (modulate), sem custo de desenho.
func show_banner(text: String, alpha: float) -> void:
	_text = text
	modulate.a = alpha
	visible = alpha > 0.0
	queue_redraw()


func _draw() -> void:
	if _text.is_empty():
		return
	var font := ThemeDB.fallback_font
	var text_w := font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var box_size := Vector2(text_w + 80.0, 76.0)
	var box := Rect2(size * 0.5 - box_size * 0.5, box_size)
	PackUI.nine(self, PAPER, box, PAPER_CAP)
	var pos := box.position + Vector2(40.0, box.size.y * 0.5 + FONT_SIZE * 0.35)
	draw_string_outline(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 6,
			Color(0, 0, 0, 0.85))
	draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, INK)
