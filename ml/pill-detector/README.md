# Pill detector data

Training data and appearance catalog for the on-device pill detector (Create ML)
behind the caregiver pill-check feature. Target drugs: benzonatate,
phenazopyridine, atorvastatin, lisinopril (plus an `other` distractor class).

## Setup

    python3 -m venv .venv && .venv/bin/pip install -r requirements.txt

## Scripts (run from this directory, with `-I`)

- `.venv/bin/python -I fetch_c3pi.py [--distractors 60]`
  Downloads the C3PI index and per-disc XML, selects target rows by drug name
  (generic and brand; combination products and names matching more than one
  target are excluded), picks distractor NDCs (never a target drug, round-robin
  over color/shape groups, prioritising WHITE/PINK/YELLOW/PEACH x
  ROUND/OVAL/CAPSULE), downloads only `MC_C3PI_REFERENCE_SEG_V1.6` PNGs and
  `C3PI_Test` JPGs, and writes `data/manifest.csv`. At most 4 concurrent
  downloads, retry with backoff, existing files are skipped (resumable).
  Images are downscaled on download: SEG PNG to 8-bit RGBA, long side <= 768 px
  (alpha = pill mask); Test JPG long side <= 1024 px, quality 90. Only the
  downscaled copies are kept.
- `.venv/bin/python -I build_catalog.py`
  Looks up each target NDC on RxNav (`ndcstatus.json`), parses strength and form
  from `conceptName`, and writes `pill_catalog.json` (one row per imprint side).
  NDCs with no conceptName / no parseable strength / drug mismatch are skipped
  and listed. Copy the result to `backend/src/data/pillCatalog.json`.

`data/manifest.csv` columns: `ndc11,class,layout,local_path,imprint,color,shape,name`;
`local_path` is relative to `data/`.

`data/`, `.venv/` and `out/` are git-ignored.

## Data source and license

Images and metadata come from the NLM C3PI / Pill Image Recognition Pilot
(https://data.lhncbc.nlm.nih.gov/public/Pills/). They are NLM public data
provided for research and development; do not redistribute the images from this
repo. Strength data comes from the NLM RxNav API.
