extends CanvasLayer
## Fondu au noir entre deux écrans. Accessible partout via Transition.

var _voile: ColorRect


func _ready() -> void:
	layer = 100
	_voile = ColorRect.new()
	_voile.color = Palette.NOIR
	_voile.modulate.a = 0.0
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_voile)


func vers(scene: String, duree := 0.5) -> void:
	_voile.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_voile, "modulate:a", 1.0, duree)
	await tween.finished
	get_tree().change_scene_to_file(scene)
	tween = create_tween()
	tween.tween_property(_voile, "modulate:a", 0.0, duree)
	await tween.finished
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
