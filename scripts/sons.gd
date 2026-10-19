extends Node
## Musiques et bruitages. Tous les sons sont créés par synthèse avec scripts/tools/generer_sons.py.
## Sons.jouer("dash") pour un bruitage, Sons.musique("jeu") pour changer de musique,
## Sons.chasse(true) pour passer en musique de poursuite (fondu).

const MUSIQUES := "res://assets/audio/music/%s.ogg"
const BRUITAGES := "res://assets/audio/sfx/%s.ogg"
const VOLUME_MUSIQUE := -8.0  ## dB : la musique reste en fond
const NB_VOIX := 10

var _musique: AudioStreamPlayer
var _poursuite: AudioStreamPlayer
var _voix: Array[AudioStreamPlayer] = []
var _suivante := 0
var _nom_musique := ""
var _en_chasse := false
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_musique = _lecteur()
	_poursuite = _lecteur()
	_poursuite.volume_db = -80.0
	for i in NB_VOIX:
		_voix.append(_lecteur())


func _lecteur() -> AudioStreamPlayer:
	var l := AudioStreamPlayer.new()
	add_child(l)
	return l


func _charger(modele: String, nom: String, en_boucle := false) -> AudioStream:
	var chemin := modele % nom
	if not _cache.has(chemin):
		var flux: AudioStreamOggVorbis = load(chemin)
		if flux:
			flux = flux.duplicate()
			flux.loop = en_boucle
		_cache[chemin] = flux
	return _cache[chemin]


## Bruitage. `volume` en dB, `hauteur` change un peu le ton pour éviter la répétition.
func jouer(nom: String, volume := 0.0, hauteur := 1.0) -> void:
	var flux := _charger(BRUITAGES, nom)
	if flux == null:
		return
	var voix := _voix[_suivante]
	_suivante = (_suivante + 1) % NB_VOIX
	voix.stream = flux
	voix.volume_db = volume
	voix.pitch_scale = hauteur
	voix.play()


## Change la musique de fond avec un fondu ; "" coupe la musique.
func musique(nom: String) -> void:
	if nom == _nom_musique:
		return
	_nom_musique = nom
	_en_chasse = false
	_poursuite.stop()
	_poursuite.volume_db = -80.0
	var tween := create_tween()
	if _musique.playing:
		tween.tween_property(_musique, "volume_db", -40.0, 0.6)
	tween.tween_callback(func():
		_musique.stop()
		if nom.is_empty():
			return
		_musique.stream = _charger(MUSIQUES, nom, true)
		_musique.volume_db = -40.0
		_musique.play())
	if not nom.is_empty():
		tween.tween_property(_musique, "volume_db", VOLUME_MUSIQUE, 1.2)


## Musique courte jouée une fois (victoire, défaite), par-dessus le silence.
func jingle(nom: String) -> void:
	musique("")
	var voix := _voix[_suivante]
	_suivante = (_suivante + 1) % NB_VOIX
	voix.stream = _charger(MUSIQUES, nom)
	voix.volume_db = VOLUME_MUSIQUE + 4.0
	voix.pitch_scale = 1.0
	voix.play()


## Les tambours de poursuite montent quand un garde nous chasse, puis s'effacent.
func chasse(active: bool) -> void:
	if active == _en_chasse or _nom_musique.is_empty():
		return
	_en_chasse = active
	if active and not _poursuite.playing:
		_poursuite.stream = _charger(MUSIQUES, "chasse", true)
		_poursuite.play()
	var tween := create_tween().set_parallel()
	tween.tween_property(_poursuite, "volume_db", VOLUME_MUSIQUE + 2.0 if active else -80.0, 0.4 if active else 2.0)
	tween.tween_property(_musique, "volume_db", -30.0 if active else VOLUME_MUSIQUE, 0.4 if active else 2.0)
