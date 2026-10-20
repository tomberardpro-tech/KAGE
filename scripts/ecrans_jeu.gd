class_name EcransJeu
extends CanvasLayer
## Écrans par-dessus la partie, d'après le Figma : tutoriel de départ,
## pause, défaite (DÉCOUVERT) et victoire avec le score.

const SCENE_MENU := "res://scenes/ui/menu.tscn"

var niveau: Niveau

var _voile: ColorRect
var _tutoriel: Control
var _pause: Control
var _defaite: Control
var _victoire: Control
var _reprendre: MenuBouton
var _stats: HBoxContainer
var _phrase_victoire: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	niveau = get_parent() as Niveau

	_voile = ColorRect.new()
	_voile.color = Color(Palette.NOIR, 0.45)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_voile)

	_tutoriel = _construire_tutoriel()
	_pause = _construire_pause()
	_defaite = _construire_defaite()
	_victoire = _construire_victoire()
	_tout_cacher()


func _tout_cacher() -> void:
	for page in [_voile, _tutoriel, _pause, _defaite, _victoire]:
		page.hide()
	_hud(true)


func _montrer(page: Control, voile := 0.45) -> void:
	_tout_cacher()
	# Le HUD reste visible sur la défaite (œil DÉCOUVERT et bords rouges), pas ailleurs.
	_hud(page == _defaite)
	_voile.color.a = voile
	_voile.show()
	page.show()
	page.modulate.a = 0.0
	create_tween().tween_property(page, "modulate:a", 1.0, 0.25)


func en_cours() -> bool:
	return _voile.visible


func _hud(visible_: bool) -> void:
	var hud := niveau.get_node_or_null("Hud") as CanvasLayer
	if hud:
		hud.visible = visible_


# --- Entrées ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	var touche_r: bool = event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).physical_keycode == KEY_R
	if _tutoriel.visible:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			fermer_tutoriel()
	elif _defaite.visible:
		if touche_r or event.is_action_pressed("ui_accept"):
			_tout_cacher()
			niveau.recommencer_a_l_autel()
		elif event.is_action_pressed("pause"):
			_vers_menu()
	elif _victoire.visible:
		if event.is_action_pressed("ui_accept"):
			_continuer()
		elif touche_r:
			get_tree().paused = false
			Transition.vers(niveau.scene_file_path)
	elif _pause.visible:
		if event.is_action_pressed("pause"):
			reprendre()
	elif event.is_action_pressed("pause") and niveau.peut_mettre_en_pause():
		mettre_en_pause()
	else:
		return
	get_viewport().set_input_as_handled()


func _vers_menu() -> void:
	get_tree().paused = false
	Transition.vers(SCENE_MENU)


## Après la victoire : niveau suivant, ou retour au menu après le dernier.
func _continuer() -> void:
	if niveau.niveau_suivant.is_empty():
		_vers_menu()
		return
	get_tree().paused = false
	Transition.vers(niveau.niveau_suivant)


# --- Tutoriel --------------------------------------------------------------

func tutoriel() -> void:
	get_tree().paused = true
	_montrer(_tutoriel)


func fermer_tutoriel() -> void:
	_tout_cacher()
	get_tree().paused = false


