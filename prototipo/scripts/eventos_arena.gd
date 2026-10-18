class_name EventosArena
extends Node3D
## "Situações" da arena, como nos episódios em que o cenário vira parte do duelo:
## a cada 20–35 s (30–45 s no modo fácil; nunca antes de 12 s de luta) um evento da lista
## do Local é sorteado, anunciado com aviso grande por 2 s (banner + telégrafo no chão + som)
## e então acontece. Tudo é justo: afeta os dois lutadores e dá tempo de reagir.
##
## Eventos em data/eventos.json: erupcao, mare_alta, tempestade_areia, raio, desmoronamento,
## rajada, falha_da_rede e eco_de_cura. `disparar("id")` força um evento (testes e tutorial).
##
## Também cuida dos "ambientes contínuos" do Local: `vento_constante` (empurrões periódicos),
## `nevoa_movel` (bancos de névoa que andam) e `corrompido` (obstáculos que somem e voltam).

const CAMINHO_DADOS := "res://data/eventos.json"
const PRIMEIRO_EVENTO := 12.0

static var _catalogo: Dictionary = {}

var batalha: Batalha
## Ids dos eventos possíveis neste Local.
var ids: Array[String] = []
## false na simulação headless: sem decoração pesada (só o que afeta a luta).
var visual := true
## Modo fácil: intervalo maior e metade do dano ao jogador.
var facil := false

var ativo := false
var _proximo_t := 0.0
var _em_curso := false
var _ultimo := ""
var _tempo := 0.0

# Estado dos efeitos em andamento.
var _cegueira_t := 0.0
var _mare_t := 0.0
var _inversao_t := 0.0
var _troca_t := 0.0
var _modificadores_originais: Array = []
var _jatos: Array = []
var _eco: Dictionary = {}
var _perigos_temporarios: Array = []
var _nos_temporarios: Array[Node] = []
var _fog_original := 0.004
var _cor_fog_original := Color.WHITE
var _cor_sol_original := Color.WHITE

# Ambiente contínuo.
var _vento_dir := Vector3.RIGHT
var _vento_t := 0.0
var _vento_giro := 0.0
var _corrompido_t := 6.0
var _sumidos: Array = []
var _nevoas: Array = []


static func catalogo() -> Dictionary:
	if _catalogo.is_empty():
		var texto := FileAccess.get_file_as_string(CAMINHO_DADOS)
		var lista = JSON.parse_string(texto)
		if typeof(lista) == TYPE_ARRAY:
			for item in lista:
				_catalogo[str(item["id"])] = item
		else:
			push_error("Falha ao ler %s" % CAMINHO_DADOS)
	return _catalogo


static func dados_evento(id: String) -> Dictionary:
	return catalogo().get(id, {})


func configurar(b: Batalha, lista: Array) -> void:
	batalha = b
	ids.clear()
	for id in lista:
		if catalogo().has(str(id)):
			ids.append(str(id))
		else:
			push_warning("Evento desconhecido no Local: %s" % id)
	visual = not b.simulacao
	facil = Jogo.facil() and not b.simulacao
	if b.ambiente and b.ambiente.environment:
		_fog_original = b.ambiente.environment.fog_density
		_cor_fog_original = b.ambiente.environment.fog_light_color
	if b.sol:
		_cor_sol_original = b.sol.light_color
	_vento_dir = Vector3(cos(randf() * TAU), 0.0, sin(randf() * TAU))


## Registra um banco de névoa que anda pela arena (nevoa_movel). `perigo` é a entrada de batalha.perigos.
func registrar_nevoa_movel(no: Node3D, perigo: Dictionary) -> void:
	_nevoas.append({"no": no, "perigo": perigo, "origem": perigo["centro"], "fase": randf() * TAU, "velocidade": randf_range(0.12, 0.2)})


# ---------------------------------------------------------------------
# Consultas usadas pela Batalha
# ---------------------------------------------------------------------

## Tempestade de areia: todo mundo fica escondido.
func cegueira_ativa() -> bool:
	return _cegueira_t > 0.0


func em_curso() -> bool:
	return _em_curso


func segundos_para_proximo() -> float:
	return _proximo_t


# ---------------------------------------------------------------------
# Laço
# ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if batalha == null or not is_instance_valid(batalha):
		return
	if not batalha.em_andamento:
		if ativo:
			encerrar()
		return
	if not ativo:
		ativo = true
		_proximo_t = maxf(PRIMEIRO_EVENTO, _intervalo() * 0.6)
	_tempo += delta
	_processar_ambiente(delta)
	_processar_efeitos(delta)
	if ids.is_empty() or _em_curso:
		return
	_proximo_t -= delta
	if _proximo_t <= 0.0:
		disparar(_sortear())


## Força um evento agora (usado por testes/roteiros e pelo tutorial).
func disparar(id: String) -> void:
	if _em_curso or batalha == null or not batalha.em_andamento:
		return
	var ev := dados_evento(id)
	if ev.is_empty():
		push_warning("Evento inexistente: %s" % id)
		return
	_executar(id, ev)


