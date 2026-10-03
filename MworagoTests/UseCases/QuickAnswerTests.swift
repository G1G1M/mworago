import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 앱을 열지 않고 내놓는 짧은 답.
///
/// 동작 버튼 · Siri · 단축어로 찾으면 결과는 작은 창 하나에 담긴다. 거기서 원하는 것은
/// **뜻 한 줄**이다 — 낱말을 하나씩 뜯어보는 것은 앱을 열어서 할 일이다. 그래서 답은
/// 번역할 원문과, 번역기를 부르지 않아도 되는 뜻(사전이 이미 아는 것)을 고른다.
@Suite("짧은 답")
struct QuickAnswerTests {

    static func 조각(_ 표기: String, _ 읽기: String, 뜻: String = "meaning",
                   korean: String? = nil, whole: Bool = false) -> Segment {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: [뜻], koreanGloss: korean)
        let result = SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                                  deinflection: nil, score: 0)
        return Segment(hangul: "x", results: [result], isWhole: whole)
    }

    @Test("문장이면 가나 원문을 싣고 번역기에 넘길 원문을 준다")
    func 문장() {
        let answer = QuickAnswer(typed: "아타마가이타이", segments: [
            Self.조각("頭", "あたま", korean: "머리"),
            Self.조각("が", "が", korean: "이·가"),
            Self.조각("痛い", "いたい", korean: "아프다"),
        ])
        #expect(answer.kana == "あたまがいたい")
        #expect(answer.knownMeaning == nil)
        // 번역기에는 한자를 살려서 준다 — 가나만 이어지면 번역기도 낱말을 못 가른다.
        #expect(answer.forTranslation == "頭が痛い")
        #expect(!answer.isEmpty)
    }

    @Test("통째로 잡힌 뜻이 있으면 번역기를 부르지 않는다")
    func 통째() {
        let answer = QuickAnswer(typed: "콘니치와", segments: [
            Self.조각("今日は", "こんにちは", korean: "안녕하세요", whole: true),
            Self.조각("今日", "こんにち", korean: "오늘"),
            Self.조각("は", "は", korean: "은·는"),
        ])
        #expect(answer.knownMeaning == "안녕하세요")
        // 통째로 찾은 것은 문장의 한 부분이 아니다 — 함께 이으면 원문이 두 번 적힌다.
        #expect(answer.kana == "こんにちは")
    }

    @Test("한 낱말이면 사전의 한국어 뜻이 곧 답이다")
    func 한낱말() {
        let answer = QuickAnswer(typed: "아타마", segments: [Self.조각("頭", "あたま", korean: "머리")])
        #expect(answer.knownMeaning == "머리")
    }

    @Test("한 낱말이라도 한국어 뜻이 없으면 번역기에 맡긴다")
    func 한낱말영어() {
        // 영어 뜻을 답 자리에 올리느니 번역기에 맡긴다 — 그쪽은 적어도 한국어를 돌려준다.
        let answer = QuickAnswer(typed: "x", segments: [Self.조각("猫", "ねこ", 뜻: "cat")])
        #expect(answer.knownMeaning == nil)
        #expect(answer.forTranslation == "猫")
    }

    @Test("조각이 둘 이상이면 문장이고, 하나면 그 낱말의 갈래를 꼬리표로 단다")
    func 꼬리표() {
        // 앱의 찾기 화면과 같은 꼬리표다 — 문장 머리줄은 `문장`, 낱말 카드는 품사.
        let 문장 = QuickAnswer(typed: "x", segments: [Self.조각("頭", "あたま"), Self.조각("が", "が")])
        #expect(문장.isSentence)
        #expect(문장.wordClass == nil)
        let 낱말 = QuickAnswer(typed: "x", segments: [Self.조각("頭", "あたま")])
        #expect(!낱말.isSentence)
        #expect(낱말.wordClass != nil)
    }

    @Test("아무것도 못 찾으면 비어 있다")
    func 빈답() {
        #expect(QuickAnswer(typed: "ㅋㅋ", segments: []).isEmpty)
        #expect(QuickAnswer(typed: "쿠", segments: [Segment(hangul: "쿠", results: [])]).isEmpty)
    }
}
