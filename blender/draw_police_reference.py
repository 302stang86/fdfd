"""Draw a stand-in reference for the police officer outfit.

The supplied reference sheet has seven characters but the game has eight outfits; the
police officer is missing. This draws a simple, flat-shaded placeholder in the same
354 x 535 RGBA layout so the same Blender pipeline can build it. Replace
blender/character_refs/08_Police.png with a proper cut-out and re-run make_characters.py
when you have real art.

    python blender/draw_police_reference.py blender/character_refs/08_Police.png
"""
import sys

import cv2
import numpy as np

S = 3  # supersampling factor
W, H = 354, 535
CX = 176

canvas = np.zeros((H * S, W * S, 3), np.float32)
alpha = np.zeros((H * S, W * S), np.float32)


def rgb(hex_color):
    return np.array([int(hex_color[i:i + 2], 16) for i in (5, 3, 1)], np.float32)  # BGR


def poly(points, mirror=False):
    pts = [(CX * 2 - x if mirror else x, y) for x, y in points]
    m = np.zeros(alpha.shape, np.uint8)
    cv2.fillPoly(m, [np.array([(int(x * S), int(y * S)) for x, y in pts], np.int32)], 255,
                 lineType=cv2.LINE_AA)
    return m


def ellipse(cx, cy, rx, ry, mirror=False):
    m = np.zeros(alpha.shape, np.uint8)
    x = CX * 2 - cx if mirror else cx
    cv2.ellipse(m, (int(x * S), int(cy * S)), (int(rx * S), int(ry * S)), 0, 0, 360, 255, -1,
                lineType=cv2.LINE_AA)
    return m


def shade(mask, color, edge=0.28, side=0.22, gloss=0.0):
    """Fill mask with a colour darkened toward its edges, plus a soft side gradient."""
    weight = mask.astype(np.float32) / 255.0
    ys, xs = np.nonzero(mask)
    if xs.size == 0:
        return
    inner = cv2.distanceTransform((mask > 127).astype(np.uint8), cv2.DIST_L2, 3)
    rim = 1.0 - edge * (1.0 - np.clip(inner / (5.0 * S), 0, 1))
    x0, x1 = xs.min(), xs.max()
    gx = (np.arange(mask.shape[1], dtype=np.float32) - (x0 + x1) / 2.0) / max((x1 - x0) / 2.0, 1)
    lit = 1.0 - side * np.clip(gx, -1, 1)[None, :] ** 2 + 0.06 * np.clip(-gx, 0, 1)[None, :]
    k = rim * lit
    if gloss:
        gy = (np.arange(mask.shape[0], dtype=np.float32) - ys.min()) / max(ys.max() - ys.min(), 1)
        k = k + gloss * np.exp(-((gy - 0.25) ** 2) / 0.02)[:, None]
    layer = np.clip(rgb(color)[None, None, :] * k[..., None], 0, 255)
    canvas[:] = canvas * (1 - weight[..., None]) + layer * weight[..., None]
    alpha[:] = np.maximum(alpha, weight)


def line(p0, p1, color, width=1.0):
    m = np.zeros(alpha.shape, np.uint8)
    cv2.line(m, (int(p0[0] * S), int(p0[1] * S)), (int(p1[0] * S), int(p1[1] * S)), 255,
             max(1, int(width * S)), lineType=cv2.LINE_AA)
    weight = m.astype(np.float32)[..., None] / 255.0
    canvas[:] = canvas * (1 - weight) + rgb(color)[None, None, :] * weight


