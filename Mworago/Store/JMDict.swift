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
    /// JMdict 의 품사 태그(`v5u`·`prt`·`adj-na`…). 먼저 쓰인 순서를 지킨다.
    /// 뜻을 한국어로 옮길 때 동사를 동사로 옮기고, 조사를 아예 건드리지 않기 위해 필요하다.
    public let partsOfSpeech: [String]
    /// **써도 되는 말인가.** JMdict 의 `misc` 태그 중 사용역에 해당하는 것들 —
    /// `arch`(고어) · `col`(구어) · `sl`(속어) · `derog`(경멸) · `vulg`(비속) ·
    /// `hon`(존경) · `male`·`fem`(남성어·여성어)…
    ///
    /// 이 앱의 빈도표는 애니 자막 말뭉치라 "얼마나 흔한가"라는 축이 이미 애니다.
    /// 그런데 애니에 흔한 것과 일상에서 써도 되는 것은 다르다 — `貴様` 는 애니에
    /// 넘치지만 사람에게 쓰면 싸움이 난다. 그 판단을 **모델에게 묻지 않는다.**
    /// 사전 편집자가 이미 붙여 둔 사실이고, 모델은 그럴듯한 거짓말을 할 수 있다.
    ///
    /// **첫 뜻갈래의 것만 담는다.** 태그는 뜻마다 붙어서, 다 합치면 흔한 낱말이
    /// 엉뚱한 딱지를 단다(`い` 가 비속어, `見` 이 존경어가 된다).
    public let usageTags: [String]

    public init(readings: [DictForm], writings: [DictForm], glosses: [String],
                usuallyKana: Bool = false, koreanGloss: String? = nil,
                partsOfSpeech: [String] = [], usageTags: [String] = []) {
        self.readings = readings
        self.writings = writings
        self.glosses = glosses
        self.usuallyKana = usuallyKana
        self.koreanGloss = koreanGloss
        self.partsOfSpeech = partsOfSpeech
        self.usageTags = usageTags
    }

    /// 이 낱말의 큰 갈래.
    public var wordClass: WordClass { WordClass(tags: partsOfSpeech) }

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
        // 품사는 뜻갈래(sense)마다 되풀이된다. 순서는 지키고 중복만 걷어낸다.
        private var partsOfSpeech: [String] = []

        // 지금 읽고 있는 k_ele / r_ele 하나의 상태.
        // 빈도 태그는 표기·읽기 **하나하나에** 붙기 때문에 이 단위로 모아야 한다.
        // 항목 전체로 합치면 유명한 낱말의 마이너한 읽기가 그 명성을 그대로 물려받는다
        // (机는 つくえ로 유명하지만 つき로도 읽힌다).
        private var formText = ""
        private var formPriority = 0
        private var formIsRare = false
        private var usuallyKana = false
        /// 지금 몇 번째 뜻갈래를 읽고 있는가. 꼬리표는 **첫 갈래의 것만** 쓴다.
        private var senseIndex = -1
        private var usageTags: [String] = []

        private var buffer = ""
        private var capturing = false

        private static let captured: Set<String> = ["keb", "reb", "gloss", "ke_pri", "re_pri", "ke_inf", "misc", "pos"]

        /// `misc` 에는 사용역 말고도 여러 표지가 섞여 있다(`abbr`·`on-mim`·`yoji`…).
        /// **"써도 되는 말인가"에 답하는 것만 고른다** — 나머지는 화면에서 할 말이 없다.
        private static let usageTagNames: Set<String> = [
            "arch", "obs", "rare", "poet",    // 옛말·안 쓰는 말·시어
            "col", "sl", "net-sl", "vulg",    // 구어·속어·비속어
            "derog", "sens", "joc",           // 경멸·민감·농
            "hon", "hum", "pol",              // 존경·겸양·공손
            "male", "fem", "chn", "fam",      // 남성어·여성어·아이말·친밀
        ]

        func parser(_ parser: XMLParser, didStartElement elementName: String,
                    namespaceURI: String?, qualifiedName: String?,
                    attributes attributeDict: [String: String] = [:]) {
            switch elementName {
            case "entry":
                readings = []; writings = []; glosses = []; usuallyKana = false
                partsOfSpeech = []; usageTags = []; senseIndex = -1
            case "sense":
                senseIndex += 1
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
                // `uk` 는 사용역이 아니라 표기 규칙이라 제 자리가 따로 있다.
                if text == "uk" { usuallyKana = true }
                else if senseIndex == 0, Self.usageTagNames.contains(text),
                        !usageTags.contains(text) {
                    usageTags.append(text)
                }
            case "k_ele":
                guard !formText.isEmpty else { return }
                writings.append(DictForm(text: formText, priority: formPriority, isRare: formIsRare))
            case "r_ele":
                guard !formText.isEmpty else { return }
                readings.append(DictForm(text: formText, priority: formPriority))
            // 뜻은 앞의 둘만 싣는다. 다섯을 다 실으면 색인이 눈에 띄게 커지는데,
            // 화면에 보이는 것은 어차피 앞의 한둘이다.
            case "gloss": if glosses.count < 2 { glosses.append(text) }
            // exposeEntities 덕에 &v5u; 가 표지 이름 그대로 들어온다.
            case "pos": if !text.isEmpty && !partsOfSpeech.contains(text) { partsOfSpeech.append(text) }
            case "entry":
                guard !readings.isEmpty else { return }
                entries.append(DictEntry(readings: readings, writings: writings,
                                         glosses: glosses, usuallyKana: usuallyKana,
                                         partsOfSpeech: partsOfSpeech,
                                         usageTags: usageTags))
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
                // 키는 조회용으로 접는다 — 가타카나도 장음 표기 차이도 여기서 만난다.
                // 돌려줄 때의 reading 은 원래 표기 그대로 둔다(화면에 그렇게 보여야 한다).
                index[KanaTable.lookupKey(reading.text), default: []].append(
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
        byReading[KanaTable.lookupKey(reading)] ?? []
    }
}
