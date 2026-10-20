#!/usr/bin/env python3
"""Synthetic mixed-pill composites for the CareBridge Create ML object detector.

Reads data/manifest.csv (MC_C3PI_REFERENCE_SEG_V1.6 RGBA cut-outs only), splits
NDCs into train/holdout (20% per class), and writes Create ML object-detection
datasets to data/composites/{train,val}/images/ (+ annotations.json).

Boxes are the tight bbox of the placed pill's alpha > 127 (never of the shadow).
Output is fully reproducible from --seed.
"""
import argparse
import csv
import json
import math
import random
import shutil
from collections import Counter, defaultdict
from multiprocessing import Pool
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

IMG_W, IMG_H = 1024, 768
MIN_GAP = 4
ALPHA_T = 127
TARGET_CLASSES = ["benzonatate", "phenazopyridine", "atorvastatin", "lisinopril"]
SEG_LAYOUT = "MC_C3PI_REFERENCE_SEG_V1.6"
HERE = Path(__file__).resolve().parent
SCALE_MAX = 0.22  # max pill long side as a fraction of image width
P_OTHER = 0.35  # per-pill chance of a distractor (then clamped by the >=30% target rule)


# ---------------------------------------------------------------- split
def split_ndcs(rows, seed=42, holdout_frac=0.2):
    """Per-class deterministic split. Returns (train_ndcs, holdout_ndcs), sorted."""
    by_cls = defaultdict(set)
    for r in rows:
        by_cls[r["class"]].add(r["ndc11"])
    rng = random.Random(seed)
    train, hold = [], []
    for cls in sorted(by_cls):
        ndcs = sorted(by_cls[cls])
        rng.shuffle(ndcs)
        k = max(1, round(holdout_frac * len(ndcs)))
        if len(ndcs) > 1:
            k = min(k, len(ndcs) - 1)
        hold += ndcs[:k]
        train += ndcs[k:]
    return sorted(train), sorted(hold)


