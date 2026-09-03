import Testing
import Foundation
@testable import MworagoDomain
@testable import MworagoUseCases

/// 1위 다음에 곁들이는 후보들.
///
/// 1위가 정답인 비율은 94%지만 3위 안에 있을 비율은 98%다. 그 4%를 사용자가
/// 직접 고르게 하려고 대안을 곁에 둔다. 그러려면 대안이 **1위와 달라 보여야** 한다.
@Suite("대안 후보")
struct AlternatesTests {

    static func 결과(_ 표기: String, _ 읽기: String, _ 뜻: String, score: Double = 0) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: [뜻])
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 읽기,
                            deinflection: nil, score: score)
    }

    @Test("1위와 표기·읽기가 같은 후보는 뺀다")
    func 같은낱말() {
        // JMdict 는 뜻갈래가 갈리면 항목을 나누어 싣는다. 大丈夫 는 형용동사와 명사로
        // 두 번 실려 있어, 그대로 늘어놓으면 화면에 같은 낱말이 두 번 보인다.
        // 사용자가 고르려는 것은 뜻갈래가 아니라 **다른 낱말**이다.
        let segment = Segment(hangul: "다이죠부", results: [
            Self.결과("大丈夫", "だいじょうぶ", "safe, secure"),
            Self.결과("大丈夫", "だいじょうぶ", "safe"),
            Self.결과("大慈父", "だいじょうぶ", "merciful father"),
        ])
        #expect(segment.alternates().map(\.headword) == ["大慈父"])
    }

    @Test("대안끼리 겹치는 것도 한 번만 남는다")
    func 대안중복() {
        let segment = Segment(hangul: "카타", results: [
            Self.결과("方", "かた", "way"),
            Self.결과("肩", "かた", "shoulder"),
            Self.결과("肩", "かた", "shoulder blade"),
            Self.결과("型", "かた", "mold"),
        ])
        #expect(segment.alternates().map(\.headword) == ["肩", "型"])
    }

    @Test("표제항이 다르면 표기가 같아도 다른 낱말이다")
    func 다른표제항() {
        // 机 는 つくえ 로도 つき 로도 읽히는데, JMdict 는 이 둘을 따로 싣는다.
        // 사전이 나누어 실은 것은 나누어 보인다.
        let segment = Segment(hangul: "츠쿠에", results: [
            Self.결과("机", "つくえ", "desk"),
            Self.결과("机", "つき", "desk (archaic)"),
        ])
        #expect(segment.alternates().map(\.reading) == ["つき"])
    }

    @Test("같은 표제항의 이표기는 한 낱말이다")
    func 이표기() {
        // 大丈夫 는 표제항 하나에 だいじょうぶ·だいじょぶ 두 읽기를 단다.
        // "다이죠부" 는 두 읽기를 다 만들어 내므로 결과가 둘로 늘어나는데,
        // 화면에는 大丈夫 가 두 번 보일 뿐이다 — 사전이 한 낱말로 실은 것은 한 낱말이다.
        let entry = DictEntry(readings: [DictForm(text: "だいじょうぶ", priority: 64),
                                         DictForm(text: "だいじょぶ", priority: 0)],
                              writings: [DictForm(text: "大丈夫", priority: 64)],
                              glosses: ["safe", "secure"])
        let segment = Segment(hangul: "다이죠부", results: [
            SearchResult(entry: entry, reading: "だいじょうぶ", matchedKana: "だいじょうぶ",
                         deinflection: nil, score: 100),
            SearchResult(entry: entry, reading: "だいじょぶ", matchedKana: "だいじょぶ",
                         deinflection: nil, score: 40),
        ])
        #expect(segment.alternates().isEmpty)
    }

    @Test("몇 개까지 보일지는 부르는 쪽이 정한다")
    func 개수제한() {
        let segment = Segment(hangul: "카타", results: [
            Self.결과("方", "かた", "way"),
            Self.결과("肩", "かた", "shoulder"),
            Self.결과("型", "かた", "mold"),
            Self.결과("片", "かた", "one side"),
        ])
        #expect(segment.alternates(limit: 2).count == 2)
        #expect(segment.alternates(limit: 10).count == 3)
    }

    @Test("결과가 하나뿐이면 대안은 없다")
    func 하나뿐() {
        let segment = Segment(hangul: "야쿠소쿠", results: [Self.결과("約束", "やくそく", "promise")])
        #expect(segment.alternates().isEmpty)
    }

    @Test("찾지 못한 조각도 죽지 않는다")
    func 빈결과() {
        #expect(Segment(hangul: "쿄로쿄로", results: []).alternates().isEmpty)
    }
}
