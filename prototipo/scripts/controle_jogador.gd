class_name ControleJogador
extends Node
## Lê o teclado/mouse/controle e repassa para o Lutador do jogador.

var lutador: Lutador
var camera: CameraOrbita


func _physics_process(_delta: float) -> void:
	if lutador == null:
		return
	if lutador.cantando or not lutador.controles_ativos:
		lutador.direcao_movimento = Vector3.ZERO
		return
	var entrada := Input.get_vector("mover_esq", "mover_dir", "mover_frente", "mover_tras")
	var frente := Vector3.FORWARD
	var direita := Vector3.RIGHT
	if camera and camera.camera:
		frente = -camera.camera.global_transform.basis.z
		direita = camera.camera.global_transform.basis.x
		frente.y = 0.0
		direita.y = 0.0
		frente = frente.normalized()
		direita = direita.normalized()
	lutador.direcao_movimento = (direita * entrada.x - frente * entrada.y).limit_length(1.0)


func _process(_delta: float) -> void:
	if lutador == null or not lutador.controles_ativos:
		return
	if lutador.cantando:
		# Durante o Cântico, WASD/setas viram as "notas" da sequência.
		for tecla in Lutador.TECLAS_CANTICO:
			if Input.is_action_just_pressed(tecla):
				lutador.cantico_tecla(tecla)
		return
	if Input.is_action_just_pressed("pular"):
		lutador.pular()
	if Input.is_action_just_pressed("esquivar"):
		lutador.esquivar(lutador.direcao_movimento)
	if Input.is_action_just_pressed("ataque_basico") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or Jogo.toque_ativo()):
		lutador.ataque_basico()
	for i in MaoCartas.TAMANHO:
		if Input.is_action_just_pressed("carta_%d" % (i + 1)):
			lutador.usar_carta(i)
	if Input.is_action_just_pressed("cantico"):
		lutador.iniciar_cantico()