# ---------------------------------------------------------------- backgrounds
def _noise(nrng, w, h, cell):
    g = nrng.random((h // cell + 2, w // cell + 2)).astype(np.float32)
    im = Image.fromarray(g, mode="F").resize((w, h), Image.BICUBIC)
    return np.clip(np.asarray(im), 0, 1)


def _fbm(nrng, w, h, base=128, octaves=4):
    out, amp, tot = np.zeros((h, w), np.float32), 1.0, 0.0
    for o in range(octaves):
        out += amp * _noise(nrng, w, h, max(2, base >> o))
        tot += amp
        amp *= 0.5
    return out / tot


def _rand_color(rng, lo=0, hi=255):
    return np.array([rng.randint(lo, hi) for _ in range(3)], np.float32)


def procedural_background(rng, w=IMG_W, h=IMG_H):
    nrng = np.random.default_rng(rng.getrandbits(32))
    kind = rng.choice(["flat", "gradient", "wood", "palm"])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    if kind == "flat":
        arr = np.ones((h, w, 3), np.float32) * _rand_color(rng)
    elif kind == "gradient":
        a, b = _rand_color(rng), _rand_color(rng)
        th = rng.uniform(0, math.tau)
        t = (xx * math.cos(th) + yy * math.sin(th))
        t = (t - t.min()) / max(1e-6, t.max() - t.min())
        arr = a + (b - a) * t[..., None]
    elif kind == "wood":
        base = np.array([rng.randint(110, 190), rng.randint(70, 130), rng.randint(30, 80)], np.float32)
        dark = base * rng.uniform(0.55, 0.8)
        warp = _fbm(nrng, w, h, 96, 4) * rng.uniform(15, 40)
        freq = rng.uniform(0.04, 0.12)
        s = 0.5 + 0.5 * np.sin((yy + warp * 3) * freq + _fbm(nrng, w, h, 32, 3) * 4)
        arr = dark + (base - dark) * s[..., None]
    else:  # palm: skin-tone blobs with noise
        skin = np.array([rng.randint(150, 235), rng.randint(105, 185), rng.randint(80, 160)], np.float32)
        arr = np.ones((h, w, 3), np.float32) * skin
        blob = np.zeros((h, w), np.float32)
        for _ in range(rng.randint(3, 6)):
            cx, cy = rng.uniform(0, w), rng.uniform(0, h)
            rx, ry = rng.uniform(150, 450), rng.uniform(120, 350)
            blob += np.exp(-(((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2) * 2)
        blob = np.clip(blob, 0, 1)
        shade = _fbm(nrng, w, h, 64, 4)
        arr = arr * (0.82 + 0.18 * blob[..., None] + 0.2 * (shade[..., None] - 0.5))
        arr[..., 0] *= 1.0 + 0.04 * (shade - 0.5)[..., ]
    fine = nrng.normal(0, rng.uniform(1, 4), (h, w, 1)).astype(np.float32)
    arr = arr * rng.uniform(0.9, 1.1) + fine
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGB")


def make_background(rng, backgrounds):
    if backgrounds and rng.random() < 0.4:
        im = Image.open(rng.choice(backgrounds)).convert("RGB")
        scale = max(IMG_W / im.width, IMG_H / im.height)
        im = im.resize((max(IMG_W, round(im.width * scale)), max(IMG_H, round(im.height * scale))))
        x0 = rng.randint(0, im.width - IMG_W)
        y0 = rng.randint(0, im.height - IMG_H)
        return im.crop((x0, y0, x0 + IMG_W, y0 + IMG_H))
    return procedural_background(rng)


# ---------------------------------------------------------------- pills
def _alpha_bbox(img, thresh):
    a = np.asarray(img.split()[3])
    ys, xs = np.where(a > thresh)
    if len(xs) == 0:
        return None
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def strip_label(img):
    """Remove the NLM caption strip that C3PI SEG cut-outs carry at the bottom.

    The strip is a separate, near-full-width opaque band touching the image
    bottom, separated from the pill by transparent rows. Its alpha is zeroed so
    it can never be pasted or enter a box. Images without such a band (e.g.
    synthetic fixtures) are returned unchanged.
    """
    a = np.asarray(img.split()[3]) > ALPHA_T
    h, w = a.shape
    rows = a.any(1)
    last = np.nonzero(rows)[0]
    if len(last) == 0:
        return img
    end = last[-1] + 1
    start = end
    while start > 0 and rows[start - 1]:
        start -= 1
    if start == 0 or end != h:
        return img  # no separate bottom band
    xs = np.nonzero(a[start:end].any(0))[0]
    if xs.max() - xs.min() + 1 < 0.9 * w:
        return img
    arr = np.array(img)
    arr[start:, :, 3] = 0
    return Image.fromarray(arr, "RGBA")


def prepare_pill(rng, src):
    """Crop, scale (long side 8-22% of image width), rotate, jitter.

    Returns (sprite RGBA, box) where box = tight bbox (x0,y0,x1,y1) of sprite
    alpha > 127 in sprite coordinates.
    """
    if not isinstance(src, Image.Image):
        src = Image.open(src)
    src = strip_label(src.convert("RGBA"))
    bb = _alpha_bbox(src, ALPHA_T)
    src = src.crop(bb)
    long_side = rng.uniform(0.08, SCALE_MAX) * IMG_W
    s = long_side / max(src.size)
    src = src.resize((max(1, round(src.width * s)), max(1, round(src.height * s))), Image.LANCZOS)
    src = src.rotate(rng.uniform(0, 360), resample=Image.BICUBIC, expand=True)
    # brightness/contrast jitter +-15% on pill RGB only (alpha untouched)
    arr = np.asarray(src).astype(np.float32)
    bright, contrast = rng.uniform(0.85, 1.15), rng.uniform(0.85, 1.15)
    rgb = arr[..., :3]
    mean = rgb[arr[..., 3] > ALPHA_T].mean() if (arr[..., 3] > ALPHA_T).any() else 128.0
    arr[..., :3] = np.clip((rgb - mean) * contrast + mean * bright, 0, 255)
    src = Image.fromarray(arr.astype(np.uint8), "RGBA")
    # crop to alpha>0 extent, then report the alpha>127 box inside it
    full = _alpha_bbox(src, 0)
    src = src.crop(full)
    return src, _alpha_bbox(src, ALPHA_T)


def paste_with_shadow(bg, sprite, box, x0, y0, rng):
    """Paste sprite so its tight box top-left lands at (x0,y0). Shadow goes beneath."""
    px, py = x0 - box[0], y0 - box[1]
    pad = 14
    a = sprite.split()[3]
    layer = Image.new("L", (sprite.width + 2 * pad, sprite.height + 2 * pad), 0)
    layer.paste(a, (pad, pad))
    layer = layer.filter(ImageFilter.GaussianBlur(rng.uniform(3, 6)))
    layer = layer.point(lambda v: int(v * rng.uniform(0.25, 0.45)))
    dx, dy = rng.randint(2, 6), rng.randint(3, 8)
    black = Image.new("RGB", layer.size, (0, 0, 0))
    bg.paste(black, (px - pad + dx, py - pad + dy), layer)
    bg.paste(sprite.convert("RGB"), (px, py), a)


def _separated(a, b, gap=MIN_GAP):
    return (b[0] - a[2] >= gap or a[0] - b[2] >= gap or
            b[1] - a[3] >= gap or a[1] - b[3] >= gap)


def place_boxes(rng, sizes, tries=50):
    """Place (w,h) boxes in the image with >= MIN_GAP separation. None on failure.

    Returns list of (x0,y0,x1,y1) in the order of `sizes`.
    """
    order = sorted(range(len(sizes)), key=lambda i: -sizes[i][0] * sizes[i][1])
    placed, out = [], [None] * len(sizes)
    for i in order:
        w, h = sizes[i]
        if w > IMG_W or h > IMG_H:
            return None
        for _ in range(tries):
            x0, y0 = rng.randint(0, IMG_W - w), rng.randint(0, IMG_H - h)
            cand = (x0, y0, x0 + w, y0 + h)
            if all(_separated(cand, p) for p in placed):
                placed.append(cand)
                out[i] = cand
                break
        else:
            return None
    return out


def _pick(rng, pool):
    """pool: list of images/paths, or {ndc: list} (NDC chosen uniformly first)."""
    if isinstance(pool, dict):
        pool = pool[rng.choice(sorted(pool))]
    return rng.choice(pool)


def choose_labels(rng, targets):
    n = rng.randint(1, 8)
    max_other = n - math.ceil(0.3 * n)
    n_other = min(sum(rng.random() < P_OTHER for _ in range(n)), max_other)
    labels = [rng.choice(targets) for _ in range(n - n_other)] + ["other"] * n_other
    rng.shuffle(labels)
    return labels


def compose_image(rng, pools, targets=TARGET_CLASSES, backgrounds=()):
    """Returns (PIL RGB image 1024x768, [Create ML annotation dicts])."""
    for _ in range(30):
        labels = choose_labels(rng, targets)
        prepared = [prepare_pill(rng, _pick(rng, pools[l])) for l in labels]
        sizes = [(b[2] - b[0], b[3] - b[1]) for _, b in prepared]
        boxes = place_boxes(rng, sizes)
        if boxes is not None:
            break
    else:
        raise RuntimeError("could not place pills")
    bg = make_background(rng, list(backgrounds))
    anns = []
    for lab, (sprite, sb), (x0, y0, x1, y1) in zip(labels, prepared, boxes):
        paste_with_shadow(bg, sprite, sb, x0, y0, rng)
        anns.append({"label": lab, "coordinates": {
            "x": (x0 + x1) / 2, "y": (y0 + y1) / 2, "width": x1 - x0, "height": y1 - y0}})
    return bg, anns


# ---------------------------------------------------------------- driver
_G = {}


def _init(g):
    _G.update(g)


def _work(job):
    global P_OTHER, SCALE_MAX
    split, idx = job
    # optional train-only overrides (val keeps the defaults so it stays comparable)
    P_OTHER = _G["train_p_other"] if split == "train" else 0.35
    SCALE_MAX = _G["train_scale_max"] if split == "train" else 0.22
    rng = random.Random(f"{_G['seed']}-{split}-{idx}")
    img, anns = compose_image(rng, _G["pools"][split], TARGET_CLASSES, _G["bgs"])
    name = f"{idx + 1:04d}.jpg"
    img.save(_G["out"] / split / "images" / name, quality=90)
    return {"image": name, "annotations": anns}


def build_pools(rows, ndcs, data_dir):
    keep = set(ndcs)
    pools = defaultdict(lambda: defaultdict(list))
    for r in rows:
        if r["layout"] == SEG_LAYOUT and r["ndc11"] in keep:
            pools[r["class"]][r["ndc11"]].append(str(data_dir / r["local_path"]))
    return {c: dict(v) for c, v in pools.items()}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", type=Path, default=HERE / "data")
    ap.add_argument("--bg-dir", type=Path, default=HERE / "backgrounds")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--count", "--train-count", dest="train_count", type=int, default=6000)
    ap.add_argument("--val-count", type=int, default=800)
    ap.add_argument("--train-p-other", type=float, default=0.35)
    ap.add_argument("--train-scale-max", type=float, default=0.22)
    ap.add_argument("--workers", type=int, default=4)
    a = ap.parse_args()

    with open(a.data_dir / "manifest.csv", newline="") as f:
        rows = [r for r in csv.DictReader(f) if r["layout"] == SEG_LAYOUT]
    train, hold = split_ndcs(rows, a.seed)
    (a.data_dir / "split.json").write_text(
        json.dumps({"train_ndcs": train, "holdout_ndcs": hold}, indent=1))
    bgs = sorted(p for p in a.bg_dir.glob("*") if p.suffix.lower() in (".jpg", ".jpeg", ".png")) \
        if a.bg_dir.is_dir() else []
    out = a.data_dir / "composites"
    g = dict(train_p_other=a.train_p_other, train_scale_max=a.train_scale_max, seed=a.seed, out=out, bgs=bgs, pools={
        "train": build_pools(rows, train, a.data_dir), "val": build_pools(rows, hold, a.data_dir)})

    for split, n in (("train", a.train_count), ("val", a.val_count)):
        shutil.rmtree(out / split, ignore_errors=True)
        (out / split / "images").mkdir(parents=True)
        with Pool(a.workers, initializer=_init, initargs=(g,)) as p:
            results = p.map(_work, [(split, i) for i in range(n)], chunksize=20)
        text = json.dumps(results)
        # annotations.json inside images/ (Create ML .createMLFormat resolves names
        # relative to it) and a copy beside it.
        (out / split / "images" / "annotations.json").write_text(text)
        (out / split / "annotations.json").write_text(text)
        counts = Counter(an["label"] for r in results for an in r["annotations"])
        total = sum(counts.values())
        print(f"{split}: {n} images, {total} pills")
        for c in TARGET_CLASSES + ["other"]:
            print(f"  {c}: {counts[c]} ({100 * counts[c] / total:.1f}%)")


if __name__ == "__main__":
    main()
