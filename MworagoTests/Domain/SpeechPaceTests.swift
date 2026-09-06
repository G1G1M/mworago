import Testing
@testable import MworagoDomain

@Suite("읽는 빠르기")
struct SpeechPaceTests {

    /// 글자 하나는 소리를 익히려고 듣는 것이라 가장 또렷해야 한다.
    /// 요음(`ぎゅ`)은 두 글자로 적히지만 **한 소리**다.
    @Test("한 소리는 글자 빠르기")
    func 한소리() {
        #expect(SpeechPace.of("あ") == .kana)
        #expect(SpeechPace.of("ぎゅ") == .kana)
        #expect(SpeechPace.of("ア") == .kana)
    }

    /// 낱말은 소리를 익히는 것이 아니라 **어떻게 들리는지**를 듣는 자리다.
    @Test("낱말은 낱말 빠르기")
    func 낱말() {
        #expect(SpeechPace.of("大丈夫") == .word)
        #expect(SpeechPace.of("だいじょうぶ") == .word)
        #expect(SpeechPace.of("痛い") == .word)
    }

    /// **문장은 이어지는 말이라 늦추면 끊어 읽는 자리가 무너진다.**
    /// 연습 카드에 문장이 담기게 되었으므로(문장째 담기), 낱말 빠르기로 읽으면
    /// 긴 말이 한없이 늘어진다.
    @Test("긴 것은 문장 빠르기")
    func 문장() {
        #expect(SpeechPace.of("だいじょうぶですか") == .sentence)
        #expect(SpeechPace.of("もうしわけありません") == .sentence)
    }

    /// 빈 것에도 답이 있어야 한다 — 부르는 쪽이 갈래를 나누지 않게.
    @Test("빈 것은 낱말로 본다")
    func 빈것() {
        #expect(SpeechPace.of("") == .word)
    }
}
