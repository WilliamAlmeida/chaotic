extends Node
## Ponto de entrada e fluxo do jogo completo:
##   título → história  (mapa → diálogo → loadout travado → batalha → resultado → diálogo → mapa)
##   título → duelo rápido (loadout → batalha → resultado → loadout)
##   título → opções
##
## Argumentos de linha de comando (depois de "--"):
##   --autoteste          uma partida IA x IA, imprime o resultado e fecha
##   --simular=N          N partidas IA x IA com loadouts aleatórios e tabela de vitórias
##   --roteiro=arquivo.gd script (extends Node) adicionado ao Main para dirigir testes/capturas
##   --pasta=caminho      pasta onde os roteiros salvam capturas (ver Depuracao)
##   --tela=nome          abre direto numa tela: titulo (padrão), campanha, opcoes, loadout, batalha
## Exemplo (rápido, sem janela):
##   godot --headless --fixed-fps 60 -- --simular=20

var _tela: Node
## Última escolha do jogador (monstro, equipamento, cântico, deck, local).
var _loadout_jogador: Dictionary = {}
## Config da última batalha (para a revanche).
var _config_batalha: Dictionary = {}
## {"circuito", "etapa"} enquanto uma luta de campanha está em andamento; vazio no duelo rápido.
var _etapa_em_jogo: Dictionary = {}
## Resultado da última luta de campanha: {"vitoria", "estrelas", "recompensa"}.
var _resultado_campanha: Dictionary = {}
var _dialogo: Dialogo
var _simulacoes_restantes := 0
var _vitorias: Dictionary = {}
var _partidas: Dictionary = {}
var _tempos: Array = []


func _ready() -> void:
	randomize()
	_loadout_jogador = (Jogo.progresso.get("ultimo_loadout", {}) as Dictionary).duplicate(true)
	var simulacoes := 0
	var tela := "titulo"
	var roteiro := ""
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoteste":
			simulacoes = 1
		elif arg.begins_with("--simular="):
			simulacoes = int(arg.get_slice("=", 1))
		elif arg.begins_with("--tela="):
			tela = arg.get_slice("=", 1)
		elif arg.begins_with("--roteiro="):
			roteiro = arg.get_slice("=", 1)
	if simulacoes > 0:
		_simulacoes_restantes = simulacoes
		_proxima_simulacao()
	else:
		match tela:
			"loadout":
				abrir_loadout()
			"campanha":
				abrir_campanha()
			"opcoes":
				abrir_opcoes()
			"batalha":
				iniciar_batalha(preparar_config(Dados.gerar_loadout_ia("")))
			_:
				abrir_titulo()
	if roteiro != "":
		var script = load(roteiro)
		if script:
			var no: Node = script.new()
			no.name = "Roteiro"
			add_child(no)


# ---------------------------------------------------------------------
# Telas
# ---------------------------------------------------------------------

func abrir_titulo() -> void:
	_limpar_tela()
	var menu := MenuTitulo.new()
	menu.campanha.connect(abrir_campanha)
	menu.duelo_rapido.connect(abrir_loadout)
	menu.opcoes.connect(abrir_opcoes)
	add_child(menu)
	_tela = menu
	Audio.musica("menu")


## História: abre o mapa. Se nada foi jogado ainda, já entra na primeira etapa (com tutorial).
func abrir_campanha() -> void:
	_abrir_mapa()
	var p := Jogo.proxima_etapa()
	if Jogo.total_estrelas() == 0 and int(p["circuito"]) == 0 and int(p["etapa"]) == 0 and not bool(Jogo.progresso.get("tutorial_feito", false)):
		iniciar_etapa(0, 0)


func _abrir_mapa() -> void:
	_limpar_tela()
	var mapa := Campanha.new()
	mapa.jogar.connect(iniciar_etapa)
	mapa.voltar.connect(abrir_titulo)
	add_child(mapa)
	_tela = mapa
	Audio.musica("menu")


func abrir_opcoes() -> void:
	_limpar_tela()
	var opcoes := Opcoes.new()
	opcoes.voltar.connect(abrir_titulo)
	add_child(opcoes)
	_tela = opcoes
	Audio.musica("menu")


