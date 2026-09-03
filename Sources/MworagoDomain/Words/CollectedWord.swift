import Foundation

/// 사용자가 담아 둔 낱말 하나.
///
/// 그때 화면에 보였던 것을 그대로 붙든다 — 뜻이 나중에 좋아지더라도, 담을 당시에 무엇을
/// 보고 담았는지가 사용자의 기억과 맞다.
public struct CollectedWord: Codable, Sendable, Equatable, Identifiable {
    public let headword: String   // 표기 (가나로만 쓰는 낱말이면 읽기와 같다)
    public let reading: String    // 읽기
    public let hangul: String     // 한글 음차 — 이 사람이 실제로 친 소리
    public let gloss: String      // 담을 때 보였던 뜻
    public let collectedAt: Date
    /// 어느 묶음에 넣었는가. 비어 있으면 아직 아무 데도 넣지 않은 것이다.
    ///
    /// **옵셔널이어야 한다.** 이 칸이 없던 시절에 담은 파일이 그대로 읽혀야 하는데,
    /// Swift 의 자동 Decodable 은 없는 칸에 기본값을 넣어 주지 않는다 — 옵셔널만이
    /// 없을 때 nil 이 된다.
    public var folder: String?
    /// 담을 때 이 낱말이 무엇이었는가 — `동사` · `명사` · `관용구`.
    ///
    /// **뜻과 같은 까닭으로 붙들어 둔다.** 책장은 사전을 뒤지지 않는다(사전을 열려면
    /// 39MB 색인을 들고 있어야 한다). 담을 때 화면에 있던 것을 그대로 가져오면
    /// 책장에서도 같은 꼬리표가 보인다.
    ///
    /// **옵셔널이어야 한다.** 이 칸이 없던 시절에 담은 파일이 그대로 읽혀야 하는데,
    /// Swift 의 자동 Decodable 은 없는 칸에 기본값을 넣어 주지 않는다.
    public var partOfSpeech: String?

    /// 표기와 읽기가 함께여야 한 낱말이다 — 机(つくえ)와 机(つき)는 다른 낱말이다.
    public var id: String { "\(headword)\u{1F}\(reading)" }

    public init(headword: String, reading: String, hangul: String, gloss: String,
                collectedAt: Date = Date(), folder: String? = nil,
                partOfSpeech: String? = nil) {
        self.headword = headword
        self.reading = reading
        self.hangul = hangul
        self.gloss = gloss
        self.collectedAt = collectedAt
        self.folder = folder
        self.partOfSpeech = partOfSpeech
    }

    /// 묶음만 바꾼 사본. 낱말 자체는 그대로다 — 어디에 넣든 같은 낱말이다.
    public func movedTo(_ folder: String?) -> CollectedWord {
        var copy = self
        copy.folder = folder
        return copy
    }
}

public extension CollectedWord {

    /// 하루치 묶음.
    struct Day: Sendable, Identifiable {
        public let date: Date       // 그날 0시
        public let words: [CollectedWord]
        public var id: Date { date }
    }

    /// 날짜로 묶는다. 최근 날이 먼저 온다.
    ///
    /// 기획의 "화별 교재"가 여기서 시작한다. 앱은 사용자가 어느 화를 보다 걸렸는지 모르지만,
    /// **애니 한 화를 보면서 찾은 것들은 같은 날 모인다.** 지어내지 않고 가진 재료로 묶는다.
    ///
    /// 자정을 넘기면 다른 날이 된다. "새벽 4시까지는 어제"처럼 지어낸 규칙을 두면
    /// 사용자가 자기 기록을 예측할 수 없다.
    static func byDay(_ words: [CollectedWord], calendar: Calendar = .current) -> [Day] {
        let grouped = Dictionary(grouping: words) { calendar.startOfDay(for: $0.collectedAt) }
        return grouped.keys.sorted(by: >).map { day in
            Day(date: day, words: grouped[day]!.sorted { $0.collectedAt > $1.collectedAt })
        }
    }
}

public extension CollectedWord {

    /// 묶음 하나. 이름이 없는 것(`nil`)도 하나의 묶음으로 다룬다 —
    /// 아직 어디에도 넣지 않은 낱말이 사라져 보이면 안 된다.
    struct Folder: Sendable, Identifiable {
        public let name: String?
        public let words: [CollectedWord]
        public var id: String { name ?? "\u{1F}없음" }
    }

    /// 묶음으로 나눈다. 이름 붙은 것이 먼저, 아직 안 넣은 것이 마지막이다.
    ///
    /// **만들어 둔 이름을 함께 받는다.** 낱말에서만 거두면 빈 묶음이 존재할 수 없어서,
    /// 마지막 낱말을 옮기는 순간 묶음이 통째로 사라진다 — 사용자는 낱말 하나를
    /// 치웠을 뿐이지 묶음을 없앤 적이 없다.
    /// **차례는 준 대로 지킨다.** 무엇이 먼저 설지는 부르는 쪽이 정한 것이라
    /// (책장은 최근에 손댄 순으로 준다) 여기서 다시 줄 세우면 그 차례가 뒤집힌다.
    /// 목록에 없는 이름(낱말만 들고 있는 것)은 뒤에 이름순으로 붙인다.
    static func byFolder(_ words: [CollectedWord], names: [String] = []) -> [Folder] {
        let grouped = Dictionary(grouping: words) { $0.folder }
        let extras = Set(grouped.keys.compactMap { $0 }).subtracting(names).sorted()
        let named = names + extras
        var folders = named.map { name in
            Folder(name: name, words: (grouped[name] ?? []).sorted { $0.collectedAt > $1.collectedAt })
        }
        if let loose = grouped[nil], !loose.isEmpty {
            folders.append(Folder(name: nil, words: loose.sorted { $0.collectedAt > $1.collectedAt }))
        }
        return folders
    }
}
