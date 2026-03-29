import ComposableArchitecture
import Dependencies
import Foundation
import PrismaVoiceCore

// Re-export types so the app target can use them without PrismaVoiceCore prefixes.
typealias RecordingAudioBehavior = PrismaVoiceCore.RecordingAudioBehavior
typealias PrismaVoiceSettings = PrismaVoiceCore.PrismaVoiceSettings

extension SharedReaderKey
	where Self == FileStorageKey<PrismaVoiceSettings>.Default
{
	static var prismaVoiceSettings: Self {
		Self[
			.fileStorage(.prismaVoiceSettingsURL),
			default: .init()
		]
	}
}

// MARK: - Storage Migration

extension URL {
	static var prismaVoiceSettingsURL: URL {
		get {
			URL.hexMigratedFileURL(named: "hex_settings.json")
		}
	}
}
