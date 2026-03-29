/// Pure logic for computing incremental text deltas during live transcription.
///
/// Tracks how many words have been pasted so far and determines which new words
/// should be pasted on each transcription tick. The last word is held back for
/// one tick to confirm stability — this prevents pasting partial words (e.g.,
/// "ham" that later becomes "hamburgers").
public struct LiveTranscriptionDelta {
	public var pastedWordCount: Int = 0
	public var heldBackWord: String?

	public init() {}

	/// Result of computing a delta against new transcription text.
	public struct Result {
		/// Text to paste into the active app. Empty means nothing to paste.
		public let textToPaste: String
		/// Whether any new words were found (even if held back).
		public let hasNewContent: Bool
	}

	/// Compute the delta between previously pasted words and new transcription text.
	///
	/// Words beyond `pastedWordCount` are candidates for pasting. The very last word
	/// is held back until it appears unchanged on a subsequent tick, preventing partial
	/// words from being pasted.
	///
	/// - Parameter text: The full transcription result for the current tick.
	/// - Returns: The text to paste (may be empty if all new words are held back).
	public mutating func computeDelta(from text: String) -> Result {
		let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

		guard words.count > pastedWordCount else {
			return Result(textToPaste: "", hasNewContent: false)
		}

		let lastWord = words.last ?? ""
		let previousHeldBack = heldBackWord

		// If the last word matches what we held back last tick, it's stable — include it
		let safeWordCount: Int
		if lastWord == previousHeldBack {
			safeWordCount = words.count
			heldBackWord = nil
		} else {
			safeWordCount = max(0, words.count - 1)
			heldBackWord = lastWord
		}

		guard safeWordCount > pastedWordCount else {
			return Result(textToPaste: "", hasNewContent: true)
		}

		let newWords = words[pastedWordCount..<safeWordCount]
		let prefix = pastedWordCount > 0 ? " " : ""
		let delta = prefix + newWords.joined(separator: " ")
		pastedWordCount = safeWordCount

		return Result(textToPaste: delta, hasNewContent: true)
	}

	/// Compute the final delta for the complete transcription after recording stops.
	/// Pastes all remaining words beyond what was already pasted live.
	///
	/// - Parameter text: The final full transcription result.
	/// - Returns: Text to paste (only the portion not already pasted).
	public func computeFinalDelta(from text: String) -> String {
		let words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
		guard words.count > pastedWordCount else { return "" }
		let remaining = words[pastedWordCount...]
		let prefix = pastedWordCount > 0 ? " " : ""
		return prefix + remaining.joined(separator: " ")
	}

	/// Reset state for a new recording session.
	public mutating func reset() {
		pastedWordCount = 0
		heldBackWord = nil
	}
}