## Duelo rápido: loadout livre.
func abrir_loadout() -> void:
	_etapa_em_jogo = {}
	_limpar_tela()
	var loadout := Loadout.new()
	loadout.config_inicial = _loadout_jogador.duplicate(true)
	loadout.lutar.connect(func(cfg: Dictionary):
		_guardar_loadout(cfg)
		iniciar_batalha(preparar_config(cfg)))
	if loadout.has_signal("voltar"):
		loadout.connect("voltar", abrir_titulo)
	add_child(loadout)
	_tela = loadout
	Audio.musica("menu")


## Etapa da campanha: diálogo de antes, depois o loadout com arena e oponente travados.
func iniciar_etapa(circuito: int, etapa: int) -> void:
	var et := Jogo.etapa(circuito, etapa)
	if et.is_empty():
		return
	_etapa_em_jogo = {"circuito": circuito, "etapa": etapa}
	if not is_instance_valid(_tela) or not _tela is Campanha:
		_abrir_mapa()
	_mostrar_dialogo(_falas(et.get("antes", []), circuito, etapa), func(): _abrir_loadout_campanha(circuito, etapa))


func _abrir_loadout_campanha(circuito: int, etapa: int) -> void:
	var et := Jogo.etapa(circuito, etapa)
	_limpar_tela()
	var loadout := Loadout.new()
	var cfg := _loadout_jogador.duplicate(true)
	cfg["local"] = Jogo.local_da_etapa(circuito, etapa)
	cfg["local_travado"] = true
	cfg["inimigo"] = Jogo.inimigo_da_etapa(circuito, etapa)
	cfg["campanha"] = {
		"circuito": circuito,
		"etapa": etapa,
		"chefe": bool(et.get("chefe", false)),
		"regra": str(et.get("regra", "")),
	}
	cfg["titulo"] = str(et.get("titulo", ""))
	cfg["frase"] = str(et.get("frase", ""))
	if bool(et.get("chefe", false)):
		cfg["dificuldade"] = "facil" if Jogo.facil() else "dificil"
	else:
		cfg["dificuldade"] = "facil" if Jogo.facil() else "normal"
	if circuito == 0 and etapa == 0 and not bool(Jogo.progresso.get("tutorial_feito", false)):
		cfg["tutorial"] = true
	loadout.config_inicial = cfg
	loadout.lutar.connect(func(escolha: Dictionary):
		_guardar_loadout(escolha)
		iniciar_batalha(preparar_config(escolha)))
	loadout.voltar.connect(func():
		_etapa_em_jogo = {}
		_abrir_mapa())
	add_child(loadout)
	_tela = loadout
	Audio.musica("menu")


## Resolve o local sorteado e gera o oponente (se a config ainda não trouxer um).
func preparar_config(cfg: Dictionary) -> Dictionary:
	var final := cfg.duplicate(true)
	if str(final.get("local", "aleatorio")) == "aleatorio" or not Dados.locais.has(str(final.get("local", ""))):
		final["local"] = Dados.locais.keys().pick_random()
		final["local_sorteado"] = true
	if not final.has("inimigo"):
		final["inimigo"] = Dados.gerar_loadout_ia(str(final["monstro"]))
	if not final.has("dificuldade"):
		final["dificuldade"] = "facil" if Jogo.facil() else "normal"
	return final


func iniciar_batalha(cfg: Dictionary) -> void:
	_limpar_tela()
	_config_batalha = cfg.duplicate(true)
	var batalha := Batalha.new()
	batalha.config = cfg
	batalha.terminou.connect(_on_batalha_terminou)
	batalha.pediu_revanche.connect(func(): iniciar_batalha(preparar_config(_config_batalha)))
	batalha.pediu_menu.connect(func():
		if _etapa_em_jogo.is_empty():
			abrir_loadout()
		else:
			_apos_batalha_campanha())
	add_child(batalha)
	_tela = batalha
	if not bool(cfg.get("simulacao", false)):
		Audio.musica("luta")


func tela_atual() -> Node:
	return _tela


## O diálogo aberto por cima da tela atual (null se não houver).
func dialogo_atual() -> Dialogo:
	return _dialogo if is_instance_valid(_dialogo) else null


func _limpar_tela() -> void:
	if is_instance_valid(_dialogo):
		_dialogo.queue_free()
	_dialogo = null
	if is_instance_valid(_tela):
		_tela.queue_free()
		remove_child(_tela)
	_tela = null


