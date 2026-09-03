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

@Suite("사전 조회 키")
struct LookupKeyTests {

    @Test("장음을 어떻게 적었든 같은 키가 된다")
    func 장음접기() {
        // 가타카나 장음부호와 히라가나 장음이 만나야 외래어가 찾힌다
        #expect(KanaTable.lookupKey("コート") == KanaTable.lookupKey("こうと"))
        #expect(KanaTable.lookupKey("ビール") == KanaTable.lookupKey("びいる"))
        #expect(KanaTable.lookupKey("スキー") == KanaTable.lookupKey("すきい"))
        #expect(KanaTable.lookupKey("カード") == KanaTable.lookupKey("かあど"))
        #expect(KanaTable.lookupKey("ケーキ") == KanaTable.lookupKey("けいき"))
        // 히라가나끼리도 갈라져 있다 — お단은 う로도 お로도 늘인다
        #expect(KanaTable.lookupKey("とおり") == KanaTable.lookupKey("とうり"))
        #expect(KanaTable.lookupKey("おおきい") == KanaTable.lookupKey("おうきい"))
        #expect(KanaTable.lookupKey("おねえさん") == KanaTable.lookupKey("おねいさん"))
    }

    @Test("장음이 아닌 이어짐은 접지 않는다")
    func 안접는것() {
        // あ단 뒤의 い는 장음이 아니라 이중모음이다 — 愛(あい)
        #expect(KanaTable.lookupKey("あい") == "あい")
        #expect(KanaTable.lookupKey("ここ") == "ここ")
        // 장음을 지운 꼴과 뭉쳐서도 안 된다. コート(외투)와 こと(일)는 다른 낱말이다
        #expect(KanaTable.lookupKey("コート") != KanaTable.lookupKey("こと"))
        #expect(KanaTable.lookupKey("こと") == "こと")
    }

    @Test("가나가 아닌 글자는 건드리지 않는다")
    func 한자() {
        #expect(KanaTable.lookupKey("大丈夫") == "大丈夫")
    }

    // MARK: 한 줄로 세운 차례 — 글자를 한 장씩 넘겨 볼 때 쓴다

    @Test("표 차례 그대로 늘어선다")
    func 차례() {
        // 청음 첫 행부터 시작한다
        #expect(KanaTable.ordered.prefix(5) == ["あ", "い", "う", "え", "お"])
        #expect(KanaTable.ordered.prefix(10).suffix(5) == ["か", "き", "く", "け", "こ"])
        // 청음이 끝나면 탁음, 그다음이 요음이다
        let ん = KanaTable.ordered.firstIndex(of: "ん")!
        let が = KanaTable.ordered.firstIndex(of: "が")!
        let きゃ = KanaTable.ordered.firstIndex(of: "きゃ")!
        #expect(ん < が)
        #expect(が < きゃ)
    }

    @Test("빈 자리는 빠진다")
    func 빈칸() {
        // や행은 다섯 칸 중 셋만 글자다. 격자는 자리를 지키지만 이 줄에는 없는 자리다
        let や = KanaTable.ordered.firstIndex(of: "や")!
        #expect(KanaTable.ordered[や + 1] == "ゆ")
        #expect(KanaTable.ordered[や + 2] == "よ")
        #expect(!KanaTable.ordered.contains(""))
    }

    @Test("같은 글자가 두 번 서지 않는다")
    func 중복없음() {
        #expect(Set(KanaTable.ordered).count == KanaTable.ordered.count)
    }
}
