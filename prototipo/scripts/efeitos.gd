class_name Efeitos
extends RefCounted
## Efeitos visuais simples feitos com malhas primitivas (sem assets externos).


static func material(cor: Color, emissao := 0.0, alfa := 1.0, sem_luz := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	if alfa < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissao > 0.0:
		mat.emission_enabled = true
		mat.emission = cor
		mat.emission_energy_multiplier = emissao
	if sem_luz:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


## Esfera que cresce e desaparece (impactos, explosões, revelações).
static func explosao(pai: Node, pos: Vector3, cor: Color, raio: float, duracao := 0.35) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 20
	esfera.rings = 10
	var mat := material(cor, 1.5, 0.3, true)
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * raio * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * raio, duracao).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao)
	tw.chain().tween_callback(mi.queue_free)


## Círculo no chão avisando onde um golpe de área/salto vai cair.
static func telegrafo(pai: Node, pos: Vector3, raio: float, cor: Color, duracao: float) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var raiz := Node3D.new()
	pai.add_child(raiz)
	raiz.global_position = Vector3(pos.x, 0.05, pos.z)

	var disco := CylinderMesh.new()
	disco.top_radius = 1.0
	disco.bottom_radius = 1.0
	disco.height = 0.02
	disco.radial_segments = 40
	var mat_disco := material(cor, 1.0, 0.3, true)
	var mi_disco := MeshInstance3D.new()
	mi_disco.mesh = disco
	mi_disco.material_override = mat_disco
	mi_disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi_disco.scale = Vector3(raio * 0.1, 1.0, raio * 0.1)
	raiz.add_child(mi_disco)

	var anel := TorusMesh.new()
	anel.inner_radius = 0.94
	anel.outer_radius = 1.0
	anel.rings = 48
	var mi_anel := MeshInstance3D.new()
	mi_anel.mesh = anel
	mi_anel.material_override = material(cor, 2.0, 0.9, true)
	mi_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi_anel.scale = Vector3(raio, 1.0, raio)
	raiz.add_child(mi_anel)

	var tw := raiz.create_tween()
	tw.tween_property(mi_disco, "scale", Vector3(raio, 1.0, raio), duracao)
	tw.tween_callback(raiz.queue_free)
