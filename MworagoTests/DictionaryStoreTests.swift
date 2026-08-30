import Testing
import Foundation
@testable import MworagoCore

@Suite("사전 색인 파일")
struct DictionaryStoreTests {

    static let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE JMdict [
    <!ENTITY uk "word usually written using kana alone">
    <!ENTITY sK "search-only kanji form">
    ]>
    <JMdict>
    <entry>
    <k_ele><keb>大丈夫</keb><ke_pri>ichi1</ke_pri><ke_pri>nf05</ke_pri></k_ele>
    <r_ele><reb>だいじょうぶ</reb><re_pri>ichi1</re_pri><re_pri>nf05</re_pri></r_ele>
    <r_ele><reb>だいじょぶ</reb></r_ele>
    <sense><gloss>safe</gloss><gloss>all right</gloss></sense>
    </entry>
    <entry>
    <k_ele><keb>止める</keb></k_ele>
    <k_ele><keb>已める</keb><ke_inf>&sK;</ke_inf></k_ele>
    <r_ele><reb>やめる</reb></r_ele>
    <sense><misc>&uk;</misc><gloss>to stop</gloss></sense>
    </entry>
    <entry>
    <r_ele><reb>ポイント</reb></r_ele>
    <sense><gloss>point</gloss></sense>
    </entry>
    </JMdict>
    """

    /// 임시 파일에 색인을 굽고 돌려준다.
    static func 색인(_ 이름: String = #function) throws -> (store: DictionaryStore, path: String) {
        let path = NSTemporaryDirectory() + "mworago-test-\(UUID().uuidString).db"
        let entries = try JMDictParser.parse(xml: sample)
        try DictionaryStore.build(entries: entries, at: path)
        return (try DictionaryStore(path: path), path)
    }

    @Test("구운 색인을 읽기로 조회한다")
    func 조회() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let hits = store.lookup("だいじょうぶ")
        #expect(hits.count == 1)
        #expect(hits.first?.entry.headword == "大丈夫")
        #expect(hits.first?.priority ?? 0 > 0)
        #expect(hits.first?.entry.glosses.first == "safe")
    }

    @Test("읽기별 점수가 색인에도 따로 남는다")
    func 읽기별점수() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        #expect(store.lookup("だいじょうぶ").first?.priority ?? 0 > 0)
        #expect(store.lookup("だいじょぶ").first?.priority == 0)
    }

    @Test("uk 와 희귀 표기 표시가 살아남는다")
    func 표지보존() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let entry = try #require(store.lookup("やめる").first?.entry)
        #expect(entry.usuallyKana)
        #expect(entry.usableWritings.map(\.text) == ["止める"])   // 已める는 검색 전용
    }

    @Test("가타카나 표제어는 히라가나로 찾고 원래 표기로 돌려준다")
    func 가타카나() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let hit = try #require(store.lookup("ぽいんと").first)
        #expect(hit.reading == "ポイント")
    }

    @Test("없는 읽기는 빈 결과")
    func 없는읽기() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(store.lookup("ありがとう").isEmpty)
    }

    @Test("메모리 색인과 같은 답을 준다")
    func 동등성() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }
        let memory = DictIndex(entries: try JMDictParser.parse(xml: Self.sample))

        for reading in ["だいじょうぶ", "だいじょぶ", "やめる", "ぽいんと", "없음"] {
            let a = store.lookup(reading).map(\.entry.headword)
            let b = memory.lookup(reading).map(\.entry.headword)
            #expect(a == b, "읽기 \(reading)")
        }
    }

    @Test("표제항의 읽기를 전부 되살린다")
    func 읽기전부() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        // 매칭된 하나만 남기면 표기 없는 낱말의 headword 가 달라지고 빈도 조회도 어긋난다
        let entry = try #require(store.lookup("だいじょぶ").first?.entry)
        #expect(entry.readings.map(\.text) == ["だいじょうぶ", "だいじょぶ"])
    }

    @Test("한국어 뜻을 구워 넣고 꺼낸다")
    func 한국어뜻() throws {
        let path = NSTemporaryDirectory() + "mworago-korean-\(UUID().uuidString).db"
        defer { try? FileManager.default.removeItem(atPath: path) }

        let entries = try JMDictParser.parse(xml: Self.sample)
        try DictionaryStore.build(entries: entries, at: path,
                                  koreanGlosses: ["大丈夫\tだいじょうぶ": "괜찮다"])
        let store = try DictionaryStore(path: path)

        let entry = try #require(store.lookup("だいじょうぶ").first?.entry)
        #expect(entry.koreanGloss == "괜찮다")
        #expect(entry.displayGloss == "괜찮다")   // 한국어가 있으면 그것이 먼저다
    }

    @Test("한국어 뜻이 없으면 영어가 남는다")
    func 뜻없음() throws {
        let (store, path) = try Self.색인()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let entry = try #require(store.lookup("だいじょうぶ").first?.entry)
        #expect(entry.koreanGloss == nil)
        #expect(entry.displayGloss == "safe · all right")
    }
}
