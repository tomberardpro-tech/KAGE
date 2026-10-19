extends Node
## Outil de capture d'écran pour la doc et le rapport (inactif en jeu).
## Usage : godot --path . -- --capture=<scene.tscn> --sortie=<image.png> [--attente=20]
## Options : --propre (sans interface ni tutoriel), --ninja=x,z (place le ninja, la caméra suit),
## --recul=1.5 (caméra plus loin, pour une vue d'ensemble).
## Sert aussi à générer un niveau avec les scripts globaux chargés :
## godot --headless --path . -- --construire=res://scripts/tools/build_chateau.gd


func _ready() -> void:
	var opts := {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var kv := arg.trim_prefix("--").split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else ""
	if opts.has("construire"):
		load(opts["construire"]).new()
		return
	if not opts.has("capture"):
		queue_free()
		return
	get_window().size = Vector2i(1920, 1080)
	get_tree().change_scene_to_file.call_deferred(opts["capture"])
	for i in 3:
		await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene and opts.has("ninja"):
		var xz: PackedStringArray = opts["ninja"].split(",")
		var ninja: Node3D = scene.get_node_or_null("Ninja")
		if ninja:
			ninja.global_position = Vector3(float(xz[0]), ninja.global_position.y, float(xz[1]))
	if scene and opts.has("recul"):
		var camera := scene.get_node_or_null("Camera")
		if camera:
			camera.set("offset", camera.get("offset") * float(opts["recul"]))
	if scene and opts.has("propre"):
		get_tree().paused = false
		for calque in scene.find_children("*", "CanvasLayer", true, false):
			calque.visible = false
	for i in int(opts.get("attente", "20")):
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(opts.get("sortie", "user://capture.png"))
	get_tree().quit()
