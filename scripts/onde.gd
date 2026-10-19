class_name Onde
extends MeshInstance3D
## Cercle qui s'élargit au sol pour montrer un bruit et jusqu'où on l'entend.


static func emettre(parent: Node, point: Vector3, rayon: float) -> void:
	var onde := Onde.new()
	var anneau := TorusMesh.new()
	anneau.inner_radius = 0.92
	anneau.outer_radius = 1.0
	anneau.rings = 48
	var materiau := StandardMaterial3D.new()
	materiau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	materiau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materiau.albedo_color = Color(Palette.OR, 0.8)
	anneau.material = materiau
	onde.mesh = anneau
	onde.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(onde)
	onde.global_position = point + Vector3.UP * 0.1
	onde.scale = Vector3(0.3, 0.05, 0.3)
	var tween := onde.create_tween().set_parallel()
	tween.tween_property(onde, "scale", Vector3(rayon, 0.05, rayon), 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(materiau, "albedo_color:a", 0.0, 0.9)
	tween.chain().tween_callback(onde.queue_free)
