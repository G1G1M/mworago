import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 문장에 놓는 글자와 담아 둔 문장.
///
/// 화면은 가나만 그리지만, 문장 뜻을 옮길 때와 문장을 담을 때는 한자 원문을 쓴다 —
/// 번역기가 가나만 받으면 뜻을 헷갈린다.
@Suite("문장의 글자")
struct SentenceWritingTests {

    static func 결과(_ 표기: String, _ 읽기: String, uk: Bool = false) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: ["gloss"],
                              usuallyKana: uk)
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                            deinflection: nil, score: 0)
    }

    @Test("문장으로 담은 것은 한자 원문을 붙든다")
    func 담은문장() {
        let 문장 = CollectedWord(headword: "私は学生です", reading: "わたしはがくせいです",
                              hangul: "와타시와가쿠세이데스", gloss: "나는 학생입니다",
                              partOfSpeech: CollectedWord.sentenceTag)
        #expect(문장.isSentence)
        #expect(문장.headword == "私は学生です")
    }

    @Test("사전이 `uk` 라고 한 낱말은 문장에 가나로 놓는다")
    func 보통가나() {
        // 자막이 가나로 적는 낱말이라, 문장에서도 가나여야 번역이 자연스럽다.
        let segment = Segment(hangul: "나루", results: [Self.결과("成る", "なる", uk: true)])
        #expect(segment.japanese == "なる")
    }
}
