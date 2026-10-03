import Testing
@testable import MworagoDomain

/// 낱말을 골라 두고 한꺼번에 옮기거나 지우는 손.
///
/// 책장의 `모두` 목록과 묶음 화면이 같은 손을 각자 들고 있었다 — 켜는 것 · 하나 고르기 ·
/// 모두 고르기 · 끄기가 두 벌이었다. 한쪽만 고치면 같은 머리줄이 화면마다 다르게 군다.
@Suite("낱말 고르기")
struct WordSelectionTests {

    @Test("처음에는 꺼져 있고 아무것도 안 골랐다")
    func 처음() {
        let 손 = WordSelection()
        #expect(!손.isActive)
        #expect(손.count == 0)
    }

    @Test("켜고 하나씩 고르고 다시 누르면 푼다")
    func 하나씩() {
        var 손 = WordSelection()
        손.begin()
        손.toggle("a")
        손.toggle("b")
        손.toggle("a")
        #expect(손.isActive)
        #expect(손.contains("b"))
        #expect(!손.contains("a"))
        #expect(손.count == 1)
    }

    @Test("모두 고르기는 다 골랐으면 다 푼다")
    func 모두() {
        var 손 = WordSelection()
        손.begin()
        let 목록 = ["a", "b", "c"]
        #expect(!손.allPicked(of: 목록))
        손.toggleAll(목록)
        #expect(손.allPicked(of: 목록))
        손.toggleAll(목록)
        #expect(손.count == 0)
        // 빈 목록은 "다 골랐다"가 아니다 — 고를 것이 없다.
        #expect(!손.allPicked(of: []))
    }

    @Test("전부 고른 채로 켤 수 있다")
    func 전부켜기() {
        var 손 = WordSelection()
        손.begin(picking: ["a", "b"])
        #expect(손.isActive)
        #expect(손.count == 2)
    }

    @Test("끄면 고른 것도 비운다")
    func 끄기() {
        var 손 = WordSelection()
        손.begin(picking: ["a"])
        손.end()
        #expect(!손.isActive)
        #expect(손.count == 0)
    }

    @Test("고른 것을 목록의 차례대로 꺼낸다")
    func 꺼내기() {
        struct 낱말: Identifiable, Equatable { let id: String }
        var 손 = WordSelection()
        손.begin(picking: ["c", "a"])
        let 목록 = [낱말(id: "a"), 낱말(id: "b"), 낱말(id: "c")]
        #expect(손.picked(in: 목록) == [낱말(id: "a"), 낱말(id: "c")])
    }
}