func _guardar_loadout(cfg: Dictionary) -> void:
	_loadout_jogador = {}
	for chave in ["monstro", "equipamento", "cantico", "deck", "local"]:
		if cfg.has(chave):
			_loadout_jogador[chave] = cfg[chave]
	if bool(cfg.get("local_travado", false)):
		_loadout_jogador.erase("local")
	Jogo.guardar_loadout(_loadout_jogador)


# ---------------------------------------------------------------------
# Campanha: diálogos, estrelas, recompensas
# ---------------------------------------------------------------------

func _mostrar_dialogo(falas: Array, ao_terminar: Callable) -> void:
	if is_instance_valid(_dialogo):
		_dialogo.queue_free()
	if falas.is_empty():
		ao_terminar.call()
		return
	_dialogo = Dialogo.new()
	_dialogo.falas = falas
	_dialogo.terminou.connect(func():
		_dialogo = null
		ao_terminar.call())
	add_child(_dialogo)


## Converte as falas do JSON ({"quem", "texto"}) em falas com nome, cor e retrato.
func _falas(brutas: Array, circuito: int, etapa: int) -> Array:
	var et := Jogo.etapa(circuito, etapa)
	var inimigo: Dictionary = et.get("inimigo", {})
	var monstro := str(inimigo.get("monstro", ""))
	var m: Dictionary = Dados.monstros.get(monstro, {})
	var f := Dados.faccao(str(m.get("faccao", "")))
	var mentor: Dictionary = Jogo.campanha.get("mentor", {"nome": "Guardiã"})
	var coro: Dictionary = Jogo.campanha.get("coro", {"nome": "Voz do Horizonte"})
	var falas: Array = []
	for bruta in brutas:
		var fala := {"texto": str(bruta.get("texto", ""))}
		match str(bruta.get("quem", "mentor")):
			"inimigo":
				fala["nome"] = str(m.get("nome", "Oponente")) + ("  (Eco Partido)" if bool(inimigo.get("coro", false)) else "")
				fala["cor"] = Color(str(f.get("cor", "#ffe3a0"))).lightened(0.35).to_html()
				fala["retrato"] = {"tipo": "monstro", "id": monstro}
			"coro":
				fala["nome"] = str(coro.get("nome", "Voz do Horizonte"))
				fala["cor"] = "#e6c6ff"
				fala["retrato"] = {"tipo": "coro"}
			_:
				fala["nome"] = str(mentor.get("nome", "Guardiã"))
				fala["cor"] = "#ffe3a0"
				fala["retrato"] = {"tipo": "mentor"}
		falas.append(fala)
	return falas


## Fala extra de vitória: estrelas com confete e a recompensa (se houver).
func _falas_premio(resultado: Dictionary) -> Array:
	var falas: Array = []
	var estrelas := int(resultado.get("estrelas", 0))
	var frases := {3: "Incrível! 3 estrelas!", 2: "Muito bem! 2 estrelas!", 1: "Boa luta! 1 estrela!"}
	falas.append({"nome": "Vitória!", "cor": "#ffe3a0", "texto": str(frases.get(estrelas, "Boa luta!")),
		"retrato": {"tipo": "estrelas", "quantidade": estrelas}, "confete": true})
	var rec: Dictionary = resultado.get("recompensa", {})
	if not rec.is_empty():
		var tipo := str(rec.get("tipo", ""))
		var id := str(rec.get("id", ""))
		match tipo:
			"monstro":
				falas.append({"nome": "Novo Eco!", "cor": "#ffe3a0", "texto": "%s agora luta com você!" % str(Dados.monstros.get(id, {}).get("nome", id)),
					"retrato": {"tipo": "carta", "carta": "monstro", "id": id}, "confete": true})
			"equipamento":
				falas.append({"nome": "Prêmio!", "cor": "#ffe3a0", "texto": "Você ganhou: %s!" % str(Dados.equipamentos.get(id, {}).get("nome", id)),
					"retrato": {"tipo": "carta", "carta": "equipamento", "id": id}, "confete": true})
			"cantico":
				falas.append({"nome": "Prêmio!", "cor": "#ffe3a0", "texto": "Você ganhou o Cântico: %s!" % str(Dados.canticos.get(id, {}).get("nome", id)),
					"retrato": {"tipo": "carta", "carta": "cantico", "id": id}, "confete": true})
			"titulo":
				falas.append({"nome": "Título!", "cor": "#ffe3a0", "texto": "Você agora é: %s!" % id, "retrato": {"tipo": "trofeu"}, "confete": true})
	return falas


