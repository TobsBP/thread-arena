class_name PackUI

## Desenho das peças de UI do Tiny Swords, que vêm em pedaços soltos dentro da
## textura em vez de um nine-patch contíguo — nem NinePatchRect nem
## StyleBoxTexture dão conta. São estáticas e recebem o CanvasItem porque quem
## desenha é o HUD (Control) e o UnitSprite (Node2D).


## 3-slice horizontal: as pontas de `cap` px saem inteiras (só escaladas) e o
## miolo (sempre x 128..192 nas texturas do pack) estica no que sobrar.
static func hslice(ci: CanvasItem, tex: Texture2D, dest: Rect2, src: Rect2,
		cap: float) -> void:
	var c := cap * dest.size.y / src.size.y
	ci.draw_texture_rect_region(tex, Rect2(dest.position, Vector2(c, dest.size.y)),
			Rect2(src.position, Vector2(cap, src.size.y)))
	ci.draw_texture_rect_region(tex,
			Rect2(dest.position + Vector2(c, 0), Vector2(dest.size.x - 2.0 * c, dest.size.y)),
			Rect2(128, src.position.y, 64, src.size.y))
	ci.draw_texture_rect_region(tex,
			Rect2(dest.position + Vector2(dest.size.x - c, 0), Vector2(c, dest.size.y)),
			Rect2(src.end.x - cap, src.position.y, cap, src.size.y))


## Nine-patch dos papéis e banners: as 9 peças estão soltas em células de 64px
## nos offsets 0/128/256 dos dois eixos. Cantos em `cap`, resto esticado.
static func nine(ci: CanvasItem, tex: Texture2D, dest: Rect2, cap: float) -> void:
	var src := [0.0, 128.0, 256.0]
	var dx := [dest.position.x, dest.position.x + cap, dest.end.x - cap]
	var dw := [cap, dest.size.x - 2.0 * cap, cap]
	var dy := [dest.position.y, dest.position.y + cap, dest.end.y - cap]
	var dh := [cap, dest.size.y - 2.0 * cap, cap]
	for r in 3:
		for c in 3:
			ci.draw_texture_rect_region(tex,
					Rect2(dx[c], dy[r], dw[c], dh[r]),
					Rect2(src[c], src[r], 64, 64))
