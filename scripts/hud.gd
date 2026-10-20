class_name Hud
extends CanvasLayer
## Interface en jeu, d'après les maquettes HUD du Figma :
## discrétion (œil + jauge), objectif (lune + parchemin), points de vie,
## invite d'action, marqueurs ? / ! au-dessus des gardes et bords rouges.

const GRIS_ARDOISE := Color("#4B5160")
const BOIS := Color("#3A2A1E")

enum Etat { CACHE, EXPOSE, REPERE, DECOUVERT }

var niveau: Niveau

var _dessin: Control
var _vignette: TextureRect
var _etat := Etat.CACHE
var _jauge := 0.2
var _invite := 0.0  # opacité de l'invite d'action
var _action := ""
var _vie_vue := 3
var _eclat := 0.0  # flash rouge quand on prend un coup

var _anton: Font
var _plex_bold: Font
var _plex_semibold: Font
var _plex: Font
var _kanji: Font


func _ready() -> void:
	layer = 5
	niveau = get_parent() as Niveau

	_vignette = TextureRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture = _texture_vignette()
	_vignette.modulate.a = 0.0
	add_child(_vignette)

	_dessin = Control.new()
	_dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dessin.draw.connect(_dessiner)
	add_child(_dessin)

	_anton = _dessin.get_theme_font("font", "TitreHud")
	_plex_bold = _dessin.get_theme_font("font", "Touche")
	_plex_semibold = _dessin.get_theme_font("font", "Consigne")
	_plex = _dessin.get_theme_font("font", "Label")
	_kanji = _dessin.get_theme_font("font", "Kanji")


func _process(delta: float) -> void:
	if niveau == null:
		return
	# pendant les cinématiques, l'écran reste propre
	_dessin.visible = not niveau.en_cinematique
	var ninja := niveau.ninja
	var soupcon := 0.0
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		if garde.etat != Garde.Etat.MORT:
			soupcon = maxf(soupcon, garde.soupcon)

	var cible: float
	if niveau.decouvert or niveau.en_chasse():
		_etat = Etat.DECOUVERT
		cible = 1.0
	elif soupcon > 0.0:
		_etat = Etat.REPERE
		cible = 0.6 + soupcon * 0.35
	elif ninja.est_cache():
		_etat = Etat.CACHE
		cible = 0.2
	else:
		_etat = Etat.EXPOSE
		cible = 0.55 if ninja.est_eclaire() else 0.4
	_jauge = lerpf(_jauge, cible, 1.0 - exp(-10.0 * delta))

	if ninja.vie < _vie_vue:
		_eclat = 1.0
	_vie_vue = ninja.vie
	_eclat = maxf(0.0, _eclat - delta * 2.5)
	var rouge := 1.0 if niveau.decouvert else 0.7 if niveau.en_chasse() else soupcon * 0.45
	rouge = maxf(rouge, _eclat)
	_vignette.modulate.a = lerpf(_vignette.modulate.a, rouge, 1.0 - exp(-8.0 * delta))

	var objet := ninja.objet_proche() if not ninja.bloque else null
	if objet:
		_action = objet.texte_action()
	var montre := objet != null
	_invite = move_toward(_invite, 1.0 if montre else 0.0, delta * 6.0)
	_dessin.queue_redraw()


func _dessiner() -> void:
	if niveau == null:
		return
	var taille := _dessin.size
	_dessiner_discretion()
	_dessiner_objectif(taille.x)
	_dessiner_vie(taille.y)
	if _invite > 0.01:
		_dessiner_invite(taille)
	_dessiner_marqueurs()


# --- Discrétion (en haut à gauche) ---------------------------------------

