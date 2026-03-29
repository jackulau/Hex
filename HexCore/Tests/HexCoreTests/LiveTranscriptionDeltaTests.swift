import Testing
@testable import HexCore

struct LiveTranscriptionDeltaTests {

	// MARK: - Basic Delta

	@Test
	func firstTickPastesAllButLastWord() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "Hello my name is Jack")
		#expect(result.textToPaste == "Hello my name is")
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
		#expect(delta.pastedWordCount == 0)
	}

	@Test
	func singleWordConfirmedOnSecondTick() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello")
		let result = delta.computeDelta(from: "Hello")
		#expect(result.textToPaste == "Hello")
		#expect(delta.pastedWordCount == 1)
		#expect(delta.heldBackWord == nil)
	}

	// MARK: - Progressive Pasting

	@Test
	func progressivePastingAcrossTicks() {
		var delta = LiveTranscriptionDelta()

		// Tick 1: "Hello my"
		let r1 = delta.computeDelta(from: "Hello my")
		#expect(r1.textToPaste == "Hello")
		#expect(delta.pastedWordCount == 1)
		#expect(delta.heldBackWord == "my")

		// Tick 2: "Hello my name is"
		let r2 = delta.computeDelta(from: "Hello my name is")
		#expect(r2.textToPaste == " my name")
		#expect(delta.pastedWordCount == 3)
		#expect(delta.heldBackWord == "is")

		// Tick 3: "Hello my name is Jack"
		let r3 = delta.computeDelta(from: "Hello my name is Jack")
		#expect(r3.textToPaste == " is")
		#expect(delta.pastedWordCount == 4)
		#expect(delta.heldBackWord == "Jack")
	}

	// MARK: - Hold-Back Stability

	@Test
	func heldBackWordReleasedWhenConfirmed() {
		var delta = LiveTranscriptionDelta()

		// Tick 1: "I like ham" — holds back "ham"
		let r1 = delta.computeDelta(from: "I like ham")
		#expect(r1.textToPaste == "I like")
		#expect(delta.heldBackWord == "ham")

		// Tick 2: "I like hamburgers and" — "ham" changed to "hamburgers", holds back "and"
		let r2 = delta.computeDelta(from: "I like hamburgers and")
		#expect(r2.textToPaste == " hamburgers")
		#expect(delta.pastedWordCount == 3)
		#expect(delta.heldBackWord == "and")
	}

	@Test
	func heldBackWordPreventsBadPaste() {
		var delta = LiveTranscriptionDelta()

		// Tick 1: "I like ham" — holds back "ham"
		_ = delta.computeDelta(from: "I like ham")
		#expect(delta.heldBackWord == "ham")

		// Tick 2: "I like hamburgers" — "ham" became "hamburgers", new hold-back
		let r2 = delta.computeDelta(from: "I like hamburgers")
		// "hamburgers" is the new last word, different from "ham", so held back
		#expect(r2.textToPaste == "")
		#expect(delta.heldBackWord == "hamburgers")
		#expect(delta.pastedWordCount == 2)

		// Tick 3: "I like hamburgers and" — "hamburgers" confirmed, paste it
		let r3 = delta.computeDelta(from: "I like hamburgers and")
		#expect(r3.textToPaste == " hamburgers")
		#expect(delta.pastedWordCount == 3)
		#expect(delta.heldBackWord == "and")
	}

	@Test
	func stableLastWordPastedImmediately() {
		var delta = LiveTranscriptionDelta()

		// Tick 1
		_ = delta.computeDelta(from: "Hello world")
		#expect(delta.heldBackWord == "world")

		// Tick 2: same last word "world" — it's stable, paste it
		let r2 = delta.computeDelta(from: "Hello world")
		#expect(r2.textToPaste == " world")
		#expect(delta.pastedWordCount == 2)
		#expect(delta.heldBackWord == nil)
	}

	// MARK: - Word Count Regression

	@Test
	func shorterResultDoesNotPaste() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "Hello my name is Jack")
		#expect(delta.pastedWordCount == 4)

		// Shorter result (model correction) — should not paste
		let r2 = delta.computeDelta(from: "Hello my name")
		#expect(r2.textToPaste == "")
		#expect(r2.hasNewContent == false)
		#expect(delta.pastedWordCount == 4) // unchanged
	}

	// MARK: - Final Delta

	@Test
	func finalDeltaPastesRemainingWords() {
		var delta = LiveTranscriptionDelta()

		_ = delta.computeDelta(from: "Hello my name is Jack")
		// Pasted "Hello my name is", holding back "Jack"
		#expect(delta.pastedWordCount == 4)

		let finalText = "Hello my name is Jack Lau"
		let finalResult = delta.computeFinalDelta(from: finalText)
		#expect(finalResult == " Jack Lau")
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
		_ = delta.computeDelta(from: "Hello world") // confirms "world"
		#expect(delta.pastedWordCount == 2)

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

	// MARK: - Edge Cases

	@Test
	func punctuationOnlyText() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "...")
		#expect(result.textToPaste == "")
		#expect(delta.heldBackWord == "...")
	}

	@Test
	func multipleSpacesAreTreatedAsOne() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "Hello   world   test")
		#expect(result.textToPaste == "Hello world")
		#expect(delta.pastedWordCount == 2)
	}

	@Test
	func leadingAndTrailingSpaces() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "  Hello world  ")
		#expect(result.textToPaste == "Hello")
		#expect(delta.pastedWordCount == 1)
	}

	@Test
	func noSpacePrefixOnFirstPaste() {
		var delta = LiveTranscriptionDelta()
		let result = delta.computeDelta(from: "Hello world test")
		#expect(result.textToPaste == "Hello world")
		// No leading space on first paste
		#expect(result.textToPaste.first != " ")
	}

	@Test
	func spacePrefixOnSubsequentPaste() {
		var delta = LiveTranscriptionDelta()
		_ = delta.computeDelta(from: "Hello world")
		let r2 = delta.computeDelta(from: "Hello world test more")
		#expect(r2.textToPaste.first == " ")
	}
}
