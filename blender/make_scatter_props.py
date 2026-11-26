"""Model the grass clumps and rubble chunks that the game scatters over the ground.

Run from the project folder (Blender 4.0 or newer, or the `bpy` pip module):

    python blender/make_scatter_props.py assets/models/scatter

Grass: four distinct multi-blade clumps. Each blade is a tapered strip with five edge
loops, bent gently, with a vertex-colour gradient from deep olive at the base through
warm green to dry straw at the tip. Origin is at the base of the clump and the tallest
blade is CLUMP_HEIGHT metres, so the game can scale a clump to any grass height.

Rubble: five angular chunk variants (blocks, a slab, a wedge, a shard, a small pile) with
bevelled edges and grey / brick vertex colours.

The scatter itself (noise-masked patches, Z-only rotation for grass, free rotation and a
slight sink for rubble) is done at load time in arena_scenery.gd.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must come first: it registers bmesh)
import bmesh
from mathutils import Euler, Matrix, Vector

CLUMP_HEIGHT = 0.5
BLADE_LOOPS = 5


def srgb_to_linear(hex_color):  # name kept; see note below
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c)  # stored as-is: this exporter + Godot show these values far darker if linearised first
    return Vector(out)


def mix(a, b, t):
    return a * (1.0 - t) + b * t


def vertex_colour_material():
    mat = bpy.data.materials.new("scatter_vertex_colour")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Col"
    mat.node_tree.links.new(colour.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


def new_object(name, bm, mat):
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def add_blade(bm, col_layer, rng, base, yaw, height, width, bend, lean, tint):
    """One tapered, gently bent blade: BLADE_LOOPS rows of two vertices and a point at the tip."""
    forward = Vector((math.cos(yaw), math.sin(yaw), 0.0))
    across = Vector((-forward.y, forward.x, 0.0))
    outward = Vector((base.x, base.y, 0.0))
    outward = outward.normalized() if outward.length > 1e-4 else forward
    olive = srgb_to_linear("#4a6a30")
    green = srgb_to_linear("#7fa845")
    straw = srgb_to_linear("#cdbd7c")
    rows = []
    for i in range(BLADE_LOOPS):
        t = i / BLADE_LOOPS
        half = width * 0.5 * (1.0 - t ** 1.6)
        centre = (base + forward * (bend * height * t * t) + outward * (lean * height * t)
                  + Vector((0, 0, height * (1.0 - 0.18 * t * t) * t)))
        rows.append(([bm.verts.new(centre - across * half), bm.verts.new(centre + across * half)], t))
    tip_t = 1.0
    tip = base + forward * (bend * height) + outward * (lean * height) + Vector((0, 0, height * 0.82))
    rows.append(([bm.verts.new(tip)], tip_t))

    def colour(t):
        c = mix(olive, green, min(t * 1.5, 1.0))
        c = mix(c, straw, max(0.0, (t - 0.62) / 0.38) * tint)
        return (c.x, c.y, c.z, 1.0)

    def make_face(verts, ts):
        try:
            face = bm.faces.new(verts)
        except ValueError:
            return
        for loop, t in zip(face.loops, ts):
            loop[col_layer] = colour(t)

    for (a, ta), (b, tb) in zip(rows[:-1], rows[1:]):
        if len(b) == 2:
            make_face([a[0], a[1], b[1], b[0]], [ta, ta, tb, tb])
        else:
            make_face([a[0], a[1], b[0]], [ta, ta, tb])


def build_grass_clump(name, seed, blades, spread, bend_range, mat):
    rng = random.Random(seed)
    bm = bmesh.new()
    col = bm.loops.layers.color.new("Col")
    for _ in range(blades):
        angle = rng.random() * math.tau
        radius = spread * math.sqrt(rng.random())
        base = Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0.0))
        height = CLUMP_HEIGHT * rng.uniform(0.55, 1.0)
        add_blade(bm, col, rng, base, rng.random() * math.tau, height,
                  rng.uniform(0.035, 0.06), rng.uniform(*bend_range), rng.uniform(0.05, 0.28),
                  rng.uniform(0.4, 1.0))
    tallest = max(v.co.z for v in bm.verts)
    bmesh.ops.scale(bm, vec=Vector((1, 1, CLUMP_HEIGHT / tallest)), verts=bm.verts)
    return new_object(name, bm, mat)


def rock_colour(rng, base_hex, spread):
    base = srgb_to_linear(base_hex)
    shade = 1.0 + rng.uniform(-spread, spread)
    return (base.x * shade, base.y * shade, base.z * shade, 1.0)


def finish_rock(bm, rng, base_hex, jitter, spread=0.18):
    for v in bm.verts:
        v.co += Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter),
                        rng.uniform(-jitter, jitter)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    try:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.012, segments=1, affect="EDGES")
    except Exception:
        pass
    col = bm.loops.layers.color.verify()
    lowest = min(v.co.z for v in bm.verts)
    for face in bm.faces:
        face_colour = rock_colour(rng, base_hex, spread)
        for loop in face.loops:
            low = 0.78 + 0.22 * min(1.0, max(0.0, (loop.vert.co.z - lowest) / 0.12))
            loop[col] = (face_colour[0] * low, face_colour[1] * low, face_colour[2] * low, 1.0)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -lowest)), verts=bm.verts)  # sit on z = 0


def box_chunk(bm, centre, size, rot):
    res = bmesh.ops.create_cube(bm, size=1.0)
    matrix = (Matrix.Translation(centre) @ Euler(rot, "XYZ").to_matrix().to_4x4()
              @ Matrix.Diagonal(Vector(size).to_4d()))
    bmesh.ops.transform(bm, matrix=matrix, verts=res["verts"])
    return res["verts"]


def build_rock(name, seed, kind, base_hex, mat):
    rng = random.Random(seed)
    bm = bmesh.new()
    if kind == "block":
        box_chunk(bm, Vector((0, 0, 0.1)), (0.26, 0.2, 0.18), (0.1, 0.05, rng.random()))
    elif kind == "slab":
        box_chunk(bm, Vector((0, 0, 0.03)), (0.42, 0.3, 0.06), (0.06, 0.1, rng.random()))
    elif kind == "wedge":
        verts = box_chunk(bm, Vector((0, 0, 0.1)), (0.3, 0.22, 0.2), (0.0, 0.0, rng.random()))
        for v in verts:
            if v.co.z > 0.1:
                v.co.x *= 0.25
    elif kind == "shard":
        box_chunk(bm, Vector((0, 0, 0.13)), (0.07, 0.3, 0.1), (0.5, 0.2, rng.random()))
    else:  # small pile
        for i in range(4):
            a = rng.random() * math.tau
            r = rng.uniform(0.0, 0.14)
            s = rng.uniform(0.08, 0.17)
            box_chunk(bm, Vector((math.cos(a) * r, math.sin(a) * r, s * 0.45)),
                      (s, s * 1.2, s * 0.9), (rng.random(), rng.random(), rng.random() * 3))
    finish_rock(bm, rng, base_hex, 0.018)
    return new_object(name, bm, mat)


def export(obj, out_dir, file_name):
    for other in bpy.context.scene.objects:
        other.select_set(other == obj)
    bpy.context.view_layer.objects.active = obj
    kwargs = dict(filepath=os.path.join(out_dir, file_name), export_format="GLB", use_selection=True,
                  export_apply=True, export_yup=True, export_materials="EXPORT",
                  export_cameras=False, export_lights=False)
    bpy.ops.export_scene.gltf(**kwargs)
    print("exported", file_name, "tris:", sum(len(p.vertices) - 2 for p in obj.data.polygons))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out_dir = os.path.abspath(argv[0] if argv else "assets/models/scatter")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = vertex_colour_material()
    items = [
        ("grass_clump_a.glb", lambda: build_grass_clump("grass_clump_a", 11, 7, 0.10, (0.15, 0.45), mat)),
        ("grass_clump_b.glb", lambda: build_grass_clump("grass_clump_b", 23, 9, 0.13, (0.05, 0.30), mat)),
        ("grass_clump_c.glb", lambda: build_grass_clump("grass_clump_c", 37, 6, 0.08, (0.25, 0.60), mat)),
        ("grass_clump_d.glb", lambda: build_grass_clump("grass_clump_d", 51, 8, 0.12, (0.10, 0.40), mat)),
        ("rubble_block.glb", lambda: build_rock("rubble_block", 3, "block", "#7b7873", mat)),
        ("rubble_slab.glb", lambda: build_rock("rubble_slab", 5, "slab", "#8a8780", mat)),
        ("rubble_wedge.glb", lambda: build_rock("rubble_wedge", 7, "wedge", "#6d6a66", mat)),
        ("rubble_shard.glb", lambda: build_rock("rubble_shard", 9, "shard", "#8c5f4d", mat)),
        ("rubble_pile.glb", lambda: build_rock("rubble_pile", 13, "pile", "#757370", mat)),
    ]
    for file_name, factory in items:
        obj = factory()
        export(obj, out_dir, file_name)
        bpy.data.objects.remove(obj)


if __name__ == "__main__":
    main()
