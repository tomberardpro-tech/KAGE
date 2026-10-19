extends Node
## Outil de capture d'écran pour la doc et le rapport (inactif en jeu).
## Usage : godot --path . -- --capture=<scene.tscn> --sortie=<image.png> [--attente=20]


func _ready() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and "=" in arg:
			var kv := arg.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1]
	if not opts.has("capture"):
		queue_free()
		return
	get_window().size = Vector2i(1920, 1080)
	get_tree().change_scene_to_file.call_deferred(opts["capture"])
	for i in int(opts.get("attente", "20")):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(opts.get("sortie", "user://capture.png"))
	get_tree().quit()
