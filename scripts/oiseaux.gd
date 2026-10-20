extends Node3D
## De temps en temps, une petite volée de corbeaux traverse le ciel au-dessus du ninja,
## en battant des ailes, et croasse au loin. Ajoutée par niveau.gd ; purement décorative.

var cible: Node3D
var _attente := 12.0
var _plumes: StandardMaterial3D


func _ready() -> void:
	_plumes = StandardMaterial3D.new()
	_plumes.albedo_color = Color("#141418")
	_plumes.cull_mode = BaseMaterial3D.CULL_DISABLED
	_plumes.roughness = 0.9


func _process(delta: float) -> void:
	_attente -= delta
	if _attente <= 0.0 and cible:
		_attente = randf_range(25.0, 45.0)
		_envol()


func _envol() -> void:
	var angle := randf() * TAU
	var cap := Vector3(cos(angle), 0, sin(angle))
	var cote := cap.cross(Vector3.UP)
	var centre := cible.global_position + Vector3(randf_range(-4, 4), randf_range(6.5, 8.0), randf_range(-6, 2))
	var depart := centre - cap * 28.0
	var arrivee := centre + cap * 28.0
	var nombre := randi_range(4, 7)
	Sons.jouer("corbeau", -10.0, randf_range(0.9, 1.1))
	for i in nombre:
		var rang := (i + 1) / 2
		var decalage := -cap * rang * 1.4 + cote * rang * (1.0 if i % 2 else -1.0) * 1.2
		var oiseau := _oiseau()
		add_child(oiseau)
		oiseau.global_position = depart + decalage
		oiseau.look_at(oiseau.global_position + cap, Vector3.UP)
		var duree := randf_range(7.0, 9.0)
		var t := oiseau.create_tween()
		t.tween_property(oiseau, "global_position", arrivee + decalage + Vector3(0, randf_range(-0.5, 1.5), 0), duree)
		t.tween_callback(oiseau.queue_free)


## Un corps et deux ailes qui battent (les ailes sont des plans qui pivotent à l'épaule).
func _oiseau() -> Node3D:
	var o := Node3D.new()
	var corps := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.12, 0.1, 0.42)
	corps.mesh = b
	corps.material_override = _plumes
	corps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	o.add_child(corps)
	var vitesse := randf_range(7.0, 9.0)
	for s in [-1.0, 1.0]:
		var epaule := Node3D.new()
		o.add_child(epaule)
		var aile := MeshInstance3D.new()
		var p := QuadMesh.new()
		p.size = Vector2(0.5, 0.22)
		aile.mesh = p
		aile.rotation.x = -PI / 2.0
		aile.position.x = s * 0.27
		aile.material_override = _plumes
		aile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		epaule.add_child(aile)
		var bat := epaule.create_tween().set_loops()
		bat.tween_property(epaule, "rotation:z", s * 0.7, 0.5 / vitesse * 4.0).set_trans(Tween.TRANS_SINE)
		bat.tween_property(epaule, "rotation:z", -s * 0.5, 0.5 / vitesse * 4.0).set_trans(Tween.TRANS_SINE)
	return o
