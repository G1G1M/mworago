import Testing
@testable import MworagoCore

@Suite("문장 분절")
struct SegmenterTests {

    /// 테스트용 작은 사전. (표기, 읽기, 그 읽기의 점수)
    static func 사전(_ 항목들: [(String, String, Int)]) -> DictIndex {
        DictIndex(entries: 항목들.map { 표기, 읽기, 점수 in
            DictEntry(readings: [DictForm(text: 읽기, priority: 점수)],
                      writings: [DictForm(text: 표기, priority: 0)],
                      glosses: [])
        })
    }

    static let 사전들: DictIndex = 사전([
        ("頭", "あたま", 100), ("痛い", "いたい", 100), ("遺体", "いたい", 100),
        ("止める", "やめる", 50), ("大丈夫", "だいじょうぶ", 100),
        ("が", "が", 200), ("を", "を", 200), ("だ", "だ", 200),
        ("あた", "あた", 10), ("魔", "ま", 10), ("痛", "いた", 10),
    ])

    @Test("띄어 쓴 입력은 어절마다 나눈다")
    func 띄어쓰기() {
        let 결과 = Segmenter.segment("아타마 가 이타이", in: Self.사전들)
        #expect(결과.count == 3)
        #expect(결과.map(\.hangul) == ["아타마", "가", "이타이"])
    }

    @Test("붙여 쓴 입력도 사전을 보고 나눈다")
    func 붙여쓰기() {
        // 일본어에 띄어쓰기가 없으니 한글 음차도 붙여 칠 것이다
        let 결과 = Segmenter.segment("아타마가이타이", in: Self.사전들)
        #expect(결과.map(\.hangul) == ["아타마", "가", "이타이"])
    }

    @Test("가장 긴 낱말을 먼저 잡는다")
    func 최장일치() {
        // "아타마"를 [아타][마]로 쪼개면 조각마다 사전에 있긴 하지만 더 나쁜 분할이다
        let 결과 = Segmenter.segment("아타마", in: Self.사전들)
        #expect(결과.map(\.hangul) == ["아타마"])
    }

    @Test("낱말 하나면 그대로 둔다")
    func 단일낱말() {
        let 결과 = Segmenter.segment("다이죠부", in: Self.사전들)
        #expect(결과.count == 1)
        #expect(결과.first?.results.first?.headword == "大丈夫")
    }

    @Test("조각마다 검색 결과를 달고 온다")
    func 조각별결과() throws {
        let 결과 = Segmenter.segment("아타마가이타이", in: Self.사전들)
        let 마지막 = try #require(결과.last)
        #expect(마지막.results.contains { $0.headword == "痛い" })
    }

    @Test("사전에 없는 조각은 그대로 남긴다")
    func 미지의조각() {
        // 아무것도 못 찾았다고 입력을 버리면 안 된다. 어디서 막혔는지 보여줘야 한다
        let 결과 = Segmenter.segment("쿄로쿄로", in: Self.사전들)
        #expect(!결과.isEmpty)
        #expect(결과.allSatisfy { $0.results.isEmpty })
    }

    @Test("빈 입력은 빈 결과")
    func 빈입력() {
        #expect(Segmenter.segment("", in: Self.사전들).isEmpty)
        #expect(Segmenter.segment("   ", in: Self.사전들).isEmpty)
    }
}
