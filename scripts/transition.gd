extends CanvasLayer
## Fondu au noir entre deux écrans, avec un écran de chargement : le niveau se charge
## en arrière-plan pendant qu'un shuriken tourne et qu'un pourcentage monte. Le chargement dure
## au moins DUREE_MIN secondes, le temps que tout soit vraiment prêt (pas de gel en jouant).
## À l'arrivée, l'écran noir est tranché en deux d'un coup de sabre et s'ouvre sur le jeu.
## Accessible partout via Transition.

var _voile: ColorRect
var _chargement: Control
var _texte: Label
var _progres := 0.0
var _angle := 0.0
var _en_cours := false
var _affiche := 0.0  # pourcentage montré (monte en douceur vers _progres)
var _fente: Control  # les deux moitiés de l'écran noir qui s'écartent à l'arrivée
var _ouverture := 0.0
var _eclair := 0.0

const DUREE_MIN := 5.0  ## s : durée minimale de l'écran de chargement d'un niveau


func _ready() -> void:
	layer = 100
	# le tutoriel met le jeu en pause dès l'arrivée : le fondu doit continuer quand même
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voile = ColorRect.new()
	_voile.color = Palette.NOIR
	_voile.modulate.a = 0.0
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_voile)
	_chargement = Control.new()
	_chargement.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chargement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chargement.draw.connect(_dessiner_chargement)
	_voile.add_child(_chargement)
	_texte = Label.new()
	_texte.text = "CHARGEMENT"
	_texte.theme_type_variation = &"Aide"
	_texte.add_theme_font_size_override("font_size", 22)
	_texte.add_theme_color_override("font_color", Palette.WASHI)
	_texte.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_texte.position = Vector2(-160, -120)
	_texte.custom_minimum_size = Vector2(320, 0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chargement.add_child(_texte)
	_chargement.hide()
	_fente = Control.new()
	_fente.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fente.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fente.draw.connect(_dessiner_fente)
	_fente.hide()
	add_child(_fente)


func _process(delta: float) -> void:
	if _chargement.visible:
		_angle += delta * 6.0
		_chargement.queue_redraw()
	if _fente.visible:
		_fente.queue_redraw()


func vers(scene: String, duree := 0.5) -> void:
	if _en_cours:
		return
	_en_cours = true
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	ResourceLoader.load_threaded_request(scene)
	var tween := create_tween()
	tween.tween_property(_voile, "modulate:a", 1.0, duree)
	await tween.finished
	# Le niveau se charge (première moitié du pourcentage), puis prépare ses matières
	# derrière le voile (Niveau.prechauffer, seconde moitié) pendant que le shuriken tourne.
	_progres = 0.0
	_affiche = 0.0
	_chargement.show()
	var debut := Time.get_ticks_msec()
	var avancement := []
	while ResourceLoader.load_threaded_get_status(scene, avancement) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_progres = (avancement[0] if avancement.size() > 0 else 0.0) * 0.5
		await _attendre_image(debut)
	var paquet := ResourceLoader.load_threaded_get(scene) as PackedScene
	_progres = 0.5
	if paquet:
		get_tree().change_scene_to_packed(paquet)
	else:
		get_tree().change_scene_to_file(scene)
	for i in 2:
		await _attendre_image(debut)
	var nouvelle := get_tree().current_scene
	var niveau := nouvelle != null and "est_pret" in nouvelle
	var limite := Time.get_ticks_msec() + 20000
	while niveau and not nouvelle.est_pret and Time.get_ticks_msec() < limite:
		_progres = 0.5 + 0.5 * float(nouvelle.get("avancement"))
		await _attendre_image(debut)
	_progres = 1.0
	# un niveau garde l'écran de chargement au moins DUREE_MIN s, jusqu'à 100 %
	while niveau and _affiche < 0.999:
		await _attendre_image(debut)
	_chargement.hide()
	if niveau:
		await _trancher()
	else:
		tween = create_tween()
		tween.tween_property(_voile, "modulate:a", 0.0, duree)
		await tween.finished
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_en_cours = false


## Une image de plus : le pourcentage affiché rattrape le vrai, sans dépasser le temps écoulé
## rapporté à DUREE_MIN (il monte régulièrement au lieu de sauter).
func _attendre_image(debut: int) -> void:
	await get_tree().process_frame
	var temps := (Time.get_ticks_msec() - debut) / 1000.0
	var cible := minf(_progres, temps / DUREE_MIN)
	_affiche = move_toward(_affiche, cible, get_process_delta_time() * 0.6)
	_texte.text = "CHARGEMENT  %d %%" % int(round(_affiche * 100.0))


## Arrivée stylée : un éclair blanc traverse l'écran en diagonale, puis les deux moitiés
## de l'écran noir s'écartent de part et d'autre de la coupure.
func _trancher() -> void:
	_ouverture = 0.0
	_eclair = 0.0
	_fente.show()
	_voile.modulate.a = 0.0
	Sons.jouer("tranche", -12.0, 0.9)
	var t := create_tween()
	t.tween_property(self, "_eclair", 1.0, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.12)
	t.tween_property(self, "_ouverture", 1.0, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "_eclair", 0.0, 0.6)
	await t.finished
	_fente.hide()


func _dessiner_fente() -> void:
	var taille := _fente.size
	# la coupure va du haut, un peu à droite du centre, au bas, un peu à gauche
	var haut := Vector2(taille.x * 0.62, -10.0)
	var bas := Vector2(taille.x * 0.38, taille.y + 10.0)
	var normale := (bas - haut).orthogonal().normalized()
	var ecart := normale * taille.length() * 0.6 * _ouverture
	var loin := taille.length()
	var gauche := PackedVector2Array([haut - ecart, bas - ecart, bas - ecart - normale * loin, haut - ecart - normale * loin])
	var droite := PackedVector2Array([haut + ecart, bas + ecart, bas + ecart + normale * loin, haut + ecart + normale * loin])
	_fente.draw_colored_polygon(gauche, Palette.NOIR)
	_fente.draw_colored_polygon(droite, Palette.NOIR)
	if _eclair > 0.01:
		var longueur := _eclair  # l'éclair se trace du haut vers le bas
		_fente.draw_line(haut, haut.lerp(bas, longueur), Color(Palette.LAQUE, _eclair * 0.6), 16.0 * (1.0 - _ouverture) + 2.0, true)
		_fente.draw_line(haut, haut.lerp(bas, longueur), Color(Palette.WASHI, _eclair), 6.0 * (1.0 - _ouverture) + 1.0, true)


## Shuriken qui tourne et barre d'avancement fine sous le mot CHARGEMENT.
func _dessiner_chargement() -> void:
	var c := _chargement.size / 2.0
	var r := 34.0
	var pts := PackedVector2Array()
	for i in 8:
		var a := _angle + i * TAU / 8.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.32))
	_chargement.draw_colored_polygon(pts, Palette.WASHI)
	_chargement.draw_circle(c, 6.0, Palette.NOIR)
	var largeur := 240.0
	var y := _chargement.size.y - 80.0
	_chargement.draw_rect(Rect2(c.x - largeur / 2.0, y, largeur, 3), Color(Palette.WASHI, 0.2))
	_chargement.draw_rect(Rect2(c.x - largeur / 2.0, y, largeur * _progres, 3), Palette.LAQUE)
