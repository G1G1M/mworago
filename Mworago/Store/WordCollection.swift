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

    /// 표기와 읽기가 함께여야 한 낱말이다 — 机(つくえ)와 机(つき)는 다른 낱말이다.
    public var id: String { "\(headword)\u{1F}\(reading)" }

    public init(headword: String, reading: String, hangul: String, gloss: String,
                collectedAt: Date = Date()) {
        self.headword = headword
        self.reading = reading
        self.hangul = hangul
        self.gloss = gloss
        self.collectedAt = collectedAt
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

/// 모은 낱말을 파일 하나에 담아 둔다.
///
/// 앱의 이야기가 여기서 이어진다 — 걸린 대사를 찾고, **그것이 모여 그 화의 교재가 되고**,
/// 쉐도잉으로 간다. 그러니 이곳은 검색의 곁다리가 아니라 다음 화면의 재료다.
///
/// 저장 경로를 받는다. 테스트가 사용자의 진짜 파일을 건드리지 않게 하려면
/// 경로를 안에서 정하면 안 된다.
public struct WordCollection: Sendable {

    public private(set) var words: [CollectedWord] = []
    private let path: String

    public init(path: String) {
        self.path = path
        self.words = Self.load(from: path)
    }

    public func contains(_ word: CollectedWord) -> Bool {
        words.contains { $0.id == word.id }
    }

    /// 담는다. 이미 있으면 아무 일도 하지 않는다 — 두 번 찾았다고 두 줄이 될 이유는 없다.
    public mutating func add(_ word: CollectedWord) {
        guard !contains(word) else { return }
        // 방금 담은 것이 눈앞에 있어야 한다. 스크롤해서 찾게 만들 이유가 없다.
        words.insert(word, at: 0)
        save()
    }

    public mutating func remove(_ word: CollectedWord) {
        words.removeAll { $0.id == word.id }
        save()
    }

    // MARK: 파일

    /// **인코더와 디코더는 짝을 맞춘다.** 한쪽에만 날짜 전략을 정하면
    /// 날짜가 든 파일만 조용히 안 읽힌다.
    private static func coder() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    /// 읽지 못하면 빈 채로 시작한다. 모은 것을 잃는 일이지만, 앱이 열리지 않는 것보다는 낫다.
    ///
    /// **한 항목이 낡아도 나머지는 살린다.** Swift 의 자동 Decodable 은 기본값을 쓰지 않아서
    /// 필드를 하나 더하면 예전 파일이 통째로 안 읽힌다 — 모은 것이 통째로 사라지는 일이 된다.
    /// 그래서 배열째 디코딩하지 않고 한 칸씩 시도해, 읽히는 것만 거둔다.
    private static func load(from path: String) -> [CollectedWord] {
        guard let data = FileManager.default.contents(atPath: path) else { return [] }
        let (_, decoder) = coder()
        if let words = try? decoder.decode([CollectedWord].self, from: data) { return words }
        guard let rows = try? decoder.decode([FailableWord].self, from: data) else { return [] }
        return rows.compactMap(\.word)
    }

    private func save() {
        let (encoder, _) = Self.coder()
        guard let data = try? encoder.encode(words) else { return }
        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    /// 한 칸을 읽다 실패해도 배열 전체를 버리지 않기 위한 껍데기.
    private struct FailableWord: Decodable {
        let word: CollectedWord?
        init(from decoder: Decoder) throws {
            word = try? CollectedWord(from: decoder)
        }
    }
}
