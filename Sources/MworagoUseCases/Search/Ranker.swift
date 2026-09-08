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

    /// 가나 옆 괄호에 넣을 한자. 가나로만 쓰는 낱말이면 nil.
    ///
    /// **문장에 적을 글자와는 규칙이 다르다.** `Segment.japanese` 는 사전이 `uk`
    /// (보통 가나로 씀)라고 한 낱말의 한자를 꺼내지 않는다 — 자막도 그렇게 쓰기 때문이다.
    /// 괄호는 적는 자리가 아니라 **가리키는 자리**라 그 규칙을 따르지 않는다.
    /// `なる` 로는 成る(되다)와 生る(열매 맺다)가 갈리지 않고, 소리로 찾아온 사람에게
    /// 어느 것인지 말해 주는 것이 이 괄호가 있는 까닭이다.
    ///
    /// 드문 표기(`rK`·`sK`)는 `entry.headword` 가 이미 빼고 준다 — `する` 의 `為る` 는
    /// 사전에 실려 있을 뿐 그렇게 적는 사람이 없다.
    public var kanji: String? {
        let writing = headword
        return writing.isEmpty || writing == reading ? nil : writing
    }
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
        /// **가나 빈도를 물려받은 낱말끼리의 동점만 가르는 무게.**
        ///
        /// `なる` 한 줄(100위·28,341회)을 `成る`(되다)와 `生る`(열매 맺다)가 똑같이
        /// 물려받아 80.0 대 80.0 이었다. 동점의 순서에는 뜻이 없어서 `生る` 가 먼저
        /// 나왔다. 말뭉치가 **한자로 적은 적이 있는 쪽**을 앞에 두어 가른다.
        ///
        /// 물려받은 점수(80점대)를 덮으면 안 되므로 아주 작아야 한다.
        /// **손으로 정하지 않는다** — `SpikeRunner --identity-sweep` 이 고른다.
        ///
        /// 2026-09-07 스윕(케이스 150 · 분절 300):
        ///
        ///     무게     낱말1위   3위안   분절완전  경계F1  조각1위
        ///     0        137/150  145/150   51.0%   0.911   93.1%
        ///     0.001    136/150  145/150   51.7%   0.911   92.8%
        ///     0.005    136/150  145/150   52.0%   0.911   92.8%   ← 골랐다
        ///     0.01     136/150  145/150   51.7%   0.909   92.9%
        ///     0.03     136/150  145/150   49.3%   0.903   93.2%
        ///     0.1      136/150  145/150   43.3%   0.893   92.1%
        ///     0.3      136/150  144/150   18.0%   0.801   91.1%
        ///     1        129/150  143/150    0.7%   0.615   75.0%
        ///
        /// **0.005 는 0.01 을 모든 축에서 이기거나 비긴다.** 0 과는 맞바꿈이 있는데
        /// (낱말 1위 하나를 잃고 분절 세 문장을 얻는다), **분절이 번역 품질의 천장**이라
        /// 그쪽을 산다. 잃는 하나는 `이야` 다 — `嫌` 이 `いや` 에 밀린다.
        ///
        /// 0.1 을 넘어가면 무너진다. 물려받은 빈도 점수(80점대)를 이 항이 덮기 시작해서,
        /// 동점을 가르는 일이 아니라 순위를 다시 매기는 일이 되기 때문이다.
        public var kanaIdentityWeight: Double

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
        /// 빈도 목록이 바뀌면 최적 가중치도 함께 움직인다. 한때 "JESC 로 훑으면 장음이
        /// 6→0 으로 옮겨 간다"고 적혀 있었는데, **배포판 자료로 다시 훑으니 6 이 맞다.**
        /// 그 사이에 규칙이 여럿 바뀌었다(JMdict 층 · 조사 경계 보너스 · `uk` 가나 줄).
        /// 규칙을 넣었으면 그 규칙이 바꾼 축을 다시 훑는다 — 예전에 고른 값이 새 규칙
        /// 아래서도 최선이라는 보장이 없고, **그 반대도 마찬가지다.**
        ///
        /// 2026-09-08 스윕(`--longvowel` · 케이스 150 · 분절 300 · JESC):
        ///
        ///     장음   낱말1위   3위안    분절틀림   경계조각   조각1위
        ///     0      134/150  146/150  161/300    732       92.9%
        ///     1      134/150  146/150  161/300    732       93.4%
        ///     2      135/150  146/150  161/300    735       93.7%
        ///     3      136/150  146/150  160/300    743       93.8%
        ///     4      136/150  147/150  160/300    743       93.8%
        ///     6      137/150  147/150  159/300    749       93.2%   ← 그대로 둔다
        ///     8      136/150  147/150  159/300    749       92.7%
        ///
        /// **내리면 두 축에서 다 잃는다.** `코훈` 이 `古墳`(고분)이 아니라 `興奮`(흥분)으로
        /// 나오려면 0 이어야 하는데, 그러면 낱말이 137 → 134 로 떨어진다. 한자어의 장음을
        /// 살리는 값과 지어낸 소리를 누르는 값이 **같은 손잡이에 매여 있다** — 그 자리는
        /// 손잡이를 하나 더 두어야 풀린다(지어낸 장음과 한자어의 장음을 갈라야 한다).
        public init(rankPenalty: Double = 0,
                    longVowelPenalty: Double = 6,
                    deinflectionPenalty: Double = 25,
                    domainWeight: Double = 1,
                    jmdictWeight: Double = 1,
                    kanaIdentityWeight: Double = 0.005) {
            self.rankPenalty = rankPenalty
            self.longVowelPenalty = longVowelPenalty
            self.deinflectionPenalty = deinflectionPenalty
            self.domainWeight = domainWeight
            self.jmdictWeight = jmdictWeight
            self.kanaIdentityWeight = kanaIdentityWeight
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
    static func domainScore(_ entry: DictEntry, reading: String, in list: FrequencyList,
                            identityWeight: Double = 0.01) -> Double {
        // **명사와 부사는 빈도도 활용해서 물려받지 않는다.**
        //
        // `쿠로` 를 치면 `畦`(논두렁)가 `黒`(검정) 위에 섰다. `畦` 는 `uk` 라 가나 빈도로
        // 재는데, 그 읽기 `くろ` 를 한 번 더 되돌려 `くる` 를 만들고 말뭉치의
        // `くる`(333위·7,381회 — 「오다」다)를 물려받았다. 69.6 대 51.8 이었다.
        //
        // `search` 는 이미 같은 규칙을 지키고 있었다(`WordClass.inflects`). 그런데
        // 조회만 막고 **점수는 활용형에서 가져오게 두어**, 사전이 한 적 없는 말을
        // 점수만 듣고 있었다. 규칙이 한 자리에만 있으면 다른 자리로 새어 나간다.
        let readingForms = Deinflector.candidates(for: reading)
            .filter { entry.wordClass.inflects || $0.rule == nil }

        // 실제로 쓰이는 한자 표기가 없거나, 사전이 "보통 가나로 쓴다"(uk)고 말하면
        // 가나 빈도로 재야 한다. 아무도 안 쓰는 한자 표기의 빈도로 재면
        // 止める(やめる)가 16601위, の(조사)가 0점이 되어 버린다.
        var best = 0.0
        if entry.usableWritings.isEmpty || entry.usuallyKana {
            best = readingForms.map { list.score(writing: nil, reading: $0.form) }.max() ?? 0

            // **가나 줄을 통째로 가져가면 안 되는 낱말이 있다.**
            //
            // `쿠세` 를 치면 `曲`(노가쿠의 한 대목)이 `癖`(버릇) 위에 섰다. 말뭉치의
            // 가나 줄 `くせ`(1,966위·1,104회)는 사람들이 `癖` 를 가나로 적은 것인데,
            // `曲` 이 `uk` 라 그 줄을 그대로 물려받아 54.4 가 되고 제 한자 줄로 재는
            // `癖`(6,612위)는 43.6 에 머물렀다.
            //
            // **말뭉치는 못 가르지만 사전은 이미 갈라 두었다.** JMdict 가 `癖` 의
            // `くせ` 읽기에 우선 표시를 달았고(47) `曲` 의 `くせ` 에는 안 달았다(0).
            // 표시가 없는 읽기가 가나 줄을 가져갈 때는 깎는다 — 표기만으로 물려받은
            // 점수를 깎는 아래 규칙과 같은 잣대다(`何時` 의 `なんじ`).
            //
            // **표기가 없는 낱말은 안 깎는다.** 가나가 곧 제 꼴이라 그 줄이 제 것이고,
            // 깎으면 기댈 곳이 아예 없어진다.
            if !entry.usableWritings.isEmpty, !Self.dictionaryCallsItCommon(entry, readingForms) {
                best *= Self.unmarkedKanaWeight
            }

            // **가나 빈도를 물려받는 낱말이 여럿이면 동점이 된다.**
            //
            // `なる` 는 말뭉치에 100위(28,341회)로 실려 있는데, 그 한 줄을 `成る`(되다)와
            // `生る`(열매 맺다)가 **똑같이** 물려받아 둘 다 80.0 이었다. 동점의 순서는
            // 뜻이 없으므로 `生る` 가 먼저 나왔고, `나루` 를 친 사람이 "열매 맺다"를 봤다.
            //
            // 말뭉치가 이미 답을 알고 있다. **한자로 적은 적이 있는 쪽**이 그 낱말이다 —
            // `成る` 는 13,983위로 따로 실려 있고 `生る` 는 목록에 아예 없다.
            // 가나로 쓰는 낱말이라도 어쩌다 한자로 적힌 자리가 있고, 그 자리가 신원을 말한다.
            //
            // **동점을 가르는 데만 쓴다.** 물려받은 점수를 덮으면 안 되므로 아주 작게 얹는다
            // — 순위가 뒤집히는 것은 앞의 층이 아무 말도 하지 않을 때뿐이다.
            // **표기가 없는 낱말은 가나가 곧 제 꼴이다.** `して`(조사)와 `仕手`(주식 용어)가
            // 둘 다 `して` 빈도(23위·126,257회)를 물려받아 92.8 로 동점이었는데,
            // 말뭉치는 `して` 를 12만 번 적었고 `仕手` 는 **한 번도 안 적었다.**
            // 제 꼴로 재면 그 차이가 드러난다.
            let forms = entry.usableWritings.isEmpty
                ? readingForms.map(\.form)
                : entry.usableWritings.map(\.text)
            let identity = forms.map { list.scoreByWriting($0) }.max() ?? 0
            best += identity * identityWeight
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
            let weight = Self.dictionaryCallsItCommon(entry, readingForms)
                       ? 1.0 : Self.writingOnlyWeight
            for writing in entry.usableWritings {
                best = max(best, list.scoreByWriting(writing.text) * weight)
            }
        }
        return best
    }

    /// 표기만으로 물려받은 점수에 실어 줄 무게. 값은 재서 골랐다.
    static let writingOnlyWeight = 0.6

    /// **사전이 이 읽기를 흔하다고 표시했는가.**
    ///
    /// 물려받은 점수를 깎을지 정하는 두 자리가 같은 물음을 쓴다 — 가나 줄을
    /// 물려받는 `uk` 낱말과, 짝이 없어 표기만으로 물려받는 낱말. 근거가 같으니
    /// 묻는 자리도 하나여야 한다.
    static func dictionaryCallsItCommon(_ entry: DictEntry,
                                        _ readingForms: [Deinflection]) -> Bool {
        let forms = Set(readingForms.map(\.form))
        return entry.readings.contains { forms.contains($0.text) && $0.priority > 0 }
    }

    /// 사전이 표시하지 않은 읽기가 **가나 빈도 줄**을 물려받을 때의 무게.
    ///
    /// **손으로 정하지 않았다.** 낱말 150개로는 0.8 아래가 전부 같아서(137/150 ·
    /// 147/150) 못 고른다 — 이 규칙이 갈라야 할 자리가 그 표본에 하나뿐이라서다.
    /// 분절 300개가 갈라 준다(같은 문장 위에서 상수만 바꾼 값이라 흔들림이 없다):
    ///
    ///     무게   틀린 것   경계를 맞힌 조각   조각 1위
    ///     1.0    160/300   741               93.1%
    ///     0.8    159/300   749               93.2%
    ///     0.6    159/300   749               93.2%   ← 골랐다
    ///     0.4    160/300   743               93.1%
    ///     0.2    160/300   743               93.1%
    ///     0.0    160/300   743               93.1%
    ///
    /// **깎되 지우지는 않는다.** 0.4 아래로 내리면 도로 나빠진다 — 표시가 없다고
    /// 가나 줄을 통째로 버리면, 정말 그 줄이 제 것인 낱말까지 기댈 데를 잃는다.
    /// 0.8 과 비긴다. `writingOnlyWeight` 와 같은 값을 쓴다 — 근거가 같은 규칙이다.
    static let unmarkedKanaWeight = 0.6


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
                    // **명사와 부사는 활용하지 않는다.**
                    //
                    // 활용을 되돌려 찾은 것이 명사로 걸리면 그것은 뜻이 맞은 것이 아니라
                    // **글자가 우연히 맞은 것**이다. `도코에`(どこへ, 어디로)가
                    // `同校`(どうこう, 같은 학교)로 나왔다 — 어미 `え` 를 5단 명령형으로
                    // 보고 되돌리니 `どうこう` 가 되었고, 거기에 명사 `同校` 가 걸렸다.
                    // 명사에 명령형이 붙을 리 없는데 사전이 그렇게 말한 적도 없다.
                    //
                    // **부사를 빼먹었더니 같은 자리가 다시 열렸다.** 명사를 막자
                    // `도코에` 가 이번에는 `如何斯う`(どうこう, 이러쿵저러쿵)로 나왔다 —
                    // 같은 가나에 걸린 부사 항목이다. 부사도 활용하지 않는다.
                    //
                    // `勉強` 처럼 `n·vs`(する가 붙는 명사)는 이 검사에 걸리지 않는다 —
                    // `벤쿄시타` 는 `勉強` + `する` 로 갈라져 명사 쪽에는 활용이 안 붙는다.
                    if deinflection.rule != nil, !hit.entry.wordClass.inflects { continue }
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
                    let domain = frequency.map {
                        domainScore(hit.entry, reading: hit.reading, in: $0,
                                    identityWeight: weights.kanaIdentityWeight)
                    } ?? 0
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
