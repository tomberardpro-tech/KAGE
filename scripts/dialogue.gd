class_name Dialogue
extends CanvasLayer
## Boîte de dialogue en bas de l'écran, sur un rouleau de papier : le nom de celui qui parle,
## son texte qui s'écrit lettre par lettre, et ENTRÉE pour continuer (ÉCHAP pour tout passer).
## await dialogue.jouer("MAÎTRE", ["…", "…"])

signal fini

const VITESSE := 45.0  ## lettres par seconde

var _lignes: Array = []
var _index := 0
var _texte: Label
var _nom: Label
var _suite: Label
var _cadre: Control
var _ecrit := 0.0


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bas := MarginContainer.new()
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -330
	bas.add_theme_constant_override("margin_left", 260)
	bas.add_theme_constant_override("margin_right", 260)
	bas.add_theme_constant_override("margin_bottom", 70)
	bas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bas)
	var rouleau := Rouleau.new()
	rouleau.vertical = true
	bas.add_child(rouleau)
	_cadre = bas
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	var marge := MarginContainer.new()
	for cote in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + cote, 70)
	for cote in ["top", "bottom"]:
		marge.add_theme_constant_override("margin_" + cote, 26)
	marge.add_child(v)
	rouleau.add_child(marge)
	_nom = _label(&"TitreParchemin", 34, Palette.LAQUE)
	v.add_child(_nom)
	_texte = _label(&"TexteParchemin", 28)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size = Vector2(1100, 96)
	v.add_child(_texte)
	_suite = _label(&"Aide", 20)
	_suite.text = "ENTRÉE ▸   ÉCHAP : passer"
	_suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_suite.add_theme_color_override("font_color", Palette.ENCRE)
	v.add_child(_suite)
	_cadre.hide()


func _label(variation: StringName, taille: int, couleur := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", taille)
	if couleur.a > 0.0:
		l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func jouer(nom: String, lignes: Array) -> void:
	_nom.text = nom
	_lignes = lignes
	_index = 0
	_montrer_ligne()
	_cadre.show()
	_cadre.modulate.a = 0.0
	create_tween().tween_property(_cadre, "modulate:a", 1.0, 0.3)
	await fini


func _montrer_ligne() -> void:
	_texte.text = _lignes[_index]
	_texte.visible_characters = 0
	_ecrit = 0.0


func _process(delta: float) -> void:
	if not _cadre.visible:
		return
	_ecrit += delta * VITESSE
	_texte.visible_characters = int(_ecrit)
	_suite.modulate.a = 1.0 if _texte.visible_ratio >= 1.0 else 0.35


func _unhandled_input(event: InputEvent) -> void:
	if not _cadre.visible:
		return
	if event.is_action_pressed("pause"):
		_fermer()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		if _texte.visible_ratio < 1.0:
			_ecrit = _texte.text.length()  # la ligne s'affiche d'un coup
		elif _index + 1 < _lignes.size():
			_index += 1
			_montrer_ligne()
		else:
			_fermer()
	else:
		return
	get_viewport().set_input_as_handled()


func _fermer() -> void:
	var t := create_tween()
	t.tween_property(_cadre, "modulate:a", 0.0, 0.25)
	await t.finished
	_cadre.hide()
	fini.emit()
