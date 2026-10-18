extends Node
## Autoload "Jogo": configurações do jogador, progresso e salvamento (user://salvo.json).
##
## Tudo que precisa sobreviver entre telas ou entre sessões mora aqui:
##   - config:    modo fácil (assistências para crianças), toque, volumes
##   - progresso: campanha, monstros desbloqueados, estrelas por etapa, vitórias
## As telas chamam Jogo.salvar() depois de alterar algo.

const ARQUIVO := "user://salvo.json"

## Monstros disponíveis numa partida nova (os outros são desbloqueados na campanha).
const MONSTROS_INICIAIS := ["tigrana", "velamar", "talhuno", "sirocal"]

var config: Dictionary = {
	"modo_facil": true,       # assistências: mira automática, IA mais branda, dicas grandes
	"toque": "auto",          # "auto" (detecta tela de toque), "sim" ou "nao"
	"volume_efeitos": 0.8,
	"volume_musica": 0.6,
	"vibracao": true,
	"nome": "Duelista",
}
var progresso: Dictionary = {
	"circuito": 0,            # índice do circuito atual da campanha
	"etapa": 0,               # próxima etapa a jogar dentro do circuito
	"monstros": [],           # ids desbloqueados (além dos iniciais)
	"estrelas": {},           # "circuito/etapa" -> 1..3
	"vitorias": 0,
	"partidas": 0,
	"tutorial_feito": false,
}


func _ready() -> void:
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
	if monstro_desbloqueado(id):
		return false
	progresso["monstros"].append(id)
	salvar()
	return true


func estrelas(circuito: int, etapa: int) -> int:
	return int(progresso["estrelas"].get("%d/%d" % [circuito, etapa], 0))


func registrar_estrelas(circuito: int, etapa: int, quantidade: int) -> void:
	var chave := "%d/%d" % [circuito, etapa]
	progresso["estrelas"][chave] = maxi(int(progresso["estrelas"].get(chave, 0)), quantidade)
	salvar()


func registrar_partida(vitoria: bool) -> void:
	progresso["partidas"] = int(progresso["partidas"]) + 1
	if vitoria:
		progresso["vitorias"] = int(progresso["vitorias"]) + 1
	salvar()


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
	progresso = {"circuito": 0, "etapa": 0, "monstros": [], "estrelas": {}, "vitorias": 0, "partidas": 0, "tutorial_feito": false}
	salvar()