func _construire_tutoriel() -> Control:
	var page := _page()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.add_child(centre)

	var rouleau := Rouleau.new()
	rouleau.vertical = true
	rouleau.custom_minimum_size = Vector2(1026, 300)
	centre.add_child(rouleau)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	rouleau.add_child(v)

	v.add_child(_label("NIVEAU %d · %s" % [niveau.numero, niveau.titre], &"Aide", 18, Palette.LAQUE))
	var titre := HBoxContainer.new()
	titre.add_theme_constant_override("separation", 22)
	v.add_child(titre)
	titre.add_child(_label("影", &"Kanji", 52))
	var t := _label("Reste dans l'ombre", &"TitreParchemin", 44, Palette.LAQUE)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titre.add_child(t)

	var corps := _label("Tant que tu n'es pas éclairé, les gardes ont du mal à te voir. "
		+ "Accroupis-toi dans les herbes hautes, reste à l'ombre des arbres et tranche "
		+ "les lanternes (E). Ton katana (L ou clic gauche) tranche les gardes. "
		+ "Tu as 3 points de vie : chaque coup de garde t'en retire un.\n"
		+ niveau.objectif,
		&"TexteParchemin", 24)
	corps.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corps.custom_minimum_size.x = 860
	v.add_child(corps)

	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", 12)
	v.add_child(pied)
	pied.add_child(_touche("ENTRÉE", true))
	pied.add_child(_label("COMMENCER", &"Aide", 18, Palette.ENCRE))
	return page


# --- Pause -------------------------------------------------------------------

func mettre_en_pause() -> void:
	get_tree().paused = true
	_montrer(_pause, 0.6)
	_reprendre.grab_focus()


func reprendre() -> void:
	_tout_cacher()
	get_tree().paused = false


func _construire_pause() -> Control:
	var page := _page()

	var fond := _label("休", &"KanjiFond", 600)
	fond.position = Vector2(1180, 160)
	page.add_child(fond)

	var v := VBoxContainer.new()
	v.position = Vector2(150, 150)
	v.add_theme_constant_override("separation", 0)
	page.add_child(v)
	v.add_child(_label("一時停止", &"Kanji", 44))
	v.add_child(_label("PAUSE", &"TitreEcran", 140))
	var espace := Control.new()
	espace.custom_minimum_size.y = 30
	v.add_child(espace)

	_reprendre = _bouton(v, "REPRENDRE", reprendre)
	_bouton(v, "RECOMMENCER À L'AUTEL", func():
		_tout_cacher()
		niveau.recommencer_a_l_autel())
	_bouton(v, "QUITTER VERS LE MENU", _vers_menu)

	var pied := _pied([["↑ ↓", "CHOISIR"], ["ENTRÉE", "VALIDER"], ["ÉCHAP", "REPRENDRE"]])
	pied.position = Vector2(150, 976)
	page.add_child(pied)
	return page


func _bouton(parent: Control, texte: String, action: Callable) -> MenuBouton:
	var bouton := MenuBouton.new()
	bouton.texte = texte
	bouton.pressed.connect(action)
	parent.add_child(bouton)
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return bouton


# --- Défaite -----------------------------------------------------------------

func defaite() -> void:
	get_tree().paused = true
	_montrer(_defaite, 0.25)


func _construire_defaite() -> Control:
	var page := _page()
	var v := _colonne_centrale(page)
	var rouleau := Rouleau.new()
	rouleau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rouleau)
	var titre := _label("DÉCOUVERT", &"TitreEcran", 110, Palette.LAQUE)
	rouleau.add_child(_marge(titre, 0, 70))
	v.add_child(_consigne("Les gardes ont eu raison de toi."))
	v.add_child(_pied([["R", "RECOMMENCER À L'AUTEL"], ["ÉCHAP", "MENU"]], true))
	return page


# --- Victoire ----------------------------------------------------------------

func victoire(temps: float, fantome: bool, pacifiste: bool) -> void:
	get_tree().paused = true
	for enfant in _stats.get_children():
		enfant.queue_free()
	_stats.add_child(_stat("時", Palette.OR, _valeur_texte("%02d:%02d" % [int(temps) / 60, int(temps) % 60]), "TEMPS"))
	_stats.add_child(_stat("影", Palette.LAQUE, _valeur(fantome), "FANTÔME · PERSONNE NE T'A VU"))
	_phrase_victoire.text = "Le clan te remercie. %s n'a jamais su que tu étais là." % niveau.lieu if fantome \
		else "Le clan te remercie. On t'a vu, mais le parchemin est rentré."
	_stats.add_child(_stat("和", Palette.GRIS, _valeur(pacifiste), "PACIFISTE · AUCUN GARDE TUÉ"))
	_montrer(_victoire, 0.55)


