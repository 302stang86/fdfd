"""Generate the Fire Defense Field Day urban-map barrier models.

Run from the project folder with Blender 4.0 or newer:

    blender -b --python blender/make_urban_props.py -- assets/models

Axes: each model is built with its length along Blender +Y, its thickness along
X and "up" along Z. The glTF exporter turns that into Godot's Y-up layout, with
the length running along Godot's Z axis, which is what urban_border.gd expects.

Wall-style models are one "bay" long (BAY metres). urban_border.gd tiles and
stretches them to fit each wall segment. The car wreck is placed unstretched.
"""
import math
import os
import random
import sys

import bpy  # noqa: F401  (must come first: it registers bmesh)
import bmesh
from mathutils import Euler, Matrix, Vector

BAY = 6.0
WALL_HEIGHT = 3.5


def srgb(hex_color):
    """Convert '#rrggbb' (sRGB, as used in Godot) to a linear RGBA tuple."""
    hex_color = hex_color.lstrip("#")
    channels = [int(hex_color[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return (linear[0], linear[1], linear[2], 1.0)


_materials = {}


def material(name, hex_color, roughness=0.9, metallic=0.0):
    if name in _materials:
        return _materials[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    _materials[name] = mat
    return mat


class Builder:
    """Collects geometry per material and bakes it into a single mesh object."""

    def __init__(self, name):
        self.name = name
        self.parts = {}

    def _bm(self, mat):
        if mat.name not in self.parts:
            self.parts[mat.name] = (mat, bmesh.new())
        return self.parts[mat.name][1]

    def box(self, center, size, mat, rot=(0.0, 0.0, 0.0), jitter=0.0, rng=None):
        bm = self._bm(mat)
        result = bmesh.ops.create_cube(bm, size=1.0)
        verts = result["verts"]
        if jitter and rng:
            for v in verts:
                v.co += Vector((rng.uniform(-jitter, jitter), rng.uniform(-jitter, jitter),
                                rng.uniform(-jitter, jitter)))
        matrix = (Matrix.Translation(center)
                  @ Euler(rot, "XYZ").to_matrix().to_4x4()
                  @ Matrix.Diagonal(Vector(size).to_4d()))
        bmesh.ops.transform(bm, matrix=matrix, verts=verts)

    def bar(self, start, end, thickness, mat):
        """A thin square bar running from start to end."""
        start, end = Vector(start), Vector(end)
        direction = end - start
        length = direction.length
        if length < 1e-4:
            return
        bm = self._bm(mat)
        result = bmesh.ops.create_cube(bm, size=1.0)
        quat = Vector((0, 0, 1)).rotation_difference(direction.normalized())
        matrix = (Matrix.Translation((start + end) * 0.5)
                  @ quat.to_matrix().to_4x4()
                  @ Matrix.Diagonal(Vector((thickness, thickness, length, 1.0))))
        bmesh.ops.transform(bm, matrix=matrix, verts=result["verts"])

    def cylinder(self, center, radius, depth, mat, axis="Z", segments=10):
        bm = self._bm(mat)
        result = bmesh.ops.create_cone(bm, cap_ends=True, segments=segments,
                                       radius1=radius, radius2=radius, depth=depth)
        rotation = {"Z": Matrix.Identity(4),
                    "X": Matrix.Rotation(math.radians(90), 4, "Y"),
                    "Y": Matrix.Rotation(math.radians(90), 4, "X")}[axis]
        bmesh.ops.transform(bm, matrix=Matrix.Translation(center) @ rotation, verts=result["verts"])

    def finish(self):
        mesh = bpy.data.meshes.new(self.name)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        merged = bmesh.new()
        slot_of = {}
        for index, (mat, bm) in enumerate(self.parts.values()):
            mesh.materials.append(mat)
            slot_of[mat.name] = index
            offset = len(merged.faces)
            temp = bpy.data.meshes.new("tmp")
            bm.to_mesh(temp)
            bm.free()
            merged.from_mesh(temp)
            bpy.data.meshes.remove(temp)
            merged.faces.ensure_lookup_table()
            for face in merged.faces[offset:]:
                face.material_index = index
        merged.to_mesh(mesh)
        merged.free()
        for poly in mesh.polygons:
            poly.use_smooth = False
        return obj


def chain_link(b, length, bottom, top, steel, wire, post_every=3.0):
    """Posts, rails and a diamond wire lattice between heights bottom and top."""
    half = length * 0.5
    posts = max(2, int(round(length / post_every)) + 1)
    for i in range(posts):
        y = -half + 0.03 + i * (length - 0.06) / (posts - 1)
        b.cylinder((0, y, top * 0.5), 0.045, top, steel, segments=8)
    for z in (bottom, top - 0.045):
        b.cylinder((0, 0, z), 0.032, length, steel, axis="Y", segments=8)
    if top - bottom > 2.2:
        b.cylinder((0, 0, (top + bottom) * 0.5), 0.02, length, steel, axis="Y", segments=6)
    lo, hi = bottom + 0.04, top - 0.07
    rise = hi - lo
    spacing = 0.25
    count = int((length + rise) / spacing) + 1
    for mirror in (1, -1):
        for i in range(count):
            y0 = -half - rise + i * spacing  # where the bar meets the bottom edge
            y1 = y0 + rise  # where it meets the top edge
            ya, za = y0, lo
            yb, zb = y1, hi
            if ya < -half:
                za, ya = lo + (-half - y0), -half
            if yb > half:
                zb, yb = hi - (y1 - half), half
            if yb - ya < 0.03:
                continue
            b.bar((0, mirror * ya, za), (0, mirror * yb, zb), 0.012, wire)


def build_chain_link_fence():
    b = Builder("chain_link_fence")
    steel = material("steel_post", "#6f858c", 0.45, 0.7)
    wire = material("wire", "#9aaeb1", 0.5, 0.8)
    chain_link(b, BAY + 0.06, 0.08, WALL_HEIGHT, steel, wire)
    # a few cable-ties / tension clamps so it doesn't read as a flat grid
    for y in (-2.2, 0.0, 2.2):
        b.box((0.0, y, WALL_HEIGHT - 0.35), (0.07, 0.05, 0.05), steel)
    return b.finish()


def build_wood_fence():
    b = Builder("wood_fence")
    rng = random.Random(7)
    shades = [material("plank_a", "#775545", 0.95), material("plank_b", "#866252", 0.95),
              material("plank_c", "#654638", 0.95)]
    rail = material("plank_rail", "#9a7357", 0.9)
    steel = material("steel_post", "#6f858c", 0.45, 0.7)
    wire = material("wire", "#9aaeb1", 0.5, 0.8)
    planks = 14
    spacing = (BAY + 0.06) / planks
    for i in range(planks):
        height = 1.62 + (i % 5) * 0.048 + rng.uniform(-0.03, 0.03)
        lean = rng.uniform(-0.015, 0.015)
        b.box((0, -BAY / 2 - 0.03 + spacing * (i + 0.5), height * 0.5),
              (0.14, spacing * 0.94, height), shades[i % 3], rot=(lean, 0, 0))
    for z in (0.48, 1.36):
        b.box((0.11, 0, z), (0.1, BAY + 0.06, 0.095), rail)
    for y in (-BAY / 2 + 0.05, 0.0, BAY / 2 - 0.05):
        b.box((0, y, 0.95), (0.27, 0.16, 1.9), rail)
    chain_link(b, BAY + 0.06, 1.62, WALL_HEIGHT, steel, wire)
    return b.finish()


def build_building(name, brick, trim, boarded):
    b = Builder(name)
    rng = random.Random(3 if boarded else 11)
    wall = material(name + "_wall", brick, 0.95)
    plinth = material(name + "_plinth", "#484b4f", 0.95)
    stone = material(name + "_trim", trim, 0.9)
    glass = material("glass", "#354950", 0.15, 0.1)
    frame = material("window_frame", "#2c3338", 0.6, 0.4)
    wood = material("board", "#8a6a50", 0.95)
    pipe = material("drain_pipe", "#3d4448", 0.5, 0.6)
    unit = material("ac_unit", "#9fa7a8", 0.6, 0.4)
    length = BAY + 0.12  # slight overlap so tiled bays never show a seam
    b.box((0, 0, 1.9), (1.55, length, 3.8), wall)
    b.box((0, 0, 0.32), (1.66, length, 0.64), plinth)
    b.box((0, 0, 3.73), (1.73, length + 0.08, 0.19), stone)
    b.box((0, 0, 3.52), (1.62, length, 0.08), stone)
    for side in (-1, 1):
        x = 0.775 * side
        for y in (-1.5, 1.5):
            for z, tall in ((1.55, 0.95), (2.75, 0.95)):
                if boarded and rng.random() < 0.55:
                    b.box((x + 0.012 * side, y, z), (0.05, 1.22, tall + 0.1), frame)
                    for k in range(4):
                        pz = z - tall * 0.5 + 0.1 + k * (tall - 0.05) / 3
                        b.box((x + 0.035 * side, y, pz), (0.04, 1.2, 0.2), wood,
                              rot=(rng.uniform(-0.07, 0.07), 0, 0))
                else:
                    b.box((x + 0.005 * side, y, z), (0.05, 1.22, tall), glass)
                    b.box((x + 0.02 * side, y, z), (0.05, 0.05, tall), frame)
                    b.box((x + 0.02 * side, y, z), (0.05, 1.22, 0.05), frame)
                    b.box((x + 0.035 * side, y, z - tall * 0.5 - 0.05), (0.14, 1.4, 0.09), stone)
                    b.box((x + 0.02 * side, y, z + tall * 0.5 + 0.05), (0.07, 1.36, 0.1), stone)
        # drainpipe where two bays meet, and a roof-line gutter
        b.cylinder((0.84 * side, BAY / 2 - 0.12, 1.9), 0.05, 3.7, pipe, segments=8)
    if not boarded:
        b.box((0.9, 1.5, 0.95), (0.35, 0.9, 0.55), unit)
        b.cylinder((1.1, 1.5, 0.95), 0.2, 0.06, frame, axis="X", segments=12)
    return b.finish()


def build_rubble():
    b = Builder("rubble_pile")
    rng = random.Random(21)
    concrete = [material("rubble_a", "#777572", 0.98), material("rubble_b", "#8a8782", 0.98),
                material("rubble_c", "#62605d", 0.98)]
    brick = material("rubble_brick", "#8c5b4a", 0.95)
    rebar = material("rebar", "#5b4b3f", 0.6, 0.6)
    pieces = 16
    for i in range(pieces):
        y = -BAY / 2 + (i + 0.5) * BAY / pieces + rng.uniform(-0.12, 0.12)
        size = 0.45 + (i % 4) * 0.17 + rng.uniform(0.0, 0.12)
        x = rng.uniform(-0.45, 0.45)
        mat = brick if i % 5 == 0 else concrete[i % 3]
        b.box((x, y, size * 0.4), (size, size * 1.34, size * 0.86), mat,
              rot=(i * 0.24, i * 1.13, i * 0.38), jitter=0.07 * size, rng=rng)
    for i in range(7):  # smaller debris filling the gaps
        y = rng.uniform(-BAY / 2, BAY / 2)
        s = rng.uniform(0.14, 0.3)
        b.box((rng.uniform(-0.7, 0.7), y, s * 0.4), (s, s * 1.2, s * 0.8),
              concrete[i % 3], rot=(rng.random() * 3, rng.random() * 3, rng.random() * 3),
              jitter=0.02, rng=rng)
    for i in range(6):  # bent rebar poking out of the heap
        y = rng.uniform(-BAY / 2 + 0.4, BAY / 2 - 0.4)
        x = rng.uniform(-0.3, 0.3)
        tilt = Vector((rng.uniform(-0.45, 0.45), rng.uniform(-0.45, 0.45), 1.0)).normalized()
        base = Vector((x, y, 0.45))
        b.bar(base, base + tilt * rng.uniform(0.7, 1.15), 0.035, rebar)
    return b.finish()


def build_car_wreck():
    b = Builder("car_wreck")
    paint = material("car_paint", "#80503c", 0.7, 0.2)
    dark = material("car_dark", "#52423e", 0.8, 0.2)
    glass = material("car_glass", "#334850", 0.15, 0.2)
    tire = material("tire", "#242629", 0.95)
    rim = material("rim", "#8a8f93", 0.4, 0.8)
    soot = material("soot", "#1d1b1a", 0.95)
    # chassis and lower body, rolled slightly like the original blockout
    b.box((0, 0, 0.52), (1.55, 3.1, 0.64), paint, rot=(0.0, 0.08, 0.0))
    b.box((0, 0, 0.26), (1.35, 2.9, 0.2), soot)
    # cabin (roof sagging toward the rear)
    b.box((0, -0.15, 1.02), (1.28, 1.52, 0.49), dark, rot=(0.04, 0.0, 0.0))
    for side in (-1, 1):
        b.box((0.645 * side, -0.15, 1.04), (0.03, 1.22, 0.32), glass)
    b.box((0, -0.93, 1.02), (1.16, 0.04, 0.3), glass)
    b.box((0, 0.625, 1.02), (1.16, 0.045, 0.3), glass, rot=(0.3, 0.0, 0.0))
    # crumpled, popped hood and a detached bumper
    b.box((0, 1.15, 0.9), (1.45, 0.95, 0.07), paint, rot=(0.0, 0.38, 0.0))
    b.box((0.1, 1.62, 0.34), (1.5, 0.12, 0.2), dark, rot=(0.0, 0.0, 0.12))
    b.box((0, 1.5, 0.55), (1.3, 0.2, 0.3), soot)
    b.box((-0.1, -1.62, 0.34), (1.5, 0.14, 0.2), dark)
    # wheels (rear-left is missing, front-right is flat)
    for sx in (-1, 1):
        for sy in (-1.02, 1.02):
            if sx == -1 and sy < 0:
                continue
            flat = sx == 1 and sy > 0
            radius = 0.25 if flat else 0.31
            b.cylinder((0.73 * sx, sy, radius), radius, 0.26, tire, axis="X", segments=12)
            b.cylinder((0.73 * sx + 0.13 * sx, sy, radius), radius * 0.55, 0.05, rim, axis="X",
                       segments=10)
    return b.finish()


def export(obj, out_dir, file_name):
    for other in bpy.context.scene.objects:
        other.select_set(other == obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, file_name),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    print("exported", file_name, "verts:", len(obj.data.vertices), "tris:",
          sum(len(p.vertices) - 2 for p in obj.data.polygons))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[0] if argv else "assets/models")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    models = [
        ("building_brick.glb", lambda: build_building("building_brick", "#66686c", "#9b9790", False)),
        ("building_boarded.glb", lambda: build_building("building_boarded", "#5e5855", "#8a857c", True)),
        ("chain_link_fence.glb", build_chain_link_fence),
        ("wood_fence.glb", build_wood_fence),
        ("rubble_pile.glb", build_rubble),
        ("car_wreck.glb", build_car_wreck),
    ]
    for file_name, factory in models:
        obj = factory()
        export(obj, out_dir, file_name)
        bpy.data.objects.remove(obj)


if __name__ == "__main__":
    main()
