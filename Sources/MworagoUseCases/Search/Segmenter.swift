import Foundation
import MworagoDomain

/// 입력을 낱말 조각으로 나눈 결과 하나.
public struct Segment: Sendable {
    public let hangul: String            // 이 조각의 한글 음차
    public let results: [SearchResult]   // 이 조각을 찾아본 결과. 비어 있으면 사전에 없는 조각이다
    /// **말뭉치가 이 조각의 낱말을 한자로 적는 비율.** 사전이 `uk` 라고 한 낱말을
    /// 번역기에 한자로 넘길지 가나로 넘길지는 이 값이 정한다(`japaneseForTranslation`).
    ///
    /// 나눌 때 함께 재어 둔다 — 그때가 빈도표를 쥐고 있는 유일한 자리다.
    public var kanjiShareInCorpus: Double = 0

    /// 나눈 조각이 아니라 **입력 전체**를 통째로 찾아본 결과인가.
    ///
    /// 관용구는 조각 점수 싸움에서 져서 묻히므로 통째 뜻을 앞에 얹는다. 다만 이것은
    /// 문장을 이루는 조각이 아니다 — 되살린 원문을 그릴 때 함께 이으면 문장이 두 번 적힌다.
    public var isWhole: Bool = false

    /// 첫 답 다음에 곁들일 후보들.
    ///
    /// 1위가 정답인 비율은 94%지만 3위 안에 있을 비율은 98%다. 그 4%를 사용자가 직접
    /// 고르게 하려고 대안을 곁에 둔다. 그러려면 대안이 **1위와 달라 보여야** 한다.
    ///
    /// **사전이 한 낱말로 실은 것은 한 낱말이다.** 같은 표제항이 여러 번 걸려 나오는 길은 둘이다 —
    /// 뜻갈래가 갈려 항목이 나뉘어 있거나(大丈夫는 형용동사와 명사로 두 번 실린다),
    /// 표제항 하나가 이표기를 달고 있거나(大丈夫 = だいじょうぶ · だいじょぶ).
    /// "다이죠부"는 두 읽기를 다 만들어 내므로 뒤쪽은 반드시 일어난다.
    /// 어느 쪽이든 화면에는 같은 낱말이 두 번 보일 뿐이다.
    ///
    /// 기준은 **화면에서 갈라 보이는가** 하나다. 표기가 다르면 그것으로 갈리고,
    /// 표기가 같아도 사전이 다른 낱말로 실었고 읽기까지 다르면 소리로 갈린다 —
    /// 机(つくえ)와 机(つき)가 그렇다. 그 밖에는 같은 답이 두 번 보이는 것뿐이다.
    public func alternates(limit: Int = 2) -> [SearchResult] {
        guard let top = results.first else { return [] }
        var picked: [SearchResult] = []
        for result in results.dropFirst() where picked.count < limit {
            guard !Self.sameWord(result, top),
                  !picked.contains(where: { Self.sameWord($0, result) })
            else { continue }
            picked.append(result)
        }
        return picked
    }

    /// 사용자 눈에 같은 낱말인가.
    ///
    /// 표기가 같은데 표제항까지 같다면 이표기다(大丈夫 = だいじょうぶ · だいじょぶ).
    /// 표제항이 달라도 읽기가 같다면 뜻갈래가 갈려 나뉜 것이다(大丈夫: 형용동사 / 명사).
    /// 둘 다 화면에는 똑같은 글자로 보인다.
    private static func sameWord(_ a: SearchResult, _ b: SearchResult) -> Bool {
        a.headword == b.headword && (a.entry == b.entry || a.reading == b.reading)
    }
}

/// 한글 음차 문장을 낱말 단위로 나눈다.
///
/// 일본어에는 띄어쓰기가 없다. 들은 대로 적는 사람은 `아타마가이타이`처럼 붙여 칠 것이다.
/// 그래서 어디서 끊을지를 **사전이 정하게 한다** — 나눈 조각이 실제 낱말인 분할이 이긴다.
///
/// 나누는 일 자체가 이미 문맥 판별이기도 하다.
/// ```
/// 아타마가이타이 → 頭 が 痛い
///                      ↑ 조사 が 뒤라면 痛い(형용사)지 遺体(명사)가 아니다
/// ```
public enum Segmenter {

