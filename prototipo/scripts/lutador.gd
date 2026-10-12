class_name Lutador
extends CharacterBody3D
## Monstro em combate. Os controladores (jogador ou IA) só preenchem
## `direcao_movimento` e chamam as ações públicas: pular, esquivar,
## ataque_basico, usar_carta, iniciar_cantico e cantico_tecla.

signal derrotado(lutador: Lutador)

const GRAVIDADE := 24.0
const RAIO_ARENA := 20.0
const ALCANCE_BASICO := 2.3
const VELOCIDADE_ESQUIVA := 17.0
const VELOCIDADE_INVESTIDA := 20.0
const TAMANHO_SEQUENCIA_CANTICO := 4
const TECLAS_CANTICO := ["mover_frente", "mover_esq", "mover_tras", "mover_dir"]

# --- Dados vindos das cartas ---
var id_monstro := ""
var nome := ""
var dados_monstro: Dictionary = {}
var equipamento: Dictionary = {}
var cantico: Dictionary = {}
var atributos: Dictionary = {}
var elementos: Array[String] = []
var energia_max := 100.0
var energia := 100.0
var cargas_cantico := 0
var reducao_dano := 0.0
var passiva := ""
var escala := 1.0
var forma := "agil"
var equipamento_revelado := false

var mao := MaoCartas.new()
var deck: Array = []
var alvo: Lutador
var local: Dictionary = {}
var e_jogador := false
var controles_ativos := false

# --- Estado de combate ---
var direcao_movimento := Vector3.ZERO
var acao: Dictionary = {}
var atordoado_t := 0.0
var invulneravel_t := 0.0
var esquiva_t := 0.0
var esquiva_recarga := 0.0
var basico_recarga := 0.0
var esquiva_dir := Vector3.ZERO
var empurrao := Vector3.ZERO
var mult_velocidade_ambiente := 1.0

var cantando := false
var cantico_t := 0.0
var cantico_limite := 3.0
var cantico_sequencia: Array[String] = []
var cantico_progresso := 0

# --- Visual ---
var _visual: Node3D
var _materiais: Array[StandardMaterial3D] = []
var _cores_base: Array[Color] = []
var _flash_t := 0.0
var _anim_t := 0.0
var _sockets: Dictionary = {}
var _modelo_equip: Node3D
var _cabeca_pos := Vector3(0, 1.75, -0.15)
var _cabeca_raio := 0.32
var _dano_ambiente := 0.0
var _contador_texto := 0


# =====================================================================
# Configuração
# =====================================================================

func configurar(monstro_id: String, equip_id: String, cantico_id: String, deck_ids: Array) -> void:
	id_monstro = monstro_id
	dados_monstro = Dados.monstros[monstro_id]
	nome = str(dados_monstro["nome"])
	equipamento = Dados.equipamentos.get(equip_id, {})
	cantico = Dados.canticos.get(cantico_id, {})
	deck = deck_ids.duplicate()
	escala = float(dados_monstro.get("escala", 1.0))
	forma = str(dados_monstro.get("forma", "agil"))
	var base: Dictionary = dados_monstro["atributos"]
	for chave in Dados.ATRIBUTOS:
		atributos[chave] = float(base.get(chave, 0))
	elementos.assign(dados_monstro["elementos"])
	energia_max = float(dados_monstro["energia"])
	cargas_cantico = int(dados_monstro.get("cargas_cantico", 0))
	var dados_passiva: Dictionary = dados_monstro.get("passiva", {})
	passiva = str(dados_passiva.get("tipo", ""))

	# Equipamento (Battlegear): bônus passivos e elemento extra.
	if not equipamento.is_empty():
		var bonus: Dictionary = equipamento.get("passivo", {})
		for chave in bonus:
			if atributos.has(chave):
				atributos[chave] += float(bonus[chave])
		energia_max += float(bonus.get("energia", 0))
		reducao_dano = float(bonus.get("reducao_dano", 0))
		var el := str(equipamento.get("elemento", ""))
		if el != "" and not elementos.has(el):
			elementos.append(el)
	energia = energia_max

	collision_layer = 2
	collision_mask = 1 | 2
	_criar_colisao()
	_construir_visual()


func _criar_colisao() -> void:
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.6 * escala
	capsula.height = 2.0 * escala
	var col := CollisionShape3D.new()
	col.shape = capsula
	col.position.y = capsula.height / 2.0
	add_child(col)


