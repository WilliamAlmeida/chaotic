class_name Efeitos
extends RefCounted
## Materiais (cel shading de anime) e efeitos visuais feitos com malhas primitivas.

const SHADER_TOON := preload("res://shaders/toon.gdshader")
const SHADER_CONTORNO := preload("res://shaders/contorno.gdshader")

static var _contornos: Dictionary = {}


## Material "desenho animado": luz em faixas + contorno escuro opcional.
static func material_toon(cor: Color, emissao := 0.0, contorno := true, espessura_px := 2.2, cor_vertice := false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_TOON
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("cor_sombra", _tom_sombra(cor))
	mat.set_shader_parameter("usar_cor_vertice", cor_vertice)
	if emissao > 0.0:
		mat.set_shader_parameter("emissao", cor)
		mat.set_shader_parameter("forca_emissao", emissao)
	if contorno:
		mat.next_pass = material_contorno(espessura_px)
	return mat


static func material_contorno(espessura_px := 2.2) -> ShaderMaterial:
	var chave := snappedf(espessura_px, 0.1)
	if not _contornos.has(chave):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_CONTORNO
		mat.set_shader_parameter("espessura_px", chave)
		_contornos[chave] = mat
	return _contornos[chave]


## Sombra "de anime": puxada para o roxo/azul em vez de simplesmente escurecer.
static func _tom_sombra(cor: Color) -> Color:
	var frio := Color(0.42, 0.4, 0.68)
	return Color(lerpf(0.55, frio.r, 0.5), lerpf(0.55, frio.g, 0.5), lerpf(0.6, frio.b, 0.5)).lerp(cor, 0.15)


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


## Impacto de golpe (faíscas, pancada): chamado pelo Lutador ao acertar. forca ~ dano/10.
static func impacto(pai: Node, pos: Vector3, cor: Color, forca := 1.0) -> void:
	explosao(pai, pos, cor, 0.5 + 0.35 * forca, 0.25)


## Tremor de câmera: pede à câmera do grupo "camera_orbita" para tremer (forca 0..1).
static func tremer_camera(arvore: SceneTree, forca := 0.5) -> void:
	if arvore == null:
		return
	for cam in arvore.get_nodes_in_group("camera_orbita"):
		if cam.has_method("tremer"):
			cam.tremer(forca)


## Impacto: esfera que cresce e some + anel de choque no plano do chão.
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
	_anel_choque(pai, pos, cor, raio * 1.3, duracao * 1.2)


static func _anel_choque(pai: Node, pos: Vector3, cor: Color, raio: float, duracao: float) -> void:
	var anel := TorusMesh.new()
	anel.inner_radius = 0.86
	anel.outer_radius = 1.0
	anel.rings = 40
	anel.ring_segments = 6
	var mat := material(cor.lightened(0.35), 2.5, 0.9, true)
	var mi := MeshInstance3D.new()
	mi.mesh = anel
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3(raio * 0.15, 1.0, raio * 0.15)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(raio, 1.0, raio), duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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


## Imagem residual translúcida (passiva Duplo Horizonte).
static func fantasma(pai: Node, pos: Vector3, cor: Color, altura: float, duracao := 0.8) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.45
	capsula.height = altura
	var mat := material(cor.lightened(0.3), 1.2, 0.45, true)
	var mi := MeshInstance3D.new()
	mi.mesh = capsula
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	mi.global_position = pos + Vector3(0, altura / 2.0, 0)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao)
	tw.tween_callback(mi.queue_free)
