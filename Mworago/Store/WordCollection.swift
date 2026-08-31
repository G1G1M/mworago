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

    /// 표기와 읽기가 함께여야 한 낱말이다 — 机(つくえ)와 机(つき)는 다른 낱말이다.
    public var id: String { "\(headword)\u{1F}\(reading)" }

    public init(headword: String, reading: String, hangul: String, gloss: String,
                collectedAt: Date = Date(), folder: String? = nil) {
        self.headword = headword
        self.reading = reading
        self.hangul = hangul
        self.gloss = gloss
        self.collectedAt = collectedAt
        self.folder = folder
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
    static func byFolder(_ words: [CollectedWord]) -> [Folder] {
        let grouped = Dictionary(grouping: words) { $0.folder }
        let named = grouped.keys.compactMap { $0 }.sorted()
        var folders = named.map { name in
            Folder(name: name, words: grouped[name]!.sorted { $0.collectedAt > $1.collectedAt })
        }
        if let loose = grouped[nil], !loose.isEmpty {
            folders.append(Folder(name: nil, words: loose.sorted { $0.collectedAt > $1.collectedAt }))
        }
        return folders
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
    /// 지난번에 담은 곳.
    ///
    /// **담을 때 어디에 넣을지 묻는다.** 한때는 보기 시작할 때 미리 정해 두고 담는
    /// 순간에는 묻지 않았다 — 흐름이 끊긴다는 판단이었다. 그런데 앱은 사용자가 어느
    /// 화를 보는지 알 길이 없다. 날짜로 묶은 것도 그것을 몰라서 쓴 대용품이었다.
    ///
    /// 그래서 묻되, **지난번 자리를 기억해 미리 골라 둔다.** 한 화를 몰아 담는 동안은
    /// 같은 곳이 계속 골라져 있으므로, 고르는 일이 확인하는 일이 된다.
    public private(set) var lastFolder: String?
    private let path: String
    /// 지난번 묶음은 낱말 파일과 따로 둔다. 낱말은 배열로 저장되는데 그 곁에 값을 하나
    /// 끼우려면 저장 구조를 바꿔야 하고, 그러면 예전 파일을 못 읽는다.
    ///
    /// 파일 이름이 `.folder` 인 것은 이 값이 "지금 담는 곳"이던 시절의 자취다.
    /// 그때 정해 둔 곳이 곧 그 사람이 마지막으로 담던 곳이라 그대로 이어받는다.
    private var folderPath: String { path + ".folder" }

    public init(path: String) {
        self.path = path
        self.words = Self.load(from: path)
        self.lastFolder = (try? String(contentsOfFile: path + ".folder", encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    /// 방금 고른 자리를 기억해 둔다. 빈 이름은 "아무 데도 아님"이다.
    ///
    /// **"안 넣기"도 기억한다.** 기억하는 것은 마지막에 고른 *묶음*이 아니라 마지막에
    /// 고른 *것*이다 — 안 넣기를 골랐는데 다음에 또 묶음이 골라져 있으면, 고른 적 없는
    /// 곳으로 낱말이 간다.
    private mutating func remember(_ folder: String?) {
        lastFolder = folder
        if let folder {
            try? folder.write(toFile: folderPath, atomically: true, encoding: .utf8)
        } else {
            try? FileManager.default.removeItem(atPath: folderPath)
        }
    }

    /// 이미 담은 낱말을 다른 묶음으로 옮긴다.
    ///
    /// **지난번 묶음은 건드리지 않는다.** 옮기기는 정리하는 일이고 지난번 묶음은
    /// "지금 무엇을 보고 있는가"의 흔적이다. 어제 것을 정리했다고 오늘 담을 자리가
    /// 어제로 끌려가면 안 된다.
    public mutating func move(_ word: CollectedWord, to folder: String?) {
        guard let index = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[index] = words[index].movedTo(folder?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty)
        save()
    }

    /// 묶음 이름을 바꾼다. 그 묶음에 든 낱말이 전부 따라간다.
    ///
    /// **이미 있는 이름으로 바꾸면 둘이 합쳐진다.** 막지 않는다 — 한 편을 두 이름으로
    /// 담아 둔 것을 합치는 일이 실제로 있고, 막으면 낱말을 하나씩 옮겨야 한다.
    public mutating func renameFolder(_ old: String, to new: String) {
        guard let new = new.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
              new != old else { return }
        var touched = false
        for index in words.indices where words[index].folder == old {
            words[index] = words[index].movedTo(new)
            touched = true
        }
        guard touched || lastFolder == old else { return }
        // 지난번 묶음도 따라간다. 안 따라가면 다음에 담을 때 없는 이름이 골라져 있고,
        // 그 이름으로 묶음이 하나 더 생긴다.
        if lastFolder == old { remember(new) }
        save()
    }

    /// 묶음을 없앤다. **낱말은 남기고 묶음에서만 뺀다.**
    ///
    /// 이름을 지운 것이지 모은 것을 버린 것이 아니다. 담은 낱말이 함께 사라지면 되돌릴
    /// 길이 없는데, 사용자는 이름만 지우려 했을 뿐이다. 낱말은 "아직 안 넣은 것"으로 간다.
    public mutating func removeFolder(_ name: String) {
        var touched = false
        for index in words.indices where words[index].folder == name {
            words[index] = words[index].movedTo(nil)
            touched = true
        }
        guard touched || lastFolder == name else { return }
        if lastFolder == name { remember(nil) }
        save()
    }

    /// 이름이 붙은 묶음들. 낱말에서 거둔다 — 빈 묶음은 따로 기억하지 않는다.
    /// 지난번 묶음은 그 안이 비었더라도 보여야 하므로 함께 넣는다. 방금 담은 곳이
    /// 목록에서 사라지면 다음에 담을 때 같은 이름을 다시 쳐야 한다.
    public var folderNames: [String] {
        var names = Set(words.compactMap(\.folder))
        if let lastFolder { names.insert(lastFolder) }
        return names.sorted()
    }

    public func contains(_ word: CollectedWord) -> Bool {
        words.contains { $0.id == word.id }
    }

    /// 담는다. 어디에 넣을지 함께 받는다 — 그것을 아는 것은 사용자뿐이다.
    ///
    /// 이미 있으면 아무 일도 하지 않는다. 두 번 찾았다고 두 줄이 될 이유는 없고,
    /// **그때는 지난번 묶음도 흔들지 않는다** — 일어나지 않은 담기다.
    public mutating func add(_ word: CollectedWord, to folder: String?) {
        guard !contains(word) else { return }
        let folder = folder?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        // 방금 담은 것이 눈앞에 있어야 한다. 스크롤해서 찾게 만들 이유가 없다.
        words.insert(word.movedTo(folder), at: 0)
        remember(folder)
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

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
