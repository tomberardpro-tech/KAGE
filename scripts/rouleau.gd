class_name Rouleau
extends MarginContainer
## Parchemin de la charte : papier washi, rouleaux en bois aux deux bouts
## avec embouts dorés, et sceau rouge en option. Le contenu va en enfant.

const BOIS := Color("#3A2A1E")
const BOIS_CLAIR := Color("#4E3A2A")

## Faux : rouleaux à gauche et à droite (bandeau). Vrai : en haut et en bas (kakemono).
@export var vertical := false
@export var sceau := true


func _ready() -> void:
	var marge_x := 70 if not vertical else 60
	var marge_y := 26 if not vertical else 50
	add_theme_constant_override("margin_left", marge_x)
	add_theme_constant_override("margin_right", marge_x)
	add_theme_constant_override("margin_top", marge_y)
	add_theme_constant_override("margin_bottom", marge_y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(8, 10), r.size), Color(Palette.NOIR, 0.45))
	draw_rect(r, Palette.WASHI)
	if vertical:
		draw_line(Vector2(0, 30), Vector2(size.x, 30), Palette.WASHI.darkened(0.08), 2)
		draw_line(Vector2(0, size.y - 30), Vector2(size.x, size.y - 30), Palette.WASHI.darkened(0.08), 2)
		for y in [-12.0, size.y - 8.0]:
			draw_rect(Rect2(-14, y, size.x + 28, 20), BOIS)
			draw_rect(Rect2(-14, y + 12, size.x + 28, 6), BOIS_CLAIR)
			draw_rect(Rect2(-34, y - 2, 22, 24), Palette.OR)
			draw_rect(Rect2(size.x + 12, y - 2, 22, 24), Palette.OR)
	else:
		draw_line(Vector2(0, size.y - 2), Vector2(size.x, size.y - 2), Palette.WASHI.darkened(0.15), 3)
		for x in [-12.0, size.x - 8.0]:
			draw_rect(Rect2(x, -14, 20, size.y + 28), BOIS)
			draw_rect(Rect2(x + 12, -14, 6, size.y + 28), BOIS_CLAIR)
			draw_rect(Rect2(x - 2, -34, 24, 22), Palette.OR)
			draw_rect(Rect2(x - 2, size.y + 12, 24, 22), Palette.OR)
	if sceau:
		# Sceau rouge (hanko) en bas à droite, légèrement penché.
		var c := Vector2(size.x - 64, size.y - 46) if not vertical else Vector2(size.x - 70, size.y - 76)
		draw_set_transform(c, deg_to_rad(-8.0))
		draw_rect(Rect2(-24, -24, 48, 48), Color(Palette.LAQUE, 0.9))
		draw_rect(Rect2(-18, -18, 36, 36), Color(Palette.WASHI, 0.85), false, 3.0)
		draw_line(Vector2(-8, -10), Vector2(8, -10), Color(Palette.WASHI, 0.85), 3.0)
		draw_line(Vector2(0, -10), Vector2(0, 12), Color(Palette.WASHI, 0.85), 3.0)
		draw_line(Vector2(-9, 3), Vector2(9, 3), Color(Palette.WASHI, 0.85), 3.0)
		draw_set_transform(Vector2.ZERO)