    /// 조각 하나의 최대 길이(음절). 일본어 한 낱말이 이보다 길기는 드물고,
    /// 제한이 없으면 긴 입력에서 후보가 제곱으로 불어난다.
    private static let maxPieceLength = 10

    /// 조각이 문장에서 맡는 자리. **앞뒤를 함께 보는 규칙은 이 갈래로 말한다.**
    private enum Role: Int, CaseIterable {
        /// 어절의 첫머리. 앞에 아무것도 없다는 것 자체가 하나의 자리다.
        case start
        /// 자립어. **갈래를 모르는 것도 여기다** — 모르는 것을 부착어로 몰면
        /// 멀쩡한 낱말이 벌을 받는다.
        case content
        /// 조사·조동사·계사. 앞에 기댈 자립어가 있어야 한다.
        case bound
        /// 사전에 없는 조각.
        case unknown

        /// **그 조각의 1위가 그 조각의 얼굴이다.** 조각마다 갈래별로 가장 좋은 후보를
        /// 따로 골라 보는 길도 있지만, 그러면 규칙이 스스로 무력해진다 — `도` 는
        /// 조사 `と`(100)와 명사 `土`(100)를 함께 내므로, 조사에 벌점을 물리면
        /// 같은 점수의 명사로 갈아타서 벌점을 피해 버린다.
        init(_ top: SearchResult?) {
            guard let top else { self = .unknown; return }
            self = top.entry.isBound ? .bound : .content
        }
    }

    /// DP 한 칸. 어디서 왔고 그때 앞 조각이 무슨 갈래였는지를 함께 들고 있다.
    private struct Step {
        let score: Double
        let start: Int
        let previous: Role
    }

    /// 조각과 조각 사이에 얹는 값. **조사 앞에서만 걸린다.**
    ///
    /// 조사가 어디에 서야 하는지를 한 자리에 모아 적은 것이다 —
    /// 앞에 아무것도 없으면 그것은 조사가 아니고(벌점), 앞이 자립어면 제자리다(보너스).
    /// 조사 뒤에 조사가 오는 것(`には`·`では`)은 실제로 흔하므로 아무것도 하지 않는다.
    private static func junction(from previous: Role, to current: Role,
                                 boundPenalty: Double, junctionBonus: Double) -> Double {
        guard current == .bound else { return 0 }
        switch previous {
        case .start:   return -boundPenalty
        case .content: return junctionBonus
        case .bound, .unknown: return 0
        }
    }

    /// **빈도 목록에 없는 낱말을 편들어 보았지만, 재서 넣지 않았다.**
    ///
    /// `ではない`(exp)는 사전에 있는데 빈도 목록에는 없어 10점이고, 쪼갠 조각
    /// `は`·`ない` 는 각각 100점대다. 그래서 `好き ではない` 가 `好きで/は/ない` 로
    /// 갈려 낱말이 깨진다. 외래어가 0점이던 것과 같은 병으로 보였다.
    ///
    /// 두 갈래로 고쳐 보았고 둘 다 손해였다.
    ///
    ///  - **JMdict 빈도 태그의 무게를 올리기**(1·3·6·10) — 네 값이 한 자리도 움직이지
    ///    않았다. 그 층은 도메인 빈도가 0일 때만 쓰이는데, 조각 비용을 이기기에는
    ///    태그 점수의 자릿수 자체가 작다.
    ///  - **사전이 `exp` 로 실은 조각의 조각 비용을 덜 물리기** — Tanaka 경계는
    ///    조금 나아지는데(틀린 문장 67 → 65) **낱말이 깨진 문장은 늘었다**(18 → 20).
    ///    보너스를 키울수록 나빠진다(100 이면 22, 135 면 25). `exp` 표제항이 수만 개라
    ///    엉뚱한 관용구로 뭉치는 쪽이 더 많다.
    ///
    /// **재서 손해인 길은 내지 않는다.** 이 자리는 조각 비용이나 빈도 층으로 풀 문제가
    /// 아니라, 빈도 목록이 복합 표현을 세지 않는다는 자료 쪽 문제로 보인다.


