"""Build the Fire Defense Field Day character models from the reference art.

Run from the project folder (Blender 4.0+ with Python packages numpy, scipy and
opencv available to Blender's Python, or the `bpy` pip module):

    python blender/make_characters.py assets/models/characters

For every character the cut-out reference (blender/character_refs/*.png, alpha =
silhouette) is turned into a low-poly body by lofting elliptical rings through the
silhouette, row by row. The reference is projected onto the front of the mesh and a
blurred copy onto the back, so the painted details (camo, polka dots, lace, reflective
stripes) come through. The body is cut into Torso, ArmA, ArmB, LegA and LegB so the game
can swing the limbs; each limb's pivot is its shoulder or hip. Feet sit at y = 0, the
figure is 1.5 m tall, and it faces +Z (Godot's glTF "forward").
"""
import math
import os
import sys

import bpy  # noqa: F401  (must come first: it registers bmesh)
import bmesh
import cv2
import numpy as np
from mathutils import Vector
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
REFS = os.path.join(HERE, "character_refs")
HEIGHT = 1.5
STEP = 6  # pixel rows per ring
HALF = 6  # segments in each half (front / back) of a ring

# Landmarks are pixel coordinates in the 354 x 535 reference images.
#   cx      centre line between the legs
#   neck    row where the head ends and the shoulders begin
#   a_top   first row of the arms
#   cut_a / cut_b   polylines [(x, y), ...] separating the arms from the torso
#                   (A = left of the image, B = right of it)
#   arm_a_bot / arm_b_bot   last row that can belong to an arm (or a held prop)
#   crotch  row where the legs split away from the torso
#   foot    first row of the foot, which is stretched forwards
#   leg_pivot   row of the hip joint
#   swing   leg swing amplitude (radians) used by the game
#   back    [(x0, y0, x1, y1, "#hex"), ...] colour patches for the back of the figure
CHARACTERS = {
    "army": dict(
        src="01_Army_Fatigues", cx=176, neck=92, a_top=98,
        cut_a=[(124, 98), (124, 300)], cut_b=[(228, 98), (228, 300)],
        arm_a_bot=306, arm_b_bot=306, crotch=268, foot=494, leg_pivot=250, swing=0.5,
        back=[(120, 10, 240, 68, "#3b2a1e"), (120, 68, 240, 96, "#c3906c")]),
    "ninja": dict(
        src="02_Ninja", cx=176, neck=97, a_top=104,
        cut_a=[(128, 104), (137, 300)], cut_b=[(226, 104), (218, 300)],
        arm_a_bot=300, arm_b_bot=300, crotch=299, foot=484, leg_pivot=290, swing=0.5,
        back=[(120, 20, 240, 100, "#2b2a30")]),
    "robot": dict(
        src="03_Robot", cx=177, neck=100, a_top=106,
        cut_a=[(134, 106), (142, 318)], cut_b=[(220, 106), (212, 318)],
        arm_a_bot=318, arm_b_bot=318, crotch=290, foot=478, leg_pivot=272, swing=0.45,
        back=[(120, 20, 240, 100, "#7d8387")]),
    "clown": dict(
        src="04_Clown", cx=173, neck=118, a_top=140,
        cut_a=[(128, 140), (128, 240)], cut_b=[(214, 140), (214, 240)],
        arm_a_bot=240, arm_b_bot=240, crotch=300, foot=468, leg_pivot=280, swing=0.5,
        back=[(110, 20, 255, 118, "#ee7f22")]),
    "firefighter": dict(
        src="05_Firefighter", cx=175, neck=96, a_top=110,
        cut_a=[(122, 110), (108, 300), (103, 400)], cut_b=[(230, 110), (248, 300)],
        arm_a_bot=400, arm_b_bot=318, crotch=312, foot=494, leg_pivot=290, swing=0.5,
        back=[(120, 10, 240, 72, "#dcae2b"), (120, 72, 240, 96, "#2a2422")]),
    "bunny": dict(
        src="06_Bunny_Cosplay", cx=176, neck=126, a_top=130,
        cut_a=[(148, 130), (152, 250)], cut_b=[(206, 130), (204, 250)],
        arm_a_bot=250, arm_b_bot=250, crotch=300, foot=486, leg_pivot=290, swing=0.45,
        back=[(132, 58, 222, 128, "#15131a"), (156, 124, 200, 262, "#15131a")]),
    "goth": dict(
        src="07_Emo_Goth", cx=176, neck=110, a_top=118,
        cut_a=[(118, 118), (116, 306)], cut_b=[(236, 118), (238, 306)],
        arm_a_bot=306, arm_b_bot=306, crotch=432, foot=492, leg_pivot=432, swing=0.35,
        back=[(138, 80, 216, 126, "#7a2548")]),
    "police": dict(
        src="08_Police", cx=176, neck=92, a_top=100,
        cut_a=[(120, 100), (120, 300)], cut_b=[(232, 100), (232, 300)],
        arm_a_bot=300, arm_b_bot=300, crotch=290, foot=494, leg_pivot=272, swing=0.5,
        back=[(120, 40, 240, 70, "#1a2230"), (120, 70, 240, 92, "#c3906c")]),
}


