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
const DURACAO_INVESTIDA := 0.45
const TAMANHO_SEQUENCIA_CANTICO := 4
const TECLAS_CANTICO := ["mover_frente", "mover_esq", "mover_tras", "mover_dir"]
const DURACAO_ESCUDO := 8.0
const JANELA_COMBO := 2.5
## Monstros que voam pairam a esta altura; com Espaço sobem até ALTURA_VOO_ALTO.
const ALTURA_VOO := 1.6
const ALTURA_VOO_ALTO := 4.6
const DURACAO_SUBIDA := 2.2

# --- Dados vindos das cartas ---
var id_monstro := ""
var nome := ""
var dados_monstro: Dictionary = {}
var faccao: Dictionary = {}
var equipamento: Dictionary = {}
var cantico: Dictionary = {}
var atributos: Dictionary = {}
var elementos: Array[String] = []
var energia_max := 100.0
var energia := 100.0
var cargas_cantico := 0
var cargas_max := 0
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
var escudo := 0.0
var escudo_t := 0.0
var miragem_t := 0.0
var voa := false
## Dentro de capim alto/névoa e parado de atacar: projéteis não perseguem e a IA perde de vista.
var escondido := false
var combo := 0

var cantando := false
var cantico_t := 0.0
var cantico_limite := 3.0
var cantico_sequencia: Array[String] = []
var cantico_progresso := 0

# --- Estado das passivas ---
var _t_sem_dano := 99.0
var _t_movendo := 0.0
var _rastro_quente := false
var _refrao := false
var _refracao := false
var _impulso_t := 0.0
var _armadura := false
var _corpo_duna_espera := 0.0
var _combo_t := 0.0
var _subida_t := 0.0
var _mergulho := false

# --- Visual ---
var _visual: Node3D
var _orbita: Node3D
var _asas: Array[Node3D] = []
var _materiais: Array[ShaderMaterial] = []
var _flash_t := 0.0
var _anim_t := 0.0
var _sockets: Dictionary = {}
var _ancoras: Dictionary = {}
var _modelo_equip: Node3D
var _escudo_visual: MeshInstance3D
var _dano_ambiente := 0.0
var _contador_texto := 0


# =====================================================================
# Configuração
# =====================================================================

func configurar(monstro_id: String, equip_id: String, cantico_id: String, deck_ids: Array) -> void:
	id_monstro = monstro_id
	dados_monstro = Dados.monstros[monstro_id]
	nome = str(dados_monstro["nome"])
	faccao = Dados.faccao(str(dados_monstro.get("faccao", "")))
	equipamento = Dados.equipamentos.get(equip_id, {})
	cantico = Dados.canticos.get(cantico_id, {})
	deck = deck_ids.duplicate()
	escala = float(dados_monstro.get("escala", 1.0))
	forma = str(dados_monstro.get("forma", "agil"))
	voa = bool(dados_monstro.get("voa", false))
	var base: Dictionary = dados_monstro["atributos"]
	for chave in Dados.ATRIBUTOS:
		atributos[chave] = float(base.get(chave, 0))
	elementos.assign(dados_monstro["elementos"])
	energia_max = float(dados_monstro["energia"])
	cargas_cantico = int(dados_monstro.get("cargas_cantico", 0))
	cargas_max = cargas_cantico
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
	var v := 4.0 + atributo("agilidade") * 0.05
	if _impulso_t > 0.0:
		v *= 1.3
	return v

func recarga_esquiva() -> float:
	var r := maxf(0.6, 2.2 - atributo("agilidade") * 0.012)
	if passiva == "corrente_lateral" and _t_movendo >= 2.0:
		r *= 0.5
	return r

## Agilidade alta = golpes básicos mais rápidos.
func recarga_basico() -> float:
	return maxf(0.3, 0.62 - atributo("agilidade") * 0.0035)

func mult_recarga() -> float:
	return maxf(0.4, 1.0 - atributo("mente") * 0.004)

func mult_cantico() -> float:
	var m := 0.7 + atributo("mente") / 200.0
	if str(cantico.get("faccao", "")) == str(dados_monstro.get("faccao", "-")):
		m *= 1.15
	return m

func chance_critico() -> float:
	return atributo("animo") * 0.002

func resistencia_atordoar() -> float:
	return clampf(atributo("animo") * 0.004, 0.0, 0.6)

func dano_basico() -> float:
	return 4.0 + atributo("forca") * 0.05

func invulneravel() -> bool:
	return invulneravel_t > 0.0

## Voando alto: fora do alcance de golpes de área, investidas e golpe básico.
func no_alto() -> bool:
	return voa and global_position.y > 3.2

