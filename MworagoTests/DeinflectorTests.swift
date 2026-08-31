import Testing
@testable import MworagoCore

@Suite("활용 역변환")
struct DeinflectorTests {

    /// 되돌린 형태들 중 기대한 게 있는지, 그때 활용 이름이 무엇인지 본다.
    func 찾기(_ 입력: String, _ 기대: String) -> Deinflection? {
        Deinflector.candidates(for: 입력).first { $0.form == 기대 }
    }

    @Test("자기 자신도 후보에 남는다")
    func 원형유지() {
        // 사전에 활용형 그대로 실린 항목(疲れた 등)을 놓치지 않기 위해
        let 후보 = Deinflector.candidates(for: "つかれた")
        #expect(후보.first?.form == "つかれた")
        #expect(후보.first?.rule == nil)
    }

    @Test("1단 동사 명령형: ろ → る")
    func 일단명령형() {
        #expect(찾기("やめろ", "やめる")?.rule == "명령형")
        #expect(찾기("きえろ", "きえる")?.rule == "명령형")
    }

    @Test("5단 동사 명령형: え단 → う단")
    func 오단명령형() {
        #expect(찾기("いそげ", "いそぐ")?.rule == "명령형")
        #expect(찾기("だまれ", "だまる")?.rule == "명령형")
        #expect(찾기("がんばれ", "がんばる")?.rule == "명령형")
    }

    @Test("い형용사 과거형: かった → い")
    func 형용사과거() {
        #expect(찾기("よかった", "よい")?.rule == "과거형")
    }

    @Test("1단 동사 て형·과거형")
    func 일단테형() {
        #expect(찾기("たすけて", "たすける")?.rule == "て형")
        #expect(찾기("つかれた", "つかれる")?.rule == "과거형")
    }

    @Test("5단 음편형은 원형 후보를 여럿 낸다")
    func 음편형() {
        // った는 う·つ·る 셋 중 어디서 왔는지 모른다. 고르는 건 사전 몫.
        let 후보 = Deinflector.candidates(for: "わかった").map(\.form)
        #expect(후보.contains("わかる"))
        #expect(후보.contains("わかう"))
        #expect(Deinflector.candidates(for: "よんだ").map(\.form).contains("よむ"))
    }

    @Test("조사 で를 뗀다")
    func 조사분리() {
        #expect(찾기("まじで", "まじ")?.rule == "조사 で")
    }

    @Test("너무 짧으면 건드리지 않는다")
    func 짧은말() {
        // "て" 한 글자를 て형으로 보면 온갖 오탐이 생긴다
        #expect(Deinflector.candidates(for: "て").count == 1)
        #expect(Deinflector.candidates(for: "む").count == 1)
    }

    @Test("진행형 축약 てる 를 되돌린다")
    func 진행형축약() {
        // 애니 대사에서 ている 는 거의 항상 てる 로 줄어든다
        #expect(찾기("たべてる", "たべる")?.rule == "진행형")
        #expect(찾기("よんでる", "よむ")?.rule == "진행형")
        #expect(찾기("かいてる", "かく")?.rule == "진행형")
        #expect(찾기("はなしてる", "はなす")?.rule == "진행형")
    }

    @Test("어간이 없는 축약도 되돌린다")
    func 어간없는축약() {
        // してる 는 する 의 축약이다. 떼고 나면 어간이 남지 않는다
        #expect(찾기("してる", "する")?.rule == "진행형")
        #expect(찾기("してた", "する")?.rule == "진행형 과거")
    }

    @Test("来る 는 형태마다 어간이 갈린다")
    func 카행변격() {
        // 일본어 불규칙 동사는 来る·する 둘뿐인데 둘 다 최빈출이다.
        // 규칙으로는 되돌릴 수 없어 형태마다 적는다 — きた 를 "た → る" 로 풀면
        // きる(着る)만 나오고 くる 는 후보에 오르지도 못한다.
        #expect(찾기("きた", "くる") != nil)
        #expect(찾기("きて", "くる") != nil)
        #expect(찾기("きます", "くる") != nil)
        #expect(찾기("こない", "くる") != nil)
        #expect(찾기("こい", "くる") != nil)
        #expect(찾기("きてる", "くる") != nil)
        // 복합 동사도 어미는 같다.
        #expect(찾기("やってきた", "やってくる") != nil)
        #expect(찾기("でてきて", "でてくる") != nil)
    }

    @Test("する 는 명사에 붙어 동사를 만든다")
    func 사행변격() {
        #expect(찾기("した", "する") != nil)
        #expect(찾기("して", "する") != nil)
        #expect(찾기("します", "する") != nil)
        #expect(찾기("しない", "する") != nil)
        // 명사+する 는 어간이 그대로 남는다.
        #expect(찾기("べんきょうした", "べんきょうする") != nil)
        #expect(찾기("あいして", "あいする") != nil)
    }

    @Test("기존 후보를 밀어내지 않는다")
    func 후보공존() {
        // 불규칙을 더해도 규칙으로 나오던 답은 그대로 있어야 한다.
        // きた 는 着た(きる)일 수도 있다. 두 답이 함께 후보에 있어야 사전이 고를 수 있다.
        #expect(찾기("きた", "きる") != nil)
        #expect(찾기("きた", "くる") != nil)
        #expect(찾기("はなした", "はなす") != nil)
        #expect(찾기("はなして", "はなす") != nil)
    }

    @Test("진행형 과거")
    func 진행형과거() {
        #expect(찾기("たべてた", "たべる")?.rule == "진행형 과거")
        #expect(찾기("よんでた", "よむ")?.rule == "진행형 과거")
    }
}