    /// 사전에 없는 조각에 매기는 점수. **음절 하나당**이다.
    ///
    /// 조각 비용보다 커야 한다. 그러지 않으면 "나누느니 모르는 채로 두자"가 이겨서
    /// 입력 전체가 한 덩어리의 미지 조각이 된다.
    ///
    /// 길이에 비례시키는 것이 중요하다. 한 번만 깎던 때에는 그 벌점이 아는 낱말 하나
    /// 값보다 커서, `다이죠부뷁` 처럼 오타가 한 글자 붙은 입력이 통째로 미지가 됐다 —
    /// 大丈夫 까지 함께 사라진다. **오타 한 글자에 아는 낱말까지 잃으면 안 된다.**
    ///
    /// 비례로 바꿔도 "정말 모르는 구간은 통째로 둔다"는 그대로다. 잘게 쪼개면
    /// 벌점 합은 같은데 조각 비용만 더 들기 때문이다. 두 규칙이 서로를 붙잡는다.
    ///
    /// 값은 스윕이 골랐다(`--segment-sweep`). 한 번만 깎던 때의 -500 에서 -200 으로
    /// 옮겨간 것은 이제 길이가 곱해지기 때문이다.
    public static let defaultUnknownScore = -200.0

    /// 조각 하나를 만들 때마다 무는 비용.
    ///
    /// 이것이 없으면 잘게 쪼갤수록 점수 합이 커진다. 조사(`が`·`だ`)는 어느 말뭉치에서나
    /// 최상위 빈도라, `다이죠부`가 `[다][이죠부]`로 갈리고도 점수에서 이겨 버린다.
    /// 낱말 수는 적을수록 낫다는 것을 값으로 넣어 주는 자리다.
    ///
    /// Tanaka Corpus 문장 300개를 훑어 고른 값이다(`SpikeRunner --segment-sweep`).
    /// 곡선이 뚜렷하다 — 50이면 잘게 부수고(정밀도 0.50), 300이면 뭉뚱그린다(재현율 0.24).
    ///
    /// 활용형이 든 문장을 표본에서 빼고 쟀을 때는 120이 최적이었다. 활용형을 넣자
    /// 135로 옮겨 갔고 완전일치도 64%에서 43%로 떨어졌다. 쉬운 문장만 골라 재면
    /// 성적도 최적값도 함께 왜곡된다.
    ///
    /// **135 는 배포판이 쓰지 않는 빈도 목록(JPDB)으로 고른 값이었다.** 배포판이 싣는
    /// JESC 로 다시 훑으니 140 이었다. 자료가 다르면 최적값도 달라진다.
    ///
    /// **점수가 달라지면 여기도 함께 옮겨야 한다.** 빈도표의 가타카나 낱말 14,630 개가
    /// 조회 키가 어긋나 0점이던 것을 고치자(`FrequencyList.rank`) 조각들의 점수가
    /// 전반적으로 올라, 조각 하나에 물리는 값도 그만큼 내려가야 균형이 맞는다.
    /// 그때 130 으로 내렸고, `何時`(몇 시)가 `何`+`時` 로 갈리는 것을 막으려고
    /// 135 로 되돌려 두었다.
    ///
    /// **그 값들은 전부 망가진 표본에서 나왔다.** 분절 케이스를 Tanaka 말뭉치 앞에서
    /// 300개 잘라 오고 있었는데 그 앞머리가 `彼は忙しい…` 한 덩어리라 **290개가 `彼` 로
    /// 시작했다**(`SegmentCaseBuilder` 주석). 말뭉치 전체에서 균등 간격으로 집도록
    /// 고치고 다시 훑으니 최적이 **140** 이었다.
    ///
    ///     비용 135   완전일치 45.3%   경계 F1 0.894
    ///     비용 140   완전일치 47.7%   경계 F1 0.897   ← 최적
    ///     비용 145   완전일치 47.0%   경계 F1 0.893
    ///
    /// 140 은 `何時` 도 지킨다(`今 何時 です か`). 135 를 지키던 까닭이 그것뿐이었으므로
    /// 이제 훑기가 고른 값을 그대로 쓴다.
    ///
    /// **조사 경계 보너스를 넣은 뒤 다시 훑으니 145 가 나왔지만 옮기지 않았다.**
    /// (145 · 활용 벌점 10 · 보너스 12 에서 Tanaka 완전일치 50.7%, 140 · 5 · 12 는 49.0%.)
    /// 화면에서 진짜로 깨진 문장을 세면 순서가 뒤집힌다 — 145 쪽이 94, 140 쪽이 89 다.
    /// 표본 300개에서 세 값을 한꺼번에 옮기는 것은 채점표에 몸을 맞추는 일에 가깝다.
    public static let defaultSegmentCost = 140.0

