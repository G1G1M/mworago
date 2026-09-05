import Testing
@testable import MworagoUseCases

@Suite("번역 언어팩")
struct TranslationPackTests {

    @Test("깔려 있으면 아무 말도 하지 않는다")
    func 준비됨() {
        #expect(TranslationPack.ready.notice == nil)
    }

    /// **아직 모르는 것을 말하지 않는다.** 물어보기 전에 안내를 띄우면, 언어팩이 멀쩡히
    /// 깔린 기기에서도 찾자마자 한 번 깜빡인다.
    @Test("아직 안 물어봤으면 아무 말도 하지 않는다")
    func 모름() {
        #expect(TranslationPack.unknown.notice == nil)
    }

    /// 받을 수 있는 것과 못 하는 것은 **사용자가 할 일이 다르다.** 뭉뚱그려 한 문장으로
    /// 적으면, 받을 수 없는 기기를 쓰는 사람을 설정 앱으로 헛걸음시킨다.
    @Test("받으면 되는 것과 못 하는 것을 가려 말한다")
    func 안내가갈린다() {
        let 받으면됨 = TranslationPack.needsDownload.notice
        let 못함 = TranslationPack.unsupported.notice
        #expect(받으면됨 != nil)
        #expect(못함 != nil)
        #expect(받으면됨 != 못함)
        // 받으면 되는 쪽에는 어디로 가야 하는지가 적혀 있어야 한다.
        #expect(받으면됨?.contains("번역 언어") == true)
        // 못 하는 쪽에는 설정으로 가라는 말이 없어야 한다.
        #expect(못함?.contains("설정") == false)
    }

    /// 낱말 뜻은 앱 안에 들어 있어 언어팩과 무관하다. 안내가 그것까지 못 쓰는 것처럼
    /// 읽히면, 사용자가 앱 전체를 못 쓰는 것으로 여긴다.
    @Test("낱말 뜻은 그대로 나온다고 함께 말한다")
    func 낱말은된다() {
        #expect(TranslationPack.needsDownload.notice?.contains("낱말") == true)
        #expect(TranslationPack.unsupported.notice?.contains("낱말") == true)
    }
}
