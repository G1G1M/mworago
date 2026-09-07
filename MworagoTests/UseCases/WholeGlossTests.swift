import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 입력 전체가 한 낱말일 때의 문장 뜻.
///
/// `콘니치와` 를 치면 화면이 이렇게 됐다.
///
///     문장   今日は  →  "오늘은"      ← 틀렸다
///     카드   こんにちわ(今日は)  안녕하세요   ← 맞다
///
/// 사전은 `今日は`(uk)를 통째로 알고 있고 뜻도 "안녕하세요"로 붙어 있는데,
/// **문장 뜻만 그것을 안 듣고** 조각(`今日`+`は`)을 도로 이어 번역기에 넘겼다.
/// 번역기는 그 글자가 인사말인 줄 알 길이 없어 `今日`(오늘)+`は`(은)로 읽는다.
///
/// 이 레포에서 세 번째 보는 모양이다 — **사전이 이미 알려 준 것을 안 듣던 문제.**
/// 통째로 잡힌 낱말의 뜻이 있으면 그것이 곧 문장 뜻이다. 사람이 다듬은 값이라
/// 기계가 문맥 없이 옮긴 것보다 낫다.
@Suite("통째로 찾은 낱말의 뜻")
struct WholeGlossTests {

    static func 조각(_ 표기: String, _ 읽기: String, korean: String? = nil,
                   uk: Bool = false, whole: Bool = false) -> Segment {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: ["hello"], usuallyKana: uk, koreanGloss: korean)
        let result = SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                                  deinflection: nil, score: 0)
        return Segment(hangul: "x", results: [result], isWhole: whole)
    }

    @Test("통째로 잡힌 낱말에 한국어 뜻이 있으면 그것이 문장 뜻이다")
    func 통째뜻() {
        let segments = [
            Self.조각("今日は", "こんにちわ", korean: "안녕하세요", uk: true, whole: true),
            Self.조각("今日", "こんにち", korean: "오늘"),
            Self.조각("は", "は", korean: "은"),
        ]
        #expect(segments.wholeKoreanGloss == "안녕하세요")
    }

    @Test("통째로 잡힌 것이 없으면 nil — 번역기가 할 일이다")
    func 통째없음() {
        let segments = [
            Self.조각("彼", "かれ", korean: "그"),
            Self.조각("は", "は", korean: "은"),
        ]
        #expect(segments.wholeKoreanGloss == nil)
    }

    @Test("통째로 잡혔어도 한국어 뜻이 없으면 nil")
    func 뜻이빈통째() {
        // 아직 안 구운 낱말이다. 영어를 문장 뜻 자리에 올리느니 번역기에 맡긴다 —
        // 그쪽은 적어도 한국어를 돌려준다.
        let segments = [
            Self.조각("何処へ", "どこへ", korean: nil, whole: true),
            Self.조각("何処", "どこ", korean: "어디"),
            Self.조각("へ", "へ", korean: "로"),
        ]
        #expect(segments.wholeKoreanGloss == nil)
    }

    @Test("빈 문자열은 뜻이 아니다")
    func 빈뜻() {
        let segments = [Self.조각("今日は", "こんにちわ", korean: "", whole: true)]
        #expect(segments.wholeKoreanGloss == nil)
    }
}
