class_name CameraOrbita
extends Node3D
## Câmera em terceira pessoa. "Travada" mantém o inimigo enquadrado (padrão de jogos de luta 3D);
## destravada, o mouse gira a câmera livremente. Tab alterna.

var alvo: Lutador
var foco: Lutador
var yaw := 0.0
var pitch := -0.32
var distancia := 7.5
var travada := true
var sensibilidade := 0.004
var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.position = Vector3(0.8, 0.0, distancia)
	add_child(camera)
	camera.make_current()
	if is_instance_valid(alvo):
		global_position = alvo.global_position + Vector3(0, 1.6, 0)
		if is_instance_valid(foco):
			var d := foco.global_position - alvo.global_position
			yaw = atan2(-d.x, -d.z)
	rotation = Vector3(pitch, yaw, 0)


func _unhandled_input(event: InputEvent) -> void:
	var movimento := event as InputEventMouseMotion
	if movimento and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pitch = clampf(pitch - movimento.relative.y * sensibilidade, -1.1, 0.25)
		if not travada:
			yaw -= movimento.relative.x * sensibilidade
	if event.is_action_pressed("travar_camera"):
		travada = not travada


func _process(delta: float) -> void:
	if not is_instance_valid(alvo):
		return
	var destino := alvo.global_position + Vector3(0, 1.6 * alvo.escala, 0)
	global_position = global_position.lerp(destino, 1.0 - exp(-10.0 * delta))
	if travada and is_instance_valid(foco) and foco.energia > 0.0:
		var d := foco.global_position - alvo.global_position
		d.y = 0.0
		if d.length() > 1.0:
			yaw = lerp_angle(yaw, atan2(-d.x, -d.z), 1.0 - exp(-5.0 * delta))
	rotation = Vector3(pitch, yaw, 0)