# =====================================================================
# Atributos derivados (como cada "disciplina" afeta a ação 3D)
# =====================================================================

func atributo(chave: String) -> float:
	return float(atributos.get(chave, 0.0))

func velocidade_movimento() -> float:
	return 4.0 + atributo("agilidade") * 0.05

func recarga_esquiva() -> float:
	return maxf(0.6, 2.2 - atributo("agilidade") * 0.012)

func mult_recarga() -> float:
	return maxf(0.4, 1.0 - atributo("mente") * 0.004)

func mult_cantico() -> float:
	return 0.6 + atributo("mente") / 100.0

func chance_critico() -> float:
	return atributo("animo") * 0.002

func resistencia_atordoar() -> float:
	return clampf(atributo("animo") * 0.004, 0.0, 0.6)

func dano_basico() -> float:
	return 4.0 + atributo("forca") * 0.08

func invulneravel() -> bool:
	return invulneravel_t > 0.0

func centro() -> Vector3:
	return global_position + Vector3(0, 1.1 * escala, 0)

func raio_acerto() -> float:
	return 0.95 * escala

func pode_agir() -> bool:
	return controles_ativos and energia > 0.0 and atordoado_t <= 0.0 and acao.is_empty() \
		and not cantando and esquiva_t <= 0.0


func modificar_dano_causado(valor: float) -> Array:
	var critico := randf() < chance_critico()
	if critico:
		valor *= 1.5
	if passiva == "furia" and energia < energia_max * 0.4:
		valor *= 1.3
	return [valor, critico]


func modificar_dano_recebido(valor: float) -> float:
	valor *= 1.0 - reducao_dano
	if passiva == "pele_rocha":
		valor -= 2.0
	return maxf(1.0, valor)


# =====================================================================
# Loop principal
# =====================================================================

func _physics_process(delta: float) -> void:
	_anim_t += delta
	_atualizar_flash(delta)
	if energia <= 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVIDADE * delta
		move_and_slide()
		return

	atordoado_t = maxf(0.0, atordoado_t - delta)
	invulneravel_t = maxf(0.0, invulneravel_t - delta)
	esquiva_t = maxf(0.0, esquiva_t - delta)
	esquiva_recarga = maxf(0.0, esquiva_recarga - delta)
	basico_recarga = maxf(0.0, basico_recarga - delta)
	if controles_ativos:
		mao.processar(delta)
		if passiva == "fluxo":
			curar(2.0 * delta, false)

	var horizontal := Vector3.ZERO
	var usar_fisica := true
	if atordoado_t > 0.0:
		pass
	elif cantando:
		_processar_cantico(delta)
	elif not acao.is_empty():
		horizontal = _processar_acao(delta)
		usar_fisica = not bool(acao.get("manual", false))
	elif esquiva_t > 0.0:
		horizontal = esquiva_dir * VELOCIDADE_ESQUIVA
	elif controles_ativos:
		horizontal = direcao_movimento * velocidade_movimento() * mult_velocidade_ambiente
		if direcao_movimento.length() > 0.1:
			_virar_para(direcao_movimento, delta)
		elif alvo:
			_virar_para(alvo.global_position - global_position, delta)

	empurrao = empurrao.move_toward(Vector3.ZERO, 28.0 * delta)
	if usar_fisica:
		velocity.x = horizontal.x + empurrao.x
		velocity.z = horizontal.z + empurrao.z
		if not is_on_floor():
			velocity.y -= GRAVIDADE * delta
		move_and_slide()
	_limitar_arena()
	_animar(delta, horizontal)


