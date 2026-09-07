import Testing
@testable import MworagoDomain
@testable import MworagoUseCases

/// 활용을 되돌린 조각 뒤의 조사 경계.
///
/// `이타이야메로`(README 의 대표 예문)가 `痛い やめろ` 가 아니라
/// **`いる い やめろ`** 로 갈렸다. 숫자를 보면 이렇다.
///
///     痛い 한 조각          57.3
///     いた(いる 과거형)     85.6   ← 「있었다」는 최상위 빈도다
///     い(조사)              92.5
///     조사 경계 보너스      +20
///
/// 앞 두 글자가 하필 최상위 빈도 낱말의 활용형이라 쪼개는 쪽이 이겼다.
/// **い형용사 전반의 병은 아니다** — `寒い`·`高い`·`早い`·`大きい` 는 멀쩡하다.
/// `さむ`·`たか` 가 `いた` 만큼 흔하지 않기 때문이다.
///
/// `Ranker` 는 "추측이 과감할수록 깎는다"는 태도로 서 있는데, 이 보너스만은
/// 앞 조각이 사전에 그대로 실린 것인지 **되돌려 만든 것인지**를 가리지 않았다.
/// 되돌리기도 추측이라, 그 위에 보너스를 또 얹으면 추측이 겹친다.
@Suite("되돌린 조각 뒤의 조사 경계")
struct InflectedJunctionTests {

    @Test("사전에 그대로 실린 자립어 뒤에는 보너스가 그대로 붙는다")
    func 그대로실린뒤() {
        #expect(Segmenter.junctionBonus(afterDeinflection: false, bonus: 8) == 8)
    }

    @Test("되돌려 찾은 자립어 뒤에는 안 붙는다")
    func 되돌린뒤() {
        #expect(Segmenter.junctionBonus(afterDeinflection: true, bonus: 8) == 0)
    }

    /// 되돌린 조각 + 조사가 낱말 하나를 이기던 자리.
    ///
    /// **보너스를 터무니없이 키워서 겨눈다.** 작은 사전으로는 실제 빈도 관계를
    /// 세울 수가 없어(점수 크기가 말뭉치에서 온다) 규칙만 따로 본다 —
    /// 되돌린 조각 뒤라면 보너스가 얼마든 경계가 안 열려야 한다.
    @Test("되돌린 조각 뒤에서는 보너스를 키워도 경계가 안 열린다")
    func 되돌린뒤에는안열린다() {
        let index = DictIndex(entries: [
            DictEntry(readings: [DictForm(text: "いたい", priority: 200)],
                      writings: [DictForm(text: "痛い", priority: 0)],
                      glosses: ["painful"], partsOfSpeech: ["adj-i"]),
            DictEntry(readings: [DictForm(text: "いる", priority: 150)],
                      writings: [DictForm(text: "居る", priority: 0)],
                      glosses: ["to be"], partsOfSpeech: ["v1"]),
            DictEntry(readings: [DictForm(text: "い", priority: 150)],
                      writings: [], glosses: ["particle"], partsOfSpeech: ["prt"]),
        ])
        // `いた` 는 `いる` 를 되돌려야 나온다. 그 뒤의 `い` 는 조사다.
        let 갈린것 = Segmenter.segment("이타이", in: index, junctionBonus: 500)
            .filter { !$0.isWhole }
        #expect(갈린것.map(\.hangul) == ["이타이"])
    }

    /// 규칙이 **멀쩡한 경계까지 닫지는 않는다.** 사전에 그대로 실린 자립어 뒤에서는
    /// 보너스가 예전처럼 자리를 가른다.
    @Test("그대로 실린 자립어 뒤에서는 보너스가 자리를 가른다")
    func 그대로실린뒤에는열린다() {
        let index = DictIndex(entries: [
            DictEntry(readings: [DictForm(text: "あたま", priority: 100)],
                      writings: [DictForm(text: "頭", priority: 0)],
                      glosses: ["head"], partsOfSpeech: ["n"]),
            DictEntry(readings: [DictForm(text: "が", priority: 200)],
                      writings: [], glosses: ["particle"], partsOfSpeech: ["prt"]),
        ])
        let 갈린것 = Segmenter.segment("아타마가", in: index).filter { !$0.isWhole }
        #expect(갈린것.map(\.hangul) == ["아타마", "가"])
    }
}
