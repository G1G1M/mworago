import Testing
@testable import MworagoDomain
@testable import MworagoUseCases

@Suite("도메인 빈도")
struct FrequencyListTests {

    // JPDB 배포본과 같은 모양. 탭 구분, frequency는 순위(작을수록 흔함).
    static let sample = """
    term\treading\tfrequency\tkana_frequency
    次\tつぎ\t201\t
    痛い\tいたい\t592\t
    町\tまち\t793\t
    遺体\tいたい\t4680\t
    突き\tつき\t9038\t
    """

    @Test("표기와 읽기 둘 다 맞아야 그 낱말이다")
    func 조회() {
        let list = FrequencyList(tsv: Self.sample)
        #expect(list.rank(writing: "痛い", reading: "いたい") == 592)
        #expect(list.rank(writing: "遺体", reading: "いたい") == 4680)
        #expect(list.rank(writing: "痛い", reading: "つう") == nil)   // 읽기가 다르면 딴 낱말
        #expect(list.rank(writing: "無い", reading: "ない") == nil)
    }

    @Test("한자 표기가 없으면 읽기만으로 찾는다")
    func 가나낱말() {
        let list = FrequencyList(tsv: "term\treading\tfrequency\nやめる\tやめる\t230\n")
        #expect(list.rank(writing: nil, reading: "やめる") == 230)
    }

    @Test("순위가 앞설수록 점수가 높다")
    func 점수변환() {
        let list = FrequencyList(tsv: Self.sample)
        let 痛い = list.score(writing: "痛い", reading: "いたい")
        let 遺体 = list.score(writing: "遺体", reading: "いたい")
        #expect(痛い > 遺体, "애니에서는 아픈 게 유체보다 흔하다")

        let 次 = list.score(writing: "次", reading: "つぎ")
        let 突き = list.score(writing: "突き", reading: "つき")
        #expect(次 > 突き)
    }

    @Test("목록에 없는 낱말은 가장 낮은 점수")
    func 미등재() {
        let list = FrequencyList(tsv: Self.sample)
        #expect(list.score(writing: "蠱", reading: "まじ") == 0)
        #expect(list.score(writing: "次", reading: "つぎ") > 0)
    }

    @Test("사전에 활용형으로 실린 낱말은 사전형의 빈도를 물려받는다")
    func 활용형빈도() {
        // 빈도 목록에는 사전형만 있다. 疲れた가 0점이면 疲れる에게 부당하게 진다.
        let list = FrequencyList(tsv: "term\treading\tfrequency\n疲れる\tつかれる\t1500\n")
        let 활용형 = DictEntry(readings: [DictForm(text: "つかれた", priority: 0)],
                            writings: [DictForm(text: "疲れた", priority: 0)],
                            glosses: [])
        #expect(Ranker.domainScore(활용형, reading: "つかれた", in: list) > 0)
    }

    @Test("빈 목록이면 아무 점수도 주지 않는다")
    func 빈목록() {
        // 빈도 파일 없이도 검색은 돌아가야 한다 — 이 층은 선택 사항이다
        let list = FrequencyList(tsv: "")
        #expect(list.isEmpty)
        #expect(list.score(writing: "次", reading: "つぎ") == 0)
    }

    @Test("표기만으로 찾는 길을 따로 둔다")
    func 표기조회() {
        // 빈도를 세는 쪽이 何 를 늘 なん 으로 읽으면 なに 항목이 없다.
        // 그래도 何 라는 낱말이 흔하다는 사실은 알려 줄 수 있다.
        // 다만 그 읽기가 정말 그 낱말의 읽기인지는 사전만 안다 — 여기서는 묻지 않는다.
        let list = FrequencyList(tsv: "term\treading\tfrequency\n何\tなん\t23\n")
        #expect(list.rank(writing: "何", reading: "なに") == nil)   // 정확 조회는 여전히 엄격하다
        #expect(list.rankByWriting("何") == 23)
        #expect(list.rankByWriting("痛い") == nil)
    }
}

@Suite("빈도표의 외래어")
struct FrequencyKatakanaTests {

    /// 빈도를 센 쪽은 외래어를 `표기=가타카나 · 읽기=히라가나` 로 싣는데 사전은 읽기까지
    /// 가타카나로 싣는다. 글자가 어긋나 조회가 빗나가면 가타카나 낱말이 통째로 0점이 된다.
    static let tsv = """
        term\treading\tfrequency\tcount
        ブラシ\tぶらし\t6667\t194
        コート\tこおと\t2977\t536
        """

    @Test("사전이 든 가타카나 읽기로도 찾는다")
    func 가타카나읽기() {
        let list = FrequencyList(tsv: Self.tsv)
        // 사전은 ブラシ 의 읽기를 ブラシ 로 싣는다. 표기가 없는 낱말이라 읽기로 찾는데,
        // 빈도표의 읽기 칸은 히라가나(ぶらし)다. 그 사이가 이어져야 한다.
        //
        // 표기 칸은 접지 않는다 — 그쪽은 한자가 오는 자리이고, 사전과 빈도표가
        // 외래어를 똑같이 가타카나로 적으므로 이미 맞는다.
        #expect(list.score(writing: nil, reading: "ブラシ") > 0)
    }

    @Test("장음을 달리 적어도 만난다")
    func 장음() {
        let list = FrequencyList(tsv: Self.tsv)
        // 빈도표는 こおと 로, 사전은 コート 로 적는다. 같은 낱말이다.
        #expect(list.score(writing: nil, reading: "コート") > 0)
    }

    @Test("없는 낱말은 그대로 0점")
    func 없는것() {
        #expect(FrequencyList(tsv: Self.tsv).score(writing: nil, reading: "すし") == 0)
    }
}
