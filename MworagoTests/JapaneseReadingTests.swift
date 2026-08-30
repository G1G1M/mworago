import Testing
@testable import MworagoCore

@Suite("일본어 문장 읽기")
struct JapaneseReadingTests {

    @Test("한자 문장을 낱말과 읽기로 나눈다")
    func 분석() {
        let tokens = JapaneseReading.analyze("頭が痛い")
        #expect(tokens.map(\.surface) == ["頭", "が", "痛い"])
        #expect(tokens.map(\.reading) == ["あたま", "が", "いたい"])
    }

    @Test("구어 축약도 읽는다")
    func 구어() {
        let tokens = JapaneseReading.analyze("何をしてるの")
        #expect(tokens.map(\.reading).joined() == "なにをしてるの" || tokens.map(\.reading).joined() == "なんをしてるの")
    }

    @Test("조사는 표기대로 읽는다")
    func 조사표기() {
        // は는 "와"로 발음되지만 적기는 は로 적는다. 음차도 표기를 따른다
        let tokens = JapaneseReading.analyze("彼は本を読んだ")
        let reading = tokens.map(\.reading).joined()
        #expect(reading.contains("は"))
        #expect(reading.contains("を"))
    }

    @Test("문장부호는 걸러진다")
    func 부호() {
        let tokens = JapaneseReading.analyze("先輩、大丈夫ですか")
        #expect(!tokens.contains { $0.surface == "、" })
        #expect(tokens.map(\.surface).contains("大丈夫"))
    }

    @Test("읽기를 못 만들면 그 낱말은 없는 것으로")
    func 실패() {
        // 로마자·숫자는 읽기가 나오지 않는다
        let tokens = JapaneseReading.analyze("ABC")
        #expect(tokens.isEmpty)
    }

    @Test("빈 문자열")
    func 빈문자열() {
        #expect(JapaneseReading.analyze("").isEmpty)
    }
}

/// 자막 코퍼스에 섞여 든 다른 언어.
///
/// JESC 일본어 칸에는 중국어가 섞여 있다. 한자는 중국어에도 쓰이므로 낱말 하나만 보고는
/// 가릴 수 없고, 토크나이저는 그 한자를 일본어 음으로 읽는다 — 我 가 が 로.
///
/// **걸러 보았으나 손해였다.** 문장에 가나가 없으면 건너뛰게 하자 오염은 사라졌지만
/// 낱말 3위안이 147에서 146으로, 분절 완전일치가 30.3%에서 30.0%로 떨어졌다.
/// 오염된 항목은 순위가 낮아 답을 바꾸지 못하는데, 함께 걸러진 짧은 일본어
/// (한자만으로 된 줄)의 손해가 더 컸다. 그래서 지금은 거르지 않는다.
@Suite("일본어가 아닌 문장")
struct ForeignSentenceTests {

    @Test("한자만 있는 줄도 그대로 읽는다 — 걸러 보았더니 손해였다")
    func 한자만() {
        // 중국어가 섞여 들지만, 그 항목들은 순위가 낮아 답을 바꾸지 못한다.
        #expect(!JapaneseReading.analyze("我生分上").isEmpty)
    }

    @Test("가나가 섞여 있으면 그대로 읽는다")
    func 일본어() {
        let tokens = JapaneseReading.analyze("頭が痛い")
        #expect(tokens.map(\.surface) == ["頭", "が", "痛い"])
        #expect(tokens.first?.reading == "あたま")
    }

    @Test("읽기가 빈 낱말은 담지 않는다")
    func 빈읽기() {
        // 你好 는 읽기가 빈 문자열로 나오는데, allSatisfy 는 빈 것에 참이라 그대로 통과했다.
        // 읽기 없는 낱말은 빈도 목록에서 아무 쓸모가 없다. 이쪽은 진짜 버그라 남겨 둔다.
        #expect(JapaneseReading.analyze("你好と世界").allSatisfy { !$0.reading.isEmpty })
    }

    @Test("빈 문장과 로마자 문장은 아무것도 내지 않는다")
    func 그밖() {
        #expect(JapaneseReading.analyze("").isEmpty)
        #expect(JapaneseReading.analyze("hello world").isEmpty)
    }
}
