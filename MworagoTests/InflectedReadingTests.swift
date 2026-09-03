import Testing
@testable import MworagoDomain

/// 표제어의 읽기에서 활용형의 읽기를 만든다.
///
/// Tanaka Corpus 는 표제어의 읽기만 적어 준다(`読む(よむ){読んだ}`). 실제 발음
/// `よんだ` 는 어디에도 없으므로 만들어 내야 하는데, 여기서 만든 읽기가 그대로
/// 분절 케이스의 **입력**(한글 음차)이 된다. 틀리면 케이스 자체가 못 쓰게 된다.
@Suite("활용형의 읽기")
struct InflectedReadingTests {

    @Test("한자 어간의 읽기는 활용해도 그대로다")
    func 어간유지() {
        // 読 = よ 는 어미가 무엇으로 바뀌든 그대로다.
        #expect(InflectedReading.make(headword: "読む", reading: "よむ", surface: "読んだ") == "よんだ")
        #expect(InflectedReading.make(headword: "行く", reading: "いく", surface: "行った") == "いった")
        #expect(InflectedReading.make(headword: "着く", reading: "つく", surface: "着いていない") == "ついていない")
    }

    @Test("표면형이 전부 가나면 그것이 곧 읽기다")
    func 가나표면형() {
        #expect(InflectedReading.make(headword: "する", reading: "する", surface: "してる") == "してる")
    }

    @Test("어간이 없거나 어긋나면 만들지 않는다")
    func 만들수없음() {
        // 앞이 가나로 시작하는 복합 동사는 어간을 뗄 수 없다.
        #expect(InflectedReading.make(headword: "やって来る", reading: "やってくる", surface: "やって来た") == nil)
        // 표면형이 표제어의 어간으로 시작하지 않으면 짝이 아니다.
        #expect(InflectedReading.make(headword: "読む", reading: "よむ", surface: "聞いた") == nil)
    }

    @Test("来る 는 어간의 읽기가 바뀐다")
    func 카행변격() {
        // カ変動詞 하나뿐인 예외다. 어간이 こ·き·く 로 갈린다.
        // 이것을 놓쳐서 2,000개 케이스 중 67개(3.4%)가 `来た → くた` 로 굳어 있었다.
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来る") == "くる")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来れば") == "くれば")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来た") == "きた")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来て") == "きて")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来ます") == "きます")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来ました") == "きました")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来ている") == "きている")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来ない") == "こない")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来られる") == "こられる")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来よう") == "こよう")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来い") == "こい")
        // ら抜き言葉. 来られる 에서 ら 를 뺀 것이라 어간은 こ 다 — 来れば(くれば)와 갈린다.
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来れる") == "これる")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来れます") == "これます")
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来れません") == "これません")
        // 어미가 없는 連用形. `花見に来` 처럼 문장 끝에 온다.
        #expect(InflectedReading.make(headword: "来る", reading: "くる", surface: "来") == "き")
    }

    @Test("来 로 시작해도 来る 가 아니면 건드리지 않는다")
    func 来가든다른낱말() {
        // 出来る 의 어간은 出来(でき) 다. 来る 규칙을 들이대면 망가진다.
        #expect(InflectedReading.make(headword: "出来る", reading: "できる", surface: "出来た") == "できた")
        // 활용하지 않은 낱말은 표제어의 읽기 그대로다.
        #expect(InflectedReading.make(headword: "来週", reading: "らいしゅう", surface: "来週") == "らいしゅう")
    }
}
