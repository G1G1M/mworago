import Foundation

/// 입력을 낱말 조각으로 나눈 결과 하나.
public struct Segment: Sendable {
    public let hangul: String            // 이 조각의 한글 음차
    public let results: [SearchResult]   // 이 조각을 찾아본 결과. 비어 있으면 사전에 없는 조각이다

    /// 첫 답 다음에 곁들일 후보들.
    ///
    /// 1위가 정답인 비율은 94%지만 3위 안에 있을 비율은 98%다. 그 4%를 사용자가 직접
    /// 고르게 하려고 대안을 곁에 둔다. 그러려면 대안이 **1위와 달라 보여야** 한다.
    ///
    /// **사전이 한 낱말로 실은 것은 한 낱말이다.** 같은 표제항이 여러 번 걸려 나오는 길은 둘이다 —
    /// 뜻갈래가 갈려 항목이 나뉘어 있거나(大丈夫는 형용동사와 명사로 두 번 실린다),
    /// 표제항 하나가 이표기를 달고 있거나(大丈夫 = だいじょうぶ · だいじょぶ).
    /// "다이죠부"는 두 읽기를 다 만들어 내므로 뒤쪽은 반드시 일어난다.
    /// 어느 쪽이든 화면에는 같은 낱말이 두 번 보일 뿐이다.
    ///
    /// 기준은 **화면에서 갈라 보이는가** 하나다. 표기가 다르면 그것으로 갈리고,
    /// 표기가 같아도 사전이 다른 낱말로 실었고 읽기까지 다르면 소리로 갈린다 —
    /// 机(つくえ)와 机(つき)가 그렇다. 그 밖에는 같은 답이 두 번 보이는 것뿐이다.
    public func alternates(limit: Int = 2) -> [SearchResult] {
        guard let top = results.first else { return [] }
        var picked: [SearchResult] = []
        for result in results.dropFirst() where picked.count < limit {
            guard !Self.sameWord(result, top),
                  !picked.contains(where: { Self.sameWord($0, result) })
            else { continue }
            picked.append(result)
        }
        return picked
    }

    /// 사용자 눈에 같은 낱말인가.
    ///
    /// 표기가 같은데 표제항까지 같다면 이표기다(大丈夫 = だいじょうぶ · だいじょぶ).
    /// 표제항이 달라도 읽기가 같다면 뜻갈래가 갈려 나뉜 것이다(大丈夫: 형용동사 / 명사).
    /// 둘 다 화면에는 똑같은 글자로 보인다.
    private static func sameWord(_ a: SearchResult, _ b: SearchResult) -> Bool {
        a.headword == b.headword && (a.entry == b.entry || a.reading == b.reading)
    }
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

    /// 사전에 없는 조각에 매기는 점수. **음절 하나당**이다.
    ///
    /// 조각 비용보다 커야 한다. 그러지 않으면 "나누느니 모르는 채로 두자"가 이겨서
    /// 입력 전체가 한 덩어리의 미지 조각이 된다.
    ///
    /// 길이에 비례시키는 것이 중요하다. 한 번만 깎던 때에는 그 벌점이 아는 낱말 하나
    /// 값보다 커서, `다이죠부뷁` 처럼 오타가 한 글자 붙은 입력이 통째로 미지가 됐다 —
    /// 大丈夫 까지 함께 사라진다. **오타 한 글자에 아는 낱말까지 잃으면 안 된다.**
    ///
    /// 비례로 바꿔도 "정말 모르는 구간은 통째로 둔다"는 그대로다. 잘게 쪼개면
    /// 벌점 합은 같은데 조각 비용만 더 들기 때문이다. 두 규칙이 서로를 붙잡는다.
    ///
    /// 값은 스윕이 골랐다(`--segment-sweep`). 한 번만 깎던 때의 -500 에서 -200 으로
    /// 옮겨간 것은 이제 길이가 곱해지기 때문이다.
    public static let defaultUnknownScore = -200.0

    /// 조각 하나를 만들 때마다 무는 비용.
    ///
    /// 이것이 없으면 잘게 쪼갤수록 점수 합이 커진다. 조사(`が`·`だ`)는 어느 말뭉치에서나
    /// 최상위 빈도라, `다이죠부`가 `[다][이죠부]`로 갈리고도 점수에서 이겨 버린다.
    /// 낱말 수는 적을수록 낫다는 것을 값으로 넣어 주는 자리다.
    ///
    /// Tanaka Corpus 문장 300개를 훑어 고른 값이다(`SpikeRunner --segment-sweep`).
    /// 곡선이 뚜렷하다 — 50이면 잘게 부수고(정밀도 0.50), 300이면 뭉뚱그린다(재현율 0.24).
    ///
    /// 활용형이 든 문장을 표본에서 빼고 쟀을 때는 120이 최적이었다. 활용형을 넣자
    /// 135로 옮겨 갔고 완전일치도 64%에서 43%로 떨어졌다. 쉬운 문장만 골라 재면
    /// 성적도 최적값도 함께 왜곡된다.
    ///
    /// **135 는 배포판이 쓰지 않는 빈도 목록(JPDB)으로 고른 값이었다.** 배포판이 싣는
    /// JESC 로 다시 훑으니 140 이었다. 자료가 다르면 최적값도 달라진다.
    public static let defaultSegmentCost = 140.0

