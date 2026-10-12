class_name Combate
extends RefCounted
## Regras de dano herdadas do card game:
##   dano = base + bônus de cada elemento que o atacante possui (+ bônus do Local)
##   Desafio: atributo do atacante >= atributo do alvo + margem
##   Teste:   atributo do atacante >= valor
##   Falha:   atributo do alvo < valor

const NOMES_CONDICAO := {"desafio": "Desafio", "teste": "Teste", "falha": "Falha"}
const EMPURRAO_BASE := 3.0


static func avaliar_condicao(cond: Dictionary, atacante: Lutador, alvo: Lutador) -> bool:
	if cond.is_empty() or atacante == null or alvo == null:
		return false
	var attr := str(cond.get("atributo", ""))
	match str(cond.get("tipo", "")):
		"desafio":
			return atacante.atributo(attr) >= alvo.atributo(attr) + float(cond.get("margem", 1))
		"teste":
			return atacante.atributo(attr) >= float(cond.get("valor", 0))
		"falha":
			return alvo.atributo(attr) < float(cond.get("valor", 0))
	return false


static func descrever_condicao(cond: Dictionary) -> String:
	if cond.is_empty():
		return ""
	var attr: String = Dados.ATRIBUTOS.get(str(cond["atributo"]), str(cond["atributo"]))
	var texto := ""
	match str(cond["tipo"]):
		"desafio":
			var margem := int(cond.get("margem", 1))
			texto = "Desafio de %s" % attr
			if margem > 1:
				texto += " (+%d)" % margem
		"teste":
			texto = "Teste: %s >= %d" % [attr, int(cond["valor"])]
		"falha":
			texto = "Falha: %s do alvo < %d" % [attr, int(cond["valor"])]
	return texto + " -> " + descrever_efeito(cond.get("efeito", {}))


static func descrever_efeito(efeito: Dictionary) -> String:
	match str(efeito.get("tipo", "")):
		"dano_extra":
			return "+%d de dano" % int(efeito["valor"])
		"atordoar":
			return "atordoa %.1fs" % float(efeito["valor"])
		"empurrar":
			return "arremessa o alvo"
		"cura":
			return "cura %d" % int(efeito["valor"])
		"roubar_carga":
			return "alvo perde 1 carga de Cântico"
	return ""


static func dano_elemental(ataque: Dictionary, atacante: Lutador, local: Dictionary) -> float:
	var total := 0.0
	var bonus: Dictionary = ataque.get("bonus_elemento", {})
	for el in bonus:
		if not atacante.elementos.has(el):
			continue
		total += float(bonus[el])
		for mod in local.get("modificadores", []):
			if str(mod.get("elemento", "")) == el:
				total += float(mod.get("dano_bonus", 0))
	return total


static func aplicar_ataque(ataque: Dictionary, atacante: Lutador, alvo: Lutador, local: Dictionary) -> void:
	if not is_instance_valid(atacante) or not is_instance_valid(alvo) or alvo.energia <= 0.0:
		return
	if alvo.invulneravel():
		alvo.mostrar_texto("Esquivou!", Color(0.85, 0.85, 0.85))
		return

	var dano := float(ataque.get("dano_base", 0)) + dano_elemental(ataque, atacante, local)
	var cond: Dictionary = ataque.get("condicao", {})
	var efeito: Dictionary = {}
	if avaliar_condicao(cond, atacante, alvo):
		efeito = cond.get("efeito", {})
		atacante.mostrar_texto(str(NOMES_CONDICAO.get(str(cond["tipo"]), "")) + "!", Color(0.5, 1.0, 0.5), 48)
		if str(efeito.get("tipo", "")) == "dano_extra":
			dano += float(efeito.get("valor", 0))

	var resultado := atacante.modificar_dano_causado(dano)
	var critico: bool = resultado[1]
	var final := alvo.modificar_dano_recebido(float(resultado[0]))
	alvo.receber_dano(final, atacante)
	if critico:
		alvo.mostrar_texto("CRÍTICO %d" % roundi(final), Color(1.0, 0.35, 0.3), 80)
	else:
		alvo.mostrar_texto("%d" % roundi(final), Color(1.0, 0.95, 0.9))

	var dir := alvo.global_position - atacante.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.ZERO
	alvo.empurrar(dir * EMPURRAO_BASE)

	match str(efeito.get("tipo", "")):
		"atordoar":
			alvo.atordoar(float(efeito["valor"]))
		"empurrar":
			alvo.empurrar(dir * float(efeito["valor"]))
		"cura":
			atacante.curar(float(efeito["valor"]))
		"roubar_carga":
			if alvo.cargas_cantico > 0:
				alvo.cargas_cantico -= 1
				alvo.mostrar_texto("-1 carga", Color(0.8, 0.5, 1.0))
