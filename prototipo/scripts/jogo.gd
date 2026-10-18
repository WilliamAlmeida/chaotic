extends Node
## Autoload "Jogo": configurações do jogador, progresso, campanha e salvamento (user://salvo.json).
##
## Tudo que precisa sobreviver entre telas ou entre sessões mora aqui:
##   - config:    modo fácil (assistências para crianças), toque, volumes
##   - progresso: campanha, monstros desbloqueados, estrelas por etapa, vitórias
##   - campanha:  os circuitos e etapas lidos de res://data/campanha.json
## As telas chamam Jogo.salvar() depois de alterar algo.

const ARQUIVO := "user://salvo.json"
const ARQUIVO_CAMPANHA := "res://data/campanha.json"

## Monstros disponíveis numa partida nova (os outros são desbloqueados na campanha).
const MONSTROS_INICIAIS := ["tigrana", "velamar", "talhuno", "sirocal"]

## Estrelas por Energia restante na vitória (fração da Energia máxima).
const ESTRELAS_3 := 0.6
const ESTRELAS_2 := 0.3

var config: Dictionary = {
	"modo_facil": true,       # assistências: mira automática, IA mais branda, dicas grandes
	"toque": "auto",          # "auto" (detecta tela de toque), "sim" ou "nao"
	"volume_efeitos": 0.8,
	"volume_musica": 0.6,
	"vibracao": true,
	"nome": "Duelista",
	"loadout_avancado": false, # true: a tela de loadout abre no modo completo (deck à mão)
}
var progresso: Dictionary = {
	"circuito": 0,            # índice do circuito atual da campanha
	"etapa": 0,               # próxima etapa a jogar dentro do circuito
	"monstros": [],           # ids desbloqueados (além dos iniciais)
	"estrelas": {},           # "circuito/etapa" -> 1..3
	"vitorias": 0,
	"partidas": 0,
	"tutorial_feito": false,
	"titulos": [],            # títulos simbólicos ganhos na campanha ("Guardião da Rede")
	"ultimo_loadout": {},     # última escolha do jogador (monstro, equipamento, cântico, deck)
}

## Campanha: {"mentor": {...}, "coro": {...}, "circuitos": [ {nome, faccao, etapas: [...]}, ... ]}
var campanha: Dictionary = {"circuitos": []}


func _ready() -> void:
	_carregar_campanha()
	carregar()


func facil() -> bool:
	return bool(config.get("modo_facil", true))


## Controles de toque: ligados em telas de toque ou quando o jogador forçar nas opções.
func toque_ativo() -> bool:
	match str(config.get("toque", "auto")):
		"sim":
			return true
		"nao":
			return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")


# ---------------------------------------------------------------------
# Monstros
# ---------------------------------------------------------------------

func monstros_desbloqueados() -> Array:
	var lista: Array = MONSTROS_INICIAIS.duplicate()
	for id in progresso.get("monstros", []):
		if not lista.has(id) and Dados.monstros.has(id):
			lista.append(id)
	return lista


func monstro_desbloqueado(id: String) -> bool:
	return monstros_desbloqueados().has(id)


## Desbloqueia e devolve true se era novo.
func desbloquear_monstro(id: String) -> bool:
	if monstro_desbloqueado(id) or not Dados.monstros.has(id):
		return false
	progresso["monstros"].append(id)
	salvar()
	return true


# ---------------------------------------------------------------------
# Campanha
# ---------------------------------------------------------------------

func _carregar_campanha() -> void:
	var texto := FileAccess.get_file_as_string(ARQUIVO_CAMPANHA)
	var dados = JSON.parse_string(texto)
	if typeof(dados) != TYPE_DICTIONARY or not dados.has("circuitos"):
		push_error("Falha ao ler %s" % ARQUIVO_CAMPANHA)
		return
	campanha = dados


func circuitos() -> Array:
	return campanha.get("circuitos", [])


