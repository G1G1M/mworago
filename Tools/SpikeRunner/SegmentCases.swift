import Foundation
import MworagoCore

// 분절 케이스는 Tanaka Corpus(EDRDG, CC BY-SA)에서 만든다.
//
// 문장을 내가 지어내면 낱말 케이스와 같은 편향이 반복된다. Tanaka Corpus 는
// 문장마다 **사람이 손으로 나눈 낱말 경계와 읽기**를 달고 있어, 정답을 내가 정하지 않아도 된다.
//
//   A: 彼は本を読む。
//   B: 彼(かれ)[01] は 本(ほん) を 読む
//        ↑ 경계와 읽기가 이미 있다

enum TanakaCorpus {

    struct Token {
        let headword: String   // 사전 표제어
        let reading: String    // 실제 문장에서의 읽기(가나)
        let surface: String?   // 문장에 나타난 형태. 활용했으면 표제어와 다르다

        var display: String { surface ?? headword }
    }

    /// `표제어(읽기)[센스]{표면형}~` 하나를 뜯는다.
    static func parseToken(_ token: String) -> Token? {
        var rest = Substring(token)
        if rest.hasSuffix("~") { rest = rest.dropLast() }

        var surface: String?
        if let open = rest.firstIndex(of: "{"), let close = rest.lastIndex(of: "}") {
            surface = String(rest[rest.index(after: open)..<close])
            rest = rest[..<open]
        }
        if let open = rest.firstIndex(of: "["), let close = rest.lastIndex(of: "]") {
            rest = rest[..<open] + rest[rest.index(after: close)...]
        }
        var reading: String?
        if let open = rest.firstIndex(of: "("), let close = rest.lastIndex(of: ")") {
            let inside = String(rest[rest.index(after: open)..<close])
            // で(#2028980) 처럼 괄호 안이 JMdict 시퀀스 번호인 경우가 있다. 읽기가 아니다.
            if !inside.hasPrefix("#") { reading = inside }
            rest = rest[..<open]
        }

        let headword = String(rest)
        guard !headword.isEmpty else { return nil }
        // 읽기가 안 적혔으면 표제어 자체가 가나다 (조사 등)
        let baseReading = reading ?? headword

        guard let surface else {
            return Token(headword: headword, reading: baseReading, surface: nil)
        }
        guard let actual = InflectedReading.make(headword: headword, reading: baseReading, surface: surface) else {
            return nil   // 읽기를 만들 수 없으면 이 문장은 쓸 수 없다
        }
        return Token(headword: headword, reading: actual, surface: surface)
    }

    /// 쓰는 대로와 읽는 대로가 다른 조사.
    ///
    /// 일본어에서 표기와 발음이 어긋나는 낱말은 이 셋뿐이다 — `は`(와) · `へ`(에) ·
    /// `を`(오). 앞의 둘이 문제가 된다(`を` 는 음차가 이미 `오` 로 떨어진다).
    ///
    /// **타나카는 조사를 표기로 적어 둔다.** 그것을 그대로 음차하면 케이스 입력이
    /// `하`·`헤` 가 되는데, 소리로 찾는 이 앱의 사용자는 `와`·`에` 로 친다.
    /// 그래서 케이스 300개에 실제로 들어오는 입력이 **하나도 없었다** —
    /// 측정기가 구조적으로 못 보는 자리였고, `와타시와` 가 `私 わ` 로 깨지는 것을
    /// 여기서 한 번도 잡지 못했다.
    static let spokenParticles: [String: String] = ["は": "わ", "へ": "え"]

    /// 그 낱말을 사람이 **소리 내어 치는** 대로의 읽기.
    ///
    /// 조사로 보는 조건은 **표제어 자체가 그 가나 한 글자인 것**이다. 歯(は)·屁(へ) 는
    /// 표제어가 한자라 여기 걸리지 않고, 활용해서 표면형이 따로 붙은 것도 아니다.
    static func spokenReading(_ token: Token) -> String {
        guard token.surface == nil,
              token.reading == token.headword,
              let spoken = spokenParticles[token.headword]
        else { return token.reading }
        return spoken
    }

    /// B 라인 하나를 낱말 열로.
    static func parseLine(_ line: String) -> [Token] {
        line.dropFirst(3)                       // "B: "
            .split(separator: " ")
            .compactMap { parseToken(String($0)) }
    }
}

/// 분절 케이스 하나.
struct SegmentCase {
    let hangul: String          // 입력 — 붙여 쓴 한글 음차
    let words: [String]         // 정답 낱말(표기)
    let readings: [String]      // 정답 낱말의 읽기
    /// 각 낱말을 따로 음차한 것. 분절 결과와 맞대 보는 자리다.
    let pieces: [String]
}

