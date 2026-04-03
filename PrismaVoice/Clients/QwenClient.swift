import Foundation
import PrismaVoiceCore

#if canImport(FluidAudio)
import FluidAudio

@available(macOS 15, *)
actor QwenClient {
  private var manager: Qwen3AsrManager?
  private var currentVariant: QwenModel?
  private let logger = PrismaVoiceLog.transcription

  func isModelAvailable(_ modelName: String) async -> Bool {
    guard let variant = QwenModel(rawValue: modelName) else { return false }
    if currentVariant == variant, manager != nil { return true }
    let fm = FileManager.default
    for dir in modelDirectories(variant) {
      if fm.fileExists(atPath: dir.path) { return true }
    }
    return false
  }

  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    guard let variant = QwenModel(rawValue: modelName) else {
      throw NSError(domain: "Qwen", code: -4, userInfo: [NSLocalizedDescriptionKey: "Unsupported Qwen variant: \(modelName)"])
    }
    if currentVariant == variant, manager != nil { return }
    if currentVariant != variant { manager = nil }

    let t0 = Date()
    logger.notice("Starting Qwen3-ASR load variant=\(variant.identifier)")
    let p = Progress(totalUnitCount: 100)
    p.completedUnitCount = 1
    progress(p)

    // Download via FluidAudio's HuggingFace integration
    let modelDir = try await Qwen3AsrModels.download(variant: variant.asrVariant)
    p.completedUnitCount = 60
    progress(p)

    // Load CoreML models from downloaded directory
    let mgr = Qwen3AsrManager()
    try await mgr.loadModels(from: modelDir)
    p.completedUnitCount = 100
    progress(p)

    self.manager = mgr
    self.currentVariant = variant
    logger.notice("Qwen3-ASR ensureLoaded completed in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
  }

  func transcribe(_ url: URL, language: String? = nil) async throws -> String {
    guard let manager else {
      throw NSError(domain: "Qwen", code: -1, userInfo: [NSLocalizedDescriptionKey: "Qwen3-ASR not initialized"])
    }
    let t0 = Date()
    logger.notice("Transcribing with Qwen3-ASR file=\(url.lastPathComponent)")

    // Read raw float32 samples from the WAV file
    // Our recordings are already 16kHz mono float32 from SuperFastCaptureController
    let data = try Data(contentsOf: url)
    guard data.count > 44 else {
      throw NSError(domain: "Qwen", code: -5, userInfo: [NSLocalizedDescriptionKey: "Audio file too small"])
    }
    // Find the data chunk in the WAV (skip header)
    var dataOffset = 12
    while dataOffset + 8 <= data.count {
      let chunkID = String(data: data[dataOffset..<dataOffset + 4], encoding: .ascii) ?? ""
      if chunkID == "data" {
        dataOffset += 8
        break
      }
      let chunkSize: UInt32 = data[dataOffset + 4..<dataOffset + 8].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
      dataOffset += 8 + Int(chunkSize)
      if chunkSize % 2 != 0 { dataOffset += 1 }
    }
    let pcmData = data[dataOffset...]
    let sampleCount = pcmData.count / MemoryLayout<Float>.size
    let samples: [Float] = pcmData.withUnsafeBytes { buffer in
      let floatBuffer = buffer.bindMemory(to: Float.self)
      return Array(floatBuffer.prefix(sampleCount))
    }
    logger.info("Qwen3-ASR audio: \(samples.count) samples (\(String(format: "%.2f", Double(samples.count) / 16000.0))s)")

    let text = try await manager.transcribe(audioSamples: samples, language: language)
    logger.info("Qwen3-ASR transcription finished in \(String(format: "%.2f", Date().timeIntervalSince(t0)))s")
    return text
  }

  func deleteModel(modelName: String) async throws {
    guard let variant = QwenModel(rawValue: modelName) else { return }
    let fm = FileManager.default
    for dir in modelDirectories(variant) {
      if fm.fileExists(atPath: dir.path) {
        try? fm.removeItem(at: dir)
      }
    }
    if currentVariant == variant { manager = nil; currentVariant = nil }
  }

}

extension QwenModel {
  var asrVariant: Qwen3AsrVariant {
    switch self {
    case .int8: return .int8
    }
  }
}

@available(macOS 15, *)
private extension QwenClient {
  func modelDirectories(_ variant: QwenModel) -> [URL] {
    let fm = FileManager.default
    let support = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    var dirs: [URL] = []
    if let support {
      dirs.append(support.appendingPathComponent("FluidAudio/Models/\(variant.identifier)"))
    }
    let userCache = fm.homeDirectoryForCurrentUser.appendingPathComponent(".cache/fluidaudio/Models/\(variant.identifier)")
    dirs.append(userCache)
    return dirs
  }
}

#else

actor QwenClient {
  func isModelAvailable(_ modelName: String) async -> Bool { false }
  func ensureLoaded(modelName: String, progress: @escaping (Progress) -> Void) async throws {
    throw NSError(domain: "Qwen", code: -2, userInfo: [NSLocalizedDescriptionKey: "Qwen3-ASR requires FluidAudio."])
  }
  func transcribe(_ url: URL, language: String? = nil) async throws -> String {
    throw NSError(domain: "Qwen", code: -3, userInfo: [NSLocalizedDescriptionKey: "Qwen3-ASR not available"])
  }
  func deleteModel(modelName: String) async throws {}
}

#endif
