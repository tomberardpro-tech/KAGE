extends Node
## Musiques et bruitages (sons enregistrés CC0 et sons de scripts/tools/generer_sons.py, voir CREDITS.md).
## La musique passe par le bus « Musique », le reste par « Bruitages » : réglables dans Options.
## Sons.jouer("dash") pour un bruitage, Sons.musique("jeu") pour changer de musique,
## Sons.chasse(true) pour passer en musique de poursuite (fondu).

const MUSIQUES := "res://assets/audio/music/%s.ogg"
const BRUITAGES := "res://assets/audio/sfx/%s.ogg"
const VOLUME_MUSIQUE := -14.0  ## dB : la musique reste en fond
const NB_VOIX := 10
## Les fichiers les plus forts sont baissés (dB) pour que tous les bruitages aient à peu près
## le même niveau (mesuré en LUFS : cri du boss, clochettes, coffre... étaient bien plus forts).
const CORRECTION := {"boss_cri": -9.0, "clochettes": -5.0, "coffre": -4.0, "frappe": -4.0, "coffre_apparait": -3.0,
	"alerte": -2.0, "boss_touche": -2.0, "herse": -2.0, "tresor": -3.0, "parchemin": -2.0}

var _musique: AudioStreamPlayer
var _poursuite: AudioStreamPlayer
var _voix: Array[AudioStreamPlayer] = []
var _suivante := 0
var _nom_musique := ""
var _en_chasse := false
var _cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_musique = _lecteur("Musique")
	_poursuite = _lecteur("Musique")
	_poursuite.volume_db = -80.0
	for i in NB_VOIX:
		_voix.append(_lecteur("Bruitages"))


func _lecteur(bus: String) -> AudioStreamPlayer:
	var l := AudioStreamPlayer.new()
	l.bus = bus
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


## Charge d'avance tous les bruitages (pendant l'écran de chargement) : pas de petit gel
## la première fois qu'on entend un son.
func precharger() -> void:
	var dossier := DirAccess.open(BRUITAGES.get_base_dir())
	if dossier == null:
		return
	for fichier in dossier.get_files():
		fichier = fichier.trim_suffix(".remap").trim_suffix(".import")
		if fichier.ends_with(".ogg"):
			_charger(BRUITAGES, fichier.get_basename())


## Bruitage. `volume` en dB, `hauteur` change un peu le ton pour éviter la répétition.
func jouer(nom: String, volume := 0.0, hauteur := 1.0) -> void:
	var flux := _charger(BRUITAGES, nom)
	if flux == null:
		return
	var voix := _voix[_suivante]
	_suivante = (_suivante + 1) % NB_VOIX
	voix.stream = flux
	voix.volume_db = volume + CORRECTION.get(nom, 0.0)
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
