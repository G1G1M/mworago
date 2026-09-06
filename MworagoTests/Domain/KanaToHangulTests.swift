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

    // MARK: 조사로 쓰인 は·へ

    @Test("조사로 쓰인 は·へ 는 읽는 대로 적는다")
    func 조사음차() {
        // `와타시와` 를 친 사람의 카드에 "하"가 적히고 있었다. 치지도 않았고
        // 들리지도 않는 소리다 — 찾을 때 `Transliterator.particleSpellings` 가
        // 연 사이를 보여 줄 때 여기서 닫는다.
        #expect(KanaToHangul.transliterate("は", asParticle: true) == "와")
        #expect(KanaToHangul.transliterate("へ", asParticle: true) == "에")
    }

    @Test("조사가 아니면 표기대로 적는다")
    func 조사아닌것() {
        // 갈리는 것은 품사이지 글자가 아니다. 가나표의 は 도, 낱말 `葉`(잎)의
        // 읽기 は 도 "하"가 맞다.
        #expect(KanaToHangul.transliterate("は", asParticle: false) == "하")
        #expect(KanaToHangul.transliterate("へ", asParticle: false) == "헤")
        #expect(KanaToHangul.transliterate("は") == "하")
    }

    @Test("を 는 조사든 아니든 오다")
    func 오() {
        // 표기와 발음이 어긋나는 셋 중 を 는 표에서도 "오"라 갈릴 것이 없다.
        #expect(KanaToHangul.transliterate("を", asParticle: true) == "오")
        #expect(KanaToHangul.transliterate("を", asParticle: false) == "오")
    }

    @Test("조사라도 は·へ 하나가 아니면 표대로 적는다")
    func 다른조사() {
        // 표는 글자 하나에만 걸린다. `には`·`まで` 처럼 여러 자인 것을
        // 통째로 바꾸려 들면 안 되는 자리까지 손댄다.
        #expect(KanaToHangul.transliterate("まで", asParticle: true) == "마데")
        #expect(KanaToHangul.transliterate("から", asParticle: true) == "카라")
    }
}
