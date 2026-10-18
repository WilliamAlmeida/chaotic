class_name ControleToque
extends CanvasLayer
## Controles de toque para celular/tablet: joystick virtual à esquerda e botões grandes à
## direita. A Batalha cria esta camada quando Jogo.toque_ativo() é verdadeiro.
##
## Contrato: esta camada só injeta ações no InputMap (Input.action_press / action_release)
## e ajusta a câmera por arrasto; o ControleJogador continua sendo quem fala com o Lutador.

var lutador: Lutador
var camera: CameraOrbita


func _ready() -> void:
	layer = 20
	# Implementação completa em andamento (joystick, botões de golpe/cartas/esquiva/pulo/cântico).
