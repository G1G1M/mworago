import Testing
@testable import MworagoDomain
@testable import MworagoUseCases

@Suite("검색 결과 줄 세우기")
struct RankerTests {

    /// 테스트용 작은 사전. (표기, 읽기, 그 읽기의 점수)
    static func 사전(_ 항목들: [(String, String, Int)]) -> DictIndex {
        DictIndex(entries: 항목들.map { 표기, 읽기, 점수 in
            DictEntry(readings: [DictForm(text: 읽기, priority: 점수)],
                      writings: [DictForm(text: 표기, priority: 0)],
                      glosses: [])
        })
    }

    /// 표기·읽기 우선순위를 따로 줄 수 있는 사전. 사전이 "이 읽기는 흔하다"고
    /// 표시했는지가 순위를 가르는 자리가 있어서(`말뭉치가_읽기를_다르게_이름_붙여도_흔한_낱말이_위로`)
    /// 그것을 시험하려면 두 값을 갈라 주어야 한다.
    static func 사전(표기우선순위: [(String, String, Int, Int)]) -> DictIndex {
        DictIndex(entries: 표기우선순위.map { 표기, 읽기, 읽기점수, 표기점수 in
            DictEntry(readings: [DictForm(text: 읽기, priority: 읽기점수)],
                      writings: [DictForm(text: 표기, priority: 표기점수)],
                      glosses: [])
        })
    }

    /// 품사까지 달아 만드는 사전. (표기, 읽기, 점수, 품사 태그)
    static func 사전(품사: [(String, String, Int, [String])]) -> DictIndex {
        DictIndex(entries: 품사.map { 표기, 읽기, 점수, 태그 in
            DictEntry(readings: [DictForm(text: 읽기, priority: 점수)],
                      writings: [DictForm(text: 표기, priority: 0)],
                      glosses: [], partsOfSpeech: 태그)
        })
    }

    @Test("명사와 부사에는 활용을 되돌려 붙이지 않는다")
    func 활용하지_않는_갈래() {
        // `도코에`(どこへ, 어디로)의 맨 위 카드에 `同校`(같은 학교)가 떴다 —
        // 어미 `え` 를 5단 명령형으로 보고 되돌려 만든 `どうこう` 에 명사가 걸린 것이다.
        // 명사를 막자 이번에는 같은 자리에 부사 `如何斯う`(이러쿵저러쿵)가 섰다.
        // 둘 다 활용하지 않는 갈래이므로, 걸렸다면 뜻이 아니라 글자가 맞은 것이다.
        let index = Self.사전(품사: [
            ("同校", "どうこう", 100, ["n"]),
            ("如何斯う", "どうこう", 100, ["adv"]),
            ("問う", "とう", 100, ["v5u"]),
        ])
        let 결과 = Ranker.search("도코에", in: index)
        #expect(결과.contains { $0.headword == "同校" } == false)
        #expect(결과.contains { $0.headword == "如何斯う" } == false)

        // 동사는 그대로 걸린다 — 활용하는 갈래다.
        let 동사 = Ranker.search("토에", in: index)
        #expect(동사.contains { $0.headword == "問う" && $0.deinflection != nil })
    }

    @Test("말뭉치가 읽기를 다르게 이름 붙여도 흔한 낱말이 위로")
    func 표기로_물려받은_빈도() {
        // **실제로 났던 일이다.** 자막 말뭉치가 `私` 를 `わたくし`(19위·148,210회)로만
        // 싣고 `わたし` 항목을 두지 않았다. 그래서 `私`+`わたし` 조회가 빈손이 되고,
        // 표기만으로 물려받은 점수가 벌점(0.6배)을 맞아 `渡し`(도선, 1103위·1,622회)
        // 에게 졌다. `와타시와칸코쿠진데쓰` 가 `渡しは韓国人です` 로 되살아나
        // 화면에는 "전달은 한국인입니다"가 떴다 — 91배 흔한 낱말이 규칙에 밀린 것이다.
        //
        // 사전은 알고 있었다. JMdict 가 `私` 의 `わたし` 읽기에 우선 표시를 달아 두었다.
        // 그 표시가 있으면 물려받은 점수를 깎지 않는다.
        let index = Self.사전(표기우선순위: [
            ("私", "わたし", 69, 69),     // 사전이 흔하다고 표시한 읽기
            ("渡し", "わたし", 39, 39),
        ])
        let frequency = FrequencyList(tsv: """
        term\treading\trank\tcount
        私\tわたくし\t19\t148210
        渡し\tわたし\t1103\t1622
        """)
        let 결과 = Ranker.search("와타시", in: index, frequency: frequency)
        #expect(결과.first?.entry.headword == "私")
    }

    @Test("흔한 낱말이 위로")
    func 빈도순() {
        let index = Self.사전([("痛い", "いたい", 100), ("異体", "いたい", 0)])
        let 결과 = Ranker.search("이타이", in: index)
        #expect(결과.first?.entry.headword == "痛い")
    }

    @Test("점수가 같으면 규칙이 먼저 낸 후보가 위")
    func 후보순서() {
        // 스고이 → すごい(0순위) · すごうい 같은 장음 변형(뒤 순위)
        let index = Self.사전([("凄い", "すごい", 0), ("素五位", "すごうい", 0)])
        let 결과 = Ranker.search("스고이", in: index)
        #expect(결과.first?.entry.headword == "凄い")
    }

    @Test("점수가 같으면 장음을 덜 넣은 후보가 위")
    func 장음페널티() {
        // 요캇타 → よかった(장음 0개) → よい / ようかった(장음 1개) → ようい
        // 한글 음차에 없던 글자를 더 많이 지어낸 쪽이 덜 그럴듯하다.
        let index = Self.사전([("良い", "よい", 100), ("容易", "ようい", 100)])
        let 결과 = Ranker.search("요캇타", in: index)
        #expect(결과.first?.entry.headword == "良い")
    }

    @Test("장음을 몇 개 넣었는지 후보가 스스로 알고 있다")
    func 장음개수() {
        let 후보 = Transliterator.candidates(for: "아리가토")
        let 장음없음 = 후보.first { $0.kana == "ありがと" }
        let 장음하나 = 후보.first { $0.kana == "ありがとう" }
        #expect(장음없음?.longVowelsAdded == 0)
        #expect(장음하나?.longVowelsAdded == 1)
    }

    @Test("사전에 그대로 실린 형태가 활용 복원보다 위")
    func 등재형우선() {
        // 빈도 목록이 있으면 疲れた 도 疲れる 의 빈도를 물려받아 동점이 된다.
        // 그다음은 활용을 되돌렸는지가 가른다 — 그대로 실린 쪽이 확실한 답이다.
        let index = Self.사전([("疲れた", "つかれた", 0), ("疲れる", "つかれる", 50)])
        let frequency = FrequencyList(tsv: "term\treading\tfrequency\n疲れる\tつかれる\t1500\n")
        let 결과 = Ranker.search("츠카레타", in: index, frequency: frequency)
        #expect(결과.first?.entry.headword == "疲れた")
        #expect(결과.first?.deinflection == nil)
    }

    @Test("활용을 되돌렸으면 무엇을 되돌렸는지 알려준다")
    func 활용이름() {
        let index = Self.사전([("止める", "やめる", 20)])
        let 결과 = Ranker.search("야메로", in: index)
        #expect(결과.first?.deinflection == "명령형")
        #expect(결과.first?.matchedKana == "やめろ")
    }

    @Test("사전에 없으면 빈 결과")
    func 없는말() {
        #expect(Ranker.search("스고이", in: Self.사전([])).isEmpty)
    }
}
