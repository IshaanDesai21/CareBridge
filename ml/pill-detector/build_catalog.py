#!/usr/bin/env python3
"""Build pill_catalog.json (imprint/appearance/strength per target NDC).

Run with:  .venv/bin/python -I build_catalog.py
Reads data/manifest.csv (from fetch_c3pi.py), looks up each target NDC's
conceptName on RxNav, and writes one row per imprint side. NDCs with no
conceptName / unparseable strength / drug mismatch are skipped and listed.
"""
import collections
import csv
import json
import re
import time
from pathlib import Path

import requests

HERE = Path(__file__).resolve().parent
MANIFEST = HERE / "data" / "manifest.csv"
OUT = HERE / "pill_catalog.json"
TARGETS = ["benzonatate", "phenazopyridine", "atorvastatin", "lisinopril"]
RXNAV = "https://rxnav.nlm.nih.gov/REST/ndcstatus.json"


def concept_name(ndc):
    for i in range(5):
        try:
            r = requests.get(RXNAV, params={"ndc": ndc}, timeout=30)
            if r.status_code == 200:
                return (r.json().get("ndcStatus") or {}).get("conceptName")
        except (requests.RequestException, ValueError):
            pass
        time.sleep(2 ** i)
    return None


def parse(concept, drug):
    """Return (strength, form) or None. Single-ingredient, mg-based only."""
    c = concept.lower()
    if drug not in c or "/" in c or " / " in c:
        return None
    m = re.search(r"(\d+(?:\.\d+)?)\s*mg\b", c)
    form = "capsule" if re.search(r"\bcapsule", c) else "tablet" if re.search(r"\btablet", c) else None
    if not m or not form:
        return None
    num = m.group(1)
    if "." in num:
        num = num.rstrip("0").rstrip(".")
    return f"{num} mg", form


def main():
    per_ndc = collections.defaultdict(list)
    with open(MANIFEST, newline="") as f:
        for r in csv.DictReader(f):
            if r["class"] in TARGETS and r["imprint"].strip():
                per_ndc[(r["ndc11"], r["class"])].append((r["imprint"].strip(), r["color"], r["shape"]))
    catalog, skipped = [], []
    for (ndc, drug), obs in sorted(per_ndc.items()):
        concept = concept_name(ndc)
        parsed = parse(concept, drug) if concept else None
        if not parsed:
            skipped.append((ndc, drug, concept))
            continue
        strength, form = parsed
        imprint, color, shape = collections.Counter(obs).most_common(1)[0][0]
        seen = set()
        for side in imprint.split(";"):
            side = side.strip()
            if not side or side.upper() in seen:
                continue
            seen.add(side.upper())
            catalog.append(dict(imprint=side, drug=drug, strength=strength, form=form,
                                color=color, shape=shape, ndc11=ndc))
    OUT.write_text(json.dumps(catalog, indent=2) + "\n")
    counts = collections.Counter(r["drug"] for r in catalog)
    print(f"wrote {len(catalog)} rows to {OUT}")
    for d in TARGETS:
        print(f"  {d}: {counts[d]} rows, {len({r['ndc11'] for r in catalog if r['drug'] == d})} NDCs")
    print(f"skipped NDCs ({len(skipped)}):")
    for ndc, drug, concept in skipped:
        print(f"  {ndc} [{drug}] conceptName={concept!r}")


if __name__ == "__main__":
    main()