func _dessiner_discretion() -> void:
	var textes := ["CACHÉ", "EXPOSÉ", "REPÉRÉ", "DÉCOUVERT"]
	var couleurs := [Palette.WASHI, Palette.WASHI, Palette.OR, Palette.LAQUE]
	var couleur: Color = couleurs[_etat]
	_dessiner_oeil(Rect2(64, 56, 90, 66), _etat == Etat.CACHE, couleur)
	_texte(_anton, textes[_etat], Vector2(178, 56), 51, couleur)
	_dessin.draw_rect(Rect2(178, 145, 330, 9), GRIS_ARDOISE)
	_dessin.draw_rect(Rect2(178, 145, 330 * _jauge, 9), couleur)
	_texte(_plex, "Visibilité", Vector2(178, 166), 22, Palette.GRIS)


func _dessiner_oeil(zone: Rect2, ferme: bool, couleur: Color) -> void:
	var c := zone.get_center()
	var rx := zone.size.x / 2.0
	var ry := zone.size.y / 2.0
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in 21:
		var t := float(i) / 20.0
		var x := c.x - rx + t * rx * 2.0
		var h := sin(t * PI)
		haut.append(Vector2(x, c.y - h * ry * 0.9))
		bas.append(Vector2(x, c.y + h * ry * 0.9))
	if ferme:
		# Paupière fermée : un arc et trois cils.
		_dessin.draw_polyline(bas, couleur, 5.0, true)
		for k in [-0.5, 0.0, 0.5]:
			var p := Vector2(c.x + k * rx, c.y + ry * 0.9 * cos(k * PI / 2.0))
			_dessin.draw_line(p, p + Vector2(k * 10.0, 14.0), couleur, 4.0, true)
		return
	var amande := haut.duplicate()
	bas.reverse()
	amande.append_array(bas)
	_dessin.draw_colored_polygon(amande, couleur)
	_dessin.draw_circle(c, ry * 0.62, Palette.ENCRE)
	_dessin.draw_circle(c, ry * 0.26, couleur if _etat != Etat.EXPOSE else Palette.LAQUE)
	_dessin.draw_circle(c + Vector2(-7, -7), 4.0, Palette.WASHI)


# --- Objectif (en haut à droite) -----------------------------------------

func _dessiner_objectif(largeur: float) -> void:
	var x := largeur - 342.0
	# Croissant de lune : il pâlit quand les nuages la cachent.
	var lune := Palette.LUNE if niveau.lune_visible else Color(Palette.GRIS, 0.45)
	var croissant := Geometry2D.clip_polygons(_cercle(Vector2(x + 30, 95), 30.0), _cercle(Vector2(x + 44, 86), 26.0))
	for morceau in croissant:
		_dessin.draw_colored_polygon(morceau, lune)
	_texte(_kanji, "巻", Vector2(largeur - 249.0, 56), 60, Palette.OR)
	var compte := "1 / 1" if niveau.a_le_parchemin else "0 / 1"
	_texte(_anton, compte, Vector2(largeur - 165.0, 59), 54,
		Palette.OR if niveau.a_le_parchemin else Palette.WASHI)


# --- Points de vie (en bas à gauche) ---------------------------------------

func _dessiner_vie(hauteur: float) -> void:
	var y := hauteur - 95.0
	_texte(_plex_bold, "VIE", Vector2(64, y + 1), 25, Palette.WASHI)
	var ninja := niveau.ninja
	for i in ninja.vie_max:
		var centre := Vector2(150 + i * 54 + 20, y + 20)
		var plein := i < ninja.vie
		# le cœur qu'on vient de perdre grossit un instant
		var taille := 20.0 * (1.0 + (_eclat * 0.5 if i == ninja.vie else 0.0))
		_coeur(centre, taille, Palette.LAQUE if plein else GRIS_ARDOISE)
		if plein:
			_coeur(centre + Vector2(-6, -6), taille * 0.28, Color(Palette.WASHI, 0.6))


func _coeur(centre: Vector2, r: float, couleur: Color) -> void:
	var points := PackedVector2Array()
	for k in 40:
		var t := TAU * k / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var yy := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
		points.append(centre + Vector2(x, -yy) * r / 16.0)
	_dessin.draw_colored_polygon(points, couleur)


# --- Invite d'action (en bas à droite) -----------------------------------

