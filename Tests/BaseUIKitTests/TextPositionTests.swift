import XCTest
@testable import BaseUIKit

final class TextPositionTests: XCTestCase {

    // MARK: - utf16Offset init

    func testUTF16OffsetInit() {
        let position = TextPosition(utf16Offset: 7)
        XCTAssertEqual(position.utf16Offset, 7)
    }

    func testUTF16OffsetZero() {
        let position = TextPosition(utf16Offset: 0)
        XCTAssertEqual(position.utf16Offset, 0)
    }

    // MARK: - stringIndex init (ASCII)

    func testStringIndexInitASCII() {
        let string = "Hello"
        let index = string.index(string.startIndex, offsetBy: 3) // after "Hel"
        let position = TextPosition(stringIndex: index, in: string)
        XCTAssertEqual(position.utf16Offset, 3)
    }

    func testStringIndexInitAtStart() {
        let string = "Hello"
        let position = TextPosition(stringIndex: string.startIndex, in: string)
        XCTAssertEqual(position.utf16Offset, 0)
    }

    func testStringIndexInitAtEnd() {
        let string = "Hello"
        let position = TextPosition(stringIndex: string.endIndex, in: string)
        XCTAssertEqual(position.utf16Offset, 5)
    }

    // MARK: - stringIndex init (multi-code-unit graphemes)

    func testStringIndexInitWithEmoji() {
        // "Hi👋" — 👋 is U+1F44B, which is 2 UTF-16 code units (a surrogate pair)
        let string = "Hi👋"
        // Index after the emoji (= endIndex)
        let position = TextPosition(stringIndex: string.endIndex, in: string)
        // H(1) + i(1) + 👋(2) = 4 UTF-16 code units
        XCTAssertEqual(position.utf16Offset, 4)
    }

    func testStringIndexInitBeforeEmoji() {
        let string = "Hi👋"
        let index = string.index(string.startIndex, offsetBy: 2) // before 👋
        let position = TextPosition(stringIndex: index, in: string)
        // H(1) + i(1) = 2
        XCTAssertEqual(position.utf16Offset, 2)
    }

    func testStringIndexInitWithFlag() {
        // 🇺🇸 is two regional indicator symbols: U+1F1FA U+1F1F8
        // Each is 2 UTF-16 code units, total = 4 UTF-16 code units, but 1 grapheme
        let string = "A🇺🇸B"
        // A(1) + 🇺🇸(4) + B(1) = 6 UTF-16 code units
        let position = TextPosition(stringIndex: string.endIndex, in: string)
        XCTAssertEqual(position.utf16Offset, 6)
    }

    func testStringIndexInitAfterFlagEmoji() {
        let string = "A🇺🇸B"
        let bIndex = string.index(string.startIndex, offsetBy: 2) // "B" is 3rd grapheme
        let position = TextPosition(stringIndex: bIndex, in: string)
        // A(1) + 🇺🇸(4) = 5
        XCTAssertEqual(position.utf16Offset, 5)
    }

    func testStringIndexInitWithCombiningCharacter() {
        // "é" composed as e + combining acute accent (U+0065 U+0301)
        // 2 UTF-16 code units, 1 grapheme cluster
        let string = "e\u{0301}x"
        let xIndex = string.index(string.startIndex, offsetBy: 1) // "x" is 2nd grapheme
        let position = TextPosition(stringIndex: xIndex, in: string)
        // e(1) + combining accent(1) = 2
        XCTAssertEqual(position.utf16Offset, 2)
    }

    // MARK: - endOf

    func testEndOfASCII() {
        let position = TextPosition.endOf("Hello")
        XCTAssertEqual(position.utf16Offset, 5)
    }

    func testEndOfWithEmoji() {
        // "A👋" — A(1) + 👋(2) = 3
        let position = TextPosition.endOf("A👋")
        XCTAssertEqual(position.utf16Offset, 3)
    }

    func testEndOfEmpty() {
        let position = TextPosition.endOf("")
        XCTAssertEqual(position.utf16Offset, 0)
    }

    // MARK: - stringIndex(in:) round-trip

    func testStringIndexRoundTripASCII() {
        let string = "Hello"
        let original = string.index(string.startIndex, offsetBy: 3)
        let position = TextPosition(stringIndex: original, in: string)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, original)
    }

    func testStringIndexRoundTripBeforeEmoji() {
        let string = "Hi👋World"
        let original = string.index(string.startIndex, offsetBy: 2) // before 👋
        let position = TextPosition(stringIndex: original, in: string)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, original)
    }

    func testStringIndexRoundTripAfterEmoji() {
        let string = "Hi👋World"
        let original = string.index(string.startIndex, offsetBy: 3) // after 👋, before "W"
        let position = TextPosition(stringIndex: original, in: string)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, original)
    }

    func testStringIndexRoundTripEndOfString() {
        let string = "Hi👋"
        let position = TextPosition.endOf(string)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, string.endIndex)
    }

    func testStringIndexRoundTripWithCombiningCharacter() {
        let string = "e\u{0301}x" // é + x
        let xIndex = string.index(string.startIndex, offsetBy: 1)
        let position = TextPosition(stringIndex: xIndex, in: string)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, xIndex)
    }

    // MARK: - stringIndex(in:) edge cases

    func testStringIndexAtZero() {
        let string = "Hello"
        let position = TextPosition(utf16Offset: 0)
        let recovered = position.stringIndex(in: string)
        XCTAssertEqual(recovered, string.startIndex)
    }

    func testStringIndexBeyondEndReturnsNil() {
        let string = "Hi"
        let position = TextPosition(utf16Offset: 100)
        let recovered = position.stringIndex(in: string)
        XCTAssertNil(recovered)
    }

    func testStringIndexInEmptyString() {
        let position = TextPosition(utf16Offset: 0)
        let recovered = position.stringIndex(in: "")
        XCTAssertEqual(recovered, "".startIndex)
    }

    // MARK: - Comparable

    func testLessThan() {
        let a = TextPosition(utf16Offset: 3)
        let b = TextPosition(utf16Offset: 5)
        XCTAssertTrue(a < b)
        XCTAssertFalse(b < a)
    }

    func testEqualPositions() {
        let a = TextPosition(utf16Offset: 4)
        let b = TextPosition(utf16Offset: 4)
        XCTAssertEqual(a, b)
        XCTAssertFalse(a < b)
    }

    // MARK: - TextRange

    func testTextRangeNormalizesOrder() {
        let range = TextRange(
            start: TextPosition(utf16Offset: 10),
            end: TextPosition(utf16Offset: 3)
        )
        XCTAssertEqual(range.start.utf16Offset, 3)
        XCTAssertEqual(range.end.utf16Offset, 10)
    }

    func testTextRangePreservesOrder() {
        let range = TextRange(
            start: TextPosition(utf16Offset: 2),
            end: TextPosition(utf16Offset: 7)
        )
        XCTAssertEqual(range.start.utf16Offset, 2)
        XCTAssertEqual(range.end.utf16Offset, 7)
    }
}
