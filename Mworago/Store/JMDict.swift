import Foundation

/// 표제항의 표기 또는 읽기 하나. 빈도 점수는 여기에 붙는다.
public struct DictForm: Sendable, Equatable {
    public let text: String
    public let priority: Int
    /// 검색 전용(`sK`)이거나 거의 안 쓰는(`rK`) 표기. 실제로 그렇게 적는 사람이 없다.
    public let isRare: Bool

    public init(text: String, priority: Int, isRare: Bool = false) {
        self.text = text
        self.priority = priority
        self.isRare = isRare
    }
}

/// JMdict 표제항 하나.
public struct DictEntry: Sendable, Equatable {
    public let readings: [DictForm]   // 가나 읽기. 이표기가 있으면 여럿
    public let writings: [DictForm]   // 한자 표기. 가나로만 쓰는 낱말은 비어 있다
    public let glosses: [String]      // 영어 뜻 (JMdict 는 영일 사전이다)
    /// 미리 구워 둔 한국어 뜻. 공개된 한일 사전이 없어 모델로 만든다.
    /// 자주 쓰는 낱말만 채우므로 없을 수 있고, 그때는 영어 뜻이 남는다.
    public let koreanGloss: String?
    /// JMdict 의 `uk` 태그 — "보통 가나로 쓰는 낱말". 한자 표기가 실려 있어도 쓰이지 않는다.
    /// `止める`(やめる)가 그렇다. 사전이 스스로 알려주는 정보인데 읽지 않으면
    /// 아무도 안 쓰는 한자 표기의 빈도로 그 낱말을 재게 된다.
    public let usuallyKana: Bool

    public init(readings: [DictForm], writings: [DictForm], glosses: [String],
                usuallyKana: Bool = false, koreanGloss: String? = nil) {
        self.readings = readings
        self.writings = writings
        self.glosses = glosses
        self.usuallyKana = usuallyKana
        self.koreanGloss = koreanGloss
    }

    /// 화면에 보일 뜻. 한국어가 있으면 그것이 먼저다.
    public var displayGloss: String {
        koreanGloss ?? glosses.joined(separator: " · ")
    }

    /// 실제로 쓰이는 표기만. 전부 희귀 표기라면 가나로 쓰는 낱말이나 마찬가지다.
    public var usableWritings: [DictForm] { writings.filter { !$0.isRare } }

    public var headword: String { usableWritings.first?.text ?? readings.first?.text ?? "" }
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

    /// XML 표준이 정한 다섯 엔티티. 이것만은 파서가 알아서 푼다.
    private static let standardEntities: Set<String> = ["amp", "lt", "gt", "quot", "apos"]

    /// JMdict 의 표지(`&uk;`·`&sK;`)를 파서가 읽을 수 있는 텍스트로 바꾼다.
    ///
    /// `XMLParser`는 내부 DTD 에 선언된 엔티티를 **확장하지 않고 빈 문자열로 만든다.**
    /// 그래서 `<misc>&uk;</misc>`가 빈 값으로 들어와, 사전이 알려주는 "가나로 쓰는 낱말"
    /// 정보를 통째로 놓치게 된다.
    ///
    /// 60MB 짜리 문서라 정규식으로 훑기에는 무겁다. `&`와 `;`만 공백으로 바꾸면
    /// 길이가 변하지 않아 제자리에서 끝난다.
    static func exposeEntities(_ data: Data) -> Data {
        var bytes = [UInt8](data)
        let ampersand = UInt8(ascii: "&"), semicolon = UInt8(ascii: ";"), hash = UInt8(ascii: "#")
        let space = UInt8(ascii: " ")

        var index = 0
        while index < bytes.count {
            defer { index += 1 }
            guard bytes[index] == ampersand else { continue }

            // 엔티티 이름은 짧다. 20바이트 안에 ; 가 없으면 그냥 & 문자다
            var end = index + 1
            while end < bytes.count, end - index < 20, bytes[end] != semicolon { end += 1 }
            guard end < bytes.count, bytes[end] == semicolon, end > index + 1 else { continue }
            guard bytes[index + 1] != hash else { continue }   // &#39; 같은 문자 참조

            let name = String(decoding: bytes[(index + 1)..<end], as: UTF8.self)
            guard !standardEntities.contains(name) else { continue }

            bytes[index] = space
            bytes[end] = space
            index = end
        }
        return Data(bytes)
    }

    public static func parse(data: Data) throws -> [DictEntry] {
        let data = exposeEntities(data)
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
        private var formIsRare = false
        private var usuallyKana = false

        private var buffer = ""
        private var capturing = false

        private static let captured: Set<String> = ["keb", "reb", "gloss", "ke_pri", "re_pri", "ke_inf", "misc"]

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "entry":
                readings = []; writings = []; glosses = []; usuallyKana = false
            case "k_ele", "r_ele":
                formText = ""; formPriority = 0; formIsRare = false
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
            case "ke_inf":
                // exposeEntities 를 거쳐 표지 이름이 그대로 들어온다: sK · rK · iK
                if text == "sK" || text == "rK" { formIsRare = true }
            case "misc":
                if text == "uk" { usuallyKana = true }
            case "k_ele":
                guard !formText.isEmpty else { return }
                writings.append(DictForm(text: formText, priority: formPriority, isRare: formIsRare))
            case "r_ele":
                guard !formText.isEmpty else { return }
                readings.append(DictForm(text: formText, priority: formPriority))
            // 뜻은 앞의 둘만 싣는다. 다섯을 다 실으면 색인이 눈에 띄게 커지는데,
            // 화면에 보이는 것은 어차피 앞의 한둘이다.
            case "gloss": if glosses.count < 2 { glosses.append(text) }
            case "entry":
                guard !readings.isEmpty else { return }
                entries.append(DictEntry(readings: readings, writings: writings,
                                         glosses: glosses, usuallyKana: usuallyKana))
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
        // 흔한 낱말이 먼저 오도록 줄 세우되, 점수가 같으면 사전에 실린 순서를 지킨다.
        // Swift 의 sort 는 안정 정렬이 아니라서 그대로 두면 색인 파일과 답이 갈린다.
        for key in index.keys {
            index[key] = index[key]?.enumerated()
                .sorted { $0.element.priority != $1.element.priority
                            ? $0.element.priority > $1.element.priority
                            : $0.offset < $1.offset }
                .map(\.element)
        }
        self.byReading = index
    }

    public func lookup(_ reading: String) -> [DictHit] {
        byReading[KanaTable.toHiragana(reading)] ?? []
    }
}
