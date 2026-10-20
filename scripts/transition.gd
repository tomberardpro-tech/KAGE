extends CanvasLayer
## Fondu au noir entre deux écrans, avec un écran de chargement : le niveau se charge
## en arrière-plan pendant qu'un shuriken tourne, au lieu d'un écran noir figé.
## Accessible partout via Transition.

var _voile: ColorRect
var _chargement: Control
var _texte: Label
var _progres := 0.0
var _angle := 0.0
var _en_cours := false


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
	_texte.position = Vector2(-80, -120)
	_texte.custom_minimum_size = Vector2(160, 0)
	_texte.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chargement.add_child(_texte)
	_chargement.hide()


func _process(delta: float) -> void:
	if _chargement.visible:
		_angle += delta * 6.0
		_chargement.queue_redraw()


func vers(scene: String, duree := 0.5) -> void:
	if _en_cours:
		return
	_en_cours = true
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	ResourceLoader.load_threaded_request(scene)
	var tween := create_tween()
	tween.tween_property(_voile, "modulate:a", 1.0, duree)
	await tween.finished
	# Le niveau finit de se charger pendant que le shuriken tourne.
	_progres = 0.0
	_chargement.show()
	var avancement := []
	while ResourceLoader.load_threaded_get_status(scene, avancement) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_progres = avancement[0] if avancement.size() > 0 else 0.0
		await get_tree().process_frame
	var paquet := ResourceLoader.load_threaded_get(scene) as PackedScene
	_progres = 1.0
	if paquet:
		get_tree().change_scene_to_packed(paquet)
	else:
		get_tree().change_scene_to_file(scene)
	# Quelques images derrière le voile : les matières se préparent sans saccade visible.
	for i in 4:
		await get_tree().process_frame
	_chargement.hide()
	tween = create_tween()
	tween.tween_property(_voile, "modulate:a", 0.0, duree)
	await tween.finished
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_en_cours = false


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
