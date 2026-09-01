import Testing
import Foundation
@testable import MworagoCore

/// 조각들을 도로 한 문장으로 잇는 일.
///
/// 지금 화면은 낱말 카드만 늘어놓아서, 사용자가 원문을 머릿속으로 이어 붙이고 있다.
/// 그런데 **1위를 그냥 이어 붙이면 딴 문장이 된다** — 활용을 되돌려 찾았으므로
/// 조각이 사전형으로 돌아와 있기 때문이다. 되돌리기 전의 표면형으로 되돌려 놓아야 한다.
@Suite("문장 복원")
struct SentenceTests {

    static func 결과(_ 표기: String, _ 읽기: String,
                   표면: String? = nil, 되돌림: String? = nil,
                   가나로씀: Bool = false) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: ["-"], usuallyKana: 가나로씀)
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 표면 ?? 읽기,
                            deinflection: 되돌림, score: 0)
    }

    static func 조각(_ 한글: String, _ 결과들: [SearchResult]) -> Segment {
        Segment(hangul: 한글, results: 결과들)
    }

    @Test("한자를 살려 문장을 잇는다")
    func 기본() {
        // 아타마가이타이 → 頭が痛い. 조사도 한 조각이라 사이에 그대로 들어간다.
        let segments = [
            Self.조각("아타마", [Self.결과("頭", "あたま")]),
            Self.조각("가", [Self.결과("が", "が")]),
            Self.조각("이타이", [Self.결과("痛い", "いたい")]),
        ]
        #expect(segments.japanese == "頭が痛い")
    }

    @Test("일본어는 띄어 쓰지 않는다")
    func 붙여쓰기() {
        let segments = [
            Self.조각("다이죠부", [Self.결과("大丈夫", "だいじょうぶ")]),
            Self.조각("데스", [Self.결과("です", "です")]),
            Self.조각("카", [Self.결과("か", "か")]),
        ]
        #expect(segments.japanese == "大丈夫ですか")
    }

    @Test("활용을 되돌린 조각은 표면형으로 되돌려 놓는다")
    func 활용형() {
        // 止める(사전형)를 그대로 쓰면 "痛い止める" 라는, 아무도 하지 않은 말이 된다.
        // 사용자가 실제로 한 말은 やめろ 다.
        //
        // 止める 는 사전이 uk 라고 한 낱말이라 한자를 꺼내지 않는다. 그 표지를 빼먹으면
        // 활용형의 한자를 되살리는 길이 열려 止めろ 가 되므로, 실물과 같게 적어 둔다.
        let segments = [
            Self.조각("이타이", [Self.결과("痛い", "いたい")]),
            Self.조각("야메로", [Self.결과("止める", "やめる", 표면: "やめろ", 되돌림: "명령형",
                                        가나로씀: true)]),
        ]
        #expect(segments.japanese == "痛いやめろ")
    }

    @Test("사전이 가나로 쓴다고 한 낱말은 한자를 꺼내지 않는다")
    func 가나로쓰는낱말() {
        // JMdict 의 uk 태그. 止める(やめる)가 그렇고, 애니 자막도 한자로 안 쓴다.
        let segments = [Self.조각("야메루", [Self.결과("止める", "やめる", 가나로씀: true)])]
        #expect(segments.japanese == "やめる")
    }

    @Test("못 찾은 조각은 한글 그대로 남긴다")
    func 구멍() {
        // 지어내지 않는다. 못 찾았다는 사실이 문장에 그대로 보여야 어디가 틀렸는지 안다.
        let segments = [
            Self.조각("아타마", [Self.결과("頭", "あたま")]),
            Self.조각("쿄로쿄로", []),
        ]
        #expect(segments.japanese == "頭쿄로쿄로")
    }

    @Test("가나 문장은 사용자가 말한 소리 그대로다")
    func 가나문장() {
        // 소리를 듣고 찾아온 사람에게 가장 가까운 것이 가나다. 여기서도 사전형이 아니라 표면형이다.
        let segments = [
            Self.조각("이타이", [Self.결과("痛い", "いたい")]),
            Self.조각("야메로", [Self.결과("止める", "やめる", 표면: "やめろ", 되돌림: "명령형")]),
        ]
        #expect(segments.kana == "いたいやめろ")
    }

    @Test("빈 입력은 빈 문장이다")
    func 빈것() {
        #expect([Segment]().japanese.isEmpty)
        #expect([Segment]().kana.isEmpty)
    }

    @Test("조각 하나하나도 같은 규칙으로 보인다")
    func 조각단위() {
        // 문장 위에서 조각을 눌러 낱말을 보려면, 문장에 쓰인 글자와 조각의 글자가 같아야 한다.
        let 조각 = Self.조각("야메로", [Self.결과("止める", "やめる", 표면: "やめろ", 되돌림: "명령형",
                                              가나로씀: true)])
        #expect(조각.japanese == "やめろ")
        #expect([조각].japanese == 조각.japanese)
    }
}

