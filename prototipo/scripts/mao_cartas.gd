class_name MaoCartas
extends RefCounted
## Deck de ataques em combate: 3 cartas na mão (como no card game).
## Usar uma carta libera o espaço, que recarrega e compra a próxima do deck.
## Quando o deck acaba, o descarte é embaralhado e vira o novo deck.

const TAMANHO := 3

var compra: Array[String] = []
var descarte: Array[String] = []
var slots: Array[String] = ["", "", ""]
var recarga: Array[float] = [0.0, 0.0, 0.0]
var recarga_total: Array[float] = [1.0, 1.0, 1.0]


## atraso_inicial > 0 faz a mão começar "recarregando" (quem perde a iniciativa).
func iniciar(deck: Array, atraso_inicial: float) -> void:
	compra.assign(deck)
	compra.shuffle()
	descarte.clear()
	for i in TAMANHO:
		slots[i] = ""
		recarga[i] = atraso_inicial
		recarga_total[i] = maxf(atraso_inicial, 0.01)
		if atraso_inicial <= 0.0:
			_comprar(i)


func processar(delta: float) -> void:
	for i in TAMANHO:
		if slots[i] != "":
			continue
		recarga[i] -= delta
		if recarga[i] <= 0.0:
			_comprar(i)


func pode_usar(i: int) -> bool:
	return slots[i] != ""


## Retira a carta do espaço i. O tempo de recarga cresce com o custo da carta
## e diminui com a Mente do monstro (mult_recarga).
func usar(i: int, mult_recarga: float) -> String:
	var id := slots[i]
	slots[i] = ""
	descarte.append(id)
	var custo := float(Dados.ataques[id]["custo"])
	recarga_total[i] = (2.8 + custo * 1.1) * mult_recarga
	recarga[i] = recarga_total[i]
	return id


## Diminui a recarga do espaço que está há mais tempo esperando (passivas de recarga).
func reduzir_maior_recarga(segundos: float) -> void:
	var escolhido := -1
	var maior := 0.0
	for i in TAMANHO:
		if slots[i] == "" and recarga[i] > maior:
			maior = recarga[i]
			escolhido = i
	if escolhido >= 0:
		recarga[escolhido] = maxf(0.0, recarga[escolhido] - segundos)


func progresso_recarga(i: int) -> float:
	if slots[i] != "":
		return 1.0
	return clampf(1.0 - recarga[i] / recarga_total[i], 0.0, 1.0)


func _comprar(i: int) -> void:
	if compra.is_empty():
		if descarte.is_empty():
			return
		compra.assign(descarte)
		descarte.clear()
		compra.shuffle()
	slots[i] = compra.pop_back()