enum SegmentCaseBuilder {

    /// 활용형이 붙은 토큰은 읽기가 표제어 기준이라 실제 발음과 어긋난다. 그런 문장은 버린다.
    ///
    /// **말뭉치 앞에서 끊어 오지 않는다.** Tanaka 는 일본어 문장으로 정렬돼 있어서
    /// 앞머리가 `彼は忙しい…` 한 덩어리다 — 앞에서 300개를 집으면 **290개가 `彼` 로
    /// 시작한다.** 그러면 측정기가 한 문형만 재게 되고, 그 문형에 없는 병은 구조적으로
    /// 못 본다. 조사로 시작하는 잘못된 분절을 벌하는 규칙이 "수치가 한 자리도 안
    /// 움직인다"고 나왔던 것이 그 때문이었다 — 표본에 조사로 시작하는 문장이 없었다.
    /// (`は`·`へ` 를 소리대로 못 치던 때와 같은 병이다. 그때도 케이스가 그 입력을
    /// 하나도 만들지 않고 있었다.)
    ///
    /// 그래서 쓸 수 있는 문장을 **다 모은 뒤 균등 간격으로 집는다.** 난수를 쓰지 않아
    /// 돌릴 때마다 같은 표본이 나온다.
    static func build(from path: String, limit: Int) -> [SegmentCase] {
        let all = buildAll(from: path)
        guard all.count > limit, limit > 0 else { return all }
        let step = Double(all.count) / Double(limit)
        return (0..<limit).map { all[Int(Double($0) * step)] }
    }

    /// 말뭉치에서 쓸 수 있는 문장을 전부 만든다.
    ///
    /// **주석이 문장을 다 덮는지 A 줄과 맞춰 본다.** Tanaka 의 B 줄은 사전에 실린 낱말만
    /// 적어서 고유명사를 통째로 건너뛰는 일이 있다 —
    /// `次郎は服にさっとブラシをかけた` 의 주석은 `は 服 に …` 로 시작한다.
    /// 그것을 그대로 케이스로 만들면 **조사로 시작하는 입력**(`와후쿠니…`)이 되는데,
    /// 그런 문장은 일본어에 없다. 균등 간격으로 300개를 집으면 13개가 그런 것이었다.
    /// 덮지 못하는 줄은 전체의 9%뿐이라 버려도 표본이 넉넉하다.
    static func buildAll(from path: String) -> [SegmentCase] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        var cases: [SegmentCase] = []
        var seen = Set<String>()
        var sentence = ""   // 바로 앞 A 줄의 문장

        for line in text.split(separator: "\n") {
            if line.hasPrefix("A: ") {
                sentence = String(line.dropFirst(3).split(separator: "\t").first ?? "")
                continue
            }
            guard line.hasPrefix("B: ") else { continue }
            // 토큰 하나라도 읽기를 못 만들면 parseLine 이 그 토큰을 버리므로 수가 안 맞는다
            let rawCount = String(line).dropFirst(3).split(separator: " ").count
            let tokens = TanakaCorpus.parseLine(String(line))
            guard tokens.count == rawCount, (3...8).contains(tokens.count) else { continue }

            // 주석이 문장을 통째로 덮어야 한다. 구두점은 낱말이 아니므로 세지 않는다.
            let bare = sentence.filter { $0.isLetter || $0.isNumber }
            guard tokens.map(\.display).joined() == bare else { continue }

            // 읽기가 전부 가나여야 음차할 수 있다
            guard tokens.allSatisfy({ $0.reading.allSatisfy(\.isKana) }) else { continue }

            // **입력은 소리다.** 정답(`readings`)은 표기 그대로 두고 입력만 읽는 대로 만든다 —
            // 사용자가 `와` 를 치면 `は` 가 나와야 한다는 것이 이 케이스가 묻는 것이다.
            let pieces = tokens.map { KanaToHangul.transliterate(TanakaCorpus.spokenReading($0)) }
            guard pieces.allSatisfy({ !$0.isEmpty && HangulSyllable.decompose($0) != nil }) else { continue }

            let hangul = pieces.joined()
            guard (4...20).contains(hangul.count), seen.insert(hangul).inserted else { continue }

            cases.append(SegmentCase(hangul: hangul,
                                     words: tokens.map(\.display),
                                     readings: tokens.map(\.reading),
                                     pieces: pieces))
        }
        return cases
    }
}


// MARK: 분절 측정