    /// 어절의 첫 조각이 부착어(조사·조동사·계사)일 때 무는 벌점.
    ///
    /// **일본어 문장은 조사로 시작하지 않는다.** 조각 하나하나의 점수만 보면 이것을 모른다 —
    /// 조사는 어느 말뭉치에서나 최상위 빈도라 첫머리에 혼자 서고도 점수 싸움에서 이긴다.
    ///
    ///     도코에(どこへ, 어디로)
    ///       [도][코에]   と 100.0 + こえ 66.2  = 166.2   ← 이기고 있었다
    ///       [도코][에]   どこ 80.0 + へ  80.4  = 160.4
    ///
    /// 되살린 문장이 `とこえ` 라는 **말이 안 되는 문자열**이 되어 번역기에 실려 갔다.
    /// 6점 차라 조각 비용으로는 못 뒤집는다 — 비용은 어느 갈래에나 똑같이 걸린다.
    ///
    /// **앞의 것이 무엇인지를 보는 규칙**이 필요한 자리이고, 그중 가장 확실한 것이
    /// 이것이다(앞에 아무것도 없다). 조사끼리 잇따르는 것(`には`·`では`)은 실제로
    /// 흔하므로 벌하지 않는다. 접속사는 부착어로 치지 않는다 — `でも` 는 문장을 연다.
    ///
    /// **이 규칙이 오래 보이지 않았던 까닭은 측정기에 있었다.** 분절 케이스를 말뭉치
    /// 앞에서 300개 잘라 오고 있었는데 그중 290개가 `彼` 로 시작해서, 첫 조각을 두고
    /// 다투는 문장이 표본에 없었다. 그래서 이 규칙을 걸어도 수치가 한 자리도 움직이지
    /// 않았다(`SegmentCaseBuilder` 주석 참고).
    ///
    /// 값은 훑어서 골랐다(`SpikeRunner --bound-sweep`, 조각 비용 140).
    ///
    ///     벌점   0    완전일치 46.7%   경계 F1 0.894
    ///     벌점  20    완전일치 47.3%   경계 F1 0.897
    ///     벌점  40    완전일치 47.7%   경계 F1 0.897   ← 최적
    ///     벌점  80    완전일치 47.0%   경계 F1 0.896
    ///
    /// 40 을 넘겨도 더 좋아지지 않는다. 뒤집을 것은 이미 뒤집혔고, 그 위는 첫 조각을
    /// 억지로 길게 만드는 쪽으로만 움직인다.
    ///
    /// **이 벌점 하나로는 `도코에` 가 안 고쳐졌다.** 조사 갈래가 밀리자 이번에는
    /// `도코에` 전체가 한 조각 `どうこう`(如何斯う, 부사)로 갔다 — 장음 둘을 지어내고
    /// 어미를 명령형으로 되돌려 만든 것이다. `Ranker` 가 활용 복원을 명사에만 막고
    /// 부사에는 열어 두고 있었다. 둘을 함께 막아야 `何処 へ` 가 선다.
    public static let defaultBoundPenalty = 40.0