func _processar_acao(delta: float) -> Vector3:
	acao["t"] = float(acao["t"]) + delta
	var t: float = acao["t"]
	var atk: Dictionary = acao.get("ataque", {})
	var resultado := Vector3.ZERO
	match str(acao["tipo"]):
		"basico":
			if not acao["feito"] and t >= 0.15:
				acao["feito"] = true
				var ponto := global_position + _frente() * 1.2 * escala + Vector3(0, 1.0 * escala, 0)
				Efeitos.explosao(get_parent(), ponto, Color(1, 1, 1), 0.6, 0.2)
				if alvo and _distancia_plana(alvo) <= ALCANCE_BASICO * maxf(escala, alvo.escala):
					Combate.aplicar_ataque(_ataque_basico_dados(), self, alvo, local)
			if t >= 0.35:
				acao = {}
		"projetil":
			if not acao["feito"] and t >= 0.2:
				acao["feito"] = true
				_disparar_projetil(atk)
			if t >= 0.4:
				acao = {}
		"area":
			if not acao["feito"] and t >= 0.5:
				acao["feito"] = true
				var raio := float(atk.get("raio", 4.5))
				Efeitos.explosao(get_parent(), global_position + Vector3(0, 0.4, 0), cor_ataque(atk), raio, 0.4)
				if alvo and _distancia_plana(alvo) <= raio + alvo.raio_acerto() * 0.5 \
						and absf(alvo.global_position.y - global_position.y) < 2.5:
					Combate.aplicar_ataque(atk, self, alvo, local)
			if t >= 0.75:
				acao = {}
		"investida":
			if t < 0.45:
				var dir: Vector3 = acao["dir"]
				resultado = dir * VELOCIDADE_INVESTIDA
				if not acao["feito"] and alvo \
						and global_position.distance_to(alvo.global_position) <= 1.9 * maxf(escala, alvo.escala):
					acao["feito"] = true
					Efeitos.explosao(get_parent(), alvo.centro(), cor_ataque(atk), 1.2)
					Combate.aplicar_ataque(atk, self, alvo, local)
			else:
				acao = {}
		"salto":
			acao["manual"] = true
			var k := clampf(t / 0.7, 0.0, 1.0)
			var inicio: Vector3 = acao["inicio"]
			var destino: Vector3 = acao["destino"]
			global_position = inicio.lerp(destino, k) + Vector3(0, sin(k * PI) * 4.5, 0)
			velocity = Vector3.ZERO
			if k >= 1.0 and not acao["feito"]:
				acao["feito"] = true
				var raio := float(atk.get("raio", 3.5))
				Efeitos.explosao(get_parent(), global_position + Vector3(0, 0.3, 0), cor_ataque(atk), raio, 0.4)
				if alvo and _distancia_plana(alvo) <= raio + alvo.raio_acerto() * 0.5:
					Combate.aplicar_ataque(atk, self, alvo, local)
			if t >= 0.9:
				acao = {}
	return resultado


# =====================================================================
# Ações públicas (chamadas pelos controladores)
# =====================================================================

func pular() -> void:
	if pode_agir() and is_on_floor():
		velocity.y = 9.0


func esquivar(dir: Vector3) -> void:
	if not pode_agir() or esquiva_recarga > 0.0:
		return
	dir.y = 0.0
	esquiva_dir = dir.normalized() if dir.length() > 0.1 else -_frente()
	esquiva_t = 0.2
	invulneravel_t = 0.3
	esquiva_recarga = recarga_esquiva()


func ataque_basico() -> void:
	if not pode_agir() or basico_recarga > 0.0:
		return
	basico_recarga = 0.45
	_encarar_alvo()
	acao = {"tipo": "basico", "t": 0.0, "feito": false}


func usar_carta(indice: int) -> bool:
	if not pode_agir() or not mao.pode_usar(indice) or alvo == null:
		return false
	var id := mao.usar(indice, mult_recarga())
	var atk: Dictionary = Dados.ataques[id]
	_encarar_alvo()
	acao = {"tipo": str(atk["arquetipo"]), "t": 0.0, "feito": false, "ataque": atk}
	var cor := cor_ataque(atk)
	match str(atk["arquetipo"]):
		"investida":
			acao["dir"] = _direcao_plana_para(alvo)
		"salto":
			var destino := alvo.global_position - _direcao_plana_para(alvo) * 1.4
			destino.y = 0.0
			var plano := Vector2(destino.x, destino.z).limit_length(RAIO_ARENA)
			destino = Vector3(plano.x, 0.0, plano.y)
			acao["inicio"] = global_position
			acao["destino"] = destino
			Efeitos.telegrafo(get_parent(), destino, float(atk.get("raio", 3.5)), cor, 0.7)
		"area":
			Efeitos.telegrafo(get_parent(), global_position, float(atk.get("raio", 4.5)), cor, 0.5)
	mostrar_texto(str(atk["nome"]), cor, 44)
	return true


