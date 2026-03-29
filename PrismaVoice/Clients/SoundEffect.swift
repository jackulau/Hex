//
//  SoundEffect.swift
//  Hex
//
//  Created by Kit Langton on 1/26/25.
//

import AVFoundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation
import PrismaVoiceCore
import SwiftUI

// Thank you. Never mind then.What a beautiful idea.
public enum SoundEffect: String, CaseIterable {
  case pasteTranscript
  case startRecording
  case stopRecording
  case cancel

  public var fileName: String {
    self.rawValue
  }

  var fileExtension: String {
    "mp3"
  }
}

@DependencyClient
public struct SoundEffectsClient {
  public var play: @Sendable (SoundEffect) -> Void
  public var stop: @Sendable (SoundEffect) -> Void
  public var stopAll: @Sendable () -> Void
  public var preloadSounds: @Sendable () async -> Void
}

extension SoundEffectsClient: DependencyKey {
  public static var liveValue: SoundEffectsClient {
    let live = SoundEffectsClientLive()
    return SoundEffectsClient(
      play: { soundEffect in
        Task { await live.play(soundEffect) }
      },
      stop: { soundEffect in
        Task { await live.stop(soundEffect) }
      },
      stopAll: {
        Task { await live.stopAll() }
      },
      preloadSounds: {
        await live.preloadSounds()
      }
    )
  }
}

public extension DependencyValues {
  var soundEffects: SoundEffectsClient {
    get { self[SoundEffectsClient.self] }
    set { self[SoundEffectsClient.self] = newValue }
  }
}

actor SoundEffectsClientLive {
  private let logger = PrismaVoiceLog.sound
  private let baselineVolume = PrismaVoiceSettings.baseSoundEffectsVolume

  private let engine = AVAudioEngine()
  @Shared(.prismaVoiceSettings) var prismaVoiceSettings: PrismaVoiceSettings
  private var playerNodes: [SoundEffect: AVAudioPlayerNode] = [:]
  private var audioBuffers: [SoundEffect: AVAudioPCMBuffer] = [:]
  private var isEngineRunning = false
  private var activePlays = 0
  private var activePlayTokens = Set<UUID>()
  private var tokensByEffect: [SoundEffect: Set<UUID>] = [:]

  func play(_ soundEffect: SoundEffect) {
	guard prismaVoiceSettings.soundEffectsEnabled else { return }
	guard let player = playerNodes[soundEffect], let buffer = audioBuffers[soundEffect] else {
		logger.error("Requested sound \(soundEffect.rawValue) not preloaded")
		return
	}
	prepareEngineIfNeeded()
	let clampedVolume = min(max(prismaVoiceSettings.soundEffectsVolume, 0), baselineVolume)
	player.volume = Float(clampedVolume)
	player.stop()
    let token = UUID()
    activePlayTokens.insert(token)
    tokensByEffect[soundEffect, default: []].insert(token)
    activePlays += 1
	player.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
      Task { await self?.handlePlaybackEnded(token: token) }
    }
	player.play()
  }

  func stop(_ soundEffect: SoundEffect) {
    playerNodes[soundEffect]?.stop()
    if let tokens = tokensByEffect.removeValue(forKey: soundEffect) {
      for token in tokens {
        if activePlayTokens.remove(token) != nil {
          activePlays = max(activePlays - 1, 0)
        }
      }
    }
    stopEngineIfIdle()
  }

  func stopAll() {
    playerNodes.values.forEach { $0.stop() }
    activePlayTokens.removeAll()
    tokensByEffect.removeAll()
    activePlays = 0
    stopEngineIfIdle()
  }

  func preloadSounds() async {
    guard !isSetup else { return }

    for soundEffect in SoundEffect.allCases {
      loadSound(soundEffect)
    }

    isSetup = true
  }

  private var isSetup = false

  private func loadSound(_ soundEffect: SoundEffect) {
    guard let url = Bundle.main.url(
      forResource: soundEffect.fileName,
      withExtension: soundEffect.fileExtension
    ) else {
      logger.error("Missing sound resource \(soundEffect.fileName).\(soundEffect.fileExtension)")
      return
    }

    do {
      let file = try AVAudioFile(forReading: url)
      let frameCount = AVAudioFrameCount(file.length)
      guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
        logger.error("Failed to allocate buffer for \(soundEffect.rawValue)")
        return
      }
      try file.read(into: buffer)
      audioBuffers[soundEffect] = buffer

      let player = AVAudioPlayerNode()
      engine.attach(player)
      engine.connect(player, to: engine.mainMixerNode, format: buffer.format)
      playerNodes[soundEffect] = player
    } catch {
      logger.error("Failed to load sound \(soundEffect.rawValue): \(error.localizedDescription)")
    }
  }
  private func prepareEngineIfNeeded() {
    if !isEngineRunning || !engine.isRunning {
      engine.prepare()
      if #available(macOS 13.0, *) {
        engine.isAutoShutdownEnabled = true
      }
      do {
        try engine.start()
        isEngineRunning = true
      } catch {
        logger.error("Failed to start AVAudioEngine: \(error.localizedDescription)")
      }
    }
  }

  private func handlePlaybackEnded(token: UUID) {
    guard activePlayTokens.remove(token) != nil else { return }
    activePlays = max(activePlays - 1, 0)
    stopEngineIfIdle()
  }

  private func stopEngineIfIdle() {
    guard activePlays == 0 else { return }
    guard isEngineRunning || engine.isRunning else { return }
    engine.stop()
    isEngineRunning = false
  }
}
