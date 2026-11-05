import Foundation
import Vision

let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.recognitionLanguages = ["en-US"]
request.minimumTextHeight = 0.004
try VNImageRequestHandler(url: URL(fileURLWithPath: CommandLine.arguments[1])).perform([request])
let rows: [[String: Any]] = (request.results ?? []).compactMap { result in
    guard let text = result.topCandidates(1).first?.string else { return nil }
    let b = result.boundingBox
    return ["text": text, "box": [b.minX, 1 - b.maxY, b.width, b.height]]
}
let data = try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
print(String(decoding: data, as: UTF8.self))