func _sortear() -> String:
	if ids.size() == 1:
		return ids[0]
	var opcoes := ids.filter(func(i): return i != _ultimo)
	return str(opcoes.pick_random())


func _intervalo() -> float:
	return randf_range(30.0, 45.0) if facil else randf_range(20.0, 35.0)


func _executar(id: String, ev: Dictionary) -> void:
	_em_curso = true
	_ultimo = id
	var aviso := float(ev.get("aviso", 2.0))
	var cor := Color(str(ev.get("cor", "#ffffff")))
	_anunciar(ev, cor)
	var preparo := _preparar(id, ev, cor, aviso)
	await _esperar(aviso)
	if not _ativo_valido():
		_em_curso = false
		return
	match id:
		"erupcao":
			_erupcao(ev, cor, preparo)
		"mare_alta":
			_mare_alta(ev, cor)
		"tempestade_areia":
			_tempestade_areia(ev, cor)
		"raio":
			_raio(ev, cor, preparo)
		"desmoronamento":
			_desmoronamento(ev, cor, preparo)
		"rajada":
			_rajada(ev, preparo)
		"falha_da_rede":
			_falha_da_rede(ev, cor)
		"eco_de_cura":
			_eco_de_cura(ev, cor, preparo)
	_em_curso = false
	_proximo_t = _intervalo()


func _anunciar(ev: Dictionary, cor: Color) -> void:
	var titulo := str(ev.get("nome", "")).to_upper() + "!"
	var dica := str(ev.get("dica", ""))
	var texto := "%s  %s" % [titulo, dica] if dica != "" else titulo
	var duracao := float(ev.get("aviso", 2.0)) + 0.6
	var hud := batalha.hud
	if hud and hud.has_method("aviso_evento"):
		# Faixa colorida da HUD (ela mesma toca o som de aviso).
		hud.call("aviso_evento", texto, cor, duracao)
	elif hud:
		hud.banner(texto, duracao)
		_som("aviso")
	else:
		_som("aviso")


## Escolhe os pontos e mostra o telégrafo durante o aviso. Devolve o que o efeito precisa.
func _preparar(id: String, ev: Dictionary, cor: Color, aviso: float) -> Dictionary:
	var preparo := {}
	match id:
		"erupcao":
			var pontos: Array[Vector3] = []
			var raio := float(ev.get("raio", 2.2))
			for i in int(ev.get("jatos", 3)):
				var p := _ponto_livre(14.0, 1.0, pontos, raio * 2.2)
				pontos.append(p)
				Efeitos.telegrafo(self, p, raio, cor, aviso)
			preparo["pontos"] = pontos
		"mare_alta":
			_telegrafo_anel(float(ev.get("raio_interno", 14.0)), cor, aviso)
		"raio":
			var alvo := _mais_longe_do_centro()
			var p := alvo.global_position
			p.y = 0.0
			Efeitos.telegrafo(self, p, float(ev.get("raio", 2.4)), cor, aviso)
			preparo["ponto"] = p
		"desmoronamento":
			var raio := float(ev.get("raio", 1.3))
			var p := _ponto_livre(13.0, raio + 1.2, [], 0.0)
			Efeitos.telegrafo(self, p, raio + 0.9, cor, aviso)
			preparo["ponto"] = p
		"rajada":
			var ang := randf() * TAU
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			preparo["direcao"] = dir
			if visual:
				_riscos_de_vento(dir, aviso + 1.0, Color(str(ev.get("cor", "#cfe8d8"))))
		"eco_de_cura":
			var p := _ponto_equidistante()
			Efeitos.telegrafo(self, p, float(ev.get("raio", 1.7)), cor, aviso)
			preparo["ponto"] = p
		"tempestade_areia", "falha_da_rede":
			if visual:
				_piscar_ambiente(cor, aviso)
	return preparo


# ---------------------------------------------------------------------
# Os eventos
# ---------------------------------------------------------------------

## Três jatos de lava: área de dano (perigo "lava" temporário) e empurrão por `duracao` s.
func _erupcao(ev: Dictionary, cor: Color, preparo: Dictionary) -> void:
	var raio := float(ev.get("raio", 2.2))
	var dano := float(ev.get("dano", 8))
	var duracao := float(ev.get("duracao", 3.0))
	_som("explosao")
	Efeitos.tremer_camera(get_tree(), 0.7)
	for p in preparo.get("pontos", []):
		var ponto: Vector3 = p
		var perigo := {"tipo": "lava", "centro": Vector2(ponto.x, ponto.z), "raio": raio, "temporario": true}
		batalha.perigos.append(perigo)
		_perigos_temporarios.append(perigo)
		var jato := _jato_de_lava(ponto, raio, cor, duracao)
		_jatos.append({"centro": Vector2(ponto.x, ponto.z), "raio": raio, "t": duracao, "no": jato, "perigo": perigo, "empurrao": float(ev.get("empurrao", 14))})
		Efeitos.explosao(self, ponto + Vector3(0, 0.5, 0), cor, raio * 2.0, 0.5)
		for l in _lutadores():
			if l.no_alto():
				continue
			var d := Vector2(l.global_position.x, l.global_position.z).distance_to(Vector2(ponto.x, ponto.z))
			if d <= raio + 0.8:
				_dano(l, dano, cor)
				l.empurrar(_afastar(l.global_position, ponto) * float(ev.get("empurrao", 14)))


