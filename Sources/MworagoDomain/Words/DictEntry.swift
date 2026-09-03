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

    /// 앞에 기댈 말이 있어야 하는 낱말인가 — 조사·조동사·계사.
    public var isBound: Bool { WordClass.isBound(tags: partsOfSpeech) }

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

    /// 색인을 만드는 쪽이 층 밖에 있으므로 밖에서 부를 수 있어야 한다 —
    /// 메모리 색인은 이 층이 만들지만 파일 색인은 인프라가 만든다.
    public init(entry: DictEntry, reading: String, priority: Int) {
        self.entry = entry
        self.reading = reading
        self.priority = priority
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
