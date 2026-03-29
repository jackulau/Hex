import Foundation

public enum RecordingAudioBehavior: String, Codable, CaseIterable, Equatable, Sendable {
	case pauseMedia
	case mute
	case doNothing
}

public enum RecordingMode: String, Codable, CaseIterable, Equatable, Sendable {
	case singleTap    // Toggle: tap to start, tap to stop
	case doubleTap    // Hold-to-record + double-tap lock
}

/// User-configurable settings saved to disk.
public struct PrismaVoiceSettings: Codable, Equatable, Sendable {
	public static let defaultPasteLastTranscriptHotkey = HotKey(key: .v, modifiers: [.option, .shift])
	public static let baseSoundEffectsVolume: Double = PrismaVoiceCoreConstants.baseSoundEffectsVolume
	public static let defaultWordRemovals: [WordRemoval] = [
		.init(pattern: "uh+"),
		.init(pattern: "um+"),
		.init(pattern: "er+"),
		.init(pattern: "hm+")
	]

	public static var defaultPasteLastTranscriptHotkeyDescription: String {
		let modifiers = defaultPasteLastTranscriptHotkey.modifiers.sorted.map { $0.stringValue }.joined()
		let key = defaultPasteLastTranscriptHotkey.key?.toString ?? ""
		return modifiers + key
	}

	public var soundEffectsEnabled: Bool
	public var soundEffectsVolume: Double
	public var hotkey: HotKey
	public var openOnLogin: Bool
	public var showDockIcon: Bool
	public var selectedModel: String
	public var useClipboardPaste: Bool
	public var preventSystemSleep: Bool
	public var recordingAudioBehavior: RecordingAudioBehavior
	public var minimumKeyTime: Double
	public var copyToClipboard: Bool
	public var superFastModeEnabled: Bool
	public var recordingMode: RecordingMode
	public var doubleTapLockEnabled: Bool
	public var outputLanguage: String?
	public var selectedMicrophoneID: String?
	public var saveTranscriptionHistory: Bool
	public var maxHistoryEntries: Int?
	public var pasteLastTranscriptHotkey: HotKey?
	public var hasCompletedModelBootstrap: Bool
	public var hasCompletedStorageMigration: Bool
	public var wordRemovalsEnabled: Bool
	public var wordRemovals: [WordRemoval]
	public var wordRemappings: [WordRemapping]
	public var liveTranscriptionEnabled: Bool

	private mutating func normalizeDoubleTapSettings() {
		// No normalization needed with recordingMode enum
	}

	public init(
		soundEffectsEnabled: Bool = true,
		soundEffectsVolume: Double = PrismaVoiceSettings.baseSoundEffectsVolume,
		hotkey: HotKey = .init(key: nil, modifiers: [.option]),
		openOnLogin: Bool = false,
		showDockIcon: Bool = true,
		selectedModel: String = ParakeetModel.multilingualV3.identifier,
		useClipboardPaste: Bool = true,
		preventSystemSleep: Bool = true,
		recordingAudioBehavior: RecordingAudioBehavior = .doNothing,
		minimumKeyTime: Double = PrismaVoiceCoreConstants.defaultMinimumKeyTime,
		copyToClipboard: Bool = false,
		superFastModeEnabled: Bool = false,
		recordingMode: RecordingMode = .singleTap,
		doubleTapLockEnabled: Bool = true,
		outputLanguage: String? = nil,
		selectedMicrophoneID: String? = nil,
		saveTranscriptionHistory: Bool = true,
		maxHistoryEntries: Int? = nil,
		pasteLastTranscriptHotkey: HotKey? = PrismaVoiceSettings.defaultPasteLastTranscriptHotkey,
		hasCompletedModelBootstrap: Bool = false,
		hasCompletedStorageMigration: Bool = false,
		wordRemovalsEnabled: Bool = false,
		wordRemovals: [WordRemoval] = PrismaVoiceSettings.defaultWordRemovals,
		wordRemappings: [WordRemapping] = [],
		liveTranscriptionEnabled: Bool = false
	) {
		self.soundEffectsEnabled = soundEffectsEnabled
		self.soundEffectsVolume = soundEffectsVolume
		self.hotkey = hotkey
		self.openOnLogin = openOnLogin
		self.showDockIcon = showDockIcon
		self.selectedModel = selectedModel
		self.useClipboardPaste = useClipboardPaste
		self.preventSystemSleep = preventSystemSleep
		self.recordingAudioBehavior = recordingAudioBehavior
		self.minimumKeyTime = minimumKeyTime
		self.copyToClipboard = copyToClipboard
		self.superFastModeEnabled = superFastModeEnabled
		self.recordingMode = recordingMode
		self.doubleTapLockEnabled = doubleTapLockEnabled
		self.outputLanguage = outputLanguage
		self.selectedMicrophoneID = selectedMicrophoneID
		self.saveTranscriptionHistory = saveTranscriptionHistory
		self.maxHistoryEntries = maxHistoryEntries
		self.pasteLastTranscriptHotkey = pasteLastTranscriptHotkey
		self.hasCompletedModelBootstrap = hasCompletedModelBootstrap
		self.hasCompletedStorageMigration = hasCompletedStorageMigration
		self.wordRemovalsEnabled = wordRemovalsEnabled
		self.wordRemovals = wordRemovals
		self.wordRemappings = wordRemappings
		self.liveTranscriptionEnabled = liveTranscriptionEnabled
		normalizeDoubleTapSettings()
	}

