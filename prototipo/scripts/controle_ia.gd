class_name ControleIA
extends Node
## IA do oponente.
## - Mantém a distância ideal para as cartas da mão. Se o monstro dela é mais rápido
##   que o alvo, faz "kiting": ataca de longe, recua quando o inimigo encosta,
##   esquiva investidas e não se deixa encurralar na borda.
## - Usa o cenário: espera as cartas recarregarem atrás de obstáculos ou no capim alto,
##   e não gasta projétil se há um pilar no caminho.
## - Voadores sobem quando o inimigo encosta; contra quem está no alto, só projéteis.
## - Quando o alvo se esconde, vai até a última posição em que o viu.
## - Dificuldade (`dificuldade`: "facil", "normal" ou "dificil"). A Batalha pode preencher;
##   se não preencher, a IA lê config["dificuldade"] da batalha (padrão "facil" no modo fácil,
##   "normal" fora dele). Nas simulações IA x IA é sempre "normal", para o balanceamento.
##     facil:   pensa devagar, erra esquivas, não faz kiting, usa poucas cartas e
##              "comemora" parada por 1 s depois de acertar.
##     normal:  comportamento padrão.
##     dificil: pensa rápido, esquiva quase sempre, encadeia cartas e faz kiting cheio.
## - `passivo` (tutorial): só anda devagar perto do jogador, sem atacar nem esquivar.

const ALCANCES := {"projetil": 15.0, "salto": 11.0}
## Diferença de Agilidade para a IA se considerar "mais rápida" (e jogar à distância).
const MARGEM_RAPIDO := 12.0
const DISTANCIA_KITING := 10.0
const DIFICULDADES := ["facil", "normal", "dificil"]

var lutador: Lutador
var batalha  # Batalha (sem tipo para evitar dependência cíclica entre scripts)
var dificuldade := ""
var passivo := false

var _pensar_t := 0.6
var _lateral := 1.0
var _lateral_t := 0.0
var _reacao_t := 0.0
var _ultima_vista := Vector3.INF
var _cobertura := Vector3.INF
var _cobertura_t := 0.0
var _pausa_t := 0.0
var _combo_visto := 0
var _encadear := false


func _physics_process(delta: float) -> void:
	if lutador == null:
		return
	if dificuldade == "":
		_resolver_dificuldade()
	var alvo := lutador.alvo
	if not lutador.controles_ativos or alvo == null or lutador.energia <= 0.0 or alvo.energia <= 0.0:
		lutador.direcao_movimento = Vector3.ZERO
		return
	if passivo:
		lutador.direcao_movimento = _desviar_lava(_movimento_passivo(alvo, delta))
		return

	# Fácil: depois de acertar, fica parada 1 s "comemorando" (dá tempo de a criança reagir).
	if lutador.combo > _combo_visto and _facil():
		_pausa_t = 1.0
	_combo_visto = lutador.combo
	_pausa_t = maxf(0.0, _pausa_t - delta)
	if _pausa_t > 0.0:
		lutador.direcao_movimento = Vector3.ZERO
		return

	var para_alvo := alvo.global_position - lutador.global_position
	para_alvo.y = 0.0
	var dist := para_alvo.length()
	var ve_alvo := not alvo.escondido or dist < 4.5
	if ve_alvo:
		_ultima_vista = alvo.global_position
	var foco := _ultima_vista if _ultima_vista != Vector3.INF else alvo.global_position
	var para_foco := foco - lutador.global_position
	para_foco.y = 0.0
	var dist_foco := para_foco.length()
	var dir := para_foco / dist_foco if dist_foco > 0.01 else Vector3.ZERO

	_reacao_t = maxf(0.0, _reacao_t - delta)
	_cobertura_t = maxf(0.0, _cobertura_t - delta)
	_lateral_t -= delta
	if _lateral_t <= 0.0:
		_lateral_t = randf_range(1.2, 2.8)
		_lateral = [-1.0, 1.0].pick_random() if _rapido() else [-1.0, 0.0, 1.0].pick_random()

	_checar_esquiva(dist)
	_pensar_t -= delta
	if _pensar_t <= 0.0 and lutador.pode_agir():
		_pensar_t = _tempo_pensar()
		if ve_alvo:
			_decidir(dist)

	var mov := _movimento(dist, dist_foco, dir, ve_alvo)
	mov = _evitar_borda(mov)
	mov = _desviar_lava(mov)
	lutador.direcao_movimento = mov.normalized() if mov.length() > 0.1 else Vector3.ZERO


