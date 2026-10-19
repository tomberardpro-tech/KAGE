extends Node
## Réglages du joueur (volume, plein écran), gardés entre deux parties.

const FICHIER := "user://reglages.cfg"

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))
		AudioServer.set_bus_mute(0, volume <= 0.0)

var plein_ecran := false:
	set(v):
		plein_ecran = v
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) == OK:
		volume = cfg.get_value("audio", "volume", volume)
	else:
		volume = volume


func sauver() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "volume", volume)
	cfg.save(FICHIER)
