import Testing
import Foundation
@testable import MworagoCore

@Suite("JMdict 파싱")
struct JMDictTests {

    // JMdict 실물에서 잘라온 모양. 빈도 태그가 읽기마다 따로 붙는 것이 핵심이다.
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
        #expect(대장부.writings.map(\.text) == ["大丈夫"])
        #expect(대장부.readings.map(\.text) == ["だいじょうぶ", "だいじょぶ"])
        #expect(대장부.glosses.first == "safe")
    }

    @Test("한자 표기가 없는 낱말도 살린다")
    func 가나전용() throws {
        let entries = try JMDictParser.parse(xml: Self.sample)
        #expect(entries[1].writings.isEmpty)
        #expect(entries[1].readings.map(\.text) == ["やばい"])
    }

    @Test("빈도 점수는 읽기마다 따로 매겨진다")
    func 읽기별점수() throws {
        let 대장부 = try JMDictParser.parse(xml: Self.sample)[0]
        // だいじょうぶ에만 태그가 붙어 있다. 이표기 だいじょぶ가 그 명성을 물려받으면 안 된다.
        #expect(대장부.readings[0].priority > 0)
        #expect(대장부.readings[1].priority == 0)
    }

    @Test("색인은 매칭된 읽기의 점수를 함께 돌려준다")
    func 색인점수() throws {
        let index = DictIndex(entries: try JMDictParser.parse(xml: Self.sample))

        let 주읽기 = try #require(index.lookup("だいじょうぶ").first)
        #expect(주읽기.entry.writings.map(\.text) == ["大丈夫"])
        #expect(주읽기.priority > 0)

        // 같은 항목이지만 부차적 읽기로 찾으면 점수는 0이어야 한다
        let 부읽기 = try #require(index.lookup("だいじょぶ").first)
        #expect(부읽기.entry.writings.map(\.text) == ["大丈夫"])
        #expect(부읽기.priority == 0)

        #expect(index.lookup("ありがとう").isEmpty)
    }

    @Test("가타카나 표제어도 히라가나 후보로 찾힌다")
    func 가타카나표제어() throws {
        let xml = """
        <JMdict><entry><ent_seq>1</ent_seq>
        <r_ele><reb>ポイント</reb></r_ele>
        <sense><gloss>point</gloss></sense>
        </entry></JMdict>
        """
        let index = DictIndex(entries: try JMDictParser.parse(xml: xml))
        let hit = try #require(index.lookup("ぽいんと").first)
        #expect(hit.reading == "ポイント")
    }

    @Test("가나로 쓰는 낱말(uk)과 검색 전용 표기(sK)를 읽는다")
    func 표지읽기() throws {
        // XMLParser 는 내부 DTD 엔티티를 확장하지 않는다. 그냥 두면 이 정보가 통째로 사라진다.
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE JMdict [
        <!ENTITY uk "word usually written using kana alone">
        <!ENTITY sK "search-only kanji form">
        ]>
        <JMdict><entry><ent_seq>1</ent_seq>
        <k_ele><keb>止める</keb></k_ele>
        <k_ele><keb>乃</keb><ke_inf>&sK;</ke_inf></k_ele>
        <r_ele><reb>やめる</reb></r_ele>
        <sense><misc>&uk;</misc><gloss>to stop</gloss></sense>
        </entry></JMdict>
        """
        let entry = try #require(JMDictParser.parse(xml: xml).first)
        #expect(entry.usuallyKana)
        #expect(entry.writings.count == 2)
        #expect(entry.usableWritings.map(\.text) == ["止める"])   // 乃 는 검색 전용이라 빠진다
    }
}
