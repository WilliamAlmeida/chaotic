"""
Renderiza a malha "crua" (cinza, sem cor) em vistas ortográficas para pintura externa
(ex.: pedir para um gerador de imagem pintar por cima), com enquadramento fixo e conhecido,
para depois projetar as imagens pintadas de volta no modelo.

Uso (Blender como módulo Python):
    python renderizar_vistas.py <entrada.glb> <pasta_saida>

Gera: frente.png, costas.png, esquerda.png, direita.png (1536x2048), folha.png (as 4 lado a lado)
e enquadramento.json (pixels por metro e centro de cada vista).
"""
import json
import math
import os
import sys

import bpy  # noqa: I001 (bpy precisa vir antes do bmesh)
import bmesh
import numpy as np
from mathutils import Vector

ENTRADA, PASTA = sys.argv[-2:]
os.makedirs(PASTA, exist_ok=True)

# Mesmo centro/chão do riggar_modelo.py, para as vistas baterem com o modelo riggado.
CENTRO_X, CENTRO_Z_GLTF, CHAO_Y = -0.07, 0.19, -0.997


def para_blender(p):
    x, y, z = p
    return Vector((x - CENTRO_X, -(z - CENTRO_Z_GLTF), y - CHAO_Y))


def ler_glb(caminho):
    import struct
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

LARGURA, ALTURA = 1536, 2048
ESCALA_ORTO = 2.2  # metros visíveis na altura da imagem
CENTRO_Z = 1.0      # altura (m) no centro da imagem

bpy.ops.wm.read_factory_settings(use_empty=True)
pos, faces = ler_glb(ENTRADA)
malha = bpy.data.meshes.new("Corpo")
malha.from_pydata([tuple(para_blender(p)) for p in pos], [], faces.tolist())
bm = bmesh.new()
bm.from_mesh(malha)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(malha)
bm.free()
for p in malha.polygons:
    p.use_smooth = True
obj = bpy.data.objects.new("Corpo", malha)
bpy.context.collection.objects.link(obj)

mat = bpy.data.materials.new("Argila")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.55, 0.55, 0.57, 1.0)
bsdf.inputs["Roughness"].default_value = 0.85
obj.data.materials.append(mat)

cena = bpy.context.scene
cena.render.engine = "CYCLES"
cena.cycles.device = "CPU"
cena.cycles.samples = 24
cena.cycles.use_denoising = True
cena.render.resolution_x = LARGURA
cena.render.resolution_y = ALTURA
cena.render.film_transparent = False
cena.view_settings.view_transform = "Standard"
mundo = bpy.data.worlds.new("Mundo")
mundo.use_nodes = True
mundo.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.57, 0.6, 1.0)
mundo.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
cena.world = mundo

luz_dados = bpy.data.lights.new("Sol", "SUN")
luz_dados.energy = 1.6
luz = bpy.data.objects.new("Sol", luz_dados)
bpy.context.collection.objects.link(luz)

cam_dados = bpy.data.cameras.new("Camera")
cam_dados.type = "ORTHO"
cam_dados.ortho_scale = ESCALA_ORTO
cam = bpy.data.objects.new("Camera", cam_dados)
bpy.context.collection.objects.link(cam)
cena.camera = cam

# Blender: frente do personagem = -Y, esquerda do personagem = +X.
VISTAS = {
    "frente": Vector((0, -6, CENTRO_Z)),
    "costas": Vector((0, 6, CENTRO_Z)),
    "esquerda": Vector((6, 0, CENTRO_Z)),   # lado esquerdo do personagem
    "direita": Vector((-6, 0, CENTRO_Z)),   # lado direito do personagem
}
for nome, posicao in VISTAS.items():
    cam.location = posicao
    direcao = Vector((0, 0, CENTRO_Z)) - posicao
    cam.rotation_euler = direcao.to_track_quat("-Z", "Y").to_euler()
    luz.location = posicao + Vector((0, 0, 3))
    luz.rotation_euler = (direcao + Vector((0.3, 0.2, -1.2))).to_track_quat("-Z", "Y").to_euler()
    cena.render.filepath = os.path.join(PASTA, nome + ".png")
    bpy.ops.render.render(write_still=True)
    print("renderizado:", nome)

px_por_metro = ALTURA / ESCALA_ORTO
json.dump({
    "largura": LARGURA, "altura": ALTURA, "px_por_metro": px_por_metro,
    "centro_px": [LARGURA / 2, ALTURA / 2], "centro_altura_m": CENTRO_Z,
    "vistas": {
        "frente": "horizontal = +X do Blender (esquerda do personagem à direita da imagem)",
        "costas": "horizontal = -X",
        "esquerda": "horizontal = +Y (costas do personagem à direita da imagem)",
        "direita": "horizontal = -Y",
    },
}, open(os.path.join(PASTA, "enquadramento.json"), "w"), indent=2, ensure_ascii=False)

# Folha com as 4 vistas lado a lado (3072x1024).
from PIL import Image  # noqa: E402
folha = Image.new("RGB", (LARGURA * 2, ALTURA // 2))
for i, nome in enumerate(["frente", "direita", "costas", "esquerda"]):
    img = Image.open(os.path.join(PASTA, nome + ".png")).convert("RGB").resize((LARGURA // 2, ALTURA // 2))
    folha.paste(img, (i * LARGURA // 2, 0))
folha.save(os.path.join(PASTA, "folha.png"))
print("ok")
