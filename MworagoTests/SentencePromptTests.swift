import Testing
@testable import MworagoCore

/// 문장 뜻을 모델에 물을 때 넘기는 재료.
///
/// 3B 온디바이스 모델에게 "이 일본어를 옮겨라"라고 맨몸으로 묻는 것과, 우리가 이미 아는 것을
/// 얹어 묻는 것은 다른 일이다. 낱말 뜻을 구울 때 품사를 안 알려 주면 `思う`(to think)가
/// "생각하다"가 아니라 "생각"으로 돌아왔다 — 문장에서도 같은 일이 일어난다.
///
/// 그래서 이 자리는 **모델에 무엇을 주는가**를 고정한다. 프롬프트가 흔들리면
/// 무엇 때문에 답이 바뀌었는지 영영 알 수 없다.
@Suite("문장 뜻을 묻는 재료")
struct SentencePromptTests {

    static func 결과(_ 표기: String, _ 읽기: String, 뜻: String,
                    품사: [String] = [], 표면: String? = nil, 되돌림: String? = nil) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: ["-"], koreanGloss: 뜻, partsOfSpeech: 품사)
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 표면 ?? 읽기,
                            deinflection: 되돌림, score: 0)
    }

    static func 조각(_ 한글: String, _ 결과들: [SearchResult], 통째: Bool = false) -> Segment {
        Segment(hangul: 한글, results: 결과들, isWhole: 통째)
    }

    /// 아타마가이타이 → 頭が痛い
    static let 문장: [Segment] = [
        조각("아타마", [결과("頭", "あたま", 뜻: "머리", 품사: ["n"])]),
        조각("가", [결과("が", "が", 뜻: "~이, ~가", 품사: ["prt"])]),
        조각("이타이", [결과("痛い", "いたい", 뜻: "아프다", 품사: ["adj-i"])]),
    ]

    @Test("낱말마다 표기·읽기·품사·뜻을 한 줄로 적는다")
    func 낱말줄() throws {
        let 재료 = try #require(SentencePrompt.materials(for: Self.문장))
        #expect(재료.contains("頭(あたま) · 명사 · 머리"))
        #expect(재료.contains("痛い(いたい) · 형용사 · 아프다"))
    }

    @Test("품사를 모르는 것은 품사 자리를 비운다")
    func 기능어() throws {
        // 조사에 품사 이름을 붙일 자리가 없다. 뜻 자리에 이미 **기능**이 적혀 있다.
        let 재료 = try #require(SentencePrompt.materials(for: Self.문장))
        #expect(재료.contains("が · ~이, ~가"))
    }

    @Test("표기가 없는 낱말은 읽기만 적는다")
    func 가나낱말() throws {
        // が(が) 처럼 같은 글자를 괄호에 한 번 더 적으면 재료가 아니라 잡음이다.
        let 재료 = try #require(SentencePrompt.materials(for: Self.문장))
        #expect(!재료.contains("が(が)"))
    }

    @Test("문장 전체가 재료 맨 위에 온다")
    func 문장머리() throws {
        // 낱말만 늘어놓으면 어순과 말투가 사라진다. 모델이 옮길 것은 결국 이 한 줄이다.
        let 재료 = try #require(SentencePrompt.materials(for: Self.문장))
        #expect(재료.contains("頭が痛い"))
        #expect(재료.contains("あたまがいたい"))
    }

    @Test("활용을 되돌린 조각은 표면형도 함께 적는다")
    func 활용() throws {
        // 사전형만 넘기면 시제와 말투가 통째로 사라진다 — 痛かった 를 "아프다"로 옮기게 된다.
        let 문장 = [
            Self.조각("아타마", [Self.결과("頭", "あたま", 뜻: "머리", 품사: ["n"])]),
            Self.조각("가", [Self.결과("が", "が", 뜻: "~이, ~가", 품사: ["prt"])]),
            Self.조각("이타캇타", [Self.결과("痛い", "いたい", 뜻: "아프다", 품사: ["adj-i"],
                                        표면: "いたかった", 되돌림: "과거형")]),
        ]
        let 재료 = try #require(SentencePrompt.materials(for: 문장))
        #expect(재료.contains("いたかった"))
        #expect(재료.contains("과거형"))
        #expect(재료.contains("痛い(いたい)"))
    }

    @Test("사전에 없는 조각은 한글 그대로 두고 모른다고 적는다")
    func 모르는조각() throws {
        // 여기서 지어내면 문장 전체가 조용히 틀어진다. 모른다는 것도 재료다.
        let 문장 = [
            Self.조각("아타마", [Self.결과("頭", "あたま", 뜻: "머리", 품사: ["n"])]),
            Self.조각("즈큰", []),
        ]
        let 재료 = try #require(SentencePrompt.materials(for: 문장))
        #expect(재료.contains("즈큰"))
        #expect(재료.contains("사전에 없다"))
    }

    @Test("통째로 찾은 것은 재료에서 뺀다")
    func 통째() throws {
        // 그것은 문장의 한 부분이 아니라 문장 전체를 한 번 더 적은 것이다.
        // 함께 넣으면 같은 말이 두 번 실린 재료가 된다.
        let 문장 = Self.문장 + [
            Self.조각("아타마가이타이",
                     [Self.결과("頭が痛い", "あたまがいたい", 뜻: "머리가 아프다")], 통째: true)
        ]
        let 재료 = try #require(SentencePrompt.materials(for: 문장))
        #expect(!재료.contains("머리가 아프다"))
    }

    @Test("뜻이 여럿이면 첫 것만 준다")
    func 첫뜻만() throws {
        // 늘어놓으면 모델이 아무거나 집는다. 彼 의 뜻을 "그, 남자친구" 로 줬더니
        // `彼は…しゃべらされた` 가 "남자친구는 그들에게 모두 대화했다" 로 돌아왔다.
        // 어느 뜻인지 고르는 일은 아직 우리가 못 하니, 사전이 먼저 적은 것을 준다.
        let 문장 = [
            Self.조각("카레", [Self.결과("彼", "かれ", 뜻: "그, 남자친구", 품사: ["pn"])]),
            Self.조각("와", [Self.결과("は", "は", 뜻: "~은, ~는", 품사: ["prt"])]),
        ]
        let 재료 = try #require(SentencePrompt.materials(for: 문장))
        #expect(재료.contains("彼(かれ) · 명사 · 그"))
        #expect(!재료.contains("남자친구"))
    }

    @Test("괄호에 든 부연은 뺀다")
    func 괄호() throws {
        // 한국어 뜻이 없는 낱말은 영어가 그대로 재료에 실린다. 그 안에 학명이 들어 있으면
        // 모델이 통째로 베낀다 — "나는 중간에 translucent 하게 나타난 red-berried elder
        // (Sambucus racemosa subsp. sieboldiana) 를 왔다" 가 실제로 돌아온 답이다.
        let 뜻없음 = SearchResult(
            entry: DictEntry(readings: [DictForm(text: "にわとこ", priority: 0)], writings: [],
                             glosses: ["red-berried elder (Sambucus racemosa subsp. sieboldiana)",
                                       "Japanese elderberry"]),
            reading: "にわとこ", matchedKana: "にわとこ", deinflection: nil, score: 0)
        let 문장 = [
            Self.조각("니와토코", [뜻없음]),
            Self.조각("가", [Self.결과("が", "が", 뜻: "~이, ~가", 품사: ["prt"])]),
        ]
        let 재료 = try #require(SentencePrompt.materials(for: 문장))
        #expect(재료.contains("red-berried elder"))
        #expect(!재료.contains("Sambucus"))
        #expect(!재료.contains("Japanese elderberry"))
    }

    @Test("조각이 하나뿐이면 물을 것이 없다")
    func 낱말하나() {
        // 낱말 하나는 카드에 뜬 뜻이 이미 답이다. 모델을 부를 이유가 없다.
        let 하나 = [Self.조각("아타마", [Self.결과("頭", "あたま", 뜻: "머리", 품사: ["n"])])]
        #expect(SentencePrompt.materials(for: 하나) == nil)
        #expect(SentencePrompt.materials(for: Self.문장) != nil)
    }
}
