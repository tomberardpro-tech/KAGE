extends SceneTree
## Ouvre une scène, attend quelques images puis enregistre une capture.
## Usage : godot --script res://scripts/tools/capture.gd -- <scene.tscn> <sortie.png>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	root.size = Vector2i(1920, 1080)
	root.add_child(load(args[0]).instantiate())
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(args[1])
	quit()