    /// 자립어 뒤에 조사가 서는 경계에 얹는 보너스.
    ///
    /// **조사가 뒷낱말에 삼켜지고 있었다.** `쿄다이가이마스카`(兄弟がいますか,
    /// 형제가 있습니까)가 `巨大`(거대) + `買います`(삽니다) 로 갈렸다 — `が` 가 뒤의
    /// `います` 와 붙어 사전에 있는 딴 낱말이 되는데, 조각이 하나 줄어 비용까지 아낀다.
    ///
    /// Tanaka 문장 300개의 틀린 분절을 갈라 보니 **화면에서 진짜로 틀린 101건 가운데
    /// 45건이 이것**이었다(삼켜진 조사는 `が` 16 · `を` 13 · `で` 7 · `に` 6 · `は` 5).
    /// 나머지는 자립어를 깬 과분할 26건과 그 밖의 뭉침·엇갈림 30건이다.
    ///
    /// 조각 비용은 어느 경계에나 똑같이 걸린다. 그런데 **조사 앞 경계는 다른 경계와
    /// 다르다** — 조사는 붙어 다니지만 제 몫의 낱말이고, 일본어 문장에서 가장 자주
    /// 나는 경계다. 그 자리를 값싸게 만들어 주는 것이 이 값이다.
    ///
    /// 앞 조각이 무엇이었는지를 봐야 하므로 **자리마다 점수 하나로는 모자란다.**
    /// 그래서 DP 가 마지막 조각의 갈래를 함께 들고 다닌다(`Role`).
    ///
    /// **잣대 둘이 서로 다른 값을 고른다.** Tanaka 채점표는 10 을, 화면에서 진짜로
    /// 깨진 문장만 세면 18~25 를 고른다. 채점표는 `ですか` 를 한 덩어리로 보는데
    /// 우리가 `です`+`か` 로 나누면 틀렸다고 세기 때문이다 — 화면에는 둘 다 제 뜻이 뜬다.
    ///
    ///     보너스    Tanaka 틀림    진짜 오류
    ///        0        157/300       101/300
    ///        8        153            92
    ///       10        152            91
    ///       12        153            89     ← 고른 값
    ///       18        156            87
    ///       25        161            87
    ///       40        192            91
    ///
    /// **18 을 고르지 않은 것은 그 잣대가 이 규칙을 편들기 때문이다.** "조사를 떼어낸
    /// 것은 오류로 안 센다"는 잣대에 대고 조사 떼기를 키우면 당연히 좋아진다.
    /// 12 는 두 잣대가 다 인정하는 자리다(채점표 최고 152 와 한 건 차이).
    ///
    /// 40 에서 두 잣대가 함께 무너진다. 자립어를 깬 문장이 26 → 52 로 늘어난다 —
    /// `そんなに` 가 `そんな`+`に` 로, `いつも` 가 `いつ`+`も` 로 갈린다.
    ///
    /// **"붙여 놓은 것이 사전에 있으면 보너스를 안 준다"는 길은 재서 버렸다.**
    /// 갈린 부사들을 지키려던 것인데, 그 조건이 **삼킴을 그대로 되살린다** —
    /// `が`+`います` 를 붙인 `買います` 도 사전에 있는 낱말이라 보너스가 꺼진다.
    /// 진짜 오류 89 → 96(조사 삼킴 32 → 41)으로 나빠졌다.
    ///
    /// 그리고 애초에 그 부사들은 보너스 탓에 갈린 것이 아니었다. `そんなに` 는
    /// **빈도 목록에 없어 10점**이고 `そんな`(79.8)+`に`(110.5)는 190점이라,
    /// 보너스가 0 이어도 진다. `ではない` 와 같은 병이다 — 점수로 풀 자리가 아니라
    /// 빈도를 셀 때 복합 표현을 한 덩어리로 세야 하는 **자료 쪽 문제**였고,
    /// 그래서 세는 자리를 고쳤다(`--build-frequency` 가 이어진 토큰도 함께 센다).
    ///
    /// **빈도 목록이 바뀌자 이 값도 움직였다.** 복합 표현이 제 점수를 얻으면서
    /// 뭉치는 쪽 힘이 세졌고, 그것을 막는 이 값도 함께 커져야 균형이 맞는다.
    ///
    ///     보너스    Tanaka 틀림    진짜 오류
    ///       12        146/300        87/300
    ///       16        148            89
    ///       18        147            85
    ///       20        147            82     ← 고른 값
    ///       22        147            83
    ///       24        151            88
    ///       30        170            94
    ///
    /// 18~22 가 평평하고 그 밖은 나빠진다. Tanaka 쪽은 그 구간에서 움직이지 않으므로
    /// 이 값은 채점표를 내주지 않고 얻는 것이다.
    public static let defaultJunctionBonus = 20.0

