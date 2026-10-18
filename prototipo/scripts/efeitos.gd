class_name Efeitos
extends RefCounted
## Materiais (cel shading de anime) e efeitos visuais feitos com malhas primitivas:
## impacto com faíscas e estilhaços, explosão com anéis duplos, telégrafo no chão,
## rastro de investida, imagem residual e tremor de câmera. Tudo "desenho animado":
## cores vivas, formas chapadas sem luz e animações com pulo (Tween BACK/ELASTIC).

const SHADER_TOON := preload("res://shaders/toon.gdshader")
const SHADER_CONTORNO := preload("res://shaders/contorno.gdshader")

static var _contornos: Dictionary = {}
static var _malhas: Dictionary = {}


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


## Malhas básicas compartilhadas entre os efeitos (evita criar uma malha por faísca).
static func _malha(nome: String) -> Mesh:
	if _malhas.has(nome):
		return _malhas[nome]
	var m: Mesh
	match nome:
		"esfera":
			var e := SphereMesh.new()
			e.radius = 1.0
			e.height = 2.0
			e.radial_segments = 16
			e.rings = 8
			m = e
		"anel":
			var a := TorusMesh.new()
			a.inner_radius = 0.86
			a.outer_radius = 1.0
			a.rings = 40
			a.ring_segments = 6
			m = a
		"anel_fino":
			var a := TorusMesh.new()
			a.inner_radius = 0.93
			a.outer_radius = 1.0
			a.rings = 48
			a.ring_segments = 5
			m = a
		"estilhaco":
			var p := PrismMesh.new()
			p.size = Vector3(1.0, 1.0, 1.0)
			m = p
		"caixa":
			m = BoxMesh.new()
		"espinho":
			# Pirâmide fina: os "raios" da estrela de impacto dos quadrinhos.
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 1.0
			c.height = 1.0
			c.radial_segments = 4
			c.rings = 1
			m = c
	_malhas[nome] = m
	return m


static func _instancia(pai: Node, malha: String, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _malha(malha)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	mi.global_position = pos
	return mi


# ---------------------------------------------------------------------
# Impacto e tremor
# ---------------------------------------------------------------------

## Impacto de golpe: flash branco, estrela de raios "POW", anel de choque, faíscas e
## estilhaços que voam com gravidade. forca ~ dano/10 (0.3 fraco, 1 normal, 2+ crítico).
static func impacto(pai: Node, pos: Vector3, cor: Color, forca := 1.0) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	forca = clampf(forca, 0.25, 3.0)
	var escala := 0.6 + 0.4 * forca
	var clara := cor.lightened(0.45)

	# Flash: esfera branca que estoura e some em um piscar.
	var mat_flash := material(Color(1, 1, 1), 2.0, 0.85, true)
	var flash := _instancia(pai, "esfera", mat_flash, pos)
	flash.scale = Vector3.ONE * 0.1
	var tw := flash.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 0.55 * escala, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat_flash, "albedo_color:a", 0.0, 0.16).set_delay(0.04)
	tw.chain().tween_callback(flash.queue_free)

	# Estrela de raios estilo quadrinhos: espinhos radiais que crescem e encolhem.
	var raios := 6 + int(forca * 3.0)
	var mat_raio := material(clara, 2.0, 1.0, true)
	for i in raios:
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var raio := _instancia(pai, "espinho", mat_raio, pos)
		raio.look_at_from_position(pos, pos + dir, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
		raio.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
		var comprimento := randf_range(0.8, 1.6) * escala
		raio.scale = Vector3(0.05, 0.05, 0.05)
		var tr := raio.create_tween()
		tr.tween_property(raio, "scale", Vector3(0.16 * escala, comprimento, 0.16 * escala), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tr.tween_property(raio, "scale", Vector3(0.02, comprimento * 1.2, 0.02), 0.14).set_ease(Tween.EASE_IN)
		tr.tween_callback(raio.queue_free)

	# Anel de choque horizontal + anel vertical virado para a direção aleatória.
	_anel_choque(pai, pos, cor, 1.6 * escala, 0.3)
	var vertical := _instancia(pai, "anel_fino", material(clara, 2.5, 0.9, true), pos)
	vertical.rotation = Vector3(PI / 2.0, randf() * TAU, 0.0)
	vertical.scale = Vector3.ONE * 0.2
	var tv := vertical.create_tween()
	tv.set_parallel(true)
	tv.tween_property(vertical, "scale", Vector3.ONE * 1.3 * escala, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tv.tween_property(vertical.material_override, "albedo_color:a", 0.0, 0.28)
	tv.chain().tween_callback(vertical.queue_free)

	# Faíscas: esferinhas brilhantes rápidas que somem encolhendo.
	var mat_faisca := material(Color(1.0, 0.95, 0.6), 2.5, 1.0, true)
	for i in 5 + int(forca * 4.0):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.1, 1.0), randf_range(-1, 1)).normalized()
		_particula(pai, "esfera", mat_faisca, pos, dir * randf_range(5.0, 9.0) * escala, 0.07 * escala, randf_range(0.25, 0.45), 14.0)

	# Estilhaços: prismas coloridos que giram, caem e somem (forte = mais pedaços).
	var mat_estilhaco := material(cor, 1.0, 1.0, true)
	var mat_estilhaco_claro := material(clara, 1.4, 1.0, true)
	for i in 4 + int(forca * 5.0):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.4, 1.2), randf_range(-1, 1)).normalized()
		_particula(pai, "estilhaco", mat_estilhaco if i % 2 == 0 else mat_estilhaco_claro, pos,
			dir * randf_range(3.5, 7.0) * escala, randf_range(0.12, 0.26) * escala, randf_range(0.45, 0.75), 22.0, true)


