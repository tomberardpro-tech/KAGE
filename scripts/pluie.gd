extends Node3D
## Pluie autour du ninja : gouttes qui tombent, éclaboussures au sol et bruit de pluie en boucle.
## Ajoutée par niveau.gd ; elle suit le ninja pour ne calculer que ce que la caméra voit.

const ZONE := Vector3(15.0, 0.0, 15.0)  ## demi-taille de la zone couverte (m)
const HAUTEUR := 11.0  ## hauteur d'où tombent les gouttes au-dessus du ninja
const VITESSE := 16.0  ## m/s

var cible: Node3D
var _gouttes: Node3D
var _eclats: Node3D


func _ready() -> void:
	# décrites en CPUParticles3D (plus lisible), puis calculées par la carte graphique
	_gouttes = _sur_gpu(_creer_gouttes())
	_eclats = _sur_gpu(_creer_eclats())
	var bruit := AudioStreamPlayer.new()
	var flux: AudioStreamOggVorbis = load("res://assets/audio/sfx/pluie.ogg").duplicate()
	flux.loop = true
	bruit.stream = flux
	bruit.volume_db = -24.0
	add_child(bruit)
	bruit.play()


func _process(_delta: float) -> void:
	if cible:
		var sol := global_position.y
		if not (cible is CharacterBody3D) or cible.is_on_floor():
			sol = cible.global_position.y  # en saut, les éclaboussures restent au sol
		global_position = Vector3(cible.global_position.x, sol, cible.global_position.z)


## Remplace des particules CPU par leur équivalent GPU : le processeur n'a plus rien à calculer.
func _sur_gpu(cpu: CPUParticles3D) -> Node3D:
	var gpu := GPUParticles3D.new()
	gpu.convert_from_particles(cpu)
	gpu.position = cpu.position
	gpu.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gpu.visibility_aabb = AABB(Vector3(-ZONE.x - 2, -HAUTEUR - 2, -ZONE.z - 2), Vector3(ZONE.x * 2 + 4, HAUTEUR + 4, ZONE.z * 2 + 4))
	remove_child(cpu)
	cpu.free()
	add_child(gpu)
	return gpu


func _creer_gouttes() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 1400
	p.lifetime = (HAUTEUR + 1.0) / VITESSE
	p.preprocess = p.lifetime
	p.local_coords = false
	p.position.y = HAUTEUR
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(ZONE.x, 0.5, ZONE.z)
	p.direction = Vector3(0.12, -1, 0.05)
	p.spread = 2.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = VITESSE * 0.9
	p.initial_velocity_max = VITESSE * 1.1
	var goutte := QuadMesh.new()
	goutte.size = Vector2(0.018, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.albedo_color = Color(0.72, 0.82, 1.0, 0.32)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	goutte.material = m
	p.mesh = goutte
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Petits anneaux d'eau qui s'ouvrent au sol là où les gouttes tombent.
func _creer_eclats() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 260
	p.lifetime = 0.35
	p.local_coords = false
	p.position.y = 0.04
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(ZONE.x * 0.7, 0.0, ZONE.z * 0.7)
	p.gravity = Vector3.ZERO
	p.initial_velocity_max = 0.0
	p.particle_flag_align_y = false
	var anneau := QuadMesh.new()
	anneau.size = Vector2(0.22, 0.22)
	anneau.orientation = PlaneMesh.FACE_Y
	var m := ShaderMaterial.new()
	var s := Shader.new()
	s.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
varying float vie;
void vertex() { vie = INSTANCE_CUSTOM.y; }
void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float rayon = 0.25 + vie * 0.75;
	float bord = smoothstep(0.12, 0.0, abs(r - rayon));
	ALBEDO = vec3(0.7, 0.8, 1.0);
	ALPHA = bord * (1.0 - vie) * 0.5;
}
"""
	m.shader = s
	anneau.material = m
	p.mesh = anneau
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p
