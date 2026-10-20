#!/usr/bin/env python3
"""Fetch C3PI pill images for the four target drugs plus distractors.

Run with:  .venv/bin/python -I fetch_c3pi.py [--distractors 60]
Everything is downscaled right after download; only the small copy is kept.
manifest.csv local_path values are relative to the data/ directory.
"""
import argparse
import collections
import csv
import html
import io
import re
import sys
import threading
import time
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests
from PIL import Image, ImageOps

BASE = "https://data.lhncbc.nlm.nih.gov/public/Pills/"
HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
SEG_LAYOUT = "MC_C3PI_REFERENCE_SEG_V1.6"
TEST_LAYOUT = "C3PI_Test"
SEG_MAX, TEST_MAX = 768, 1024
MAX_WORKERS = 4

# generic and brand names per target class (case-insensitive substring match)
TARGETS = {
    "benzonatate": ["benzonatate", "tessalon"],
    "phenazopyridine": ["phenazopyridine", "pyridium"],
    "atorvastatin": ["atorvastatin", "lipitor"],
    "lisinopril": ["lisinopril", "zestril", "prinivil", "qbrelis"],
}
ALL_TARGET_WORDS = [w for ws in TARGETS.values() for w in ws]
COMBO_WORDS = ["hydrochlorothiazide", "hctz", "amlodipine", "clavulan"]
PRIORITY_COLORS = ["WHITE", "PINK", "YELLOW", "PEACH"]
PRIORITY_SHAPES = ["ROUND", "OVAL", "CAPSULE"]

_session = requests.Session()
_session.headers["User-Agent"] = "CareBridge-pill-detector-research/1.0"
_lock = threading.Semaphore(MAX_WORKERS)  # hard cap on concurrent requests


def get(url, tries=6):
    for i in range(tries):
        try:
            with _lock:
                r = _session.get(url, timeout=60)
            if r.status_code == 200:
                return r.content
            if r.status_code == 404:
                return None
        except requests.RequestException:
            pass
        time.sleep(2 ** i)
    return None


def clean_name(name):
    return re.sub(r"<[^>]*>", "", html.unescape(name)).strip()


def is_combo(name):
    n = name.lower()
    return "/" in n or " and " in n or any(w in n for w in COMBO_WORDS)


def target_class(name):
    n = clean_name(name).lower()
    hits = {c for c, ws in TARGETS.items() if any(w in n for w in ws)}
    if len(hits) != 1 or is_combo(n):
        return None
    return hits.pop()


def mentions_target(name):
    n = clean_name(name).lower()
    return any(w in n for w in ALL_TARGET_WORDS)


def safe(s):
    return re.sub(r"[^A-Za-z0-9._-]", "_", s)


def load_index():
    path = DATA / "directory_of_images.txt"
    if not path.exists():
        print("downloading index ...")
        data = get(BASE + "directory_of_images.txt")
        if data is None:
            sys.exit("could not download index")
        path.write_bytes(data)
    rows = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        p = line.split("|")
        if len(p) != 5:
            continue
        ndc, _part, rel, layout, name = p
        ok = (layout == SEG_LAYOUT and rel.lower().endswith(".png")) or \
             (layout == TEST_LAYOUT and rel.lower().endswith((".jpg", ".jpeg")))
        m = re.match(r"(PillProjectDisc\d+)/", rel)
        if ok and m and re.fullmatch(r"\d{11}", ndc):
            rows.append(dict(ndc11=ndc, rel=rel, layout=layout, name=clean_name(name), disc=m.group(1)))
    return rows


def load_disc_meta(disc):
    xmlp = DATA / "xml" / f"{disc}.xml"
    if not xmlp.exists():
        data = get(f"{BASE}ALLXML/{disc}.xml")
        if data is None:
            print(f"warning: no XML for {disc}")
            return {}
        xmlp.parent.mkdir(parents=True, exist_ok=True)
        xmlp.write_bytes(data)
    meta = {}
    for im in ET.parse(xmlp).getroot().iter("Image"):
        fn = im.findtext("File/Name")
        if fn:
            meta[fn] = dict(imprint=(im.findtext("Imprint") or "").strip(),
                            color=(im.findtext("Color") or "").strip().upper(),
                            shape=(im.findtext("Shape") or "").strip().upper())
    return meta


def process(img_bytes, layout):
    im = Image.open(io.BytesIO(img_bytes))
    out = io.BytesIO()
    if layout == SEG_LAYOUT:
        im = im.convert("RGBA")  # 16-bit -> 8-bit; alpha (pill mask) is converted alongside
        im.thumbnail((SEG_MAX, SEG_MAX), Image.LANCZOS)  # RGBA resize is alpha-aware
        im.save(out, "PNG", optimize=True)
    else:
        im = ImageOps.exif_transpose(im).convert("RGB")
        im.thumbnail((TEST_MAX, TEST_MAX), Image.LANCZOS)
        im.save(out, "JPEG", quality=90)
    return out.getvalue()