## A água sobe pelas bordas: anel (raio_interno..borda) vira perigo "agua" por `duracao` s.
func _mare_alta(ev: Dictionary, cor: Color) -> void:
	var interno := float(ev.get("raio_interno", 14.0))
	var duracao := float(ev.get("duracao", 8.0))
	var perigo := {"tipo": "agua", "centro": Vector2.ZERO, "raio": 40.0, "raio_interno": interno, "temporario": true}
	batalha.perigos.append(perigo)
	_perigos_temporarios.append(perigo)
	_mare_t = duracao
	_som("vento", -4.0, 0.6)
	# Anel de água que sobe e baixa.
	var anel := TorusMesh.new()
	anel.inner_radius = interno
	anel.outer_radius = Lutador.RAIO_ARENA + 2.5
	anel.rings = 64
	anel.ring_segments = 8
	var mat := Efeitos.material(Color("#1848c8"), 0.25, 0.92)
	var mi := MeshInstance3D.new()
	mi.mesh = anel
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1.0, 0.08, 1.0)
	mi.position.y = -0.6
	add_child(mi)
	_nos_temporarios.append(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position:y", 0.3, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(t: float): mi.position.y = 0.37 + 0.08 * sin(t * TAU * 4.0), 0.0, 1.0, duracao - 1.6)
	tw.tween_property(mi, "position:y", -0.6, 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_remover_perigo(perigo)
		_liberar(mi))
	_espuma(interno, cor, duracao)


## Poeira cobre a arena: os dois ficam escondidos (projéteis não perseguem) por `duracao` s.
func _tempestade_areia(ev: Dictionary, cor: Color) -> void:
	var duracao := float(ev.get("duracao", 6.0))
	_cegueira_t = duracao
	_som("vento")
	if not visual:
		return
	var gerador := RandomNumberGenerator.new()
	for i in 14:
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		esfera.radial_segments = 10
		esfera.rings = 5
		var mat := Efeitos.material(cor, 0.15, 0.0, true)
		var mi := MeshInstance3D.new()
		mi.mesh = esfera
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var ang := gerador.randf() * TAU
		var r := gerador.randf_range(2.0, 18.0)
		mi.position = Vector3(cos(ang) * r, gerador.randf_range(1.0, 3.5), sin(ang) * r)
		mi.scale = Vector3(gerador.randf_range(5.0, 9.0), gerador.randf_range(2.5, 4.0), gerador.randf_range(5.0, 9.0))
		add_child(mi)
		_nos_temporarios.append(mi)
		var tw := mi.create_tween()
		tw.tween_property(mat, "albedo_color:a", 0.42, 0.6)
		tw.parallel().tween_property(mi, "position", mi.position + _vento_dir * gerador.randf_range(6.0, 12.0), duracao)
		tw.tween_interval(maxf(0.0, duracao - 1.4))
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
		tw.tween_callback(_liberar.bind(mi))
	_ajustar_nevoa_ambiente(0.035, cor, 0.5)
	var volta := create_tween()
	volta.tween_interval(duracao - 0.5)
	volta.tween_callback(_ajustar_nevoa_ambiente.bind(_fog_original, _cor_fog_original, 0.8))


## Um raio cai no ponto avisado: dano + atordoamento a quem estiver no círculo.
func _raio(ev: Dictionary, cor: Color, preparo: Dictionary) -> void:
	var ponto: Vector3 = preparo.get("ponto", Vector3.ZERO)
	var raio := float(ev.get("raio", 2.4))
	_som("explosao", 2.0, 1.4)
	Efeitos.tremer_camera(get_tree(), 0.8)
	Efeitos.explosao(self, ponto + Vector3(0, 0.6, 0), cor, raio * 2.2, 0.45)
	if visual:
		_coluna_de_luz(ponto, cor, 0.7, 0.7)
	for l in _lutadores():
		var d := Vector2(l.global_position.x, l.global_position.z).distance_to(Vector2(ponto.x, ponto.z))
		if d <= raio + 0.6:
			_dano(l, float(ev.get("dano", 12)), cor)
			l.atordoar(float(ev.get("atordoar", 0.8)))


## Uma pedra cai do céu, machuca quem está embaixo e vira um obstáculo novo.
func _desmoronamento(ev: Dictionary, cor: Color, preparo: Dictionary) -> void:
	var ponto: Vector3 = preparo.get("ponto", Vector3.ZERO)
	var raio := float(ev.get("raio", 1.3))
	var altura := float(ev.get("altura", 2.8))
	var estilo := str(batalha.local.get("estilo_obstaculo", "rocha"))
	if estilo in ["pilar", "arvore"]:
		estilo = "rocha"
	var o: Dictionary = batalha.adicionar_obstaculo(ponto, raio, altura, estilo)
	batalha.obstaculos.erase(o)
	var corpo: Node3D = o["corpo"]
	corpo.position.y = 28.0
	_som("salto", -4.0, 0.5)
	var tw := corpo.create_tween()
	tw.tween_property(corpo, "position:y", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not _ativo_valido():
			return
		batalha.obstaculos.append(o)
		_som("quebra")
		Efeitos.tremer_camera(get_tree(), 1.0)
		Efeitos.explosao(self, ponto + Vector3(0, 0.4, 0), cor, raio * 3.0, 0.5)
		for l in _lutadores():
			if l.no_alto():
				continue
			var d := Vector2(l.global_position.x, l.global_position.z).distance_to(Vector2(ponto.x, ponto.z))
			if d <= raio + 0.9:
				_dano(l, float(ev.get("dano", 14)), cor)
				l.empurrar(_afastar(l.global_position, ponto) * float(ev.get("empurrao", 12))))


## Vento forte: empurra os dois na mesma direção.
func _rajada(ev: Dictionary, preparo: Dictionary) -> void:
	var dir: Vector3 = preparo.get("direcao", Vector3.RIGHT)
	_som("vento")
	for l in _lutadores():
		l.empurrar(dir * float(ev.get("forca", 16)))
	if batalha.hud:
		batalha.hud.banner("Rajada de vento!", 1.0)


## Arena corrompida: obstáculos trocam de lugar e o bônus elemental vira penalidade.
func _falha_da_rede(ev: Dictionary, cor: Color) -> void:
	var duracao := float(ev.get("duracao", 10.0))
	_inversao_t = duracao
	_troca_t = 0.3
	_inverter_modificadores(true)
	_som("cantico_falha")
	if visual:
		_ajustar_nevoa_ambiente(0.012, cor, 0.3)
		Efeitos.explosao(self, Vector3(0, 1.0, 0), cor, 8.0, 0.6)


## Esfera verde: quem chegar primeiro cura.
func _eco_de_cura(ev: Dictionary, cor: Color, preparo: Dictionary) -> void:
	var ponto: Vector3 = preparo.get("ponto", Vector3.ZERO)
	var raiz := Node3D.new()
	raiz.position = ponto + Vector3(0, 1.1, 0)
	add_child(raiz)
	_nos_temporarios.append(raiz)
	var esfera := SphereMesh.new()
	esfera.radius = 0.55
	esfera.height = 1.1
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = Efeitos.material(cor, 2.2, 1.0, true)
	mi.material_override.next_pass = Efeitos.material_contorno(2.5)
	raiz.add_child(mi)
	var anel := TorusMesh.new()
	anel.inner_radius = 0.8
	anel.outer_radius = 0.95
	var mi_anel := MeshInstance3D.new()
	mi_anel.mesh = anel
	mi_anel.material_override = Efeitos.material(cor.lightened(0.4), 2.0, 1.0, true)
	raiz.add_child(mi_anel)
	if visual:
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.light_energy = 1.6
		luz.omni_range = 7.0
		raiz.add_child(luz)
	var tw := raiz.create_tween().set_loops()
	tw.tween_property(raiz, "position:y", ponto.y + 1.5, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(raiz, "position:y", ponto.y + 0.9, 0.9).set_trans(Tween.TRANS_SINE)
	var tw2 := mi_anel.create_tween().set_loops()
	tw2.tween_property(mi_anel, "rotation", Vector3(0.6, TAU, 0.0), 2.0).as_relative()
	_som("cantico_ok")
	_eco = {"no": raiz, "centro": Vector2(ponto.x, ponto.z), "raio": float(ev.get("raio", 1.7)), "cura": float(ev.get("cura", 25)), "t": float(ev.get("duracao", 12.0)), "cor": cor}


# ---------------------------------------------------------------------
# Efeitos contínuos (por quadro)
# ---------------------------------------------------------------------

func _processar_efeitos(delta: float) -> void:
	if _cegueira_t > 0.0:
		_cegueira_t -= delta
	if _mare_t > 0.0:
		_mare_t -= delta
	# Jatos de lava empurram quem está dentro.
	for j in _jatos.duplicate():
		j["t"] = float(j["t"]) - delta
		if float(j["t"]) <= 0.0:
			_jatos.erase(j)
			_remover_perigo(j["perigo"])
			continue
		for l in _lutadores():
			if l.no_alto():
				continue
			var plano := Vector2(l.global_position.x, l.global_position.z)
			if plano.distance_to(j["centro"]) <= float(j["raio"]) + 0.3:
				var dir := _afastar(l.global_position, Vector3(j["centro"].x, 0.0, j["centro"].y))
				l.empurrar(dir * float(j["empurrao"]) * 2.5 * delta)
	# Falha da Rede: contagem e troca de obstáculos.
	if _inversao_t > 0.0:
		_inversao_t -= delta
		_troca_t -= delta
		if _troca_t <= 0.0:
			_troca_t = float(dados_evento("falha_da_rede").get("intervalo_troca", 2.5))
			_trocar_obstaculos()
		if _inversao_t <= 0.0:
			_inverter_modificadores(false)
			if batalha.hud:
				batalha.hud.banner("A Rede voltou ao normal.", 1.5)
			if visual:
				_ajustar_nevoa_ambiente(_fog_original, _cor_fog_original, 0.8)
	# Eco de cura: quem chega primeiro leva.
	if not _eco.is_empty():
		_eco["t"] = float(_eco["t"]) - delta
		var pego := false
		for l in _lutadores():
			var plano := Vector2(l.global_position.x, l.global_position.z)
			if plano.distance_to(_eco["centro"]) <= float(_eco["raio"]) + l.raio_acerto() * 0.5:
				l.curar(float(_eco["cura"]))
				_som("cura")
				Efeitos.explosao(self, l.centro(), _eco["cor"], 2.2, 0.5)
				if batalha.hud:
					batalha.hud.banner("%s pegou o Eco de Cura!" % l.nome, 1.5)
				pego = true
				break
		if pego or float(_eco["t"]) <= 0.0:
			_liberar(_eco["no"])
			_eco = {}


func _processar_ambiente(delta: float) -> void:
	var local := batalha.local
	# Vento constante: empurrões curtos e frequentes numa direção que gira devagar.
	var forca := float(local.get("vento_constante", 0.0))
	if forca > 0.0:
		_vento_giro += delta * 0.15
		_vento_dir = Vector3(cos(_vento_giro), 0.0, sin(_vento_giro))
		_vento_t -= delta
		if _vento_t <= 0.0:
			_vento_t = 0.8
			for l in _lutadores():
				if not l.no_alto():
					l.empurrar(_vento_dir * forca)
			if visual and randf() < 0.5:
				_riscos_de_vento(_vento_dir, 1.2, Color("#e8d9b0"), 3)
	# Névoa que anda.
	for n in _nevoas:
		n["fase"] = float(n["fase"]) + delta * float(n["velocidade"])
		var origem: Vector2 = n["origem"]
		var desloc := Vector2(cos(float(n["fase"])), sin(float(n["fase"]) * 0.7)) * 5.0
		var centro := origem + desloc
		if centro.length() > Lutador.RAIO_ARENA - 2.0:
			centro = centro.normalized() * (Lutador.RAIO_ARENA - 2.0)
		n["perigo"]["centro"] = centro
		var no: Node3D = n["no"]
		if is_instance_valid(no):
			no.position = Vector3(centro.x, 0.0, centro.y)
	# Arena corrompida: um obstáculo some e volta.
	if bool(local.get("corrompido", false)):
		_corrompido_t -= delta
		if _corrompido_t <= 0.0:
			_corrompido_t = randf_range(5.0, 8.0)
			_alternar_obstaculo_corrompido()
		for s in _sumidos.duplicate():
			s["t"] = float(s["t"]) - delta
			if float(s["t"]) <= 0.0 and _ninguem_em(s["dados"]["centro"], float(s["dados"]["raio"]) + 1.0):
				_sumidos.erase(s)
				_reaparecer_obstaculo(s["dados"])


# ---------------------------------------------------------------------
# Encerramento e limpeza
# ---------------------------------------------------------------------

## Para tudo: perigos temporários, modificadores, nós visuais, névoa. Chamado no fim da luta.
func encerrar() -> void:
	ativo = false
	_em_curso = false
	_cegueira_t = 0.0
	_mare_t = 0.0
	_jatos.clear()
	if _inversao_t > 0.0:
		_inversao_t = 0.0
		_inverter_modificadores(false)
	for p in _perigos_temporarios:
		batalha.perigos.erase(p)
	_perigos_temporarios.clear()
	for no in _nos_temporarios:
		if is_instance_valid(no):
			no.queue_free()
	_nos_temporarios.clear()
	_eco = {}
	if visual and is_instance_valid(batalha) and is_inside_tree():
		_ajustar_nevoa_ambiente(_fog_original, _cor_fog_original, 0.3)


func _exit_tree() -> void:
	if ativo and is_instance_valid(batalha):
		encerrar()


func _ativo_valido() -> bool:
	return is_inside_tree() and is_instance_valid(batalha) and batalha.em_andamento


# ---------------------------------------------------------------------
# Apoio
# ---------------------------------------------------------------------

func _lutadores() -> Array:
	var lista := []
	for l in [batalha.jogador, batalha.inimigo]:
		if is_instance_valid(l) and l.energia > 0.0:
			lista.append(l)
	return lista


## Dano de evento: mostra o número e respeita o modo fácil (metade para o jogador).
func _dano(l: Lutador, valor: float, cor: Color) -> void:
	if l.invulneravel():
		l.mostrar_texto("Esquivou!", Color(0.85, 0.85, 0.85))
		return
	if facil and l.e_jogador:
		valor *= 0.5
	valor = l.modificar_dano_recebido(valor)
	l.receber_dano(valor)
	if valor > 0.0:
		l.mostrar_texto("%d" % roundi(valor), cor.lightened(0.3))


func _afastar(de: Vector3, centro: Vector3) -> Vector3:
	var d := de - centro
	d.y = 0.0
	if d.length() < 0.05:
		var ang := randf() * TAU
		return Vector3(cos(ang), 0.0, sin(ang))
	return d.normalized()


func _mais_longe_do_centro() -> Lutador:
	var lista := _lutadores()
	if lista.is_empty():
		return batalha.inimigo
	var melhor: Lutador = lista[0]
	for l in lista:
		if Vector2(l.global_position.x, l.global_position.z).length() > Vector2(melhor.global_position.x, melhor.global_position.z).length():
			melhor = l
	return melhor


## Ponto aleatório da arena longe de obstáculos, perigos e dos pontos já escolhidos.
func _ponto_livre(raio_max: float, margem: float, evitar: Array, dist_evitar: float) -> Vector3:
	var melhor := Vector3.ZERO
	for tentativa in 30:
		var ang := randf() * TAU
		var r := sqrt(randf()) * raio_max
		var p := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
		melhor = p
		if not _ponto_ok(p, margem):
			continue
		var perto := false
		for e in evitar:
			if p.distance_to(e) < dist_evitar:
				perto = true
		if not perto:
			return p
	return melhor


func _ponto_ok(p: Vector3, margem: float) -> bool:
	var plano := Vector2(p.x, p.z)
	for o in batalha.obstaculos:
		if plano.distance_to(o["centro"]) < float(o["raio"]) + margem:
			return false
	for pr in batalha.perigos:
		if str(pr["tipo"]) in ["lava", "agua"] and not bool(pr.get("temporario", false)) \
				and plano.distance_to(pr["centro"]) < float(pr["raio"]) + margem * 0.5:
			return false
	return true


## Ponto livre a distâncias parecidas dos dois lutadores (justo para o Eco de Cura).
func _ponto_equidistante() -> Vector3:
	var lista := _lutadores()
	var melhor := Vector3.ZERO
	var melhor_dif := INF
	for i in 14:
		var p := _ponto_livre(12.0, 1.2, [], 0.0)
		var dif := 0.0
		if lista.size() == 2:
			var a: Lutador = lista[0]
			var b: Lutador = lista[1]
			var da := a.global_position.distance_to(p)
			var db := b.global_position.distance_to(p)
			dif = absf(da - db) + maxf(0.0, 4.0 - minf(da, db)) * 3.0
		if dif < melhor_dif:
			melhor_dif = dif
			melhor = p
	return melhor


func _ninguem_em(centro: Vector2, raio: float) -> bool:
	for l in _lutadores():
		if Vector2(l.global_position.x, l.global_position.z).distance_to(centro) < raio:
			return false
	return true


func _remover_perigo(p: Dictionary) -> void:
	batalha.perigos.erase(p)
	_perigos_temporarios.erase(p)


func _liberar(no: Node) -> void:
	if is_instance_valid(no):
		_nos_temporarios.erase(no)
		no.queue_free()


func _esperar(segundos: float) -> void:
	await get_tree().create_timer(segundos).timeout


## Som do evento (silencioso na simulação headless).
func _som(nome: String, volume_db := 0.0, afinacao := 1.0) -> void:
	if visual:
		Audio.tocar(nome, volume_db, afinacao)


func _inverter_modificadores(inverter: bool) -> void:
	var mods: Array = batalha.local.get("modificadores", [])
	if inverter:
		_modificadores_originais = mods.duplicate(true)
		for m in mods:
			m["dano_bonus"] = -absf(float(m.get("dano_bonus", 0)))
	else:
		for i in mods.size():
			if i < _modificadores_originais.size():
				mods[i]["dano_bonus"] = _modificadores_originais[i].get("dano_bonus", 0)


## Falha da Rede: dois obstáculos piscam e trocam de lugar (nunca em cima de alguém).
func _trocar_obstaculos() -> void:
	var lista: Array = batalha.obstaculos.duplicate()
	if lista.size() < 2:
		return
	lista.shuffle()
	var a: Dictionary = lista[0]
	var b: Dictionary = lista[1]
	if not _ninguem_em(a["centro"], float(b["raio"]) + 1.0) or not _ninguem_em(b["centro"], float(a["raio"]) + 1.0):
		return
	var corpo_a: Node3D = a["corpo"]
	var corpo_b: Node3D = b["corpo"]
	var pos_a := corpo_a.position
	var pos_b := corpo_b.position
	var roxo := Color("#b45bff")
	Efeitos.explosao(self, pos_a + Vector3(0, 1, 0), roxo, 2.0, 0.3)
	Efeitos.explosao(self, pos_b + Vector3(0, 1, 0), roxo, 2.0, 0.3)
	_som("estrela", -6.0, 0.7)
	a["centro"] = Vector2(pos_b.x, pos_b.z)
	b["centro"] = Vector2(pos_a.x, pos_a.z)
	for par in [[corpo_a, pos_b], [corpo_b, pos_a]]:
		var corpo: Node3D = par[0]
		var destino: Vector3 = par[1]
		var tw := corpo.create_tween()
		tw.tween_property(corpo, "scale", Vector3(0.05, 1.2, 0.05), 0.18)
		tw.tween_callback(func(): corpo.position = destino)
		tw.tween_property(corpo, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Arena corrompida: tira um obstáculo da luta por alguns segundos.
func _alternar_obstaculo_corrompido() -> void:
	if batalha.obstaculos.size() <= 2:
		return
	var o: Dictionary = batalha.obstaculos.pick_random()
	batalha.obstaculos.erase(o)
	var corpo: StaticBody3D = o["corpo"]
	corpo.collision_layer = 0
	Efeitos.explosao(self, corpo.position + Vector3(0, 1, 0), Color("#b45bff"), 2.0, 0.3)
	var tw := corpo.create_tween()
	tw.tween_property(corpo, "scale", Vector3(0.02, 1.4, 0.02), 0.3)
	tw.tween_callback(func(): corpo.visible = false)
	_sumidos.append({"dados": o, "t": randf_range(4.0, 6.0)})


func _reaparecer_obstaculo(o: Dictionary) -> void:
	var corpo: StaticBody3D = o["corpo"]
	if not is_instance_valid(corpo):
		return
	corpo.visible = true
	corpo.collision_layer = 1
	batalha.obstaculos.append(o)
	Efeitos.explosao(self, corpo.position + Vector3(0, 1, 0), Color("#d9b3ff"), 2.0, 0.3)
	var tw := corpo.create_tween()
	tw.tween_property(corpo, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------
# Visuais dos eventos
# ---------------------------------------------------------------------

func _jato_de_lava(ponto: Vector3, raio: float, cor: Color, duracao: float) -> Node3D:
	var raiz := Node3D.new()
	raiz.position = ponto
	add_child(raiz)
	_nos_temporarios.append(raiz)
	var poca := CylinderMesh.new()
	poca.top_radius = raio
	poca.bottom_radius = raio
	poca.height = 0.08
	poca.radial_segments = 32
	var mp := MeshInstance3D.new()
	mp.mesh = poca
	mp.material_override = Efeitos.material(Color(1.0, 0.35, 0.08), 1.3)
	mp.position.y = 0.05
	raiz.add_child(mp)
	var jato := CylinderMesh.new()
	jato.top_radius = raio * 0.25
	jato.bottom_radius = raio * 0.7
	jato.height = 1.0
	jato.radial_segments = 12
	var mj := MeshInstance3D.new()
	mj.mesh = jato
	mj.material_override = Efeitos.material(cor.lightened(0.2), 2.0, 0.85, true)
	mj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mj.position.y = 0.5
	mj.scale = Vector3(1.0, 0.1, 1.0)
	raiz.add_child(mj)
	if visual:
		var luz := OmniLight3D.new()
		luz.light_color = cor
		luz.light_energy = 2.0
		luz.omni_range = raio * 4.0
		luz.position.y = 1.5
		raiz.add_child(luz)
	var tw := raiz.create_tween()
	tw.tween_property(mj, "scale", Vector3(1.0, 6.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mj, "position:y", 3.0, 0.25)
	tw.tween_method(func(t: float): mj.scale = Vector3(1.05 - 0.15 * sin(t * TAU * 3.0), 5.5 + 1.0 * sin(t * TAU * 3.0), 1.05 - 0.15 * sin(t * TAU * 3.0)), 0.0, 1.0, duracao - 0.6)
	tw.tween_property(mj, "scale", Vector3(1.0, 0.05, 1.0), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(mj, "position:y", 0.0, 0.35)
	tw.tween_property(mp, "scale", Vector3(0.05, 1.0, 0.05), 0.4)
	tw.tween_callback(_liberar.bind(raiz))
	return raiz


func _telegrafo_anel(raio_interno: float, cor: Color, duracao: float) -> void:
	var anel := TorusMesh.new()
	anel.inner_radius = 0.96
	anel.outer_radius = 1.0
	anel.rings = 64
	var mi := MeshInstance3D.new()
	mi.mesh = anel
	mi.material_override = Efeitos.material(cor, 2.0, 0.9, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.08
	mi.scale = Vector3(Lutador.RAIO_ARENA, 1.0, Lutador.RAIO_ARENA)
	add_child(mi)
	_nos_temporarios.append(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(raio_interno, 1.0, raio_interno), duracao).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_liberar.bind(mi))
	# Setas simples (cones) apontando para o centro, nos quatro lados.
	for i in 4:
		var ang := TAU * i / 4.0
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.6
		cone.height = 1.6
		cone.radial_segments = 8
		var mc := MeshInstance3D.new()
		mc.mesh = cone
		mc.material_override = Efeitos.material(cor, 2.0, 1.0, true)
		mc.position = Vector3(cos(ang) * 17.0, 0.8, sin(ang) * 17.0)
		mc.rotation = Vector3(0, -ang, PI / 2.0)
		add_child(mc)
		_nos_temporarios.append(mc)
		var tc := mc.create_tween()
		tc.tween_property(mc, "position", Vector3(cos(ang) * 12.0, 0.8, sin(ang) * 12.0), duracao * 0.5)
		tc.tween_property(mc, "position", Vector3(cos(ang) * 17.0, 0.8, sin(ang) * 17.0), 0.0)
		tc.tween_property(mc, "position", Vector3(cos(ang) * 12.0, 0.8, sin(ang) * 12.0), duracao * 0.5)
		tc.tween_callback(_liberar.bind(mc))


func _espuma(raio_interno: float, cor: Color, duracao: float) -> void:
	if not visual:
		return
	var gerador := RandomNumberGenerator.new()
	for i in 16:
		var ang := TAU * i / 16.0
		var esfera := SphereMesh.new()
		esfera.radius = 0.7
		esfera.height = 0.7
		var mat := Efeitos.material(Color.WHITE, 0.8, 0.9, true)
		var mi := MeshInstance3D.new()
		mi.mesh = esfera
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(ang) * raio_interno, 0.45, sin(ang) * raio_interno)
		add_child(mi)
		_nos_temporarios.append(mi)
		var maior := gerador.randf_range(1.3, 1.8)
		var tw := mi.create_tween()
		tw.tween_method(func(t: float): mi.scale = Vector3.ONE * lerpf(0.8, maior, 0.5 + 0.5 * sin(t * TAU * duracao / 1.2)), 0.0, 1.0, duracao)
		tw.tween_callback(_liberar.bind(mi))


func _coluna_de_luz(ponto: Vector3, cor: Color, raio: float, duracao: float) -> void:
	var col := CylinderMesh.new()
	col.top_radius = raio
	col.bottom_radius = raio * 0.5
	col.height = 40.0
	col.radial_segments = 8
	var mat := Efeitos.material(cor.lightened(0.5), 3.0, 1.0, true)
	var mi := MeshInstance3D.new()
	mi.mesh = col
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = ponto + Vector3(0, 20.0, 0)
	add_child(mi)
	_nos_temporarios.append(mi)
	# Ramos tortos em volta da coluna: silhueta de raio, não de poste.
	for i in 3:
		var ramo := CylinderMesh.new()
		ramo.top_radius = raio * 0.25
		ramo.bottom_radius = raio * 0.25
		ramo.height = 7.0
		ramo.radial_segments = 6
		var mr := MeshInstance3D.new()
		mr.mesh = ramo
		mr.material_override = mat
		mr.position = Vector3(0, 2.5 + i * 3.0, 0)
		mr.rotation = Vector3(0.0, TAU * i / 3.0, 0.55)
		mr.rotate_object_local(Vector3.UP, 0.0)
		mi.add_child(mr)
		mr.position = Vector3(cos(TAU * i / 3.0) * 1.5, -17.0 + i * 4.0, sin(TAU * i / 3.0) * 1.5)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 6.0
	luz.omni_range = 16.0
	luz.position = ponto + Vector3(0, 2.0, 0)
	add_child(luz)
	_nos_temporarios.append(luz)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(2.2, 1.0, 2.2), duracao * 0.3)
	tw.parallel().tween_property(luz, "light_energy", 0.0, duracao)
	tw.tween_property(mat, "albedo_color:a", 0.0, duracao * 0.7)
	tw.tween_callback(func(): _liberar(mi); _liberar(luz))


## Riscos brancos cruzando a arena na direção do vento.
func _riscos_de_vento(dir: Vector3, duracao: float, cor: Color, quantidade := 10) -> void:
	var gerador := RandomNumberGenerator.new()
	var lateral := Vector3(-dir.z, 0.0, dir.x)
	for i in quantidade:
		var risco := BoxMesh.new()
		risco.size = Vector3(0.16, 0.16, gerador.randf_range(3.0, 6.0))
		var mi := MeshInstance3D.new()
		mi.mesh = risco
		mi.material_override = Efeitos.material(Color.WHITE, 1.5, 0.9, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var desloc := lateral * gerador.randf_range(-18.0, 18.0)
		var inicio := -dir * 24.0 + desloc + Vector3(0, gerador.randf_range(0.4, 2.2), 0)
		mi.position = inicio
		add_child(mi)
		mi.look_at(inicio + dir, Vector3.UP)
		_nos_temporarios.append(mi)
		var tw := mi.create_tween()
		tw.tween_interval(gerador.randf_range(0.0, duracao * 0.5))
		tw.tween_property(mi, "position", inicio + dir * 48.0, gerador.randf_range(0.5, 0.9))
		tw.tween_callback(_liberar.bind(mi))


## O sol pisca na cor do evento durante o aviso.
func _piscar_ambiente(cor: Color, duracao: float) -> void:
	if batalha.sol == null:
		return
	var tw := create_tween().set_loops(int(duracao / 0.5))
	tw.tween_property(batalha.sol, "light_color", cor, 0.25)
	tw.tween_property(batalha.sol, "light_color", _cor_sol_original, 0.25)


## Densidade e cor da névoa do ambiente (tempestade de areia, Falha da Rede) e cor do sol.
func _ajustar_nevoa_ambiente(densidade: float, cor: Color, duracao: float) -> void:
	if batalha == null or not is_instance_valid(batalha) or batalha.ambiente == null or batalha.ambiente.environment == null:
		return
	var env: Environment = batalha.ambiente.environment
	var tw := create_tween()
	tw.tween_property(env, "fog_density", densidade, duracao)
	tw.parallel().tween_property(env, "fog_light_color", cor if densidade > _fog_original else _cor_fog_original, duracao)
	if batalha.sol:
		tw.parallel().tween_property(batalha.sol, "light_color", cor.lerp(_cor_sol_original, 0.5) if densidade > _fog_original else _cor_sol_original, duracao)
