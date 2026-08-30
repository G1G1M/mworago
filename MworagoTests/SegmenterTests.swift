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

/// 모르는 조각이 섞였을 때.
///
/// 오타 한 글자에 아는 낱말까지 잃으면 안 된다. 실제로 `다이죠부뷁` 을 치면
/// 大丈夫 까지 사라지고 "사전에 없어요" 한 줄만 남았다 —
/// 미지 조각의 벌점이 길이와 무관해서, 통째로 모르는 편이 점수가 높았기 때문이다.
@Suite("모르는 조각")
struct UnknownPieceTests {

    static let 사전 = SegmenterTests.사전들

    @Test("아는 낱말 옆에 모르는 조각이 붙어도 아는 것은 찾아 준다")
    func 부분미지() {
        let 결과 = Segmenter.segment("다이죠부뷁", in: Self.사전)
        #expect(결과.contains { $0.hangul == "다이죠부" && !$0.results.isEmpty })
        // 모르는 자리는 모르는 채로 남는다 — 구멍이 보여야 어디가 틀렸는지 안다.
        #expect(결과.contains { $0.results.isEmpty })
    }

    @Test("앞에 붙어도 마찬가지다")
    func 앞에붙음() {
        let 결과 = Segmenter.segment("뷁다이죠부", in: Self.사전)
        #expect(결과.contains { $0.hangul == "다이죠부" && !$0.results.isEmpty })
    }

    @Test("정말 모르는 구간은 통째로 둔다")
    func 통째미지() {
        // 잘게 쪼개 봐야 조각마다 모르기는 마찬가지다. 조각 비용만 더 든다.
        let 결과 = Segmenter.segment("뷁뷁뷁", in: Self.사전)
        #expect(결과.count == 1)
        #expect(결과.first?.results.isEmpty == true)
    }

    @Test("아는 낱말들 사이에 낀 것도 가른다")
    func 사이에낌() {
        let 결과 = Segmenter.segment("아타마뷁이타이", in: Self.사전)
        #expect(결과.contains { $0.hangul == "아타마" && !$0.results.isEmpty })
        #expect(결과.contains { $0.hangul == "이타이" && !$0.results.isEmpty })
    }
}
