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
