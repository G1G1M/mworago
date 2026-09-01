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

    @Test("장음부호로 실린 외래어를 장음 없는 음차로도 찾는다")
    func 장음부호표제어() throws {
        let xml = """
        <JMdict><entry><ent_seq>1</ent_seq>
        <r_ele><reb>コート</reb></r_ele>
        <sense><gloss>coat</gloss></sense>
        </entry></JMdict>
        """
        let index = DictIndex(entries: try JMDictParser.parse(xml: xml))
        // 규칙이 만드는 후보는 히라가나에 장음을 지어낸 꼴이다. 조회 키가 장음 표기를
        // 접지 않으면 `こーと` 와 `こうと` 는 영영 만나지 못한다.
        #expect(index.lookup("こうと").first?.reading == "コート")
        #expect(index.lookup("コート").first?.reading == "コート")
        // 장음을 지우면 다른 낱말이다 — 여기까지 뭉개지면 안 된다
        #expect(index.lookup("こと").isEmpty)
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

/// 사용역 꼬리표 — **써도 되는 말인가.**
///
/// 이 앱의 빈도표는 애니 자막 말뭉치라 "얼마나 흔한가"라는 축이 이미 애니다.
/// 그러나 애니에 흔한 것과 일상에서 써도 되는 것은 다르다 — `貴様` 는 애니에 넘치지만
/// 사람에게 쓰면 싸움이 난다. 그 판단을 **모델에게 묻지 않는다.** 사전이 이미 알고 있다.
///
/// `arch`(고어) 3,799 · `col`(구어) 2,506 · `sl`(속어) 1,406 · `hon`(존경) 749 ·
/// `derog`(경멸) 477 · `vulg`(비속) 238 … 파서가 `misc` 를 이미 읽으면서 `uk` 만
/// 쓰고 나머지를 버리고 있었다.
@Suite("사용역 꼬리표")
struct JMDictUsageTests {

    /// 뜻갈래가 하나인 표제항. 그 뜻에 붙은 꼬리표가 곧 낱말의 꼬리표다.
    @Test("사전이 붙인 꼬리표를 읽는다")
    func 꼬리표읽기() throws {
        let xml = """
        <JMdict><entry>
        <r_ele><reb>きさま</reb></r_ele>
        <k_ele><keb>貴様</keb></k_ele>
        <sense><pos>&pn;</pos><misc>&derog;</misc><misc>&male;</misc>
        <gloss>you</gloss></sense>
        </entry></JMdict>
        """
        let entry = try JMDictParser.parse(xml: xml).first
        #expect(entry?.usageTags == ["derog", "male"])
    }

    /// **첫 뜻갈래의 것만 쓴다.**
    ///
    /// 꼬리표는 표제항이 아니라 **뜻마다** 붙는다. 다 합치면 흔한 낱말이 엉뚱한 딱지를
    /// 단다 — `い` 가 비속어가 되고 `見` 이 존경어가 된다. 어느 뜻의 꼬리표인지 화면에서
    /// 가릴 방법이 없으므로, 사용자가 보는 첫 뜻의 것만 남긴다.
    /// `loadJobs` 가 `でも`/`デモ` 를 가르는 것과 같은 종류의 조심이다.
    @Test("둘째 뜻갈래의 꼬리표는 딸려오지 않는다")
    func 첫뜻만() throws {
        let xml = """
        <JMdict><entry>
        <r_ele><reb>かみ</reb></r_ele>
        <k_ele><keb>紙</keb></k_ele>
        <sense><gloss>paper</gloss></sense>
        <sense><misc>&sl;</misc><gloss>awesome</gloss></sense>
        </entry></JMdict>
        """
        let entry = try JMDictParser.parse(xml: xml).first
        #expect(entry?.usageTags.isEmpty == true)
    }

    /// `uk` 는 사용역이 아니라 표기 규칙이라 이미 제 자리가 있다. 두 번 세지 않는다.
    @Test("uk 는 꼬리표에 섞이지 않는다")
    func uk는따로() throws {
        let xml = """
        <JMdict><entry>
        <r_ele><reb>やめる</reb></r_ele>
        <k_ele><keb>止める</keb></k_ele>
        <sense><misc>&uk;</misc><misc>&col;</misc><gloss>to stop</gloss></sense>
        </entry></JMdict>
        """
        let entry = try JMDictParser.parse(xml: xml).first
        #expect(entry?.usuallyKana == true)
        #expect(entry?.usageTags == ["col"])
    }

    @Test("꼬리표가 없는 낱말은 비어 있다")
    func 없으면빈것() throws {
        let xml = """
        <JMdict><entry>
        <r_ele><reb>やくそく</reb></r_ele><k_ele><keb>約束</keb></k_ele>
        <sense><pos>&n;</pos><gloss>promise</gloss></sense>
        </entry></JMdict>
        """
        #expect(try JMDictParser.parse(xml: xml).first?.usageTags.isEmpty == true)
    }

    /// 색인을 거쳐도 살아남아야 한다. 파서만 읽고 색인이 안 실으면 화면에는 없는 것이다.
    @Test("색인에 굽고 다시 읽어도 남는다")
    func 색인왕복() throws {
        let path = NSTemporaryDirectory() + "mworago-usage-\(UUID().uuidString).db"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let entry = DictEntry(readings: [DictForm(text: "きさま", priority: 0)],
                              writings: [DictForm(text: "貴様", priority: 0)],
                              glosses: ["you"],
                              usageTags: ["derog", "male"])
        try DictionaryStore.build(entries: [entry], at: path)
        let store = try DictionaryStore(path: path)
        #expect(store.lookup("きさま").first?.entry.usageTags == ["derog", "male"])
    }
}