enum SegmentEval {
    struct Score {
        var exact = 0            // 조각이 정답과 완전히 같은 문장 수
        var senseHit = 0         // 그 조각의 1위 표제어가 정답 낱말과 같은 횟수
        var senseTotal = 0       // 견줄 수 있었던 조각 수(경계가 맞은 것만)
        var senseTop3 = 0        // 정답이 3위 안에 있는 횟수
        var senseAnywhere = 0    // 정답이 후보 어딘가에는 있는 횟수
        var boundaryHit = 0      // 맞힌 경계 수
        var boundaryFound = 0    // 내가 그은 경계 수
        var boundaryTruth = 0    // 정답 경계 수
        var total = 0

        var exactRate: Double { total == 0 ? 0 : Double(exact) / Double(total) }
        /// 경계를 맞힌 조각에서 **뜻까지 맞혔는가.** 문맥 판별(3층)이 벌 수 있는 몫의
        /// 상한이 여기서 나온다 — 이미 1위가 정답이면 모델이 고쳐 줄 것이 없다.
        var senseRate: Double { senseTotal == 0 ? 0 : Double(senseHit) / Double(senseTotal) }
        var senseTop3Rate: Double { senseTotal == 0 ? 0 : Double(senseTop3) / Double(senseTotal) }
        var senseAnywhereRate: Double { senseTotal == 0 ? 0 : Double(senseAnywhere) / Double(senseTotal) }
        var precision: Double { boundaryFound == 0 ? 0 : Double(boundaryHit) / Double(boundaryFound) }
        var recall: Double { boundaryTruth == 0 ? 0 : Double(boundaryHit) / Double(boundaryTruth) }
        var f1: Double {
            let (p, r) = (precision, recall)
            return p + r == 0 ? 0 : 2 * p * r / (p + r)
        }
    }

    /// 조각 길이 열을 경계 위치 집합으로. 마지막 경계(문장 끝)는 누구나 맞히므로 뺀다.
    static func boundaries(_ pieces: [String]) -> Set<Int> {
        var result: Set<Int> = []
        var cursor = 0
        for piece in pieces.dropLast() {
            cursor += piece.count
            result.insert(cursor)
        }
        return result
    }

    /// `cache` 는 **가중치가 같은 동안만** 물려 쓸 수 있다. 조각을 찾아본 결과는
    /// 가중치가 정하고 조각 비용은 나눌 자리만 정하므로, 비용을 훑는 사이에는 그대로다.
    static func evaluate(_ cases: [SegmentCase], index: some DictionaryLookup,
                         frequency: FrequencyList?,
                         weights: Ranker.Weights = Ranker.Weights(),
                         segmentCost: Double,
                         unknownScore: Double = Segmenter.defaultUnknownScore,
                         boundPenalty: Double = Segmenter.defaultBoundPenalty,
                         cache: SearchCache? = nil) -> Score {
        var score = Score()
        for testCase in cases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             weights: weights,
                                             segmentCost: segmentCost, unknownScore: unknownScore,
                                             boundPenalty: boundPenalty, cache: cache)
            let mine = segments.map(\.hangul)
            score.total += 1
            if mine == testCase.pieces { score.exact += 1 }

            // 경계가 맞은 문장에서만 뜻을 견준다. 경계가 어긋나면 무엇과 견줄지가 없다.
            //
            // **읽기로 견준다.** Tanaka 의 정답은 문장에 나타난 그대로라 활용형이고
            // 표기도 제각각인데(`かけた` · `した` · `うわさ`), 우리 결과는 사전형이다
            // (`掛ける` · `する` · `噂`). 표제어를 문자열로 견주면 맞은 것이 통째로
            // 틀린 것이 된다 — 처음에 그렇게 재어 21.9%를 "후보에 없다"고 잘못 셌다.
            if mine == testCase.pieces {
                for (i, segment) in segments.enumerated() where i < testCase.readings.count {
                    guard segment.results.first != nil else { continue }
                    let forms = Set(Deinflector.candidates(for: testCase.readings[i]).map(\.form))
                    func matches(_ result: SearchResult) -> Bool { forms.contains(result.reading) }
                    score.senseTotal += 1
                    if matches(segment.results[0]) { score.senseHit += 1 }
                    if segment.results.prefix(3).contains(where: matches) { score.senseTop3 += 1 }
                    if segment.results.contains(where: matches) { score.senseAnywhere += 1 }
                }
            }

            let truth = boundaries(testCase.pieces)
            let found = boundaries(mine)
            score.boundaryHit += found.intersection(truth).count
            score.boundaryFound += found.count
            score.boundaryTruth += truth.count
        }
        return score
    }
}
