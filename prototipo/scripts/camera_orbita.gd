class_name CameraOrbita
extends Node3D
## Câmera em terceira pessoa. "Travada" mantém o inimigo enquadrado (padrão de jogos de luta 3D);
## destravada, o mouse gira a câmera livremente. Tab alterna (no modo fácil fica sempre travada).
##
## Enquadramento dinâmico: travada, a câmera se afasta um pouco quando os lutadores se
## distanciam e desliza em direção ao meio dos dois, para os dois ficarem sempre visíveis.
## Tremor de câmera com decaimento (tremer(forca)) e "hit stop" curto em golpes fortes.
## O controle de toque mexe em yaw/pitch diretamente.

var alvo: Lutador
var foco: Lutador
var yaw := 0.0
var pitch := -0.32
## Distância base; a distância real cresce com a separação entre os lutadores.
var distancia := 7.5
var travada := true
var sensibilidade := 0.004
var camera: Camera3D

var _tremor := 0.0
var _tremor_fase := 0.0
var _distancia_atual := 7.5
var _deslize := Vector3.ZERO
var _em_hit_stop := false


func _ready() -> void:
	add_to_group("camera_orbita")
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0.8, 0.0, distancia)
	add_child(camera)
	camera.make_current()
	_distancia_atual = distancia
	if is_instance_valid(alvo):
		global_position = alvo.global_position + Vector3(0, 1.6, 0)
		if is_instance_valid(foco):
			var d := foco.global_position - alvo.global_position
			yaw = atan2(-d.x, -d.z)
	rotation = Vector3(pitch, yaw, 0)


func _exit_tree() -> void:
	# Nunca deixa o jogo "congelado" se a câmera sumir no meio de um hit stop.
	Engine.time_scale = 1.0


func _unhandled_input(event: InputEvent) -> void:
	var movimento := event as InputEventMouseMotion
	if movimento and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pitch = clampf(pitch - movimento.relative.y * sensibilidade, -1.1, 0.25)
		if not travada:
			yaw -= movimento.relative.x * sensibilidade
	if event.is_action_pressed("travar_camera") and not Jogo.facil():
		travada = not travada


## Tremor de câmera (forca 0..1+). Golpes fortes (> 0.7) também dão um "hit stop" de ~0.06 s.
func tremer(forca: float) -> void:
	forca = clampf(forca, 0.0, 1.5)
	_tremor = maxf(_tremor, forca)
	if forca > 0.7 and not _em_hit_stop:
		_em_hit_stop = true
		Engine.time_scale = 0.05
		var arvore := get_tree()
		if arvore == null:
			Engine.time_scale = 1.0
			_em_hit_stop = false
			return
		# Temporizador em tempo real (ignora o time_scale), restaurando sempre.
		arvore.create_timer(0.06, true, false, true).timeout.connect(func():
			Engine.time_scale = 1.0
			_em_hit_stop = false)


func _process(delta: float) -> void:
	if not is_instance_valid(alvo):
		return
	if Jogo.facil():
		travada = true
	var destino := alvo.global_position + Vector3(0, 1.6 * alvo.escala, 0)
	var distancia_desejada := distancia
	var deslize_desejado := Vector3.ZERO
	var foco_valido := is_instance_valid(foco) and foco.energia > 0.0
	if travada and foco_valido:
		var d := foco.global_position - alvo.global_position
		var separacao := Vector2(d.x, d.z).length()
		d.y = 0.0
		if separacao > 1.0:
			yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * delta))
		# Afasta até +45% quando a distância cresce e desliza um pouco rumo ao meio dos dois.
		distancia_desejada = distancia * (1.0 + clampf((separacao - 6.0) / 14.0, 0.0, 0.45))
		deslize_desejado = (foco.global_position - alvo.global_position) * clampf((separacao - 4.0) / 24.0, 0.0, 0.22)
		deslize_desejado.y = clampf(deslize_desejado.y, -0.5, 1.2)
	global_position = global_position.lerp(destino, 1.0 - exp(-10.0 * delta))
	_deslize = _deslize.lerp(deslize_desejado, 1.0 - exp(-4.0 * delta))
	_distancia_atual = lerpf(_distancia_atual, distancia_desejada, 1.0 - exp(-3.0 * delta))
	rotation = Vector3(pitch, yaw, 0)

	# O deslize é aplicado no espaço da câmera, só no eixo lateral/vertical, para não
	# "entrar" no monstro do jogador.
	var lateral := global_transform.basis.x.dot(_deslize)
	var deslocamento := Vector3(0.8 + lateral, _deslize.y, _distancia_atual)

	# Tremor: ruído rápido com decaimento exponencial, mais forte no começo.
	if _tremor > 0.001:
		_tremor_fase += delta * 60.0
		var amplitude := _tremor * 0.35
		deslocamento += Vector3(sin(_tremor_fase * 1.3) * amplitude, cos(_tremor_fase * 1.7) * amplitude * 0.7, 0.0)
		camera.rotation.z = sin(_tremor_fase * 0.9) * _tremor * 0.03
		_tremor = maxf(0.0, _tremor - delta * (2.2 + _tremor * 2.0))
	else:
		_tremor = 0.0
		camera.rotation.z = 0.0
	camera.position = deslocamento
