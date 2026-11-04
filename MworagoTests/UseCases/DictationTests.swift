import Testing
@testable import MworagoDomain
@testable import MworagoUseCases

/// 받아쓰기는 맞고 틀림이 아니라 **그렇게 쳐도 그 낱말에 닿는가**를 본다.
@Suite("받아쓰기")
struct DictationTests {

    @Test("표기법이 달라도 같은 낱말에 닿으면 닿은 것이다")
    func 여러갈래() {
        #expect(Dictation.check("다이죠부", reading: "だいじょうぶ") == .reached)
        #expect(Dictation.check("다이조부", reading: "だいじょうぶ") == .reached)
        #expect(Dictation.check("아리가토우", reading: "ありがとう") == .reached)
        #expect(Dictation.check("츠쿠에", reading: "つくえ") == .reached)
        #expect(Dictation.check("쓰쿠에", reading: "つくえ") == .reached)
        // 띄어 써도 같다.
        #expect(Dictation.check("다이 죠부", reading: "だいじょうぶ") == .reached)
    }

    @Test("탁음 하나가 다르면 그 글자를 고친 소리를 알려 준다")
    func 탁음() {
        #expect(Dictation.check("캇코", reading: "がっこう") == .close(hangul: "갓코", change: .voicing))
    }

    @Test("ん 을 흘려들었으면 그 자리를 알려 준다")
    func 받침() {
        #expect(Dictation.check("세파이", reading: "せんぱい") == .close(hangul: "센파이", change: .nasalAdded))
    }

    @Test("끝자리 조사 は 는 읽는 대로 쳐도 닿는다")
    func 조사() {
        #expect(Dictation.check("콘니치와", reading: "こんにちは") == .reached)
    }

    @Test("담을 때 친 한글은 그대로 받는다")
    func 담을때() {
        #expect(Dictation.check("뭐든", reading: "なんでも", alsoAccepts: ["뭐든"]) == .reached)
    }

    @Test("한 글자로 못 고치면 닿지 않은 것이다")
    func 안닿음() {
        #expect(Dictation.check("사쿠라", reading: "がっこう") == .missed)
    }

    @Test("비었거나 한글이 아니면 묻지 않는다")
    func 빈것() {
        #expect(Dictation.check("  ", reading: "がっこう") == .empty)
        #expect(Dictation.check("gakkou", reading: "がっこう") == .empty)
    }
}
