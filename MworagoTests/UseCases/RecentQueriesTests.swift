import Testing
@testable import MworagoUseCases

@Suite("최근 찾은 것")
struct RecentQueriesTests {

    @Test("새로 찾은 것이 맨 위에 서고 다섯 개를 넘으면 오래된 것이 빠진다")
    func 맨위에() {
        var list: [String] = []
        for q in ["아", "이", "우", "에", "오", "카"] { list = RecentQueries.adding(q, to: list) }
        #expect(list == ["카", "오", "에", "우", "이"])
    }

    @Test("이미 있던 소리는 겹치지 않고 위로 올라간다 — 띄어쓰기는 가리지 않는다")
    func 겹치지않는다() {
        let list = RecentQueries.adding("다이 죠부", to: ["갓코", "다이죠부"])
        #expect(list == ["다이 죠부", "갓코"])
    }

    @Test("하나만 지우면 나머지는 차례 그대로 남는다")
    func 하나지우기() {
        #expect(RecentQueries.removing("갓코", from: ["다이죠부", "갓코", "아리가토"]) == ["다이죠부", "아리가토"])
    }

    @Test("빈 것은 남기지 않는다")
    func 빈것() {
        #expect(RecentQueries.adding("  ", to: ["갓코"]) == ["갓코"])
    }

    @Test("적었다가 그대로 읽는다")
    func 적고읽기() {
        let list = ["갓코", "다이죠부"]
        #expect(RecentQueries.decode(RecentQueries.encode(list)) == list)
        #expect(RecentQueries.encode([]) == nil)
        #expect(RecentQueries.decode(nil).isEmpty)
    }
}