# ---------------------------------------------------------------------
# Dificuldade
# ---------------------------------------------------------------------

func _resolver_dificuldade() -> void:
	var padrao := "facil" if Jogo.facil() else "normal"
	if batalha:
		if bool(batalha.get("simulacao")):
			padrao = "normal"
		else:
			var cfg = batalha.get("config")
			if typeof(cfg) == TYPE_DICTIONARY:
				padrao = str(cfg.get("dificuldade", padrao))
	dificuldade = padrao if padrao in DIFICULDADES else "normal"


func _facil() -> bool:
	return dificuldade == "facil"


func _dificil() -> bool:
	return dificuldade == "dificil"


## Intervalo entre decisões: a IA fácil "pensa" devagar; a difícil, quase sem pausa.
func _tempo_pensar() -> float:
	if _facil():
		return randf_range(1.2, 2.2)
	if _dificil():
		return randf_range(0.3, 0.6) * (0.5 if _encadear else 1.0)
	return randf_range(0.6, 1.3) * (0.85 if _rapido() else 1.0)


func _chance_esquiva() -> float:
	if _facil():
		return 0.25
	if _dificil():
		return 0.8
	return clampf(lutador.atributo("agilidade") / 180.0, 0.15, 0.55)


# ---------------------------------------------------------------------
# Movimento
# ---------------------------------------------------------------------

func _movimento(dist: float, dist_foco: float, dir: Vector3, ve_alvo: bool) -> Vector3:
	var alvo := lutador.alvo
	var lateral := Vector3(-dir.z, 0.0, dir.x)
	if not ve_alvo:
		# Procura o alvo escondido: vai até onde o viu por último e dá uma volta por ali.
		if dist_foco < 1.5:
			_ultima_vista = Vector3.INF
			return lateral * _lateral
		return dir
	if alvo.cantando:
		return dir

	# Esperando cartas recarregarem: busca cobertura (monstros rápidos ou feridos).
	if _cartas_prontas() == 0 and batalha and dist > 5.0 and not _facil() \
			and (_rapido() or lutador.energia < lutador.energia_max * 0.5):
		if _cobertura_t <= 0.0:
			_cobertura_t = 1.0
			_cobertura = batalha.ponto_cobertura(lutador.global_position, alvo.global_position)
			if _cobertura == Vector3.INF:
				_cobertura = batalha.esconderijo_proximo(lutador.global_position)
		if _cobertura != Vector3.INF:
			var ate := _cobertura - lutador.global_position
			ate.y = 0.0
			return ate.normalized() if ate.length() > 0.8 else Vector3.ZERO

	var alcance := _alcance_desejado()
	var mov := Vector3.ZERO
	if dist > alcance + 0.8:
		mov += dir
	elif dist < alcance - 2.0:
		mov -= dir * (1.4 if _rapido() else 1.0)
	mov += lateral * _lateral * (0.9 if _rapido() else 0.6)
	return mov