func centro() -> Vector3:
	return global_position + Vector3(0, 1.1 * escala, 0)

func raio_acerto() -> float:
	return 0.95 * escala

func pode_agir() -> bool:
	return controles_ativos and energia > 0.0 and atordoado_t <= 0.0 and acao.is_empty() \
		and not cantando and esquiva_t <= 0.0


# =====================================================================
# Ganchos usados pelas regras de combate (passivas)
# =====================================================================

func modificar_dano_causado(valor: float, ataque: Dictionary = {}) -> Array:
	var arquetipo := str(ataque.get("arquetipo", ""))
	if passiva == "vantagem_altura" and no_alto() and arquetipo == "projetil":
		valor *= 1.2
	if _mergulho and arquetipo in ["investida", "salto"]:
		_mergulho = false
		valor += 6.0
	var critico := randf() < chance_critico()
	if critico:
		valor *= 1.5
	if passiva == "furia" and energia < energia_max * 0.4:
		valor *= 1.3
	return [valor, critico]


## Retorna o dano que realmente chega à Energia (o escudo absorve primeiro).
func modificar_dano_recebido(valor: float, ataque: Dictionary = {}) -> float:
	valor *= 1.0 - reducao_dano
	match passiva:
		"pele_rocha":
			valor -= 2.0
		"crosta_termica":
			if _t_sem_dano >= 4.0:
				valor *= 0.65
				mostrar_texto("Crosta!", Color(1.0, 0.6, 0.3), 40)
		"nucleo_pesado":
			if is_on_floor() and str(ataque.get("arquetipo", "")) == "investida":
				valor *= 0.85
	valor = maxf(1.0, valor)
	if escudo > 0.0:
		var absorvido := minf(escudo, valor)
		escudo -= absorvido
		valor -= absorvido
		if escudo <= 0.0:
			_remover_escudo()
	return valor


## Multiplicador do dano elemental (Refrão Ígneo: +20% em ataques de Brasa após um Cântico).
func mult_elemental(ataque: Dictionary) -> float:
	var bonus: Dictionary = ataque.get("bonus_elemento", {})
	if _refrao and bonus.has("brasa") and elementos.has("brasa"):
		_refrao = false
		return 1.2
	return 1.0


## Refração Tática: o primeiro ataque elemental após um Cântico tem a condição garantida.
func condicao_garantida(ataque: Dictionary) -> bool:
	var bonus: Dictionary = ataque.get("bonus_elemento", {})
	if _refracao and not bonus.is_empty() and not ataque.get("condicao", {}).is_empty():
		_refracao = false
		return true
	return false


func registrar_acerto(ataque: Dictionary) -> void:
	combo = combo + 1 if _combo_t > 0.0 else 1
	_combo_t = JANELA_COMBO
	if passiva == "impulso_de_lasca" and str(ataque.get("arquetipo", "")) == "investida":
		_impulso_t = 2.0


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
		_animar_asas(delta, false)
		return

	_atualizar_timers(delta)
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

	# Passivas que dependem de "estar em movimento".
	if horizontal.length() > 2.0 and acao.is_empty():
		_t_movendo += delta
		if passiva == "passo_sem_rastro" and _t_movendo >= 2.0 and not _armadura:
			_armadura = true
			mostrar_texto("Passo sem Rastro", Color(1.0, 0.92, 0.6), 36)
	else:
		_t_movendo = 0.0

	empurrao = empurrao.move_toward(Vector3.ZERO, 28.0 * delta)
	if usar_fisica:
		velocity.x = horizontal.x + empurrao.x
		velocity.z = horizontal.z + empurrao.z
		_aplicar_vertical(delta)
		move_and_slide()
	_limitar_arena()
	_animar(delta, horizontal)