    /// 분절이 쓰는 가중치. 낱말 검색과 한 가지가 다르다 — **활용을 되돌린 것에 무는 벌점**.
    ///
    /// 낱말 검색에서 이 벌점(25)은 타당하다. 사용자가 낱말 하나를 쳤다면 등재형일
    /// 공산이 크기 때문이다. 그런데 **문장 안에서는 활용형이 정상**이다. 그 벌점 때문에
    /// `카케타`(かけた)가 `카케`+`타` 로 갈렸다 — `た` 는 조동사로 어느 말뭉치에서나
    /// 최상위 빈도라 두 조각의 합이 활용형 하나를 이겨 버린다.
    /// 틀린 문장을 뽑아 보니 **실패의 76%가 이렇게 잘게 쪼갠 것**이었다.
    ///
    /// 5 가 가장 나았다(완전일치 27.7% → 34.0%, 조각 비용 140 과 함께). 0 이 아닌 것은
    /// 등재형이 있으면 그쪽을 먼저 보는 편이 여전히 낫기 때문이다(0 에서 33.0%).
    public static let defaultWeights: Ranker.Weights = {
        var weights = Ranker.Weights()
        weights.deinflectionPenalty = 5
        return weights
    }()

    /// `cache` 를 주면 조각을 찾아본 결과를 호출 사이에도 들고 있는다.
    /// 글자를 칠 때마다 다시 찾는 화면에서는 이것이 있고 없고가 크게 갈린다.
    public static func segment(_ input: String,
                               in index: some DictionaryLookup,
                               frequency: FrequencyList? = nil,
                               weights: Ranker.Weights = defaultWeights,
                               segmentCost: Double = defaultSegmentCost,
                               unknownScore: Double = defaultUnknownScore,
                               boundPenalty: Double = defaultBoundPenalty,
                               junctionBonus: Double = defaultJunctionBonus,
                               cache: SearchCache? = nil) -> [Segment] {
        var segments: [Segment] = []
        // 사람이 띄어 썼다면 그 뜻을 존중한다. 어절 안쪽만 사전을 보고 나눈다.
        for word in input.split(whereSeparator: \.isWhitespace) {
            segments += segmentWord(String(word), in: index, frequency: frequency,
                                    weights: weights, segmentCost: segmentCost,
                                    unknownScore: unknownScore,
                                    boundPenalty: boundPenalty,
                                    junctionBonus: junctionBonus,
                                    cache: cache)
        }
        return segments
    }

