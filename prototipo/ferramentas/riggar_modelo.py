"""
Pipeline de rig automático para modelos humanoides gerados por IA (ex.: Hunyuan3D).

Uso (Blender como módulo Python, `pip install bpy`):
    python riggar_modelo.py <entrada.glb> <referencia.png|webp> <saida.glb>

O modelo de entrada deve estar em pose T (braços abertos na horizontal, sem encostar no
corpo): assim os pesos dos braços saem limpos, sem "pontes" de malha entre braço e tronco.

O que faz:
  1. Carrega a malha (só geometria), centraliza no quadril e põe os pés em y = 0.
  2. Cria um esqueleto humanoide + cauda nas posições das articulações (JUNTAS).
  3. Pesos de pele automáticos (difusão de calor do Blender), limitados a um tubo em volta
     de cada braço.
  4. Abaixa os braços (pose T -> pose A) e grava essa pose como a pose de repouso, que é a
     que as animações e o jogo esperam.
  5. Pinta cores de vértice projetando a imagem de referência pela frente;
     a parte de trás da cabeça/costas vira cabelo, preso à cabeça/peito.
  6. Cria as animações usadas pelo jogo e exporta GLB (malha + esqueleto + animações).

As coordenadas de JUNTAS estão no espaço do glTF original (Y para cima, frente em +Z) e
foram medidas por fatias da malha e numa vista ortográfica com grade. Para outro modelo,
meça e troque a tabela.
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
CENTRO_X, CENTRO_Z, CHAO_Y = -0.05, 0.20, -1.0004

# (nome, cabeça, cauda, pai) — coordenadas glTF: (x, y, z), frente = +z, esquerda do personagem = +x.
# Pose T: braços na horizontal em y ~ 0.6.
JUNTAS = [
    ("Hips", (-0.05, 0.02, 0.20), (-0.05, 0.16, 0.19), None),
    ("Spine", (-0.05, 0.16, 0.19), (-0.05, 0.32, 0.19), "Hips"),
    ("Chest", (-0.05, 0.32, 0.19), (-0.05, 0.56, 0.18), "Spine"),
    ("Neck", (-0.05, 0.58, 0.17), (-0.045, 0.70, 0.18), "Chest"),
    ("Head", (-0.045, 0.70, 0.18), (-0.04, 0.97, 0.20), "Neck"),
    ("Shoulder.R", (-0.10, 0.57, 0.18), (-0.25, 0.60, 0.18), "Chest"),
    ("UpperArm.R", (-0.25, 0.60, 0.18), (-0.49, 0.585, 0.185), "Shoulder.R"),
    ("Forearm.R", (-0.49, 0.585, 0.185), (-0.72, 0.575, 0.205), "UpperArm.R"),
    ("Hand.R", (-0.72, 0.575, 0.205), (-0.86, 0.575, 0.20), "Forearm.R"),
    ("Shoulder.L", (0.00, 0.57, 0.18), (0.15, 0.60, 0.18), "Chest"),
    ("UpperArm.L", (0.15, 0.60, 0.18), (0.39, 0.588, 0.185), "Shoulder.L"),
    ("Forearm.L", (0.39, 0.588, 0.185), (0.62, 0.58, 0.20), "UpperArm.L"),
    ("Hand.L", (0.62, 0.58, 0.20), (0.79, 0.575, 0.19), "Forearm.L"),
    ("Thigh.R", (-0.16, 0.00, 0.20), (-0.26, -0.45, 0.19), "Hips"),
    ("Shin.R", (-0.26, -0.45, 0.19), (-0.30, -0.85, 0.17), "Thigh.R"),
    ("Foot.R", (-0.30, -0.85, 0.17), (-0.32, -0.97, 0.42), "Shin.R"),
    ("Thigh.L", (0.06, 0.00, 0.20), (0.19, -0.45, 0.19), "Hips"),
    ("Shin.L", (0.19, -0.45, 0.19), (0.23, -0.85, 0.17), "Thigh.L"),
    ("Foot.L", (0.23, -0.85, 0.17), (0.24, -0.97, 0.42), "Shin.L"),
]
# Linha central da cauda (medida por distância geodésica ao longo da malha a partir da raiz).
CAUDA = [(0.00, 0.07, 0.07), (0.03, -0.14, 0.00), (0.04, -0.38, -0.01), (0.09, -0.60, -0.11),
         (0.22, -0.71, -0.30), (0.36, -0.555, -0.46), (0.53, -0.47, -0.50), (0.58, -0.64, -0.44)]
N_CAUDA = len(CAUDA) - 1
for i in range(N_CAUDA):
    JUNTAS.append((f"Tail{i + 1}", CAUDA[i], CAUDA[i + 1], "Hips" if i == 0 else f"Tail{i}"))
# Pose T -> pose A: quanto cada braço desce (graus) antes de virar a pose de repouso.
DESCIDA_BRACO = 72.0

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
# 2. Esqueleto
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
# 3. Pesos automáticos
# ---------------------------------------------------------------------------
bpy.ops.object.select_all(action="DESELECT")
corpo.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
grupos = {g.name: g for g in corpo.vertex_groups}
# Limpeza dos braços: o calor ainda "vaza" para os cachos de cabelo ao lado dos ombros.
# Cada braço só pode influenciar vértices dentro de um tubo em volta dos seus ossos;
# dentro do tubo, o braço manda.
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
    fora = np.where((d_braco > 0.09) | (d_braco > d_corpo * 0.85))[0].tolist()
    dentro = np.where((d_braco < 0.065) & (d_braco < d_corpo * 0.7))[0].tolist()
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

# Vértices que ficaram sem peso: osso mais próximo (fora dos braços).
candidatos = [n for n in segmentos if not n.startswith(("UpperArm", "Forearm", "Hand"))]
for vt in malha.vertices:
    if len(vt.groups) == 0:
        mais_perto = min(candidatos, key=lambda n: dist[n][vt.index])
        grupos[mais_perto].add([vt.index], 1.0, "REPLACE")

d_bracos = np.min([dist[n] for n in segmentos if n.startswith(("UpperArm", "Forearm", "Hand"))], axis=0)

# ---------------------------------------------------------------------------
# 3b. Cores de um modelo já pintado (opcional), ainda na pose T
# ---------------------------------------------------------------------------
USAR_MODELO = REFERENCIA.lower().endswith(".glb")
# Ossos "seguintes" (definem a direção de cada osso a partir das cabeças).
SEGUINTE = {"Hips": "Spine", "Spine": "Chest", "Chest": "Neck", "Neck": "Head"}
for lado in ("R", "L"):
    SEGUINTE.update({f"Shoulder.{lado}": f"UpperArm.{lado}", f"UpperArm.{lado}": f"Forearm.{lado}",
                     f"Forearm.{lado}": f"Hand.{lado}", f"Thigh.{lado}": f"Shin.{lado}", f"Shin.{lado}": f"Foot.{lado}"})


def classe_osso(nome):
    if nome.startswith(("UpperArm", "Forearm", "Hand")):
        return "braco_" + nome[-1]
    return "cauda" if nome.startswith("Tail") else "corpo"


def direcoes(cabecas, pais, n_cauda):
    """Direção de cada osso: até a cabeça do osso seguinte; nas pontas, a do pai.
    Devolve {osso: (vetor, é_ponta)}."""
    seguinte = dict(SEGUINTE)
    seguinte.update({f"Tail{i}": f"Tail{i + 1}" for i in range(1, n_cauda)})
    dirs = {}
    for nome in cabecas:
        if nome in seguinte and seguinte[nome] in cabecas:
            dirs[nome] = (cabecas[seguinte[nome]] - cabecas[nome], False)
    for nome in cabecas:
        if nome not in dirs:
            vetor = cabecas[nome] - cabecas[pais[nome]] if pais.get(nome) else np.array([0.0, 1.0, 0.0])
            dirs[nome] = (vetor, True)
    return dirs


def rotacao_entre(a, b):
    """Matriz da menor rotação que leva a direção a até b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(a @ b)
    if np.linalg.norm(v) < 1e-8:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx / (1 + c)