func _atualizar_timers(delta: float) -> void:
	atordoado_t = maxf(0.0, atordoado_t - delta)
	invulneravel_t = maxf(0.0, invulneravel_t - delta)
	esquiva_t = maxf(0.0, esquiva_t - delta)
	esquiva_recarga = maxf(0.0, esquiva_recarga - delta)
	basico_recarga = maxf(0.0, basico_recarga - delta)
	miragem_t = maxf(0.0, miragem_t - delta)
	_impulso_t = maxf(0.0, _impulso_t - delta)
	_corpo_duna_espera = maxf(0.0, _corpo_duna_espera - delta)
	if _subida_t > 0.0:
		_subida_t -= delta
		if _subida_t <= 0.0 and passiva == "mergulho_igneo":
			_mergulho = true
			mostrar_texto("Mergulho Ígneo pronto", Color(1.0, 0.6, 0.3), 36)
	_t_sem_dano += delta
	if _combo_t > 0.0:
		_combo_t -= delta
		if _combo_t <= 0.0:
			combo = 0
	if escudo_t > 0.0:
		escudo_t -= delta
		if escudo_t <= 0.0:
			_remover_escudo()


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
				if alvo and _distancia_plana(alvo) <= ALCANCE_BASICO * maxf(escala, alvo.escala) \
						and absf(alvo.global_position.y - global_position.y) < 2.2:
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
				var raio := Dados.raio_ataque(atk)
				Efeitos.explosao(get_parent(), global_position + Vector3(0, 0.4, 0), cor_ataque(atk), raio, 0.4)
				_dano_cenario(global_position, raio, float(atk.get("dano_base", 0)) * 2.0)
				if alvo and _distancia_plana(alvo) <= raio + alvo.raio_acerto() * 0.5 \
						and absf(alvo.global_position.y - global_position.y) < 2.5:
					Combate.aplicar_ataque(atk, self, alvo, local)
			if t >= 0.75:
				acao = {}
		"investida":
			if t < DURACAO_INVESTIDA:
				var dir: Vector3 = acao["dir"]
				resultado = dir * Dados.velocidade_investida(atk)
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
				var raio := Dados.raio_ataque(atk)
				Efeitos.explosao(get_parent(), global_position + Vector3(0, 0.3, 0), cor_ataque(atk), raio, 0.4)
				_dano_cenario(global_position, raio, float(atk.get("dano_base", 0)) * 2.0)
				if alvo and _distancia_plana(alvo) <= raio + alvo.raio_acerto() * 0.5 \
						and absf(alvo.global_position.y - global_position.y) < 2.5:
					Combate.aplicar_ataque(atk, self, alvo, local)
				if passiva == "duplo_horizonte":
					miragem_t = 1.5
					Efeitos.fantasma(get_parent(), inicio, Color(str(dados_monstro.get("cor_detalhe", "#ffffff"))), 2.0 * escala)
			if t >= 0.9:
				acao = {}
	return resultado


# =====================================================================
# Ações públicas (chamadas pelos controladores)
# =====================================================================

func pular() -> void:
	if not pode_agir():
		return
	if voa:
		if _subida_t <= 0.0:
			_subida_t = DURACAO_SUBIDA
	elif is_on_floor():
		velocity.y = 9.0


func _aplicar_vertical(delta: float) -> void:
	if voa:
		var altura := ALTURA_VOO_ALTO if _subida_t > 0.0 else ALTURA_VOO
		velocity.y = (altura - global_position.y) * 5.0
	elif not is_on_floor():
		velocity.y -= GRAVIDADE * delta


## Golpes de área e saltos também quebram obstáculos do cenário.
func _dano_cenario(pos: Vector3, raio: float, dano: float) -> void:
	if not is_inside_tree():
		return
	var batalha := get_tree().get_first_node_in_group("batalha")
	if batalha:
		batalha.danificar_area(pos, raio, dano)


func esquivar(dir: Vector3) -> void:
	if not pode_agir() or esquiva_recarga > 0.0:
		return
	dir.y = 0.0
	esquiva_dir = dir.normalized() if dir.length() > 0.1 else -_frente()
	esquiva_t = 0.2
	invulneravel_t = 0.4 if (passiva == "corrente_lateral" and _t_movendo >= 2.0) else 0.3
	esquiva_recarga = recarga_esquiva()
	if passiva == "rastro_quente":
		_rastro_quente = true


func ataque_basico() -> void:
	if not pode_agir() or basico_recarga > 0.0:
		return
	basico_recarga = recarga_basico()
	_encarar_alvo()
	acao = {"tipo": "basico", "t": 0.0, "feito": false}


func usar_carta(indice: int) -> bool:
	if not pode_agir() or not mao.pode_usar(indice) or alvo == null:
		return false
	var id := mao.usar(indice, mult_recarga())
	var atk: Dictionary = Dados.ataques[id]
	if _rastro_quente and str(atk["arquetipo"]) == "projetil":
		_rastro_quente = false
		mao.recarga[indice] *= 0.8
		mao.recarga_total[indice] *= 0.8
	_encarar_alvo()
	acao = {"tipo": str(atk["arquetipo"]), "t": 0.0, "feito": false, "ataque": atk}
	var cor := cor_ataque(atk)
	match str(atk["arquetipo"]):
		"investida":
			acao["dir"] = _direcao_plana_para(alvo)
		"salto":
			var destino := alvo.global_position - _direcao_plana_para(alvo) * 1.4
			var plano := Vector2(destino.x, destino.z).limit_length(RAIO_ARENA)
			destino = Vector3(plano.x, 0.0, plano.y)
			acao["inicio"] = global_position
			acao["destino"] = destino
			Efeitos.telegrafo(get_parent(), destino, Dados.raio_ataque(atk), cor, 0.7)
		"area":
			Efeitos.telegrafo(get_parent(), global_position, Dados.raio_ataque(atk), cor, 0.5)
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
	Efeitos.telegrafo(get_parent(), global_position, 2.0, _cor_cantico(), 0.6)


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
	mostrar_texto(str(equipamento["nome"]), cor, 48)