    private static func segmentWord(_ word: String,
                                    in index: some DictionaryLookup,
                                    frequency: FrequencyList?,
                                    weights: Ranker.Weights,
                                    segmentCost: Double,
                                    unknownScore: Double,
                                    boundPenalty: Double,
                                    junctionBonus: Double,
                                    cache: SearchCache?) -> [Segment] {
        let syllables = Array(word)
        guard !syllables.isEmpty else { return [] }

        // 밖에서 받은 것이 있으면 그것을 쓴다. 없으면 이 한 번을 위한 것을 만든다 —
        // 한 문장 안에서도 같은 조각을 여러 번 재보므로 그때도 값어치가 있다.
        let store = cache ?? SearchCache()
        func lookup(_ piece: String) -> [SearchResult] {
            store.result(for: piece) {
                Ranker.search(piece, in: index, frequency: frequency, weights: weights)
            }
        }

        // best[i][갈래] = 앞에서부터 i음절까지를 나눈 최선의 방법. **갈래는 마지막 조각의 것**이다.
        //
        // 자리마다 점수 하나만 들고 가면 앞뒤를 함께 보는 규칙을 걸 수가 없다 —
        // 같은 자리라도 마지막 조각이 자립어였는지 조사였는지에 따라 다음 경계의 값이
        // 달라진다. 갈래가 넷뿐이라 상태를 넷으로 늘려도 값이 거의 안 든다.
        var best = Array(repeating: [Step?](repeating: nil, count: Role.allCases.count),
                         count: syllables.count + 1)
        best[0][Role.start.rawValue] = Step(score: 0, start: -1, previous: .start)

        for end in 1...syllables.count {
            for start in max(0, end - maxPieceLength)..<end {
                let piece = String(syllables[start..<end])
                let results = lookup(piece)
                // **모르는 조각은 길수록 나쁘다.** 길이와 무관하게 한 번만 깎으면
                // 아는 낱말 하나 값보다 벌점이 커서, 다이죠부뷁 처럼 오타가 한 글자 붙은 것이
                // 통째로 미지가 됐다 — 大丈夫 까지 함께 사라진다.
                //
                // 길이에 비례시켜도 "정말 모르는 구간은 통째로 둔다"는 그대로다.
                // 잘게 쪼개면 벌점 합은 같은데 조각 비용만 더 들기 때문이다.
                let piecePenalty = unknownScore * Double(end - start)
                let base = (results.first?.score ?? piecePenalty) - segmentCost
                let role = Role(results.first)

                for previous in Role.allCases {
                    guard let step = best[start][previous.rawValue] else { continue }
                    let edge = junction(from: previous, to: role,
                                        boundPenalty: boundPenalty, junctionBonus: junctionBonus)
                    let total = step.score + base + edge
                    if best[end][role.rawValue] == nil || total > best[end][role.rawValue]!.score {
                        best[end][role.rawValue] = Step(score: total, start: start, previous: previous)
                    }
                }
            }
        }

        // 뒤에서부터 되짚어 조각을 모은다. 끝자리에서 가장 좋은 갈래부터 잡는다.
        var pieces: [String] = []
        var cursor = syllables.count
        var role = best[cursor].enumerated()
            .compactMap { index, step in step.map { (Role(rawValue: index)!, $0.score) } }
            .max { $0.1 < $1.1 }?.0
        while cursor > 0, let current = role, let step = best[cursor][current.rawValue] {
            pieces.append(String(syllables[step.start..<cursor]))
            cursor = step.start
            role = step.previous
        }
        let segments = pieces.reversed().map { piece -> Segment in
            let results = lookup(piece)
            var segment = Segment(hangul: piece, results: results)
            // 사전이 `uk` 라고 한 낱말만 물어보면 된다. 그 밖에는 한자를 쓰는 것이 기본이다.
            if let top = results.first, top.entry.usuallyKana, let frequency,
               !top.headword.isEmpty, top.headword != top.reading {
                segment.kanjiShareInCorpus = frequency.kanjiShare(writing: top.headword,
                                                                 reading: top.reading)
            }
            return segment
        }

        // **통째로도 사전에 실려 있으면 그것부터 낸다.**
        //
        // 관용구는 조각 점수 싸움에서 진다 — 조각이 다 흔한 낱말일수록 그렇다.
        // `잇테키마스` 는 `잇테`(行って)와 `키마스`(来ます)가 둘 다 최상위 빈도라
        // 나누는 쪽이 이겨서, 사전에 있는 `行ってきます`("다녀오겠습니다")가 묻혔다.
        // `잇테랏샤이` 가 살아남은 것은 `랏샤이` 가 실재하지 않아 쪼갤 수 없어서였을 뿐이다.
        //
        // 분절 가중치를 손대면 검색 전체가 흔들린다. 나눈 결과는 그대로 두고
        // 통째 뜻을 **앞에** 얹는다 — 어느 쪽이 맞는지는 보는 사람이 안다.
        guard segments.count > 1 else { return segments }
        // **통째 후보는 확신이 있을 때만 세운다.**
        //
        // 활용을 되돌려야 겨우 맞은 것은 관용구가 아니라 **글자가 우연히 맞은 것**이다.
        // `도코에`(どこへ, 어디로)의 맨 위 카드에 `同校`(같은 학교)가 떴다 —
        // 장음을 둘 지어내고 어미를 명령형으로 되돌려 만든 `どうこう` 였다.
        // `잇테키마스` → `行ってきます` 처럼 진짜 관용구는 되돌릴 것 없이 그대로 맞는다.
        let whole = lookup(word).filter { $0.deinflection == nil }
        return whole.isEmpty ? segments
                             : [Segment(hangul: word, results: whole, isWhole: true)] + segments
    }
}
