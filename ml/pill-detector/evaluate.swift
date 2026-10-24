// Usage (from repo root): swift ml/pill-detector/evaluate.swift [model.mlmodel] [EVAL.md out path]
// Evaluates the pill detector with Vision, sweeps the confidence threshold, writes EVAL.md.
import CoreML
import Foundation
import ImageIO
import Vision

let args = CommandLine.arguments
let modelPath = args.count > 1 ? args[1] : "ml/pill-detector/out/PillDetector.mlmodel"
let evalPath = args.count > 2 ? args[2] : "ml/pill-detector/EVAL.md"
let dataDir = URL(fileURLWithPath: "ml/pill-detector/data")
let targets = ["benzonatate", "phenazopyridine", "atorvastatin", "lisinopril"]
let allClasses = targets + ["other"]
let thresholds: [Double] = stride(from: 0.30, through: 0.90001, by: 0.05).map { ($0 * 100).rounded() / 100 }

// MARK: model

let compiled = try MLModel.compileModel(at: URL(fileURLWithPath: modelPath))
let mlModel = try MLModel(contentsOf: compiled)
let vnModel = try VNCoreMLModel(for: mlModel)

struct Det { let label: String; let conf: Double }

var inferTimes: [Double] = []

func detect(_ url: URL, timed: Bool) -> [Det] {
    let req = VNCoreMLRequest(model: vnModel)
    req.imageCropAndScaleOption = .scaleFill
    let handler = VNImageRequestHandler(url: url, options: [:])
    let t0 = Date()
    try? handler.perform([req])
    if timed { inferTimes.append(Date().timeIntervalSince(t0)) }
    let obs = (req.results as? [VNRecognizedObjectObservation]) ?? []
    return obs.compactMap { o in
        guard let l = o.labels.first else { return nil }
        return Det(label: l.identifier, conf: Double(l.confidence))
    }.sorted { $0.conf > $1.conf }
}

func pct(_ n: Int, _ d: Int) -> String {
    d == 0 ? "n/a (n=0)" : String(format: "%.1f%% (%d/%d)", 100 * Double(n) / Double(d), n, d)
}
func frac(_ n: Int, _ d: Int) -> Double { d == 0 ? 0 : Double(n) / Double(d) }

// MARK: metric (a) data: holdout-NDC val composites

struct ValImage { let name: String; let counts: [String: Int]; let dets: [Det] }
let valDir = dataDir.appendingPathComponent("composites/val/images")
let valAnn = try JSONSerialization.jsonObject(with: Data(contentsOf: valDir.appendingPathComponent("annotations.json"))) as! [[String: Any]]
var valImages: [ValImage] = []
for entry in valAnn {
    let name = entry["image"] as! String
    var counts: [String: Int] = [:]
    for a in entry["annotations"] as! [[String: Any]] { counts[a["label"] as! String, default: 0] += 1 }
    valImages.append(ValImage(name: name, counts: counts, dets: detect(valDir.appendingPathComponent(name), timed: false)))
}
print("val composites evaluated: \(valImages.count)")

// MARK: real photos

struct Photo { let ndc: String; let cls: String; let holdout: Bool; let dets: [Det] }
let split = try JSONSerialization.jsonObject(with: Data(contentsOf: dataDir.appendingPathComponent("split.json"))) as! [String: [String]]
let holdoutNDCs = Set(split["holdout_ndcs"]!)
var photos: [Photo] = []
let manifest = try String(contentsOf: dataDir.appendingPathComponent("manifest.csv"), encoding: .utf8)
    .components(separatedBy: .newlines).filter { !$0.isEmpty }.dropFirst()
var photoRows: [(String, String, String)] = []  // ndc, class, path
for line in manifest {
    // name column may contain commas, but the first four columns never do
    let f = line.split(separator: ",", maxSplits: 4, omittingEmptySubsequences: false).map(String.init)
    if f.count >= 4, f[2] == "C3PI_Test" { photoRows.append((f[0], f[1], f[3])) }
}
// warm-up so the timing excludes model load / first-run compilation
if let first = photoRows.first { _ = detect(dataDir.appendingPathComponent(first.2), timed: false) }
for (ndc, cls, path) in photoRows {
    photos.append(Photo(ndc: ndc, cls: cls, holdout: holdoutNDCs.contains(ndc),
                        dets: detect(dataDir.appendingPathComponent(path), timed: true)))
}
let meanMs = 1000 * inferTimes.reduce(0, +) / Double(max(1, inferTimes.count))
let maxMs = 1000 * (inferTimes.max() ?? 0)
print("real photos evaluated: \(photos.count), mean inference \(String(format: "%.1f", meanMs)) ms")

