class_name MenuBouton
extends Button
## Bouton du menu principal. Sélectionné, il s'affiche sur une bannière
## de parchemin avec son rouleau et le sceau 斬, comme dans le Figma.

const RETRAIT_TEXTE := 115.0  # du rouleau au début du texte
const RETRAIT_SCEAU := 55.0
const MARGE_DROITE := 40.0
const POINTE := 14.0

@export var texte := "BOUTON"

var _label: Label
var _sceau: Label
var _banniere: Control


func _ready() -> void:
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	theme_type_variation = &"BoutonMenu"

	_banniere = Control.new()
	_banniere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banniere.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banniere.draw.connect(_dessiner_banniere)
	add_child(_banniere)

	_sceau = Label.new()
	_sceau.theme_type_variation = &"Kanji"
	_sceau.add_theme_font_size_override("font_size", 39)
	_sceau.text = "斬"
	_sceau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sceau)

	_label = Label.new()
	_label.text = texte
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", get_theme_font("font", "BoutonMenu"))
	_label.add_theme_font_size_override("font_size", get_theme_font_size("font_size", "BoutonMenu"))
	add_child(_label)

	var largeur_texte := _label.get_theme_font("font").get_string_size(
		texte, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")).x
	custom_minimum_size = Vector2(RETRAIT_TEXTE + largeur_texte + MARGE_DROITE + POINTE, 104)

	focus_entered.connect(_mettre_a_jour)
	focus_exited.connect(_mettre_a_jour)
	mouse_entered.connect(func(): if not disabled: grab_focus())
	resized.connect(_placer)
	_placer()
	_mettre_a_jour()


## À appeler après avoir changé `disabled`.
func rafraichir() -> void:
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	_mettre_a_jour()


func _placer() -> void:
	var h := size.y
	_label.position = Vector2(RETRAIT_TEXTE, (h - _label.get_combined_minimum_size().y) / 2.0)
	_sceau.position = Vector2(RETRAIT_SCEAU, (h - _sceau.get_combined_minimum_size().y) / 2.0)
	_banniere.queue_redraw()


func _mettre_a_jour() -> void:
	var actif := has_focus()
	_sceau.visible = actif
	var couleur := Palette.ENCRE if actif else Palette.WASHI
	if disabled:
		couleur = Color(Palette.GRIS, 0.6)
	elif not actif:
		couleur.a = 0.8
	_label.add_theme_color_override("font_color", couleur)
	_banniere.queue_redraw()


func _dessiner_banniere() -> void:
	if not has_focus():
		return
	var h := size.y
	var w := size.x
	var haut := 10.0
	var bas := h - 10.0
	# Ombre portée
	var ombre := PackedVector2Array([
		Vector2(26, haut + 6), Vector2(w - POINTE, haut + 6), Vector2(w, h / 2 + 6),
		Vector2(w - POINTE, bas + 6), Vector2(26, bas + 6)])
	_banniere.draw_colored_polygon(ombre, Color(Palette.NOIR, 0.45))
	# Bande de parchemin avec la pointe à droite
	var bande := PackedVector2Array([
		Vector2(24, haut), Vector2(w - POINTE, haut), Vector2(w, h / 2),
		Vector2(w - POINTE, bas), Vector2(24, bas)])
	_banniere.draw_colored_polygon(bande, Palette.WASHI)
	_banniere.draw_line(Vector2(24, bas - 1), Vector2(w - POINTE, bas - 1), Palette.WASHI.darkened(0.15), 2)
	# Rouleau en bois et ses embouts dorés
	_banniere.draw_rect(Rect2(2, -12, 20, h + 24), Color("#3A2A1E"))
	_banniere.draw_rect(Rect2(14, -12, 6, h + 24), Color("#4E3A2A"))
	_banniere.draw_rect(Rect2(0, -24, 24, 14), Palette.OR)
	_banniere.draw_rect(Rect2(0, h + 10, 24, 14), Palette.OR)
