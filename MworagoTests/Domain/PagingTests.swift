import Testing
@testable import MworagoDomain

/// 넘겨 보는 화면(연습 · 가나 익히기 · 낱말 상세)이 함께 쓰는 셈.
///
/// 네 화면이 "id 로 지금 장 찾기, 없으면 첫 장"과 "끝에서 처음으로 돌기"를 각자 적고
/// 있었다. 한 화면만 셈이 달라지면 같은 몸짓이 화면마다 다르게 넘어간다.
@Suite("넘겨 보기")
struct PagingTests {

    struct 장: Identifiable, Equatable { let id: Int }
    let 묶음 = [장(id: 10), 장(id: 20), 장(id: 30)]

    @Test("보고 있던 장을 찾고, 없으면 첫 장이다")
    func 지금장() {
        #expect(묶음.page(20) == 장(id: 20))
        #expect(묶음.page(99) == 장(id: 10))
        #expect(묶음.page(nil) == 장(id: 10))
        #expect([장]().page(10) == nil)
    }

    @Test("몇 번째 장인지는 찾았을 때만 말한다")
    func 몇번째() {
        #expect(묶음.pageIndex(30) == 2)
        #expect(묶음.pageIndex(99) == nil)
        #expect(묶음.pageIndex(nil) == nil)
    }

    @Test("넘기면 끝에서 처음으로, 처음에서 끝으로 돈다")
    func 돌기() {
        #expect(묶음.pageID(from: 30, by: 1) == 10)
        #expect(묶음.pageID(from: 10, by: -1) == 30)
        #expect(묶음.pageID(from: 20, by: 1) == 30)
        // 보던 장이 사라졌으면 첫 장에서 센다.
        #expect(묶음.pageID(from: 99, by: 1) == 20)
        #expect([장]().pageID(from: 10, by: 1) == nil)
    }
}
