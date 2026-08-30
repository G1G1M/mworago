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
