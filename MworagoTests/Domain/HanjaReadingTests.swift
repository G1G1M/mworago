import Testing
@testable import MworagoDomain

@Suite("한자 한국 독음")
struct HanjaReadingTests {
    static let table = HanjaReading(tsv: """
        # 한자\t한국 독음
        大\t대
        丈\t장
        夫\t부
        約\t약
        束\t속
        痛\t통
        変\t변
        人\t인
        """)

    @Test("한자어를 이어 읽는다")
    func 한자어() {
        #expect(Self.table.reading(of: "約束") == "약속")     // 뜻까지 통한다
        #expect(Self.table.reading(of: "大丈夫") == "대장부")  // 독음만 통하고 뜻은 다르다
    }

    @Test("가나는 건너뛴다")
    func 가나섞임() {
        #expect(Self.table.reading(of: "痛い") == "통")
    }

    @Test("한자가 없으면 nil")
    func 한자없음() {
        #expect(Self.table.reading(of: "やめる") == nil)
        #expect(Self.table.reading(of: "") == nil)
    }

    @Test("모르는 한자는 건너뛴다")
    func 미등재() {
        #expect(Self.table.reading(of: "大𠮟") == "대")
    }

    @Test("글자마다 떼어 읽는다 — 이어 읽으면 다른 낱말이 된다")
    func 글자마다() {
        let pairs = Self.table.characters(of: "大変")
        #expect(pairs.map(\.hanja) == ["大", "変"])
        #expect(pairs.map(\.reading) == ["대", "변"])
    }

    @Test("가나 · 々 · 겹친 한자는 빼고 읽는다")
    func 글자마다_거르기() {
        #expect(Self.table.characters(of: "痛い").map(\.reading) == ["통"])
        #expect(Self.table.characters(of: "人々").map(\.hanja) == ["人"])
        #expect(Self.table.characters(of: "大大").count == 1)
        #expect(Self.table.characters(of: "やめる").isEmpty)
    }
}
