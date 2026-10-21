class_name Autel
extends Area3D
## Petit autel : en passant devant, il devient le point de reprise. Un cercle lumineux au sol
## et un cristal qui flotte montrent que c'est un point de sauvegarde ; ils deviennent dorés une fois activé.

signal active(autel: Autel)

var deja_active := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_sur_entree)


func _sur_entree(corps: Node3D) -> void:
	if corps is Ninja:
		active.emit(self)
		if not deja_active:
			deja_active = true
			var flamme := get_node_or_null("Flamme") as Node3D
			if flamme:
				flamme.visible = true
			_allumer()


func _process(delta: float) -> void:
	var cristal := get_node_or_null("Cristal") as Node3D
	if cristal:
		cristal.rotation.y += delta * 1.2
		cristal.position.y = 1.75 + sin(Time.get_ticks_msec() / 600.0) * 0.08


func _allumer() -> void:
	var cercle := get_node_or_null("Cercle") as MeshInstance3D
	if cercle and cercle.material_override is ShaderMaterial:
		var t := create_tween()
		t.tween_method(func(v: float): (cercle.material_override as ShaderMaterial).set_shader_parameter("actif", v), 0.0, 1.0, 0.6)
	var cristal := get_node_or_null("Cristal") as MeshInstance3D
	if cristal and cristal.material_override is StandardMaterial3D:
		var m := cristal.material_override as StandardMaterial3D
		m.albedo_color = Color("#ffd27a")
		m.emission = Color("#ffb347")
