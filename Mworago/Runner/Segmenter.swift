import Foundation

/// 입력을 낱말 조각으로 나눈 결과 하나.
public struct Segment: Sendable {
    public let hangul: String            // 이 조각의 한글 음차
    public let results: [SearchResult]   // 이 조각을 찾아본 결과. 비어 있으면 사전에 없는 조각이다
}

/// 한글 음차 문장을 낱말 단위로 나눈다.
///
/// 일본어에는 띄어쓰기가 없다. 들은 대로 적는 사람은 `아타마가이타이`처럼 붙여 칠 것이다.
/// 그래서 어디서 끊을지를 **사전이 정하게 한다** — 나눈 조각이 실제 낱말인 분할이 이긴다.
///
/// 나누는 일 자체가 이미 문맥 판별이기도 하다.
/// ```
/// 아타마가이타이 → 頭 が 痛い
///                      ↑ 조사 が 뒤라면 痛い(형용사)지 遺体(명사)가 아니다
/// ```
public enum Segmenter {

    /// 조각 하나의 최대 길이(음절). 일본어 한 낱말이 이보다 길기는 드물고,
    /// 제한이 없으면 긴 입력에서 후보가 제곱으로 불어난다.
    private static let maxPieceLength = 10

    /// 사전에 없는 조각에 매기는 점수.
    ///
    /// 조각 비용보다 훨씬 커야 한다. 그러지 않으면 "나누느니 모르는 채로 두자"가 이겨서
    /// 입력 전체가 한 덩어리의 미지 조각이 된다. 길이와 무관하게 한 번만 깎는 것은,
    /// 정말 모르는 구간이라면 잘게 쪼개는 것보다 통째로 두는 편이 낫기 때문이다.
    private static let unknownScore = -500.0

    /// 조각 하나를 만들 때마다 무는 비용.
    ///
    /// 이것이 없으면 잘게 쪼갤수록 점수 합이 커진다. 조사(`が`·`だ`)는 어느 말뭉치에서나
    /// 최상위 빈도라, `다이죠부`가 `[다][이죠부]`로 갈리고도 점수에서 이겨 버린다.
    /// 낱말 수는 적을수록 낫다는 것을 값으로 넣어 주는 자리다.
    ///
    /// 다른 가중치들과 달리 이 값은 아직 손으로 정한 것이다. 문장 케이스가 없어
    /// 훑을 수가 없다. 문장 표본을 만들면 `--sweep`으로 넘겨야 한다.
    public static let defaultSegmentCost = 150.0

    public static func segment(_ input: String,
                               in index: DictIndex,
                               frequency: FrequencyList? = nil,
                               weights: Ranker.Weights = Ranker.Weights(),
                               segmentCost: Double = defaultSegmentCost) -> [Segment] {
        var segments: [Segment] = []
        // 사람이 띄어 썼다면 그 뜻을 존중한다. 어절 안쪽만 사전을 보고 나눈다.
        for word in input.split(whereSeparator: \.isWhitespace) {
            segments += segmentWord(String(word), in: index, frequency: frequency, weights: weights, segmentCost: segmentCost)
        }
        return segments
    }

    private static func segmentWord(_ word: String,
                                    in index: DictIndex,
                                    frequency: FrequencyList?,
                                    weights: Ranker.Weights,
                                    segmentCost: Double) -> [Segment] {
        let syllables = Array(word)
        guard !syllables.isEmpty else { return [] }

        var cache: [String: [SearchResult]] = [:]
        func lookup(_ piece: String) -> [SearchResult] {
            if let cached = cache[piece] { return cached }
            let found = Ranker.search(piece, in: index, frequency: frequency, weights: weights)
            cache[piece] = found
            return found
        }

        // best[i] = 앞에서부터 i음절까지를 나눈 최선의 방법
        var best: [(score: Double, start: Int)?] = Array(repeating: nil, count: syllables.count + 1)
        best[0] = (0, -1)

        for end in 1...syllables.count {
            for start in max(0, end - maxPieceLength)..<end {
                guard let previous = best[start] else { continue }
                let piece = String(syllables[start..<end])
                let results = lookup(piece)
                let score = (results.first?.score ?? unknownScore) - segmentCost
                let total = previous.score + score
                if best[end] == nil || total > best[end]!.score {
                    best[end] = (total, start)
                }
            }
        }

        // 뒤에서부터 되짚어 조각을 모은다
        var pieces: [String] = []
        var cursor = syllables.count
        while cursor > 0, let step = best[cursor] {
            pieces.append(String(syllables[step.start..<cursor]))
            cursor = step.start
        }
        return pieces.reversed().map { Segment(hangul: $0, results: lookup($0)) }
    }
}
