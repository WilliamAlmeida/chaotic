"""
Pipeline de rig automático para modelos humanoides gerados por IA (ex.: Hunyuan3D).

Uso (Blender como módulo Python, `pip install bpy`):
    python riggar_modelo.py <entrada.glb> <referencia.png|webp> <saida.glb>

O que faz:
  1. Carrega a malha (só geometria), centraliza no quadril e põe os pés em y = 0.
  2. Pinta cores de vértice projetando a imagem de referência pela frente;
     a parte de trás da cabeça/costas vira cabelo.
  3. Cria um esqueleto humanoide + cauda nas posições das articulações (JUNTAS).
  4. Pesos de pele automáticos (difusão de calor do Blender); o cabelo é preso à cabeça/peito.
  5. Cria as animações usadas pelo jogo e exporta GLB (malha + esqueleto + animações).

As coordenadas de JUNTAS estão no espaço do glTF original (Y para cima, frente em +Z) e
foram medidas numa vista ortográfica com grade. Para outro modelo, meça e troque a tabela.
"""
import math
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from PIL import Image

ENTRADA, REFERENCIA, SAIDA = sys.argv[-3:]

# Centro do quadril (x, z) e chão (y) no espaço do glTF original.
CENTRO_X, CENTRO_Z, CHAO_Y = -0.07, 0.19, -0.997

# (nome, cabeça, cauda, pai) — coordenadas glTF: (x, y, z), frente = +z, esquerda do personagem = +x.
JUNTAS = [
    ("Hips", (-0.07, -0.06, 0.19), (-0.07, 0.10, 0.18), None),
    ("Spine", (-0.07, 0.10, 0.18), (-0.07, 0.28, 0.18), "Hips"),
    ("Chest", (-0.07, 0.28, 0.18), (-0.07, 0.50, 0.17), "Spine"),
    ("Neck", (-0.07, 0.52, 0.17), (-0.08, 0.66, 0.19), "Chest"),
    ("Head", (-0.08, 0.66, 0.19), (-0.08, 0.95, 0.20), "Neck"),
    ("Shoulder.R", (-0.12, 0.50, 0.17), (-0.28, 0.52, 0.17), "Chest"),
    ("UpperArm.R", (-0.28, 0.52, 0.17), (-0.37, 0.20, 0.17), "Shoulder.R"),
    ("Forearm.R", (-0.37, 0.20, 0.17), (-0.40, -0.04, 0.23), "UpperArm.R"),
    ("Hand.R", (-0.40, -0.04, 0.23), (-0.41, -0.18, 0.25), "Forearm.R"),
    ("Shoulder.L", (-0.02, 0.50, 0.17), (0.14, 0.52, 0.17), "Chest"),
    ("UpperArm.L", (0.14, 0.52, 0.17), (0.22, 0.22, 0.17), "Shoulder.L"),
    ("Forearm.L", (0.22, 0.22, 0.17), (0.19, -0.01, 0.24), "UpperArm.L"),
    ("Hand.L", (0.19, -0.01, 0.24), (0.18, -0.12, 0.26), "Forearm.L"),
    ("Thigh.R", (-0.19, -0.08, 0.18), (-0.26, -0.45, 0.21), "Hips"),
    ("Shin.R", (-0.26, -0.45, 0.21), (-0.29, -0.85, 0.16), "Thigh.R"),
    ("Foot.R", (-0.29, -0.85, 0.16), (-0.31, -0.97, 0.38), "Shin.R"),
    ("Thigh.L", (0.04, -0.08, 0.18), (0.11, -0.45, 0.21), "Hips"),
    ("Shin.L", (0.11, -0.45, 0.21), (0.16, -0.85, 0.16), "Thigh.L"),
    ("Foot.L", (0.16, -0.85, 0.16), (0.19, -0.97, 0.38), "Shin.L"),
]
CAUDA = [(-0.08, -0.10, 0.06), (-0.11, -0.35, 0.03), (-0.10, -0.60, -0.03), (-0.02, -0.85, -0.15),
         (0.15, -0.93, -0.30), (0.30, -0.78, -0.40), (0.38, -0.88, -0.48)]
