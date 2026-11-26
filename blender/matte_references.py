import cv2, numpy as np, glob, os
os.makedirs('mattes', exist_ok=True)
for f in sorted(glob.glob('/home/claude/char_refs/0?_*.png')):
    if 'grid' in f: continue
    name = os.path.basename(f)[:-4]
    img = cv2.imread(f, cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    # probable foreground: a generous box around the figure; sure background: the outer frame
    mask[8:h-8, 40:w-40] = cv2.GC_PR_FGD
    # background-colour pixels connected to the border are sure background
    bg = np.median(np.concatenate([img[:6].reshape(-1,3), img[:, :6].reshape(-1,3), img[:, -6:].reshape(-1,3)]), axis=0)
    dist = np.linalg.norm(img.astype(float) - bg, axis=2)
    mn = img.min(axis=2).astype(int); mx = img.max(axis=2).astype(int)
    lightlow = ((mn > 192) & (mx - mn < 34))
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(cv2.GaussianBlur(gray, (0,0), 1.2), 14, 36)
    edges = cv2.dilate(edges, np.ones((3,3), np.uint8))
    near = (lightlow & (edges == 0)).astype(np.uint8)
    n, lab = cv2.connectedComponents(near, connectivity=4)
    border_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:,0], lab[:,-1]]))) - {0}
    sure_bg = np.isin(lab, list(border_labels))
    sure_bg = cv2.dilate(sure_bg.astype(np.uint8), np.ones((3,3), np.uint8)).astype(bool)
    mask[sure_bg] = cv2.GC_BGD
    # strongly different from background = sure foreground core
    core = (dist > 60)
    core = cv2.erode(core.astype(np.uint8), np.ones((3,3), np.uint8)).astype(bool)
    mask[core & ~sure_bg] = cv2.GC_FGD
    bgd = np.zeros((1,65)); fgd = np.zeros((1,65))
    cv2.grabCut(img, mask, None, bgd, fgd, 6, cv2.GC_INIT_WITH_MASK)
    fg = ((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)).astype(np.uint8)
    # large smooth background-coloured pockets (between arms and body, between legs) are not figure
    blur = cv2.GaussianBlur(img.astype(np.float32), (0,0), 2.0)
    var = cv2.GaussianBlur(((img.astype(np.float32)-blur)**2).sum(axis=2), (0,0), 2.0)
    mn = img.min(axis=2).astype(int); mx = img.max(axis=2).astype(int)
    smooth_near = (((dist < 32) | ((mn > 185) & (mx - mn < 28))) & (var < 70)).astype(np.uint8)
    smooth_near = cv2.morphologyEx(smooth_near, cv2.MORPH_OPEN, np.ones((3,3), np.uint8))
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(smooth_near, connectivity=4)
    for i in range(1, n2):
        if st2[i, cv2.CC_STAT_AREA] > 700:
            fg[lab2 == i] = 0
    # keep the largest component, fill holes, light smoothing
    n, lab, stats, _ = cv2.connectedComponentsWithStats(fg, connectivity=8)
    keep = np.zeros_like(fg)
    for i in range(1, n):
        if stats[i, cv2.CC_STAT_AREA] > 150: keep[lab == i] = 1
    fg = keep
    fg = cv2.morphologyEx(fg, cv2.MORPH_CLOSE, np.ones((3,3), np.uint8))
    alpha = cv2.GaussianBlur(fg.astype(np.float32), (0,0), 0.8)
    out = np.dstack([img, (np.clip(alpha,0,1)*255).astype(np.uint8)])
    cv2.imwrite(f'mattes/{name}.png', out)
    comp = img.copy().astype(np.float32)
    comp = comp*alpha[...,None] + np.array([200,0,200],np.float32)*(1-alpha[...,None])
    cv2.imwrite(f'mattes/{name}_check.png', comp.astype(np.uint8))
    print(name, 'fg frac %.3f' % fg.mean())
# contact sheet
checks = [cv2.imread(f'mattes/{os.path.basename(f)[:-4]}_check.png') for f in sorted(glob.glob('/home/claude/char_refs/0?_*.png')) if 'grid' not in f]
row1 = np.hstack(checks[:4]); row2 = np.hstack(checks[4:] + [np.zeros_like(checks[0])])
cv2.imwrite('mattes/sheet.png', np.vstack([row1,row2]))