	public init(from decoder: Decoder) throws {
		self.init()
		let container = try decoder.container(keyedBy: PrismaVoiceSettingKey.self)
		for field in PrismaVoiceSettingsSchema.fields {
			try field.decode(into: &self, from: container)
		}
		normalizeDoubleTapSettings()
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: PrismaVoiceSettingKey.self)
		for field in PrismaVoiceSettingsSchema.fields {
			try field.encode(self, into: &container)
		}
	}
}

// MARK: - Schema

private enum PrismaVoiceSettingKey: String, CodingKey, CaseIterable {
	case soundEffectsEnabled
	case soundEffectsVolume
	case hotkey
	case openOnLogin
	case showDockIcon
	case selectedModel
	case useClipboardPaste
	case preventSystemSleep
	case recordingAudioBehavior
	case pauseMediaOnRecord // Legacy
	case minimumKeyTime
	case copyToClipboard
	case superFastModeEnabled
	case recordingMode
	case useDoubleTapOnly // Legacy
	case doubleTapLockEnabled
	case outputLanguage
	case selectedMicrophoneID
	case saveTranscriptionHistory
	case maxHistoryEntries
	case pasteLastTranscriptHotkey
	case hasCompletedModelBootstrap
	case hasCompletedStorageMigration
	case wordRemovalsEnabled
	case wordRemovals
	case wordRemappings
	case liveTranscriptionEnabled
}

private struct SettingsField<Value: Codable & Sendable> {
	let key: PrismaVoiceSettingKey
	let keyPath: WritableKeyPath<PrismaVoiceSettings, Value>
	let defaultValue: Value
	let decodeStrategy: (KeyedDecodingContainer<PrismaVoiceSettingKey>, PrismaVoiceSettingKey, Value) throws -> Value
	let encodeStrategy: (inout KeyedEncodingContainer<PrismaVoiceSettingKey>, PrismaVoiceSettingKey, Value) throws -> Void

	init(
		_ key: PrismaVoiceSettingKey,
		keyPath: WritableKeyPath<PrismaVoiceSettings, Value>,
		default defaultValue: Value,
		decode: ((KeyedDecodingContainer<PrismaVoiceSettingKey>, PrismaVoiceSettingKey, Value) throws -> Value)? = nil,
		encode: ((inout KeyedEncodingContainer<PrismaVoiceSettingKey>, PrismaVoiceSettingKey, Value) throws -> Void)? = nil
	) {
		self.key = key
		self.keyPath = keyPath
		self.defaultValue = defaultValue
		self.decodeStrategy = decode ?? { container, key, defaultValue in
			try container.decodeIfPresent(Value.self, forKey: key) ?? defaultValue
		}
		self.encodeStrategy = encode ?? { container, key, value in
			try container.encode(value, forKey: key)
		}
	}

	func eraseToAny() -> AnySettingsField {
		AnySettingsField(
			key: key,
			decode: { container, settings in
				let value = try decodeStrategy(container, key, defaultValue)
				settings[keyPath: keyPath] = value
			},
			encode: { settings, container in
				let value = settings[keyPath: keyPath]
				try encodeStrategy(&container, key, value)
			}
		)
	}
}

private struct AnySettingsField {
	let key: PrismaVoiceSettingKey
	let decode: (KeyedDecodingContainer<PrismaVoiceSettingKey>, inout PrismaVoiceSettings) throws -> Void
	let encode: (PrismaVoiceSettings, inout KeyedEncodingContainer<PrismaVoiceSettingKey>) throws -> Void

	func decode(into settings: inout PrismaVoiceSettings, from container: KeyedDecodingContainer<PrismaVoiceSettingKey>) throws {
		try decode(container, &settings)
	}

	func encode(_ settings: PrismaVoiceSettings, into container: inout KeyedEncodingContainer<PrismaVoiceSettingKey>) throws {
		try encode(settings, &container)
	}
}

private enum PrismaVoiceSettingsSchema {
	static let defaults = PrismaVoiceSettings()