for i in range(len(CAUDA) - 1):
    JUNTAS.append((f"Tail{i + 1}", CAUDA[i], CAUDA[i + 1], "Hips" if i == 0 else f"Tail{i}"))

FPS = 30


def para_blender(p):
    """glTF (x, y-cima, z-frente) -> Blender (x, y-trás, z-cima), centralizado e com pés em 0."""
    x, y, z = p
    return Vector((x - CENTRO_X, -(z - CENTRO_Z), y - CHAO_Y))


def ler_glb(caminho):
    import json, struct
    dados = open(caminho, "rb").read()
    tam_json = struct.unpack("<I", dados[12:16])[0]
    js = json.loads(dados[20:20 + tam_json])
    ini = 20 + tam_json
    tam_bin = struct.unpack("<I", dados[ini:ini + 4])[0]
    binario = dados[ini + 8:ini + 8 + tam_bin]
    prim = js["meshes"][0]["primitives"][0]

    def acessor(i):
        a = js["accessors"][i]
        bv = js["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        tipo = {5125: np.uint32, 5123: np.uint16, 5126: np.float32}[a["componentType"]]
        n = {"SCALAR": 1, "VEC3": 3}[a["type"]]
        arr = np.frombuffer(binario, dtype=tipo, count=a["count"] * n, offset=off)
        return arr.reshape(-1, n) if n > 1 else arr

    return acessor(prim["attributes"]["POSITION"]).astype(np.float64), acessor(prim["indices"]).reshape(-1, 3)


# ---------------------------------------------------------------------------
# 1. Malha
# ---------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
pos_gltf, faces = ler_glb(ENTRADA)
verts_b = [tuple(para_blender(p)) for p in pos_gltf]
malha = bpy.data.meshes.new("Corpo")
malha.from_pydata(verts_b, [], faces.tolist())
malha.update()
corpo = bpy.data.objects.new("Corpo", malha)
bpy.context.collection.objects.link(corpo)

bm = bmesh.new()
bm.from_mesh(malha)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# Uma subdivisão simples dá mais resolução para as listras pintadas por vértice.
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, use_grid_fill=True)
bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.to_mesh(malha)
bm.free()
for p in malha.polygons:
    p.use_smooth = True
print("vertices:", len(malha.vertices), "triangulos:", len(malha.polygons))

# ---------------------------------------------------------------------------
# 2. Cores (projeção frontal da referência + cabelo atrás)
# ---------------------------------------------------------------------------
n_v = len(malha.vertices)
co = np.zeros(n_v * 3)
malha.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
nor = np.zeros(n_v * 3)
malha.vertices.foreach_get("normal", nor)
nor = nor.reshape(-1, 3)
# De volta ao espaço glTF para projetar: gx = bx + cx, gy = bz + chao, gz = -by + cz
gx = co[:, 0] + CENTRO_X
gy = co[:, 2] + CHAO_Y
nz_frente = -nor[:, 1]  # normal apontando para a frente (+z glTF = -y Blender)

img = np.asarray(Image.open(REFERENCIA).convert("RGB")).astype(np.float64) / 255.0
alt_img, larg_img = img.shape[:2]
fundo = np.median(np.concatenate([img[0], img[-1], img[:, 0], img[:, -1]]), axis=0)
mascara = np.linalg.norm(img - fundo, axis=2) > 60.0 / 255.0
# Preenche o fundo com a cor do primeiro plano mais próxima (evita "vazar" cinza nas bordas).
preenchida = img.copy()
conhecido = mascara.copy()
for _ in range(25):
    soma = np.zeros_like(preenchida)
    cont = np.zeros(mascara.shape)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        desl_c = np.roll(conhecido, (dy, dx), axis=(0, 1))
        desl_i = np.roll(preenchida, (dy, dx), axis=(0, 1))
        soma += desl_i * desl_c[..., None]
        cont += desl_c
    novos = (~conhecido) & (cont > 0)
    preenchida[novos] = soma[novos] / cont[novos][:, None]
    conhecido |= novos

