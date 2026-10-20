extends Node
## Réglages du joueur (volumes, plein écran), gardés entre deux parties.
## Trois volumes : général, musique et bruitages (bus audio de default_bus_layout.tres).

const FICHIER := "user://reglages.cfg"

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))
		AudioServer.set_bus_mute(0, volume <= 0.0)

## La musique et les bruitages démarrent assez bas : la pluie et l'ambiance restent agréables.
var volume_musique := 0.45:
	set(v):
		volume_musique = clampf(v, 0.0, 1.0)
		_regler_bus("Musique", volume_musique)

var volume_bruitages := 0.6:
	set(v):
		volume_bruitages = clampf(v, 0.0, 1.0)
		_regler_bus("Bruitages", volume_bruitages)

var plein_ecran := false:
	set(v):
		plein_ecran = v
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) == OK:
		volume = cfg.get_value("audio", "volume", volume)
		volume_musique = cfg.get_value("audio", "musique", volume_musique)
		volume_bruitages = cfg.get_value("audio", "bruitages", volume_bruitages)
	else:
		volume = volume
		volume_musique = volume_musique
		volume_bruitages = volume_bruitages


func _regler_bus(nom: String, v: float) -> void:
	var bus := AudioServer.get_bus_index(nom)
	if bus < 0:
		return
	AudioServer.set_bus_volume_db(bus, linear_to_db(v))
	AudioServer.set_bus_mute(bus, v <= 0.0)


func sauver() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "musique", volume_musique)
	cfg.set_value("audio", "bruitages", volume_bruitages)
	cfg.save(FICHIER)
