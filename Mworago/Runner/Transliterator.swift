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

    // MARK: 표기법이 지우는 것

    /// じ·ち 계열의 초성.
    ///
    /// 국립국어원 표기법은 `じゃ·じゅ·じょ` 를 **자·주·조**로, `ちゃ·ちゅ·ちょ` 를
    /// **차·추·초**로 적는다. じ 와 ち 가 이미 구개음이라 한국어에서 요음성이 표기되지 않는다.
    /// 그래서 표기법대로 적은 사람이 오히려 못 찾았다 — "쇼조"(少女)가 しょじょ 조차 못 냈다.
    static let palatalInitials: Set<Character> = ["ㅈ", "ㅉ", "ㅊ"]

    /// `つ` 를 적는 또 하나의 길.
    ///
    /// 표기법은 `つ` 를 **쓰**로 적는다(쓰나미 · 쓰시마). 관용 표기인 "츠"만 길이 나 있어서,
    /// 표기법대로 친 사람이 机(つくえ)에 닿지 못했다.
    ///
    /// **"스"는 열지 않는다.** 처음엔 ㅅ 도 함께 열었는데, 재어 보니 JESC 기준 3위 안이
    /// 146 에서 145 로 떨어졌다 — `스`(っす)가 つ 에 밀렸다. ㅆ 만 열면 그 손해가 없고
    /// 표기법 쪽 길은 그대로 난다. 한글이 소리를 잃는 자리마다 길을 내되,
    /// **재서 손해인 길은 내지 않는다.**
    static func isTsuSpelling(_ syllable: HangulSyllable) -> Bool {
        syllable.initial == "ㅆ" && syllable.medial == "ㅡ"
    }

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
                var morae = [mora]
                // 표기법이 요음을 단모음으로 적는 자리 — 조 → じょ · 초 → ちょ
                if kind == .plain, Self.palatalInitials.contains(syllable.initial) {
                    morae.append(consonant + "y" + String(vowel))
                }
                for mora in morae {
                    guard KanaTable.kana(for: mora) != nil else { continue }
                    let candidate = [mora] + tail
                    if !result.contains(candidate) { result.append(candidate) }
                }
            }
        }
        // 쓰·스 → つ
        if isTsuSpelling(syllable), KanaTable.kana(for: "tu") != nil {
            let candidate = ["tu"] + tail
            if !result.contains(candidate) { result.append(candidate) }
        }
        return result
    }

    // MARK: 장음 복원

    /// 모음 뒤에 붙는 장음 글자. 한글 음차에서 가장 흔하게 증발하는 정보다.
    private static let longVowel: [Character: String] = ["o": "u", "u": "u", "e": "i"]

    /// 장음을 넣을 수 있는 자리를 모두 조합해 변형을 만든다.
    /// こう·とう처럼 어디에 들어갔는지 한글만 봐서는 알 수 없으므로 전부 시도한다.
    /// 넣은 개수를 함께 돌려준다 — 한글에 없던 글자를 많이 지어낸 후보일수록 덜 그럴듯하다.
    static func longVowelVariants(_ morae: [String]) -> [(morae: [String], added: Int)] {
        // 삽입 가능한 자리 찾기
        var slots: [(index: Int, mora: String)] = []
        for (index, mora) in morae.enumerated() {
            guard let last = mora.last, let inserted = longVowel[last] else { continue }
            // 다음 모라가 이미 그 장음이면 넣어봐야 같은 말이 되므로 건너뛴다
            if index + 1 < morae.count, morae[index + 1] == inserted { continue }
            slots.append((index, inserted))
        }
        slots = Array(slots.prefix(8))   // 2^8 = 256. 이 이상은 후보가 쓸모없이 불어난다

        var variants: [(morae: [String], added: Int)] = []
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
            variants.append((variant, mask.nonzeroBitCount))
        }
        // 장음을 적게 넣은 것부터 — 뒤에서 순위를 매길 때 이 순서가 곧 그럴듯함의 순서다
        return variants.sorted { $0.added < $1.added }
    }

    // MARK: 낱말 전체

    /// 규칙이 만들어 낸 가나 후보 하나와, 그것이 얼마나 과감한 추측인지에 대한 단서.
    public struct KanaCandidate: Sendable, Equatable {
        public let kana: String
        public let rank: Int              // 규칙이 낸 순서. 앞일수록 보수적인 추측
        public let longVowelsAdded: Int   // 한글에 없던 장음을 몇 개 지어냈나
        /// 한글에 없던 촉음을 몇 개 지어냈나.
        ///
        /// 후보 **순서**를 뒤로 미루는 것만으로는 모자랐다. 점수는 빈도로 매기므로
        /// 지어낸 쪽이 더 흔한 낱말이면 그대로 이긴다 — `이타이` 가 `いったい`(도대체)로
        /// 잡혀 `いたい`(아프다)를 밀어냈다. 그래서 점수에서도 깎는다.
        public var geminatesAdded: Int = 0
    }

    /// 촉음 뒤에 올 수 있는 소리의 첫 글자. 모라는 로마자 키로 다루므로
    /// か·さ·た·ぱ 행이 각각 k · s · t(ch 는 c) · p 로 온다.
    /// 탁음 앞의 촉음(っが)은 일본 고유어에 없어 넣지 않는다.
    private static let afterGeminate: Set<Character> = ["k", "s", "t", "c", "p"]

    /// 촉음을 **한 번** 끼운 변형들.
    ///
    /// 촉음은 한국 사람 귀에 가장 안 들리는 소리다. 앞 음절 받침으로 적어야 하는데
    /// (`らっしゃ` → `랏샤`) 뒤 음절과 이어져 들려서 그냥 넘어가기 쉽다.
    /// 실제로 `잇테라샤이` 는 첫 촉음만 맞히고 둘째를 빠뜨린 꼴이다.
    ///
    /// **한 번만 끼운다.** 자리마다 넣고 빼면 후보가 2ⁿ 으로 터진다. 두 개를 한꺼번에
    /// 빠뜨리는 일은 드물고, 하나만 열어도 대부분 닿는다.
    private static func geminateVariants(_ morae: [String]) -> [[String]] {
        guard morae.count >= 2 else { return [] }
        var out: [[String]] = []
        for i in 0..<(morae.count - 1) {
            guard morae[i] != "Q", morae[i + 1] != "Q", morae[i + 1] != "n",
                  let head = morae[i + 1].first, afterGeminate.contains(head)
            else { continue }
            var copy = morae
            copy.insert("Q", at: i + 1)   // 촉음. 로마자 표기가 없어 대문자로 쓴다
            out.append(copy)
        }
        return out
    }

    /// 한글 음차가 될 수 있는 가나 표기를 모두 만든다. 한글이 아니면 빈 배열.
    public static func kanaCandidates(for hangul: String, limit: Int = 5000) -> [String] {
        candidates(for: hangul, limit: limit).map(\.kana)
    }

    /// 후보를 단서와 함께 만든다. 순위를 매기는 쪽이 쓴다.
    public static func candidates(for hangul: String, limit: Int = 5000) -> [KanaCandidate] {
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
        var result: [KanaCandidate] = []
        for sequence in sequences {
            for variant in longVowelVariants(sequence) {
                guard let kana = KanaTable.compose(variant.morae), seen.insert(kana).inserted else { continue }
                result.append(KanaCandidate(kana: kana, rank: result.count, longVowelsAdded: variant.added))
                if result.count >= limit { return result }
            }
        }

        // **촉음을 지어낸 것은 맨 뒤에 선다.** 사용자가 적지 않은 소리를 넣는 것이라
        // 장음보다도 과감한 추측이다. 제대로 친 사람의 답을 밀어내면 안 된다.
        for sequence in sequences {
            for variant in longVowelVariants(sequence) {
                for geminated in geminateVariants(variant.morae) {
                    guard let kana = KanaTable.compose(geminated), seen.insert(kana).inserted else { continue }
                    result.append(KanaCandidate(kana: kana, rank: result.count,
                                                longVowelsAdded: variant.added,
                                                geminatesAdded: 1))
                    if result.count >= limit { return result }
                }
            }
        }
        return result
    }
}