## Mostra o equipamento sem animação (retratos das cartas).
func mostrar_equipamento() -> void:
	equipamento_revelado = true
	if _modelo_equip:
		_modelo_equip.visible = true


# =====================================================================
# Receber efeitos
# =====================================================================

func receber_dano(valor: float, _origem: Lutador = null) -> void:
	if energia <= 0.0:
		return
	_t_sem_dano = 0.0
	if valor <= 0.0:
		mostrar_texto("Bloqueado", Color(0.7, 0.9, 1.0), 40)
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
		mostrar_texto("-%d" % roundi(_dano_ambiente), Color(1.0, 0.55, 0.2), 40)
		_dano_ambiente = 0.0
		_flash_t = 0.08
	if cantando:
		_falhar_cantico("queimado")
	if energia <= 0.0:
		_derrotar()


func atordoar(duracao: float) -> void:
	if duracao <= 0.0 or energia <= 0.0:
		return
	if _armadura:
		_armadura = false
		mostrar_texto("Resistiu!", Color(1.0, 0.92, 0.6), 44)
		return
	atordoado_t = maxf(atordoado_t, duracao * (1.0 - resistencia_atordoar()))
	acao = {}
	esquiva_t = 0.0
	if cantando:
		_falhar_cantico("atordoado")
	mostrar_texto("Atordoado!", Color(1.0, 0.9, 0.3), 44)


func empurrar(vetor: Vector3) -> void:
	vetor.y = 0.0
	var fator := clampf(1.0 - atributo("forca") * 0.005, 0.3, 1.0)
	if passiva == "lastro_abissal":
		fator *= 0.5
	empurrao += vetor * fator
	if passiva == "corpo_de_duna" and vetor.length() > 1.0 and _corpo_duna_espera <= 0.0:
		_corpo_duna_espera = 1.5
		mao.reduzir_maior_recarga(0.8)


func curar(valor: float, mostrar := true) -> void:
	if energia <= 0.0:
		return
	energia = minf(energia_max, energia + valor)
	if mostrar:
		mostrar_texto("+%d" % roundi(valor), Color(0.4, 1.0, 0.5))
		if passiva == "memoria_das_ondas":
			mao.reduzir_maior_recarga(0.6)


## Texto flutuante 3D (dano, nomes de golpes, avisos).
func mostrar_texto(texto: String, cor: Color, tamanho := 60) -> void:
	var pai := get_parent()
	if pai == null or not is_inside_tree():
		return
	var label := Label3D.new()
	label.text = texto
	label.modulate = cor
	label.font = Tema.fonte("numero") if texto.is_valid_int() or texto.begins_with("+") or texto.begins_with("-") else Tema.fonte("texto_negrito")
	label.font_size = tamanho
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 16
	label.outline_modulate = Color(0.05, 0.03, 0.08, 0.9)
	pai.add_child(label)
	_contador_texto = (_contador_texto + 1) % 3
	var altura := 2.6 * escala + _contador_texto * 0.55
	label.global_position = global_position + Vector3(randf_range(-0.4, 0.4), altura, 0)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "global_position:y", label.global_position.y + 1.3, 0.9)
	tw.tween_property(label, "transparency", 1.0, 0.6).set_delay(0.35)
	tw.chain().tween_callback(label.queue_free)


func cor_ataque(atk: Dictionary) -> Color:
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	for el in bonus:
		if elementos.has(el):
			return Dados.cor_elemento(el)
	for el in bonus:
		return Dados.cor_elemento(el)
	return Color(0.95, 0.95, 0.95)


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
	var cor := _cor_cantico()
	match str(cantico.get("tipo", "")):
		"cura":
			Efeitos.explosao(get_parent(), centro(), Color(0.4, 1.0, 0.6), 2.2, 0.5)
			curar(float(cantico["valor"]) * mult)
		"dano":
			var alcance := float(cantico.get("alcance", 12))
			Efeitos.telegrafo(get_parent(), global_position, alcance, cor, 0.4)
			if alvo and alvo.energia > 0.0 and _distancia_plana(alvo) <= alcance:
				var dano := alvo.modificar_dano_recebido(float(cantico["valor"]) * mult)
				Efeitos.explosao(get_parent(), alvo.centro(), cor, 1.8, 0.4)
				alvo.receber_dano(dano, self)
				alvo.mostrar_texto("%d" % roundi(dano), cor.lightened(0.4), 72)
				alvo.atordoar(float(cantico.get("atordoar", 0)))
		"escudo":
			escudo = float(cantico["valor"]) * mult
			escudo_t = DURACAO_ESCUDO
			_mostrar_escudo(cor)
			mostrar_texto("Escudo %d" % roundi(escudo), cor.lightened(0.4), 52)
	if passiva == "refrao_igneo":
		_refrao = true
	elif passiva == "refracao_tatica":
		_refracao = true