func _dessiner_invite(taille: Vector2) -> void:
	var a := _invite
	var r := Rect2(taille.x - 618.0, taille.y - 144.0, 554, 88)
	_dessin.draw_rect(Rect2(r.position + Vector2(6, 6), r.size), Color(Palette.NOIR, 0.4 * a))
	_dessin.draw_rect(r, Color(Palette.WASHI, a))
	_dessin.draw_line(r.position + Vector2(0, r.size.y - 1), r.end - Vector2(0, 1), Color(Palette.WASHI.darkened(0.15), a), 2)
	# Rouleau à gauche
	_dessin.draw_rect(Rect2(r.position.x - 10, r.position.y - 10, 18, r.size.y + 20), Color(BOIS, a))
	_dessin.draw_rect(Rect2(r.position.x - 12, r.position.y - 20, 22, 12), Color(Palette.OR, a))
	_dessin.draw_rect(Rect2(r.position.x - 12, r.end.y + 8, 22, 12), Color(Palette.OR, a))
	# Touche E
	var touche := Rect2(r.position.x + 34, r.position.y + 15, 55, 58)
	_dessin.draw_rect(touche, Color(Palette.ENCRE, a))
	_texte(_plex_bold, "E", touche.position + Vector2(17, 9), 30, Color(Palette.WASHI, a))
	_texte(_plex_semibold, _action, Vector2(r.position.x + 112, r.position.y + 21), 30, Color(Palette.ENCRE, a))


# --- Marqueurs au-dessus des gardes ---------------------------------------

func _dessiner_marqueurs() -> void:
	var camera := _dessin.get_viewport().get_camera_3d()
	if camera == null:
		return
	for garde: Garde in get_tree().get_nodes_in_group("gardes"):
		var alerte := garde.etat == Garde.Etat.ALERTE or garde.etat == Garde.Etat.CHASSE
		var mefiant := garde.etat == Garde.Etat.ENQUETE or (garde.etat == Garde.Etat.RONDE and garde.soupcon > 0.0)
		if not (alerte or mefiant):
			continue
		var monde := garde.global_position + Vector3.UP * 2.7
		if camera.is_position_behind(monde):
			continue
		var p := camera.unproject_position(monde)
		_losange(p, 34.0, Palette.LAQUE if alerte else Palette.OR)
		var signe := "!" if alerte else "?"
		var largeur := _anton.get_string_size(signe, HORIZONTAL_ALIGNMENT_LEFT, -1, 42).x
		_texte(_anton, signe, p - Vector2(largeur / 2.0, 30), 42, Palette.WASHI if alerte else Palette.ENCRE)


# --- Outils ----------------------------------------------------------------

## Écrit un texte dont `haut_gauche` est le coin haut gauche, comme dans Figma.
func _texte(police: Font, texte: String, haut_gauche: Vector2, taille: int, couleur: Color) -> void:
	_dessin.draw_string(police, haut_gauche + Vector2(0, police.get_ascent(taille)), texte,
		HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)


func _cercle(centre: Vector2, rayon: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 48:
		points.append(centre + Vector2.from_angle(TAU * i / 48.0) * rayon)
	return points


func _losange(centre: Vector2, rayon: float, couleur: Color) -> void:
	if rayon <= 0.5:
		return
	_dessin.draw_colored_polygon(PackedVector2Array([
		centre + Vector2(0, -rayon), centre + Vector2(rayon, 0),
		centre + Vector2(0, rayon), centre + Vector2(-rayon, 0)]), couleur)


func _texture_vignette() -> GradientTexture2D:
	var degrade := Gradient.new()
	degrade.set_offset(0, 0.55)
	degrade.set_color(0, Color(Palette.LAQUE, 0.0))
	degrade.set_offset(1, 1.0)
	degrade.set_color(1, Color(Palette.LAQUE, 0.75))
	var texture := GradientTexture2D.new()
	texture.gradient = degrade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 1.0)
	texture.width = 256
	texture.height = 256
	return texture
