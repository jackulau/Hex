import Testing
@testable import PrismaVoiceCore

struct LiveTranscriptionDeltaTests {

	// MARK: - Basic Delta

	@Test
	func firstTickPastesAllButLastWord() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "Hello my name is Jack")
		#expect(result.textToPaste == "Hello my name is")
		#expect(result.needsLeadingSpace == false)
		#expect(result.hasNewContent == true)
		#expect(delta.pastedWordCount == 4)
		#expect(delta.heldBackWord == "Jack")
	}

	@Test
	func emptyTextReturnsNoDelta() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "")
		#expect(result.textToPaste == "")
		#expect(result.hasNewContent == false)
	}

	@Test
	func singleWordIsHeldBack() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "Hello")
		#expect(result.textToPaste == "")
		#expect(result.hasNewContent == true)
		#expect(delta.heldBackWord == "Hello")
	}

	@Test
	func singleWordConfirmedOnSecondTick() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello")
		let result = delta.computeDelta(from: "Hello")
		#expect(result.textToPaste == "Hello")
		#expect(result.needsLeadingSpace == false)
	}

	// MARK: - Progressive Pasting

	@Test
	func progressivePastingAcrossTicks() {
		var delta = LiveTranscriptionDelta()

		let r1 = delta.computeDelta(from: "Hello my")
		#expect(r1.textToPaste == "Hello")
		#expect(r1.needsLeadingSpace == false)

		let r2 = delta.computeDelta(from: "Hello my name is")
		#expect(r2.textToPaste == "my name")
		#expect(r2.needsLeadingSpace == true)

		let r3 = delta.computeDelta(from: "Hello my name is Jack")
		#expect(r3.textToPaste == "is")
		#expect(r3.needsLeadingSpace == true)
	}

	// MARK: - Hold-Back Stability

	@Test
	func heldBackWordReleasedWhenConfirmed() {
		var delta = LiveTranscriptionDelta()

		let r1 = delta.computeDelta(from: "I like ham")
		#expect(r1.textToPaste == "I like")
		#expect(r1.needsLeadingSpace == false)

		let r2 = delta.computeDelta(from: "I like hamburgers and")
		#expect(r2.textToPaste == "hamburgers")
		#expect(r2.needsLeadingSpace == true)
	}

	@Test
	func heldBackWordPreventsBadPaste() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "I like ham")

		let r2 = delta.computeDelta(from: "I like hamburgers")
		#expect(r2.textToPaste == "")

		let r3 = delta.computeDelta(from: "I like hamburgers and")
		#expect(r3.textToPaste == "hamburgers")
		#expect(r3.needsLeadingSpace == true)
	}

	@Test
	func stableLastWordPastedImmediately() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "Hello world")

		let r2 = delta.computeDelta(from: "Hello world")
		#expect(r2.textToPaste == "world")
		#expect(r2.needsLeadingSpace == true)
	}

	// MARK: - Word Count Regression

	@Test
	func shorterResultDoesNotPaste() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello my name is Jack")

		let r2 = delta.computeDelta(from: "Hello my name")
		#expect(r2.textToPaste == "")
		#expect(r2.hasNewContent == false)
		#expect(delta.pastedWordCount == 4)
	}

	// MARK: - Final Delta

	@Test
	func finalDeltaPastesRemainingWords() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello my name is Jack")
		#expect(delta.pastedWordCount == 4)

		let finalResult = delta.computeFinalDelta(from: "Hello my name is Jack Lau")
		#expect(finalResult == "Jack Lau")
	}

	@Test
	func finalDeltaWithNothingPastedReturnsFullText() {
		let delta = LiveTranscriptionDelta()
		let result = delta.computeFinalDelta(from: "Hello world")
		#expect(result == "Hello world")
	}

	@Test
	func finalDeltaWithEverythingPastedReturnsEmpty() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello world")
		_ = delta.computeDelta(from: "Hello world")

		let result = delta.computeFinalDelta(from: "Hello world")
		#expect(result == "")
	}

	// MARK: - Reset

	@Test
	func resetClearsState() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello world")
		delta.reset()
		#expect(delta.pastedWordCount == 0)
		#expect(delta.heldBackWord == nil)
	}

	// MARK: - Flush Held-Back Word

	@Test
	func flushHeldBackWordReturnsIt() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello world")

		let flushed = delta.flushHeldBackWord()
		#expect(flushed == "world")
		#expect(delta.pastedWordCount == 2)
	}

	@Test
	func flushWithNothingHeldBackReturnsEmpty() {
		var delta = LiveTranscriptionDelta()
		#expect(delta.flushHeldBackWord() == "")
	}

	@Test
	func flushThenFinalDeltaDoesNotRepeat() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello my name is Jack")
		_ = delta.flushHeldBackWord()

		let final = delta.computeFinalDelta(from: "Hello my name is Jack")
		#expect(final == "")
	}

	@Test
	func flushThenFinalDeltaOnlyPastesNewContent() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello my name is Jack")
		_ = delta.flushHeldBackWord()

		let final = delta.computeFinalDelta(from: "Hello my name is Jack Lau")
		#expect(final == "Lau")
	}

	// MARK: - Edge Cases

	@Test
	func punctuationOnlyText() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "...")
		#expect(result.textToPaste == "")
		#expect(delta.heldBackWord == "...")
	}

	@Test
	func subsequentDeltaNeedsLeadingSpace() {
		var delta = LiveTranscriptionDelta()
		let r1 = delta.computeDelta(from: "Hello world test")
		#expect(r1.needsLeadingSpace == false)

		let r2 = delta.computeDelta(from: "Hello world test more words")
		#expect(r2.needsLeadingSpace == true)
	}
}
