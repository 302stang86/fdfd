"""Enterable hiding props (10 models): hollow shell, hinged doors, interior for hiding.

Run with Blender 4.0+ (or the bpy pip module) from the project folder:

    python blender/make_enterable_props.py assets/models/enterable

Each .glb holds separate objects so Godot can treat them independently:
    Shell     the hollow walls/floor/roof (+ crates etc. inside). Godot builds a TRIMESH collision
              for it, never a convex hull, so the inside stays open.
    Dressing  purely visual extras (wheels, signs, vents...). No collision.
    Door_L / Door_R   swinging doors. Their object origin sits ON THE HINGE, so rotating the node
              around Y swings the door. Door_L is hinged on its -x edge, Door_R on its +x edge.
Every entrance faces +z (Godot). Coordinates are Godot terms (x across, y up, z along).
The hide-zone boxes and door signs live in street_props.gd (ENTER); keep them in sync.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401,E402
from make_climb_props import G, mats  # noqa: E402


def room(b, W, H, D, wall, floor, opening=None):
    b.gbox((0, floor / 2, 0), (W, floor, D), M["dark"])
    b.gbox((0, H / 2, -D / 2 + wall / 2), (W, H, wall), M["wall"])
    for sx in (-1, 1):
        b.gbox((sx * (W / 2 - wall / 2), H / 2, 0), (wall, H, D), M["wall"])
    b.gbox((0, H - wall / 2, 0), (W, wall, D), M["wall"])
    zf = D / 2 - wall / 2
    if opening is None:
        b.gbox((0, H / 2, zf), (W, H, wall), M["wall"])
        return
    x0, x1, y0, y1 = opening
    b.gbox(((x0 - W / 2) / 2, H / 2, zf), (x0 + W / 2, H, wall), M["wall"])
    b.gbox(((x1 + W / 2) / 2, H / 2, zf), (W / 2 - x1, H, wall), M["wall"])
    b.gbox(((x0 + x1) / 2, (y1 + H) / 2, zf), (x1 - x0, H - y1, wall), M["wall"])
    if y0 > floor:
        b.gbox(((x0 + x1) / 2, (floor + y0) / 2, zf), (x1 - x0, y0 - floor, wall), M["wall"])


def ramp(b, x, z_start, length, rise, width=1.6):
    """A walk-up ramp in front of a raised floor (z_start is the floor edge, going +z)."""
    ang = math.atan2(rise, length)
    hyp = math.hypot(rise, length)
    b.box((x, -(z_start + length / 2), rise / 2 - 0.03), (width, hyp, 0.06), M["dark"], rot=(ang, 0, 0))


def door(name, hinge, width, y0, y1, thick, mat, left=True, slats=False, glass=False):
    d = G(name)
    cx = width / 2 if left else -width / 2
    d.gbox((cx, (y0 + y1) / 2, 0), (width, y1 - y0, thick), M["glass"] if glass else mat)
    if slats:
        for i in range(5):
            d.gbox((cx, y1 - 0.25 - i * 0.07, thick / 2 + 0.01), (width * 0.7, 0.03, 0.02), M["dark"])
    hx = hinge[0]
    d.gbox((cx + (width / 2 - 0.1) * (1 if left else -1), (y0 + y1) / 2, thick / 2 + 0.03), (0.04, 0.04, 0.05), M["grey"])
    obj = d.finish()
    obj.location = (hx, -hinge[1], 0.0)
    return obj


def fin(b, name):
    obj = b.finish()
    obj.name = name
    return obj


def export_multi(objs, out_dir, file_name):
    for other in bpy.context.scene.objects:
        other.select_set(other in objs)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, file_name), export_format="GLB", use_selection=True,
                              export_apply=True, export_yup=True, export_materials="EXPORT",
                              export_cameras=False, export_lights=False)
    print("exported", file_name, [o.name for o in objs])


def porta_potty():
    sh, dr = G("s"), G("d")
    room(sh, 1.2, 2.4, 1.2, 0.05, 0.1, opening=(-0.45, 0.45, 0.1, 2.2))
    sh.gbox((0.3, 1.0, -0.5), (0.4, 0.4, 0.4), M["grey"])  # seat block
    ramp(sh, 0, 0.6, 0.4, 0.1, 0.9)
    dr.gbox((0, 2.45, 0), (1.3, 0.05, 1.3), M["white"])  # roof cap
    for i in range(4):
        dr.gbox((0.616, 1.9 - i * 0.07, 0), (0.01, 0.03, 0.5), M["dark"])  # vent slits
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.45, 0.6), 0.9, 0.1, 2.2, 0.04, M["wall"], left=True, slats=True)]


def cargo_trailer():
    sh, dr = G("s"), G("d")
    W, D = 2.6, 8.0
    room(sh, W, 3.0, D, 0.08, 0.3, opening=(-1.15, 1.15, 0.3, 2.7))
    for x, z in ((-0.85, -3.2), (0.85, -3.2), (-0.85, -2.2), (0.0, -3.3)):
        sh.gbox((x, 0.7, z), (0.8, 0.8, 0.8), M["wood"])
    ramp(sh, 0, D / 2, 1.0, 0.3, 2.2)
    for sz in (2.6, 3.4):
        for sx in (-1, 1):
            dr.gcyl((sx * 1.1, 0.4, sz), 0.4, 0.3, M["tire"], axis="X")
    dr.gbox((0, 0.12, 0), (2.4, 0.2, 7.8), M["dark"])
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-1.15, D / 2), 1.15, 0.3, 2.7, 0.06, M["white"], left=True),
            door("Door_R", (1.15, D / 2), 1.15, 0.3, 2.7, 0.06, M["white"], left=False)]


def container_interior():
    sh, dr = G("s"), G("d")
    W, D, H = 2.44, 6.06, 2.6
    room(sh, W, H, D, 0.08, 0.1, opening=(-1.1, 1.1, 0.1, 2.45))
    ramp(sh, 0, D / 2, 0.4, 0.1, 2.0)
    z = -D / 2 + 0.3
    while z < D / 2 - 0.3:
        for sx in (-1, 1):
            dr.gbox((sx * (W / 2 + 0.015), H / 2, z), (0.03, H - 0.3, 0.12), M["dark"])
        z += 0.34
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-1.1, D / 2), 1.1, 0.1, 2.45, 0.06, M["red"], left=True),
            door("Door_R", (1.1, D / 2), 1.1, 0.1, 2.45, 0.06, M["red"], left=False)]


def dumpster_hideout():
    sh, dr = G("s"), G("d")
    room(sh, 1.4, 1.3, 2.0, 0.06, 0.15, opening=(-0.4, 0.4, 0.15, 1.15))
    sh.box((0, 1.0, 1.3), (1.44, 0.9, 0.06), M["dark"], rot=(0.0, 0.0, 0.0)) if False else None
    ramp(sh, 0, 1.0, 0.5, 0.15, 0.8)
    dr.box((0, 0.95, 1.5), (1.44, 0.9, 0.06), M["dark"], rot=(0.9, 0, 0))  # lid propped open
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.4, 1.0), 0.8, 0.15, 1.15, 0.04, M["green"], left=True)]


def bus_shelter_enclosed():
    sh, dr = G("s"), G("d")
    W, D = 3.5, 1.5
    sh.gbox((0, 0.05, 0), (W, 0.1, D), M["dark"])
    sh.gbox((0, 1.15, -D / 2 + 0.03), (W, 2.3, 0.06), M["glass"])
    for sx in (-1, 1):
        sh.gbox((sx * (W / 2 - 0.03), 1.15, 0), (0.06, 2.3, D), M["glass"])
    sh.gbox((0, 2.35, 0), (W + 0.1, 0.1, D + 0.1), M["grey"])
    for sx in (-1, 1):
        sh.gbox((sx * (W / 2 - 0.05), 1.15, D / 2 - 0.05), (0.1, 2.3, 0.1), M["grey"])
    sh.gbox((0, 0.45, -0.45), (2.6, 0.06, 0.4), M["wood"])  # bench
    sh.gbox((0, 0.22, -0.45), (2.4, 0.3, 0.3), M["grey"])
    dr.gbox((0.6, 1.4, -0.7), (0.9, 1.1, 0.03), M["yellow"])
    return [fin(sh, "Shell"), fin(dr, "Dressing")]


def payphone_booth():
    sh, dr = G("s"), G("d")
    room(sh, 1.1, 2.3, 1.1, 0.05, 0.08, opening=(-0.35, 0.35, 0.08, 2.1))
    sh.gbox((0, 1.2, -0.45), (0.3, 0.5, 0.1), M["dark"])  # phone unit
    ramp(sh, 0, 0.55, 0.35, 0.08, 0.7)
    dr.gbox((0, 2.38, 0), (1.15, 0.16, 1.15), M["blue"])
    dr.gbox((0, 2.38, 0.58), (0.9, 0.12, 0.02), M["white"])
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.35, 0.55), 0.7, 0.08, 2.1, 0.03, M["glass"], left=True, glass=True)]


def utility_cabinet():
    sh, dr = G("s"), G("d")
    room(sh, 3.2, 2.6, 2.8, 0.1, 0.1, opening=(-0.8, 0.8, 0.1, 2.3))
    ramp(sh, 0, 1.4, 0.4, 0.1, 1.6)
    for x in (-1.0, 0.0, 1.0):
        sh.gbox((x, 1.1, -1.05), (0.8, 2.0, 0.5), M["grey"])
    dr.gbox((0, 2.68, 0), (3.3, 0.1, 2.9), M["olive"])
    for i in range(8):
        dr.gbox((-1.61, 1.5, -1.2 + i * 0.3), (0.02, 0.8, 0.1), M["dark"])
    dr.gbox((1.0, 2.0, 1.43), (0.4, 0.3, 0.02), M["yellow"])
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.8, 1.4), 0.8, 0.1, 2.3, 0.06, M["olive"], left=True),
            door("Door_R", (0.8, 1.4), 0.8, 0.1, 2.3, 0.06, M["olive"], left=False)]


def construction_tent():
    sh, dr = G("s"), G("d")
    room(sh, 3.0, 2.4, 3.0, 0.03, 0.04, opening=(-0.5, 0.5, 0.04, 2.1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            dr.gbox((sx * 1.55, 1.2, sz * 1.55), (0.06, 2.4, 0.06), M["grey"])
    dr.gbox((0, 2.5, 0), (3.2, 0.12, 3.2), M["orange"])  # valance
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.5, 1.5), 1.0, 0.04, 2.1, 0.03, M["orange"], left=True)]


def van_camper():
    sh, dr = G("s"), G("d")
    W, D, H = 2.1, 5.0, 2.2
    room(sh, W, H, D, 0.08, 0.3, opening=(-0.8, 0.8, 0.3, 1.9))
    sh.gbox((0, 1.1, -D / 2 + 0.75), (W, 2.2, 1.5), M["blue"])  # solid cab block
    for sx in (-1, 1):
        sh.gbox((sx * 0.7, 0.55, -0.4), (0.5, 0.5, 1.4), M["grey"])  # bench seats
    ramp(sh, 0, D / 2, 1.0, 0.3, 1.8)
    for sz in (-1.5, 1.4):
        for sx in (-1, 1):
            dr.gcyl((sx * 0.95, 0.35, sz), 0.35, 0.25, M["tire"], axis="X")
    for sx in (-1, 1):
        dr.gbox((sx * 1.06, 1.45, -1.3), (0.02, 0.5, 1.4), M["glass"])
    return [fin(sh, "Shell"), fin(dr, "Dressing"),
            door("Door_L", (-0.8, D / 2), 0.8, 0.3, 1.9, 0.05, M["blue"], left=True),
            door("Door_R", (0.8, D / 2), 0.8, 0.3, 1.9, 0.05, M["blue"], left=False)]


def culvert():
    sh, dr = G("s"), G("d")
    R, L, N = 1.1, 4.0, 16
    for i in range(N):
        a = math.tau * i / N
        sh.box((R * math.cos(a), 0, R + R * math.sin(a)), (0.22, L, math.tau * R / N * 1.15), M["concrete"], rot=(0, -a, 0))
    sh.gbox((0, 0.42, 0), (1.3, 0.08, L), M["dark"])  # flat floor to crawl on
    for z in (-L / 2 + 0.1, L / 2 - 0.1):
        for i in range(N):
            a = math.tau * i / N
            dr.box((1.18 * math.cos(a), -z, R + 1.18 * math.sin(a)), (0.1, 0.18, math.tau * R / N * 1.2), M["grey"], rot=(0, -a, 0))
    return [fin(sh, "Shell"), fin(dr, "Dressing")]


MODELS = [("porta_potty", porta_potty), ("cargo_trailer", cargo_trailer), ("container_interior", container_interior),
          ("dumpster_hideout", dumpster_hideout), ("bus_shelter_enclosed", bus_shelter_enclosed),
          ("payphone_booth", payphone_booth), ("utility_cabinet", utility_cabinet),
          ("construction_tent", construction_tent), ("van_camper", van_camper), ("culvert", culvert)]


def main():
    global M
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out_dir = os.path.abspath(argv[0] if argv else "assets/models/enterable")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M = mats()
    M["wall"] = M["grey"]
    from make_urban_props import material
    palette = {"porta": "#2f6fb0"}
    for name, factory in MODELS:
        M["wall"] = material(name + "_wall", {"porta_potty": "#2f6fb0", "cargo_trailer": "#d8d8d4", "container_interior": "#9b3a2e",
                                              "dumpster_hideout": "#2f5a3e", "bus_shelter_enclosed": "#7d8588", "payphone_booth": "#2d4f7a",
                                              "utility_cabinet": "#5b6650", "construction_tent": "#d9631f", "van_camper": "#2f5b8a",
                                              "culvert": "#8f908c"}[name], 0.8, 0.1)
        objs = factory()
        export_multi(objs, out_dir, name + ".glb")
        for o in objs:
            bpy.data.objects.remove(o)


if __name__ == "__main__":
    main()
