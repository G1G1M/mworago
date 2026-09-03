import Foundation
import MworagoDomain

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
        /// JMdict 빈도 태그에 실어 줄 무게. 이쪽은 신문 말뭉치 기준이라 애니에서는 잡음이다.
        /// **도메인 빈도가 아무 말도 하지 않을 때만** 쓰이므로 0 이 아니다 —
        /// 스윕에서 1 일 때 분절 완전일치가 30.3%에서 32.3%로 올랐고, 3 이면 20.7%,
        /// 8 이면 10.0% 로 무너진다. 거들기만 해야지 도메인을 덮으면 안 된다.
        public var jmdictWeight: Double

        /// 기본값은 손으로 정한 것이 아니라 케이스 50개를 훑어 고른 값이다
        /// (`SpikeRunner --sweep`). 케이스가 늘면 다시 훑어야 한다.
        ///
        /// `jmdictWeight`가 0인 것이 이 스윕의 결론이다. JMdict의 빈도 태그는 신문 말뭉치
        /// 기준이라 애니 대사에서는 **잡음이다.** 케이스 50개에서도 150개에서도 상위 조합이
        /// 예외 없이 0을 골랐다.
        ///
        /// 다만 도메인 빈도 목록이 없으면 `search`가 이 값을 1로 되돌린다. 그때는 신문 빈도라도
        /// 있는 편이 아무 신호도 없는 것보다 낫다.
        ///
        /// `deinflectionPenalty`는 빈도 목록이 있는 한 등재형이 어차피 이긴다 —
        /// `疲れた`가 `疲れる`의 빈도를 물려받아 동점이 되고, 되돌리지 않은 쪽이 페널티가 없다.
        /// 그래서 값이 클 필요가 없고, JESC 기준 스윕은 25를 골랐다.
        ///
        /// 빈도 목록이 바뀌면 최적 가중치도 함께 움직인다. JESC(자막)로 바꿔 훑었을 때는
        /// 장음 6→0, 후보 순서 0→5로 옮겨 갔다. 지금 기준선은 JPDB 쪽 값이다.
        public init(rankPenalty: Double = 0,
                    longVowelPenalty: Double = 6,
                    deinflectionPenalty: Double = 25,
                    domainWeight: Double = 1,
                    jmdictWeight: Double = 1) {
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

        // 실제로 쓰이는 한자 표기가 없거나, 사전이 "보통 가나로 쓴다"(uk)고 말하면
        // 가나 빈도로 재야 한다. 아무도 안 쓰는 한자 표기의 빈도로 재면
        // 止める(やめる)가 16601위, の(조사)가 0점이 되어 버린다.
        var best = 0.0
        if entry.usableWritings.isEmpty || entry.usuallyKana {
            best = readingForms.map { list.score(writing: nil, reading: $0.form) }.max() ?? 0
            if entry.usableWritings.isEmpty { return best }
        }

        for writing in entry.usableWritings {
            for writingForm in Deinflector.candidates(for: writing.text) {
                // 표기와 읽기를 같은 활용 규칙으로 되돌린 짝만 맞춰 본다
                for readingForm in readingForms where readingForm.rule == writingForm.rule {
                    best = max(best, list.score(writing: writingForm.form, reading: readingForm.form))
                }
            }
        }

        // **짝이 없으면 표기만으로 찾은 점수라도 쓴다.**
        //
        // 빈도를 센 쪽이 `何時` 를 `いつ`(368회)와 `なんどき`(100회)로만 세었다.
        // `なんじ` 항목이 없어서 何時(なんじ)가 0점이 되고, 목록에 실린 고어
        // 汝(なんじ)가 43점으로 이겼다 — "이마난지데스카"가 "지금 당신입니까"로 나왔다.
        //
        // **이 판단은 여기서만 할 수 있다.** 빈도 목록은 그 읽기가 정말 그 낱말의 읽기인지
        // 모르지만, 우리는 사전 항목을 손에 쥐고 있다. 사전이 `なんじ` 를 何時 의 읽기로
        // 싣고 있으니, 何時 가 흔하다는 사실을 이 항목이 물려받아도 된다.
        //
        // 그래도 **정확히 짝이 맞은 것보다는 낮다.** 빈도가 세지 않은 읽기라는 것은
        // 그 읽기가 덜 쓰인다는 뜻이기도 하다.
        if best == 0 {
            // **사전이 흔하다고 표시한 읽기에는 벌점을 물리지 않는다.**
            //
            // 벌점의 근거는 "말뭉치가 이 읽기를 안 셌다면 덜 쓰이는 읽기일 것"이다.
            // 그런데 안 센 것이 아니라 **다른 이름으로 센** 자리가 있다 —
            // 자막 말뭉치는 `私` 를 `わたくし`(19위·148,210회)로만 싣고 `わたし` 항목을
            // 두지 않았다. 그 바람에 `私` 가 56.6점으로 깎여 `渡し`(도선, 1103위·1,622회)
            // 의 59.1점에 졌고, `와타시와칸코쿠진데쓰` 가 `渡しは韓国人です` 로 되살아나
            // "전달은 한국인입니다"가 되었다. **91배 흔한 낱말이 규칙에 져서 밀렸다.**
            //
            // 사전은 이 사실을 이미 알고 있다. JMdict 가 `私` 의 표기와 `わたし` 읽기에
            // 둘 다 우선 표시를 달아 두었다. 말뭉치가 이름을 잘못 붙였을 뿐 흔한 읽기라는
            // 것은 사전이 보증하므로, 그때는 물려받은 점수를 깎지 않는다.
            //
            // 사전이 아무 표시도 안 단 읽기는 벌점을 그대로 문다 — 그쪽은 원래 근거가
            // 살아 있다(`何時` 의 `なんじ` 처럼).
            let forms = Set(readingForms.map(\.form))
            let dictionaryCallsItCommon = entry.readings.contains {
                forms.contains($0.text) && $0.priority > 0
            }
            let weight = dictionaryCallsItCommon ? 1.0 : Self.writingOnlyWeight
            for writing in entry.usableWritings {
                best = max(best, list.scoreByWriting(writing.text) * weight)
            }
        }
        return best
    }

    /// 표기만으로 물려받은 점수에 실어 줄 무게. 값은 재서 골랐다.
    static let writingOnlyWeight = 0.6

    /// 일상에서 쓰지 않는 말에 매길 벌점.
    ///
    /// **사전이 이미 알려 준 사실인데 듣지 않고 있었다.** 사용역 태그를 읽어 두기만 하고
    /// 순위에는 쓰지 않아서, 애니 자막에 흔한 고어·시어가 현대어를 밀어냈다 —
    /// `なんじ` 에서 시어 `汝`(그대)가 `何時`(몇 시)를 눌러 "이마난지데스카"가
    /// "지금 당신입니까"로 나왔다.
    ///
    /// **모든 꼬리표를 깎지는 않는다.** 존경어·겸양어·구어는 일상에서 쓰는 말이고,
    /// 애니를 보다 찾아온 사람에게는 오히려 그쪽이 답이다. 옛말과 시어만 깎는다.
    static let datedTags: Set<String> = ["arch", "obs", "poet"]
    static let datedPenalty = 25.0

    public static func search(_ hangul: String,
                              in index: some DictionaryLookup,
                              frequency: FrequencyList? = nil,
                              weights: Weights = Weights()) -> [SearchResult] {
        var results: [SearchResult] = []

        // 도메인 빈도가 없으면 JMdict 점수라도 써야 한다. 그러지 않으면 모두 0점이 되어
        // 후보 순서만으로 줄을 세우게 된다.
        let jmdictWeight = frequency == nil ? max(weights.jmdictWeight, 1) : weights.jmdictWeight

        for candidate in Transliterator.candidates(for: hangul) {
            for deinflection in Deinflector.candidates(for: candidate.kana) {
                for hit in index.lookup(deinflection.form) {
                    // **명사는 활용하지 않는다.**
                    //
                    // 활용을 되돌려 찾은 것이 명사로 걸리면 그것은 뜻이 맞은 것이 아니라
                    // **글자가 우연히 맞은 것**이다. `도코에`(どこへ, 어디로)가
                    // `同校`(どうこう, 같은 학교)로 나왔다 — 어미 `え` 를 5단 명령형으로
                    // 보고 되돌리니 `どうこう` 가 되었고, 거기에 명사 `同校` 가 걸렸다.
                    // 명사에 명령형이 붙을 리 없는데 사전이 그렇게 말한 적도 없다.
                    //
                    // `勉強` 처럼 `n·vs`(する가 붙는 명사)는 이 검사에 걸리지 않는다 —
                    // `벤쿄시타` 는 `勉強` + `する` 로 갈라져 명사 쪽에는 활용이 안 붙는다.
                    if deinflection.rule != nil, hit.entry.wordClass == .noun { continue }
                    // **도메인 빈도가 아무 말도 하지 않을 때만 JMdict 를 듣는다.**
                    //
                    // 신문 빈도는 애니에서 잡음이라 스윕이 늘 jmdictWeight 0 을 골랐다.
                    // 그런데 그 0 이 도메인 목록에 **없는** 낱말까지 0점으로 만들었다 —
                    // 사전이 아는 낱말인데도. 배포판이 쓸 JESC 는 Tanaka 정답 낱말의
                    // 75.1% 만 담고 있어서(JPDB 는 86.6%), 나머지 넷 중 하나가 통째로
                    // 말이 없어진다. 분절은 문장의 모든 낱말을 찾아야 하므로 여기서 진다.
                    //
                    // 도메인 점수가 있으면 그것만 쓰고, 없을 때만 JMdict 로 메운다.
                    // "신문 빈도가 잡음"이라는 판단은 도메인 빈도가 말을 할 때의 이야기다.
                    var score = 0.0
                    let domain = frequency.map { domainScore(hit.entry, reading: hit.reading, in: $0) } ?? 0
                    if domain > 0, weights.domainWeight != 0 {
                        score += weights.domainWeight * domain
                    } else {
                        score += jmdictWeight * Double(hit.priority)
                    }
                    // 옛말·시어는 사전이 그렇게 적어 두었다. 애니에 흔하다고 현대어를
                    // 밀어내면 안 된다 — 빈도는 "얼마나 나오는가"만 알고 "지금 쓰는 말인가"는 모른다.
                    if hit.entry.usageTags.contains(where: Self.datedTags.contains) {
                        score -= Self.datedPenalty
                    }
                    score -= weights.rankPenalty * Double(candidate.rank)
                    score -= weights.longVowelPenalty * Double(candidate.longVowelsAdded)
                    // 촉음을 지어낸 것은 장음보다 과감한 추측이라 더 깎는다.
                    // 사용자가 **적지 않은 소리**를 넣는 것이어서, 지어낸 쪽이 더 흔한
                    // 낱말이면 제대로 친 답을 밀어낸다.
                    score -= weights.longVowelPenalty * 3 * Double(candidate.geminatesAdded)
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