def fill_transparent(bgr, alpha_mask):
    """Replace colours outside the figure with the nearest figure colour (no fringes)."""
    inside = ndimage.binary_erosion(alpha_mask, iterations=2)
    if not inside.any():
        inside = alpha_mask
    _, (iy, ix) = ndimage.distance_transform_edt(~inside, return_indices=True)
    return bgr[iy, ix]


def make_atlas(bgr, alpha, patches):
    """Front image next to a blurred back image, ready to use as one texture."""
    mask = alpha > 0.5
    front = fill_transparent(bgr, mask)
    inside = ndimage.binary_erosion(mask, iterations=2).astype(np.float32)
    weights = inside[..., None]
    sigma = 3.2
    num = cv2.GaussianBlur(bgr.astype(np.float32) * weights, (0, 0), sigma)
    den = cv2.GaussianBlur(weights[..., 0], (0, 0), sigma)[..., None]
    back = np.where(den > 1e-3, num / np.maximum(den, 1e-3), front.astype(np.float32))
    back *= 0.9  # the back of the figure is slightly less lit
    for x0, y0, x1, y1, hex_color in patches:
        r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
        region = np.zeros(mask.shape, np.float32)
        region[y0:y1, x0:x1] = 1.0
        region = cv2.GaussianBlur(region, (0, 0), 3.0) * mask  # feathered edges
        back = back * (1 - region[..., None]) + np.array((b, g, r), np.float32) * region[..., None]
    back = fill_transparent(np.clip(back, 0, 255).astype(np.uint8), mask)
    return np.hstack([front, back])


def polyline(points, height):
    xs = np.interp(np.arange(height), [p[1] for p in points], [p[0] for p in points])
    return xs


def part_masks(cfg, mask):
    h, w = mask.shape
    yy, xx = np.mgrid[0:h, 0:w]
    lap = 7
    cut_a = polyline(cfg["cut_a"], h)[:, None]
    cut_b = polyline(cfg["cut_b"], h)[:, None]
    in_a = (yy >= cfg["a_top"]) & (yy < cfg["arm_a_bot"]) & (xx < cut_a)
    in_b = (yy >= cfg["a_top"]) & (yy < cfg["arm_b_bot"]) & (xx >= cut_b)
    arm_a = mask & (yy >= cfg["a_top"]) & (yy < cfg["arm_a_bot"]) & (xx < cut_a + lap)
    arm_b = mask & (yy >= cfg["a_top"]) & (yy < cfg["arm_b_bot"]) & (xx >= cut_b - lap)
    below = yy >= cfg["crotch"]
    torso = mask & ~in_a & ~in_b & ~below
    lap_rows = yy >= cfg["crotch"] - 10
    leg_a = mask & lap_rows & (xx < cfg["cx"]) & ~in_a & ~in_b
    leg_b = mask & lap_rows & (xx >= cfg["cx"]) & ~in_a & ~in_b
    return {"Torso": torso, "ArmA": arm_a, "ArmB": arm_b, "LegA": leg_a, "LegB": leg_b}


def row_runs(band, min_width=4, merge_gap=3):
    cols = np.flatnonzero(band)
    if cols.size == 0:
        return []
    runs = []
    start = prev = cols[0]
    for c in cols[1:]:
        if c - prev > merge_gap + 1:
            runs.append((start, prev + 1))
            start = c
        prev = c
    runs.append((start, prev + 1))
    return [r for r in runs if r[1] - r[0] >= min_width]


