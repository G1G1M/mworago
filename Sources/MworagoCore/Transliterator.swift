import Foundation

/// 한글 음차를 가나 후보들로 되돌린다.
///
/// 가나 → 한글은 답이 하나지만, 한글 → 가나는 답이 여럿이다. 한글이 표기하지 못하는
/// 정보(장음·탁음·촉음)가 있기 때문이다. 그래서 이 단계는 정답 하나를 고르지 않고
/// **가능한 후보를 모두 펼친다.** 좁히는 일은 다음 단계(사전 대조)의 몫이다.
public enum Transliterator {

    // MARK: 초성 → 자음

    /// 한국어에는 어두 유성음이 없어서, 화자가 だ를 "다"로도 "타"로도 적는다.
    /// 그래서 갈리는 초성은 후보를 둘 다 낸다. 배열 순서가 곧 우선순위.
    static let consonants: [Character: [String]] = [
        "ㄱ": ["g", "k"], "ㄲ": ["k"], "ㅋ": ["k"],
        "ㄷ": ["d", "t"], "ㄸ": ["t"], "ㅌ": ["t"],
        "ㅂ": ["b", "p"], "ㅃ": ["p"], "ㅍ": ["p"],
        "ㅈ": ["z", "t"], "ㅉ": ["z"], "ㅊ": ["t"],   // じ와 ち를 한국인은 둘 다 "지/치"로 적는다
        "ㅅ": ["s"], "ㅆ": ["s"],
        "ㄴ": ["n"], "ㅁ": ["m"], "ㄹ": ["r"], "ㅎ": ["h"],
        "ㅇ": [""],                                    // 모음으로 시작
    ]

    // MARK: 중성 → 모음

    enum MedialKind {
        case plain   // 자음 + 모음
        case yoon    // 자음 + y + 모음 (きゃ·しょ)
        case w       // w + 모음 (わ·を)
    }

    static let medials: [Character: [(Character, MedialKind)]] = [
        "ㅏ": [("a", .plain)],
        "ㅐ": [("e", .plain)],
        "ㅓ": [("o", .plain)],                        // 일본어에 "어"가 없어 お로 흡수된다
        "ㅔ": [("e", .plain)],
        "ㅗ": [("o", .plain), ("o", .w)],             // 조사 を도 "오"로 적힌다
        "ㅜ": [("u", .plain)],
        "ㅡ": [("u", .plain)],
        "ㅣ": [("i", .plain)],
        "ㅢ": [("i", .plain)],
        "ㅑ": [("a", .yoon)], "ㅒ": [("a", .yoon)],
        "ㅕ": [("o", .yoon)], "ㅖ": [("e", .plain)],
        "ㅛ": [("o", .yoon)],
        "ㅠ": [("u", .yoon)],
        "ㅘ": [("a", .w)], "ㅙ": [("e", .w)], "ㅚ": [("o", .plain)],
        "ㅝ": [("o", .w)], "ㅞ": [("e", .w)], "ㅟ": [("i", .plain)],
    ]

    // MARK: 종성 → 특수 모라

    /// 받침은 일본어의 두 특수 모라 중 하나로 간다.
    /// ん은 뒤 자음에 따라 ㄴ·ㅁ·ㅇ 어느 받침으로도 적히고, っ은 ㅅ·ㄱ·ㅂ 등으로 적힌다.
    static let finals: [Character: String] = [
        "ㄴ": "n", "ㅁ": "n", "ㅇ": "n",
        "ㄱ": "Q", "ㄲ": "Q", "ㄷ": "Q", "ㅅ": "Q", "ㅆ": "Q",
        "ㅈ": "Q", "ㅊ": "Q", "ㅋ": "Q", "ㅌ": "Q", "ㅍ": "Q", "ㅂ": "Q", "ㅎ": "Q",
    ]

    // MARK: 음절 하나

