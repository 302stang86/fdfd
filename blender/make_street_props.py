"""Gameplay-relevant urban street props for Fire Defense Field Day (20 models).

Run with Blender 4.0 or newer (or the bpy pip module) from the project folder:

    blender -b --python blender/make_street_props.py -- assets/models/street

Same conventions as make_urban_props.py: length along Blender +Y, thickness along X,
up along Z, origin at the bottom centre. Flat colours only (no texture downloads), so
they work with the Compatibility renderer. Cover pieces use 1.0 - 1.1 m crouch height.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: F401,E402
from make_urban_props import Builder, material, export  # noqa: E402


def brick_wall_low():
    b = Builder("brick_wall_low")
    brick = material("brick", "#8a4f3e", 0.95)
    cap = material("concrete_cap", "#9a9a95", 0.9)
    mortar = material("mortar", "#6c6862", 0.95)
    rng = random.Random(4)
    b.box((0, 0, 0.5), (0.3, 4.0, 1.0), brick)
    for i in range(9):  # mortar courses
        b.box((0, 0, 0.1 + i * 0.11), (0.31, 4.01, 0.012), mortar)
    for y in (-2.0, 0.0, 2.0):
        b.box((0, y, 0.52), (0.38, 0.14, 1.04), brick)  # pilasters
    b.box((0, 0, 1.05), (0.38, 4.08, 0.1), cap)
    return b.finish()


def concrete_wall_tall():
    b = Builder("concrete_wall_tall")
    con = material("concrete", "#8d8e8a", 0.95)
    dark = material("concrete_dark", "#6f706d", 0.95)
    b.box((0, 0, 1.5), (0.3, 4.0, 3.0), con)
    b.box((0, 0, 3.05), (0.4, 4.1, 0.14), dark)
    for y in (-2.0, 0.0, 2.0):
        b.box((0, y, 1.5), (0.38, 0.16, 3.0), dark)
    return b.finish()


def jersey_barrier():
    b = Builder("jersey_barrier")
    con = material("jersey", "#a9a8a2", 0.9)
    dark = material("jersey_slot", "#4a4a48", 0.9)
    stripe = material("jersey_stripe", "#c4452d", 0.7)
    b.box((0, 0, 0.17), (0.6, 2.5, 0.34), con)
    b.box((0, 0, 0.55), (0.34, 2.5, 0.42), con)
    b.box((0, 0, 0.8), (0.2, 2.5, 0.1), con)
    for y in (-0.8, 0.8):
        b.box((0, y, 0.1), (0.62, 0.3, 0.1), dark)
    b.box((0.171, 0, 0.62), (0.01, 2.0, 0.08), stripe)
    b.box((-0.171, 0, 0.62), (0.01, 2.0, 0.08), stripe)
    return b.finish()


def crowd_barricade():
    b = Builder("crowd_barricade")
    steel = material("barricade_steel", "#aab0b4", 0.45, 0.7)
    for y in (-1.0, 1.0):
        b.bar((0, y, 0), (0.22, y, 1.1), 0.05, steel)
        b.bar((0, y, 0), (-0.22, y, 1.1), 0.05, steel)
        b.bar((-0.22, y, 1.1), (0.22, y, 1.1), 0.05, steel)
    for z in (1.05, 0.6):
        b.bar((0, -1.1, z), (0, 1.1, z), 0.045, steel)
    for i in range(10):
        y = -0.95 + i * 0.21
        b.bar((0, y, 0.12), (0, y, 1.05), 0.025, steel)
    return b.finish()


def bollard():
    b = Builder("bollard")
    con = material("bollard_concrete", "#8f908c", 0.9)
    tape = material("bollard_tape", "#e6c43a", 0.5)
    b.cylinder((0, 0, 0.42), 0.15, 0.84, con, segments=12)
    b.cylinder((0, 0, 0.9), 0.12, 0.06, con, segments=12)
    b.cylinder((0, 0, 0.7), 0.156, 0.1, tape, segments=12)
    return b.finish()


def car(name, body_hex, length, width, cab_len, cab_h, body_h, bed=False):
    b = Builder(name)
    paint = material(name + "_paint", body_hex, 0.35, 0.6)
    glass = material("car_glass2", "#26343a", 0.1, 0.3)
    tire = material("tire2", "#202225", 0.95)
    rim = material("rim2", "#9aa0a4", 0.4, 0.8)
    trim = material("car_trim", "#1c1d1f", 0.8)
    ride = 0.26
    b.box((0, 0, ride + body_h * 0.5), (width, length, body_h), paint)
    if bed:  # pickup: cab at the front (+Y), open bed behind
        cab_y = length * 0.5 - cab_len * 0.5 - 0.35
        b.box((0, cab_y, ride + body_h + cab_h * 0.5), (width * 0.94, cab_len, cab_h), paint)
        b.box((0, cab_y, ride + body_h + cab_h * 0.55), (width * 0.97, cab_len * 0.8, cab_h * 0.55), glass)
        bed_len = length - cab_len - 0.6
        bed_y = -length * 0.5 + bed_len * 0.5 + 0.05
        for sx in (-1, 1):
            b.box((sx * (width * 0.5 - 0.04), bed_y, ride + body_h + 0.22), (0.08, bed_len, 0.44), paint)
        b.box((0, -length * 0.5 + 0.06, ride + body_h + 0.22), (width, 0.1, 0.44), paint)
        b.box((0, bed_y, ride + body_h + 0.02), (width - 0.12, bed_len, 0.04), trim)
    else:
        cab_y = 0.0 if cab_len < length * 0.7 else 0.0
        b.box((0, cab_y, ride + body_h + cab_h * 0.5), (width * 0.92, cab_len, cab_h), paint)
        b.box((0, cab_y, ride + body_h + cab_h * 0.55), (width * 0.96, cab_len * 0.82, cab_h * 0.55), glass)
        b.box((0, cab_y + cab_len * 0.5 + 0.01, ride + body_h + cab_h * 0.55), (width * 0.84, 0.03, cab_h * 0.5), glass)
    b.box((0, length * 0.5, ride + 0.2), (width, 0.12, 0.28), trim)
    b.box((0, -length * 0.5, ride + 0.2), (width, 0.12, 0.28), trim)
    for sx in (-1, 1):
        for sy in (-0.32, 0.32):
            y = sy * length
            b.cylinder((sx * (width * 0.5 - 0.1), y, 0.33), 0.33, 0.24, tire, axis="X", segments=14)
            b.cylinder((sx * (width * 0.5 + 0.02), y, 0.33), 0.18, 0.04, rim, axis="X", segments=10)
    return b.finish()


def box_truck():
    b = Builder("box_truck")
    paint = material("truck_cab", "#d8d8d4", 0.5, 0.3)
    cargo = material("truck_cargo", "#e8e6df", 0.6, 0.1)
    glass = material("car_glass2", "#26343a", 0.1, 0.3)
    tire = material("tire2", "#202225", 0.95)
    rim = material("rim2", "#9aa0a4", 0.4, 0.8)
    trim = material("car_trim", "#1c1d1f", 0.8)
    stripe = material("truck_stripe", "#c23b2a", 0.6)
    b.box((0, 0, 0.55), (2.3, 6.5, 0.4), trim)  # chassis
    b.box((0, -0.5, 1.9), (2.4, 4.7, 2.5), cargo)  # cargo box
    b.box((0, 2.3, 1.1), (2.3, 1.6, 1.4), paint)  # cab lower
    b.box((0, 2.5, 1.95), (2.2, 1.2, 0.9), paint)
    b.box((0, 3.11, 1.95), (2.0, 0.04, 0.62), glass)
    for sx in (-1, 1):
        b.box((sx * 1.11, 2.5, 1.95), (0.04, 0.9, 0.55), glass)
        b.box((sx * 1.21, -0.5, 1.4), (0.02, 4.7, 0.22), stripe)
    for y in (-2.0, -0.9, 2.2):
        for sx in (-1, 1):
            b.cylinder((sx * 1.0, y, 0.4), 0.4, 0.3, tire, axis="X", segments=14)
            b.cylinder((sx * 1.16, y, 0.4), 0.22, 0.05, rim, axis="X", segments=10)
    return b.finish()


def dumpster():
    b = Builder("dumpster")
    body = material("dumpster_green", "#2f5a3e", 0.7, 0.4)
    lid = material("dumpster_lid", "#232a28", 0.8)
    rust = material("dumpster_rust", "#6a3f2a", 0.9)
    b.box((0, 0, 0.7), (1.4, 2.0, 1.0), body)
    for y in (-0.55, 0.55):
        b.box((0, y, 1.3), (1.4, 0.9, 0.06), lid, rot=(0.0, 0.0, 0.0))
    b.box((0, -1.0, 1.25), (1.42, 0.06, 0.2), lid)
    for y in (-0.6, 0.6):
        b.box((0.71, y, 0.3), (0.04, 0.5, 0.1), rust)
        b.box((-0.71, y, 0.3), (0.04, 0.5, 0.1), rust)
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cylinder((sx * 0.55, sy * 0.85, 0.1), 0.1, 0.08, lid, axis="X", segments=8)
    b.box((0, 0, 0.27), (1.5, 2.1, 0.07), lid)
    return b.finish()


def pallet_stack():
    b = Builder("pallet_stack")
    wood = material("pallet_wood", "#a98456", 0.95)
    dark = material("pallet_dark", "#8a683f", 0.95)
    rng = random.Random(8)
    for level in range(5):
        z = level * 0.14
        yaw = rng.uniform(-0.07, 0.07)
        for i in range(3):
            b.box((0, -0.3 + i * 0.3, z + 0.05), (0.8, 0.14, 0.1), dark, rot=(0, 0, yaw)) if False else None
        for sx in (-0.34, 0, 0.34):
            b.box((sx, 0, z + 0.035), (0.1, 1.2, 0.07), dark, rot=(0, 0, yaw))
        for y in (-0.5, -0.17, 0.17, 0.5):
            b.box((0, y, z + 0.11), (0.8, 0.12, 0.03), wood, rot=(0, 0, yaw))
    return b.finish()


def box_pile():
    b = Builder("box_pile")
    card = material("cardboard", "#a87f52", 0.95)
    tape = material("tape", "#c9b27c", 0.8)
    rng = random.Random(12)
    layout = [((-0.3, -0.25, 0.0), (0.6, 0.5, 0.45)), ((0.3, -0.3, 0.0), (0.55, 0.45, 0.55)),
              ((0.0, 0.3, 0.0), (0.7, 0.5, 0.5)), ((-0.25, -0.2, 0.45), (0.5, 0.4, 0.4)),
              ((0.1, 0.3, 0.5), (0.45, 0.4, 0.45))]
    for (x, y, z), (sx, sy, sz) in layout:
        yaw = rng.uniform(-0.3, 0.3)
        b.box((x, y, z + sz / 2), (sx, sy, sz), card, rot=(0, 0, yaw))
        b.box((x, y, z + sz + 0.002), (0.07, sy * 1.01, 0.006), tape, rot=(0, 0, yaw))
    return b.finish()


def traffic_cone():
    b = Builder("traffic_cone")
    orange = material("cone_orange", "#e8662a", 0.6)
    white = material("cone_white", "#e8e8e4", 0.5)
    b.box((0, 0, 0.015), (0.38, 0.38, 0.03), material("cone_base", "#2a2a2a", 0.9))
    b.cylinder((0, 0, 0.3), 0.13, 0.5, orange, segments=10)
    b.cylinder((0, 0, 0.6), 0.04, 0.2, orange, segments=10)
    b.cylinder((0, 0, 0.38), 0.115, 0.1, white, segments=10)
    return b.finish()


def barrel():
    b = Builder("barrel")
    orange = material("barrel_orange", "#e5671f", 0.6)
    white = material("barrel_white", "#e9e9e5", 0.5)
    black = material("barrel_rubber", "#1f1f20", 0.95)
    b.cylinder((0, 0, 0.06), 0.3, 0.12, black, segments=14)
    b.cylinder((0, 0, 0.55), 0.24, 0.9, orange, segments=14)
    for z in (0.4, 0.7):
        b.cylinder((0, 0, z), 0.245, 0.1, white, segments=14)
    b.cylinder((0, 0, 1.01), 0.26, 0.04, orange, segments=14)
    return b.finish()


def sawhorse():
    b = Builder("sawhorse")
    wood = material("sawhorse_wood", "#b8895a", 0.9)
    yellow = material("sawhorse_yellow", "#e2b92a", 0.6)
    black = material("sawhorse_black", "#222222", 0.7)
    for sy in (-0.4, 0.4):
        b.bar((0, sy, 0), (0.28, sy, 0.95), 0.07, wood)
        b.bar((0, sy, 0), (-0.28, sy, 0.95), 0.07, wood)
    for i in range(4):
        y = -0.6 + i * 0.3
        b.box((0, 0, 0.82 + (i % 2) * 0.0), (0.04, 1.2, 0.2), yellow)
        break
    for i in range(8):
        b.box((0.0, -0.55 + i * 0.15, 0.84), (0.05, 0.075, 0.2), black if i % 2 else yellow)
    b.box((0, 0, 0.6), (0.04, 1.0, 0.16), yellow)
    return b.finish()


def hedge():
    b = Builder("hedge")
    leaf = material("hedge_leaf", "#3b6b34", 0.95)
    leaf2 = material("hedge_leaf2", "#2f5a2b", 0.95)
    rng = random.Random(21)
    b.box((0, 0, 0.5), (0.8, 2.0, 1.0), leaf2)
    for i in range(14):
        b.box((rng.uniform(-0.3, 0.3), rng.uniform(-0.9, 0.9), rng.uniform(0.55, 1.05)),
              (0.4, 0.5, 0.35), leaf if i % 2 else leaf2, rot=(rng.random(), rng.random(), rng.random()))
    return b.finish()


def planter():
    b = Builder("planter")
    con = material("planter_concrete", "#9b9a94", 0.95)
    dirt = material("planter_dirt", "#4a3626", 0.95)
    leaf = material("planter_leaf", "#4d8a3c", 0.9)
    rng = random.Random(5)
    for sx in (-0.3, 0.3):
        b.box((sx, 0, 0.3), (0.1, 1.5, 0.6), con)
    for sy in (-0.7, 0.7):
        b.box((0, sy, 0.3), (0.7, 0.1, 0.6), con)
    b.box((0, 0, 0.45), (0.5, 1.3, 0.12), dirt)
    for i in range(7):
        b.box((rng.uniform(-0.2, 0.2), rng.uniform(-0.55, 0.55), 0.62), (0.12, 0.12, 0.22), leaf,
              rot=(rng.random(), rng.random(), rng.random()))
    return b.finish()


def hydrant():
    b = Builder("hydrant")
    red = material("hydrant_red", "#b3281f", 0.6, 0.3)
    cap = material("hydrant_cap", "#d6d2c8", 0.5, 0.5)
    b.cylinder((0, 0, 0.05), 0.15, 0.1, red, segments=8)
    b.cylinder((0, 0, 0.37), 0.1, 0.62, red, segments=8)
    b.cylinder((0, 0, 0.7), 0.12, 0.06, red, segments=8)
    b.cylinder((0, 0, 0.76), 0.07, 0.08, cap, segments=5)
    for side in (-1, 1):
        b.cylinder((0.13 * side, 0, 0.5), 0.045, 0.16, cap, axis="X", segments=8)
    b.cylinder((0, -0.13, 0.5), 0.055, 0.14, cap, axis="Y", segments=8)
    return b.finish()


def trash_can():
    b = Builder("trash_can")
    metal = material("can_metal", "#3b4a44", 0.6, 0.5)
    lid = material("can_lid", "#222a27", 0.7, 0.4)
    b.cylinder((0, 0, 0.45), 0.24, 0.9, metal, segments=12)
    for i in range(8):
        a = math.tau * i / 8
        b.box((math.cos(a) * 0.245, math.sin(a) * 0.245, 0.45), (0.03, 0.03, 0.85), lid, rot=(0, 0, a))
    b.cylinder((0, 0, 0.93), 0.27, 0.07, lid, segments=12)
    b.cylinder((0, 0, 0.98), 0.2, 0.05, lid, segments=12)
    return b.finish()


def bench():
    b = Builder("bench")
    iron = material("bench_iron", "#1f2a26", 0.6, 0.6)
    wood = material("bench_wood", "#9a6d3f", 0.9)
    for sy in (-0.8, 0.8):
        b.box((0, sy, 0.22), (0.5, 0.06, 0.44), iron)
        b.box((-0.24, sy, 0.62), (0.05, 0.06, 0.9), iron, rot=(0.0, 0.0, 0.0))
    for i in range(3):
        b.box((0.05 - 0.0, 0, 0.45), (0.12 + 0.0, 1.8, 0.04), wood) if False else None
    for x in (-0.15, 0.0, 0.15, 0.3):
        b.box((x, 0, 0.45), (0.12, 1.8, 0.04), wood)
    for z in (0.68, 0.86):
        b.box((-0.25, 0, z), (0.04, 1.8, 0.13), wood, rot=(0, 0.15, 0))
    return b.finish()


def transformer_box():
    b = Builder("transformer_box")
    olive = material("transformer_olive", "#5b6650", 0.7, 0.3)
    pad = material("transformer_pad", "#8c8b86", 0.95)
    vent = material("transformer_vent", "#2c3228", 0.8)
    warn = material("transformer_warn", "#e0b92c", 0.6)
    b.box((0, 0, 0.05), (1.4, 1.4, 0.1), pad)
    b.box((0, 0, 0.6), (1.2, 1.2, 1.0), olive)
    b.box((0, 0, 1.14), (1.3, 1.3, 0.08), olive)
    for sx in (-1, 1):
        for i in range(7):
            b.box((sx * 0.605, -0.45 + i * 0.15, 0.6), (0.02, 0.07, 0.6), vent)
    b.box((0, -0.605, 0.82), (0.25, 0.02, 0.18), warn)
    return b.finish()


MODELS = [
    ("brick_wall_low", brick_wall_low),
    ("concrete_wall_tall", concrete_wall_tall),
    ("jersey_barrier", jersey_barrier),
    ("crowd_barricade", crowd_barricade),
    ("bollard", bollard),
    ("sedan", lambda: car("sedan", "#2d4f7a", 4.4, 1.8, 2.2, 0.55, 0.62)),
    ("pickup", lambda: car("pickup", "#7a2d2d", 5.4, 2.0, 1.7, 0.7, 0.7, bed=True)),
    ("box_truck", box_truck),
    ("dumpster", dumpster),
    ("pallet_stack", pallet_stack),
    ("box_pile", box_pile),
    ("traffic_cone", traffic_cone),
    ("barrel", barrel),
    ("sawhorse", sawhorse),
    ("hedge", hedge),
    ("planter", planter),
    ("hydrant", hydrant),
    ("trash_can", trash_can),
    ("bench", bench),
    ("transformer_box", transformer_box),
]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out_dir = os.path.abspath(argv[0] if argv else "assets/models/street")
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, factory in MODELS:
        obj = factory()
        export(obj, out_dir, name + ".glb")
        bpy.data.objects.remove(obj)


if __name__ == "__main__":
    main()
