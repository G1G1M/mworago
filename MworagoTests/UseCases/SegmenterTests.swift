import Testing
@testable import MworagoDomain
@testable import MworagoUseCases

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

    /// 품사까지 달아 만드는 사전. (표기, 읽기, 그 읽기의 점수, 품사 태그)
    static func 사전(_ 항목들: [(String, String, Int, [String])]) -> DictIndex {
        DictIndex(entries: 항목들.map { 표기, 읽기, 점수, 태그 in
            DictEntry(readings: [DictForm(text: 읽기, priority: 점수)],
                      writings: [DictForm(text: 표기, priority: 0)],
                      glosses: [], partsOfSpeech: 태그)
        })
    }

    static let 사전들: DictIndex = 사전([
        ("頭", "あたま", 100), ("痛い", "いたい", 100), ("遺体", "いたい", 100),
        ("止める", "やめる", 50), ("大丈夫", "だいじょうぶ", 100),
        ("が", "が", 200), ("を", "を", 200), ("だ", "だ", 200),
        ("あた", "あた", 10), ("魔", "ま", 10), ("痛", "いた", 10),
    ])

    /// 조사 `は`·`へ` 를 시험할 작은 사전.
    ///
    /// 함정을 일부러 넣었다 — `和本` 은 실제로 사전에 있는 낱말이고, 조사 `は` 가
    /// 없으면 `코레와혼데스` 가 `これ 和本 です` 로 끊긴다. 조사가 빠지면 조각이
    /// 하나 사라지는 것으로 끝나지 않고 **없는 말이 만들어진다.**
    static let 조사사전: DictIndex = 사전([
        ("私", "わたし", 100), ("渡し", "わたし", 60),
        ("これ", "これ", 100), ("本", "ほん", 100), ("和本", "わほん", 20),
        ("日本", "にほん", 100), ("内", "うち", 100),
        ("は", "は", 200), ("へ", "へ", 200), ("です", "です", 200),
        ("わ", "わ", 30), ("え", "え", 30), ("輪", "わ", 20),
    ])

    /// 어절 첫머리의 조사를 시험할 사전.
    ///
    /// 실제 점수를 그대로 옮겼다 — `と` 는 조사라 최상위 빈도이고, `どこ`+`へ` 를
    /// 합친 것보다 `と`+`こえ` 쪽이 높다. 그래서 점수만 보면 반드시 진다.
    static let 첫머리사전: DictIndex = 사전([
        ("何処", "どこ", 90, []),
        ("へ", "へ", 90, ["prt"]),
        ("と", "と", 100, ["prt", "conj", "n"]),
        ("声", "こえ", 90, []),
        ("私", "わたし", 100, ["pn"]),
        ("は", "は", 200, ["prt"]),
        ("でも", "でも", 100, ["conj", "prt"]),
    ])

    @Test("문장은 조사로 시작하지 않는다")
    func 첫머리조사() {
        // 벌점이 없으면 `도코에`(どこへ, 어디로)가 `と`+`こえ` 로 갈린다 —
        // 되살린 원문이 `とこえ` 라는 말이 안 되는 문자열이 되어 번역기로 넘어간다.
        //
        // **두 규칙을 갈라서 본다.** 조사 경계 보너스만으로도 이 자리는 뒤집히므로,
        // 그것을 켜 둔 채로는 첫머리 벌점이 제 몫을 하는지 알 수 없다.
        let 벌점없이 = Segmenter.segment("도코에", in: Self.첫머리사전,
                                       boundPenalty: 0, junctionBonus: 0)
        #expect(벌점없이.filter { !$0.isWhole }.map(\.hangul) == ["도", "코에"])

        let 벌점주고 = Segmenter.segment("도코에", in: Self.첫머리사전,
                                       boundPenalty: 40, junctionBonus: 0)
        #expect(벌점주고.filter { !$0.isWhole }.map(\.hangul) == ["도코", "에"])
    }

    @Test("앞에 낱말이 있는 조사는 벌하지 않는다")
    func 뒤따르는조사() {
        // 벌점은 **첫머리에만** 건다. 조사 자체를 깎으면 `私 は` 가 깨진다.
        let 결과 = Segmenter.segment("와타시와", in: Self.첫머리사전, boundPenalty: 40)
        #expect(결과.filter { !$0.isWhole }.map(\.hangul) == ["와타시", "와"])
    }

    @Test("접속사는 문장을 연다")
    func 접속사첫머리() {
        // `でも` 는 conj 를 먼저 달고 prt 를 겸한다. 기능어라고 뭉뚱그려 벌하면
        // "그런데 …" 로 시작하는 멀쩡한 문장이 밀린다.
        let 결과 = Segmenter.segment("데모코에", in: Self.첫머리사전, boundPenalty: 40)
        #expect(결과.filter { !$0.isWhole }.map(\.hangul) == ["데모", "코에"])
    }

    /// 조사가 뒷낱말에 삼켜지는 자리를 시험할 사전.
    ///
    /// 실제로 났던 일이다 — `쿄다이가이마스카`(兄弟がいますか, 형제가 있습니까)가
    /// `巨大`(거대) + `買います`(삽니다) 로 갈렸다. 조사 `が` 가 뒤의 `います` 와 붙어
    /// **사전에 있는 딴 낱말**이 되는데, 조각이 하나 줄어 비용까지 아낀다.
    static let 삼킴사전: DictIndex = 사전([
        ("兄弟", "きょうだい", 100, ["n"]),
        ("が", "が", 200, ["prt"]),
        ("居ます", "います", 150, ["v1"]),
        ("買います", "かいます", 220, ["v5u"]),
    ])

    @Test("조사는 자립어 뒤가 제자리다")
    func 조사가_삼켜지는_것() {
        // 보너스가 없으면 조각을 덜 만드는 쪽이 이겨서 조사가 통째로 삼켜진다.
        let 보너스없이 = Segmenter.segment("쿄다이가이마스", in: Self.삼킴사전, junctionBonus: 0)
        #expect(보너스없이.filter { !$0.isWhole }.map(\.hangul) == ["쿄다이", "가이마스"])

        // 자립어 뒤에 조사가 서는 경계를 편들면 제자리를 찾는다.
        let 보너스주고 = Segmenter.segment("쿄다이가이마스", in: Self.삼킴사전, junctionBonus: 40)
        #expect(보너스주고.filter { !$0.isWhole }.map(\.hangul) == ["쿄다이", "가", "이마스"])
    }

    @Test("보너스는 조사 앞이 자립어일 때만 붙는다")
    func 보너스_거는_자리() {
        // 어절 첫머리의 조사에는 보너스가 아니라 벌점이 걸린다. 두 규칙이 한 자리에서
        // 부딪히면 안 되므로, 첫머리 조사가 보너스로 되살아나지 않는지 못을 박는다.
        let 결과 = Segmenter.segment("도코에", in: Self.첫머리사전,
                                    boundPenalty: 40, junctionBonus: 40)
        #expect(결과.filter { !$0.isWhole }.map(\.hangul) == ["도코", "에"])
    }

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

    // MARK: 쓰는 대로와 읽는 대로가 다른 조사

    @Test("조사 は 를 `와` 로 쳐도 나온다")
    func 주제조사() {
        // 사전에는 `は` 로 실리고 사람은 `와` 로 친다. 이 사이가 벌어져 있어서
        // `와타시와` 가 `私 わ`(종조사 "~네")로 끊겼고, 문장 뜻이 딴것이 됐다.
        let 결과 = Segmenter.segment("와타시와", in: Self.조사사전)
        #expect(결과.map(\.hangul) == ["와타시", "와"])
        #expect(결과.last?.results.first?.entry.writings.first?.text == "は")
    }

    @Test("조사가 빠지면 없는 낱말이 만들어진다")
    func 조사가없으면() {
        // 조사 `は` 가 없으면 남은 `와` 가 뒷글자와 붙어 `和本`(일본 고서)이 된다.
        // 조각 하나가 틀리는 것이 아니라 문장이 딴 문장이 되는 자리다.
        let 결과 = Segmenter.segment("코레와혼데스", in: Self.조사사전)
        #expect(결과.map(\.hangul) == ["코레", "와", "혼", "데스"])
        #expect(!결과.contains { $0.results.first?.entry.writings.first?.text == "和本" })
    }

    @Test("조사 へ 를 `에` 로 쳐도 나온다")
    func 방향조사() {
        #expect(Segmenter.segment("우치에", in: Self.조사사전).map(\.hangul) == ["우치", "에"])
        // `니혼에` 는 조사가 없을 때 `に 本営` 로 앞에서부터 어긋나던 문장이다.
        #expect(Segmenter.segment("니혼에", in: Self.조사사전).map(\.hangul) == ["니혼", "에"])
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