func iniciar_cantico() -> void:
	if not pode_agir() or cargas_cantico <= 0 or cantico.is_empty():
		return
	cantando = true
	cantico_t = 0.0
	cantico_progresso = 0
	cantico_limite = 2.6 + atributo("mente") * 0.01
	cantico_sequencia.clear()
	for i in TAMANHO_SEQUENCIA_CANTICO:
		cantico_sequencia.append(TECLAS_CANTICO.pick_random())
	mostrar_texto(str(cantico["nome"]), Color(0.85, 0.65, 1.0), 44)
	Efeitos.telegrafo(get_parent(), global_position, 2.0, Color(0.8, 0.5, 1.0), 0.6)


## O jogador confirma cada nota da sequência do Cântico (mini-ritmo).
func cantico_tecla(acao_nome: String) -> void:
	if not cantando:
		return
	if acao_nome == cantico_sequencia[cantico_progresso]:
		cantico_progresso += 1
		if cantico_progresso >= cantico_sequencia.size():
			_concluir_cantico()
	else:
		_falhar_cantico("nota errada")


func revelar_equipamento() -> void:
	if equipamento_revelado:
		return
	equipamento_revelado = true
	if _modelo_equip == null:
		return
	_modelo_equip.visible = true
	_modelo_equip.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(_modelo_equip, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var cor := Color(str(equipamento.get("cor", "#ffffff")))
	Efeitos.explosao(get_parent(), centro(), cor, 1.8, 0.5)
	mostrar_texto(str(equipamento["nome"]), cor, 56)


# =====================================================================
# Receber efeitos
# =====================================================================

func receber_dano(valor: float, _origem: Lutador = null) -> void:
	if energia <= 0.0:
		return
	energia = maxf(0.0, energia - valor)
	_flash_t = 0.12
	if cantando:
		_falhar_cantico("interrompido")
	if energia <= 0.0:
		_derrotar()


func receber_dano_ambiente(valor: float) -> void:
	if energia <= 0.0:
		return
	energia = maxf(0.0, energia - valor)
	_dano_ambiente += valor
	if _dano_ambiente >= 3.0:
		mostrar_texto("-%d" % roundi(_dano_ambiente), Color(1.0, 0.55, 0.2), 44)
		_dano_ambiente = 0.0
		_flash_t = 0.08
	if cantando:
		_falhar_cantico("queimado")
	if energia <= 0.0:
		_derrotar()


func atordoar(duracao: float) -> void:
	if duracao <= 0.0 or energia <= 0.0:
		return
	atordoado_t = maxf(atordoado_t, duracao * (1.0 - resistencia_atordoar()))
	acao = {}
	esquiva_t = 0.0
	if cantando:
		_falhar_cantico("atordoado")
	mostrar_texto("Atordoado!", Color(1.0, 0.9, 0.3), 48)


func empurrar(vetor: Vector3) -> void:
	vetor.y = 0.0
	empurrao += vetor * clampf(1.0 - atributo("forca") * 0.005, 0.3, 1.0)


func curar(valor: float, mostrar := true) -> void:
	if energia <= 0.0:
		return
	energia = minf(energia_max, energia + valor)
	if mostrar:
		mostrar_texto("+%d" % roundi(valor), Color(0.4, 1.0, 0.5))


## Texto flutuante 3D (dano, nomes de golpes, avisos).
func mostrar_texto(texto: String, cor: Color, tamanho := 64) -> void:
	var pai := get_parent()
	if pai == null or not is_inside_tree():
		return
	var label := Label3D.new()
	label.text = texto
	label.modulate = cor
	label.font_size = tamanho
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 14
	label.outline_modulate = Color(0, 0, 0, 0.85)
	pai.add_child(label)
	_contador_texto = (_contador_texto + 1) % 3
	var altura := 2.6 * escala + _contador_texto * 0.55
	label.global_position = global_position + Vector3(randf_range(-0.4, 0.4), altura, 0)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.3, 0.9)
	tw.tween_property(label, "transparency", 1.0, 0.6).set_delay(0.35)
	tw.chain().tween_callback(label.queue_free)


# =====================================================================
# Internos
# =====================================================================

func _processar_cantico(delta: float) -> void:
	cantico_t += delta
	if not e_jogador and cantico_t >= 1.8:
		_concluir_cantico()
	elif e_jogador and cantico_t >= cantico_limite:
		_falhar_cantico("tempo esgotado")


