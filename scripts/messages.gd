class_name Messages
extends CanvasLayer
## Gros titre au centre de l'écran (début de niveau, découvert, victoire).

@onready var _titre: Label = $Centre/V/Titre
@onready var _texte: Label = $Centre/V/Texte
@onready var _boite: Control = $Centre

var _tween: Tween


func _ready() -> void:
	_boite.modulate.a = 0.0


func afficher(titre: String, texte := "", duree := 2.0) -> void:
	_titre.text = titre
	_texte.text = texte
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_boite, "modulate:a", 1.0, 0.25)
	_tween.tween_interval(duree)
	_tween.tween_property(_boite, "modulate:a", 0.0, 0.5)