def build_part(name, mask, cfg, scale, foot_row, atlas_w, atlas_h, width_px):
    """Loft rings through the mask. Returns a bmesh with UVs, in world metres."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("UV")
    vert_uv = {}
    h = mask.shape[0]
    rows = np.flatnonzero(mask.any(axis=1))
    if rows.size == 0:
        return bm
    first, last = rows[0], rows[-1]
    rings = []  # per band: list of ring dicts
    band_tops = list(range(first, last + 1, STEP))
    for top in band_tops:
        band = mask[top:top + STEP].mean(axis=0) >= 0.5
        yc_px = min(top + STEP / 2.0, h - 1)
        entries = []
        for x0, x1 in row_runs(band):
            entries.append(dict(x0=x0, x1=x1, y=yc_px, ring=None, up=False, down=False))
        rings.append(entries)

    def make_ring(e):
        a_px = (e["x1"] - e["x0"]) / 2.0
        xc_px = (e["x0"] + e["x1"]) / 2.0
        y_px = e["y"]
        a = a_px * scale
        if name == "Torso":
            k = 0.95 if y_px < cfg["neck"] + 6 else 0.5
        else:
            k = 0.9
        b = max(a * k, 0.02)
        shift = 0.0
        if name.startswith("Leg"):
            # the sole lengthens towards the toe: ramp up over 30 rows above `foot`
            ramp = min(max((y_px - (foot_row - 30)) / 30.0, 0.0), 1.0)
            if ramp > 0.0:
                b = min(a * (1.0 + 0.6 * ramp), 0.16)
                b = max(b, a)
                shift = -(b - a) * 0.8
        z = (foot_y - y_px) * scale
        out = {"front": [], "back": [], "xc": (xc_px - cfg["cx"]) * scale, "yc": shift,
               "z": z, "a": a, "b": b, "xc_px": xc_px, "a_px": a_px, "y_px": y_px}
        for half, start in (("front", 0.0), ("back", math.pi)):
            for i in range(HALF + 1):
                theta = start + math.pi * i / HALF
                px = xc_px + a_px * math.cos(theta)
                co = Vector(((xc_px - cfg["cx"]) * scale + a * math.cos(theta),
                             shift - b * math.sin(theta), z))
                v = bm.verts.new(co)
                u = (px + (0 if half == "front" else width_px)) / atlas_w
                vert_uv[v] = (u, 1.0 - y_px / atlas_h)
                out[half].append(v)
        return out

    for entries in rings:
        for e in entries:
            e["ring"] = make_ring(e)

    def add_face(verts, outward, want_up=None):
        n = (verts[1].co - verts[0].co).cross(verts[2].co - verts[0].co)
        if want_up is not None:
            flip = (n.z * want_up) < 0
        else:
            c = sum((v.co for v in verts), Vector()) / len(verts)
            flip = n.dot(Vector((c.x - outward[0], c.y - outward[1], 0.0))) < 0
        if flip:
            verts = list(reversed(verts))
        try:
            face = bm.faces.new(verts)
        except ValueError:
            return
        face.smooth = True
        for loop in face.loops:
            loop[uv_layer].uv = vert_uv[loop.vert]

    def overlap(p, q):
        lo = max(p["x0"], q["x0"])
        hi = min(p["x1"], q["x1"])
        return hi - lo >= 0.35 * min(p["x1"] - p["x0"], q["x1"] - q["x0"])

    for band_index in range(len(rings) - 1):
        for p in rings[band_index]:
            for q in rings[band_index + 1]:
                if not overlap(p, q):
                    continue
                p["down"] = q["up"] = True
                A, B = p["ring"], q["ring"]
                for half in ("front", "back"):
                    for i in range(HALF):
                        add_face([A[half][i], A[half][i + 1], B[half][i + 1], B[half][i]],
                                 (A["xc"], A["yc"]))

    cap_h = STEP * scale * 0.7
    for entries in rings:
        for e in entries:
            for is_top in (True, False):
                if (e["up"] if is_top else e["down"]):
                    continue
                r = e["ring"]
                cz = r["z"] + (cap_h if is_top else -cap_h)
                for half in ("front", "back"):
                    centre = bm.verts.new(Vector((r["xc"], r["yc"], cz)))
                    px = r["xc_px"] + (0 if half == "front" else width_px)
                    vert_uv[centre] = (px / atlas_w, 1.0 - r["y_px"] / atlas_h)
                    ring = r[half]
                    for i in range(HALF):
                        add_face([centre, ring[i + 1], ring[i]], (r["xc"], r["yc"]),
                                 want_up=1.0 if is_top else -1.0)
    # Join coincident front/back edge vertices while retaining the per-face
    # UV coordinates. Recalculate smooth normals on the joined surface.
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.normal_update()
    return bm


def pivot_for(name, cfg, mask, scale):
    h, w = mask.shape
    if name == "Torso":
        return Vector((0.0, 0.0, 0.0))
    if name.startswith("Arm"):
        cut = cfg["cut_a"] if name == "ArmA" else cfg["cut_b"]
        sign = -1 if name == "ArmA" else 1
        px = cut[0][0] + sign * -10  # a little inside the shoulder
        py = cfg["a_top"] + 14
    else:
        ys, xs = np.nonzero(mask[cfg["crotch"]:cfg["crotch"] + 12])
        px = xs.mean() if xs.size else cfg["cx"] + (-24 if name == "LegA" else 24)
        py = cfg["leg_pivot"]
    return Vector(((px - cfg["cx"]) * scale, 0.0, (foot_y_global[0] - py) * scale))


foot_y_global = [0.0]
foot_y = 0.0


def build_character(char_id, cfg, out_dir, tex_dir):
    global foot_y
    arr = cv2.imread(os.path.join(REFS, cfg["src"] + ".png"), cv2.IMREAD_UNCHANGED)
    bgr, alpha = arr[..., :3], arr[..., 3] / 255.0
    mask = alpha > 0.5
    ys = np.flatnonzero(mask.any(axis=1))
    height_px = ys[-1] - ys[0] + 1
    scale = HEIGHT / height_px
    # shift rows so the soles are at the bottom: rows are used as-is, z measured from foot_y
    foot_y = ys[-1] + 1
    foot_y_global[0] = foot_y
    h, w = mask.shape

    atlas = make_atlas(bgr, alpha, cfg["back"])
    atlas_path = os.path.join(tex_dir, "char_%s.png" % char_id)
    cv2.imwrite(atlas_path, atlas)
    image = bpy.data.images.load(atlas_path)
    image.name = "char_%s" % char_id
    image.pack()
    mat = bpy.data.materials.new("char_%s" % char_id)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Linear"
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85

    objects = []
    for name, part_mask in part_masks(cfg, mask).items():
        bm = build_part(name, part_mask, cfg, scale, cfg["foot"], atlas.shape[1], atlas.shape[0], w)
        if len(bm.verts) == 0:
            bm.free()
            continue
        pivot = pivot_for(name, cfg, part_mask, scale)
        bmesh.ops.translate(bm, vec=-pivot, verts=bm.verts)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        obj.location = pivot
        bpy.context.scene.collection.objects.link(obj)
        objects.append(obj)

    for other in bpy.context.scene.objects:
        other.select_set(other in objects)
    bpy.context.view_layer.objects.active = objects[0]
    path = os.path.join(out_dir, "char_%s.glb" % char_id)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format="GLB", use_selection=True, export_apply=True,
        export_yup=True, export_materials="EXPORT", export_image_format="AUTO",
        export_cameras=False, export_lights=False, export_normals=True, export_tangents=True)
    tris = sum(len(p.vertices) - 2 for o in objects for p in o.data.polygons)
    print("exported", os.path.basename(path), "parts:", [o.name for o in objects], "tris:", tris,
          "pivots:", {o.name: tuple(round(c, 2) for c in o.location) for o in objects})
    for obj in objects:
        bpy.data.objects.remove(obj)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    out_dir = os.path.abspath(argv[0] if argv else "assets/models/characters")
    only = set(argv[1:])
    os.makedirs(out_dir, exist_ok=True)
    tex_dir = os.path.join(HERE, "character_atlases")
    os.makedirs(tex_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for char_id, cfg in CHARACTERS.items():
        if only and char_id not in only:
            continue
        if not os.path.exists(os.path.join(REFS, cfg["src"] + ".png")):
            print("skipping", char_id, "- no reference image yet")
            continue
        build_character(char_id, cfg, out_dir, tex_dir)


if __name__ == "__main__":
    main()