func _falhar_cantico(motivo: String) -> void:
	if not cantando:
		return
	cantando = false
	cargas_cantico = maxi(0, cargas_cantico - 1)
	mostrar_texto("Cântico falhou (%s)" % motivo, Color(0.7, 0.7, 0.75), 40)


func _cor_cantico() -> Color:
	return Color(str(Dados.faccao(str(cantico.get("faccao", ""))).get("cor", "#b07cff")))


func _mostrar_escudo(cor: Color) -> void:
	if _escudo_visual == null:
		var esfera := SphereMesh.new()
		esfera.radius = 1.0
		esfera.height = 2.0
		_escudo_visual = MeshInstance3D.new()
		_escudo_visual.mesh = esfera
		_escudo_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_escudo_visual)
	_escudo_visual.material_override = Efeitos.material(cor.lightened(0.2), 1.2, 0.22, true)
	_escudo_visual.position = Vector3(0, 1.0 * escala, 0)
	_escudo_visual.scale = Vector3.ONE * 1.35 * escala
	_escudo_visual.visible = true


func _remover_escudo() -> void:
	escudo = 0.0
	escudo_t = 0.0
	if _escudo_visual:
		_escudo_visual.visible = false


func _derrotar() -> void:
	acao = {}
	cantando = false
	controles_ativos = false
	_remover_escudo()
	mostrar_texto("Derrotado!", Color(1, 0.3, 0.3), 80)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_visual, "rotation_degrees:x", 85.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_visual, "position:y", 0.3, 0.6)
	derrotado.emit(self)


func _ataque_basico_dados() -> Dictionary:
	return {"nome": "Golpe", "arquetipo": "basico", "dano_base": dano_basico(), "bonus_elemento": {}}


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
	if _orbita:
		_orbita.rotation.y += delta * 0.8
	_animar_asas(delta, true)
	var mov := Vector2(horizontal.x, horizontal.z).length()
	var alvo_y := 0.0
	if voa:
		alvo_y = sin(_anim_t * 3.0) * 0.12
	elif forma == "mistico":
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


func _animar_asas(_delta: float, vivo: bool) -> void:
	if _asas.is_empty():
		return
	var ritmo := 14.0 if _subida_t > 0.0 else 9.0
	for asa in _asas:
		var lado := signf(asa.position.x)
		var abertura := 0.15 if not vivo else 0.35 + 0.5 * sin(_anim_t * ritmo)
		asa.rotation.z = lado * abertura


func _atualizar_flash(delta: float) -> void:
	if _flash_t <= 0.0:
		return
	_flash_t = maxf(0.0, _flash_t - delta)
	var k := _flash_t / 0.12
	for mat in _materiais:
		mat.set_shader_parameter("flash", k)


# =====================================================================
# Modelo procedural (primitivas com cel shading). Troque por um .glb quando houver arte.
# A forma define o corpo; a lista "pecas" do JSON acrescenta acessórios de silhueta.
# =====================================================================

