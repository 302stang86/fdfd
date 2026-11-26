"""Climbable props (each has a ladder up to a standable top) for Fire Defense Field Day.

Run with Blender 4.0+ (or the bpy pip module) from the project folder:

    python blender/make_climb_props.py assets/models/climb

Every coordinate below is written in Godot terms: x across, y up, z along (front is -z).
The `G` wrapper converts to Blender's axes; the glTF exporter converts back.
Heights follow the design list (box truck roof 2.8 m, container 2.6 m, ...). The matching
collision boxes and ladder positions live in street_props.gd (CLIMB); keep them in sync.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401,E402
from make_urban_props import Builder, material, export  # noqa: E402

STEEL = ("ladder_steel", "#c9a227", 0.5, 0.6)


class G(Builder):
    def gbox(self, c, s, mat):
        self.box((c[0], -c[2], c[1]), (s[0], s[2], s[1]), mat)

    def gbar(self, a, b, t, mat):
        self.bar((a[0], -a[2], a[1]), (b[0], -b[2], b[1]), t, mat)

    def gcyl(self, c, r, h, mat, axis="Y", seg=14):
        self.cylinder((c[0], -c[2], c[1]), r, h, mat, axis={"Y": "Z", "X": "X", "Z": "Y"}[axis], segments=seg)

    def ladder(self, at, normal, top):
        """Rails and rungs on the face point `at` (x, z), facing outward along `normal`."""
        mat = material(*STEEL)
        nx, nz = normal
        tx, tz = -nz, nx
        def p(side, y):
            return (at[0] + nx * 0.08 + tx * side, y, at[1] + nz * 0.08 + tz * side)
        for side in (-0.22, 0.22):
            self.gbar(p(side, 0.0), p(side, top + 0.9), 0.05, mat)
        y = 0.25
        while y < top + 0.7:
            self.gbar(p(-0.22, y), p(0.22, y), 0.035, mat)
            y += 0.3


def mats():
    return {k: material(k, *v) for k, v in {
        "red": ("#9b3a2e", 0.7, 0.3), "blue": ("#2f5b8a", 0.7, 0.3), "dark": ("#2a2c2e", 0.8, 0.2),
        "white": ("#dcdcd6", 0.6, 0.2), "tire": ("#202225", 0.95, 0.0), "rim": ("#9aa0a4", 0.4, 0.8),
        "concrete": ("#8f908c", 0.95, 0.0), "brick": ("#8a4f3e", 0.95, 0.0), "wood": ("#a98456", 0.95, 0.0),
        "olive": ("#5b6650", 0.7, 0.3), "green": ("#2f5a3e", 0.7, 0.4), "grey": ("#7d8588", 0.6, 0.5),
        "yellow": ("#d9a92a", 0.6, 0.2), "glass": ("#3a5560", 0.15, 0.2), "dirt": ("#4a3626", 0.95, 0.0),
        "leaf": ("#4d8a3c", 0.9, 0.0), "orange": ("#d9631f", 0.6, 0.2), "rust": ("#6a3f2a", 0.9, 0.2),
    }.items()}


def wheels(b, m, ys, x, r=0.4, z_list=()):
    for z in z_list:
        for sx in (-1, 1):
            b.gcyl((sx * x, r, z), r, 0.3, m["tire"], axis="X")
            b.gcyl((sx * (x + 0.16), r, z), r * 0.55, 0.05, m["rim"], axis="X", seg=10)


def box_truck_climb():
    b, m = G("box_truck_climb"), mats()
    b.gbox((0, 0.35, 0), (2.3, 0.3, 6.5), m["dark"])
    b.gbox((0, 1.75, 0.5), (2.4, 2.1, 4.7), m["white"])
    for sx in (-1, 1):
        b.gbox((sx * 1.21, 1.2, 0.5), (0.02, 0.22, 4.7), m["red"])
    b.gbox((0, 1.1, -2.3), (2.3, 1.4, 1.6), m["grey"])
    b.gbox((0, 1.95, -2.5), (2.2, 0.9, 1.2), m["grey"])
    b.gbox((0, 1.95, -3.12), (2.0, 0.62, 0.04), m["glass"])
    wheels(b, m, None, 1.0, z_list=(-2.2, 1.0, 2.0))
    b.ladder((0, 2.85), (0, 1), 2.8)
    return b.finish()


def container(name, length, colour):
    b, m = G(name), mats()
    H, W = 2.6, 2.44
    b.gbox((0, H / 2, 0), (W, H, length), m[colour])
    b.gbox((0, H + 0.02, 0), (W + 0.04, 0.04, length + 0.04), m["dark"])
    z = -length / 2 + 0.3
    while z < length / 2 - 0.2:
        for sx in (-1, 1):
            b.gbox((sx * (W / 2 + 0.015), H / 2, z), (0.03, H - 0.25, 0.12), m["dark"])
        z += 0.34
    for sx in (-1, 1):
        b.gbar((sx * 0.5, 0.15, -length / 2 - 0.03), (sx * 0.5, H - 0.15, -length / 2 - 0.03), 0.06, m["grey"])
    b.ladder((0, length / 2), (0, 1), H)
    return b.finish()


def dumpster_climb():
    b, m = G("dumpster_climb"), mats()
    b.gbox((0, 0.7, 0), (1.4, 1.0, 2.0), m["green"])
    b.gbox((0, 1.45 - 0.04, 0), (1.44, 0.08, 2.04), m["dark"])  # closed lid
    b.gbox((0, 1.25, 0), (1.44, 0.4, 2.04), m["green"])
    for z in (-0.6, 0.6):
        b.gbox((0.72, 0.3, z), (0.04, 0.1, 0.5), m["rust"])
    b.ladder((0.7, 0), (1, 0), 1.45)
    return b.finish()


def pallet_stairs():
    b, m = G("pallet_stairs"), mats()
    for z, h in ((-1.3, 0.7), (0, 1.4), (1.3, 2.1)):
        n = int(h / 0.14)
        for i in range(n):
            b.gbox((0, i * 0.14 + 0.05, z), (1.2, 0.04, 1.0), m["wood"]) if i % 2 == 0 else b.gbox((0, i * 0.14 + 0.05, z), (1.0, 0.1, 1.2), m["wood"])
        b.gbox((0, h / 2, z), (1.12, h - 0.08, 1.0), m["wood"])
    b.gbox((0, 0.5, 1.82), (1.0, 0.06, 0.04), m["wood"])  # cleat board
    b.ladder((0, 1.8), (0, 1), 2.1)
    return b.finish()


def scaffold_tower():
    b, m = G("scaffold_tower"), mats()
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.gbar((sx * 0.95, 0, sz * 0.95), (sx * 0.95, 3.0, sz * 0.95), 0.1, m["grey"])
    for y in (0.5, 1.5, 2.5):
        for sx in (-1, 1):
            b.gbar((sx * 0.95, y, -0.95), (sx * 0.95, y + 1.0, 0.95), 0.045, m["grey"])
    b.gbox((0, 2.94, 0), (2.0, 0.12, 2.0), m["wood"])
    for sx in (-1, 1):
        b.gbar((sx * 0.95, 3.5, -0.95), (sx * 0.95, 3.5, 0.95), 0.05, m["grey"])
    b.gbar((-0.95, 3.5, -0.95), (0.95, 3.5, -0.95), 0.05, m["grey"])
    b.ladder((0, 1.0), (0, 1), 3.0)
    return b.finish()


def jersey_stack():
    b, m = G("jersey_stack"), mats()
    for tier, width in ((0, 1.2), (1, 0.8)):
        y = tier * 0.85
        b.gbox((0, y + 0.425, 0), (width, 0.85, 2.5), m["concrete"])
        b.gbox((0, y + 0.1, 0), (width + 0.04, 0.2, 2.52), m["grey"])
    for sx in (-1, 1):
        b.gbox((sx * 0.41, 1.45, 0), (0.01, 0.08, 2.0), m["orange"])
    b.ladder((0, 1.25), (0, 1), 1.7)
    return b.finish()


def retaining_wall():
    b, m = G("retaining_wall"), mats()
    b.gbox((0, 1.15, 0), (0.6, 2.3, 4.0), m["brick"])
    b.gbox((0, 2.35, 0), (0.64, 0.1, 4.04), m["concrete"])
    for z in (-2.0, 0, 2.0):
        b.gbox((0, 1.1, z), (0.7, 2.2, 0.16), m["concrete"])
    b.ladder((0.3, 0), (1, 0), 2.4)
    return b.finish()


def transformer_climb():
    b, m = G("transformer_climb"), mats()
    b.gbox((0, 0.05, 0), (1.5, 0.1, 1.5), m["concrete"])
    b.gbox((0, 0.9, 0), (1.4, 1.7, 1.4), m["olive"])
    b.gbox((0, 1.76, 0), (1.5, 0.08, 1.5), m["olive"])
    for i in range(7):
        b.gbox((0, 0.9, -0.5 + i * 0.16), (1.42, 0.7, 0.07), m["dark"]) if False else b.gbox((-0.705, 0.9, -0.48 + i * 0.16), (0.02, 0.8, 0.07), m["dark"])
    b.ladder((0, 0.7), (0, 1), 1.8)
    return b.finish()


def ac_chiller():
    b, m = G("ac_chiller"), mats()
    b.gbox((0, 0.8, 0), (1.2, 1.5, 2.2), m["grey"])
    b.gbox((0, 1.57, 0), (1.26, 0.06, 2.26), m["dark"])
    for z in (-0.55, 0.55):
        b.gcyl((0, 1.61, z), 0.4, 0.03, m["dark"])
    for i in range(10):
        b.gbox((-0.605, 0.8, -1.0 + i * 0.22), (0.02, 1.2, 0.07), m["dark"])
    b.ladder((0.6, 0), (1, 0), 1.6)
    return b.finish()


def gazebo():
    b, m = G("gazebo"), mats()
    for sx in (-1, 1):
        for sz in (-1, 1):
            b.gbox((sx * 1.4, 1.25, sz * 1.4), (0.2, 2.5, 0.2), m["wood"])
    b.gbox((0, 2.5, 0), (3.4, 0.2, 3.4), m["wood"])
    b.gbox((0, 2.62, 0), (3.5, 0.04, 3.5), m["red"])
    for x in (-0.9, 0.0, 0.9):
        b.gbox((x, 2.3, 0), (0.1, 0.12, 3.0), m["wood"])
    b.ladder((0.9, 1.7), (0, 1), 2.6)
    return b.finish()


def bus_stop():
    b, m = G("bus_stop"), mats()
    for sx in (-1, 1):
        b.gbox((sx * 1.7, 1.15, -0.65), (0.1, 2.3, 0.1), m["grey"])
        b.gbox((sx * 1.7, 1.15, 0.65), (0.1, 2.3, 0.1), m["grey"])
    b.gbox((0, 1.2, -0.7), (3.4, 2.1, 0.06), m["glass"])
    b.gbox((0, 2.35, 0), (3.7, 0.1, 1.56), m["grey"])
    b.gbox((0, 0.45, -0.45), (3.0, 0.06, 0.4), m["wood"])
    b.gbox((0.9, 1.3, -0.62), (1.0, 1.2, 0.04), m["yellow"])
    b.ladder((0, -0.78), (0, -1), 2.4)
    return b.finish()


def vending_climb():
    b, m = G("vending_climb"), mats()
    b.gbox((0, 1.0, 0), (1.0, 2.0, 0.85), m["red"])
    b.gbox((0, 1.15, 0.43), (0.8, 1.2, 0.02), m["glass"])
    b.gbox((0, 1.99, 0), (1.04, 0.04, 0.9), m["dark"])
    b.gbox((0, 0.25, 0.43), (0.7, 0.2, 0.02), m["dark"])
    b.ladder((0.5, 0), (1, 0), 2.0)
    return b.finish()


def generator():
    b, m = G("generator"), mats()
    b.gbox((0, 0.85, 0), (1.0, 1.5, 2.2), m["yellow"])
    b.gbox((0, 1.65, 0), (1.04, 0.1, 2.24), m["dark"])
    b.gbox((0, 0.1, 0), (1.1, 0.2, 2.3), m["dark"])
    for i in range(6):
        b.gbox((-0.505, 0.9, -0.9 + i * 0.36), (0.02, 0.9, 0.1), m["dark"])
    b.gbar((0, 1.7, 0.9), (0.3, 2.6, 0.9), 0.06, m["grey"])  # folded light mast
    b.ladder((0.5, 0), (1, 0), 1.7)
    return b.finish()


def water_tank():
    b, m = G("water_tank"), mats()
    for a in range(4):
        import math
        ang = a * math.pi / 2 + math.pi / 4
        b.gbar((math.cos(ang) * 0.9, 0, math.sin(ang) * 0.9), (math.cos(ang) * 0.9, 1.0, math.sin(ang) * 0.9), 0.12, m["grey"])
    b.gcyl((0, 1.45, 0), 1.2, 2.1, m["blue"], seg=20)
    b.gcyl((0, 2.52, 0), 1.0, 0.1, m["grey"], seg=20)
    for y in (1.0, 1.9):
        b.gcyl((0, y, 0), 1.23, 0.08, m["grey"], seg=20)
    b.ladder((0, 1.2), (0, 1), 2.5)
    return b.finish()


def cable_spools():
    b, m = G("cable_spools"), mats()
    for z, r, top in ((-1.7, 0.8, 0.9), (0, 0.85, 1.5), (1.7, 0.9, 2.1)):
        b.gcyl((0, top - 0.04, z), r, 0.08, m["wood"], seg=18)
        b.gcyl((0, 0.04, z), r, 0.08, m["wood"], seg=18)
        b.gcyl((0, top / 2, z), r * 0.5, top - 0.1, m["dark"], seg=14)
        for k in range(5):
            b.gcyl((0, 0.15 + k * (top - 0.3) / 4, z), r * 0.8, 0.06, m["orange"], seg=18)
    b.ladder((0, 2.6), (0, 1), 2.1)
    return b.finish()


def flatbed():
    b, m = G("flatbed"), mats()
    b.gbox((0, 1.3, 0), (2.5, 0.2, 7.5), m["dark"])
    b.gbox((0, 1.43, 0), (2.4, 0.06, 7.4), m["wood"])
    for sx in (-1, 1):
        b.gbox((sx * 0.7, 1.1, 0), (0.15, 0.25, 7.2), m["grey"])
        b.gbox((sx * 1.0, 0.1, -3.2), (0.1, 0.2, 0.1), m["grey"])
    wheels(b, m, None, 1.0, z_list=(2.4, 3.3))
    b.gbox((0, 0.7, -3.4), (0.15, 1.2, 0.15), m["grey"])
    b.ladder((0, 3.75), (0, 1), 1.4)
    return b.finish()


def billboard():
    b, m = G("billboard"), mats()
    b.gbox((0, 1.5, 0), (0.5, 3.0, 0.5), m["grey"])
    b.gbox((0, 2.94, -0.3), (3.0, 0.12, 1.0), m["grey"])
    for sx in (-1, 1):
        b.gbar((sx * 1.4, 3.5, -0.75), (sx * 1.4, 3.5, 0.1), 0.05, m["grey"])
    b.gbox((0, 5.4, -0.9), (5.0, 2.6, 0.12), m["white"])
    b.gbox((0, 5.4, -0.83), (4.7, 2.3, 0.02), m["red"])
    for sx in (-1, 1):
        b.gbar((sx * 1.2, 3.0, -0.75), (sx * 1.2, 4.1, -0.9), 0.08, m["grey"])
    b.ladder((0, 0.25), (0, 1), 3.0)
    return b.finish()


def fire_escape():
    b, m = G("fire_escape"), mats()
    b.gbox((0, 2.0, -0.9), (3.2, 4.0, 0.4), m["brick"])
    b.gbox((0, 3.14, -0.1), (2.4, 0.12, 1.2), m["dark"])
    for sx in (-1, 1):
        b.gbar((sx * 1.1, 2.4, 0.5), (sx * 1.1, 3.9, 0.5), 0.05, m["dark"])
        b.gbar((sx * 1.1, 2.6, -0.7), (sx * 1.1, 3.1, 0.4), 0.05, m["dark"])
    b.gbar((-1.1, 3.9, 0.5), (1.1, 3.9, 0.5), 0.05, m["dark"])
    for sx in (-1, 1):
        b.gbar((sx * 1.1, 3.9, 0.5), (sx * 1.1, 3.9, -0.65), 0.05, m["dark"])
    b.gbox((0, 2.9, -0.69), (0.8, 1.1, 0.02), m["glass"])
    b.ladder((0, 0.5), (0, 1), 3.2)
    return b.finish()


def planter_tier():
    b, m = G("planter_tier"), mats()
    b.gbox((0, 0.7, 0), (1.2, 1.4, 3.0), m["concrete"])
    b.gbox((0, 1.41, 0), (1.3, 0.04, 3.1), m["grey"])
    b.gbox((0, 1.38, 0), (0.7, 0.04, 2.5), m["dirt"])
    for i in range(6):
        b.gbox((0, 1.5, -1.1 + i * 0.44), (0.25, 0.2, 0.25), m["leaf"])
    b.ladder((0.6, 0), (1, 0), 1.4)
    return b.finish()


def material_bin():
    b, m = G("material_bin"), mats()
    b.gbox((0, 0.9, 0), (1.5, 1.8, 2.0), m["orange"])
    b.gbox((0, 1.79, 0), (1.56, 0.06, 2.06), m["dark"])
    b.gbox((0, 1.82, 0), (1.0, 0.04, 1.5), m["rust"])
    for z in (-0.7, 0.7):
        b.gbox((0, 0.12, z), (1.6, 0.14, 0.2), m["dark"])
    b.ladder((0.75, 0), (1, 0), 1.8)
    return b.finish()


MODELS = [
    ("box_truck_climb", box_truck_climb),
    ("container_20ft", lambda: container("container_20ft", 6.06, "red")),
    ("container_40ft", lambda: container("container_40ft", 12.19, "blue")),
    ("dumpster_climb", dumpster_climb), ("pallet_stairs", pallet_stairs), ("scaffold_tower", scaffold_tower),
    ("jersey_stack", jersey_stack), ("retaining_wall", retaining_wall), ("transformer_climb", transformer_climb),
    ("ac_chiller", ac_chiller), ("gazebo", gazebo), ("bus_stop", bus_stop), ("vending_climb", vending_climb),
    ("generator", generator), ("water_tank", water_tank), ("cable_spools", cable_spools), ("flatbed", flatbed),
    ("billboard", billboard), ("fire_escape", fire_escape), ("planter_tier", planter_tier),
    ("material_bin", material_bin),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out_dir = os.path.abspath(argv[0] if argv else "assets/models/climb")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, factory in MODELS:
        obj = factory()
        export(obj, out_dir, name + ".glb")
        bpy.data.objects.remove(obj)


if __name__ == "__main__":
    main()
