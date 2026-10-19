extends Node
## Progression du joueur. Le bouton Continuer n'est actif que s'il existe une partie.

const FICHIER := "user://sauvegarde.cfg"


func existe() -> bool:
	return FileAccess.file_exists(FICHIER)
