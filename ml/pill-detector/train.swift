// Usage (from repo root): swift ml/pill-detector/train.swift [maxIterations] [batchSize] [trainDir] [valDir]
// Trains the four-drug pill detector (Create ML object detector, transfer learning).
import CreateML
import Foundation

let args = CommandLine.arguments
let iterations = args.count > 1 ? Int(args[1])! : 8000
let batch = args.count > 2 ? Int(args[2])! : 32
let base = URL(fileURLWithPath: "ml/pill-detector/data/composites")
let trainURL = args.count > 3 ? URL(fileURLWithPath: args[3]) : base.appendingPathComponent("train/images")
let valURL = args.count > 4 ? URL(fileURLWithPath: args[4]) : base.appendingPathComponent("val/images")
let outDir = URL(fileURLWithPath: "ml/pill-detector/out")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let start = Date()
let params = MLObjectDetector.ModelParameters(
    validation: .dataSource(.directoryWithImagesAndJsonAnnotation(at: valURL)),
    batchSize: batch,
    maxIterations: iterations,
    algorithm: .transferLearning(.objectPrint(revision: 1))
)
print("iterations=\(iterations) batch=\(batch)")
let detector = try MLObjectDetector(
    trainingData: .directoryWithImagesAndJsonAnnotation(at: trainURL),
    parameters: params,
    annotationType: .boundingBox(units: .pixel, origin: .topLeft))
print("Validation metrics: \(detector.validationMetrics)")
print("Training metrics: \(detector.trainingMetrics)")
let meta = MLModelMetadata(
    author: "CareBridge",
    shortDescription: "Pill detector: benzonatate, phenazopyridine, atorvastatin, lisinopril, other",
    version: "1.0")
try detector.write(to: outDir.appendingPathComponent("PillDetector.mlmodel"), metadata: meta)
print("Done in \(Int(Date().timeIntervalSince(start)))s")
