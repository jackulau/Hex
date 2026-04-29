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

	// MARK: - Sliding Window

	@Test
	func slidingWindowContinuesPasting() {
		var delta = LiveTranscriptionDelta()

		// Buffer fills: "A B C D E"
		let r1 = delta.computeDelta(from: "A B C D E")
		#expect(r1.textToPaste == "A B C D")
		#expect(delta.heldBackWord == "E")

		// Buffer slides: "A" drops, "F" added → "B C D E F"
		let r2 = delta.computeDelta(from: "B C D E F")
		#expect(r2.textToPaste == "E")
		#expect(r2.needsLeadingSpace == true)
		#expect(delta.heldBackWord == "F")

		// Another slide: "B" drops, "G" added → "C D E F G"
		let r3 = delta.computeDelta(from: "C D E F G")
		#expect(r3.textToPaste == "F")
		#expect(r3.needsLeadingSpace == true)
		#expect(delta.heldBackWord == "G")
	}

	@Test
	func slidingWindowFlushesCorrectly() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "A B C D E")
		_ = delta.computeDelta(from: "B C D E F")

		let flushed = delta.flushHeldBackWord()
		#expect(flushed == "F")
	}

	@Test
	func slidingWindowFinalDelta() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "A B C D E")
		// Slide
		_ = delta.computeDelta(from: "B C D E F")
		// E got pasted, F held back

		// Final transcription of full audio (not windowed)
		let final = delta.computeFinalDelta(from: "B C D E F G H")
		// pastedWordCount is relative to current window, F is held back
		// Should paste everything after what was confirmed
		#expect(final.contains("F"))
		#expect(final.contains("G"))
		#expect(final.contains("H"))
	}

	@Test
	func noSlideWhenFirstWordUnchanged() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "Hello my name is Jack")
		#expect(delta.pastedWordCount == 4)

		// Model fluctuation — same start, fewer words. Should NOT adjust.
		let r2 = delta.computeDelta(from: "Hello my name")
		#expect(r2.textToPaste == "")
		#expect(r2.hasNewContent == false)
	}

	@Test
	func overlapFailureDoesNotRepaste() {
		var delta = LiveTranscriptionDelta()

		// Build up pasted state
		_ = delta.computeDelta(from: "the quick brown fox jumps over the lazy dog")
		#expect(delta.pastedWordCount == 8)

		// Completely different transcription (no overlap). Must NOT re-paste.
		let r2 = delta.computeDelta(from: "something entirely different here now")
		#expect(r2.textToPaste == "")
	}

	@Test
	func slidingWindowWithRealisticWordCount() {
		var delta = LiveTranscriptionDelta()

		// ~20 words, simulating 30s of speech
		let initial = "I want to make sure that we are scraping all the events and verifying that the links are correct"
		_ = delta.computeDelta(from: initial)
		let pastedAfterFirst = delta.pastedWordCount
		#expect(pastedAfterFirst == 18) // all but "correct" held back

		// Slide: first word drops, new word added at end
		let slid = "want to make sure that we are scraping all the events and verifying that the links are correct as"
		let r2 = delta.computeDelta(from: slid)
		#expect(r2.textToPaste == "correct")
		#expect(r2.needsLeadingSpace == true)

		// Another slide
		let slid2 = "to make sure that we are scraping all the events and verifying that the links are correct as well"
		let r3 = delta.computeDelta(from: slid2)
		#expect(r3.textToPaste == "as")
		#expect(r3.needsLeadingSpace == true)
	}
}
