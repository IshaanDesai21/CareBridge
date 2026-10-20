# PillDetector evaluation

## Training runs

Both runs: Create ML `MLObjectDetector`, `.transferLearning(.objectPrint(revision: 1))` (brief spelling compiled; this Xcode also requires `annotationType: .boundingBox(units: .pixel, origin: .topLeft)`, center anchor), maxIterations 8000, batchSize 32, 6000 train / 800 val composites (val = holdout NDCs only, identical split and val generation in both runs), Apple M3 / 8 GB, no reduction needed.

- Run 1 (defaults: distractor probability 0.35 per pill, pill long side 8-22% of image width): 5102 s. Validation mAP@IoU0.5 = 0.796 (mAP varied IoU 0.627); training mAP@0.5 = 0.994.
- Run 2 (the single permitted iteration, train set only: distractor probability 0.5, pill long side up to 45% of width for close-up shots; `composite.py --train-p-other 0.5 --train-scale-max 0.45`): 5741 s. Validation mAP numbers below.

This document is the evaluation of RUN 2 (the final model). Run 1 results are summarized at the end.

Model: `ml/pill-detector/out/PillDetector.mlmodel`. Evaluated with Vision (`VNCoreMLRequest`, `scaleFill`), model default NMS/IoU settings.

## Chosen threshold: 0.90

Rule: pick from 0.30-0.90 (step 0.05): distractor rejection (holdout) >= 90%, maximize holdout top-1 (b); ties go to the higher threshold (fail closed). Constraint satisfiable: NO (fell back to 0.90).

## Acceptance metrics at threshold 0.90

| Metric | Result | Bar |
|---|---|---|
| (a) val composites (holdout NDCs only), all 5 class counts exact per image | 25.9% (207/800) | per-class >= 95% |
| (a) per-class exact count, benzonatate (all 800 images) | 67.5% (540/800) | >= 95% |
| (a) per-class exact count, phenazopyridine (all 800 images) | 92.0% (736/800) | >= 95% |
| (a) per-class exact count, atorvastatin (all 800 images) | 72.5% (580/800) | >= 95% |
| (a) per-class exact count, lisinopril (all 800 images) | 61.2% (490/800) | >= 95% |
| (a) per-class exact count, other (all 800 images) | 33.8% (270/800) | >= 95% |
| (a) per-class exact count, benzonatate (only images containing it) | 43.1% (187/434) | informational |
| (a) per-class exact count, phenazopyridine (only images containing it) | 91.0% (402/442) | informational |
| (a) per-class exact count, atorvastatin (only images containing it) | 46.8% (185/395) | informational |
| (a) per-class exact count, lisinopril (only images containing it) | 35.9% (149/415) | informational |
| (a) per-class exact count, other (only images containing it) | 28.2% (160/567) | informational |
| (b) PRIMARY real photos, holdout target NDCs, top-1 correct at >= threshold | 31.7% (40/126) | >= 90% |
| (b) PRIMARY breakdown | correct 40, below-threshold/no-box 6, confidently wrong 80 | below >= wrong |
| (b) PRIMARY benzonatate | 100.0% (17/17); below 0, wrong 0 | |
| (b) PRIMARY phenazopyridine | 61.5% (8/13); below 0, wrong 5 | |
| (b) PRIMARY atorvastatin | 6.7% (1/15); below 0, wrong 14 | |
| (b) PRIMARY lisinopril | 17.3% (14/81); below 6, wrong 61 | |
| (b) SECONDARY (optimistic: all target NDCs, includes training NDCs) | 18.7% (154/822); below 38, wrong 630 | informational |
| (b) SECONDARY benzonatate | 100.0% (44/44); below 0, wrong 0 | |
| (b) SECONDARY phenazopyridine | 80.8% (21/26); below 0, wrong 5 | |
| (b) SECONDARY atorvastatin | 5.5% (12/219); below 6, wrong 201 | |
| (b) SECONDARY lisinopril | 14.4% (77/533); below 32, wrong 424 | |
| (c) PRIMARY distractor rejection, holdout `other` photos | 85.2% (23/27) | >= 90% |
| (c) SECONDARY distractor rejection, all `other` photos (optimistic) | 90.6% (106/117) | informational |
| (d) mean inference time per image (Vision, 939 real photos, after warm-up) | 4.5 ms (max 5.9 ms) | < 1000 ms |