## Partícula simples animada por Tween: voa com gravidade, gira e encolhe até sumir.
static func _particula(pai: Node, malha: String, mat: Material, pos: Vector3, velocidade: Vector3, tamanho: float,
		duracao: float, gravidade: float, girar := false) -> void:
	var p := _instancia(pai, malha, mat, pos)
	p.scale = Vector3.ONE * tamanho
	var rot := Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	p.rotation = rot
	var giro := Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)) if girar else Vector3.ZERO
	var mover := func(t: float):
		p.global_position = pos + velocidade * t + Vector3(0, -0.5 * gravidade * t * t, 0)
		p.rotation = rot + giro * t
	var tw := p.create_tween()
	tw.set_parallel(true)
	tw.tween_method(mover, 0.0, duracao, duracao)
	tw.tween_property(p, "scale", Vector3.ONE * 0.001, duracao * 0.5).set_delay(duracao * 0.5).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(p.queue_free)


## Tremor de câmera: pede à câmera do grupo "camera_orbita" para tremer (forca 0..1).
static func tremer_camera(arvore: SceneTree, forca := 0.5) -> void:
	if arvore == null:
		return
	for cam in arvore.get_nodes_in_group("camera_orbita"):
		if cam.has_method("tremer"):
			cam.tremer(forca)


## Rastro de investida: imagens residuais coloridas deixadas pelo monstro por `duracao` s.
static func rastro(no: Node3D, cor: Color, duracao := 0.45, altura := 1.8) -> void:
	if no == null or not no.is_inside_tree():
		return
	var pai := no.get_parent()
	var passos := maxi(1, int(duracao / 0.05))
	var deixar := func():
		if not is_instance_valid(no) or not no.is_inside_tree():
			return
		var capsula := CapsuleMesh.new()
		capsula.radius = 0.4
		capsula.height = altura
		var mat := material(cor.lightened(0.2), 1.6, 0.4, true)
		var mi := MeshInstance3D.new()
		mi.mesh = capsula
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pai.add_child(mi)
		mi.global_position = no.global_position + Vector3(0, altura / 2.0, 0)
		mi.rotation.y = no.rotation.y
		var tf := mi.create_tween()
		tf.set_parallel(true)
		tf.tween_property(mat, "albedo_color:a", 0.0, 0.3)
		tf.tween_property(mi, "scale", Vector3(0.6, 0.9, 0.6), 0.3)
		tf.chain().tween_callback(mi.queue_free)
	var tw := no.create_tween()
	for i in passos:
		tw.tween_callback(deixar).set_delay(0.05)