func _construir_visual() -> void:
	_visual = Node3D.new()
	_visual.scale = Vector3.ONE * escala
	add_child(_visual)
	_orbita = Node3D.new()
	_visual.add_child(_orbita)
	var cor := Color(str(dados_monstro.get("cor", "#888888")))
	var detalhe := Color(str(dados_monstro.get("cor_detalhe", "#ffffff")))
	var escura := cor.darkened(0.3)
	var cabeca := Vector3.ZERO
	var raio_cabeca := 0.3
	match forma:
		"robusto":
			_peca(_caixa(Vector3(1.3, 1.2, 0.9)), cor, Vector3(0, 1.05, 0))
			cabeca = Vector3(0, 1.9, -0.15)
			raio_cabeca = 0.38
			_peca(_esfera(raio_cabeca), cor.darkened(0.08), cabeca)
			_peca(_capsula(0.3, 1.3), escura, Vector3(0.9, 1.0, -0.05))
			_peca(_capsula(0.3, 1.3), escura, Vector3(-0.9, 1.0, -0.05))
			_peca(_caixa(Vector3(0.42, 0.6, 0.48)), cor.darkened(0.4), Vector3(0.35, 0.3, 0))
			_peca(_caixa(Vector3(0.42, 0.6, 0.48)), cor.darkened(0.4), Vector3(-0.35, 0.3, 0))
			_ancoras = {"ombro": Vector3(0.78, 1.62, 0.0), "costas": Vector3(0, 1.3, 0.47),
				"peito": Vector3(0, 1.3, -0.47), "mao": Vector3(0.92, 0.35, -0.1), "quadril": Vector3(0, 0.75, 0.45)}
			_sockets["mao_dir"] = _socket(Vector3(0.95, 0.5, -0.35))
			_sockets["mao_esq"] = _socket(Vector3(-1.0, 0.9, -0.4))
			_sockets["peito"] = _socket(Vector3(0, 1.3, -0.5))
		"mistico":
			_peca(_esfera(0.6), cor, Vector3(0, 1.3, 0))
			cabeca = Vector3(0, 1.45, -0.2)
			raio_cabeca = 0.45
			_peca(_cone(0.45, 0.9), escura, Vector3(0, 0.55, 0), Vector3(180, 0, 0))
			_peca(_capsula(0.1, 0.7), escura, Vector3(0.62, 1.15, -0.1), Vector3(0, 0, 25))
			_peca(_capsula(0.1, 0.7), escura, Vector3(-0.62, 1.15, -0.1), Vector3(0, 0, -25))
			_ancoras = {"ombro": Vector3(0.55, 1.6, 0.0), "costas": Vector3(0, 1.35, 0.52),
				"peito": Vector3(0, 1.2, -0.56), "mao": Vector3(0.72, 0.85, -0.15), "quadril": Vector3(0, 0.8, 0.35)}
			_sockets["mao_dir"] = _socket(Vector3(0.8, 0.9, -0.25))
			_sockets["mao_esq"] = _socket(Vector3(-0.8, 0.9, -0.25))
			_sockets["peito"] = _socket(Vector3(0, 1.0, -0.6))
		_:
			_peca(_capsula(0.4, 1.3), cor, Vector3(0, 1.0, 0), Vector3(-12, 0, 0))
			cabeca = Vector3(0, 1.8, -0.2)
			raio_cabeca = 0.34
			_peca(_esfera(raio_cabeca), cor, cabeca)
			_peca(_capsula(0.13, 0.7), cor.darkened(0.25), Vector3(0.25, 0.3, 0))
			_peca(_capsula(0.13, 0.7), cor.darkened(0.25), Vector3(-0.25, 0.3, 0))
			_peca(_capsula(0.1, 0.65), cor.darkened(0.1), Vector3(0.5, 1.05, -0.15), Vector3(-30, 0, 15))
			_peca(_capsula(0.1, 0.65), cor.darkened(0.1), Vector3(-0.5, 1.05, -0.15), Vector3(-30, 0, -15))
			_ancoras = {"ombro": Vector3(0.42, 1.45, -0.05), "costas": Vector3(0, 1.2, 0.38),
				"peito": Vector3(0, 1.25, -0.42), "mao": Vector3(0.58, 0.72, -0.3), "quadril": Vector3(0, 0.8, 0.35)}
			_sockets["mao_dir"] = _socket(Vector3(0.55, 0.8, -0.4))
			_sockets["mao_esq"] = _socket(Vector3(-0.6, 0.95, -0.45))
			_sockets["peito"] = _socket(Vector3(0, 1.25, -0.45))
	_ancoras["cabeca"] = cabeca
	_ancoras["raio_cabeca"] = raio_cabeca

	var pecas: Array = dados_monstro.get("pecas", [])
	for peca in pecas:
		_acessorio(str(peca), cor, detalhe, escura)

	# Olhos grandes e brilhantes (estilo anime), olhando para -Z (a frente do Godot).
	for lado in [-1.0, 1.0]:
		var olho := cabeca + Vector3(lado * raio_cabeca * 0.42, raio_cabeca * 0.15, -raio_cabeca * 0.8)
		_peca(_esfera(raio_cabeca * 0.27), Color(1, 1, 1), olho, Vector3.ZERO, 0.0, null, false)
		_peca(_esfera(raio_cabeca * 0.15), Color(0.08, 0.05, 0.12), olho + Vector3(0, -0.01, -raio_cabeca * 0.17), Vector3.ZERO, 0.0, null, false)
		_peca(_esfera(raio_cabeca * 0.05), Color(1, 1, 1), olho + Vector3(lado * 0.02, 0.04, -raio_cabeca * 0.3), Vector3.ZERO, 2.0, null, false)
	_criar_equipamento()


