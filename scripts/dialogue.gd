class_name Dialogue
extends CanvasLayer
## Boîte de dialogue des cinématiques, sobre et moderne : un panneau sombre arrondi en bas
## de l'écran, le nom du personnage dans une pastille rouge, le texte qui s'écrit lettre par lettre.
## ENTRÉE pour continuer, ÉCHAP pour tout passer.
## var passe := await dialogue.jouer("intro")   # vrai si le joueur a tout passé

signal fini

const VITESSE := 45.0  ## lettres par seconde
const DIALOGUES := "res://assets/dialogues.json"
const LARGEUR := 1240.0

var passe := false

var _lignes: Array = []
var _index := 0
var _ecrit := 0.0
var _ouvert := false
var _t := 0.0
var _racine: Control
var _panneau: PanelContainer
var _pastille: PanelContainer
var _nom: Label
var _texte: Label
var _suite: Label
var _aide: Label

static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		_donnees = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUES))
	return _donnees


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_racine = Control.new()
	_racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	_racine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_racine)
	var plex: Font = load("res://assets/fonts/IBMPlexSansJP-SemiBold.ttf")

	_panneau = PanelContainer.new()
	var fond := StyleBoxFlat.new()
	fond.bg_color = Color("#0d0f14", 0.86)
	fond.border_color = Color(1, 1, 1, 0.08)
	fond.set_border_width_all(1)
	fond.set_corner_radius_all(22)
	fond.content_margin_left = 44
	fond.content_margin_right = 44
	fond.content_margin_top = 34
	fond.content_margin_bottom = 30
	fond.shadow_color = Color(0, 0, 0, 0.35)
	fond.shadow_size = 18
	_panneau.add_theme_stylebox_override("panel", fond)
	_racine.add_child(_panneau)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	_panneau.add_child(colonne)
	_texte = Label.new()
	_texte.add_theme_font_override("font", plex)
	_texte.add_theme_font_size_override("font_size", 30)
	_texte.add_theme_color_override("font_color", Color("#f4f1ea"))
	_texte.add_theme_constant_override("line_spacing", 8)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size = Vector2(LARGEUR - 88, 84)
	colonne.add_child(_texte)
	_suite = Label.new()
	_suite.add_theme_font_override("font", plex)
	_suite.add_theme_font_size_override("font_size", 18)
	_suite.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	_suite.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_suite.text = "ENTRÉE  ▸"
	colonne.add_child(_suite)

	# pastille du nom, posée à cheval sur le bord haut du panneau
	_pastille = PanelContainer.new()
	var puce := StyleBoxFlat.new()
	puce.bg_color = Palette.LAQUE
	puce.set_corner_radius_all(20)
	puce.content_margin_left = 22
	puce.content_margin_right = 22
	puce.content_margin_top = 6
	puce.content_margin_bottom = 6
	_pastille.add_theme_stylebox_override("panel", puce)
	_racine.add_child(_pastille)
	_nom = Label.new()
	_nom.add_theme_font_override("font", plex)
	_nom.add_theme_font_size_override("font_size", 22)
	_nom.add_theme_color_override("font_color", Color.WHITE)
	_pastille.add_child(_nom)

	_aide = Label.new()
	_aide.add_theme_font_override("font", plex)
	_aide.add_theme_font_size_override("font_size", 16)
	_aide.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	_aide.text = "ÉCHAP  PASSER"
	_racine.add_child(_aide)
	_racine.hide()


## Joue un dialogue de assets/dialogues.json (« intro », « oni_debut »…). Renvoie vrai si passé.
func jouer(cle: String) -> bool:
	var d: Dictionary = donnees()[cle]
	_nom.text = d["nom"]
	_lignes = d["lignes"]
	_index = 0
	passe = false
	_ouvert = true
	# l'aide de la cinématique se cache : la boîte a la sienne
	for c in get_parent().get_children():
		if c is Cinema:
			c.aide_visible(false)
	_montrer_ligne()
	_racine.show()
	_placer()
	_racine.modulate.a = 0.0
	_panneau.position.y += 24.0
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_racine, "modulate:a", 1.0, 0.3)
	t.tween_property(_panneau, "position:y", _panneau.position.y - 24.0, 0.35)
	await fini
	return passe


func _placer() -> void:
	var taille := _racine.size if _racine.size.x > 0 else Vector2(1920, 1080)
	_panneau.size = Vector2(LARGEUR, 0)
	_panneau.reset_size()
	_panneau.size.x = LARGEUR
	_panneau.position = Vector2((taille.x - LARGEUR) / 2.0, taille.y - 90.0 - _panneau.size.y)
	_pastille.reset_size()
	_pastille.position = _panneau.position + Vector2(36, -_pastille.size.y / 2.0)
	_aide.position = Vector2(_panneau.position.x + LARGEUR - 140, _panneau.position.y + _panneau.size.y + 16)


func _montrer_ligne() -> void:
	var ligne: Dictionary = _lignes[_index]
	_texte.text = ligne["fr"]
	_texte.visible_characters = 0
	_ecrit = 0.0


func _process(delta: float) -> void:
	if not _ouvert:
		return
	_t += delta
	_ecrit += delta * VITESSE
	_texte.visible_characters = int(_ecrit)
	var fini_ := _texte.visible_ratio >= 1.0
	_suite.modulate.a = (0.6 + 0.4 * sin(_t * 4.0)) if fini_ else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not _ouvert:
		return
	if event.is_action_pressed("pause"):
		passe = true
		_fermer()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("frapper"):
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
	_ouvert = false
	var t := create_tween()
	t.tween_property(_racine, "modulate:a", 0.0, 0.25)
	await t.finished
	_racine.hide()
	for c in get_parent().get_children():
		if c is Cinema and c.actif:
			c.aide_visible(true)
	fini.emit()
