import Testing
@testable import MworagoDomain

/// **사전이 권하는 철자가 머리에 선다.**
///
/// 사용자가 친 것은 소리뿐이라 철자는 우리가 고른다. `콘방와` 를 치면 규칙은
/// `こんばんわ` 를 만들고 사전에는 그 철자도 실려 있다 — 다만 `ik`(불규칙 가나 표기)
/// 라는 표시를 달고서다. 표시를 읽지 않으면 둘이 같은 급이 되어, 사용자가 `와` 로
/// 쳤다는 이유만으로 사전이 권하지 않는 철자가 카드 머리에 선다.
///
/// **찾는 길은 그대로 열어 둔다.** 사람들은 실제로 `와` 로 친다. 닫을 것은 화면뿐이다.
@Suite("권하는 철자")
struct DictEntryReadingTests {

    /// 今晩は — 권하는 철자와 불규칙 철자가 나란히 실려 있다.
    static let 저녁인사 = DictEntry(
        readings: [DictForm(text: "こんばんは", priority: 10),
                   DictForm(text: "こんばんわ", priority: 0, isRare: true)],
        writings: [DictForm(text: "今晩は", priority: 10)],
        glosses: ["good evening"], usuallyKana: true)

    @Test("불규칙 철자로 찾아와도 권하는 철자로 선다")
    func 권하는철자() {
        #expect(Self.저녁인사.preferredReading("こんばんわ") == "こんばんは")
        // 권하는 철자로 찾아왔으면 바꿀 것이 없다.
        #expect(Self.저녁인사.preferredReading("こんばんは") == "こんばんは")
    }

    /// **바꿔 세울 자리가 없으면 그대로 둔다.** 읽기가 하나도 안 남는 것보다
    /// 사전이 실은 그대로 보이는 편이 낫다.
    @Test("권하는 철자가 아예 없으면 찾은 것을 그대로 세운다")
    func 전부드물면() {
        let entry = DictEntry(readings: [DictForm(text: "ゐ", priority: 0, isRare: true)],
                              writings: [], glosses: ["archaic i"])
        #expect(entry.preferredReading("ゐ") == "ゐ")
        #expect(entry.usableReadings.map(\.text) == ["ゐ"])
        #expect(entry.headword == "ゐ")
    }

    /// 표기가 없는 낱말은 첫 읽기가 표제어다. 그 자리에도 드문 철자가 서면 안 된다.
    @Test("표기 없는 낱말의 표제어도 권하는 철자다")
    func 가나표제어() {
        let entry = DictEntry(readings: [DictForm(text: "ふいんき", priority: 0, isRare: true),
                                         DictForm(text: "ふんいき", priority: 10)],
                              writings: [], glosses: ["atmosphere"])
        #expect(entry.headword == "ふんいき")
    }

    // MARK: 소리
    //
    // 권하는 철자를 세우고 나면 **음차가 「콘반하」가 된다.** 그러면 소리가 틀린다 —
    // 사용자가 친 것도, 실제로 들리는 것도 「콘반와」다.

    /// **지어내지 않는다.** 같은 표제항에 끝만 `わ` 로 바뀐 이표기가 나란히 서 있는 것이
    /// 사전이 남긴 증거다 — 그 `は` 는 와로 읽힌다는 뜻이다.
    @Test("낱말 끝의 は 를 와로 읽는 근거는 사전 안에 있다")
    func 끝의は() {
        #expect(Self.저녁인사.spokenReading("こんばんは") == "こんばんわ")

        // 증거가 없으면 표기대로 읽는다. `葉`(잎)의 `は` 는 하다.
        let 잎 = DictEntry(readings: [DictForm(text: "は", priority: 10)],
                          writings: [DictForm(text: "葉", priority: 10)], glosses: ["leaf"])
        #expect(잎.spokenReading("は") == "は")

        // 끝이 は 가 아니면 손댈 것이 없다.
        #expect(Self.저녁인사.spokenReading("こんばんわ") == "こんばんわ")
    }
}
