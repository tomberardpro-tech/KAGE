class_name Dialogue
extends CanvasLayer
## Boîte de dialogue des cinématiques : bandeau d'encre en bas de l'écran, médaillon du personnage,
## nom sur une plaque de laque, réplique japonaise dite à voix haute (assets/audio/voix/) avec la
## traduction qui s'écrit lettre par lettre. ENTRÉE pour continuer, ÉCHAP pour tout passer.
## var passe := await dialogue.jouer("intro")   # vrai si le joueur a tout passé

signal fini

const VITESSE := 40.0  ## lettres par seconde
const DIALOGUES := "res://assets/dialogues.json"

var passe := false

var _lignes: Array = []
var _index := 0
var _ecrit := 0.0
var _ouvert := false
var _t := 0.0
var _fond: Control
var _portrait: TextureRect
var _nom: Label
var _jp: Label
var _texte: Label
var _aide: Label
var _voix: AudioStreamPlayer

static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		_donnees = JSON.parse_string(FileAccess.get_file_as_string(DIALOGUES))
	return _donnees


func _ready() -> void:
	layer = 11
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fond = Control.new()
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fond.draw.connect(_dessiner)
	add_child(_fond)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.size = Vector2(190, 190)
	_fond.add_child(_portrait)
	_nom = _label(&"TitreParchemin", 30, Palette.WASHI)
	_jp = _label(&"", 27, Palette.OR)
	_jp.add_theme_font_override("font", load("res://assets/fonts/NotoSerifJP-Bold-dialogues.otf"))
	_texte = _label(&"", 31, Palette.WASHI)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.add_theme_constant_override("line_spacing", 6)
	_aide = _label(&"Aide", 18, Palette.GRIS)
	_aide.text = "ENTRÉE · SUITE      ÉCHAP · PASSER"
	_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_voix = AudioStreamPlayer.new()
	_voix.volume_db = 2.0
	add_child(_voix)
	_fond.hide()


func _label(variation: StringName, taille: int, couleur: Color) -> Label:
	var l := Label.new()
	if variation != &"":
		l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fond.add_child(l)
	return l


## Joue un dialogue de assets/dialogues.json (« intro », « oni_debut »…). Renvoie vrai si passé.
func jouer(cle: String) -> bool:
	var d: Dictionary = donnees()[cle]
	_nom.text = d["nom"]
	_portrait.texture = load("res://assets/textures/portrait_%s.png" % d["portrait"])
	_lignes = d["lignes"]
	_index = 0
	passe = false
	_ouvert = true
	# l'aide de la cinématique se cache : la boîte a la sienne
	for c in get_parent().get_children():
		if c is Cinema:
			c.aide_visible(false)
	_placer()
	_montrer_ligne()
	_fond.show()
	_fond.modulate.a = 0.0
	create_tween().tween_property(_fond, "modulate:a", 1.0, 0.35)
	await fini
	return passe


func _placer() -> void:
	var taille := _fond.size if _fond.size.x > 0 else Vector2(1920, 1080)
	var r := _cadre(taille)
	_portrait.position = Vector2(r.position.x + 24, r.position.y + r.size.y / 2.0 - 95)
	_nom.position = Vector2(r.position.x + 250, r.position.y - 44)
	_jp.position = Vector2(r.position.x + 250, r.position.y + 26)
	_texte.position = Vector2(r.position.x + 250, r.position.y + 76)
	_texte.size = Vector2(r.size.x - 320, 120)
	_aide.position = Vector2(r.end.x - 520, r.end.y + 14)
	_aide.size = Vector2(500, 24)


func _cadre(taille: Vector2) -> Rect2:
	var largeur := minf(1500.0, taille.x - 120.0)
	return Rect2((taille.x - largeur) / 2.0, taille.y - 330.0, largeur, 236.0)


func _montrer_ligne() -> void:
	var ligne: Dictionary = _lignes[_index]
	_jp.text = ligne["jp"]
	_texte.text = ligne["fr"]
	_texte.visible_characters = 0
	_jp.modulate.a = 0.0
	create_tween().tween_property(_jp, "modulate:a", 1.0, 0.5)
	_ecrit = 0.0
	var chemin := "res://assets/audio/voix/%s.ogg" % ligne["id"]
	_voix.stop()
	if ResourceLoader.exists(chemin):
		_voix.stream = load(chemin)
		_voix.play()


func _process(delta: float) -> void:
	if not _ouvert:
		return
	_t += delta
	_ecrit += delta * VITESSE
	_texte.visible_characters = int(_ecrit)
	_fond.queue_redraw()


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
	_voix.stop()
	var t := create_tween()
	t.tween_property(_fond, "modulate:a", 0.0, 0.25)
	await t.finished
	_fond.hide()
	for c in get_parent().get_children():
		if c is Cinema and c.actif:
			c.aide_visible(true)
	fini.emit()


## Bandeau d'encre : dégradé noir qui monte du bas, cadre aux filets dorés, vagues seigaiha
## à peine visibles, plaque de laque pour le nom et petite flèche qui sautille en fin de ligne.
func _dessiner() -> void:
	var taille := _fond.size
	var r := _cadre(taille)
	# voile qui assombrit le bas de l'écran
	var bandes := 24
	for k in bandes:
		var y := taille.y - 420.0 + k * 420.0 / bandes
		_fond.draw_rect(Rect2(0, y, taille.x, 420.0 / bandes + 1), Color(Palette.NOIR, 0.55 * float(k) / bandes))
	_fond.draw_rect(r, Color("#101116", 0.94))
	# vagues seigaiha au bout droit du bandeau
	for i in 5:
		for j in 3:
			var c := Vector2(r.end.x - 60 - i * 56 - (28 if j % 2 else 0), r.end.y - 6 - j * 26)
			for k in 3:
				_fond.draw_arc(c, 26.0 - k * 8.0, PI, TAU, 16, Color(Palette.OR, 0.07), 2.0)
	for y in [r.position.y + 6, r.end.y - 6]:
		_fond.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Palette.OR, 0.8), 2.0)
	for y in [r.position.y + 12, r.end.y - 12]:
		_fond.draw_line(Vector2(r.position.x + 20, y), Vector2(r.end.x - 20, y), Color(Palette.OR, 0.25), 1.0)
	# plaque du nom
	var plaque := Rect2(r.position.x + 232, r.position.y - 52, _nom.get_minimum_size().x + 44, 50)
	_fond.draw_rect(plaque, Palette.LAQUE)
	_fond.draw_rect(plaque.grow(-4), Color(Palette.OR, 0.6), false, 1.5)
	# flèche de suite
	if _texte.visible_ratio >= 1.0:
		var bas := Vector2(r.end.x - 40, r.end.y - 34 + sin(_t * 6.0) * 4.0)
		_fond.draw_colored_polygon(PackedVector2Array([bas + Vector2(-10, -12), bas + Vector2(10, -12), bas]), Palette.OR)
