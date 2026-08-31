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
        collection.add(Self.낱말("大丈夫", "だいじょうぶ", "다이죠부"), to: nil)
        collection.add(Self.낱말("約束", "やくそく", "야쿠소쿠"), to: nil)

        let 다시 = WordCollection(path: path)
        #expect(다시.words.map(\.headword) == ["約束", "大丈夫"])
    }

    @Test("나중에 담은 것이 위로 온다")
    func 최신순() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("一"), to: nil)
        collection.add(Self.낱말("二"), to: nil)
        collection.add(Self.낱말("三"), to: nil)
        // 방금 찾은 것이 눈앞에 있어야 한다. 스크롤해서 찾게 만들 이유가 없다.
        #expect(collection.words.map(\.headword) == ["三", "二", "一"])
    }

    @Test("같은 낱말을 또 담아도 하나다")
    func 중복() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        collection.add(Self.낱말("大丈夫", "だいじょうぶ"), to: nil)
        collection.add(Self.낱말("大丈夫", "だいじょうぶ"), to: nil)
        #expect(collection.words.count == 1)

        // 표기가 같아도 읽기가 다르면 다른 낱말이다 — 机(つくえ)와 机(つき).
        collection.add(Self.낱말("机", "つくえ"), to: nil)
        collection.add(Self.낱말("机", "つき"), to: nil)
        #expect(collection.words.count == 3)
    }

    @Test("담긴 것인지 물어볼 수 있다")
    func 담김여부() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        let 낱말 = Self.낱말("約束", "やくそく")
        #expect(!collection.contains(낱말))
        collection.add(낱말, to: nil)
        #expect(collection.contains(낱말))
    }

    @Test("빼면 사라지고, 그것도 남는다")
    func 빼기() throws {
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path) }

        var collection = WordCollection(path: path)
        let 낱말 = Self.낱말("約束", "やくそく")
        collection.add(낱말, to: nil)
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
        collection.add(Self.낱말("約束"), to: nil)
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

/// 묶음(폴더).
///
/// 날짜만으로는 부족하다 — 하루에 두 편을 보면 한 덩어리로 뭉치고, 한 편을 이틀에
/// 걸쳐 보면 갈라진다. "날짜가 곧 그 화"라는 전제가 실제 시청 습관과 어긋나는 자리다.
///
/// 그래서 **담는 순간에 어디에 넣을지 묻는다.** 한때는 미리 정해 두고 담을 때는 묻지
/// 않았는데, 앱은 사용자가 어느 화를 보는지 알 길이 없다 — 아는 사람에게 묻는 것이
/// 지어낸 대용품보다 정확하다. 대신 **지난번에 넣은 곳을 기억해** 미리 골라 둔다.
@Suite("모은 낱말 묶음")
struct WordCollectionFolderTests {

    static func 임시경로() -> String {
        NSTemporaryDirectory() + "mworago-folder-\(UUID().uuidString).json"
    }

    static func 낱말(_ 표기: String, _ 읽기: String) -> CollectedWord {
        CollectedWord(headword: 표기, reading: 읽기, hangul: "요미", gloss: "뜻")
    }

    @Test("담을 때 어디에 넣을지 받는다")
    func 담을때고르기() {
        var collection = WordCollection(path: Self.임시경로())
        collection.add(Self.낱말("犬", "いぬ"), to: "리코리스 3화")
        #expect(collection.words.first?.folder == "리코리스 3화")

        // 안 넣고 담을 수도 있다. 묶음은 거들 뿐이지 담기의 조건이 아니다.
        collection.add(Self.낱말("猫", "ねこ"), to: nil)
        #expect(collection.words.first?.folder == nil)
    }

    @Test("지난번에 넣은 곳을 기억한다 — 모달이 그것을 미리 골라 준다")
    func 지난번묶음() {
        let path = Self.임시경로()
        var collection = WordCollection(path: path)
        #expect(collection.lastFolder == nil)   // 처음에는 지난번이 없다

        collection.add(Self.낱말("犬", "いぬ"), to: "1화")
        #expect(collection.lastFolder == "1화")

        // 한 화를 몰아 담는 사이에 앱이 죽어도 그 자리를 잃지 않는다.
        #expect(WordCollection(path: path).lastFolder == "1화")

        collection.add(Self.낱말("猫", "ねこ"), to: "2화")
        #expect(collection.lastFolder == "2화")
    }

