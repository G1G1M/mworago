import Testing
@testable import MworagoCore

@Suite("훈령식 로마자 → 가나")
struct KanaTableTests {

    @Test("기본 오십음")
    func 기본() {
        #expect(KanaTable.kana(for: "a") == "あ")
        #expect(KanaTable.kana(for: "ka") == "か")
        #expect(KanaTable.kana(for: "si") == "し")
        #expect(KanaTable.kana(for: "tu") == "つ")
        #expect(KanaTable.kana(for: "ho") == "ほ")
    }

    @Test("탁음·반탁음")
    func 탁음() {
        #expect(KanaTable.kana(for: "ga") == "が")
        #expect(KanaTable.kana(for: "zi") == "じ")
        #expect(KanaTable.kana(for: "du") == "づ")
        #expect(KanaTable.kana(for: "pa") == "ぱ")
        #expect(KanaTable.kana(for: "bu") == "ぶ")
    }

    @Test("요음은 い단 + 작은 가나")
    func 요음() {
        #expect(KanaTable.kana(for: "kya") == "きゃ")
        #expect(KanaTable.kana(for: "syo") == "しょ")
        #expect(KanaTable.kana(for: "zyo") == "じょ")
        #expect(KanaTable.kana(for: "tyu") == "ちゅ")
    }

    @Test("특수 모라")
    func 특수() {
        #expect(KanaTable.kana(for: "n") == "ん")
        #expect(KanaTable.kana(for: "Q") == "っ")   // 촉음
        #expect(KanaTable.kana(for: "wo") == "を")
    }

    @Test("일본어에 없는 소리는 nil")
    func 없는소리() {
        #expect(KanaTable.kana(for: "yi") == nil)
        #expect(KanaTable.kana(for: "wu") == nil)
        #expect(KanaTable.kana(for: "zzz") == nil)
    }

    @Test("모라 열을 이어 붙여 가나 문자열로")
    func 문자열조립() {
        #expect(KanaTable.compose(["da", "i", "zyo", "u", "bu"]) == "だいじょうぶ")
        #expect(KanaTable.compose(["i", "Q", "syo", "ni"]) == "いっしょに")
        #expect(KanaTable.compose(["se", "n", "pa", "i"]) == "せんぱい")
        #expect(KanaTable.compose(["ka", "xx"]) == nil)
    }
}

@Suite("가나 표")
struct KanaChartTests {

    @Test("가타카나로 넘긴 뒤 되돌리면 그대로다")
    func 되돌리기() {
        #expect(KanaTable.toKatakana("あいうえお") == "アイウエオ")
        #expect(KanaTable.toKatakana("きゃっ") == "キャッ")
        #expect(KanaTable.toHiragana(KanaTable.toKatakana("しょうじょ")) == "しょうじょ")
        // 가나가 아닌 것은 건드리지 않는다.
        #expect(KanaTable.toKatakana("犬いぬ") == "犬イヌ")
    }

    @Test("표는 배우는 차례로 갈려 있다")
    func 차례() {
        let charts = KanaTable.charts
        #expect(charts.count == 3)
        // 청음 열 행 + ん 한 줄.
        #expect(charts[0].rows.count == 11)
        #expect(charts[0].rows[0] == ["あ", "い", "う", "え", "お"])
        // や행과 わ행은 빈 칸이 있다 — 없는 소리를 지어내지 않는다.
        #expect(charts[0].rows[7] == ["や", nil, "ゆ", nil, "よ"])
        #expect(charts[0].rows[9] == ["わ", nil, nil, nil, "を"])
        #expect(charts[1].rows[0] == ["が", "ぎ", "ぐ", "げ", "ご"])
        // 요음은 세 칸이다.
        #expect(charts[2].rows[0] == ["きゃ", "きゅ", "きょ"])
    }
}
