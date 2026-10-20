extends Node
## Progression du joueur : le dernier niveau débloqué.
## Le bouton Continuer n'est actif que s'il existe une partie.

const FICHIER := "user://sauvegarde.cfg"
const PREMIER_NIVEAU := "res://scenes/levels/chateau.scn"


func existe() -> bool:
	return FileAccess.file_exists(FICHIER)


## Niveau où reprendre avec Continuer.
func niveau() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(FICHIER) != OK:
		return PREMIER_NIVEAU
	var chemin: String = cfg.get_value("partie", "niveau", PREMIER_NIVEAU)
	return chemin if ResourceLoader.exists(chemin) else PREMIER_NIVEAU


## Appelé à la victoire : le niveau suivant devient le point de reprise.
func atteindre(chemin: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FICHIER)
	cfg.set_value("partie", "niveau", chemin)
	cfg.save(FICHIER)