func _concluir_cantico() -> void:
	cantando = false
	cargas_cantico -= 1
	var mult := mult_cantico()
	match str(cantico.get("tipo", "")):
		"cura":
			Efeitos.explosao(get_parent(), centro(), Color(0.4, 1.0, 0.6), 2.2, 0.5)
			curar(float(cantico["valor"]) * mult)
		"dano":
			var alcance := float(cantico.get("alcance", 12))
			Efeitos.telegrafo(get_parent(), global_position, alcance, Color(0.8, 0.4, 1.0), 0.4)
			if alvo and alvo.energia > 0.0 and _distancia_plana(alvo) <= alcance:
				var dano := float(cantico["valor"]) * mult
				Efeitos.explosao(get_parent(), alvo.centro(), Color(0.8, 0.4, 1.0), 1.8, 0.4)
				alvo.receber_dano(dano, self)
				alvo.mostrar_texto("%d" % roundi(dano), Color(0.85, 0.6, 1.0), 72)
				alvo.atordoar(float(cantico.get("atordoar", 0)))


func _falhar_cantico(motivo: String) -> void:
	if not cantando:
		return
	cantando = false
	cargas_cantico = maxi(0, cargas_cantico - 1)
	mostrar_texto("Cântico falhou (%s)" % motivo, Color(0.7, 0.7, 0.75), 44)


func _derrotar() -> void:
	acao = {}
	cantando = false
	controles_ativos = false
	mostrar_texto("Derrotado!", Color(1, 0.3, 0.3), 80)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "rotation_degrees:x", 85.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:y", 0.3, 0.6)
	derrotado.emit(self)


func _ataque_basico_dados() -> Dictionary:
	return {"nome": "Golpe", "dano_base": dano_basico(), "bonus_elemento": {}}


func _disparar_projetil(atk: Dictionary) -> void:
	var p := Projetil.new()
	p.dono = self
	p.alvo = alvo
	p.ataque = atk
	p.local = local
	p.velocidade = float(atk.get("velocidade", 22))
	p.raio = float(atk.get("tamanho", 0.35))
	p.cor = cor_ataque(atk)
	get_parent().add_child(p)
	p.global_position = centro() + _frente() * 0.9 * escala
	p.direcao = (alvo.centro() - p.global_position).normalized() if alvo else _frente()


func cor_ataque(atk: Dictionary) -> Color:
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	for el in bonus:
		if elementos.has(el):
			return Dados.cor_elemento(el)
	for el in bonus:
		return Dados.cor_elemento(el)
	return Color(0.95, 0.95, 0.95)


func _frente() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


func _direcao_plana_para(outro: Lutador) -> Vector3:
	var d := outro.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.01 else _frente()


func _distancia_plana(outro: Lutador) -> float:
	var d := outro.global_position - global_position
	d.y = 0.0
	return d.length()


func _virar_para(dir: Vector3, delta: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 1.0 - exp(-14.0 * delta))


func _encarar_alvo() -> void:
	if alvo == null:
		return
	var d := _direcao_plana_para(alvo)
	rotation.y = atan2(-d.x, -d.z)


func _limitar_arena() -> void:
	var plano := Vector2(global_position.x, global_position.z)
	if plano.length() > RAIO_ARENA:
		plano = plano.normalized() * RAIO_ARENA
		global_position.x = plano.x
		global_position.z = plano.y
	if global_position.y < -5.0:
		global_position.y = 1.0
		velocity = Vector3.ZERO


func _animar(delta: float, horizontal: Vector3) -> void:
	if _visual == null:
		return
	var mov := Vector2(horizontal.x, horizontal.z).length()
	var alvo_y := 0.0
	if forma == "mistico":
		alvo_y = 0.15 + sin(_anim_t * 2.5) * 0.12
	elif mov > 0.5 and is_on_floor():
		alvo_y = absf(sin(_anim_t * 12.0)) * 0.12
	_visual.position.y = lerpf(_visual.position.y, alvo_y, 1.0 - exp(-15.0 * delta))

	var escala_alvo := Vector3.ONE * escala
	if not acao.is_empty() and float(acao["t"]) < 0.2:
		escala_alvo = Vector3(1.12, 0.88, 1.12) * escala
	elif esquiva_t > 0.0:
		escala_alvo = Vector3(0.85, 1.1, 0.85) * escala
	_visual.scale = _visual.scale.lerp(escala_alvo, 1.0 - exp(-14.0 * delta))

	if atordoado_t > 0.0:
		_visual.rotation.z = sin(_anim_t * 25.0) * 0.12
	else:
		_visual.rotation.z = lerpf(_visual.rotation.z, 0.0, 1.0 - exp(-10.0 * delta))
	if cantando:
		_visual.rotation.y = sin(_anim_t * 5.0) * 0.5
	else:
		_visual.rotation.y = lerpf(_visual.rotation.y, 0.0, 1.0 - exp(-10.0 * delta))


