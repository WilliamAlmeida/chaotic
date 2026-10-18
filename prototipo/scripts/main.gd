extends Node
## Ponto de entrada: título → (campanha | duelo rápido | opções) → loadout → batalha.
##
## Argumentos de linha de comando (depois de "--"):
##   --autoteste          uma partida IA x IA, imprime o resultado e fecha
##   --simular=N          N partidas IA x IA com loadouts aleatórios e tabela de vitórias
##   --roteiro=arquivo.gd script (extends Node) adicionado ao Main para dirigir testes/capturas
##   --pasta=caminho      pasta onde os roteiros salvam capturas (ver Depuracao)
##   --tela=nome          abre direto numa tela: titulo (padrão), loadout, batalha
## Exemplo (rápido, sem janela):
##   godot --headless --fixed-fps 60 -- --simular=20

var _tela: Node
var _ultima_config: Dictionary = {}
var _simulacoes_restantes := 0
var _vitorias: Dictionary = {}
var _partidas: Dictionary = {}
var _tempos: Array = []


func _ready() -> void:
	randomize()
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


## Campanha (história): por enquanto abre o loadout; a tela própria vem na sequência.
func abrir_campanha() -> void:
	abrir_loadout()


func abrir_opcoes() -> void:
	abrir_titulo()


func abrir_loadout() -> void:
	_limpar_tela()
	var loadout := Loadout.new()
	loadout.config_inicial = _ultima_config
	loadout.lutar.connect(func(cfg: Dictionary):
		_ultima_config = cfg
		iniciar_batalha(preparar_config(cfg)))
	if loadout.has_signal("voltar"):
		loadout.connect("voltar", abrir_titulo)
	add_child(loadout)
	_tela = loadout
	Audio.musica("menu")


## Resolve o local sorteado e gera o oponente (se a config ainda não trouxer um).
func preparar_config(cfg: Dictionary) -> Dictionary:
	var final := cfg.duplicate(true)
	if str(final.get("local", "aleatorio")) == "aleatorio":
		final["local"] = Dados.locais.keys().pick_random()
		final["local_sorteado"] = true
	if not final.has("inimigo"):
		final["inimigo"] = Dados.gerar_loadout_ia(str(final["monstro"]))
	return final


func iniciar_batalha(cfg: Dictionary) -> void:
	_limpar_tela()
	var batalha := Batalha.new()
	batalha.config = cfg
	batalha.terminou.connect(_on_batalha_terminou)
	batalha.pediu_revanche.connect(func(): iniciar_batalha(preparar_config(_ultima_config if not _ultima_config.is_empty() else cfg)))
	batalha.pediu_menu.connect(abrir_loadout)
	add_child(batalha)
	_tela = batalha
	if not bool(cfg.get("simulacao", false)):
		Audio.musica("luta")


func tela_atual() -> Node:
	return _tela


func _limpar_tela() -> void:
	if is_instance_valid(_tela):
		_tela.queue_free()
		remove_child(_tela)
	_tela = null


# ---------------------------------------------------------------------
# Simulação IA x IA (balanceamento)
# ---------------------------------------------------------------------

func _on_batalha_terminou(vitoria: bool, detalhes: Dictionary) -> void:
	if not bool(_tela.get("simulacao")):
		Jogo.registrar_partida(vitoria)
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