# Mapeamento vertical: topo/base da silhueta. Horizontal: ajuste linear das bordas por linha.
linhas = np.where(mascara.sum(1) > 2)[0]
topo_img, base_img = linhas.min(), linhas.max()
gy_max, gy_min = gy.max(), gy.min()


def linha_img(y):
    return topo_img + (gy_max - y) / (gy_max - gy_min) * (base_img - topo_img)


pares_x, pares_img = [], []
for y in np.linspace(gy_min + 0.75 * (gy_max - gy_min), gy_min + 0.95 * (gy_max - gy_min), 25):
    faixa = (np.abs(gy - y) < 0.015) & (nz_frente > 0.0)
    if faixa.sum() < 5:
        continue
    li = int(round(linha_img(y)))
    cols = np.where(mascara[li])[0]
    if len(cols) < 3:
        continue
    pares_x += [gx[faixa].min(), gx[faixa].max()]
    pares_img += [cols.min(), cols.max()]
a, b = np.polyfit(pares_x, pares_img, 1)
print("ajuste horizontal: px = %.1f * x + %.1f" % (a, b))

u = np.clip(np.round(a * gx + b), 0, larg_img - 1).astype(int)
v = np.clip(np.round(linha_img(gy)), 0, alt_img - 1).astype(int)
cores = preenchida[v, u]

CABELO = np.array([0.80, 0.20, 0.10])
# Atrás da cabeça e nas costas até a cintura: cabelo (a referência só mostra a frente).
costas = nz_frente < -0.25
centro_tronco = np.abs(gx - CENTRO_X) < 0.27
eh_cabelo = costas & (((gy > 0.20) & centro_tronco) | (gy > 0.62))
orelha = gy > 0.88
eh_cabelo &= ~orelha
cores[eh_cabelo] = CABELO * (0.85 + 0.15 * np.clip(-nz_frente[eh_cabelo], 0, 1))[:, None]
# Classificação de cabelo também pela cor (vermelho forte), para os pesos.
r, g = cores[:, 0], cores[:, 1]
eh_cabelo |= (r > 0.45) & (g / np.maximum(r, 1e-3) < 0.38) & (gy > 0.15)

# Realça a saturação (visual de anime) e grava como atributo de cor por vértice (sRGB).
cinza = cores.mean(1, keepdims=True)
cores = np.clip(cinza + (cores - cinza) * 1.1, 0, 1)
atributo = malha.color_attributes.new("Col", "BYTE_COLOR", "POINT")
rgba = np.concatenate([cores, np.ones((n_v, 1))], axis=1)
atributo.data.foreach_set("color_srgb", rgba.ravel())