func _atualizar_flash(delta: float) -> void:
	if _flash_t <= 0.0:
		return
	_flash_t = maxf(0.0, _flash_t - delta)
	var k := _flash_t / 0.12
	for i in _materiais.size():
		_materiais[i].albedo_color = _cores_base[i].lerp(Color(1, 1, 1), k)


# =====================================================================
# Modelo procedural (primitivas). Troque por um .glb quando houver arte.
# =====================================================================

func _construir_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * escala
	add_child(_visual)
	var cor := Color(str(dados_monstro.get("cor", "#888888")))
	var detalhe := Color(str(dados_monstro.get("cor_detalhe", "#ffffff")))
	match forma:
		"robusto":
			_peca(_caixa(Vector3(1.3, 1.2, 0.9)), cor, Vector3(0, 1.05, 0))
			_cabeca_pos = Vector3(0, 1.9, -0.15)
			_cabeca_raio = 0.4
			_peca(_esfera(_cabeca_raio), cor.darkened(0.1), _cabeca_pos)
			_peca(_capsula(0.3, 1.3), cor.darkened(0.2), Vector3(0.9, 1.0, -0.05))
			_peca(_capsula(0.3, 1.3), cor.darkened(0.2), Vector3(-0.9, 1.0, -0.05))
			_peca(_caixa(Vector3(0.4, 0.6, 0.45)), cor.darkened(0.3), Vector3(0.35, 0.3, 0))
			_peca(_caixa(Vector3(0.4, 0.6, 0.45)), cor.darkened(0.3), Vector3(-0.35, 0.3, 0))
			for i in 3:
				_peca(_cone(0.22, 0.5), detalhe, Vector3(0, 1.35 + i * 0.3, 0.45), Vector3(-70, 0, 0), 1.2)
			_sockets["mao_dir"] = _socket(Vector3(0.95, 0.5, -0.35))
			_sockets["mao_esq"] = _socket(Vector3(-1.0, 0.9, -0.4))
			_sockets["peito"] = _socket(Vector3(0, 1.3, -0.48))
		"mistico":
			_peca(_esfera(0.6), cor, Vector3(0, 1.3, 0))
			_cabeca_pos = Vector3(0, 1.45, -0.2)
			_cabeca_raio = 0.45
			_peca(_cone(0.45, 0.9), cor.darkened(0.2), Vector3(0, 0.55, 0), Vector3(180, 0, 0))
			var aureola := TorusMesh.new()
			aureola.inner_radius = 0.42
			aureola.outer_radius = 0.52
			_peca(aureola, detalhe, Vector3(0, 2.15, 0.05), Vector3(15, 0, 0), 2.0)
			_peca(_esfera(0.14), detalhe, Vector3(0.85, 1.5, 0), Vector3.ZERO, 1.5)
			_peca(_esfera(0.14), detalhe, Vector3(-0.85, 1.5, 0), Vector3.ZERO, 1.5)
			_sockets["mao_dir"] = _socket(Vector3(0.85, 1.2, -0.2))
			_sockets["mao_esq"] = _socket(Vector3(-0.85, 1.2, -0.2))
			_sockets["peito"] = _socket(Vector3(0, 1.0, -0.55))
		_:
			_peca(_capsula(0.4, 1.3), cor, Vector3(0, 1.0, 0), Vector3(-12, 0, 0))
			_cabeca_pos = Vector3(0, 1.8, -0.2)
			_cabeca_raio = 0.34
			_peca(_esfera(_cabeca_raio), cor, _cabeca_pos)
			_peca(_cone(0.12, 0.5), detalhe, _cabeca_pos + Vector3(0.18, 0.35, 0.05), Vector3(0, 0, -20), 1.0)
			_peca(_cone(0.12, 0.5), detalhe, _cabeca_pos + Vector3(-0.18, 0.35, 0.05), Vector3(0, 0, 20), 1.0)
			_peca(_capsula(0.12, 1.1), cor.darkened(0.15), Vector3(0, 0.9, 0.65), Vector3(60, 0, 0))
			_peca(_cone(0.14, 0.35), detalhe, Vector3(0, 1.25, 1.15), Vector3(60, 0, 0), 2.0)
			_peca(_capsula(0.13, 0.7), cor.darkened(0.25), Vector3(0.25, 0.3, 0))
			_peca(_capsula(0.13, 0.7), cor.darkened(0.25), Vector3(-0.25, 0.3, 0))
			_peca(_capsula(0.1, 0.65), cor.darkened(0.1), Vector3(0.5, 1.05, -0.15), Vector3(-30, 0, 15))
			_peca(_capsula(0.1, 0.65), cor.darkened(0.1), Vector3(-0.5, 1.05, -0.15), Vector3(-30, 0, -15))
			_sockets["mao_dir"] = _socket(Vector3(0.55, 0.8, -0.4))
			_sockets["mao_esq"] = _socket(Vector3(-0.6, 0.95, -0.45))
			_sockets["peito"] = _socket(Vector3(0, 1.25, -0.45))
	# Olhos (olhando para -Z, a frente do Godot).
	for lado in [-1.0, 1.0]:
		var olho := _cabeca_pos + Vector3(lado * _cabeca_raio * 0.42, _cabeca_raio * 0.15, -_cabeca_raio * 0.82)
		_peca(_esfera(_cabeca_raio * 0.24), Color(1, 1, 1), olho)
		_peca(_esfera(_cabeca_raio * 0.12), Color(0.05, 0.05, 0.08), olho + Vector3(0, 0, -_cabeca_raio * 0.16))
	_criar_equipamento()


