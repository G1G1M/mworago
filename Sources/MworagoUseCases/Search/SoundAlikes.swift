import Foundation
import MworagoDomain

/// 한 글자만 다르게 들었다면 닿았을 낱말.
public struct SoundAlike: Sendable {
    /// 무엇을 바꿨는가. 화면이 「~로 들렸다면」을 말할 때 쓴다.
    public enum Change: String, Sendable {
        /// 거센소리·된소리를 예사소리로(`캇코` → `갓코`). 예사소리는 탁음과 청음을 둘 다 연다.
        case voicing
        /// `ㄹ` 과 `ㄷ` 을 맞바꾼다. 일본어 ら행은 혀를 한 번 튀기는 소리라 `ㄷ` 으로도 들린다.
        case liquid
        /// 받침을 뺀다. 없는 촉음·ん 을 들은 것이다.
        case finalDropped
        /// `ㄴ` 받침을 더한다. ん 은 짧고 콧소리라 흘려듣기 쉽다.
        case nasalAdded
    }

    /// 바꾼 조각 전체의 한글.
    public let hangul: String
    public let change: Change
    /// 그 소리로 찾았을 때의 1위.
    public let result: SearchResult
}

/// 사용자가 친 한글에서 **한 글자만 다르게 들은** 소리를 만들어 사전에 묻는다.
///
/// **주 순위는 건드리지 않는다.** 순위는 케이스 150 · 문장 300 으로 훑어 고른 값들이 받치고
/// 있고, 그 위에 「혹시 이렇게 들은 것 아니냐」는 추측을 섞으면 제대로 친 사람의 답이
/// 밀린다. 그래서 고친 소리는 1위와 다른 자리에 따로 곁들인다 — 고를지는 보는 사람이 정한다.
///
/// 두 자리에서 쓴다.
///  - **찾은 조각:** 탁음 하나만 본다. 바꾼 소리의 낱말이 지금 1위보다 **더 흔할 때만** 낸다.
///    그렇지 않으면 카드마다 헛것이 한 줄씩 붙는다(`키타` 를 칠 때마다 `기타`).
///  - **못 찾은 조각:** 한 글자를 바꾸는 길을 모두 연다. 이미 구멍이라 밀릴 답이 없다.
public enum SoundAlikes {

    /// 예사소리로 되돌릴 초성. **한쪽으로만 간다** — 예사소리는 이미 청음과 탁음을 둘 다
    /// 열고 있어서(`ㄱ` → が · か), 거꾸로 가면 새로 닿는 것이 없다.
    ///
    /// **`ㅅ` → `ㅈ` 은 넣지 않는다.** さ행의 탁음 ざ행이 `ㅈ` 에 적히기는 하지만, `ㅈ` 은
    /// ち 도 함께 열어서 엉뚱한 낱말이 걸렸다 — `코소`(こそ)에 「코조로 들렸다면 こと」가 붙었다.
    static let plain: [Character: Character] = [
        "ㅋ": "ㄱ", "ㄲ": "ㄱ", "ㅌ": "ㄷ", "ㄸ": "ㄷ",
        "ㅍ": "ㅂ", "ㅃ": "ㅂ", "ㅊ": "ㅈ",
    ]
    static let liquid: [Character: Character] = ["ㄹ": "ㄷ", "ㄷ": "ㄹ"]

    /// 한 글자만 바꾼 소리들. 같은 소리가 두 길로 나오면 앞의 것만 남긴다.
    static func neighbors(of hangul: String, voicingOnly: Bool) -> [(hangul: String, change: SoundAlike.Change)] {
        guard let syllables = HangulSyllable.decompose(hangul) else { return [] }
        var out: [(String, SoundAlike.Change)] = []
        var seen: Set<String> = [hangul]
        func add(_ index: Int, _ replaced: HangulSyllable?, _ change: SoundAlike.Change) {
            guard let replaced else { return }
            var copy = syllables
            copy[index] = replaced
            let text = String(copy.map(\.character))
            if seen.insert(text).inserted { out.append((text, change)) }
        }
        for (index, syllable) in syllables.enumerated() {
            if let to = plain[syllable.initial] {
                add(index, HangulSyllable(initial: to, medial: syllable.medial, final: syllable.final), .voicing)
            }
            guard !voicingOnly else { continue }
            if let to = liquid[syllable.initial] {
                add(index, HangulSyllable(initial: to, medial: syllable.medial, final: syllable.final), .liquid)
            }
            if syllable.final != nil {
                add(index, HangulSyllable(initial: syllable.initial, medial: syllable.medial, final: nil), .finalDropped)
            } else if index < syllables.count - 1 {
                add(index, HangulSyllable(initial: syllable.initial, medial: syllable.medial, final: "ㄴ"), .nasalAdded)
            }
        }
        return out
    }