## Depois do resultado da luta de campanha: volta ao mapa e mostra o diálogo de depois.
func _apos_batalha_campanha() -> void:
	var c := int(_etapa_em_jogo.get("circuito", 0))
	var e := int(_etapa_em_jogo.get("etapa", 0))
	var et := Jogo.etapa(c, e)
	var resultado := _resultado_campanha.duplicate(true)
	_etapa_em_jogo = {}
	_resultado_campanha = {}
	_abrir_mapa()
	var falas: Array
	if bool(resultado.get("vitoria", false)):
		falas = _falas_premio(resultado) + _falas(et.get("vitoria", []), c, e)
	else:
		falas = _falas(et.get("derrota", []), c, e)
	_mostrar_dialogo(falas, func(): pass)


# ---------------------------------------------------------------------
# Fim da batalha e simulação IA x IA (balanceamento)
# ---------------------------------------------------------------------

func _on_batalha_terminou(vitoria: bool, detalhes: Dictionary) -> void:
	if not bool(_tela.get("simulacao")):
		Jogo.registrar_partida(vitoria)
		if bool(_config_batalha.get("tutorial", false)):
			Jogo.marcar_tutorial_feito()
		if not _etapa_em_jogo.is_empty():
			_registrar_resultado_campanha(vitoria, detalhes)
		Audio.musica("vitoria" if vitoria else "menu")
		return
	var vencedor := str(detalhes["vencedor"])
	var perdedor := str(detalhes["perdedor"])
	_vitorias[vencedor] = int(_vitorias.get(vencedor, 0)) + 1
	_partidas[vencedor] = int(_partidas.get(vencedor, 0)) + 1
	_partidas[perdedor] = int(_partidas.get(perdedor, 0)) + 1
	_tempos.append(float(detalhes["tempo"]))
	print("Partida: %s venceu %s em %s (%.1fs, %s, energia restante %.0f)" % [
		vencedor, perdedor, detalhes["local"], detalhes["tempo"], detalhes["motivo"], detalhes["energia_restante"]])
	_proxima_simulacao.call_deferred()


## Estrelas, progresso e recompensa da etapa (salvos na hora, antes da tela de resultado).
func _registrar_resultado_campanha(vitoria: bool, detalhes: Dictionary) -> void:
	var c := int(_etapa_em_jogo["circuito"])
	var e := int(_etapa_em_jogo["etapa"])
	_resultado_campanha = {"vitoria": vitoria, "estrelas": 0, "recompensa": {}}
	if not vitoria:
		return
	var energia_max := 1.0
	var batalha := _tela as Batalha
	if batalha != null and batalha.jogador != null:
		energia_max = maxf(1.0, batalha.jogador.energia_max)
	var fracao := clampf(float(detalhes.get("energia_restante", 0.0)) / energia_max, 0.0, 1.0)
	var estrelas := Jogo.estrelas_por_energia(fracao)
	_resultado_campanha["recompensa"] = Jogo.entregar_recompensa(c, e)
	_resultado_campanha["estrelas"] = estrelas
	Jogo.registrar_estrelas(c, e, estrelas)
	Jogo.avancar_campanha(c, e)


func _proxima_simulacao() -> void:
	if _simulacoes_restantes <= 0:
		_imprimir_resumo()
		get_tree().quit()
		return
	_simulacoes_restantes -= 1
	var cfg := Dados.gerar_loadout_ia("")
	cfg["inimigo"] = Dados.gerar_loadout_ia(str(cfg["monstro"]))
	cfg["local"] = Dados.locais.keys().pick_random()
	cfg["simulacao"] = true
	iniciar_batalha(cfg)


func _imprimir_resumo() -> void:
	print("=== Resumo das simulações ===")
	for id in _partidas:
		var v := int(_vitorias.get(id, 0))
		var p := int(_partidas[id])
		print("%-10s %2d vitórias em %2d partidas (%.0f%%)" % [id, v, p, 100.0 * v / maxf(1.0, p)])
	if not _tempos.is_empty():
		var soma := 0.0
		for t in _tempos:
			soma += float(t)
		print("Duração média: %.1fs" % (soma / _tempos.size()))
