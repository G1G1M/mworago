import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 가나 옆 괄호에 넣을 한자.
///
/// 앱은 오래도록 한자를 한 자도 그리지 않았다. `だいじょうぶ` 는 나오는데
/// `大丈夫` 는 어디에도 없어서, 소리로 찾아낸 낱말이 **무엇인지**는 화면이
/// 말해 주지 않았다. `やめる` 하나에 止める(그만두다)·辞める(사직하다)·
/// 病める(병들다)가 걸리는데 뜻은 이미 표제항마다 따로 붙어 있다 —
/// 빠진 것은 정확도가 아니라 **어느 것인지 보이는 것**이었다.
///
/// 규칙은 하나다. **표기가 읽기와 다를 때만 괄호를 그린다.**
@Suite("괄호 안의 한자")
struct KanjiWritingTests {

    static func 결과(_ 표기: String, _ 읽기: String,
                   rare: Bool = false, uk: Bool = false) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기
                                  ? [] : [DictForm(text: 표기, priority: 0, isRare: rare)],
                              glosses: ["gloss"],
                              usuallyKana: uk)
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                            deinflection: nil, score: 0)
    }

    @Test("한자 표기가 있으면 그것을 준다")
    func 한자있음() {
        #expect(Self.결과("大丈夫", "だいじょうぶ").kanji == "大丈夫")
    }

    @Test("가나로만 쓰는 낱말은 괄호가 없다")
    func 가나뿐() {
        // 뜻이 붙은 것 중 10.3% 가 한자 표기 자체를 갖고 있지 않다.
        // 그 자리에 `ありがとう(ありがとう)` 를 그리면 같은 말을 두 번 적는 꼴이다.
        #expect(Self.결과("ありがとう", "ありがとう").kanji == nil)
    }

    @Test("거의 안 쓰는 표기(rK·sK)는 꺼내지 않는다")
    func 드문표기() {
        // `する` 의 `為る` 가 그렇다. 사전이 실어 두었을 뿐 그렇게 적는 사람이 없어서,
        // 앱도 굽는 쪽도 이미 빼고 본다(`usableWritings`).
        #expect(Self.결과("為る", "する", rare: true).kanji == nil)
    }

    @Test("사전이 `uk` 라고 한 낱말도 괄호에는 넣는다")
    func 보통가나() {
        // 문장에는 가나로 적는 것이 맞다(`Segment.japanese` 가 그 규칙을 지킨다).
        // 괄호는 **적는 자리가 아니라 가리키는 자리**라 규칙이 다르다 —
        // `なる` 로는 成る(되다)와 生る(열매 맺다)가 갈리지 않는다.
        #expect(Self.결과("成る", "なる", uk: true).kanji == "成る")
    }

    @Test("담아 둔 낱말도 같은 규칙으로 갈린다")
    func 담은낱말() {
        // 책장과 연습 카드는 사전이 아니라 담을 때 적어 둔 것을 그린다.
        let 한자 = CollectedWord(headword: "大丈夫", reading: "だいじょうぶ",
                              hangul: "다이죠부", gloss: "괜찮다")
        let 가나 = CollectedWord(headword: "ありがとう", reading: "ありがとう",
                              hangul: "아리가토", gloss: "고맙다")
        #expect(한자.kanji == "大丈夫")
        #expect(가나.kanji == nil)
    }

    @Test("문장으로 담은 것에는 괄호를 안 단다")
    func 담은문장() {
        // 괄호는 같은 소리로 갈리는 낱말이 무엇인지 가리키는 자리다. 문장에는 가릴
        // 것이 없고 길이만 두 배가 된다 — 목록 한 줄에 가나 문장과 한자 문장이
        // 나란히 선다. 한자 원문은 담을 때 그대로 붙들려 있으므로 잃는 것이 없다.
        let 문장 = CollectedWord(headword: "私は学生です", reading: "わたしはがくせいです",
                              hangul: "와타시와가쿠세이데스", gloss: "나는 학생입니다",
                              partOfSpeech: CollectedWord.sentenceTag)
        #expect(문장.isSentence)
        #expect(문장.kanji == nil)
        #expect(문장.headword == "私は学生です")   // 붙들린 것은 그대로다
    }

    @Test("문장에 놓는 글자는 이 규칙과 따로 논다")
    func 문장은그대로() {
        // 괄호를 넣는다고 문장 머리까지 한자로 바뀌면 안 된다. `uk` 낱말은
        // 자막이 가나로 적으므로 문장에서는 그대로 가나여야 한다.
        let segment = Segment(hangul: "나루", results: [Self.결과("成る", "なる", uk: true)])
        #expect(segment.japanese == "なる")
        #expect(segment.results[0].kanji == "成る")
    }
}
