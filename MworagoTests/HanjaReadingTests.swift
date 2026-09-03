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
}
