import Testing
@testable import MworagoCore

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
