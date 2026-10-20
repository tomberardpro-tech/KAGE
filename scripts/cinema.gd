class_name Cinema
extends CanvasLayer
## Habillage des cinématiques : bandes noires en haut et en bas, grand titre au centre,
## et « ÉCHAP · passer » en bas à droite. ÉCHAP met `passe` à vrai : le niveau saute à la fin.

signal passee

var passe := false
var actif := false

var _haut: ColorRect
var _bas: ColorRect
var _titre: Label
var _sous_titre: Label
var _aide: Label
var _tween_titre: Tween


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_haut = _bande()
	_bas = _bande()
	_titre = Label.new()
	_titre.theme_type_variation = &"TitreParchemin"
	_titre.add_theme_font_size_override("font_size", 120)
	_titre.add_theme_color_override("font_color", Palette.WASHI)
	_titre.add_theme_color_override("font_outline_color", Color(Palette.NOIR, 0.8))
	_titre.add_theme_constant_override("outline_size", 14)
	_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre.set_anchors_preset(Control.PRESET_CENTER)
	_titre.modulate.a = 0.0
	add_child(_titre)
	_sous_titre = Label.new()
	_sous_titre.theme_type_variation = &"Aide"
	_sous_titre.add_theme_font_size_override("font_size", 28)
	_sous_titre.add_theme_color_override("font_color", Palette.OR)
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sous_titre.set_anchors_preset(Control.PRESET_CENTER)
	_sous_titre.modulate.a = 0.0
	add_child(_sous_titre)
	_aide = Label.new()
	_aide.theme_type_variation = &"Aide"
	_aide.text = "ÉCHAP · PASSER"
	_aide.add_theme_font_size_override("font_size", 18)
	_aide.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_aide.position = Vector2(-260, -60)
	_aide.modulate.a = 0.0
	add_child(_aide)
	_placer(0.0)


func _bande() -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	return b


func _placer(v: float) -> void:
	var taille := get_viewport().get_visible_rect().size
	var h := 120.0 * v
	_haut.position = Vector2(0, 0)
	_haut.size = Vector2(taille.x, h)
	_bas.position = Vector2(0, taille.y - h)
	_bas.size = Vector2(taille.x, h)


func entrer(passable := true) -> void:
	actif = true
	passe = false
	create_tween().tween_method(_placer, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	if passable:
		create_tween().tween_property(_aide, "modulate:a", 0.8, 0.6)


func sortir() -> void:
	actif = false
	create_tween().tween_method(_placer, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(_aide, "modulate:a", 0.0, 0.3)


## Grand titre qui apparaît puis s'efface (titre du jeu, objet obtenu…).
func titre(texte: String, sous_titre := "", duree := 2.5, hauteur := 0.36) -> void:
	_titre.text = texte
	_sous_titre.text = sous_titre
	var taille := get_viewport().get_visible_rect().size
	_titre.size = Vector2(taille.x, 160)
	_titre.position = Vector2(0, taille.y * hauteur - 80)
	_sous_titre.size = Vector2(taille.x, 40)
	_sous_titre.position = Vector2(0, taille.y * hauteur + 90)
	if _tween_titre:
		_tween_titre.kill()
	var t := create_tween()
	_tween_titre = t
	t.tween_property(_titre, "modulate:a", 1.0, 0.6)
	t.parallel().tween_property(_sous_titre, "modulate:a", 1.0, 0.9)
	t.tween_interval(duree)
	t.tween_property(_titre, "modulate:a", 0.0, 0.6)
	t.parallel().tween_property(_sous_titre, "modulate:a", 0.0, 0.6)


func aide_visible(oui: bool) -> void:
	create_tween().tween_property(_aide, "modulate:a", 0.8 if oui else 0.0, 0.2)


func cacher_titre() -> void:
	if _tween_titre:
		_tween_titre.kill()
	_titre.modulate.a = 0.0
	_sous_titre.modulate.a = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if actif and not passe and event.is_action_pressed("pause"):
		passe = true
		passee.emit()
		get_viewport().set_input_as_handled()


## Attend `duree` secondes, ou moins si le joueur passe la cinématique. Renvoie vrai si passée.
func attendre(duree: float) -> bool:
	var fin := Time.get_ticks_msec() + int(duree * 1000.0)
	while Time.get_ticks_msec() < fin and not passe:
		await get_tree().process_frame
	return passe
