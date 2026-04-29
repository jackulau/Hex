/// Pure logic for computing incremental text deltas during live transcription.
///
/// Tracks how many words have been pasted so far and determines which new words
/// should be pasted on each transcription tick. The last word is held back for
/// one tick to confirm stability — this prevents pasting partial words (e.g.,
/// "ham" that later becomes "hamburgers").
///
/// Handles sliding audio windows: when the capture buffer drops old samples from
/// the front, the transcription loses leading words. The delta detects this via
/// suffix-prefix overlap between consecutive transcriptions and adjusts the
/// pasted word cursor so pasting continues uninterrupted.
public struct LiveTranscriptionDelta {
	public var pastedWordCount: Int = 0
	public var heldBackWord: String?
	private var previousWords: [String] = []

	public init() {}

	/// Result of computing a delta against new transcription text.
	public struct Result {
		/// Text to paste into the active app. Empty means nothing to paste.
		public let textToPaste: String
		/// Whether any new words were found (even if held back).
		public let hasNewContent: Bool
		/// Whether a space separator should be typed before pasting this delta.
		/// The space must be typed as a keystroke, not included in the paste text,
		/// because clipboard paste strips leading/trailing whitespace.
		public let needsLeadingSpace: Bool
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

		// Detect sliding window: if the first word changed, old audio dropped off
		// the front of the buffer. Find how many words shifted out and adjust.
		if !previousWords.isEmpty, !words.isEmpty,
		   previousWords.first != words.first
		{
			let shifted = detectWordShift(from: previousWords, to: words)
			if shifted > 0 {
				pastedWordCount = max(0, pastedWordCount - shifted)
			}
		}
		previousWords = words

		guard words.count > pastedWordCount else {
			return Result(textToPaste: "", hasNewContent: false, needsLeadingSpace: false)
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
			return Result(textToPaste: "", hasNewContent: true, needsLeadingSpace: false)
		}

		let newWords = words[pastedWordCount..<safeWordCount]
		let needsLeadingSpace = pastedWordCount > 0
		let delta = newWords.joined(separator: " ")
		pastedWordCount = safeWordCount

		return Result(textToPaste: delta, hasNewContent: true, needsLeadingSpace: needsLeadingSpace)
	}

	/// Find how many words shifted out from the front by finding the longest
	/// suffix of `previous` that matches a prefix of `current`.
	/// Requires at least half the words to overlap to prevent false matches
	/// from common short phrases. Returns 0 if no reliable overlap found —
	/// the delta may get stuck for a tick but won't re-paste.
	private func detectWordShift(from previous: [String], to current: [String]) -> Int {
		let maxOverlap = min(previous.count, current.count)
		let minOverlap = max(3, maxOverlap / 2)
		for len in stride(from: maxOverlap, through: minOverlap, by: -1) {
			if previous.suffix(len).elementsEqual(current.prefix(len)) {
				return previous.count - len
			}
		}
		return 0
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
		// No trailing space on final paste
		return remaining.joined(separator: " ")
	}

	/// Flush the held-back word immediately (e.g., on key release).
	/// Returns the word with a leading space if there's prior pasted content.
	public mutating func flushHeldBackWord() -> String {
		guard let word = heldBackWord else { return "" }
		heldBackWord = nil
		pastedWordCount += 1
		// No trailing space on flush (final word)
		return word
	}

	/// Reset state for a new recording session.
	public mutating func reset() {
		pastedWordCount = 0
		heldBackWord = nil
		previousWords = []
	}
}