def ler_glb_riggado(caminho):
    """Posições, cores (sRGB), osso dominante e cabeças dos ossos de um GLB exportado por este script."""
    import json, struct
    dados = open(caminho, "rb").read()
    tam_json = struct.unpack("<I", dados[12:16])[0]
    js = json.loads(dados[20:20 + tam_json])
    ini = 20 + tam_json
    binario = dados[ini + 8:ini + 8 + struct.unpack("<I", dados[ini:ini + 4])[0]]

    def acessor(i):
        a = js["accessors"][i]
        bv = js["bufferViews"][a["bufferView"]]
        off = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        tipo = {5121: np.uint8, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}[a["componentType"]]
        n = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[a["type"]]
        return np.frombuffer(binario, dtype=tipo, count=a["count"] * n, offset=off).reshape(a["count"], n)

    prim = js["meshes"][0]["primitives"][0]["attributes"]
    pele = js["skins"][0]
    nomes = [js["nodes"][j]["name"] for j in pele["joints"]]
    ibm = acessor(pele["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
    cabecas = {nome: np.linalg.inv(m)[:3, 3] for nome, m in zip(nomes, ibm)}
    pais = {}
    for j in pele["joints"]:
        for filho in js["nodes"][j].get("children", []):
            pais[js["nodes"][filho]["name"]] = js["nodes"][j]["name"]
    cor = acessor(prim["COLOR_0"])[:, :3].astype(np.float64)
    cor = np.where(cor <= 0.0031308, cor * 12.92, 1.055 * np.power(np.clip(cor, 0, 1), 1 / 2.4) - 0.055)
    juntas = acessor(prim["JOINTS_0"])
    pesos = acessor(prim["WEIGHTS_0"])
    dominante = np.array(nomes)[juntas[np.arange(len(juntas)), pesos.argmax(1)]]
    return acessor(prim["POSITION"]).astype(np.float64), cor, dominante, cabecas, pais


def cores_por_modelo(caminho):
    """Copia a pintura de outro modelo riggado da mesma personagem (mesmos nomes de ossos).

    Cada vértice é levado para o espaço do outro modelo pelo seu osso dominante (posição em
    relação à cabeça do osso, girada para a direção que o osso tem lá) e pega a cor do vértice
    mais próximo que pertence à mesma região (braço direito, braço esquerdo, cauda ou corpo)."""
    from mathutils.kdtree import KDTree
    pos_v, cor_v, dom_v, cab_v, pais_v = ler_glb_riggado(caminho)
    n_cauda_v = sum(1 for n in cab_v if n.startswith("Tail"))
    # Este modelo, no mesmo espaço do GLB exportado (Y para cima, quadril em x=z=0, pés em y=0).
    def para_glb(v):
        return np.array([v[0], v[2], -v[1]])
    cab_n = {nome: para_glb(para_blender(c)) for nome, c, _, _ in JUNTAS}
    pais_n = {nome: pai for nome, _, _, pai in JUNTAS}
    pos_n = np.array([para_glb(vt.co) for vt in malha.vertices])
    dom_n = []
    for vt in malha.vertices:
        g = max(vt.groups, key=lambda g: g.weight, default=None)
        dom_n.append(corpo.vertex_groups[g.group].name if g else "Hips")
    dir_v = direcoes(cab_v, pais_v, n_cauda_v)
    dir_n = direcoes(cab_n, pais_n, N_CAUDA)
    arvores = {}
    for cls in ("braco_R", "braco_L", "cauda", "corpo"):
        idx = np.where([classe_osso(n) == cls for n in dom_v])[0]
        arvore = KDTree(len(idx))
        for k, i in enumerate(idx):
            arvore.insert(pos_v[i], k)
        arvore.balance()
        arvores[cls] = (arvore, idx)
    cores_saida = np.zeros((len(pos_n), 3))
    for nome in cab_n:
        # Cauda com número diferente de ossos: usa o osso na mesma fração do comprimento.
        alvo = nome
        if nome.startswith("Tail"):
            alvo = f"Tail{min(n_cauda_v, max(1, round(int(nome[4:]) * n_cauda_v / N_CAUDA)))}"
        if alvo not in cab_v:
            continue
        sel = np.where(np.array(dom_n) == nome)[0]
        if len(sel) == 0:
            continue
        (vet_n, ponta), (vet_v, _) = dir_n[nome], dir_v[alvo]
        rot = rotacao_entre(vet_n, vet_v)
        # Estica só ao longo do osso (comprimentos diferentes); a grossura fica igual.
        escala = 1.0 if ponta else np.linalg.norm(vet_v) / max(np.linalg.norm(vet_n), 1e-6)
        eixo = vet_n / np.linalg.norm(vet_n)
        rel = pos_n[sel] - cab_n[nome]
        ao_longo = (rel @ eixo)[:, None] * eixo
        estimadas = cab_v[alvo] + (rel + (escala - 1.0) * ao_longo) @ rot.T
        arvore, idx = arvores[classe_osso(nome)]
        for i, p in zip(sel, estimadas):
            _, k, _ = arvore.find(p)
            cores_saida[i] = cor_v[idx[k]]
    return cores_saida


if USAR_MODELO:
    cores_modelo = cores_por_modelo(REFERENCIA)
    print("cores copiadas de", REFERENCIA)

# ---------------------------------------------------------------------------
# 4. Pose T -> pose A (vira a pose de repouso)
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


pose.bones["UpperArm.R"].rotation_quaternion = rot_mundo("UpperArm.R", Y, -DESCIDA_BRACO)
pose.bones["UpperArm.L"].rotation_quaternion = rot_mundo("UpperArm.L", Y, DESCIDA_BRACO)
# Cotovelo levemente dobrado para a frente, como numa pose relaxada.
pose.bones["Forearm.R"].rotation_quaternion = rot_mundo("Forearm.R", X, -8)
pose.bones["Forearm.L"].rotation_quaternion = rot_mundo("Forearm.L", X, -8)
bpy.context.view_layer.update()
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = corpo
corpo.select_set(True)
nome_mod = next(m.name for m in corpo.modifiers if m.type == "ARMATURE")
bpy.ops.object.modifier_apply(modifier=nome_mod)
corpo.select_set(False)
bpy.context.view_layer.objects.active = arm
arm.select_set(True)
bpy.ops.object.mode_set(mode="POSE")
bpy.ops.pose.armature_apply(selected=False)
bpy.ops.object.mode_set(mode="OBJECT")
mod = corpo.modifiers.new("Armature", "ARMATURE")
mod.object = arm
for pb in pose.bones:
    pb.rotation_quaternion = Quaternion()

# ---------------------------------------------------------------------------
# 5. Cores (pintura copiada de outro modelo ou projeção da referência), já na pose A
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


def cores_por_referencia(caminho):
    """Projeta a imagem de referência pela frente; atrás da cabeça e nas costas vira cabelo."""
    img = np.asarray(Image.open(caminho).convert("RGB")).astype(np.float64) / 255.0
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
    eh_cabelo = costas & (((gy > 0.24) & centro_tronco) | (gy > 0.66))
    orelha = gy > 0.91
    eh_cabelo &= ~orelha
    cores[eh_cabelo] = CABELO * (0.85 + 0.15 * np.clip(-nz_frente[eh_cabelo], 0, 1))[:, None]
    # Realça a saturação (visual de anime).
    cinza = cores.mean(1, keepdims=True)
    return np.clip(cinza + (cores - cinza) * 1.1, 0, 1)


cores = cores_modelo if USAR_MODELO else cores_por_referencia(REFERENCIA)
# Cabelo (para os pesos): vermelho forte acima do quadril.
r, g = cores[:, 0], cores[:, 1]
eh_cabelo = (r > 0.45) & (g / np.maximum(r, 1e-3) < 0.38) & (gy > 0.15)

# Grava como atributo de cor por vértice (sRGB).
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

# Cabelo segue cabeça/peito (senão os cachos laterais acompanham os braços).
# Só fora do tubo dos braços (medido na pose T, onde braço e cabelo estão separados).
eh_cabelo &= d_bracos > 0.06
idx_cabelo = np.where(eh_cabelo)[0].tolist()
for g in corpo.vertex_groups:
    g.remove(idx_cabelo)
alto = [i for i in idx_cabelo if gy[i] >= 0.66]
baixo = [i for i in idx_cabelo if gy[i] < 0.66]
# (Busca os grupos de novo: as referências antigas não valem mais depois de aplicar o modificador.)
corpo.vertex_groups["Head"].add(alto, 1.0, "REPLACE")
corpo.vertex_groups["Chest"].add(baixo, 1.0, "REPLACE")
print("vertices de cabelo:", len(idx_cabelo), "sem peso:", sum(1 for vt in malha.vertices if len(vt.groups) == 0))

# ---------------------------------------------------------------------------
# 6. Animações
# ---------------------------------------------------------------------------
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
    return {f"Tail{i}": [(Z, amp * math.sin(fase + i * 0.7))] for i in range(1, N_CAUDA + 1)}


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
# 7. Exportar
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