func _criar_equipamento() -> void:
	if equipamento.is_empty():
		return
	var socket: Node3D = _sockets.get(str(equipamento.get("socket", "mao_dir")), _sockets["mao_dir"])
	_modelo_equip = Node3D.new()
	socket.add_child(_modelo_equip)
	var cor := Color(str(equipamento.get("cor", "#cccccc")))
	match str(equipamento.get("modelo", "")):
		"espada":
			var espada := Node3D.new()
			espada.rotation_degrees = Vector3(-65, 0, 0)
			_modelo_equip.add_child(espada)
			_peca(_caixa(Vector3(0.1, 1.3, 0.22)), cor, Vector3(0, 0.8, 0), Vector3.ZERO, 1.2, espada)
			_peca(_caixa(Vector3(0.5, 0.08, 0.14)), Color(0.85, 0.75, 0.3), Vector3(0, 0.12, 0), Vector3.ZERO, 0.0, espada)
			_peca(_caixa(Vector3(0.08, 0.3, 0.08)), Color(0.25, 0.15, 0.1), Vector3(0, -0.08, 0), Vector3.ZERO, 0.0, espada)
		"escudo":
			var disco := CylinderMesh.new()
			disco.top_radius = 0.55
			disco.bottom_radius = 0.55
			disco.height = 0.1
			_peca(disco, cor, Vector3.ZERO, Vector3(90, 0, 0), 0.3, _modelo_equip)
			_peca(_esfera(0.15), Color(0.95, 0.9, 0.8), Vector3(0, 0, -0.08), Vector3.ZERO, 0.5, _modelo_equip)
		"amuleto":
			var argola := TorusMesh.new()
			argola.inner_radius = 0.12
			argola.outer_radius = 0.2
			_peca(argola, Color(0.9, 0.8, 0.4), Vector3.ZERO, Vector3(90, 0, 0), 0.0, _modelo_equip)
			_peca(_esfera(0.13), cor, Vector3(0, 0, -0.05), Vector3.ZERO, 2.5, _modelo_equip)
	_modelo_equip.visible = false


func _peca(malha: Mesh, cor: Color, pos: Vector3, rot_graus := Vector3.ZERO, emissao := 0.0, pai: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	var mat := Efeitos.material(cor, emissao)
	mat.roughness = 0.55
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_graus
	(pai if pai != null else _visual).add_child(mi)
	_materiais.append(mat)
	_cores_base.append(mat.albedo_color)
	return mi


func _socket(pos: Vector3) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	_visual.add_child(s)
	return s


func _esfera(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return m


func _capsula(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	return m


func _caixa(tamanho: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = tamanho
	return m


func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	return m
