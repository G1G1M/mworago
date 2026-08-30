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

    /// 활용형의 읽기를 만든다.
    ///
    /// B 라인은 표제어의 읽기만 적어 준다(`読む(よむ){読んだ}`). 실제 발음은 `よんだ`인데
    /// 그 읽기는 어디에도 없다. 한자 어간은 활용해도 읽기가 변하지 않으므로,
    /// 표제어에서 어간의 읽기를 떼어 내 표면형의 어미에 붙이면 된다.
    ///
    ///     読む(よむ) + 読んだ  →  어간 読 = よ, 어미 む → んだ  ⇒  よんだ
    static func surfaceReading(headword: String, reading: String, surface: String) -> String? {
        // 표면형이 전부 가나면 그 자체가 읽기다 (する{してる})
        if surface.allSatisfy(\.isKana) { return surface }

        let stem = headword.prefix { !$0.isKana }
        guard !stem.isEmpty, surface.hasPrefix(stem) else { return nil }

        let headwordTail = headword.dropFirst(stem.count)
        let surfaceTail = surface.dropFirst(stem.count)
        guard reading.hasSuffix(headwordTail), surfaceTail.allSatisfy(\.isKana) else { return nil }

        return String(reading.dropLast(headwordTail.count)) + String(surfaceTail)
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
        guard let actual = surfaceReading(headword: headword, reading: baseReading, surface: surface) else {
            return nil   // 읽기를 만들 수 없으면 이 문장은 쓸 수 없다
        }
        return Token(headword: headword, reading: actual, surface: surface)
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
    static func build(from path: String, limit: Int) -> [SegmentCase] {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        var cases: [SegmentCase] = []
        var seen = Set<String>()

        for line in text.split(separator: "\n") where line.hasPrefix("B: ") {
            // 토큰 하나라도 읽기를 못 만들면 parseLine 이 그 토큰을 버리므로 수가 안 맞는다
            let rawCount = String(line).dropFirst(3).split(separator: " ").count
            let tokens = TanakaCorpus.parseLine(String(line))
            guard tokens.count == rawCount, (3...8).contains(tokens.count) else { continue }

            // 읽기가 전부 가나여야 음차할 수 있다
            guard tokens.allSatisfy({ $0.reading.allSatisfy(\.isKana) }) else { continue }

            let pieces = tokens.map { KanaToHangul.transliterate($0.reading) }
            guard pieces.allSatisfy({ !$0.isEmpty && HangulSyllable.decompose($0) != nil }) else { continue }

            let hangul = pieces.joined()
            guard (4...20).contains(hangul.count), seen.insert(hangul).inserted else { continue }

            cases.append(SegmentCase(hangul: hangul,
                                     words: tokens.map(\.display),
                                     readings: tokens.map(\.reading),
                                     pieces: pieces))
            if cases.count >= limit { break }
        }
        return cases
    }
}

extension Character {
    /// 히라가나·가타카나·장음 부호
    var isKana: Bool {
        unicodeScalars.allSatisfy { (0x3041...0x30FF).contains($0.value) }
    }
}


// MARK: 분절 측정

enum SegmentEval {
    struct Score {
        var exact = 0            // 조각이 정답과 완전히 같은 문장 수
        var boundaryHit = 0      // 맞힌 경계 수
        var boundaryFound = 0    // 내가 그은 경계 수
        var boundaryTruth = 0    // 정답 경계 수
        var total = 0

        var exactRate: Double { total == 0 ? 0 : Double(exact) / Double(total) }
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

    static func evaluate(_ cases: [SegmentCase], index: some DictionaryLookup,
                         frequency: FrequencyList?, segmentCost: Double,
                         unknownScore: Double = Segmenter.defaultUnknownScore) -> Score {
        var score = Score()
        for testCase in cases {
            let segments = Segmenter.segment(testCase.hangul, in: index, frequency: frequency,
                                             segmentCost: segmentCost, unknownScore: unknownScore)
            let mine = segments.map(\.hangul)
            score.total += 1
            if mine == testCase.pieces { score.exact += 1 }

            let truth = boundaries(testCase.pieces)
            let found = boundaries(mine)
            score.boundaryHit += found.intersection(truth).count
            score.boundaryFound += found.count
            score.boundaryTruth += truth.count
        }
        return score
    }
}
