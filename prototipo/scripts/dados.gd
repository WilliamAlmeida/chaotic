extends Node
## Autoload "Dados": carrega as cartas (JSON em res://data) e registra os controles.
## Para criar uma carta nova basta editar os arquivos JSON — nenhum código precisa mudar.

const ELEMENTOS := {
	"brasa": {"nome": "Brasa", "cor": Color(1.0, 0.45, 0.15)},
	"tempestade": {"nome": "Tempestade", "cor": Color(0.55, 0.9, 1.0)},
	"pedra": {"nome": "Pedra", "cor": Color(0.78, 0.6, 0.38)},
	"mare": {"nome": "Maré", "cor": Color(0.25, 0.55, 1.0)},
}
const ATRIBUTOS := {"agilidade": "Agilidade", "forca": "Força", "mente": "Mente", "animo": "Ânimo"}
const ARQUETIPOS := {"projetil": "Projétil", "area": "Área", "investida": "Investida", "salto": "Salto"}

## Regras de montagem do deck de ataques (herdadas do card game: 20 pontos de orçamento).
const ORCAMENTO_DECK := 20
const DECK_MIN := 6
const DECK_MAX := 10

var monstros: Dictionary = {}
var ataques: Dictionary = {}
var equipamentos: Dictionary = {}
var canticos: Dictionary = {}
var locais: Dictionary = {}


func _ready() -> void:
	monstros = _carregar("res://data/monstros.json")
	ataques = _carregar("res://data/ataques.json")
	equipamentos = _carregar("res://data/equipamentos.json")
	canticos = _carregar("res://data/canticos.json")
	locais = _carregar("res://data/locais.json")
	_registrar_controles()


func _carregar(caminho: String) -> Dictionary:
	var texto := FileAccess.get_file_as_string(caminho)
	var lista = JSON.parse_string(texto)
	if typeof(lista) != TYPE_ARRAY:
		push_error("Falha ao ler %s" % caminho)
		return {}
	var resultado := {}
	for item in lista:
		resultado[str(item["id"])] = item
	return resultado


func cor_elemento(elemento: String) -> Color:
	if ELEMENTOS.has(elemento):
		return ELEMENTOS[elemento]["cor"]
	return Color(0.95, 0.95, 0.95)


## Sugere um deck que combine com os elementos do monstro, respeitando o orçamento.
func deck_sugerido(monstro_id: String) -> Array:
	var elementos_monstro: Array = monstros[monstro_id]["elementos"]
	var candidatos: Array = ataques.values()
	candidatos.sort_custom(func(a, b): return _nota_ataque(a, elementos_monstro) > _nota_ataque(b, elementos_monstro))
	var deck: Array = []
	var custo := 0
	for atk in candidatos:
		if deck.size() >= DECK_MAX:
			break
		var c := int(atk["custo"])
		if _nota_ataque(atk, elementos_monstro) > 0.0 and custo + c <= ORCAMENTO_DECK:
			deck.append(atk["id"])
			custo += c
	if deck.size() < DECK_MIN:
		candidatos.sort_custom(func(a, b): return int(a["custo"]) < int(b["custo"]))
		for atk in candidatos:
			if deck.size() >= DECK_MIN:
				break
			var c := int(atk["custo"])
			if not deck.has(atk["id"]) and custo + c <= ORCAMENTO_DECK:
				deck.append(atk["id"])
				custo += c
	return deck


func _nota_ataque(atk: Dictionary, elementos_monstro: Array) -> float:
	var bonus: Dictionary = atk.get("bonus_elemento", {})
	var nota := 1.0 if bonus.is_empty() else 0.0
	for el in bonus:
		if elementos_monstro.has(el):
			nota += 2.0 + float(bonus[el]) * 0.1
	if nota <= 0.0:
		return 0.0
	return nota + float(atk["custo"]) * 0.2


## Loadout completo e aleatório para a IA (ou para as simulações).
func gerar_loadout_ia(excluir_monstro: String) -> Dictionary:
	var opcoes := monstros.keys().filter(func(k): return k != excluir_monstro)
	var monstro: String = opcoes.pick_random()
	return {
		"monstro": monstro,
		"equipamento": equipamentos.keys().pick_random(),
		"cantico": canticos.keys().pick_random(),
		"deck": deck_sugerido(monstro),
	}


func _registrar_controles() -> void:
	_acao("mover_frente", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_acao("mover_tras", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	_acao("mover_esq", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_acao("mover_dir", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	_acao("pular", [KEY_SPACE], [JOY_BUTTON_A])
	_acao("esquivar", [KEY_SHIFT], [JOY_BUTTON_B])
	_acao("ataque_basico", [KEY_J], [JOY_BUTTON_X], [], MOUSE_BUTTON_LEFT)
	_acao("carta_1", [KEY_1], [JOY_BUTTON_LEFT_SHOULDER])
	_acao("carta_2", [KEY_2], [JOY_BUTTON_Y])
	_acao("carta_3", [KEY_3], [JOY_BUTTON_RIGHT_SHOULDER])
	_acao("cantico", [KEY_Q], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_acao("travar_camera", [KEY_TAB], [JOY_BUTTON_RIGHT_STICK])


func _acao(nome: String, teclas: Array, botoes: Array = [], eixos: Array = [], mouse: int = 0) -> void:
	if not InputMap.has_action(nome):
		InputMap.add_action(nome, 0.35)
	for tecla in teclas:
		var ev_tecla := InputEventKey.new()
		ev_tecla.physical_keycode = tecla
		InputMap.action_add_event(nome, ev_tecla)
	for botao in botoes:
		var ev_botao := InputEventJoypadButton.new()
		ev_botao.button_index = botao
		InputMap.action_add_event(nome, ev_botao)
	for par in eixos:
		var ev_eixo := InputEventJoypadMotion.new()
		ev_eixo.axis = par[0]
		ev_eixo.axis_value = par[1]
		InputMap.action_add_event(nome, ev_eixo)
	if mouse != 0:
		var ev_mouse := InputEventMouseButton.new()
		ev_mouse.button_index = mouse
		InputMap.action_add_event(nome, ev_mouse)
