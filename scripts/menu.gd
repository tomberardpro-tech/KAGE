extends Control
## Menu principal : nouvelle partie, continuer, options, quitter.

const SCENE_JEU := "res://scenes/jeu.tscn"

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

	_nouvelle.pressed.connect(_lancer_partie)
	_continuer.pressed.connect(_lancer_partie)
	_options_bouton.pressed.connect(_ouvrir_options)
	_quitter.pressed.connect(get_tree().quit)

	_volume.value = Reglages.volume * 100.0
	_volume.value_changed.connect(func(v: float): Reglages.volume = v / 100.0)
	_plein_ecran.button_pressed = Reglages.plein_ecran
	_plein_ecran.toggled.connect(func(on: bool): Reglages.plein_ecran = on)
	%Retour.pressed.connect(_fermer_options)
	_options.hide()

	_nouvelle.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _options.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_fermer_options()
		get_viewport().set_input_as_handled()


func _lancer_partie() -> void:
	Transition.vers(SCENE_JEU)


func _ouvrir_options() -> void:
	_options.show()
	_volume.grab_focus()


func _fermer_options() -> void:
	Reglages.sauver()
	_options.hide()
	_options_bouton.grab_focus()
