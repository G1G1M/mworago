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
        /// 도메인(애니) 빈도에 실어 줄 무게. 0이면 그 층을 쓰지 않는다
        public var domainWeight: Double
        /// JMdict 빈도 태그에 실어 줄 무게. 이쪽은 신문 말뭉치 기준이다
        public var jmdictWeight: Double

        /// 기본값은 손으로 정한 것이 아니라 케이스 50개를 훑어 고른 값이다
        /// (`SpikeRunner --sweep`). 케이스가 늘면 다시 훑어야 한다.
        ///
        /// `jmdictWeight`가 0.3까지 내려간 것이 이 스윕의 결론이다. JMdict의 빈도 태그는
        /// 신문 말뭉치 기준이라 애니 대사에서는 **잡음에 가깝다.** 완전히 0으로 두어도
        /// 성적은 같지만, 도메인 목록에 없는 낱말들끼리의 순서는 여전히 이쪽이 정해준다.
        public init(rankPenalty: Double = 0,
                    longVowelPenalty: Double = 6,
                    deinflectionPenalty: Double = 25,
                    domainWeight: Double = 1,
                    jmdictWeight: Double = 0.3) {
            self.rankPenalty = rankPenalty
            self.longVowelPenalty = longVowelPenalty
            self.deinflectionPenalty = deinflectionPenalty
            self.domainWeight = domainWeight
            self.jmdictWeight = jmdictWeight
        }
    }

    /// 표제항 하나의 도메인 빈도 점수.
    ///
    /// 표기가 있는 낱말은 **표기로만** 찾는다. 읽기만으로 찾으면 같은 소리를 내는 모든 항목이
    /// 같은 점수를 받아, 정작 갈라야 할 동음이의어를 못 가른다.
    ///
    /// 빈도 목록에는 사전형만 실린다. 그래서 사전에 활용형으로 실린 표제항
    /// (`疲れた`·`助けて`)은 그대로 찾으면 0점이 되고, 같은 낱말의 사전형(`疲れる`)에게
    /// 진다. 같은 낱말이 활용됐다는 이유만으로 지는 것은 부당하므로,
    /// **표기와 읽기를 같은 규칙으로 함께 되돌려** 사전형의 빈도를 물려받게 한다.
    static func domainScore(_ entry: DictEntry, reading: String, in list: FrequencyList) -> Double {
        let readingForms = Deinflector.candidates(for: reading)

        guard !entry.writings.isEmpty else {
            return readingForms.map { list.score(writing: nil, reading: $0.form) }.max() ?? 0
        }

        var best = 0.0
        for writing in entry.writings {
            for writingForm in Deinflector.candidates(for: writing.text) {
                // 표기와 읽기를 같은 활용 규칙으로 되돌린 짝만 맞춰 본다
                for readingForm in readingForms where readingForm.rule == writingForm.rule {
                    best = max(best, list.score(writing: writingForm.form, reading: readingForm.form))
                }
            }
        }
        return best
    }

    public static func search(_ hangul: String,
                              in index: DictIndex,
                              frequency: FrequencyList? = nil,
                              weights: Weights = Weights()) -> [SearchResult] {
        var results: [SearchResult] = []

        for candidate in Transliterator.candidates(for: hangul) {
            for deinflection in Deinflector.candidates(for: candidate.kana) {
                for hit in index.lookup(deinflection.form) {
                    var score = weights.jmdictWeight * Double(hit.priority)
                    if let frequency, weights.domainWeight != 0 {
                        score += weights.domainWeight * domainScore(hit.entry, reading: hit.reading, in: frequency)
                    }
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
