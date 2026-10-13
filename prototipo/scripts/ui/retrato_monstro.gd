class_name RetratoMonstro
extends SubViewport
## Renderiza um monstro 3D (com o mesmo cel shading da luta) numa textura,
## usada como "arte" das cartas e como retrato na HUD.

var monstro_id := ""
var equipamento_id := ""
## "corpo" (carta) ou "rosto" (HUD).
var enquadramento := "corpo"
var balancar := true

var _pivo: Node3D
var _camera: Camera3D
var _t := 0.0


func _init() -> void:
	size = Vector2i(320, 320)
	transparent_bg = true
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	msaa_3d = Viewport.MSAA_2X


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.6, 0.75)
	env.ambient_light_energy = 0.55
	var mundo := WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 200, 0)
	luz.light_energy = 1.15
	add_child(luz)
	_pivo = Node3D.new()
	add_child(_pivo)
	_camera = Camera3D.new()
	_camera.fov = 32.0
	add_child(_camera)
	if monstro_id != "":
		definir(monstro_id, equipamento_id)


func definir(id: String, equip_id := "") -> void:
	monstro_id = id
	equipamento_id = equip_id
	if _pivo == null or not Dados.monstros.has(id):
		return
	for filho in _pivo.get_children():
		filho.queue_free()
	var l := Lutador.new()
	l.process_mode = Node.PROCESS_MODE_DISABLED
	l.configurar(id, equip_id, "", [])
	_pivo.add_child(l)
	if equip_id != "":
		l.mostrar_equipamento()
	l.preparar_retrato()
	var e := l.escala
	var foco := Vector3(0, 1.15 * e, 0)
	var distancia := 5.0 * e
	if enquadramento == "rosto":
		foco = Vector3(0, 1.55 * e, 0)
		distancia = 2.6 * e
	if str(Dados.monstros[id].get("modelo", "")) != "":
		# Modelos importados são mais esguios que os procedurais: enquadra mais perto.
		distancia *= 0.72
		foco.y *= 1.08
	_camera.position = Vector3(0.9 * e, foco.y + 0.35 * e, -distancia)
	_camera.look_at(foco, Vector3.UP)


func _process(delta: float) -> void:
	if balancar and _pivo:
		_t += delta
		_pivo.rotation.y = sin(_t * 0.7) * 0.45
