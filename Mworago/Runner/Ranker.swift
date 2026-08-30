import Foundation

/// 검색 결과 한 건.
public struct SearchResult: Sendable {
    public let entry: DictEntry
    public let reading: String        // 사전에서 찾은 읽기
    public let matchedKana: String    // 규칙이 만들어 낸 가나 후보
    public let deinflection: String?  // 활용을 되돌렸다면 그 이름 ("명령형" 등)
    public let score: Double

    public var headword: String { entry.headword }
}

/// 살아남은 후보들을 줄 세운다.
///
/// M0 측정에서 드러난 사실: 규칙과 사전은 **찾아내는 데는** 성공했다(재현율 100%).
/// 틀린 답이 나온 경우도 정답은 후보 안에 있었고, 순위에서 밀렸을 뿐이다.
/// 그래서 이 파일이 정확도를 좌우한다.
///
/// 점수는 사전 빈도에서 출발해, **추측이 과감할수록 깎는다.**
/// 한글에 없던 글자를 지어냈거나(장음), 활용을 되돌렸다면 그만큼 덜 확실한 답이다.
public enum Ranker {

    public struct Weights: Sendable, Equatable {
        /// 규칙이 낸 순서. 뒤에 나온 후보일수록 조금씩 깎는다
        public var rankPenalty: Double
        /// 한글에 없던 장음을 하나 지어낼 때마다 깎는 값
        public var longVowelPenalty: Double
        /// 활용을 되돌려 찾았을 때 깎는 값. 사전에 그대로 실린 형태를 우선하기 위한 것
        public var deinflectionPenalty: Double

        /// 기본값은 손으로 정한 것이 아니라 케이스 50개를 훑어 고른 값이다
        /// (`SpikeRunner --sweep`). 케이스가 늘면 다시 훑어야 한다.
        public init(rankPenalty: Double = 0,
                    longVowelPenalty: Double = 6,
                    deinflectionPenalty: Double = 60) {
            self.rankPenalty = rankPenalty
            self.longVowelPenalty = longVowelPenalty
            self.deinflectionPenalty = deinflectionPenalty
        }
    }

    public static func search(_ hangul: String,
                              in index: DictIndex,
                              weights: Weights = Weights()) -> [SearchResult] {
        var results: [SearchResult] = []

        for candidate in Transliterator.candidates(for: hangul) {
            for deinflection in Deinflector.candidates(for: candidate.kana) {
                for hit in index.lookup(deinflection.form) {
                    var score = Double(hit.priority)
                    score -= weights.rankPenalty * Double(candidate.rank)
                    score -= weights.longVowelPenalty * Double(candidate.longVowelsAdded)
                    if deinflection.rule != nil { score -= weights.deinflectionPenalty }

                    results.append(SearchResult(entry: hit.entry,
                                                reading: hit.reading,
                                                matchedKana: candidate.kana,
                                                deinflection: deinflection.rule,
                                                score: score))
                }
            }
        }

        // 점수가 같으면 규칙이 먼저 낸 쪽이 앞. 정렬이 실행마다 뒤바뀌지 않도록 한다.
        results.sort {
            $0.score != $1.score ? $0.score > $1.score : $0.matchedKana.count < $1.matchedKana.count
        }
        return results
    }
}
