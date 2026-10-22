class_name Coffre
extends Node3D
## Coffre au trésor qui apparaît au centre du donjon quand le seigneur Oni est vaincu.
## E pour l'ouvrir : le niveau joue alors la cinématique du parchemin, et la Grande Lame en sort.

signal ouvert

var _couvercle: Node3D
var _lumiere: OmniLight3D
var _rayon: MeshInstance3D
var _etincelles: GPUParticles3D
var _disponible := false


func _ready() -> void:
	_construire()
	visible = false


func texte_action() -> String:
	return "Ouvrir le coffre"


func peut_interagir() -> bool:
	return _disponible


func interagir() -> void:
	if not _disponible:
		return
	_disponible = false
	remove_from_group("interactifs")
	ouvert.emit()


## Le coffre tombe du ciel dans une colonne de lumière dorée.
func apparaitre() -> void:
	visible = true
	scale = Vector3.ONE * 0.01
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE, 0.6)
	t.parallel().tween_property(_lumiere, "light_energy", 2.5, 0.6)
	_rayon.visible = true
	_etincelles.emitting = true
	Sons.jouer("coffre_apparait")
	await t.finished
	_disponible = true
	add_to_group("interactifs")


## Ouverture lente du couvercle, avec la lumière qui jaillit de l'intérieur.
func ouvrir_couvercle(duree := 1.2) -> void:
	Sons.jouer("coffre")
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.3)
	t.tween_property(_couvercle, "rotation:x", deg_to_rad(-105.0), duree)
	t.parallel().tween_property(_lumiere, "light_energy", 6.0, duree)
	await t.finished


## La Grande Lame monte lentement du coffre ouvert, pointe la première, dans un éclat blanc.
## Renvoie l'épée (elle reste dans le coffre jusqu'à ce que le ninja la prenne).
func sortir_grande_lame(duree := 3.4) -> GrandeLame:
	var lame := GrandeLame.new()
	lame.name = "GrandeLame"
	add_child(lame)
	var bord := 0.55  # hauteur du coffre
	lame.position = Vector3(0, bord - GrandeLame.LONGUEUR - 0.05, 0)  # la pointe juste sous le bord
	lame.rotation.y = deg_to_rad(46.0)  # le plat de la lame tourné vers les caméras de la cinématique
	lame.briller(0.0)
	Sons.jouer("coffre_apparait", -4.0, 0.62)
	Sons.jouer("degainer", -2.0, 0.55)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(lame, "position:y", bord + 0.75, duree)
	# la lumière du coffre pâlit : c'est la lueur blanche de l'épée qui domine
	t.parallel().tween_property(_lumiere, "light_energy", 3.0, duree * 0.5)
	t.parallel().tween_property(_lumiere, "light_color", Color(0.86, 0.9, 1.0), duree * 0.5)
	var eclat := create_tween()
	eclat.tween_method(lame.briller, 0.0, 1.0, duree * 0.6)
	eclat.tween_method(lame.briller, 1.0, 0.35, duree * 0.4)
	return lame


func eteindre_rayon() -> void:
	var t := create_tween()
	t.tween_property(_rayon, "transparency", 1.0, 0.8)
	t.parallel().tween_property(_lumiere, "light_energy", 1.2, 0.8)
	_etincelles.emitting = false


func _boite(parent: Node3D, taille: Vector3, centre: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.position = centre
	mi.material_override = m
	parent.add_child(mi)


func _construire() -> void:
	var laque := StandardMaterial3D.new()
	laque.albedo_color = Color("#7a1a14")
	laque.roughness = 0.35
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Color("#d9a94e")
	or_.metallic = 0.8
	or_.roughness = 0.3
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color("#141418")
	var w := 1.1
	var d := 0.7
	var h := 0.55
	_boite(self, Vector3(w, h, d), Vector3(0, h / 2.0, 0), laque)
	for x in [-w / 2.0 + 0.06, w / 2.0 - 0.06]:
		_boite(self, Vector3(0.1, h + 0.02, d + 0.02), Vector3(x, h / 2.0, 0), or_)
	_boite(self, Vector3(w + 0.04, 0.06, d + 0.04), Vector3(0, 0.03, 0), noir)
	# couvercle bombé, articulé à l'arrière
	_couvercle = Node3D.new()
	_couvercle.position = Vector3(0, h, -d / 2.0)
	add_child(_couvercle)
	_boite(_couvercle, Vector3(w + 0.04, 0.2, d + 0.04), Vector3(0, 0.1, d / 2.0), laque)
	_boite(_couvercle, Vector3(w * 0.7, 0.08, d * 0.8), Vector3(0, 0.24, d / 2.0), laque)
	for x in [-w / 2.0 + 0.06, w / 2.0 - 0.06]:
		_boite(_couvercle, Vector3(0.1, 0.22, d + 0.06), Vector3(x, 0.1, d / 2.0), or_)
	# serrure dorée (mon du clan)
	_boite(self, Vector3(0.18, 0.2, 0.04), Vector3(0, h - 0.08, d / 2.0 + 0.02), or_)
	_lumiere = OmniLight3D.new()
	_lumiere.light_color = Color(1.0, 0.82, 0.45)
	_lumiere.omni_range = 6.0
	_lumiere.light_energy = 0.0
	_lumiere.position = Vector3(0, 0.9, 0)
	add_child(_lumiere)
	# colonne de lumière qui monte du coffre
	_rayon = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 0.5
	cyl.height = 9.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	_rayon.mesh = cyl
	_rayon.position.y = 4.5
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	float haut = 1.0 - UV.y;
	float bandes = 0.75 + 0.25 * sin(UV.x * 40.0 + TIME * 2.0);
	ALBEDO = vec3(1.0, 0.78, 0.38) * pow(1.0 - haut, 1.5) * bandes * 0.55;
}
"""
	_rayon.material_override = m
	_rayon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rayon.visible = false
	add_child(_rayon)
	_etincelles = GPUParticles3D.new()
	var cpu := CPUParticles3D.new()
	cpu.amount = 40
	cpu.lifetime = 1.8
	cpu.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cpu.emission_sphere_radius = 0.7
	cpu.direction = Vector3.UP
	cpu.spread = 20.0
	cpu.gravity = Vector3(0, 0.6, 0)
	cpu.initial_velocity_min = 0.4
	cpu.initial_velocity_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var mq := StandardMaterial3D.new()
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mq.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mq.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mq.albedo_color = Color(1.0, 0.85, 0.5)
	mq.set("disable_fog", true)
	q.material = mq
	cpu.mesh = q
	_etincelles.convert_from_particles(cpu)
	cpu.free()
	_etincelles.position.y = 0.6
	_etincelles.emitting = false
	add_child(_etincelles)
