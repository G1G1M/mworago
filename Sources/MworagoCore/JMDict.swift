import Foundation

/// JMdict 표제항 하나.
public struct DictEntry: Sendable, Equatable {
    public let readings: [String]   // 가나 읽기. 이표기가 있으면 여럿
    public let writings: [String]   // 한자 표기. 가나로만 쓰는 낱말은 비어 있다
    public let glosses: [String]    // 영어 뜻
    public let priority: Int        // 클수록 흔한 낱말

    public var headword: String { writings.first ?? readings.first ?? "" }
}

/// JMdict XML을 표제항 배열로 읽는다.
///
/// 130MB짜리 파일이라 통째로 트리를 만드는 대신 XMLParser로 흘려 읽는다.
/// 필요한 건 표기·읽기·뜻·빈도 넷뿐이고 나머지 태그는 그냥 지나친다.
public enum JMDictParser {

    public static func parse(xml: String) throws -> [DictEntry] {
        guard let data = xml.data(using: .utf8) else { return [] }
        return try parse(data: data)
    }

    public static func parse(data: Data) throws -> [DictEntry] {
        let parser = XMLParser(data: data)
        let collector = Collector()
        parser.delegate = collector
        parser.shouldResolveExternalEntities = false

        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "JMDictParser", code: -1)
        }
        return collector.entries
    }

    /// 빈도 태그를 점수로 환산한다.
    ///
    /// JMdict는 흔한 낱말에 ichi1·news1·spec1 같은 표지를 달고,
    /// nf01~nf48은 신문 말뭉치 빈도 순위대(작을수록 흔함)를 뜻한다.
    /// 후보를 줄 세울 때 이 점수가 "사람이 실제로 찾을 낱말"을 위로 올려준다.
    static func priorityScore(_ tag: String) -> Int {
        switch tag {
        case "ichi1", "news1", "spec1": return 10
        case "gai1": return 5
        case "ichi2", "news2", "spec2", "gai2": return 3
        default:
            guard tag.hasPrefix("nf"), let rank = Int(tag.dropFirst(2)) else { return 0 }
            return max(0, 50 - rank)
        }
    }

    private final class Collector: NSObject, XMLParserDelegate {
        var entries: [DictEntry] = []

        private var readings: [String] = []
        private var writings: [String] = []
        private var glosses: [String] = []
        private var priority = 0
        private var buffer = ""
        private var capturing = false

        private static let captured: Set<String> = ["keb", "reb", "gloss", "ke_pri", "re_pri"]

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            if elementName == "entry" {
                readings = []; writings = []; glosses = []; priority = 0
            }
            if Self.captured.contains(elementName) {
                buffer = ""
                capturing = true
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard capturing else { return }
            buffer += string   // 긴 텍스트는 여러 조각으로 들어온다
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?) {
            let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            capturing = false

            switch elementName {
            case "keb": writings.append(text)
            case "reb": readings.append(text)
            case "gloss": if glosses.count < 5 { glosses.append(text) }
            case "ke_pri", "re_pri": priority += JMDictParser.priorityScore(text)
            case "entry":
                guard !readings.isEmpty else { return }
                entries.append(DictEntry(readings: readings, writings: writings,
                                         glosses: glosses, priority: priority))
            default: break
            }
        }
    }
}

/// 읽기(가나)로 표제항을 찾는 색인.
///
/// 음차 복원이 만든 가나 후보를 그대로 두드려 보는 자리다.
/// 사전에 없는 후보는 여기서 조용히 사라진다 — 그게 이 설계의 핵심이다.
public struct DictIndex: Sendable {
    private let byReading: [String: [DictEntry]]

    public var entryCount: Int { byReading.values.reduce(0) { $0 + $1.count } }
    public var readingCount: Int { byReading.count }

    public init(entries: [DictEntry]) {
        var index: [String: [DictEntry]] = [:]
        for entry in entries {
            for reading in entry.readings {
                index[reading, default: []].append(entry)
            }
        }
        // 흔한 낱말이 먼저 나오도록 미리 줄 세워 둔다
        for key in index.keys {
            index[key]?.sort { $0.priority > $1.priority }
        }
        self.byReading = index
    }

    public func lookup(_ reading: String) -> [DictEntry] {
        byReading[reading] ?? []
    }
}