def draw():
    navy, navy_dark, skin, black = "#26344d", "#1b2538", "#d29a76", "#14161b"
    for mirror in (False, True):  # legs and boots
        shade(poly([(128, 286), (176, 286), (172, 494), (137, 494)], mirror), "#1f2a40")
        shade(poly([(130, 484), (173, 484), (178, 515), (120, 515)], mirror), black, gloss=0.25)
        sx = 2 * CX - 150 if mirror else 150
        line((sx, 300), (sx - 1, 480), "#3d4c6b", 1.5)
    # torso
    shade(poly([(152, 96), (200, 96), (230, 106), (228, 150), (224, 290), (128, 290),
                (124, 150), (122, 106)]), navy)
    for mirror in (False, True):  # arms
        shade(poly([(122, 104), (125, 126), (112, 200), (107, 262), (80, 262), (84, 200),
                    (95, 126), (101, 106)], mirror), navy)
        shade(ellipse(93, 282, 13, 21, mirror), skin)
        shade(poly([(100, 112), (112, 112), (111, 136), (99, 136)], mirror), "#d6b04a", edge=0.4)
        shade(poly([(122, 102), (150, 98), (151, 110), (123, 114)], mirror), navy_dark)
    # collar, tie, pockets
    shade(poly([(150, 96), (176, 120), (164, 100)]), "#3a4a6c", edge=0.1)
    shade(poly([(202, 96), (176, 120), (188, 100)]), "#3a4a6c", edge=0.1)
    shade(poly([(170, 102), (182, 102), (184, 182), (176, 194), (168, 182)]), black)
    for x0, x1 in ((134, 164), (188, 218)):
        line((x0, 160), (x1, 160), "#3c4b69", 1.4)
        line((x0, 160), (x0, 196), "#3c4b69", 1.4)
        line((x1, 160), (x1, 196), "#3c4b69", 1.4)
        line((x0, 196), (x1, 196), "#3c4b69", 1.4)
    # badge and name plate
    shade(poly([(204, 150), (214, 150), (216, 162), (209, 170), (202, 162)]), "#d8b53f", edge=0.5)
    shade(poly([(140, 148), (162, 148), (162, 156), (140, 156)]), "#b9c0c8", edge=0.4)
    # radio on the shoulder
    shade(poly([(196, 110), (210, 110), (210, 140), (196, 140)]), black)
    line((209, 110), (212, 84), "#20232a", 1.8)
    # duty belt, holster, cuffs
    shade(poly([(126, 226), (226, 226), (226, 246), (126, 246)]), black, gloss=0.2)
    shade(poly([(164, 228), (188, 228), (188, 244), (164, 244)]), "#b9c0c8", edge=0.4)
    shade(poly([(126, 240), (152, 240), (154, 292), (126, 292)]), "#0e1014", gloss=0.2)
    shade(poly([(204, 244), (224, 244), (224, 268), (204, 268)]), "#0e1014")
    shade(poly([(154, 244), (166, 244), (166, 258), (154, 258)]), "#0e1014")
    # neck, head, ears
    shade(poly([(162, 84), (190, 84), (192, 102), (160, 102)]), "#b8825f")
    shade(ellipse(150, 62, 5, 9), "#c58b68")
    shade(ellipse(202, 62, 5, 9), "#c58b68")
    shade(ellipse(176, 58, 25, 31), skin, edge=0.18)
    shade(poly([(151, 48), (157, 48), (156, 66), (151, 62)]), "#2a2018", edge=0.1)
    shade(poly([(195, 48), (201, 48), (201, 62), (196, 66)]), "#2a2018", edge=0.1)
    # face
    for x in (166, 186):
        shade(ellipse(x, 60, 5.2, 3.4), "#f2eee9", edge=0.0, side=0.0)
        shade(ellipse(x, 60, 2.4, 2.8), "#3a2a1e", edge=0.0, side=0.0)
        line((x - 6, 53), (x + 6, 52), "#2a2018", 1.8)
    line((176, 62), (174, 74), "#b07650", 1.5)
    line((168, 84), (184, 84), "#8a4a3c", 1.8)
    # peaked cap
    shade(poly([(148, 34), (204, 34), (206, 46), (146, 46)]), navy_dark, edge=0.2)
    shade(poly([(146, 36), (151, 19), (176, 12), (201, 19), (206, 36)]), "#2d3d5c", edge=0.2)
    shade(poly([(150, 44), (202, 44), (212, 54), (140, 54)]), black, gloss=0.35)
    shade(poly([(170, 20), (182, 20), (184, 32), (176, 38), (168, 32)]), "#d8b53f", edge=0.5)


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "blender/character_refs/08_Police.png"
    draw()
    a_small = cv2.resize(alpha, (W, H), interpolation=cv2.INTER_AREA)
    premult = cv2.resize(canvas * alpha[..., None], (W, H), interpolation=cv2.INTER_AREA)
    color = premult / np.maximum(a_small[..., None], 1e-3)
    color = np.clip(color, 0, 255).astype(np.uint8)
    rgba = np.dstack([color, (np.clip(a_small, 0, 1) * 255).astype(np.uint8)])
    cv2.imwrite(out, rgba)
    ys, xs = np.nonzero(a_small > 0.5)
    print("police reference written", out, "bbox y", ys.min(), ys.max(), "x", xs.min(), xs.max())


if __name__ == "__main__":
    main()
