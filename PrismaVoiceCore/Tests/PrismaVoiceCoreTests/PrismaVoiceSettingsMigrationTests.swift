import XCTest
@testable import PrismaVoiceCore

final class PrismaVoiceSettingsMigrationTests: XCTestCase {
	func testV1FixtureMigratesToCurrentDefaults() throws {
		let data = try loadFixture(named: "v1")
		let decoded = try JSONDecoder().decode(PrismaVoiceSettings.self, from: data)

		XCTAssertEqual(decoded.recordingAudioBehavior, .pauseMedia, "Legacy pauseMediaOnRecord bool should map to pauseMedia behavior")
		XCTAssertEqual(decoded.soundEffectsEnabled, false)
		XCTAssertEqual(decoded.soundEffectsVolume, PrismaVoiceSettings.baseSoundEffectsVolume)
		XCTAssertEqual(decoded.openOnLogin, true)
		XCTAssertEqual(decoded.showDockIcon, false)
		XCTAssertEqual(decoded.selectedModel, "whisper-large-v3")
		XCTAssertEqual(decoded.useClipboardPaste, false)
		XCTAssertEqual(decoded.preventSystemSleep, true)
		XCTAssertEqual(decoded.minimumKeyTime, 0.25)
		XCTAssertEqual(decoded.copyToClipboard, true)
		XCTAssertFalse(decoded.superFastModeEnabled)
		XCTAssertEqual(decoded.recordingMode, .doubleTap)
		XCTAssertEqual(decoded.doubleTapLockEnabled, true)
		XCTAssertEqual(decoded.outputLanguage, "en")
		XCTAssertEqual(decoded.selectedMicrophoneID, "builtin:mic")
		XCTAssertEqual(decoded.saveTranscriptionHistory, false)
		XCTAssertEqual(decoded.maxHistoryEntries, 10)
		XCTAssertEqual(decoded.hasCompletedModelBootstrap, true)
		XCTAssertEqual(decoded.hasCompletedStorageMigration, true)
	}

	func testEncodeDecodeRoundTripPreservesDefaults() throws {
		let settings = PrismaVoiceSettings()
		let data = try JSONEncoder().encode(settings)
		let decoded = try JSONDecoder().decode(PrismaVoiceSettings.self, from: data)
		XCTAssertEqual(decoded, settings)
	}

	func testLegacyUseDoubleTapOnlyDecodesAsRecordingMode() throws {
		let payload = "{\"useDoubleTapOnly\":true}"
		guard let data = payload.data(using: .utf8) else {
			XCTFail("Failed to encode JSON payload")
			return
		}
		let decoded = try JSONDecoder().decode(PrismaVoiceSettings.self, from: data)
		XCTAssertEqual(decoded.recordingMode, .doubleTap)
	}

	func testLegacyUseDoubleTapOnlyFalseDecodesAsSingleTap() throws {
		let payload = "{\"useDoubleTapOnly\":false}"
		guard let data = payload.data(using: .utf8) else {
			XCTFail("Failed to encode JSON payload")
			return
		}
		let decoded = try JSONDecoder().decode(PrismaVoiceSettings.self, from: data)
		XCTAssertEqual(decoded.recordingMode, .singleTap)
	}

	private func loadFixture(named name: String) throws -> Data {
		guard let url = Bundle.module.url(
			forResource: name,
			withExtension: "json",
			subdirectory: "Fixtures/PrismaVoiceSettings"
		) else {
			XCTFail("Missing fixture \(name).json")
			throw NSError(domain: "Fixture", code: 0)
		}
		return try Data(contentsOf: url)
	}
}
