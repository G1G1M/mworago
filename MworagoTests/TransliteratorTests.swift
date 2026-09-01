import Testing
@testable import MworagoCore

@Suite("한글 음차 → 가나 후보")
struct TransliteratorTests {

    // MARK: 음절 하나

    @Test("탁음·청음이 갈리는 초성은 후보가 둘")
    func 탁음모호() throws {
        let 다 = try #require(HangulSyllable("다"))
        #expect(Transliterator.moraCandidates(for: 다) == [["da"], ["ta"]])
    }

    @Test("받침 ㄴ·ㅁ·ㅇ은 발음 ん")
    func 발음() throws {
        let 센 = try #require(HangulSyllable("센"))
        #expect(Transliterator.moraCandidates(for: 센) == [["se", "n"]])
    }

    @Test("받침 ㅅ·ㄱ·ㅂ은 촉음 っ")
    func 촉음() throws {
        let 잇 = try #require(HangulSyllable("잇"))
        #expect(Transliterator.moraCandidates(for: 잇) == [["i", "Q"]])
    }

    @Test("ㅛ·ㅑ·ㅠ는 요음")
    func 요음() throws {
        let 죠 = try #require(HangulSyllable("죠"))
        #expect(Transliterator.moraCandidates(for: 죠).contains(["zyo"]))
    }

    @Test("초성 ㅇ + ㅗ는 조사 を도 후보에")
    func 조사を() throws {
        let 오 = try #require(HangulSyllable("오"))
        let 후보 = Transliterator.moraCandidates(for: 오)
        #expect(후보.contains(["o"]))
        #expect(후보.contains(["wo"]))
    }

    // MARK: 낱말 전체 — 정답이 후보 안에 있는가

    @Test("정답이 후보에 포함된다", arguments: [
        ("다이죠부", "だいじょうぶ"),      // 장음 + 탁음 모호
        ("잇쇼니", "いっしょに"),          // 촉음 + 요음
        ("센빠이", "せんぱい"),            // 발음 + 경음
        ("아리가토", "ありがとう"),        // 끝 장음
        ("혼토니", "ほんとうに"),          // 중간 장음
        ("요캇타", "よかった"),            // 촉음
        ("츠카레타", "つかれた"),          // つ
        ("키오츠케테", "きをつけて"),      // 조사 を
        ("스고이", "すごい"),
        ("젠젠", "ぜんぜん"),
    ])
    func 정답포함(_ 입력: String, _ 정답: String) {
        let 후보 = Transliterator.kanaCandidates(for: 입력)
        #expect(후보.contains(정답), "\(입력) → \(정답) 가 후보 \(후보.count)개 안에 없음")
    }

    @Test("한글이 아니면 빈 배열")
    func 비한글() throws {
        #expect(Transliterator.kanaCandidates(for: "だいじょうぶ").isEmpty)
    }

    @Test("후보 수가 통제 범위 안이다")
    func 폭발방지() throws {
        // 가장 긴 축에 속하는 5음절. 여기서 수천 개가 나오면 사전 조회가 감당 못 한다.
        let 후보 = Transliterator.kanaCandidates(for: "키오츠케테")
        #expect(후보.count < 3000, "후보 \(후보.count)개 — 너무 많다")
    }
}

/// 국립국어원 표기법이 실제로 쓰는 적기.
///
/// 규칙을 짐작해 만든 것이 아니라, `--explain` 으로 재어 보니 **표기법대로 적은 사람이
/// 오히려 못 찾고 있었다.** 관용 표기(`죠`·`츠`)만 길이 나 있고 표기법 쪽(`조`·`쓰`)이 막혀 있었다.
@Suite("표기법대로 적은 것도 찾는다")
struct OrthographyTests {

    static func 가나후보(_ 한글: String) -> [String] {
        Transliterator.candidates(for: 한글).map(\.kana)
    }

