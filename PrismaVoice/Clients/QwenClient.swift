import AVFoundation
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

    // Read audio samples from file
    let audioFile = try AVAudioFile(forReading: url)
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    let converter = AVAudioConverter(from: audioFile.processingFormat, to: format)
    let frameCount = AVAudioFrameCount(audioFile.length * Int64(format.sampleRate) / Int64(audioFile.processingFormat.sampleRate))
    guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw NSError(domain: "Qwen", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio buffer"])
    }
    if let converter {
      var error: NSError?
      let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
        let readBuffer = AVAudioPCMBuffer(pcmFormat: audioFile.processingFormat, frameCapacity: 4096)!
        do { try audioFile.read(into: readBuffer) } catch { outStatus.pointee = .endOfStream; return nil }
        outStatus.pointee = .haveData
        return readBuffer
      }
      converter.convert(to: buffer, error: &error, withInputFrom: inputBlock)
    } else {
      try audioFile.read(into: buffer)
    }

    guard let samples = buffer.floatChannelData?[0] else {
      throw NSError(domain: "Qwen", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to read audio samples"])
    }
    let sampleArray = Array(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))

    let text = try await manager.transcribe(audioSamples: sampleArray, language: language)
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
    case .standard: return .f32
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
