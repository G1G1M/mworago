import Testing
@testable import MworagoCore

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
}
