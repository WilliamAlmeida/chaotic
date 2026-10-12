extends Node
## Ponto de entrada: alterna entre a tela de loadout e a batalha.
##
## Argumentos de linha de comando (depois de "--"):
##   --autoteste     uma partida IA x IA, imprime o resultado e fecha
##   --simular=N     N partidas IA x IA com loadouts aleatórios e tabela de vitórias
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
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoteste":
			simulacoes = 1
		elif arg.begins_with("--simular="):
			simulacoes = int(arg.get_slice("=", 1))
	if simulacoes > 0:
		_simulacoes_restantes = simulacoes
		_proxima_simulacao()
	else:
		_abrir_loadout()


func _abrir_loadout() -> void:
	_limpar_tela()
	var loadout := Loadout.new()
	loadout.config_inicial = _ultima_config
	loadout.lutar.connect(func(cfg: Dictionary):
		_ultima_config = cfg
		_iniciar_batalha(_preparar_config(cfg)))
	add_child(loadout)
	_tela = loadout


## Resolve o local sorteado e gera o oponente.
func _preparar_config(cfg: Dictionary) -> Dictionary:
	var final := cfg.duplicate(true)
	if final["local"] == "aleatorio":
		final["local"] = Dados.locais.keys().pick_random()
		final["local_sorteado"] = true
	final["inimigo"] = Dados.gerar_loadout_ia(str(final["monstro"]))
	return final


func _iniciar_batalha(cfg: Dictionary) -> void:
	_limpar_tela()
	var batalha := Batalha.new()
	batalha.config = cfg
	batalha.terminou.connect(_on_batalha_terminou)
	batalha.pediu_revanche.connect(func(): _iniciar_batalha(_preparar_config(_ultima_config)))
	batalha.pediu_menu.connect(_abrir_loadout)
	add_child(batalha)
	_tela = batalha


func _limpar_tela() -> void:
	if is_instance_valid(_tela):
		_tela.queue_free()
		remove_child(_tela)
	_tela = null


func _on_batalha_terminou(_vitoria: bool, detalhes: Dictionary) -> void:
	if not bool(_tela.get("simulacao")):
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
	_iniciar_batalha(cfg)


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