func circuito(i: int) -> Dictionary:
	var lista := circuitos()
	if i < 0 or i >= lista.size():
		return {}
	return lista[i]


func etapas(i: int) -> Array:
	return circuito(i).get("etapas", [])


func etapa(c: int, e: int) -> Dictionary:
	var lista := etapas(c)
	if e < 0 or e >= lista.size():
		return {}
	return lista[e]


## Arena da etapa: usa "local_reserva" quando o local pedido ainda não existe nos dados.
func local_da_etapa(c: int, e: int) -> String:
	var et := etapa(c, e)
	var id := str(et.get("local", "aleatorio"))
	if Dados.locais.has(id):
		return id
	var reserva := str(et.get("local_reserva", ""))
	if Dados.locais.has(reserva):
		return reserva
	return "aleatorio"


## Loadout do oponente da etapa, completo (deck sugerido, Cântico da facção, equipamento do elemento).
func inimigo_da_etapa(c: int, e: int) -> Dictionary:
	var et := etapa(c, e)
	var base: Dictionary = et.get("inimigo", {})
	var monstro := str(base.get("monstro", ""))
	if not Dados.monstros.has(monstro):
		return Dados.gerar_loadout_ia("")
	var cfg := base.duplicate(true)
	cfg["equipamento"] = str(base.get("equipamento", equipamento_sugerido(monstro)))
	cfg["cantico"] = str(base.get("cantico", cantico_sugerido(monstro)))
	if not (base.get("deck") is Array) or (base["deck"] as Array).is_empty():
		cfg["deck"] = Dados.deck_sugerido(monstro)
	return cfg


func campanha_concluida() -> bool:
	return int(progresso["circuito"]) >= circuitos().size()


## A próxima etapa a jogar (a última da campanha, se tudo já foi vencido).
func proxima_etapa() -> Dictionary:
	if campanha_concluida():
		var c := circuitos().size() - 1
		return {"circuito": c, "etapa": etapas(c).size() - 1}
	return {"circuito": int(progresso["circuito"]), "etapa": int(progresso["etapa"])}


func etapa_liberada(c: int, e: int) -> bool:
	if campanha_concluida():
		return true
	var pc := int(progresso["circuito"])
	return c < pc or (c == pc and e <= int(progresso["etapa"]))


func etapa_vencida(c: int, e: int) -> bool:
	return estrelas(c, e) > 0


func circuito_liberado(c: int) -> bool:
	return etapa_liberada(c, 0)


## Avança o progresso quando a etapa vencida era a atual (repetir etapas antigas não muda nada).
func avancar_campanha(c: int, e: int) -> void:
	if campanha_concluida():
		return
	if c != int(progresso["circuito"]) or e != int(progresso["etapa"]):
		return
	progresso["etapa"] = e + 1
	if int(progresso["etapa"]) >= etapas(c).size():
		progresso["circuito"] = c + 1
		progresso["etapa"] = 0
	salvar()


## Entrega a recompensa da etapa. Devolve a recompensa se ela for nova (senão, {}).
func entregar_recompensa(c: int, e: int) -> Dictionary:
	var rec: Dictionary = etapa(c, e).get("recompensa", {})
	if rec.is_empty():
		return {}
	match str(rec.get("tipo", "")):
		"monstro":
			if desbloquear_monstro(str(rec["id"])):
				return rec
		"titulo":
			if not progresso["titulos"].has(rec["id"]):
				progresso["titulos"].append(rec["id"])
				salvar()
				return rec
		_:
			# Equipamentos e Cânticos já estão todos disponíveis: a recompensa é simbólica,
			# mostrada só na primeira vitória da etapa.
			if not etapa_vencida(c, e):
				return rec
	return {}


# ---------------------------------------------------------------------
# Estrelas e partidas
# ---------------------------------------------------------------------

func estrelas(c: int, e: int) -> int:
	return int(progresso["estrelas"].get("%d/%d" % [c, e], 0))