mat = bpy.data.materials.new("Pele")
mat.use_nodes = True
nos = mat.node_tree.nodes
bsdf = nos.get("Principled BSDF")
attr_no = nos.new("ShaderNodeVertexColor")
attr_no.layer_name = "Col"
mat.node_tree.links.new(attr_no.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
corpo.data.materials.append(mat)

# ---------------------------------------------------------------------------
# 3. Esqueleto
# ---------------------------------------------------------------------------
arm_dados = bpy.data.armatures.new("Esqueleto")
arm = bpy.data.objects.new("Esqueleto", arm_dados)
bpy.context.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
for nome, cabeca, cauda, pai in JUNTAS:
    osso = arm_dados.edit_bones.new(nome)
    osso.head = para_blender(cabeca)
    osso.tail = para_blender(cauda)
    # Rolagem coerente: eixo Z local do osso aponta para trás do personagem.
    osso.align_roll(Vector((0, 1, 0)) if abs((osso.tail - osso.head).normalized().y) < 0.9 else Vector((0, 0, 1)))
    if pai:
        osso.parent = arm_dados.edit_bones[pai]
        osso.use_connect = (osso.head - arm_dados.edit_bones[pai].tail).length < 1e-4
bpy.ops.object.mode_set(mode="OBJECT")

# ---------------------------------------------------------------------------
# 4. Pesos automáticos
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
corpo.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
grupos = {g.name: g for g in corpo.vertex_groups}
# Limpeza geométrica dos braços: no modelo original os punhos encostam nas coxas e os
# braços ficam colados ao tronco, então o calor "vaza". Cada braço só pode influenciar
# vértices dentro de um tubo em volta dos seus ossos; dentro do tubo, o braço manda.
segmentos = {nome: (para_blender(c), para_blender(t)) for nome, c, t, _ in JUNTAS}


def distancia_segmento(pontos, a, b):
    a = np.array(a)
    b = np.array(b)
    ab = b - a
    t = np.clip(((pontos - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(pontos - (a + t[:, None] * ab), axis=1)


pontos = np.array([vt.co[:] for vt in malha.vertices])
dist = {nome: distancia_segmento(pontos, a, b) for nome, (a, b) in segmentos.items()}
OSSOS_CORPO = ["Hips", "Spine", "Chest", "Neck", "Thigh.R", "Thigh.L", "Shin.R", "Shin.L"]
d_corpo = np.min([dist[n] for n in OSSOS_CORPO], axis=0)
for lado in ("R", "L"):
    braco = [f"UpperArm.{lado}", f"Forearm.{lado}", f"Hand.{lado}"]
    d_braco = np.min([dist[n] for n in braco], axis=0)
    fora = np.where((d_braco > 0.10) | (d_braco > d_corpo * 0.85))[0].tolist()
    dentro = np.where((d_braco < 0.075) & (d_braco < d_corpo * 0.7))[0].tolist()
    for nome in braco:
        grupos[nome].remove(fora)
    for nome in OSSOS_CORPO + [f"Shoulder.{lado}"]:
        grupos[nome].remove(dentro)
    # Dentro do tubo, distribui entre os ossos do braço pelo mais próximo.
    mais_perto = np.argmin([dist[n] for n in braco], axis=0)
    for i in dentro:
        if not any(grupos[n].index == g.group for g in malha.vertices[i].groups for n in braco):
            grupos[braco[mais_perto[i]]].add([i], 1.0, "REPLACE")
sem_peso = sum(1 for vt in malha.vertices if len(vt.groups) == 0)
print("vertices sem peso apos calor:", sem_peso)

# Cabelo segue cabeça/peito (senão os cachos laterais acompanham os braços).
idx_cabelo = np.where(eh_cabelo)[0].tolist()
for nome in grupos:
    grupos[nome].remove(idx_cabelo)
alto = [i for i in idx_cabelo if gy[i] >= 0.62]
baixo = [i for i in idx_cabelo if gy[i] < 0.62]
grupos["Head"].add(alto, 1.0, "REPLACE")
grupos["Chest"].add(baixo, 1.0, "REPLACE")

# Corta as "pontes" de malha entre braço e corpo (pulso encostado na coxa, braço colado
# ao tronco): triângulos que misturam vértices do braço com vértices do corpo, longe do
# ombro, são removidos. Sem isso eles esticam como paredes quando o braço se move.
def classe_vertice(vt):
    melhor, peso = "corpo", 0.0
    for g in vt.groups:
        nome = corpo.vertex_groups[g.group].name
        if g.weight > peso:
            peso = g.weight
            melhor = ("braco_" + nome[-1]) if nome.startswith(("UpperArm", "Forearm", "Hand")) else "corpo"
    return melhor


ombros = {lado: np.array(para_blender(c)) for nome, c, _, _ in JUNTAS for lado in ("R", "L") if nome == f"UpperArm.{lado}"}
# Fora da região do ombro, cada vértice pertence inteiro ao braço ou inteiro ao corpo
# (peso dividido faz o vértice andar "pela metade" e esticar a malha).
nomes_grupos = [g.name for g in corpo.vertex_groups]
for vt in malha.vertices:
    p = np.array(vt.co[:])
    if min(np.linalg.norm(p - ombros[l]) for l in ombros) < 0.13:
        continue
    peso_braco = sum(g.weight for g in vt.groups if nomes_grupos[g.group].startswith(("UpperArm", "Forearm", "Hand")))
    peso_resto = sum(g.weight for g in vt.groups) - peso_braco
    if peso_braco == 0.0 or peso_resto == 0.0:
        continue
    manter_braco = peso_braco >= peso_resto
    for g in list(vt.groups):
        eh_braco = nomes_grupos[g.group].startswith(("UpperArm", "Forearm", "Hand"))
        if eh_braco != manter_braco:
            corpo.vertex_groups[g.group].remove([vt.index])
classes = [classe_vertice(vt) for vt in malha.vertices]
bm = bmesh.new()
bm.from_mesh(malha)
bm.faces.ensure_lookup_table()
remover = []
for f in bm.faces:
    cls = {classes[v.index] for v in f.verts}
    if len(cls) < 2:
        continue
    centro = np.array(f.calc_center_median()[:])
    perto_ombro = any(np.linalg.norm(centro - ombros[lado]) < 0.13 for lado in ombros)
    if not perto_ombro:
        remover.append(f)
bmesh.ops.delete(bm, geom=remover, context="FACES_ONLY")
# Obs.: não preenchemos os buracos — cada contorno mistura braço e corpo e recriaria a ponte.
# Os buracos ficam nos pontos de contato (escondidos atrás do braço na maior parte do tempo).
bm.to_mesh(malha)
bm.free()
print("triangulos de ponte removidos:", len(remover))

# Vértices que ficaram sem peso: osso mais próximo (fora dos braços).
candidatos = [n for n in segmentos if not n.startswith(("UpperArm", "Forearm", "Hand"))]
for vt in malha.vertices:
    if len(vt.groups) == 0:
        mais_perto = min(candidatos, key=lambda n: dist[n][vt.index])
        grupos[mais_perto].add([vt.index], 1.0, "REPLACE")

# ---------------------------------------------------------------------------
# 5. Animações
# ---------------------------------------------------------------------------
pose = arm.pose
for pb in pose.bones:
    pb.rotation_mode = "QUATERNION"
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))  # X = esquerda, -Y = frente, Z = cima


# Convenção dos braços: em torno de Y, positivo abre o braço DIREITO (.R) para fora e
# negativo abre o ESQUERDO (.L); em torno de X, negativo leva braço/perna para a frente.
def rot_mundo(nome, eixo, graus):
    """Quaternion local que gira o osso `graus` em torno de um eixo do espaço do esqueleto."""
    pb = pose.bones[nome]
    rest = pb.bone.matrix_local.to_3x3()
    eixo_local = (rest.inverted() @ eixo).normalized()
    return Quaternion(eixo_local, math.radians(graus))


def chave(acao_poses, quadro):
    """acao_poses: {osso: [(eixo, graus), ...]} ou {"Hips_loc": Vector}."""
    for pb in pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for nome, rotacoes in acao_poses.items():
        if nome == "Hips_loc":
            pose.bones["Hips"].location = rotacoes
            continue
        q = Quaternion()
        for eixo, graus in rotacoes:
            q = rot_mundo(nome, eixo, graus) @ q
        pose.bones[nome].rotation_quaternion = q
    for pb in pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=quadro)
        pb.keyframe_insert("location", frame=quadro)


def cauda_balanco(fase, amp=10.0):
    return {f"Tail{i}": [(Z, amp * math.sin(fase + i * 0.7))] for i in range(1, 7)}


def criar_acao(nome, quadros, funcao):
    acao = bpy.data.actions.new(nome)
    acao.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = acao
    for f in range(quadros + 1):
        t = f / quadros
        chave(funcao(t), f)
    trilha = arm.animation_data.nla_tracks.new()
    trilha.name = nome
    trilha.strips.new(nome, 0, acao)
    arm.animation_data.action = None


def mescla(*dicts):
    saida = {}
    for d in dicts:
        for k, v in d.items():
            if k == "Hips_loc":
                saida[k] = v
            else:
                saida.setdefault(k, []).extend(v)
    return saida


def parado(t):
    s = math.sin(t * math.tau)
    return mescla({
        "Chest": [(X, 2.0 * s)], "Head": [(X, -1.5 * s), (Z, 3 * math.sin(t * math.tau + 1))],
        "UpperArm.R": [(Y, 3 + 2 * s)], "UpperArm.L": [(Y, -3 - 2 * s)],
        "Forearm.R": [(X, -8)], "Forearm.L": [(X, -8)],
        "Hips_loc": Vector((0, 0.006 * s, 0)),
    }, cauda_balanco(t * math.tau, 8))


def andar(t, amp=1.0, inclinacao=4.0):
    f = t * math.tau
    s = math.sin(f)
    return mescla({
        "Thigh.R": [(X, -28 * amp * s)], "Thigh.L": [(X, 28 * amp * s)],
        "Shin.R": [(X, 35 * amp * max(0.0, math.sin(f + 1.2)))],
        "Shin.L": [(X, 35 * amp * max(0.0, math.sin(f + 1.2 + math.pi)))],
        "Foot.R": [(X, -10 * amp * s)], "Foot.L": [(X, 10 * amp * s)],
        "UpperArm.R": [(X, 22 * amp * s), (Y, 8)], "UpperArm.L": [(X, -22 * amp * s), (Y, -8)],
        "Forearm.R": [(X, -18 * amp)], "Forearm.L": [(X, -18 * amp)],
        "Spine": [(Z, 5 * amp * s)], "Chest": [(X, -inclinacao), (Z, -6 * amp * s)],
        "Hips_loc": Vector((0, 0.025 * amp * abs(math.cos(f)), 0)),
    }, cauda_balanco(f, 12 * amp))


def correr(t):
    base = andar(t, 1.65, 14.0)
    base["Forearm.R"] = [(X, -75)]
    base["Forearm.L"] = [(X, -75)]
    return base


def atacar(t):
    # Garra: prepara (0-0.35) e risca na diagonal (0.35-0.6), volta (0.6-1).
    if t < 0.35:
        k = t / 0.35
        ang_braco, giro = -110 * k, 25 * k
    elif t < 0.6:
        k = (t - 0.35) / 0.25
        ang_braco, giro = -110 + 160 * k, 25 - 55 * k
    else:
        k = (t - 0.6) / 0.4
        ang_braco, giro = 50 * (1 - k), -30 * (1 - k)
    return mescla({
        "UpperArm.R": [(X, ang_braco), (Y, 20)], "Forearm.R": [(X, -30)],
        "Chest": [(Z, giro)], "Spine": [(Z, giro * 0.4)],
        "Thigh.R": [(X, 15)], "Thigh.L": [(X, -15)], "Shin.L": [(X, 20)],
    }, cauda_balanco(t * math.tau, 18))


def conjurar(t):
    # Os dois braços se estendem à frente (projéteis / golpes de área).
    k = math.sin(min(t / 0.6, 1.0) * math.pi * 0.5) if t < 0.6 else 1 - (t - 0.6) / 0.4
    return mescla({
        "UpperArm.R": [(X, -80 * k), (Y, 15 * k)], "UpperArm.L": [(X, -80 * k), (Y, -15 * k)],
        "Forearm.R": [(X, -10 * k)], "Forearm.L": [(X, -10 * k)],
        "Chest": [(X, -8 * k)], "Thigh.R": [(X, -12 * k)], "Thigh.L": [(X, 12 * k)],
    }, cauda_balanco(t * math.tau, 15))


def investida(t):
    return mescla({
        "Chest": [(X, -30)], "Spine": [(X, -15)], "Head": [(X, 20)],
        "UpperArm.R": [(X, 50), (Y, 25)], "UpperArm.L": [(X, 50), (Y, -25)],
        "Thigh.R": [(X, -45)], "Shin.R": [(X, 60)], "Thigh.L": [(X, 30)], "Shin.L": [(X, 40)],
    }, cauda_balanco(0, 0))


def salto(t):
    k = math.sin(t * math.pi)
    return mescla({
        "Thigh.R": [(X, -70 * k)], "Thigh.L": [(X, -70 * k)], "Shin.R": [(X, 100 * k)], "Shin.L": [(X, 100 * k)],
        "UpperArm.R": [(X, -95 * k), (Y, 20)], "UpperArm.L": [(X, -95 * k), (Y, -20)],
        "Chest": [(X, -15 * k)],
    }, cauda_balanco(t * math.tau, 25))


def esquiva(t):
    k = math.sin(t * math.pi)
    return mescla({
        "Spine": [(X, -25 * k)], "Chest": [(X, -20 * k)],
        "Thigh.R": [(X, -50 * k)], "Thigh.L": [(X, -50 * k)], "Shin.R": [(X, 80 * k)], "Shin.L": [(X, 80 * k)],
        "UpperArm.R": [(X, -40 * k)], "UpperArm.L": [(X, -40 * k)],
        "Hips_loc": Vector((0, -0.25 * k, 0)),
    }, cauda_balanco(0, 0))


def cantar(t):
    f = t * math.tau
    return mescla({
        "UpperArm.R": [(Y, 95), (X, -25 - 10 * math.sin(f))], "UpperArm.L": [(Y, -95), (X, -25 + 10 * math.sin(f))],
        "Forearm.R": [(X, -25)], "Forearm.L": [(X, -25)],
        "Chest": [(X, 8), (Z, 6 * math.sin(f))], "Head": [(X, 12)],
    }, cauda_balanco(f, 20))


def dano(t):
    k = math.sin(t * math.pi)
    return mescla({
        "Chest": [(X, 22 * k)], "Head": [(X, 18 * k)], "Spine": [(X, 10 * k)],
        "UpperArm.R": [(Y, 30 * k)], "UpperArm.L": [(Y, -30 * k)],
    }, cauda_balanco(0, 0))


def atordoado(t):
    f = t * math.tau
    return mescla({
        "Head": [(Z, 18 * math.sin(f)), (X, 15)], "Chest": [(X, 15), (Y, 8 * math.sin(f))],
        "UpperArm.R": [(Y, 10)], "UpperArm.L": [(Y, -10)], "Forearm.R": [(X, -5)], "Forearm.L": [(X, -5)],
    }, cauda_balanco(f, 5))


def derrota(t):
    k = min(t / 0.7, 1.0)
    k = 1 - (1 - k) ** 3
    return mescla({
        "Hips": [(X, -82 * k)], "Spine": [(X, -10 * k)], "Head": [(X, -20 * k)],
        "UpperArm.R": [(Y, 60 * k)], "UpperArm.L": [(Y, -60 * k)],
        "Thigh.R": [(X, 60 * k)], "Thigh.L": [(X, 70 * k)], "Shin.R": [(X, 30 * k)],
        "Hips_loc": Vector((0, -0.55 * k, 0)),
    }, cauda_balanco(0, 0))


ANIMACOES = [
    ("parado", 60, parado), ("andar", 30, andar), ("correr", 18, correr),
    ("atacar", 18, atacar), ("conjurar", 21, conjurar), ("investida", 12, investida),
    ("salto", 24, salto), ("esquiva", 9, esquiva), ("cantar", 36, cantar),
    ("dano", 12, dano), ("atordoado", 30, atordoado), ("derrota", 36, derrota),
]
bpy.context.scene.render.fps = FPS
for nome, quadros, funcao in ANIMACOES:
    criar_acao(nome, quadros, funcao)
for pb in pose.bones:
    pb.rotation_quaternion = Quaternion()
    pb.location = Vector()

# ---------------------------------------------------------------------------
# 6. Exportar
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=SAIDA,
    export_format="GLB",
    use_selection=True,
    export_skins=True,
    export_animations=True,
    export_animation_mode="NLA_TRACKS",
    export_vertex_color="ACTIVE",
    export_yup=True,
)
print("exportado:", SAIDA)