    /// 조각 하나에 곁들일 소리들. `lookup` 은 나누기가 쓴 것과 같은 찾기여야 한다 —
    /// 같은 캐시를 지나야 치는 동안 다시 찾지 않는다.
    public static func suggestions(for segment: Segment, limit: Int = 3,
                                   margin: Double = voicingMargin,
                                   lookup: (String) -> [SearchResult]) -> [SoundAlike] {
        guard !segment.isWhole else { return [] }
        if let top = segment.results.first {
            // 한 글자짜리 조각은 고치지 않는다. 조사·어미가 대부분이라 바꾸면 딴 조사가 된다(`스` → `즈`).
            guard segment.hangul.count >= 2 else { return [] }
            // 찾은 조각: 탁음 하나, 그것도 지금 1위보다 흔한 낱말일 때만.
            //
            // **활용을 되돌려 겨우 맞은 것은 내지 않는다.** 지금 1위가 사전에 그대로 실린
            // 낱말인데 고친 쪽은 어미까지 지어낸 것이라면, 흔하다는 점수가 같은 잣대가 아니다.
            let shown = segment.results.prefix(3).map(\.entry)
            var best: SoundAlike?
            for (hangul, change) in neighbors(of: segment.hangul, voicingOnly: true) {
                guard let candidate = lookup(hangul).first,
                      candidate.deinflection == nil || top.deinflection != nil,
                      !shown.contains(candidate.entry),
                      candidate.score > top.score + margin,
                      candidate.score > (best?.result.score ?? -.infinity)
                else { continue }
                best = SoundAlike(hangul: hangul, change: change, result: candidate)
            }
            return best.map { [$0] } ?? []
        }

        // 못 찾은 조각: 한 글자를 바꾼 소리 중 사전에 있는 것, 흔한 순으로.
        var found: [SoundAlike] = []
        for (hangul, change) in neighbors(of: segment.hangul, voicingOnly: false) {
            guard let candidate = lookup(hangul).first,
                  !found.contains(where: { $0.result.entry == candidate.entry })
            else { continue }
            found.append(SoundAlike(hangul: hangul, change: change, result: candidate))
        }
        return Array(found.sorted { $0.result.score > $1.result.score }.prefix(limit))
    }

    /// 찾은 조각에 탁음을 곁들이려면 고친 쪽이 1위보다 이만큼은 흔해야 한다.
    ///
    /// **손으로 정하지 않았다.** `SpikeRunner --sound-alike` 로 쟀다(2026-11-03 · 낱말 케이스
    /// 150 과 손으로 적은 문장 40 을 바르게 친 것 190 개 · 한 글자를 틀리게 친 것 472 개).
    ///
    ///     여유   바르게 쳤는데 붙음   탁음을 틀린 62 개 중 건짐
    ///     0      2/190              51
    ///     5      1/190              49
    ///     10     1/190              48   ← 골랐다
    ///     20     0/190              44
    ///     30     0/190              40
    ///
    /// **20 이면 잡음이 0 이지만 이 기능이 있는 까닭을 잃는다.** `캇코` 를 친 사람에게
    /// 「갓코 学校」를 묻는 것이 이 줄의 첫 쓸모인데, 学校(60.8)와 かっこ(48.8)의 차이가 12 라
    /// 20 에서는 안 뜬다. 남는 잡음 하나는 `사이코`(最高 58)에 붙는 「사이고 最後」(69)로
    /// 차이가 11 이다 — 둘은 **같은 모양의 물음**이라 여유로는 가를 수 없고, 最高 와 最後 는
    /// 실제로도 한국 귀에 헷갈리는 짝이라 묻는 편을 택했다.
    /// 0 에서 하나 더 붙는 `카와`(川 54 → 側 57)는 차이 3 짜리라 묻기에는 약하다.
    public static let voicingMargin: Double = 10

    /// 입력 전체를 한 글자 바꿔 **한 낱말로** 닿는 소리.
    ///
    /// 한 글자를 틀리게 치면 대개 구멍이 나지 않는다 — 나누기가 어떻게든 아는 조각으로
    /// 메워서 `아디가토` 가 `あ 出 がと` 같은 엉뚱한 문장이 된다. 조각마다 고쳐 봐야
    /// 잘린 자리가 이미 틀렸으므로, 입력을 통째로 놓고 한 글자를 바꿔 본다.
    ///
    /// **입력이 이미 한 낱말로 찾아졌으면 내지 않는다.** 그때는 조각의 탁음 곁들이기가 맡는다.
    public static func wholeSuggestion(for input: String, segments: [Segment],
                                       minimumScore: Double = wholeMinimumScore,
                                       lookup: (String) -> [SearchResult]) -> SoundAlike? {
        let word = String(input.filter { !$0.isWhitespace })
        guard (2...maxWholeLength).contains(word.count), !segments.contains(where: \.isWhole) else { return nil }
        let pieces = segments.filter { !$0.isWhole }
        guard pieces.count > 1 || pieces.first?.results.isEmpty == true else { return nil }
        var best: SoundAlike?
        for (hangul, change) in neighbors(of: word, voicingOnly: false) {
            guard let candidate = lookup(hangul).first, candidate.deinflection == nil,
                  candidate.score >= minimumScore,
                  candidate.score > (best?.result.score ?? -.infinity)
            else { continue }
            best = SoundAlike(hangul: hangul, change: change, result: candidate)
        }
        return best
    }