// MARK: metrics

/// (a) per-image exact per-class count, detections only count at conf >= t.
func metricA(_ t: Double) -> (all: Int, perClass: [String: Int], presentCorrect: [String: Int], presentN: [String: Int]) {
    var all = 0
    var per: [String: Int] = [:], pc: [String: Int] = [:], pn: [String: Int] = [:]
    for img in valImages {
        var pred: [String: Int] = [:]
        for d in img.dets where d.conf >= t { pred[d.label, default: 0] += 1 }
        var ok = true
        for c in allClasses {
            let g = img.counts[c] ?? 0, p = pred[c] ?? 0
            if g == p { per[c, default: 0] += 1 } else { ok = false }
            if g > 0 { pn[c, default: 0] += 1; if g == p { pc[c, default: 0] += 1 } }
        }
        if ok { all += 1 }
    }
    return (all, per, pc, pn)
}

/// (b) top-1: highest-confidence box has the right class AND conf >= t.
/// Returns correct / belowThreshold (no box or top conf < t) / wrong (confident wrong class).
struct B { var correct = 0, below = 0, wrong = 0, n = 0 }
func metricB(_ t: Double, holdoutOnly: Bool) -> (total: B, perClass: [String: B]) {
    var total = B(); var per: [String: B] = [:]
    for p in photos where targets.contains(p.cls) && (!holdoutOnly || p.holdout) {
        var b = per[p.cls] ?? B()
        b.n += 1; total.n += 1
        if let top = p.dets.first, top.conf >= t {
            if top.label == p.cls { b.correct += 1; total.correct += 1 } else { b.wrong += 1; total.wrong += 1 }
        } else { b.below += 1; total.below += 1 }
        per[p.cls] = b
    }
    return (total, per)
}

/// (c) distractor photo rejected: no box, top box is `other`, or top conf < t.
func metricC(_ t: Double, holdoutOnly: Bool) -> (rejected: Int, n: Int) {
    var r = 0, n = 0
    for p in photos where p.cls == "other" && (!holdoutOnly || p.holdout) {
        n += 1
        if let top = p.dets.first, top.conf >= t, top.label != "other" { continue }
        r += 1
    }
    return (r, n)
}

// MARK: threshold choice: (c holdout) >= 90%, maximize (b holdout), ties -> higher threshold (fail closed)

var best: Double? = nil
var bestB = -1.0
for t in thresholds {
    let c = metricC(t, holdoutOnly: true)
    guard frac(c.rejected, c.n) >= 0.9 else { continue }
    let b = metricB(t, holdoutOnly: true).total
    let v = frac(b.correct, b.n)
    if v >= bestB { bestB = v; best = t }  // >= keeps the later (higher) threshold on ties
}
let chosen = best ?? thresholds.last!
let constraintMet = best != nil

// MARK: report

var md = ""
func line(_ s: String = "") { md += s + "\n"; print(s) }

let a = metricA(chosen)
let bH = metricB(chosen, holdoutOnly: true)
let bA = metricB(chosen, holdoutOnly: false)
let cH = metricC(chosen, holdoutOnly: true)
let cA = metricC(chosen, holdoutOnly: false)