func _construire_victoire() -> Control:
	var page := _page()
	var v := _colonne_centrale(page)
	var rouleau := Rouleau.new()
	rouleau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(rouleau)
	rouleau.add_child(_marge(_label("PARCHEMIN RÉCUPÉRÉ", &"TitreEcran", 96, Palette.ENCRE), 0, 70))
	_phrase_victoire = _consigne("")
	v.add_child(_phrase_victoire)

	var panneau := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.ENCRE, 0.88)
	style.border_color = Color(Palette.OR, 0.6)
	style.border_width_top = 3
	style.content_margin_left = 50
	style.content_margin_right = 50
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	panneau.add_theme_stylebox_override("panel", style)
	panneau.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(panneau)
	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 70)
	panneau.add_child(_stats)

	v.add_child(_pied([["ENTRÉE", "CONTINUER"], ["R", "REJOUER"]], true))
	return page


func _stat(kanji: String, couleur: Color, valeur: Control, legende: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 6)
	col.custom_minimum_size.x = 260
	for enfant: Control in [_label(kanji, &"Kanji", 56, couleur), valeur, _label(legende, &"Aide", 16)]:
		enfant.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(enfant)
	return col


func _valeur_texte(texte: String) -> Label:
	return _label(texte, &"TitreHud", 64)


## ✓ dessiné (la police n'a pas ce signe) ou tiret si le bonus est raté.
func _valeur(reussi: bool) -> Control:
	if not reussi:
		return _valeur_texte("–")
	var coche := Control.new()
	coche.custom_minimum_size = Vector2(64, 88)
	coche.draw.connect(func():
		coche.draw_polyline(PackedVector2Array([Vector2(8, 46), Vector2(26, 66), Vector2(58, 22)]),
			Palette.WASHI, 9.0, true))
	return coche


# --- Outils de construction --------------------------------------------------

func _page() -> Control:
	var page := Control.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page)
	return page


func _colonne_centrale(page: Control) -> VBoxContainer:
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(centre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 34)
	centre.add_child(v)
	return v


func _label(texte: String, variation: StringName, taille := 0, couleur := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = texte
	l.theme_type_variation = variation
	if taille > 0:
		l.add_theme_font_size_override("font_size", taille)
	if couleur.a > 0.0:
		l.add_theme_color_override("font_color", couleur)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _consigne(texte: String) -> Label:
	var l := _label(texte, &"Consigne", 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 3)
	return l


func _marge(enfant: Control, vertical: int, horizontal: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", horizontal)
	m.add_theme_constant_override("margin_right", horizontal)
	m.add_theme_constant_override("margin_top", vertical)
	m.add_theme_constant_override("margin_bottom", vertical)
	m.add_child(enfant)
	return m


## Touche dans son cadre washi, ou encre quand elle est posée sur un parchemin.
func _touche(texte: String, sur_parchemin := false) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.theme_type_variation = &"ToucheCadre"
	var l := _label(texte, &"Touche")
	if sur_parchemin:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.ENCRE
		style.content_margin_left = 12
		style.content_margin_right = 12
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		cadre.add_theme_stylebox_override("panel", style)
		l.add_theme_color_override("font_color", Palette.WASHI)
	cadre.add_child(l)
	return cadre


func _pied(touches: Array, centre := false) -> HBoxContainer:
	var pied := HBoxContainer.new()
	pied.add_theme_constant_override("separation", 12)
	if centre:
		pied.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in touches.size():
		if k > 0:
			var espace := Control.new()
			espace.custom_minimum_size.x = 20
			pied.add_child(espace)
		pied.add_child(_touche(touches[k][0]))
		pied.add_child(_label(touches[k][1], &"Aide"))
	return pied
