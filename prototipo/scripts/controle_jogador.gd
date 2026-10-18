class_name ControleJogador
extends Node
## Lê o teclado/mouse/controle e repassa para o Lutador do jogador.
## Os controles de toque (ControleToque) injetam as mesmas ações no InputMap, então
## nada aqui precisa saber se o jogador está num celular.

## Abertura (em graus) do cone em que a mira assistida do modo fácil puxa o movimento para o inimigo.
const CONE_ASSISTENCIA := 30.0
## Força máxima da assistência (0 = nada, 1 = anda direto para o inimigo).
const PESO_ASSISTENCIA := 0.5

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
	var direcao := (direita * entrada.x - frente * entrada.y).limit_length(1.0)
	if Jogo.facil() and direcao.length() > 0.1:
		direcao = _assistir_direcao(direcao)
	lutador.direcao_movimento = direcao


## Mira assistida leve (modo fácil): se o jogador anda quase na direção do inimigo, o
## movimento é puxado um pouco para ele, assim a criança chega ao alvo sem precisão fina.
## Parado, nada muda (o Lutador já vira sozinho para o alvo). As ações continuam as mesmas.
func _assistir_direcao(direcao: Vector3) -> Vector3:
	if not is_instance_valid(lutador.alvo) or lutador.alvo.energia <= 0.0:
		return direcao
	var para_alvo := lutador.alvo.global_position - lutador.global_position
	para_alvo.y = 0.0
	if para_alvo.length() < 1.5:
		return direcao
	para_alvo = para_alvo.normalized()
	var angulo := direcao.normalized().angle_to(para_alvo)
	var cone := deg_to_rad(CONE_ASSISTENCIA)
	if angulo > cone:
		return direcao
	var peso := PESO_ASSISTENCIA * (1.0 - angulo / cone)
	var nova := direcao.normalized().lerp(para_alvo, peso)
	if nova.length() < 0.001:
		return direcao
	return nova.normalized() * direcao.length()


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