    @Test("안 넣고 담으면 다음번 기본도 안 넣기다")
    func 안넣기도기억() {
        // 기억하는 것은 "마지막에 고른 것"이지 "마지막에 고른 묶음"이 아니다.
        // 안 넣기를 골랐는데 다음에 또 묶음이 골라져 있으면 고른 적 없는 곳으로 간다.
        let path = Self.임시경로()
        var collection = WordCollection(path: path)
        collection.add(Self.낱말("犬", "いぬ"), to: "1화")
        collection.add(Self.낱말("猫", "ねこ"), to: nil)
        #expect(collection.lastFolder == nil)
        #expect(WordCollection(path: path).lastFolder == nil)
    }

    @Test("공백만 적은 이름은 묶음이 아니다")
    func 빈이름() {
        var collection = WordCollection(path: Self.임시경로())
        collection.add(Self.낱말("犬", "いぬ"), to: "   ")
        #expect(collection.words.first?.folder == nil)
        #expect(collection.lastFolder == nil)
    }

    @Test("전에 '지금 담는 곳'을 정해 둔 사람은 그 자리가 지난번 묶음이 된다")
    func 옛담는곳() throws {
        // 담는 방식을 바꾸기 전에 쓰던 파일이다. 그 사람이 마지막으로 정해 둔 곳이
        // 곧 마지막으로 담던 곳이라, 버리지 않고 이어받는다.
        let path = Self.임시경로()
        defer { try? FileManager.default.removeItem(atPath: path + ".folder") }
        try "리코리스 3화".write(toFile: path + ".folder", atomically: true, encoding: .utf8)
        #expect(WordCollection(path: path).lastFolder == "리코리스 3화")
    }

    @Test("낱말을 다 빼도 지난번 묶음은 고를 목록에 남는다")
    func 빈묶음도목록에() {
        var collection = WordCollection(path: Self.임시경로())
        let word = Self.낱말("犬", "いぬ")
        collection.add(word, to: "1화")
        collection.remove(word)
        // 묶음 이름은 낱말에서 거두는데, 방금 담은 곳이 목록에서 사라지면
        // 다음에 담을 때 같은 이름을 다시 쳐야 한다.
        #expect(collection.folderNames == ["1화"])
    }

    @Test("이미 담은 낱말을 또 담아도 지난번 묶음이 흔들리지 않는다")
    func 중복은무시() {
        var collection = WordCollection(path: Self.임시경로())
        let word = Self.낱말("犬", "いぬ")
        collection.add(word, to: "1화")
        collection.add(word, to: "2화")   // 아무 일도 일어나지 않는다
        #expect(collection.words.count == 1)
        #expect(collection.words.first?.folder == "1화")
        #expect(collection.lastFolder == "1화")
    }

    @Test("담은 뒤에도 묶음을 옮길 수 있다")
    func 옮기기() {
        let path = Self.임시경로()
        var collection = WordCollection(path: path)
        let word = Self.낱말("犬", "いぬ")
        collection.add(word, to: nil)
        collection.move(word, to: "1화")
        #expect(collection.words.first?.folder == "1화")
        #expect(WordCollection(path: path).words.first?.folder == "1화")

        collection.move(word, to: nil)
        #expect(collection.words.first?.folder == nil)
    }

    @Test("옮기는 것은 지난번 묶음을 바꾸지 않는다")
    func 옮겨도기억은그대로() {
        // 옮기기는 정리하는 일이고, 지난번 묶음은 "지금 무엇을 보고 있는가"의 흔적이다.
        // 어제 것을 정리했다고 오늘 담을 곳이 어제로 끌려가면 안 된다.
        var collection = WordCollection(path: Self.임시경로())
        let word = Self.낱말("犬", "いぬ")
        collection.add(word, to: "오늘 본 화")
        collection.move(word, to: "지난주에 본 화")
        #expect(collection.lastFolder == "오늘 본 화")
    }

    @Test("묶음으로 나눈다 — 아직 안 넣은 것이 마지막")
    func 묶음나누기() {
        let words = [Self.낱말("犬", "いぬ").movedTo("2화"),
                     Self.낱말("猫", "ねこ").movedTo("1화"),
                     Self.낱말("茶", "ちゃ")]
        #expect(CollectedWord.byFolder(words).map(\.name) == ["1화", "2화", nil])
    }

    @Test("묶음 칸이 없던 파일도 그대로 읽힌다")
    func 옛파일() throws {
        let path = Self.임시경로()
        let old = #"[{"headword":"犬","reading":"いぬ","hangul":"이누","gloss":"개","collectedAt":"2026-08-31T11:00:00Z"}]"#
        try old.write(toFile: path, atomically: true, encoding: .utf8)
        let collection = WordCollection(path: path)
        #expect(collection.words.count == 1)
        #expect(collection.words.first?.folder == nil)
    }
}
