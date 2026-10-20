extends Node
## Réglages du joueur (volumes, plein écran), gardés entre deux parties.
## Trois volumes : général, musique et bruitages (bus audio de default_bus_layout.tres).

const FICHIER := "user://reglages.cfg"

var volume := 0.8:
	set(v):
		volume = clampf(v, 0.0, 1.0)
		AudioServer.set_bus_volume_db(0, linear_to_db(volume))
		AudioServer.set_bus_mute(0, volume <= 0.0)

## La musique et les bruitages démarrent assez bas : l'ambiance reste agréable.
var volume_musique := 0.45:
	set(v):
		volume_musique = clampf(v, 0.0, 1.0)
		_regler_bus("Musique", volume_musique)

var volume_bruitages := 0.6:
	set(v):
		volume_bruitages = clampf(v, 0.0, 1.0)
		_regler_bus("Bruitages", volume_bruitages)

## Qualité de l'image : 0 rapide, 1 normale, 2 haute. En « rapide », l'image est calculée un peu
## plus petite puis agrandie, sans lissage des bords, sans ombres de la lune ni halo lumineux.
const QUALITES := ["Rapide", "Normale", "Haute"]
var qualite := 1:
	set(v):
		qualite = clampi(v, 0, 2)
		appliquer_qualite()

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
		qualite = cfg.get_value("video", "qualite", qualite)
	else:
		qualite = qualite
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
	cfg.set_value("video", "qualite", qualite)
	cfg.save(FICHIER)


## Applique la qualité à l'écran et, si un niveau est chargé, à sa lune et à son ambiance.
## Le niveau l'appelle aussi à son ouverture.
func appliquer_qualite(scene: Node = null) -> void:
	var vue := get_tree().root
	vue.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][qualite]
	vue.scaling_3d_scale = 0.75 if qualite == 0 else 1.0
	if scene == null:
		scene = get_tree().current_scene
	if scene == null:
		return
	var lune := scene.get_node_or_null("Lune") as DirectionalLight3D
	if lune:
		lune.shadow_enabled = qualite > 0
	# en « rapide », l'herbe, les fleurs et les feuilles ne sont dessinées que tout près
	for detail: GeometryInstance3D in scene.find_children("*", "MultiMeshInstance3D", true, false):
		if detail.visibility_range_end > 0.0:
			if not detail.has_meta("portee"):
				detail.set_meta("portee", detail.visibility_range_end)
			detail.visibility_range_end = 28.0 if qualite == 0 else detail.get_meta("portee")
	var ambiance := scene.get_node_or_null("Ambiance") as WorldEnvironment
	if ambiance and ambiance.environment:
		ambiance.environment.glow_enabled = qualite > 0