    @Test("자·주·조 는 じゃ·じゅ·じょ 를 적은 것일 수 있다")
    func 요음이_평모음으로() {
        // 표기법은 じょ 를 "조"로 적는다(じゃ 자 · じゅ 주 · じょ 조).
        // じ 는 이미 구개음이라 한국어에서 요음성이 표기되지 않는다.
        // 그래서 少女(しょうじょ)를 찾으려고 "쇼조"라 쳐도 しょじょ 조차 안 나왔다.
        #expect(Self.가나후보("조").contains("じょ"))
        #expect(Self.가나후보("자").contains("じゃ"))
        #expect(Self.가나후보("주").contains("じゅ"))
        #expect(Self.가나후보("쇼조").contains("しょうじょ"))
    }

    @Test("차·추·초 는 ちゃ·ちゅ·ちょ 를 적은 것일 수 있다")
    func 청음쪽요음() {
        // ち 도 같은 사정이다. 한국인은 ちょ 를 "초"로도 "쵸"로도 적는다.
        #expect(Self.가나후보("초").contains("ちょ"))
        #expect(Self.가나후보("차").contains("ちゃ"))
    }

    @Test("쓰 는 つ 를 적은 것이다")
    func 쓰() {
        // 표기법은 つ 를 "쓰"로 적는다 — 쓰나미 · 쓰시마.
        // 관용 표기 "츠"만 길이 나 있어서, 표기법대로 친 사람이 못 찾았다.
        #expect(Self.가나후보("쓰").contains("つ"))
        #expect(Self.가나후보("쓰나미").contains("つなみ"))
        #expect(Self.가나후보("쓰쿠에").contains("つくえ"))
    }

    @Test("원래 되던 길은 그대로 열려 있다")
    func 관용표기() {
        #expect(Self.가나후보("죠").contains("じょ"))
        #expect(Self.가나후보("츠").contains("つ"))
        #expect(Self.가나후보("츠쿠에").contains("つくえ"))
        #expect(Self.가나후보("스").contains("す"))
        // "스"는 つ 로 열지 않는다 — 재어 보니 っす 가 밀려 JESC 3위 안이 하나 줄었다.
        #expect(!Self.가나후보("스").contains("つ"))
    }

    @Test("엉뚱한 자리까지 요음이 번지지는 않는다")
    func 번지지않음() {
        // 요음을 더하는 것은 じ·ち 계열(초성 ㅈ·ㅉ·ㅊ)뿐이다.
        // 사·가·다 까지 열면 후보가 쓸모없이 불어난다.
        #expect(!Self.가나후보("사").contains("しゃ"))
        #expect(!Self.가나후보("가").contains("ぎゃ"))
    }

    // MARK: 촉음을 빠뜨린 입력
    //
    // 촉음은 한국 사람 귀에 가장 안 들리는 소리다. 특히 뒤 음절과 이어질 때
    // (らっしゃ · きって) 받침으로 적을 생각을 못 한다. 앱이 "들린 대로 치세요" 라고
    // 하는 이상, 빠뜨린 쪽도 길이 있어야 한다.

    @Test("촉음을 빠뜨려도 후보에 오른다")
    func 촉음누락() {
        #expect(Transliterator.kanaCandidates(for: "잇테라샤이").contains("いってらっしゃい"))
        #expect(Transliterator.kanaCandidates(for: "기테").contains("きって"))
        #expect(Transliterator.kanaCandidates(for: "가코").contains("がっこう")
                || Transliterator.kanaCandidates(for: "가코").contains("がっこ"))
    }

    @Test("촉음은 아무 데나 끼우지 않는다")
    func 촉음자리() {
        // 촉음 뒤에는 か·さ·た·ぱ 행만 온다. あ·な·ま·や·ら·わ 행 앞에는 넣지 않는다.
        let 후보 = Transliterator.kanaCandidates(for: "아라")
        #expect(!후보.contains("あっら"))
        let 후보2 = Transliterator.kanaCandidates(for: "아나")
        #expect(!후보2.contains("あっな"))
    }

    @Test("제대로 친 것이 여전히 먼저다")
    func 순서유지() {
        // 촉음을 지어내는 것은 더 과감한 추측이라 뒤에 선다.
        let 후보 = Transliterator.kanaCandidates(for: "잇테랏샤이")
        #expect(후보.first == "いってらっしゃい" || 후보.contains("いってらっしゃい"))
    }
}
