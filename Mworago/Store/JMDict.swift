import Foundation

/// 표제항의 표기 또는 읽기 하나. 빈도 점수는 여기에 붙는다.
public struct DictForm: Sendable, Equatable {
    public let text: String
    public let priority: Int
}

/// JMdict 표제항 하나.
public struct DictEntry: Sendable, Equatable {
    public let readings: [DictForm]   // 가나 읽기. 이표기가 있으면 여럿
    public let writings: [DictForm]   // 한자 표기. 가나로만 쓰는 낱말은 비어 있다
    public let glosses: [String]      // 영어 뜻

    public var headword: String { writings.first?.text ?? readings.first?.text ?? "" }
}

/// 색인이 돌려주는 한 건. 점수는 **찾은 그 읽기의** 점수다.
public struct DictHit: Sendable {
    public let entry: DictEntry
    public let reading: String
    public let priority: Int
}

/// JMdict XML을 표제항 배열로 읽는다.
///
/// 130MB짜리 파일이라 통째로 트리를 만드는 대신 XMLParser로 흘려 읽는다.
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

        private var readings: [DictForm] = []
        private var writings: [DictForm] = []
        private var glosses: [String] = []

        // 지금 읽고 있는 k_ele / r_ele 하나의 상태.
        // 빈도 태그는 표기·읽기 **하나하나에** 붙기 때문에 이 단위로 모아야 한다.
        // 항목 전체로 합치면 유명한 낱말의 마이너한 읽기가 그 명성을 그대로 물려받는다
        // (机는 つくえ로 유명하지만 つき로도 읽힌다).
        private var formText = ""
        private var formPriority = 0

        private var buffer = ""
        private var capturing = false

        private static let captured: Set<String> = ["keb", "reb", "gloss", "ke_pri", "re_pri"]

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "entry":
                readings = []; writings = []; glosses = []
            case "k_ele", "r_ele":
                formText = ""; formPriority = 0
            default: break
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
            case "keb", "reb": formText = text
            case "ke_pri", "re_pri": formPriority += JMDictParser.priorityScore(text)
            case "k_ele":
                guard !formText.isEmpty else { return }
                writings.append(DictForm(text: formText, priority: formPriority))
            case "r_ele":
                guard !formText.isEmpty else { return }
                readings.append(DictForm(text: formText, priority: formPriority))
            case "gloss": if glosses.count < 5 { glosses.append(text) }
            case "entry":
                guard !readings.isEmpty else { return }
                entries.append(DictEntry(readings: readings, writings: writings, glosses: glosses))
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
    private let byReading: [String: [DictHit]]

    public var entryCount: Int { byReading.values.reduce(0) { $0 + $1.count } }
    public var readingCount: Int { byReading.count }

    public init(entries: [DictEntry]) {
        var index: [String: [DictHit]] = [:]
        for entry in entries {
            for reading in entry.readings {
                // 점수는 찾은 그 읽기의 것이다. 항목의 다른 읽기가 벌어온 점수를 물려주지 않는다.
                // 키는 히라가나로 맞춘다 — 외래어 표제어는 가타카나로 실려 있다.
                // 돌려줄 때의 reading 은 원래 표기 그대로 둔다(화면에 그렇게 보여야 한다).
                index[KanaTable.toHiragana(reading.text), default: []].append(
                    DictHit(entry: entry, reading: reading.text, priority: reading.priority))
            }
        }
        for key in index.keys {
            index[key]?.sort { $0.priority > $1.priority }
        }
        self.byReading = index
    }

    public func lookup(_ reading: String) -> [DictHit] {
        byReading[KanaTable.toHiragana(reading)] ?? []
    }
}
