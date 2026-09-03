import Testing
@testable import MworagoDomain

@Suite("가나 → 한글 음차")
struct KanaToHangulTests {

    /// 손으로 쓴 케이스 50개의 음차를 이 규칙이 재현해야 한다.
    /// 재현하지 못하면 표기 관행을 잘못 잡은 것이다.
    @Test("손으로 쓴 음차를 재현한다", arguments: [
        ("だいじょうぶ", "다이죠부"),    // 장음 う 생략
        ("ありがとう", "아리가토"),      // 끝 장음 생략
        ("さいこう", "사이코"),
        ("ほんとうに", "혼토니"),        // 발음 ん + 중간 장음
        ("せんぱい", "센빠이"),          // ん 받침 + 어중 ぱ는 경음
        ("いっしょに", "잇쇼니"),        // 촉음 っ 받침 + 요음
        ("よかった", "요캇타"),
        ("ぜんぜん", "젠젠"),
        ("つかれた", "츠카레타"),        // つ
        ("きをつけて", "키오츠케테"),    // 조사 を는 "오"
        ("すごい", "스고이"),
        ("たのしい", "타노시이"),
        ("はずかしい", "하즈카시이"),
        ("だまれ", "다마레"),
        ("やくそく", "야쿠소쿠"),
    ])
    func 관행재현(_ 가나: String, _ 기대: String) {
        #expect(KanaToHangul.transliterate(가나) == 기대)
    }

    @Test("청음은 격음, 탁음은 평음으로 적는 관행")
    func 청탁구분() {
        #expect(KanaToHangul.transliterate("かた") == "카타")
        #expect(KanaToHangul.transliterate("がだ") == "가다")
        #expect(KanaToHangul.transliterate("ぱぴ") == "파피")   // 어두 ぱ행은 격음
    }

    @Test("ぱ행은 촉음·발음 뒤에서만 경음이 된다")
    func 경음조건() {
        // 일본 고유어에서 ぱ행은 っ·ん 뒤에만 나타난다. 그 밖의 자리는 대개 외래어이고,
        // 외래어는 격음으로 적는 것이 관행이다.
        #expect(KanaToHangul.transliterate("せんぱい") == "센빠이")
        #expect(KanaToHangul.transliterate("いっぱい") == "잇빠이")
        #expect(KanaToHangul.transliterate("ピアノ") == "피아노")
        #expect(KanaToHangul.transliterate("ピアニスト") == "피아니스토")
        #expect(KanaToHangul.transliterate("パン") == "판")
    }

    @Test("가타카나도 같게 적는다")
    func 가타카나() {
        #expect(KanaToHangul.transliterate("マジ") == "마지")
        #expect(KanaToHangul.transliterate("ナイフ") == "나이후")
    }

    @Test("え단 뒤 い는 남긴다")
    func 에이() {
        // お단·う단 뒤 う는 버리지만, せんせい는 "센세이"라고 적는다
        #expect(KanaToHangul.transliterate("せんせい") == "센세이")
    }

    @Test("가나가 아닌 글자는 그대로 둔다")
    func 비가나() {
        #expect(KanaToHangul.transliterate("大丈夫") == "大丈夫")
        #expect(KanaToHangul.transliterate("").isEmpty)
    }
}
