extends Node3D
## Scène de jeu provisoire. Échap ramène au menu en attendant l'écran de pause.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Transition.vers("res://scenes/ui/menu.tscn")