## Tutorial: fica a uns metros do jogador andando devagar, sem atacar nem esquivar.
func _movimento_passivo(alvo: Lutador, delta: float) -> Vector3:
	var para_alvo := alvo.global_position - lutador.global_position
	para_alvo.y = 0.0
	var dist := para_alvo.length()
	var dir := para_alvo / dist if dist > 0.01 else Vector3.ZERO
	_lateral_t -= delta
	if _lateral_t <= 0.0:
		_lateral_t = randf_range(2.0, 4.0)
		_lateral = [-1.0, 1.0].pick_random()
	var mov := Vector3.ZERO
	if dist > 7.0:
		mov = dir
	elif dist > 2.5:
		mov = Vector3(-dir.z, 0.0, dir.x) * _lateral * 0.6
	return _evitar_borda(mov).limit_length(1.0) * 0.35


## Perto da borda da arena, puxa para dentro e para o lado (para não ficar encurralado).
func _evitar_borda(mov: Vector3) -> Vector3:
	var plano := Vector2(lutador.global_position.x, lutador.global_position.z)
	var limite := Lutador.RAIO_ARENA - 4.0
	if plano.length() <= limite:
		return mov
	var peso := (plano.length() - limite) / 4.0
	var para_centro := -Vector3(plano.x, 0.0, plano.y).normalized()
	var tangente := Vector3(-para_centro.z, 0.0, para_centro.x) * _lateral
	return mov + (para_centro * 1.5 + tangente) * peso


## Não entra na lava: se o próximo passo cai nela, vira 90 graus.
func _desviar_lava(mov: Vector3) -> Vector3:
	if batalha and mov.length() > 0.1 and not lutador.voa:
		var futuro := lutador.global_position + mov.normalized() * 1.8
		if batalha.perigo_em(futuro) == "lava":
			return Vector3(-mov.z, 0.0, mov.x)
	return mov


func _alcance_desejado() -> float:
	var melhor := -1.0
	var custo_melhor := -1.0
	for i in MaoCartas.TAMANHO:
		if not lutador.mao.pode_usar(i):
			continue
		var atk: Dictionary = Dados.ataques[lutador.mao.slots[i]]
		if not _util_contra_alvo(atk):
			continue
		if float(atk["custo"]) > custo_melhor:
			custo_melhor = float(atk["custo"])
			melhor = _alcance(atk)
	if melhor < 0.0:
		# Sem cartas: o rápido se afasta (kiting); os outros vão para o corpo a corpo.
		return DISTANCIA_KITING if _rapido() else Lutador.ALCANCE_BASICO * 0.8
	return melhor * 0.8


# ---------------------------------------------------------------------
# Decisão de ataque
# ---------------------------------------------------------------------

func _decidir(dist: float) -> void:
	var alvo := lutador.alvo
	# Voador sobe quando o inimigo encosta (fica fora de golpes de área e investidas).
	if lutador.voa and dist < 4.5 and not lutador.no_alto() and randf() < (0.3 if _facil() else 0.6):
		lutador.pular()
		return
	if lutador.cargas_cantico > 0 and not lutador.cantico.is_empty() and (not _facil() or randf() < 0.5):
		var tipo_cantico := str(lutador.cantico.get("tipo", ""))
		if tipo_cantico == "cura" and lutador.energia < lutador.energia_max * 0.45 and dist > 7.0:
			lutador.iniciar_cantico()
			return
		if tipo_cantico == "dano" and dist < float(lutador.cantico.get("alcance", 12)) * 0.8 and randf() < 0.25:
			lutador.iniciar_cantico()
			return
		if tipo_cantico == "escudo" and lutador.escudo <= 0.0 and lutador.energia < lutador.energia_max * 0.75 \
				and dist > 5.0 and randf() < 0.35:
			lutador.iniciar_cantico()
			return

	# Fácil: metade das vezes a IA "esquece" as cartas e só dá o golpe básico.
	var usa_cartas := not _facil() or randf() < 0.5
	var melhor := -1
	var melhor_nota := -INF
	var cartas := MaoCartas.TAMANHO if usa_cartas else 0
	for i in cartas:
		if not lutador.mao.pode_usar(i):
			continue
		var atk: Dictionary = Dados.ataques[lutador.mao.slots[i]]
		if dist > _alcance(atk) or not _util_contra_alvo(atk):
			continue
		var tipo := str(atk["arquetipo"])
		# Não atira em pilar: precisa de linha de visão.
		if tipo == "projetil" and batalha and not batalha.linha_livre(lutador.centro(), alvo.centro()):
			continue
		var nota := float(atk["custo"]) + randf() * 2.0
		if Combate.avaliar_condicao(atk.get("condicao", {}), lutador, alvo):
			nota += 3.0
		if alvo.cantando:
			nota += 4.0
		if _rapido() and tipo == "projetil":
			nota += 1.5
		if _dificil():
			# Difícil: encadeia cartas em cima de alvo atordoado ou de um combo em andamento.
			if alvo.atordoado_t > 0.0 and tipo in ["area", "salto", "investida"]:
				nota += 3.0
			if lutador.combo > 0:
				nota += 2.0
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	_encadear = false
	if melhor >= 0:
		lutador.usar_carta(melhor)
		_encadear = _dificil()
	elif dist <= Lutador.ALCANCE_BASICO * maxf(lutador.escala, alvo.escala) and not alvo.no_alto():
		lutador.ataque_basico()