# ---------------------------------------------------------------------
# Explosão, telégrafo e fantasma
# ---------------------------------------------------------------------

## Explosão: esfera que cresce e some, miolo claro, anéis duplos de choque e faíscas.
static func explosao(pai: Node, pos: Vector3, cor: Color, raio: float, duracao := 0.35) -> void:
	if pai == null or not pai.is_inside_tree():
		return
	var mat := material(cor, 1.5, 0.35, true)
	var mi := _instancia(pai, "esfera", mat, pos)
	mi.scale = Vector3.ONE * raio * 0.2
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * raio, duracao).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao)
	tw.chain().tween_callback(mi.queue_free)

	# Miolo claro (quase branco) que estoura mais rápido.
	var mat_miolo := material(cor.lightened(0.7), 2.5, 0.9, true)
	var miolo := _instancia(pai, "esfera", mat_miolo, pos)
	miolo.scale = Vector3.ONE * raio * 0.1
	var tm := miolo.create_tween()
	tm.set_parallel(true)
	tm.tween_property(miolo, "scale", Vector3.ONE * raio * 0.55, duracao * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tm.tween_property(mat_miolo, "albedo_color:a", 0.0, duracao * 0.6)
	tm.chain().tween_callback(miolo.queue_free)

	_anel_choque(pai, pos, cor, raio * 1.3, duracao * 1.2)
	_anel_choque(pai, pos, cor.lightened(0.5), raio * 1.8, duracao * 1.5, 0.12)
	var mat_faisca := material(cor.lightened(0.5), 2.5, 1.0, true)
	for i in int(clampf(raio * 4.0, 4.0, 14.0)):
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.0), randf_range(-1, 1)).normalized()
		_particula(pai, "esfera", mat_faisca, pos, dir * randf_range(3.0, 6.0) * raio, 0.08 * raio, randf_range(0.3, 0.5), 10.0)


static func _anel_choque(pai: Node, pos: Vector3, cor: Color, raio: float, duracao: float, atraso := 0.0) -> void:
	var mat := material(cor.lightened(0.35), 2.5, 0.9, true)
	var mi := _instancia(pai, "anel", mat, pos)
	mi.scale = Vector3(raio * 0.15, 1.0, raio * 0.15)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(raio, 1.0, raio), duracao).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(atraso)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao).set_delay(atraso)
	tw.chain().tween_callback(mi.queue_free)


## Círculo no chão avisando onde um golpe de área/salto vai cair: disco que enche,
## anel externo fixo e anel interno pulsante girando (mais "perigo" para quem está dentro).
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
	var mat_disco := material(cor, 1.0, 0.35, true)
	var mi_disco := MeshInstance3D.new()
	mi_disco.mesh = disco
	mi_disco.material_override = mat_disco
	mi_disco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi_disco.scale = Vector3(raio * 0.1, 1.0, raio * 0.1)
	raiz.add_child(mi_disco)

	var mi_anel := MeshInstance3D.new()
	mi_anel.mesh = _malha("anel_fino")
	mi_anel.material_override = material(cor, 2.0, 0.95, true)
	mi_anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi_anel.scale = Vector3(raio, 1.0, raio)
	raiz.add_child(mi_anel)

	# Anel interno tracejado (4 arcos) que gira e pulsa.
	var giro := Node3D.new()
	raiz.add_child(giro)
	for i in 4:
		var arco := MeshInstance3D.new()
		arco.mesh = _malha("caixa")
		arco.material_override = material(cor.lightened(0.5), 2.0, 0.9, true)
		arco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := i * PI / 2.0
		arco.position = Vector3(cos(ang), 0.02, sin(ang)) * raio * 0.7
		arco.rotation.y = -ang
		arco.scale = Vector3(0.1, 0.03, raio * 0.35)
		giro.add_child(arco)

	var tw := raiz.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi_disco, "scale", Vector3(raio, 1.0, raio), duracao)
	tw.tween_property(giro, "rotation:y", TAU * 0.75, duracao)
	tw.tween_property(giro, "scale", Vector3.ONE * 0.55, duracao).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(raiz.queue_free)


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