## Acessórios de silhueta (lista "pecas" do monstro).
func _acessorio(tipo: String, cor: Color, detalhe: Color, escura: Color) -> void:
	var cabeca: Vector3 = _ancoras["cabeca"]
	var rc: float = _ancoras["raio_cabeca"]
	var ombro: Vector3 = _ancoras["ombro"]
	var costas: Vector3 = _ancoras["costas"]
	var peito: Vector3 = _ancoras["peito"]
	var mao: Vector3 = _ancoras["mao"]
	var quadril: Vector3 = _ancoras["quadril"]
	match tipo:
		"chifres":
			for s in [-1.0, 1.0]:
				_peca(_cone(0.12, 0.55), detalhe, cabeca + Vector3(s * rc * 0.55, rc * 0.85, 0.05), Vector3(0, 0, -s * 22))
		"chifres_frente":
			for s in [-1.0, 1.0]:
				_peca(_cone(0.1, 0.6), detalhe, cabeca + Vector3(s * rc * 0.5, rc * 0.55, -rc * 0.6), Vector3(-65, 0, -s * 12))
		"crista":
			var c := _peca(_cone(0.28, 0.8), detalhe, cabeca + Vector3(0, rc * 0.9, rc * 0.35), Vector3(40, 0, 0))
			c.scale = Vector3(0.3, 1, 1)
		"cauda":
			_peca(_capsula(0.12, 1.1), escura, quadril + Vector3(0, 0.1, 0.3), Vector3(60, 0, 0))
			_peca(_cone(0.15, 0.4), detalhe, quadril + Vector3(0, 0.45, 0.8), Vector3(60, 0, 0), 1.5)
		"cauda_cones":
			for i in 3:
				var r := 0.22 - i * 0.05
				_peca(_cone(r, 0.45), detalhe if i == 2 else escura, quadril + Vector3(0, -0.05 * i, 0.25 + 0.32 * i), Vector3(100, 0, 0), 1.2 if i == 2 else 0.0)
		"barbatanas_ombro":
			for s in [-1.0, 1.0]:
				var b := _peca(_cone(0.2, 0.75), detalhe, ombro * Vector3(s, 1, 1) + Vector3(0, 0.1, 0.15), Vector3(55, 0, -s * 20), 1.0)
				b.scale = Vector3(0.35, 1, 1)
		"barbatanas_braco":
			for s in [-1.0, 1.0]:
				var b := _peca(_cone(0.18, 0.6), detalhe, mao * Vector3(s, 1, 1) + Vector3(s * 0.12, 0.3, 0.15), Vector3(50, 0, -s * 35))
				b.scale = Vector3(0.3, 1, 1)
		"placas_costas":
			for i in 3:
				_peca(_cone(0.24 - i * 0.03, 0.5), detalhe, costas + Vector3(0, 0.32 * i - 0.25, 0.05), Vector3(70, 0, 0), 1.2)
		"punhos":
			for s in [-1.0, 1.0]:
				_peca(_caixa(Vector3(0.42, 0.42, 0.42)), escura.darkened(0.1), mao * Vector3(s, 1, 1))
		"casco":
			var casco := _peca(_esfera(0.78), escura, costas + Vector3(0, 0.05, 0.15))
			casco.scale = Vector3(1.0, 0.85, 0.5)
			_peca(_torus(0.62, 0.72), detalhe, costas + Vector3(0, 0.05, 0.32), Vector3(90, 0, 0), 1.0)
		"ombreiras_cone":
			for s in [-1.0, 1.0]:
				_peca(_cone(0.35, 0.55), detalhe, ombro * Vector3(s, 1, 1) + Vector3(0, 0.12, 0), Vector3(0, 0, -s * 55))
		"ombreiras_bloco":
			for s in [-1.0, 1.0]:
				_peca(_caixa(Vector3(0.6, 0.42, 0.65)), escura, ombro * Vector3(s, 1, 1) + Vector3(s * 0.05, 0.12, 0))
		"ombreiras_esfera":
			for s in [-1.0, 1.0]:
				_peca(_esfera(0.34), detalhe.darkened(0.2), ombro * Vector3(s, 1, 1) + Vector3(0, 0.08, 0))
		"ombreiras_inclinadas":
			for s in [-1.0, 1.0]:
				_peca(_caixa(Vector3(0.5, 0.12, 0.42)), detalhe, ombro * Vector3(s, 1, 1) + Vector3(s * 0.08, 0.12, 0.05), Vector3(0, 0, -s * 28))
		"nucleo":
			_peca(_esfera(0.17), detalhe, peito + Vector3(0, 0, -0.04), Vector3.ZERO, 1.2, null, false)
		"ornamentos":
			for i in 3:
				var ang := TAU * i / 3.0
				var pos := Vector3(cos(ang) * 0.95, 1.55 + 0.2 * sin(ang * 2.0), sin(ang) * 0.95)
				_peca(_esfera(0.12), detalhe, pos, Vector3.ZERO, 0.5, _orbita)
				_peca(_cone(0.08, 0.25), detalhe, pos + Vector3(0, 0.22, 0), Vector3.ZERO, 0.5, _orbita)
		"nos_perola":
			for p in [Vector3(0, 0.2, 0), Vector3(0.22, 0.0, 0.02), Vector3(-0.22, 0.0, 0.02), Vector3(0.14, -0.22, 0.04), Vector3(-0.14, -0.22, 0.04)]:
				_peca(_esfera(0.08), detalhe, peito + p, Vector3.ZERO, 0.8, null, false)
		"cristais":
			for i in 4:
				var ang := TAU * i / 4.0 + PI / 4.0
				_peca(_cone(0.11, 0.5), detalhe, Vector3(cos(ang) * 0.85, 1.75, sin(ang) * 0.85), Vector3(0, 0, 0), 0.6, _orbita)
		"laminas_laterais":
			for s in [-1.0, 1.0]:
				var l := _peca(_cone(0.22, 1.0), detalhe, Vector3(s * 0.8, 1.25, 0.1), Vector3(0, 0, -s * 70), 1.2)
				l.scale = Vector3(1, 1, 0.3)
		"aureola":
			_peca(_torus(0.4, 0.5), detalhe, cabeca + Vector3(0, rc + 0.35, 0.1), Vector3(15, 0, 0), 0.8, null, false)
		"manto":
			_peca(_cone(0.75, 1.05), escura.darkened(0.15), Vector3(0, 0.75, 0.05), Vector3(180, 0, 0))
		"asas":
			for s in [-1.0, 1.0]:
				var pivo := Node3D.new()
				pivo.position = costas + Vector3(s * 0.18, 0.25, 0.05)
				_visual.add_child(pivo)
				_asas.append(pivo)
				var asa := _peca(_cone(0.5, 1.5), detalhe, Vector3(s * 0.75, 0.05, 0.1), Vector3(0, 0, -s * 90), 0.4, pivo)
				asa.scale = Vector3(1, 1, 0.14)
				var pena := _peca(_cone(0.32, 1.1), cor, Vector3(s * 0.6, -0.25, 0.14), Vector3(0, 0, -s * 115), 0.0, pivo)
				pena.scale = Vector3(1, 1, 0.12)


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
			_peca(_caixa(Vector3(0.1, 1.3, 0.22)), cor, Vector3(0, 0.8, 0), Vector3.ZERO, 1.0, espada)
			_peca(_caixa(Vector3(0.5, 0.08, 0.14)), Color(0.85, 0.75, 0.3), Vector3(0, 0.12, 0), Vector3.ZERO, 0.0, espada)
			_peca(_caixa(Vector3(0.08, 0.3, 0.08)), Color(0.25, 0.15, 0.1), Vector3(0, -0.08, 0), Vector3.ZERO, 0.0, espada)
		"escudo":
			var disco := CylinderMesh.new()
			disco.top_radius = 0.55
			disco.bottom_radius = 0.55
			disco.height = 0.1
			_peca(disco, cor, Vector3.ZERO, Vector3(90, 0, 0), 0.2, _modelo_equip)
			_peca(_esfera(0.15), Color(0.95, 0.9, 0.8), Vector3(0, 0, -0.08), Vector3.ZERO, 0.5, _modelo_equip)
		"amuleto":
			_peca(_torus(0.12, 0.2), Color(0.9, 0.8, 0.4), Vector3.ZERO, Vector3(90, 0, 0), 0.0, _modelo_equip)
			_peca(_esfera(0.13), cor, Vector3(0, 0, -0.05), Vector3.ZERO, 2.5, _modelo_equip, false)
	_modelo_equip.visible = false


func _peca(malha: Mesh, cor: Color, pos: Vector3, rot_graus := Vector3.ZERO, emissao := 0.0, pai: Node3D = null, contorno := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	var mat := Efeitos.material_toon(cor, emissao, contorno)
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_graus
	(pai if pai != null else _visual).add_child(mi)
	_materiais.append(mat)
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


func _torus(interno: float, externo: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = interno
	m.outer_radius = externo
	return m