    /// 음절 하나가 만들 수 있는 모라 열들. 일본어에 없는 소리는 여기서 이미 걸러진다.
    public static func moraCandidates(for syllable: HangulSyllable) -> [[String]] {
        guard let consonants = consonants[syllable.initial],
              let medials = medials[syllable.medial]
        else { return [] }

        // 받침이 있는데 ん·っ 어느 쪽도 아니면(ㄹ, 겹받침) 이 음절은 포기한다.
        var tail: [String] = []
        if let final = syllable.final {
            guard let mora = finals[final] else { return [] }
            tail = [mora]
        }

        var result: [[String]] = []
        for consonant in consonants {
            for (vowel, kind) in medials {
                let mora: String
                switch kind {
                case .plain: mora = consonant + String(vowel)
                case .yoon:  mora = consonant + "y" + String(vowel)
                case .w:     guard consonant.isEmpty else { continue }; mora = "w" + String(vowel)
                }
                guard KanaTable.kana(for: mora) != nil else { continue }
                let candidate = [mora] + tail
                if !result.contains(candidate) { result.append(candidate) }
            }
        }
        return result
    }

    // MARK: 장음 복원

    /// 모음 뒤에 붙는 장음 글자. 한글 음차에서 가장 흔하게 증발하는 정보다.
    private static let longVowel: [Character: String] = ["o": "u", "u": "u", "e": "i"]

    /// 장음을 넣을 수 있는 자리를 모두 조합해 변형을 만든다.
    /// こう·とう처럼 어디에 들어갔는지 한글만 봐서는 알 수 없으므로 전부 시도한다.
    static func longVowelVariants(_ morae: [String]) -> [[String]] {
        // 삽입 가능한 자리 찾기
        var slots: [(index: Int, mora: String)] = []
        for (index, mora) in morae.enumerated() {
            guard let last = mora.last, let inserted = longVowel[last] else { continue }
            // 다음 모라가 이미 그 장음이면 넣어봐야 같은 말이 되므로 건너뛴다
            if index + 1 < morae.count, morae[index + 1] == inserted { continue }
            slots.append((index, inserted))
        }
        slots = Array(slots.prefix(8))   // 2^8 = 256. 이 이상은 후보가 쓸모없이 불어난다

        var variants: [[String]] = []
        for mask in 0..<(1 << slots.count) {
            var variant: [String] = []
            var slotCursor = 0
            for (index, mora) in morae.enumerated() {
                variant.append(mora)
                if slotCursor < slots.count, slots[slotCursor].index == index {
                    if mask & (1 << slotCursor) != 0 { variant.append(slots[slotCursor].mora) }
                    slotCursor += 1
                }
            }
            variants.append(variant)
        }
        return variants
    }

    // MARK: 낱말 전체

    /// 한글 음차가 될 수 있는 가나 표기를 모두 만든다. 한글이 아니면 빈 배열.
    public static func kanaCandidates(for hangul: String, limit: Int = 5000) -> [String] {
        guard let syllables = HangulSyllable.decompose(hangul), !syllables.isEmpty else { return [] }

        // 음절별 후보를 이어 붙인다(데카르트 곱). 중간에 상한을 넘으면 잘라낸다.
        var sequences: [[String]] = [[]]
        for syllable in syllables {
            let candidates = moraCandidates(for: syllable)
            guard !candidates.isEmpty else { return [] }

            var next: [[String]] = []
            next.reserveCapacity(min(sequences.count * candidates.count, limit))
            for sequence in sequences {
                for candidate in candidates {
                    next.append(sequence + candidate)
                    if next.count >= limit { break }
                }
                if next.count >= limit { break }
            }
            sequences = next
        }

        var seen = Set<String>()
        var result: [String] = []
        for sequence in sequences {
            for variant in longVowelVariants(sequence) {
                guard let kana = KanaTable.compose(variant), seen.insert(kana).inserted else { continue }
                result.append(kana)
                if result.count >= limit { return result }
            }
        }
        return result
    }
}
