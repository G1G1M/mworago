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

    /// 외래어의 확장음. **작은 가나가 앞 글자와 합쳐진다.**
    ///
    /// 합치지 못하면 그 글자가 **음차에 일본어로 그대로 남는다** — 화면에
    /// `푸로지ぇ쿠토` 가 적힌다. 사전의 읽기 265,528개 중 15,427개(5.8%)에
    /// 작은 모음이 들어 있다.
    @Test("외래어의 작은 가나는 앞 글자와 합쳐진다", arguments: [
        ("チェック", "쳇쿠"),          // い단 + ぇ → 평모음 ㅔ
        ("プロジェクト", "푸로제쿠토"),
        ("ジェーン", "젠"),            // 장음은 버리므로 ん 이 앞 음절에 붙는다
        ("パーティー", "파티"),        // え단 + ぃ → ㅣ
        ("メディア", "메디아"),
        ("ファイル", "화이루"),        // う단 + 작은 모음 → w 계열
        ("フィルム", "휘루무"),
        ("ウォルター", "워루타"),
        ("デュエル", "듀에루"),        // え단 + ゅ → 요음 ㅠ
        ("ヴァン", "반"),              // ヴ 는 ば행으로 적는다
        ("ねぇ", "네"),                // え단 + ぇ → 같은 모음이라 겹치지 않는다
        ("さぁ", "사"),
        ("かなぁ", "카나"),
    ])
    func 외래어확장음(_ 가나: String, _ 기대: String) {
        #expect(KanaToHangul.transliterate(가나) == 기대)
    }

    @Test("음차에 일본어를 남기지 않는다")
    func 일본어를_남기지_않는다() {
        // **이 규칙이 곧 잣대다.** 어떤 가나가 오든 한글만 나와야 한다 —
        // 표에 없는 글자를 그대로 흘리면 화면에 일본어가 섞인다.
        let 가나범위: ClosedRange<UInt32> = 0x3041...0x3096      // 히라가나
        for scalar in 가나범위 {
            guard let unicode = Unicode.Scalar(scalar) else { continue }
            let 음차 = KanaToHangul.transliterate(String(Character(unicode)))
            #expect(음차.unicodeScalars.allSatisfy { !가나범위.contains($0.value) },
                    "\(Character(unicode)) → \(음차)")
        }
    }

    @Test("조사라도 は·へ 하나가 아니면 표대로 적는다")
    func 다른조사() {
        // 표는 글자 하나에만 걸린다. `には`·`まで` 처럼 여러 자인 것을
        // 통째로 바꾸려 들면 안 되는 자리까지 손댄다.
        #expect(KanaToHangul.transliterate("まで", asParticle: true) == "마데")
        #expect(KanaToHangul.transliterate("から", asParticle: true) == "카라")
    }
}