	nonisolated(unsafe) static let fields: [AnySettingsField] = [
		SettingsField(.soundEffectsEnabled, keyPath: \.soundEffectsEnabled, default: defaults.soundEffectsEnabled).eraseToAny(),
		SettingsField(.soundEffectsVolume, keyPath: \.soundEffectsVolume, default: defaults.soundEffectsVolume).eraseToAny(),
		SettingsField(.hotkey, keyPath: \.hotkey, default: defaults.hotkey).eraseToAny(),
		SettingsField(.openOnLogin, keyPath: \.openOnLogin, default: defaults.openOnLogin).eraseToAny(),
		SettingsField(.showDockIcon, keyPath: \.showDockIcon, default: defaults.showDockIcon).eraseToAny(),
		SettingsField(.selectedModel, keyPath: \.selectedModel, default: defaults.selectedModel).eraseToAny(),
		SettingsField(.useClipboardPaste, keyPath: \.useClipboardPaste, default: defaults.useClipboardPaste).eraseToAny(),
		SettingsField(.preventSystemSleep, keyPath: \.preventSystemSleep, default: defaults.preventSystemSleep).eraseToAny(),
		SettingsField(
			.recordingAudioBehavior,
			keyPath: \.recordingAudioBehavior,
			default: defaults.recordingAudioBehavior,
			decode: { container, key, defaultValue in
				if let value = try container.decodeIfPresent(RecordingAudioBehavior.self, forKey: key) {
					return value
				}
				if let legacyPause = try container.decodeIfPresent(Bool.self, forKey: .pauseMediaOnRecord) {
					return legacyPause ? .pauseMedia : .doNothing
				}
				return defaultValue
			}
		).eraseToAny(),
		SettingsField(.minimumKeyTime, keyPath: \.minimumKeyTime, default: defaults.minimumKeyTime).eraseToAny(),
		SettingsField(.copyToClipboard, keyPath: \.copyToClipboard, default: defaults.copyToClipboard).eraseToAny(),
		SettingsField(.superFastModeEnabled, keyPath: \.superFastModeEnabled, default: defaults.superFastModeEnabled).eraseToAny(),
		SettingsField(
			.recordingMode,
			keyPath: \.recordingMode,
			default: defaults.recordingMode,
			decode: { container, key, defaultValue in
				if let value = try container.decodeIfPresent(RecordingMode.self, forKey: key) {
					return value
				}
				if let legacy = try container.decodeIfPresent(Bool.self, forKey: .useDoubleTapOnly) {
					return legacy ? .doubleTap : .singleTap
				}
				return defaultValue
			}
		).eraseToAny(),
		SettingsField(.doubleTapLockEnabled, keyPath: \.doubleTapLockEnabled, default: defaults.doubleTapLockEnabled).eraseToAny(),
		SettingsField(
			.outputLanguage,
			keyPath: \.outputLanguage,
			default: defaults.outputLanguage,
			encode: { container, key, value in
				try container.encodeIfPresent(value, forKey: key)
			}
		).eraseToAny(),
		SettingsField(
			.selectedMicrophoneID,
			keyPath: \.selectedMicrophoneID,
			default: defaults.selectedMicrophoneID,
			encode: { container, key, value in
				try container.encodeIfPresent(value, forKey: key)
			}
		).eraseToAny(),
		SettingsField(.saveTranscriptionHistory, keyPath: \.saveTranscriptionHistory, default: defaults.saveTranscriptionHistory).eraseToAny(),
		SettingsField(
			.maxHistoryEntries,
			keyPath: \.maxHistoryEntries,
			default: defaults.maxHistoryEntries,
			encode: { container, key, value in
				try container.encodeIfPresent(value, forKey: key)
			}
		).eraseToAny(),
		SettingsField(
			.pasteLastTranscriptHotkey,
			keyPath: \.pasteLastTranscriptHotkey,
			default: defaults.pasteLastTranscriptHotkey,
			encode: { container, key, value in
				try container.encodeIfPresent(value, forKey: key)
			}
		).eraseToAny(),
		SettingsField(.hasCompletedModelBootstrap, keyPath: \.hasCompletedModelBootstrap, default: defaults.hasCompletedModelBootstrap).eraseToAny(),
		SettingsField(.hasCompletedStorageMigration, keyPath: \.hasCompletedStorageMigration, default: defaults.hasCompletedStorageMigration).eraseToAny(),
		SettingsField(.wordRemovalsEnabled, keyPath: \.wordRemovalsEnabled, default: defaults.wordRemovalsEnabled).eraseToAny(),
		SettingsField(
			.wordRemovals,
			keyPath: \.wordRemovals,
			default: defaults.wordRemovals
		).eraseToAny(),
		SettingsField(
			.wordRemappings,
			keyPath: \.wordRemappings,
			default: defaults.wordRemappings
		).eraseToAny(),
		SettingsField(.liveTranscriptionEnabled, keyPath: \.liveTranscriptionEnabled, default: defaults.liveTranscriptionEnabled).eraseToAny()
	]
}
