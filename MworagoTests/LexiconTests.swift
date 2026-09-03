import Testing
import Foundation
@testable import MworagoCore

@Suite("검색 재료 한 벌")
struct LexiconTests {

    /// 무엇이 어디 있다고 대답할지 시험이 정한다.
    ///
    /// 이것이 있어야 하는 까닭이 이 시험의 전부다 — 예전에는 재료를 여는 자리가
    /// `Bundle.main` 을 직접 뒤져서, 앱을 세우지 않고는 그 길을 한 번도 밟을 수 없었다.
    struct FakeLocator: ResourceLocating {
        var files: [String: String] = [:]
        func path(forResource name: String, ofType ext: String) -> String? {
            files["\(name).\(ext)"]
        }
    }

    static let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE JMdict [
    <!ENTITY n "noun">
    ]>
    <JMdict>
    <entry>
    <k_ele><keb>大丈夫</keb></k_ele>
    <r_ele><reb>だいじょうぶ</reb></r_ele>
    <sense><pos>&n;</pos><gloss>safe</gloss></sense>
    </entry>
    </JMdict>
    """

    /// 임시 자리에 색인을 굽고 경로를 돌려준다. 쓰고 나면 지운다.
    static func bakedIndex() throws -> String {
        let path = NSTemporaryDirectory() + "mworago-lexicon-\(UUID().uuidString).db"
        try DictionaryStore.build(entries: try JMDictParser.parse(xml: sample), at: path)
        return path
    }

    static func writtenFile(_ contents: String, ext: String) throws -> String {
        let path = NSTemporaryDirectory() + "mworago-lexicon-\(UUID().uuidString).\(ext)"
        try contents.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    @Test("사전과 빈도가 다 있으면 둘 다 들고 열린다")
    func 둘다() throws {
        let dict = try Self.bakedIndex()
        let freq = try Self.writtenFile("term\treading\tfrequency\n大丈夫\tだいじょうぶ\t12\n", ext: "tsv")
        defer {
            try? FileManager.default.removeItem(atPath: dict)
            try? FileManager.default.removeItem(atPath: freq)
        }

        let lexicon = try Lexicon(locating: FakeLocator(files: [
            "mworago-dict.db": dict,
            "jesc_freq.tsv": freq,
        ]))

        #expect(lexicon.dictionary.lookup("だいじょうぶ").first?.entry.headword == "大丈夫")
        #expect(lexicon.frequency?.count == 1)
    }

    @Test("빈도가 없어도 열린다 — 순위만 신문 기준으로 밀린다")
    func 빈도없음() throws {
        let dict = try Self.bakedIndex()
        defer { try? FileManager.default.removeItem(atPath: dict) }

        let lexicon = try Lexicon(locating: FakeLocator(files: ["mworago-dict.db": dict]))

        #expect(lexicon.frequency == nil)
        #expect(!lexicon.dictionary.lookup("だいじょうぶ").isEmpty)
    }

    @Test("빈도 파일이 비어 있으면 없는 셈 친다")
    func 빈빈도() throws {
        let dict = try Self.bakedIndex()
        // 헤더만 있고 줄이 없다. 굽다 만 파일이 실려도 순위가 전부 0점이 되면 안 된다.
        let freq = try Self.writtenFile("term\treading\tfrequency\n", ext: "tsv")
        defer {
            try? FileManager.default.removeItem(atPath: dict)
            try? FileManager.default.removeItem(atPath: freq)
        }

        let lexicon = try Lexicon(locating: FakeLocator(files: [
            "mworago-dict.db": dict,
            "jesc_freq.tsv": freq,
        ]))

        #expect(lexicon.frequency == nil)
    }

    @Test("사전이 없으면 무엇이 없는지 말한다")
    func 사전없음() throws {
        #expect(throws: Lexicon.LoadError.self) {
            _ = try Lexicon(locating: FakeLocator())
        }

        do {
            _ = try Lexicon(locating: FakeLocator())
            Issue.record("열려서는 안 된다")
        } catch let error as Lexicon.LoadError {
            // 화면에 뜨는 말이다. 파일 이름이 들어 있어야 무엇을 다시 구울지 알 수 있다.
            #expect(String(describing: error).contains("mworago-dict.db"))
        }
    }

    @Test("사전 파일이 있으나 색인이 아니면 실패한다")
    func 망가진사전() throws {
        let broken = try Self.writtenFile("이것은 색인이 아니다", ext: "db")
        defer { try? FileManager.default.removeItem(atPath: broken) }

        #expect(throws: (any Error).self) {
            _ = try Lexicon(locating: FakeLocator(files: ["mworago-dict.db": broken]))
        }
    }

    @Test("재료를 직접 건네도 선다 — 시험은 파일을 거치지 않는다")
    func 직접건네기() throws {
        let index = DictIndex(entries: try JMDictParser.parse(xml: Self.sample))
        let lexicon = Lexicon(dictionary: index, frequency: nil)

        #expect(lexicon.dictionary.lookup("だいじょうぶ").first?.entry.headword == "大丈夫")
    }
}
