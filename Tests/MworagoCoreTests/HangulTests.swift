import Testing
@testable import MworagoCore

@Suite("한글 음절 분해")
struct HangulTests {

    @Test("받침 없는 음절")
    func 받침없음() throws {
        let s = try #require(HangulSyllable("가"))
        #expect(s.initial == "ㄱ")
        #expect(s.medial == "ㅏ")
        #expect(s.final == nil)
    }

    @Test("받침 있는 음절")
    func 받침있음() throws {
        let s = try #require(HangulSyllable("센"))
        #expect(s.initial == "ㅅ")
        #expect(s.medial == "ㅔ")
        #expect(s.final == "ㄴ")
    }

    @Test("요음이 될 중성")
    func 요음중성() throws {
        let s = try #require(HangulSyllable("죠"))
        #expect(s.initial == "ㅈ")
        #expect(s.medial == "ㅛ")
    }

    @Test("한글이 아니면 nil")
    func 비한글() throws {
        #expect(HangulSyllable("あ") == nil)
        #expect(HangulSyllable("A") == nil)
        #expect(HangulSyllable("ㄱ") == nil)   // 자모 단독은 음절이 아니다
    }

    @Test("문자열 전체 분해")
    func 문자열분해() throws {
        let syllables = try #require(HangulSyllable.decompose("잇쇼니"))
        #expect(syllables.count == 3)
        #expect(syllables[0].final == "ㅅ")
        #expect(syllables[1].initial == "ㅅ")
        #expect(syllables[2].medial == "ㅣ")
    }
}
