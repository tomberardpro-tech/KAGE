extends Node3D
## Boule de feu soufflée par le seigneur Oni : elle file tout droit, brûle le ninja
## (une vie en moins) et s'éteint contre le sol, un mur ou après quelques secondes.

@export var vitesse := 8.5
@export var duree := 3.5

var direction := Vector3.FORWARD
var lanceur: Node  ## le boss, qui gère la mort du ninja

var _age := 0.0
var _boule: MeshInstance3D
var _lueur: OmniLight3D

static var _matiere: ShaderMaterial


## Matière partagée par toutes les boules (le boss en garde une cachée pour la préchauffer).
static func matiere() -> ShaderMaterial:
	if _matiere == null:
		_matiere = ShaderMaterial.new()
		_matiere.shader = Shader.new()
		_matiere.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;
void fragment() {
	float bord = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float flamme = 0.75 + 0.25 * sin(TIME * 25.0 + UV.y * 30.0);
	ALBEDO = mix(vec3(1.0, 0.18, 0.02), vec3(1.0, 0.85, 0.4), bord * bord) * bord * flamme * 2.0;
}
"""
	return _matiere


static func maillage() -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.32
	s.height = 0.64
	s.radial_segments = 12
	s.rings = 6
	return s


func _ready() -> void:
	add_to_group("flamme_boss")
	_boule = MeshInstance3D.new()
	_boule.mesh = maillage()
	_boule.material_override = matiere()
	_boule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_boule)
	# petite lueur, sans ombre : il y en a trois à la fois
	_lueur = OmniLight3D.new()
	_lueur.light_color = Color(1.0, 0.45, 0.1)
	_lueur.light_energy = 0.7
	_lueur.omni_range = 2.5
	_lueur.shadow_enabled = false
	add_child(_lueur)


func _physics_process(delta: float) -> void:
	_age += delta
	_boule.scale = Vector3.ONE * (1.0 + 0.12 * sin(_age * 30.0))
	var depart := global_position
	var arrivee := depart + direction * vitesse * delta
	# sol ou mur : elle s'éteint
	var rayon := PhysicsRayQueryParameters3D.create(depart, arrivee, 1)
	if not get_world_3d().direct_space_state.intersect_ray(rayon).is_empty() or _age > duree:
		_eteindre()
		return
	global_position = arrivee
	var ninja := get_tree().get_first_node_in_group("ninja") as Node3D
	if ninja and (ninja.global_position + Vector3.UP * 0.6).distance_to(arrivee) < 0.7:
		if ninja.blesser(arrivee - direction):
			Sons.jouer("frappe", -8.0, 1.3)
			if lanceur and lanceur.has_method("_toucher_ninja"):
				lanceur._toucher_ninja(ninja)
		_eteindre()


## Petit éclat, puis elle disparaît.
func _eteindre() -> void:
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(_boule, "scale", Vector3.ONE * 1.8, 0.15)
	t.tween_property(_lueur, "light_energy", 0.0, 0.15)
	t.chain().tween_callback(queue_free)