line("# PillDetector evaluation")
line()
if let notes = try? String(contentsOfFile: "ml/pill-detector/out/train_notes.md", encoding: .utf8) {
    line(notes)
}
line("Model: `\(modelPath)`. Evaluated with Vision (`VNCoreMLRequest`, `scaleFill`), model default NMS/IoU settings.")
line()
line("## Chosen threshold: \(String(format: "%.2f", chosen))")
line()
line("Rule: pick from 0.30-0.90 (step 0.05): distractor rejection (holdout) >= 90%, maximize holdout top-1 (b); ties go to the higher threshold (fail closed). Constraint satisfiable: \(constraintMet ? "yes" : "NO (fell back to 0.90)").")
line()
line("## Acceptance metrics at threshold \(String(format: "%.2f", chosen))")
line()
line("| Metric | Result | Bar |")
line("|---|---|---|")
line("| (a) val composites (holdout NDCs only), all 5 class counts exact per image | \(pct(a.all, valImages.count)) | per-class >= 95% |")
for c in allClasses {
    line("| (a) per-class exact count, \(c) (all \(valImages.count) images) | \(pct(a.perClass[c] ?? 0, valImages.count)) | >= 95% |")
}
for c in allClasses {
    line("| (a) per-class exact count, \(c) (only images containing it) | \(pct(a.presentCorrect[c] ?? 0, a.presentN[c] ?? 0)) | informational |")
}
line("| (b) PRIMARY real photos, holdout target NDCs, top-1 correct at >= threshold | \(pct(bH.total.correct, bH.total.n)) | >= 90% |")
line("| (b) PRIMARY breakdown | correct \(bH.total.correct), below-threshold/no-box \(bH.total.below), confidently wrong \(bH.total.wrong) | below >= wrong |")
for c in targets {
    let b = bH.perClass[c] ?? B()
    line("| (b) PRIMARY \(c) | \(pct(b.correct, b.n)); below \(b.below), wrong \(b.wrong) | |")
}
line("| (b) SECONDARY (optimistic: all target NDCs, includes training NDCs) | \(pct(bA.total.correct, bA.total.n)); below \(bA.total.below), wrong \(bA.total.wrong) | informational |")
for c in targets {
    let b = bA.perClass[c] ?? B()
    line("| (b) SECONDARY \(c) | \(pct(b.correct, b.n)); below \(b.below), wrong \(b.wrong) | |")
}
line("| (c) PRIMARY distractor rejection, holdout `other` photos | \(pct(cH.rejected, cH.n)) | >= 90% |")
line("| (c) SECONDARY distractor rejection, all `other` photos (optimistic) | \(pct(cA.rejected, cA.n)) | informational |")
line("| (d) mean inference time per image (Vision, \(inferTimes.count) real photos, after warm-up) | \(String(format: "%.1f", meanMs)) ms (max \(String(format: "%.1f", maxMs)) ms) | < 1000 ms |")
line()
line("Photo sample sizes (C3PI_Test): " + allClasses.map { c in
    "\(c): \(photos.filter { $0.cls == c && $0.holdout }.count) holdout / \(photos.filter { $0.cls == c }.count) total"
}.joined(separator: "; "))
line()
line("Definitions: (b) counts a photo as correct only if the highest-confidence box is the right class with confidence >= threshold; no box or top confidence below threshold is \"below threshold\"; a confident wrong class is \"wrong\". (c) rejected = no box, top box is `other`, or top confidence < threshold. (a) counts only detections with confidence >= threshold, `other` is its own class; per-class accuracy over all val images counts an image correct for a class when the predicted count equals the true count (including 0 = 0).")
line()
line("## Holdout photo confusion at threshold (rows = true class, cols = top box label or `none/below`)")
line()
line("| true | " + allClasses.joined(separator: " | ") + " | none/below |")
line("|---|" + String(repeating: "---|", count: allClasses.count + 1))
for tc in allClasses {
    var row: [String: Int] = [:]
    for p in photos where p.holdout && p.cls == tc {
        if let top = p.dets.first, top.conf >= chosen { row[top.label, default: 0] += 1 } else { row["none", default: 0] += 1 }
    }
    line("| \(tc) | " + allClasses.map { String(row[$0] ?? 0) }.joined(separator: " | ") + " | \(row["none"] ?? 0) |")
}
line()
line("## Threshold sweep")
line()
line("| t | (a) all-exact | (a) min per-class | (b) holdout top-1 | (b) holdout wrong | (b) all-NDC top-1 | (c) holdout reject | (c) all reject |")
line("|---|---|---|---|---|---|---|---|")
for t in thresholds {
    let a = metricA(t), b = metricB(t, holdoutOnly: true), b2 = metricB(t, holdoutOnly: false)
    let c = metricC(t, holdoutOnly: true), c2 = metricC(t, holdoutOnly: false)
    let minPer = allClasses.map { frac(a.perClass[$0] ?? 0, valImages.count) }.min() ?? 0
    line(String(format: "| %.2f | %.1f%% | %.1f%% | %.1f%% | %d | %.1f%% | %.1f%% | %.1f%% |", t,
                100 * frac(a.all, valImages.count), 100 * minPer,
                100 * frac(b.total.correct, b.total.n), b.total.wrong,
                100 * frac(b2.total.correct, b2.total.n),
                100 * frac(c.rejected, c.n), 100 * frac(c2.rejected, c2.n)))
}
try md.write(toFile: evalPath, atomically: true, encoding: .utf8)
print("wrote \(evalPath)")