    /// 분절이 쓰는 가중치. 낱말 검색과 한 가지가 다르다 — **활용을 되돌린 것에 무는 벌점**.
    ///
    /// 낱말 검색에서 이 벌점(25)은 타당하다. 사용자가 낱말 하나를 쳤다면 등재형일
    /// 공산이 크기 때문이다. 그런데 **문장 안에서는 활용형이 정상**이다. 그 벌점 때문에
    /// `카케타`(かけた)가 `카케`+`타` 로 갈렸다 — `た` 는 조동사로 어느 말뭉치에서나
    /// 최상위 빈도라 두 조각의 합이 활용형 하나를 이겨 버린다.
    /// 틀린 문장을 뽑아 보니 **실패의 76%가 이렇게 잘게 쪼갠 것**이었다.
    ///
    /// 5 가 가장 나았다(완전일치 27.7% → 34.0%, 조각 비용 140 과 함께). 0 이 아닌 것은
    /// 등재형이 있으면 그쪽을 먼저 보는 편이 여전히 낫기 때문이다(0 에서 33.0%).
    public static let defaultWeights: Ranker.Weights = {
        var weights = Ranker.Weights()
        weights.deinflectionPenalty = 5
        return weights
    }()

    public static func segment(_ input: String,
                               in index: some DictionaryLookup,
                               frequency: FrequencyList? = nil,
                               weights: Ranker.Weights = defaultWeights,
                               segmentCost: Double = defaultSegmentCost,
                               unknownScore: Double = defaultUnknownScore) -> [Segment] {
        var segments: [Segment] = []
        // 사람이 띄어 썼다면 그 뜻을 존중한다. 어절 안쪽만 사전을 보고 나눈다.
        for word in input.split(whereSeparator: \.isWhitespace) {
            segments += segmentWord(String(word), in: index, frequency: frequency,
                                    weights: weights, segmentCost: segmentCost, unknownScore: unknownScore)
        }
        return segments
    }

    private static func segmentWord(_ word: String,
                                    in index: some DictionaryLookup,
                                    frequency: FrequencyList?,
                                    weights: Ranker.Weights,
                                    segmentCost: Double,
                                    unknownScore: Double) -> [Segment] {
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
                // **모르는 조각은 길수록 나쁘다.** 길이와 무관하게 한 번만 깎으면
                // 아는 낱말 하나 값보다 벌점이 커서, 다이죠부뷁 처럼 오타가 한 글자 붙은 것이
                // 통째로 미지가 됐다 — 大丈夫 까지 함께 사라진다.
                //
                // 길이에 비례시켜도 "정말 모르는 구간은 통째로 둔다"는 그대로다.
                // 잘게 쪼개면 벌점 합은 같은데 조각 비용만 더 들기 때문이다.
                let piecePenalty = unknownScore * Double(end - start)
                let score = (results.first?.score ?? piecePenalty) - segmentCost
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
        let segments = pieces.reversed().map { Segment(hangul: $0, results: lookup($0)) }

        // **통째로도 사전에 실려 있으면 그것부터 낸다.**
        //
        // 관용구는 조각 점수 싸움에서 진다 — 조각이 다 흔한 낱말일수록 그렇다.
        // `잇테키마스` 는 `잇테`(行って)와 `키마스`(来ます)가 둘 다 최상위 빈도라
        // 나누는 쪽이 이겨서, 사전에 있는 `行ってきます`("다녀오겠습니다")가 묻혔다.
        // `잇테랏샤이` 가 살아남은 것은 `랏샤이` 가 실재하지 않아 쪼갤 수 없어서였을 뿐이다.
        //
        // 분절 가중치를 손대면 검색 전체가 흔들린다. 나눈 결과는 그대로 두고
        // 통째 뜻을 **앞에** 얹는다 — 어느 쪽이 맞는지는 보는 사람이 안다.
        guard segments.count > 1 else { return segments }
        let whole = lookup(word)
        return whole.isEmpty ? segments : [Segment(hangul: word, results: whole)] + segments
    }
}
