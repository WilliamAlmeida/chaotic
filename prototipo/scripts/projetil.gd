class_name Projetil
extends Node3D
## Projétil com leve perseguição ao alvo. Atravessa quem estiver esquivando.

var dono: Lutador
var alvo: Lutador
var ataque: Dictionary = {}
var local: Dictionary = {}
var direcao := Vector3.FORWARD
var velocidade := 22.0
var raio := 0.35
var cor := Color.WHITE

var _vida := 2.5
var _curva := 1.2
var _desviado := false


func _ready() -> void:
	add_to_group("projeteis")
	var esfera := SphereMesh.new()
	esfera.radius = raio
	esfera.height = raio * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = esfera
	mi.material_override = Efeitos.material(cor, 3.0, 1.0, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var luz := OmniLight3D.new()
	luz.light_color = cor
	luz.light_energy = 1.5
	luz.omni_range = 3.0
	add_child(luz)


func _physics_process(delta: float) -> void:
	_vida -= delta
	if _vida <= 0.0:
		queue_free()
		return
	var alvo_valido := is_instance_valid(alvo) and alvo.energia > 0.0
	if alvo_valido and not _desviado:
		var desejada := (alvo.centro() - global_position).normalized()
		direcao = direcao.lerp(desejada, clampf(_curva * delta, 0.0, 1.0)).normalized()
	global_position += direcao * velocidade * delta

	if alvo_valido and not _desviado \
			and global_position.distance_to(alvo.centro()) <= alvo.raio_acerto() + raio:
		if alvo.invulneravel():
			_desviado = true
			alvo.mostrar_texto("Esquivou!", Color(0.85, 0.85, 0.85))
		else:
			Combate.aplicar_ataque(ataque, dono, alvo, local)
			Efeitos.explosao(get_parent(), global_position, cor, 1.4)
			queue_free()
			return
	if global_position.y < 0.0:
		Efeitos.explosao(get_parent(), global_position, cor, 0.8)
		queue_free()