func registrar_estrelas(c: int, e: int, quantidade: int) -> void:
	var chave := "%d/%d" % [c, e]
	progresso["estrelas"][chave] = maxi(int(progresso["estrelas"].get(chave, 0)), clampi(quantidade, 0, 3))
	salvar()


## 3 estrelas com mais de 60% de Energia, 2 com mais de 30%, 1 por vencer.
func estrelas_por_energia(fracao: float) -> int:
	if fracao > ESTRELAS_3:
		return 3
	if fracao > ESTRELAS_2:
		return 2
	return 1


func total_estrelas() -> int:
	var soma := 0
	for chave in progresso["estrelas"]:
		soma += int(progresso["estrelas"][chave])
	return soma


func estrelas_do_circuito(c: int) -> int:
	var soma := 0
	for e in etapas(c).size():
		soma += estrelas(c, e)
	return soma


func registrar_partida(vitoria: bool) -> void:
	progresso["partidas"] = int(progresso["partidas"]) + 1
	if vitoria:
		progresso["vitorias"] = int(progresso["vitorias"]) + 1
	salvar()


func marcar_tutorial_feito() -> void:
	progresso["tutorial_feito"] = true
	salvar()


# ---------------------------------------------------------------------
# Sugestões de loadout (Escolha Rápida)
# ---------------------------------------------------------------------

## Cântico da facção do monstro (ganha +15%); se não houver, qualquer um.
func cantico_sugerido(monstro_id: String) -> String:
	var fac := str(Dados.monstros.get(monstro_id, {}).get("faccao", ""))
	for id in Dados.canticos:
		if str(Dados.canticos[id].get("faccao", "")) == fac:
			return str(id)
	return str(Dados.canticos.keys()[0]) if not Dados.canticos.is_empty() else ""


## Equipamento com um elemento do monstro (acende os bônus das cartas); senão, o primeiro.
func equipamento_sugerido(monstro_id: String) -> String:
	var elementos: Array = Dados.monstros.get(monstro_id, {}).get("elementos", [])
	for el in elementos:
		for id in Dados.equipamentos:
			if str(Dados.equipamentos[id].get("elemento", "")) == str(el):
				return str(id)
	return str(Dados.equipamentos.keys()[0]) if not Dados.equipamentos.is_empty() else ""


## Loadout completo e pronto para um monstro.
func loadout_sugerido(monstro_id: String) -> Dictionary:
	return {
		"monstro": monstro_id,
		"equipamento": equipamento_sugerido(monstro_id),
		"cantico": cantico_sugerido(monstro_id),
		"deck": Dados.deck_sugerido(monstro_id),
	}


func guardar_loadout(cfg: Dictionary) -> void:
	var guardado := {}
	for chave in ["monstro", "equipamento", "cantico", "deck", "local"]:
		if cfg.has(chave):
			guardado[chave] = cfg[chave]
	progresso["ultimo_loadout"] = guardado
	salvar()


# ---------------------------------------------------------------------
# Salvamento
# ---------------------------------------------------------------------

func salvar() -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"config": config, "progresso": progresso}, "\t"))


func carregar() -> void:
	if not FileAccess.file_exists(ARQUIVO):
		return
	var texto := FileAccess.get_file_as_string(ARQUIVO)
	var dados = JSON.parse_string(texto)
	if typeof(dados) != TYPE_DICTIONARY:
		return
	for chave in config:
		if dados.get("config", {}).has(chave):
			config[chave] = dados["config"][chave]
	for chave in progresso:
		if dados.get("progresso", {}).has(chave):
			progresso[chave] = dados["progresso"][chave]


func apagar_progresso() -> void:
	progresso = {"circuito": 0, "etapa": 0, "monstros": [], "estrelas": {}, "vitorias": 0, "partidas": 0,
		"tutorial_feito": false, "titulos": [], "ultimo_loadout": {}}
	salvar()
