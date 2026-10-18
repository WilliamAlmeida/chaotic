class_name Tutorial
extends CanvasLayer
## Tutorial guiado da primeira luta (dicas grandes, passo a passo). A Batalha cria esta camada
## quando config["tutorial"] é verdadeiro. Implementação em andamento.

var batalha  # Batalha (sem tipo para evitar dependência cíclica)


func _ready() -> void:
	layer = 15
