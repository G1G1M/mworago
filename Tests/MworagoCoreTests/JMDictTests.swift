import Testing
import Foundation
@testable import MworagoCore

@Suite("JMdict 파싱")
struct JMDictTests {

    // JMdict 실물에서 잘라온 모양. 엔티티(&adj-na;)와 빈도 태그(nf05)까지 그대로 둔다.
    static let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE JMdict [
    <!ENTITY adj-na "adjectival nouns or quasi-adjectives">
    ]>
    <JMdict>
    <entry>
    <ent_seq>1414150</ent_seq>
    <k_ele><keb>大丈夫</keb><ke_pri>ichi1</ke_pri><ke_pri>news1</ke_pri><ke_pri>nf05</ke_pri></k_ele>
    <r_ele><reb>だいじょうぶ</reb><re_pri>ichi1</re_pri><re_pri>nf05</re_pri></r_ele>
    <r_ele><reb>だいじょぶ</reb></r_ele>
    <sense><pos>&adj-na;</pos><gloss>safe</gloss><gloss>all right</gloss></sense>
    </entry>
    <entry>
    <ent_seq>2000001</ent_seq>
    <r_ele><reb>やばい</reb></r_ele>
    <sense><gloss>dangerous</gloss></sense>
    </entry>
    </JMdict>
    """

    @Test("표기·읽기·뜻을 뽑는다")
    func 기본파싱() throws {
        let entries = try JMDictParser.parse(xml: Self.sample)
        #expect(entries.count == 2)

        let 대장부 = entries[0]
        #expect(대장부.writings == ["大丈夫"])
        #expect(대장부.readings == ["だいじょうぶ", "だいじょぶ"])
        #expect(대장부.glosses.first == "safe")
    }

    @Test("한자 표기가 없는 낱말도 살린다")
    func 가나전용() throws {
        let entries = try JMDictParser.parse(xml: Self.sample)
        #expect(entries[1].writings.isEmpty)
        #expect(entries[1].readings == ["やばい"])
    }

    @Test("빈도 태그가 있으면 점수가 높다")
    func 빈도점수() throws {
        let entries = try JMDictParser.parse(xml: Self.sample)
        #expect(entries[0].priority > entries[1].priority)
        #expect(entries[1].priority == 0)   // 태그가 없으면 0점
    }

    @Test("읽기로 찾는 색인")
    func 색인조회() throws {
        let index = DictIndex(entries: try JMDictParser.parse(xml: Self.sample))
        #expect(index.lookup("だいじょうぶ").first?.writings == ["大丈夫"])
        #expect(index.lookup("だいじょぶ").first?.writings == ["大丈夫"])   // 이표기도 같은 항목으로
        #expect(index.lookup("ありがとう").isEmpty)
    }
}
