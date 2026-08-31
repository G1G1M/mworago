import Testing
import Foundation
@testable import MworagoCore

/// 찾은 낱말을 모아 두는 곳.
///
/// 앱의 이야기가 여기서 이어진다 — 걸린 대사를 찾고, **그것이 모여 그 화의 교재가 되고**,
/// 쉐도잉으로 간다. 그러니 이 저장소는 검색 결과의 곁다리가 아니라 다음 화면의 재료다.
@Suite("모은 낱말")
struct WordCollectionTests {

    static func 임시경로() -> String {
        NSTemporaryDirectory() + "mworago-collection-\(UUID().uuidString).json"
    }

    static func 낱말(_ 표기: String, _ 읽기: String = "よみ", _ 한글: String = "요미") -> CollectedWord {
        CollectedWord(headword: 표기, reading: 읽기, hangul: 한글, gloss: "뜻")
    }

    @Test("담고 다시 열어도 그대로다")
    func 왕복() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("大丈夫", "だいじょうぶ", "다이죠부"))
        collection.add(Self.낱말("約束", "やくそく", "야쿠소쿠"))

        let 다시 = WordCollection(path: path)
        #expect(다시.words.map(\.headword) == ["約束", "大丈夫"])
    }

    @Test("나중에 담은 것이 위로 온다")
    func 최신순() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("一"))
        collection.add(Self.낱말("二"))
        collection.add(Self.낱말("三"))
        // 방금 찾은 것이 눈앞에 있어야 한다. 스크롤해서 찾게 만들 이유가 없다.
        #expect(collection.words.map(\.headword) == ["三", "二", "一"])
    }

    @Test("같은 낱말을 또 담아도 하나다")
    func 중복() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("大丈夫", "だいじょうぶ"))
        collection.add(Self.낱말("大丈夫", "だいじょうぶ"))
        #expect(collection.words.count == 1)

        // 표기가 같아도 읽기가 다르면 다른 낱말이다 — 机(つくえ)와 机(つき).
        collection.add(Self.낱말("机", "つくえ"))
        collection.add(Self.낱말("机", "つき"))
        #expect(collection.words.count == 3)
    }

    @Test("담긴 것인지 물어볼 수 있다")
    func 담김여부() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        let 낱말 = Self.낱말("約束", "やくそく")
        #expect(!collection.contains(낱말))
        collection.add(낱말)
        #expect(collection.contains(낱말))
    }

    @Test("빼면 사라지고, 그것도 남는다")
    func 빼기() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        let 낱말 = Self.낱말("約束", "やくそく")
        collection.add(낱말)
        collection.remove(낱말)
        #expect(collection.words.isEmpty)
        #expect(WordCollection(path: path).words.isEmpty)
    }

    @Test("파일이 없으면 빈 채로 시작한다")
    func 첫실행() {
        #expect(WordCollection(path: Self.임시경로()).words.isEmpty)
    }

    @Test("파일이 깨져 있어도 앱이 죽지 않는다")
    func 깨진파일() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }
        try "이건 JSON 이 아니다".write(toFile: path, atomically: true, encoding: .utf8)
        #expect(WordCollection(path: path).words.isEmpty)
    }

    @Test("나중에 필드가 늘어도 예전에 담은 것을 읽는다")
    func 옛파일() throws {
        // Swift 의 자동 Decodable 은 기본값을 쓰지 않아서, 필드를 하나 더하면
        // 예전 파일이 **통째로** 안 읽힌다. 모은 것이 통째로 사라지는 일이 된다.
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        let 옛것 = """
        [{"headword":"約束","reading":"やくそく","hangul":"야쿠소쿠","gloss":"약속",
          "collectedAt":"2026-08-31T00:00:00Z"}]
        """
        try 옛것.write(toFile: path, atomically: true, encoding: .utf8)
        #expect(WordCollection(path: path).words.map(\.headword) == ["約束"])
    }

    @Test("날짜는 넣은 대로 나온다")
    func 날짜짝() throws {
        // 인코더에 전략을 정하고 디코더에 안 정하면, 날짜 든 파일만 조용히 안 읽힌다.
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("約束"))
        let 담긴때 = try #require(collection.words.first?.collectedAt)
        let 다시 = try #require(WordCollection(path: path).words.first?.collectedAt)
        #expect(abs(담긴때.timeIntervalSince(다시)) < 1)
    }
}

/// 모은 낱말을 날짜로 묶는다.
///
/// 기획의 "화별 교재"가 여기서 시작한다. 앱은 사용자가 어느 화를 보다 걸렸는지 모르지만,
/// **애니 한 화를 보면서 찾은 것들은 같은 날 모인다.** 지어내지 않고 가진 재료로 묶는다.
@Suite("날짜로 묶기")
struct CollectionDayTests {

    static func 낱말(_ 표기: String, _ 날짜: String) -> CollectedWord {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = TimeZone.current
        return CollectedWord(headword: 표기, reading: "よみ", hangul: "요미", gloss: "뜻",
                             collectedAt: f.date(from: 날짜)!)
    }

    @Test("같은 날 모은 것끼리 묶인다")
    func 묶기() {
        let words = [Self.낱말("三", "2026-08-31 09:00"),
                     Self.낱말("二", "2026-08-30 22:10"),
                     Self.낱말("一", "2026-08-30 21:00")]
        let days = CollectedWord.byDay(words)
        #expect(days.count == 2)
        #expect(days.first?.words.map(\.headword) == ["三"])
        #expect(days.last?.words.map(\.headword) == ["二", "一"])
    }

    @Test("최근 날이 먼저 온다")
    func 최신순() {
        let days = CollectedWord.byDay([Self.낱말("옛", "2026-08-01 10:00"),
                                        Self.낱말("새", "2026-08-31 10:00")])
        #expect(days.first?.words.first?.headword == "새")
    }

    @Test("자정을 넘겨도 날은 갈린다")
    func 자정() {
        // 밤늦게 보다가 자정을 넘기면 다른 날이 된다. 아쉽지만 날짜는 날짜다 —
        // 지어낸 규칙(새벽 4시까지는 어제)을 두면 사용자가 예측할 수 없다.
        let days = CollectedWord.byDay([Self.낱말("늦", "2026-08-30 23:58"),
                                        Self.낱말("넘", "2026-08-31 00:03")])
        #expect(days.count == 2)
    }

    @Test("빈 것은 빈 채로")
    func 빈것() { #expect(CollectedWord.byDay([]).isEmpty) }
}
