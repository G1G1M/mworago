import Foundation
import SQLite3

/// 읽기로 표제항을 찾을 수 있는 것. 메모리 색인과 파일 색인이 같은 자리에 들어간다.
public protocol DictionaryLookup {
    func lookup(_ reading: String) -> [DictHit]
}

extension DictIndex: DictionaryLookup {}

/// 미리 구워 둔 사전 색인 파일.
///
/// XML 을 그대로 쓰면 앱을 열 때마다 60MB 를 파싱하느라 3초를 쓰고, 26.5만 표제항이
/// 통째로 메모리에 올라간다. 색인을 미리 구워 두면 **열 때 아무것도 읽지 않고**
/// 검색할 때 필요한 행만 꺼낸다.
public final class DictionaryStore: DictionaryLookup, @unchecked Sendable {

    private let handle: OpaquePointer
    private let statement: OpaquePointer
    private let lock = NSLock()   // sqlite3 문장 하나를 여러 곳에서 쓰지 않도록

    /// 표기·읽기 하나를 한 칸에 담을 때 쓰는 구분자. 일본어 표기에 나타나지 않는 제어문자다.
    private static let fieldSeparator = "\u{1F}"
    private static let recordSeparator = "\u{1E}"

    public init(path: String) throws {
        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let opened = handle
        else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "열 수 없음"
            sqlite3_close(handle)
            throw StoreError.cannotOpen(path: path, message: message)
        }
        self.handle = opened

        // 조회는 한 문장으로 끝난다. 미리 준비해 두고 매번 바인딩만 바꾼다.
        let sql = """
            SELECT r.display, r.priority, e.writings, e.glosses, e.usually_kana, e.readings
            FROM readings r JOIN entries e ON e.id = r.entry_id
            WHERE r.reading = ? ORDER BY r.priority DESC, r.entry_id ASC
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(opened, sql, -1, &statement, nil) == SQLITE_OK, let prepared = statement else {
            let message = String(cString: sqlite3_errmsg(opened))
            sqlite3_close(opened)
            throw StoreError.cannotOpen(path: path, message: message)
        }
        self.statement = prepared
    }

    deinit {
        sqlite3_finalize(statement)
        sqlite3_close(handle)
    }

    public func lookup(_ reading: String) -> [DictHit] {
        let key = KanaTable.toHiragana(reading)
        lock.lock()
        defer {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            lock.unlock()
        }

        sqlite3_bind_text(statement, 1, key, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        var hits: [DictHit] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let display = column(0) else { continue }
            let priority = Int(sqlite3_column_int(statement, 1))
            let writings = Self.decodeForms(column(2) ?? "")
            let glosses = (column(3) ?? "").isEmpty ? [] : (column(3) ?? "").components(separatedBy: Self.recordSeparator)
            let usuallyKana = sqlite3_column_int(statement, 4) != 0
            // 표제항의 읽기를 전부 되살린다. 매칭된 하나만 남기면 headword 가 달라지고
            // (표기가 없는 낱말은 첫 읽기가 표제어다) 도메인 빈도 조회도 어긋난다.
            let readings = Self.decodeForms(column(5) ?? "")

            let entry = DictEntry(readings: readings.isEmpty ? [DictForm(text: display, priority: priority)] : readings,
                                  writings: writings, glosses: glosses, usuallyKana: usuallyKana)
            hits.append(DictHit(entry: entry, reading: display, priority: priority))
        }
        return hits
    }

    private func column(_ index: Int32) -> String? {
        sqlite3_column_text(statement, index).map { String(cString: $0) }
    }

    // MARK: 굽기

    public static func build(entries: [DictEntry], at path: String) throws {
        try? FileManager.default.removeItem(atPath: path)

        var handle: OpaquePointer?
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let db = handle
        else { throw StoreError.cannotOpen(path: path, message: "만들 수 없음") }
        defer { sqlite3_close(db) }

        // 색인은 한 번 굽고 읽기만 하므로 안전장치를 꺼도 된다. 굽는 시간이 크게 줄어든다.
        try exec(db, "PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF;")
        try exec(db, """
            CREATE TABLE entries (id INTEGER PRIMARY KEY, writings TEXT, glosses TEXT,
                                  usually_kana INTEGER, readings TEXT);
            CREATE TABLE readings (reading TEXT NOT NULL, display TEXT NOT NULL,
                                   priority INTEGER NOT NULL, entry_id INTEGER NOT NULL);
            -- 점수가 같으면 사전에 실린 순서를 따른다. 메모리 색인과 답이 갈리지 않게 하는 장치다.
            """)
        try exec(db, "BEGIN")

        var entryStatement: OpaquePointer?
        var readingStatement: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT INTO entries VALUES (?, ?, ?, ?, ?)", -1, &entryStatement, nil)
        sqlite3_prepare_v2(db, "INSERT INTO readings VALUES (?, ?, ?, ?)", -1, &readingStatement, nil)
        defer {
            sqlite3_finalize(entryStatement)
            sqlite3_finalize(readingStatement)
        }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        for (index, entry) in entries.enumerated() {
            let id = Int32(index + 1)
            sqlite3_bind_int(entryStatement, 1, id)
            sqlite3_bind_text(entryStatement, 2, encodeForms(entry.writings), -1, transient)
            sqlite3_bind_text(entryStatement, 3, entry.glosses.joined(separator: recordSeparator), -1, transient)
            sqlite3_bind_int(entryStatement, 4, entry.usuallyKana ? 1 : 0)
            sqlite3_bind_text(entryStatement, 5, encodeForms(entry.readings), -1, transient)
            sqlite3_step(entryStatement)
            sqlite3_reset(entryStatement)

            for reading in entry.readings {
                // 조회 키는 히라가나로 맞춘다 — 외래어 표제어는 가타카나로 실려 있다.
                sqlite3_bind_text(readingStatement, 1, KanaTable.toHiragana(reading.text), -1, transient)
                sqlite3_bind_text(readingStatement, 2, reading.text, -1, transient)
                sqlite3_bind_int(readingStatement, 3, Int32(reading.priority))
                sqlite3_bind_int(readingStatement, 4, id)
                sqlite3_step(readingStatement)
                sqlite3_reset(readingStatement)
            }
        }
        try exec(db, "COMMIT")
        // 색인은 자료를 다 넣은 뒤에 만드는 편이 훨씬 빠르다
        try exec(db, "CREATE INDEX idx_reading ON readings(reading); VACUUM;")
    }

    private static func encodeForms(_ forms: [DictForm]) -> String {
        forms.map { "\($0.text)\(fieldSeparator)\($0.priority)\(fieldSeparator)\($0.isRare ? 1 : 0)" }
            .joined(separator: recordSeparator)
    }

    private static func decodeForms(_ text: String) -> [DictForm] {
        guard !text.isEmpty else { return [] }
        return text.components(separatedBy: recordSeparator).compactMap { record in
            let fields = record.components(separatedBy: fieldSeparator)
            guard fields.count == 3 else { return nil }
            return DictForm(text: fields[0], priority: Int(fields[1]) ?? 0, isRare: fields[2] == "1")
        }
    }

    private static func exec(_ db: OpaquePointer, _ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "알 수 없음"
            sqlite3_free(error)
            throw StoreError.sqlFailed(message)
        }
    }

    public enum StoreError: Error, CustomStringConvertible {
        case cannotOpen(path: String, message: String)
        case sqlFailed(String)

        public var description: String {
            switch self {
            case .cannotOpen(let path, let message): "색인을 열 수 없다: \(path) — \(message)"
            case .sqlFailed(let message): "색인 작업 실패: \(message)"
            }
        }
    }
}
