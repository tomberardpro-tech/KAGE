extends Control
## Menu principal : nouvelle partie, continuer, options, quitter.

@onready var _nouvelle: MenuBouton = %NouvellePartie
@onready var _continuer: MenuBouton = %Continuer
@onready var _options_bouton: MenuBouton = %Options
@onready var _quitter: MenuBouton = %Quitter
@onready var _options: Control = %PanneauOptions
@onready var _volume: HSlider = %Volume
@onready var _plein_ecran: CheckButton = %PleinEcran


func _ready() -> void:
	_continuer.disabled = not Sauvegarde.existe()
	_continuer.rafraichir()
	# Dans le navigateur, on ne peut pas fermer le jeu : le bouton est masqué.
	_quitter.visible = not OS.has_feature("web")

	_nouvelle.pressed.connect(func(): Transition.vers(Sauvegarde.PREMIER_NIVEAU))
	_continuer.pressed.connect(func(): Transition.vers(Sauvegarde.niveau()))
	_options_bouton.pressed.connect(_ouvrir_options)
	_quitter.pressed.connect(get_tree().quit)

	_volume.value = Reglages.volume * 100.0
	_volume.value_changed.connect(func(v: float): Reglages.volume = v / 100.0)
	%VolumeMusique.value = Reglages.volume_musique * 100.0
	%VolumeMusique.value_changed.connect(func(v: float): Reglages.volume_musique = v / 100.0)
	%VolumeBruitages.value = Reglages.volume_bruitages * 100.0
	%VolumeBruitages.value_changed.connect(func(v: float): Reglages.volume_bruitages = v / 100.0)
	var qualite: OptionButton = %Qualite
	for nom in Reglages.QUALITES:
		qualite.add_item(nom)
	qualite.select(Reglages.qualite)
	qualite.item_selected.connect(func(i: int): Reglages.qualite = i)
	_plein_ecran.button_pressed = Reglages.plein_ecran
	_plein_ecran.toggled.connect(func(on: bool): Reglages.plein_ecran = on)
	%Retour.pressed.connect(_fermer_options)
	_options.hide()

	# pétales rouges qui tombent, devant le décor et derrière les boutons
	var petales := preload("res://scripts/petales_menu.gd").new()
	add_child(petales)
	move_child(petales, 1)

	_nouvelle.grab_focus()
	Sons.musique("menu")


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_fermer_options()
		get_viewport().set_input_as_handled()


func _ouvrir_options() -> void:
	_options.show()
	_volume.grab_focus()


func _fermer_options() -> void:
	Reglages.sauver()
	_options.hide()
	_options_bouton.grab_focus()
