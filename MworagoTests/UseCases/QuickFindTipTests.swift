import Testing
import MworagoDomain
@testable import MworagoUseCases

@Suite("바로 찾기 쪽지")
struct QuickFindTipTests {

    @Test("처음에는 뜨지 않는다")
    func 처음() {
        #expect(!QuickFindTip.isDue(in: InMemoryPreferences()))
    }

    @Test("세 번 찾으면 뜬다 — 두 번까지는 안 뜬다")
    func 세번() {
        let preferences = InMemoryPreferences()
        QuickFindTip.noteFind(in: preferences)
        QuickFindTip.noteFind(in: preferences)
        #expect(!QuickFindTip.isDue(in: preferences))
        QuickFindTip.noteFind(in: preferences)
        #expect(QuickFindTip.isDue(in: preferences))
    }

    @Test("닫으면 더 찾아도 다시 뜨지 않는다")
    func 닫으면() {
        let preferences = InMemoryPreferences()
        for _ in 0..<3 { QuickFindTip.noteFind(in: preferences) }
        QuickFindTip.dismiss(in: preferences)
        for _ in 0..<5 { QuickFindTip.noteFind(in: preferences) }
        #expect(!QuickFindTip.isDue(in: preferences))
        #expect(preferences.string(forKey: QuickFindTip.countKey) == nil)
    }

    @Test("셀 만큼 센 뒤로는 더 적지 않는다")
    func 더적지않는다() {
        let preferences = InMemoryPreferences()
        for _ in 0..<10 { QuickFindTip.noteFind(in: preferences) }
        #expect(preferences.string(forKey: QuickFindTip.countKey) == "3")
    }
}