## Contra um alvo voando alto, só projéteis alcançam.
func _util_contra_alvo(atk: Dictionary) -> bool:
	return not lutador.alvo.no_alto() or str(atk["arquetipo"]) == "projetil"


func _alcance(atk: Dictionary) -> float:
	var tipo := str(atk["arquetipo"])
	match tipo:
		"area":
			return Dados.raio_ataque(atk) * 0.85
		"investida":
			return Dados.velocidade_investida(atk) * Lutador.DURACAO_INVESTIDA + 0.5
	return float(ALCANCES.get(tipo, 3.0))


func _cartas_prontas() -> int:
	var total := 0
	for i in MaoCartas.TAMANHO:
		if lutador.mao.pode_usar(i) and _util_contra_alvo(Dados.ataques[lutador.mao.slots[i]]):
			total += 1
	return total


## "Mais rápida" que o alvo: joga à distância. A fácil nunca faz kiting; a difícil, com pouca margem.
func _rapido() -> bool:
	if _facil():
		return false
	var margem := 4.0 if _dificil() else MARGEM_RAPIDO
	return lutador.atributo("agilidade") >= lutador.alvo.atributo("agilidade") + margem


# ---------------------------------------------------------------------
# Esquiva
# ---------------------------------------------------------------------

func _checar_esquiva(dist: float) -> void:
	if not lutador.pode_agir() or lutador.esquiva_recarga > 0.0:
		return
	var chance := _chance_esquiva()
	if not _facil() and not _dificil():
		chance *= 1.3 if _rapido() else 0.8
	# Investidas, saltos e golpes corpo a corpo vindo na sua direção.
	var alvo := lutador.alvo
	var golpe := str(alvo.acao.get("tipo", ""))
	if _reacao_t <= 0.0 and golpe in ["investida", "salto", "basico"] and dist < 6.0:
		_reacao_t = 1.2 if _facil() else (0.5 if _dificil() else 0.8)
		if randf() < chance:
			var para_alvo := (alvo.global_position - lutador.global_position).normalized()
			var lado := Vector3(-para_alvo.z, 0.0, para_alvo.x) * _lateral
			lutador.esquivar(lado - para_alvo * 0.5)
			return
	# Projéteis.
	var distancia_vista := 8.0 if _dificil() else 6.0
	for no in get_tree().get_nodes_in_group("projeteis"):
		var proj := no as Projetil
		if proj == null or proj.alvo != lutador or proj.has_meta("ia_viu"):
			continue
		if proj.global_position.distance_to(lutador.centro()) < distancia_vista:
			proj.set_meta("ia_viu", true)
			if randf() < chance:
				var lado := proj.direcao.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				lutador.esquivar(lado)
				return
