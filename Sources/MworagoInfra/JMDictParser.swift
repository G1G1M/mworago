import Foundation
import MworagoDomain
import MworagoUseCases

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
