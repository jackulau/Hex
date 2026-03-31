import Foundation

public enum QwenModel: String, CaseIterable, Sendable {
	case standard = "qwen3-asr-f32"
	case int8 = "qwen3-asr-int8"

	public var identifier: String { rawValue }
	public var capabilityLabel: String { "Multilingual (30 languages)" }
	public var isMultilingual: Bool { true }
}