def local_path(row):
    seg = row["layout"] == SEG_LAYOUT
    stem = safe(Path(row["rel"]).stem)
    return f"{'seg' if seg else 'test'}/{row['ndc11']}/{row['disc']}_{stem}.{'png' if seg else 'jpg'}"


def download(row):
    dest = DATA / row["local_path"]
    if dest.exists() and dest.stat().st_size > 0:
        return True
    raw = get(BASE + row["rel"])
    if raw is None:
        return False
    try:
        small = process(raw, row["layout"])
    except Exception as e:  # corrupt image
        print(f"bad image {row['rel']}: {e}")
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    tmp.write_bytes(small)
    tmp.replace(dest)
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--distractors", type=int, default=60, help="distractor NDC count")
    ap.add_argument("--distractor-seg-per-ndc", type=int, default=8)
    ap.add_argument("--distractor-test-per-ndc", type=int, default=3)
    args = ap.parse_args()
    DATA.mkdir(exist_ok=True)

    rows = load_index()
    targets = []
    for r in rows:
        c = target_class(r["name"])
        if c:
            r["class"] = c
            targets.append(r)
    discs = sorted({r["disc"] for r in targets}, key=lambda d: int(d[len("PillProjectDisc"):]))
    print(f"{len(targets)} target rows across {len(discs)} discs; fetching XML")
    with ThreadPoolExecutor(MAX_WORKERS) as ex:
        meta = dict(zip(discs, ex.map(load_disc_meta, discs)))

    def attach(r):
        m = meta.get(r["disc"], {}).get(Path(r["rel"]).name, {})
        r.update(imprint=m.get("imprint", ""), color=m.get("color", ""), shape=m.get("shape", ""))

    # distractors: only NDCs from discs whose XML we already have; never a target drug by name
    cand = collections.defaultdict(list)
    for r in rows:
        if r["disc"] in meta and "class" not in r and not mentions_target(r["name"]):
            cand[r["ndc11"]].append(r)
    target_ndcs = {r["ndc11"] for r in targets}
    groups = collections.defaultdict(list)
    for ndc, rs in sorted(cand.items()):
        if ndc in target_ndcs:
            continue
        for r in rs:
            attach(r)
        segs = [r for r in rs if r["layout"] == SEG_LAYOUT]
        if len(segs) < 4:
            continue
        s0 = next((r for r in segs if r["color"] and r["shape"]), None)
        if s0:
            groups[(s0["color"], s0["shape"])].append(ndc)
    prio = [(c, s) for c in PRIORITY_COLORS for s in PRIORITY_SHAPES]
    order = [k for k in prio if k in groups] + sorted(k for k in groups if k not in prio)
    pools = {k: list(groups[k]) for k in order}
    chosen = []
    while len(chosen) < args.distractors and any(pools.values()):
        for k in order:
            if pools[k] and len(chosen) < args.distractors:
                chosen.append(pools[k].pop(0))

    selected = list(targets)
    for ndc in chosen:
        rs = cand[ndc]
        segs = sorted((r for r in rs if r["layout"] == SEG_LAYOUT), key=lambda r: r["rel"])
        tests = sorted((r for r in rs if r["layout"] == TEST_LAYOUT), key=lambda r: r["rel"])
        for r in segs[:args.distractor_seg_per_ndc] + tests[:args.distractor_test_per_ndc]:
            r["class"] = "other"
            selected.append(r)
    for r in targets:
        attach(r)
    for r in selected:
        r["local_path"] = local_path(r)
    print(f"downloading {len(selected)} images ({len(chosen)} distractor NDCs)", flush=True)

    ok_rows = []
    with ThreadPoolExecutor(MAX_WORKERS) as ex:
        for i, (r, ok) in enumerate(zip(selected, ex.map(download, selected)), 1):
            if ok:
                ok_rows.append(r)
            else:
                print(f"FAILED {r['rel']}")
            if i % 200 == 0:
                print(f"  {i}/{len(selected)}", flush=True)

    with open(DATA / "manifest.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ndc11", "class", "layout", "local_path", "imprint", "color", "shape", "name"])
        for r in ok_rows:
            w.writerow([r["ndc11"], r["class"], r["layout"], r["local_path"],
                        r["imprint"], r["color"], r["shape"], r["name"]])

    cnt = collections.Counter((r["class"], "SEG" if r["layout"] == SEG_LAYOUT else "Test") for r in ok_rows)
    print("\nSummary (class: SEG / Test):")
    for c in list(TARGETS) + ["other"]:
        print(f"  {c}: {cnt[(c, 'SEG')]} / {cnt[(c, 'Test')]}")
    print(f"  failed downloads: {len(selected) - len(ok_rows)}")
    print(f"  distractor NDCs: {len({r['ndc11'] for r in ok_rows if r['class'] == 'other'})}")
    total = sum(p.stat().st_size for p in DATA.rglob("*") if p.is_file())
    print(f"  data dir size: {total / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
