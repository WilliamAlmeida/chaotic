class_name ControleIA
extends Node
## IA simples: mantém a distância ideal para as cartas que tem na mão,
## prefere cartas cuja condição (Desafio/Teste/Falha) está ativa,
## tenta esquivar de projéteis e interrompe o Cântico do oponente.

const ALCANCES := {"projetil": 15.0, "investida": 8.0, "salto": 11.0}

var lutador: Lutador
var batalha  # Batalha (sem tipo para evitar dependência cíclica entre scripts)

var _pensar_t := 0.6
var _lateral := 1.0
var _lateral_t := 0.0


func _physics_process(delta: float) -> void:
	if lutador == null:
		return
	var alvo := lutador.alvo
	if not lutador.controles_ativos or alvo == null or lutador.energia <= 0.0 or alvo.energia <= 0.0:
		lutador.direcao_movimento = Vector3.ZERO
		return

	var para_alvo := alvo.global_position - lutador.global_position
	para_alvo.y = 0.0
	var dist := para_alvo.length()
	var dir := para_alvo / dist if dist > 0.01 else Vector3.ZERO

	_checar_esquiva()
	_lateral_t -= delta
	if _lateral_t <= 0.0:
		_lateral_t = randf_range(1.2, 2.8)
		_lateral = [-1.0, 0.0, 1.0].pick_random()
	_pensar_t -= delta
	if _pensar_t <= 0.0 and lutador.pode_agir():
		_pensar_t = randf_range(0.6, 1.3)
		_decidir(dist)

	var alcance := 1.5 if alvo.cantando else _alcance_desejado()
	var mov := Vector3.ZERO
	if dist > alcance + 0.8:
		mov += dir
	elif dist < alcance - 2.0:
		mov -= dir
	mov += Vector3(-dir.z, 0.0, dir.x) * _lateral * 0.7
	if batalha and mov.length() > 0.1:
		var futuro := lutador.global_position + mov.normalized() * 1.8
		if batalha.perigo_em(futuro) == "lava":
			mov = Vector3(-mov.z, 0.0, mov.x)
	lutador.direcao_movimento = mov.normalized() if mov.length() > 0.1 else Vector3.ZERO


func _decidir(dist: float) -> void:
	var alvo := lutador.alvo
	if lutador.cargas_cantico > 0 and not lutador.cantico.is_empty():
		var e_cura := str(lutador.cantico.get("tipo", "")) == "cura"
		if e_cura and lutador.energia < lutador.energia_max * 0.45 and dist > 7.0:
			lutador.iniciar_cantico()
			return
		if not e_cura and dist < float(lutador.cantico.get("alcance", 12)) * 0.8 and randf() < 0.25:
			lutador.iniciar_cantico()
			return

	var melhor := -1
	var melhor_nota := -INF
	for i in MaoCartas.TAMANHO:
		if not lutador.mao.pode_usar(i):
			continue
		var atk: Dictionary = Dados.ataques[lutador.mao.slots[i]]
		if dist > _alcance(atk):
			continue
		var nota := float(atk["custo"]) + randf() * 2.0
		if Combate.avaliar_condicao(atk.get("condicao", {}), lutador, alvo):
			nota += 3.0
		if alvo.cantando:
			nota += 4.0
		if nota > melhor_nota:
			melhor_nota = nota
			melhor = i
	if melhor >= 0:
		lutador.usar_carta(melhor)
	elif dist <= Lutador.ALCANCE_BASICO * maxf(lutador.escala, alvo.escala):
		lutador.ataque_basico()


func _alcance(atk: Dictionary) -> float:
	var tipo := str(atk["arquetipo"])
	if tipo == "area":
		return float(atk.get("raio", 4.5)) * 0.85
	return float(ALCANCES.get(tipo, 3.0))


func _alcance_desejado() -> float:
	var melhor := -1.0
	var custo_melhor := -1.0
	for i in MaoCartas.TAMANHO:
		if lutador.mao.pode_usar(i):
			var atk: Dictionary = Dados.ataques[lutador.mao.slots[i]]
			if float(atk["custo"]) > custo_melhor:
				custo_melhor = float(atk["custo"])
				melhor = _alcance(atk)
	if melhor < 0.0:
		return Lutador.ALCANCE_BASICO * 0.8
	return melhor * 0.8


func _checar_esquiva() -> void:
	if not lutador.pode_agir() or lutador.esquiva_recarga > 0.0:
		return
	for no in get_tree().get_nodes_in_group("projeteis"):
		var proj := no as Projetil
		if proj == null or proj.alvo != lutador or proj.has_meta("ia_viu"):
			continue
		if proj.global_position.distance_to(lutador.centro()) < 6.0:
			proj.set_meta("ia_viu", true)
			if randf() < 0.35:
				var lado := proj.direcao.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
				lutador.esquivar(lado)
				return