    /// 통째로 고쳐 볼 입력의 길이 상한(음절). 한 낱말이 이보다 길기는 드물고, 넘으면 문장이다.
    ///
    /// 길이만큼 이웃이 생기고 이웃마다 긴 조각을 통째로 찾아야 해서, 열 글자짜리 문장을
    /// 치는 동안 한 글자에 0.7초를 여기서 썼다. 문장 하나를 한 글자 고쳐 한 낱말로
    /// 만드는 일은 없으므로 낱말 길이에서 끊는다.
    static let maxWholeLength = 8

    /// 통째로 고친 낱말이 이만큼은 흔해야 낸다.
    ///
    /// **문턱을 두지 않는다(0).** 같은 측정에서 바르게 친 190 개에는 어느 문턱에서도 한 번도
    /// 붙지 않았고, 문턱을 올리면 건지는 것만 줄었다.
    ///
    ///     문턱   건짐(472 중)   헛짚음
    ///     0      380            8
    ///     30     347            8
    ///     50     186            5
    ///     70     32             1
    ///
    /// 헛짚은 8 개도 소리는 맞았다 — `인야` → `いや`(정답 표기는 嫌), `쿤라스` → `クラス`
    /// (정답은 暮らす). 같은 소리의 어느 낱말이 1위인지는 주 순위의 몫이다.
    public static let wholeMinimumScore: Double = 0

    /// 나누기와 같은 찾기. 캐시를 함께 쓰면 고친 소리를 찾는 일도 치는 동안 한 번뿐이다.
    public static func lookup(in index: some DictionaryLookup,
                              frequency: FrequencyList? = nil,
                              weights: Ranker.Weights = Segmenter.defaultWeights,
                              cache: SearchCache? = nil) -> (String) -> [SearchResult] {
        let store = cache ?? SearchCache()
        return { piece in
            store.result(for: piece) {
                Ranker.search(piece, in: index, frequency: frequency, weights: weights)
            }
        }
    }

    /// 나눈 조각마다 곁들일 소리를 단다. 화면과 측정기가 같은 길을 쓴다.
    public static func attach(to segments: [Segment],
                              in index: some DictionaryLookup,
                              frequency: FrequencyList? = nil,
                              weights: Ranker.Weights = Segmenter.defaultWeights,
                              margin: Double = voicingMargin,
                              cache: SearchCache? = nil) -> [Segment] {
        let lookup = Self.lookup(in: index, frequency: frequency, weights: weights, cache: cache)
        return segments.map { segment in
            var copy = segment
            copy.soundAlikes = suggestions(for: segment, margin: margin, lookup: lookup)
            return copy
        }
    }

    /// 입력에서 `position` 번째 조각(통째 후보는 세지 않는다)을 다른 한글로 바꾼다.
    ///
    /// **사람이 친 띄어쓰기는 그대로 둔다.** 조각을 이어 붙여 입력을 다시 만들면
    /// 띄어 쓴 자리가 사라지고, 띄어쓰기는 사용자가 나누는 자리를 정한 것이라(`Segmenter`)
    /// 그 뜻까지 함께 지워진다. 그래서 입력을 글자 단위로 걸으며 그 조각의 자리만 바꾼다.
    public static func replacing(_ input: String, segments: [Segment],
                                 at position: Int, with hangul: String) -> String {
        let pieces = segments.filter { !$0.isWhole }
        guard pieces.indices.contains(position) else { return input }
        // 공백을 뺀 글자 기준으로 그 조각이 몇 번째 글자에서 시작하는가.
        let start = pieces[..<position].reduce(0) { $0 + $1.hangul.count }
        let length = pieces[position].hangul.count
        var out = ""
        var seen = 0
        var replaced = false
        for character in input {
            if character.isWhitespace { out.append(character); continue }
            if seen >= start && seen < start + length {
                if !replaced { out += hangul; replaced = true }
            } else {
                out.append(character)
            }
            seen += 1
        }
        return out
    }
}