Photo sample sizes (C3PI_Test): benzonatate: 17 holdout / 44 total; phenazopyridine: 13 holdout / 26 total; atorvastatin: 15 holdout / 219 total; lisinopril: 81 holdout / 533 total; other: 27 holdout / 117 total

Definitions: (b) counts a photo as correct only if the highest-confidence box is the right class with confidence >= threshold; no box or top confidence below threshold is "below threshold"; a confident wrong class is "wrong". (c) rejected = no box, top box is `other`, or top confidence < threshold. (a) counts only detections with confidence >= threshold, `other` is its own class; per-class accuracy over all val images counts an image correct for a class when the predicted count equals the true count (including 0 = 0).

## Holdout photo confusion at threshold (rows = true class, cols = top box label or `none/below`)

| true | benzonatate | phenazopyridine | atorvastatin | lisinopril | other | none/below |
|---|---|---|---|---|---|---|
| benzonatate | 17 | 0 | 0 | 0 | 0 | 0 |
| phenazopyridine | 5 | 8 | 0 | 0 | 0 | 0 |
| atorvastatin | 0 | 0 | 1 | 0 | 14 | 0 |
| lisinopril | 3 | 8 | 0 | 14 | 50 | 6 |
| other | 0 | 3 | 0 | 1 | 23 | 0 |

## Threshold sweep

| t | (a) all-exact | (a) min per-class | (b) holdout top-1 | (b) holdout wrong | (b) all-NDC top-1 | (c) holdout reject | (c) all reject |
|---|---|---|---|---|---|---|---|
| 0.30 | 18.4% | 25.0% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.35 | 18.4% | 25.0% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.40 | 18.4% | 25.0% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.45 | 18.4% | 25.0% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.50 | 18.4% | 25.1% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.55 | 18.9% | 26.0% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.60 | 19.9% | 26.5% | 33.3% | 83 | 20.0% | 85.2% | 89.7% |
| 0.65 | 20.9% | 27.4% | 33.3% | 83 | 19.8% | 85.2% | 89.7% |
| 0.70 | 21.2% | 28.0% | 33.3% | 83 | 19.8% | 85.2% | 89.7% |
| 0.75 | 22.1% | 29.1% | 33.3% | 81 | 19.7% | 85.2% | 89.7% |
| 0.80 | 23.2% | 30.2% | 33.3% | 81 | 19.7% | 85.2% | 89.7% |
| 0.85 | 24.5% | 31.8% | 33.3% | 81 | 19.3% | 85.2% | 89.7% |
| 0.90 | 25.9% | 33.8% | 31.7% | 80 | 18.7% | 85.2% | 90.6% |

## Run 1 summary (before the iteration)

Chosen threshold 0.90 (distractor constraint also unsatisfiable). (a) all-exact 28.1%, per-class 36.6-93.0% (lowest `other`, highest phenazopyridine). (b) holdout top-1 27.8% (35/126; benzonatate 17/17, phenazopyridine 10/13, atorvastatin 0/15, lisinopril 8/81), wrong 85; all-NDC 14.2%. (c) holdout 77.8% (21/27), all-NDC 90.6%. Inference 4.6 ms.

## Verdict

Acceptance bar NOT met (needs (a) per-class >= 95%, (b) >= 90%, (c) >= 90%, inference < 1 s; only inference met). Model NOT shipped into `ios/`, backend `CONFIDENCE_THRESHOLD` default (0.6) unchanged. Failure mode: confident misclassification of real phone photos (lisinopril and atorvastatin from held-out NDCs are mostly called `other` with confidence >= 0.9, so no threshold can separate them) - a synthetic-to-real / unseen-NDC generalization gap (training mAP@0.5 0.998 vs validation 0.804). Note the holdout photo sets are small (atorvastatin 15 photos, probably 1-2 NDCs; lisinopril 81 photos, 5 NDCs), so per-class numbers are noisy.
