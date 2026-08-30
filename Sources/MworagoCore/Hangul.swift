import Foundation

/// 한글 음절 하나를 초성·중성·종성으로 쪼갠 것.
///
/// 한글 완성형은 U+AC00(가)부터 U+D7A3(힣)까지 11,172자가
/// `초성 × 588 + 중성 × 28 + 종성` 순서로 빈틈없이 채워져 있다.
/// 그래서 표를 찾을 필요 없이 나눗셈 세 번으로 분해된다.
public struct HangulSyllable: Equatable, Sendable {
    public let initial: Character   // 초성 19개 중 하나
    public let medial: Character    // 중성 21개 중 하나
    public let final: Character?    // 종성 27개 중 하나, 받침이 없으면 nil

    public static let initials: [Character] = [
        "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]
    public static let medials: [Character] = [
        "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ",
        "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ",
    ]
    /// 0번은 "받침 없음" 자리라 비어 있다.
    public static let finals: [Character?] = [
        nil, "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ",
        "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ",
        "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
    ]

    private static let base: UInt32 = 0xAC00
    private static let last: UInt32 = 0xD7A3

    /// 완성형 한글 음절 하나를 분해한다. 한글이 아니면 nil.
    public init?(_ character: Character) {
        guard character.unicodeScalars.count == 1,
              let scalar = character.unicodeScalars.first,
              (Self.base...Self.last).contains(scalar.value)
        else { return nil }

        let index = Int(scalar.value - Self.base)
        self.initial = Self.initials[index / 588]
        self.medial = Self.medials[(index / 28) % 21]
        self.final = Self.finals[index % 28]
    }

    /// 문자열 전체를 분해한다. 한 글자라도 완성형 한글이 아니면 nil.
    public static func decompose(_ text: String) -> [HangulSyllable]? {
        var result: [HangulSyllable] = []
        result.reserveCapacity(text.count)
        for character in text {
            guard let syllable = HangulSyllable(character) else { return nil }
            result.append(syllable)
        }
        return result
    }
}