/// 활용형에 한자를 되살리는 일.
///
/// 되돌리기 전 표면형은 가나다(`おこって`). 그런데 가나만으로는 낱말이 갈리지 않는다 —
/// `おこる` 는 怒る(화내다)이기도 하고 起こる(일어나다)이기도 하다.
/// 애플 번역기에 문장을 넘겨 보고 알았다. `彼はおこっている` 가 "그는 일어나고 있다"로
/// 돌아왔는데, 번역기 탓이 아니라 **우리가 한자를 잃고 넘긴 탓**이었다.
///
/// 사전이 그 낱말의 표기를 알려 주므로 어간은 되살릴 수 있다. 지어내는 것이 아니라
/// 사전에 실린 것을 도로 꺼내는 일이다.
@Suite("활용형의 한자")
struct InflectedWritingTests {

    static func 결과(_ 표기: String, _ 읽기: String, 표면: String, 되돌림: String,
                    가나로씀: Bool = false) -> SearchResult {
        let entry = DictEntry(readings: [DictForm(text: 읽기, priority: 0)],
                              writings: 표기 == 읽기 ? [] : [DictForm(text: 표기, priority: 0)],
                              glosses: ["-"], usuallyKana: 가나로씀)
        return SearchResult(entry: entry, reading: 읽기, matchedKana: 표면,
                            deinflection: 되돌림, score: 0)
    }

    @Test("어간을 한자로 되돌린다")
    func 어간복원() {
        // 怒る(おこる) 의 어간 おこ 는 怒 다. 활용 어미는 표면형 그대로 둔다.
        let 조각 = Segment(hangul: "오콧테",
                          results: [Self.결과("怒る", "おこる", 표면: "おこって", 되돌림: "연용형")])
        #expect(조각.japanese == "怒って")
    }

    @Test("보내는 글자가 여럿이어도 자리를 찾는다")
    func 보내는글자() {
        // 食べる(たべる) 는 た 만 한자다. べ 부터는 보내는 글자라 그대로 남는다.
        let 조각 = Segment(hangul: "타베타",
                          results: [Self.결과("食べる", "たべる", 표면: "たべた", 되돌림: "과거형")])
        #expect(조각.japanese == "食べた")
    }

    @Test("가나로 쓰는 낱말은 한자를 꺼내지 않는다")
    func 가나로씀() {
        // 사전이 uk 라고 말한 낱말이다. 자막도 그렇게 쓰므로 한자를 되살리면 오히려 낯설다.
        let 조각 = Segment(hangul: "야메로",
                          results: [Self.결과("止める", "やめる", 표면: "やめろ", 되돌림: "명령형",
                                            가나로씀: true)])
        #expect(조각.japanese == "やめろ")
    }

    @Test("어간이 안 맞으면 손대지 않는다")
    func 안맞으면() {
        // 표면형이 사전형 어간으로 시작하지 않으면 되살릴 근거가 없다. 지어내지 않는다.
        let 조각 = Segment(hangul: "키타",
                          results: [Self.결과("来る", "くる", 표면: "きた", 되돌림: "과거형")])
        #expect(조각.japanese == "きた")
    }
}
